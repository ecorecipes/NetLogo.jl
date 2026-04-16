module NetLogoVignetteSupport

using NetLogo
using Sockets

export benchmark_backend, benchmark_model, benchmark_model_keys, close_bundle!, model_title

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const PROJECT_ROOT = normpath(joinpath(REPO_ROOT, ".."))
const EVAL_MODELS_DIR = joinpath(REPO_ROOT, "eval", "models")
const STANDARD_PEN_COLORS = Float64[55.0, 15.0, 5.0, 105.0, 45.0, 125.0, 85.0, 25.0]
const SOURCE_SEARCH_DIRS = (
  netlogo_dist=joinpath(PROJECT_ROOT, "NetLogo-dist", "NetLogo-6.4.0-64", "models"),
  modelingcommons=joinpath(PROJECT_ROOT, "modelingcommons"),
  classmodels=joinpath(PROJECT_ROOT, "ClassModels"),
  model_zoo=joinpath(PROJECT_ROOT, "model-zoo"),
)
const SOURCE_PATH_ALIASES = Dict(
  :decay => joinpath(SOURCE_SEARCH_DIRS.netlogo_dist, "Sample Models", "Chemistry & Physics", "Radioactivity", "Decay.nlogo"),
  :fire => joinpath(SOURCE_SEARCH_DIRS.netlogo_dist, "Sample Models", "Earth Science", "Fire.nlogo"),
  :firepercolation => joinpath(SOURCE_SEARCH_DIRS.model_zoo, "as-released", "base-models", "5.3-firePercolation.nlogo"),
)
const SOURCE_INDEX_CACHE = Ref{Union{Nothing, NamedTuple}}(nothing)
const SOURCE_INTERFACE_CACHE = Dict{String, Union{Nothing, NamedTuple{(:widgets, :defaults), Tuple{Vector{NetLogo.InterfaceWidgetSpec}, Dict{String, Any}}}}}()
const SIR_DEFAULTS = Dict(
  "POPULATION" => 200.0,
  "INITIAL-INFECTED" => 5.0,
  "INITIAL-RECOVERED" => 0.0,
  "INFECTION-PROBABILITY" => 0.15,
  "INFECTION-RADIUS" => 1.5,
  "RECOVERY-DAYS" => 14.0,
  "MOVEMENT-STEP" => 1.0,
  "TURN-RANGE" => 25.0,
)

Base.include(@__MODULE__, joinpath(REPO_ROOT, "eval", "NetLogoCompare.jl"))

function ensure_all_model_files_loaded!()
  for path in sort(readdir(EVAL_MODELS_DIR; join=true))
    endswith(path, ".jl") || continue
    match_obj = match(r"struct\s+([A-Za-z0-9_]+)\s*<:\s*[A-Za-z0-9_]*BenchmarkModel", read(path, String))
    match_obj === nothing && continue
    type_name = Symbol(only(match_obj.captures))
    isdefined(NetLogoCompare, type_name) || Base.include(NetLogoCompare, path)
  end
  nothing
end

ensure_all_model_files_loaded!()

function discover_model_types()
  mapping = Dict{Symbol, Symbol}()
  for path in sort(readdir(EVAL_MODELS_DIR; join=true))
    endswith(path, ".jl") || continue
    match_obj = match(r"struct\s+([A-Za-z0-9_]+)\s*<:\s*[A-Za-z0-9_]*BenchmarkModel", read(path, String))
    match_obj === nothing && continue
    key = Symbol(first(splitext(basename(path))))
    type_name = Symbol(only(match_obj.captures))
    isdefined(NetLogoCompare, type_name) || continue
    mapping[key] = type_name
  end
  mapping
end

const MODEL_TYPES = discover_model_types()
const MODEL_KEYS_BY_TYPE = Dict(getfield(NetLogoCompare, type_name) => key for (key, type_name) in MODEL_TYPES)

benchmark_model_keys() = sort!(collect(keys(MODEL_TYPES)); by=String)

function benchmark_model(name::Union{Symbol, AbstractString})
  key = name isa Symbol ? name : Symbol(String(name))
  type_name = get(MODEL_TYPES, key, nothing)
  type_name === nothing && throw(ArgumentError("No vignette support registered for eval model $(key)."))
  getfield(NetLogoCompare, type_name)()
end

model_title(name::Union{Symbol, AbstractString}) = NetLogoCompare.model_name(benchmark_model(name))
benchmark_model_key(benchmark_model) = MODEL_KEYS_BY_TYPE[typeof(benchmark_model)]

function free_local_port()
  server = listen(ip"127.0.0.1", 0)
  try
    Int(last(getsockname(server)))
  finally
    close(server)
  end
end

function prettify_global_name(name::AbstractString)
  raw = String(name)
  occursin(r"^[A-Za-z][A-Za-z0-9-]*$", raw) || return raw
  cleaned = replace(lowercase(raw), "num-" => "")
  join(uppercasefirst.(split(cleaned, '-')), " ")
end

normalize_lookup_name(name::AbstractString) = replace(lowercase(String(name)), r"[^a-z0-9]+" => "")

function source_index()
  cached = SOURCE_INDEX_CACHE[]
  cached !== nothing && return cached

  by_corpus = (
    netlogo_dist=Dict{String, Vector{String}}(),
    modelingcommons=Dict{String, Vector{String}}(),
    classmodels=Dict{String, Vector{String}}(),
    model_zoo=Dict{String, Vector{String}}(),
  )
  modelingcommons_ids = Dict{String, String}()

  for (corpus_name, root) in pairs(SOURCE_SEARCH_DIRS)
    isdir(root) || continue
    for (dirpath, _, filenames) in walkdir(root)
      for filename in filenames
        endswith(lowercase(filename), ".nlogo") || continue
        full_path = joinpath(dirpath, filename)
        key = normalize_lookup_name(first(splitext(filename)))
        push!(get!(getproperty(by_corpus, corpus_name), key, String[]), full_path)
      end
    end
  end

  if isdir(SOURCE_SEARCH_DIRS.modelingcommons)
    for entry in readdir(SOURCE_SEARCH_DIRS.modelingcommons)
      match_obj = match(r"^(\d+)-", entry)
      match_obj === nothing && continue
      model_dir = joinpath(SOURCE_SEARCH_DIRS.modelingcommons, entry, "model")
      isdir(model_dir) || continue
      for filename in sort(readdir(model_dir))
        endswith(lowercase(filename), ".nlogo") || continue
        modelingcommons_ids[only(match_obj.captures)] = joinpath(model_dir, filename)
        break
      end
    end
  end

  cache_value = (; by_corpus, modelingcommons_ids)
  SOURCE_INDEX_CACHE[] = cache_value
  cache_value
end

function wrapper_source_text(model_key::Symbol)
  read(joinpath(EVAL_MODELS_DIR, string(model_key) * ".jl"), String)
end

function preferred_source_corpora(wrapper_source::AbstractString)
  if occursin("ClassModels", wrapper_source)
    (:classmodels, :netlogo_dist, :modelingcommons, :model_zoo)
  elseif occursin("model-zoo", wrapper_source)
    (:model_zoo, :netlogo_dist, :modelingcommons, :classmodels)
  elseif occursin("modsoc", wrapper_source)
    (:netlogo_dist, :model_zoo, :modelingcommons, :classmodels)
  elseif occursin("NetLogo models library", wrapper_source)
    (:netlogo_dist, :classmodels, :model_zoo, :modelingcommons)
  else
    (:netlogo_dist, :modelingcommons, :classmodels, :model_zoo)
  end
end

function lookup_original_model_path(model_key::Symbol, benchmark_model)
  benchmark_model isa NetLogoCompare.FileBenchmarkModel && return NetLogoCompare.nlogo_path(benchmark_model)

  alias_path = get(SOURCE_PATH_ALIASES, model_key, nothing)
  alias_path !== nothing && isfile(alias_path) && return alias_path

  source_text = wrapper_source_text(model_key)
  index = source_index()
  mc_match = match(r"modelingcommons\s+#(\d+)", source_text)
  if mc_match !== nothing
    return get(index.modelingcommons_ids, only(mc_match.captures), nothing)
  end

  names = String[
    NetLogoCompare.model_name(benchmark_model),
    replace(string(model_key), '_' => ' '),
  ]
  keys = unique(normalize_lookup_name(name) for name in names if !isempty(strip(name)))
  for corpus_name in preferred_source_corpora(source_text)
    corpus_index = getproperty(index.by_corpus, corpus_name)
    for key in keys
      matches = get(corpus_index, key, nothing)
      matches === nothing || isempty(matches) || return first(matches)
    end
  end

  nothing
end

parameter_widget_global_name(::NetLogo.InterfaceWidgetSpec) = nothing
parameter_widget_global_name(widget::NetLogo.SliderWidgetSpec) = widget.variable
parameter_widget_global_name(widget::NetLogo.SwitchWidgetSpec) = widget.variable
parameter_widget_global_name(widget::NetLogo.ChooserWidgetSpec) = widget.variable
parameter_widget_global_name(widget::NetLogo.InputBoxWidgetSpec) = widget.variable

is_parameter_widget(::NetLogo.InterfaceWidgetSpec) = false
is_parameter_widget(::NetLogo.SliderWidgetSpec) = true
is_parameter_widget(::NetLogo.SwitchWidgetSpec) = true
is_parameter_widget(::NetLogo.ChooserWidgetSpec) = true
is_parameter_widget(::NetLogo.InputBoxWidgetSpec) = true

function relayout_parameter_widget(widget::NetLogo.SliderWidgetSpec, top::Int)
  NetLogo.SliderWidgetSpec(540, top, 860, top + 34, widget.display, widget.variable, widget.minimum, widget.maximum, widget.default_value, widget.step, widget.units, widget.direction)
end

function relayout_parameter_widget(widget::NetLogo.SwitchWidgetSpec, top::Int)
  NetLogo.SwitchWidgetSpec(540, top, 860, top + 34, widget.display, widget.variable, widget.on)
end

function relayout_parameter_widget(widget::NetLogo.ChooserWidgetSpec, top::Int)
  NetLogo.ChooserWidgetSpec(540, top, 860, top + 45, widget.display, widget.variable, copy(widget.choices), widget.current_choice)
end

function relayout_parameter_widget(widget::NetLogo.InputBoxWidgetSpec, top::Int)
  height = widget.multiline ? 72 : 34
  NetLogo.InputBoxWidgetSpec(540, top, 860, top + height, widget.variable, widget.value, widget.multiline, widget.value_kind)
end

parameter_widget_gap(::NetLogo.InterfaceWidgetSpec) = 8

function extract_source_interface_metadata(source_path::AbstractString)
  source = read(source_path, String)
  interface_source = String(NetLogoCompare.nlogo_section(source, 2))
  model = NetLogo.ModelSpec("")
  NetLogo.parse_interface_widgets!(model, interface_source)
  widgets = filter(is_parameter_widget, model.interface_widgets)
  defaults = copy(model.interface_globals)
  (; widgets, defaults)
end

function source_interface_metadata(benchmark_model)
  model_key = benchmark_model_key(benchmark_model)
  source_path = lookup_original_model_path(model_key, benchmark_model)
  source_path === nothing && return nothing
  if haskey(SOURCE_INTERFACE_CACHE, source_path)
    return SOURCE_INTERFACE_CACHE[source_path]
  end
  metadata =
    try
      extract_source_interface_metadata(source_path)
    catch
      nothing
    end
  SOURCE_INTERFACE_CACHE[source_path] = metadata
  metadata
end

function source_parameter_defaults(compiled::NetLogo.ModelSpec, benchmark_model)
  metadata = source_interface_metadata(benchmark_model)
  metadata === nothing && return Dict{String, Any}()
  allowed = Set(compiled.globals)
  Dict(
    key => value for (key, value) in metadata.defaults
    if key in allowed && key != "RANDOMSEED"
  )
end

function source_parameter_widgets(compiled::NetLogo.ModelSpec, benchmark_model)
  metadata = source_interface_metadata(benchmark_model)
  metadata === nothing && return NetLogo.InterfaceWidgetSpec[]
  allowed = Set(compiled.globals)
  widgets = NetLogo.InterfaceWidgetSpec[]
  top = 128
  for widget in metadata.widgets
    name = parameter_widget_global_name(widget)
    name === nothing && continue
    key = NetLogo.canonical_name(name)
    key in allowed || continue
    key == "RANDOMSEED" && continue
    reflowed = relayout_parameter_widget(widget, top)
    push!(widgets, reflowed)
    top = reflowed.bottom + parameter_widget_gap(reflowed)
  end
  widgets
end

function strip_setup_parameter_assignments(source::AbstractString, parameter_globals::Set{String})
  isempty(parameter_globals) && return String(source)
  match_obj = match(r"(?ms)(^to\s+setup\b[^\n]*\n)(.*?)(^end\b)", String(source))
  match_obj === nothing && return String(source)

  header, body, footer = match_obj.captures
  kept_lines = String[]
  changed = false
  for line in split(body, '\n'; keepempty=true)
    stripped = strip(line)
    indent = something(findfirst(c -> !isspace(c), line), lastindex(line) + 1) - 1
    assign_match = match(r"^set\s+([A-Za-z0-9_?\-]+)\b", stripped)
    if indent <= 2 && assign_match !== nothing && NetLogo.canonical_name(only(assign_match.captures)) in parameter_globals
      changed = true
      continue
    end
    push!(kept_lines, line)
  end
  changed || return String(source)
  replacement_body = join(kept_lines, "\n")
  replacement = header * replacement_body * (endswith(replacement_body, "\n") || isempty(replacement_body) ? "" : "\n") * footer
  replace(String(source), match_obj.match => replacement)
end

function benchmark_runtime_kwargs(benchmark_model)
  min_px, max_px, min_py, max_py = NetLogoCompare.world_dims(benchmark_model)
  (
    min_pxcor=min_px,
    max_pxcor=max_px,
    min_pycor=min_py,
    max_pycor=max_py,
    topology=NetLogoCompare.runtime_topology_mode(NetLogo, benchmark_model),
  )
end

function view_patch_size(benchmark_model)
  min_px, max_px, min_py, max_py = NetLogoCompare.world_dims(benchmark_model)
  width = max_px - min_px + 1
  height = max_py - min_py + 1
  base = floor(480 / max(width, height))
  clamp(Float64(base), 8.0, 14.0)
end

function standard_plot_spec(benchmark_model)
  tracked = NetLogoCompare.tracked_globals(benchmark_model)
  pens = NetLogo.PlotPenSpec[
    NetLogo.PlotPenSpec(
      prettify_global_name(global_name),
      STANDARD_PEN_COLORS[mod1(index, length(STANDARD_PEN_COLORS))],
      1.0,
      0,
      true,
      "",
      "plot $(global_name)",
    ) for (index, global_name) in enumerate(tracked)
  ]
  NetLogo.PlotSpec(
    "Tracked Globals",
    "Ticks",
    "Value",
    0.0,
    Float64(max(10, NetLogoCompare.n_ticks(benchmark_model))),
    0.0,
    1.0,
    true,
    true,
    true,
    "",
    "",
    pens,
  )
end

function standard_widgets(compiled::NetLogo.ModelSpec, benchmark_model)
  tracked = NetLogoCompare.tracked_globals(benchmark_model)
  controls = parameter_widgets(compiled, benchmark_model)
  monitor_top = isempty(controls) ? 132 : maximum(widget.bottom for widget in controls) + 24
  widgets = NetLogo.InterfaceWidgetSpec[
    NetLogo.TextBoxWidgetSpec(12, 12, 520, 48, NetLogoCompare.model_name(benchmark_model), 18, 0.0, true),
    NetLogo.ButtonWidgetSpec(540, 24, 640, 56, "setup", NetLogoCompare.setup_command(benchmark_model), false, "OBSERVER", nothing, false),
    NetLogo.ButtonWidgetSpec(650, 24, 760, 56, "go once", go_button_source(benchmark_model), false, "OBSERVER", nothing, true),
    NetLogo.ButtonWidgetSpec(770, 24, 860, 56, "go", go_button_source(benchmark_model), true, "OBSERVER", nothing, true),
    NetLogo.MonitorWidgetSpec(540, 80, 655, 120, "Ticks", "ticks", 0, 11),
  ]
  append!(widgets, controls)
  for (index, global_name) in enumerate(tracked)
    top = monitor_top + (index - 1) * 54
    push!(
      widgets,
      NetLogo.MonitorWidgetSpec(
        540,
        top,
        775,
        top + 40,
        prettify_global_name(global_name),
        global_name,
        0,
        11,
      ),
    )
  end
  output_top = monitor_top + length(tracked) * 54 + 24
  push!(widgets, NetLogo.OutputWidgetSpec(540, output_top, 860, output_top + 110, 11))
  widgets
end

fallback_parameter_widgets(::NetLogoCompare.AbstractBenchmarkModel) = NetLogo.InterfaceWidgetSpec[]
go_button_source(benchmark_model) = NetLogoCompare.go_command(benchmark_model)

function fallback_parameter_widgets(::NetLogoCompare.SIRModel)
  specs = [
    ("Population", "population", 25.0, 500.0, 25.0, 200.0),
    ("Initial infected", "initial-infected", 1.0, 100.0, 1.0, 5.0),
    ("Initial recovered", "initial-recovered", 0.0, 100.0, 1.0, 0.0),
    ("Infection probability", "infection-probability", 0.01, 1.0, 0.01, 0.15),
    ("Infection radius", "infection-radius", 0.5, 5.0, 0.1, 1.5),
    ("Recovery days", "recovery-days", 1.0, 30.0, 1.0, 14.0),
    ("Movement step", "movement-step", 0.0, 3.0, 0.1, 1.0),
    ("Turn range", "turn-range", 0.0, 90.0, 1.0, 25.0),
  ]
  widgets = NetLogo.InterfaceWidgetSpec[]
  for (index, (display, variable, minimum, maximum, step, default)) in enumerate(specs)
    top = 128 + (index - 1) * 42
    push!(
      widgets,
      NetLogo.SliderWidgetSpec(
        540,
        top,
        860,
        top + 34,
        display,
        variable,
        string(minimum),
        string(maximum),
        default,
        string(step),
        "",
        "HORIZONTAL",
      ),
    )
  end
  widgets
end

function parameter_widgets(compiled::NetLogo.ModelSpec, benchmark_model)
  widgets = source_parameter_widgets(compiled, benchmark_model)
  isempty(widgets) ? fallback_parameter_widgets(benchmark_model) : widgets
end

function fallback_interface_globals(::NetLogoCompare.AbstractBenchmarkModel)
  Dict{String, Any}()
end

function fallback_interface_globals(::NetLogoCompare.SIRModel)
  copy(SIR_DEFAULTS)
end

function apply_default_interface_globals!(compiled::NetLogo.ModelSpec, benchmark_model)
  merge!(compiled.interface_globals, source_parameter_defaults(compiled, benchmark_model))
  merge!(compiled.interface_globals, fallback_interface_globals(benchmark_model))
  compiled
end

function apply_model_shapes!(compiled::NetLogo.ModelSpec, benchmark_model)
  compiled.turtle_shapes_text = NetLogoCompare.turtle_shapes_text(benchmark_model)
  compiled
end

function synthesize_standard_interface!(compiled::NetLogo.ModelSpec, benchmark_model)
  kwargs = benchmark_runtime_kwargs(benchmark_model)
  compiled.view_widget = NetLogo.ViewWidgetSpec(
    12,
    60,
    520,
    568,
    view_patch_size(benchmark_model),
    12,
    kwargs.topology == NetLogo.Torus || kwargs.topology == NetLogo.VerticalCylinder,
    kwargs.topology == NetLogo.Torus || kwargs.topology == NetLogo.HorizontalCylinder,
    kwargs.min_pxcor,
    kwargs.max_pxcor,
    kwargs.min_pycor,
    kwargs.max_pycor,
    true,
    "ticks",
    30.0,
  )
  empty!(compiled.interface_widgets)
  append!(compiled.interface_widgets, standard_widgets(compiled, benchmark_model))
  empty!(compiled.plots)
  push!(compiled.plots, standard_plot_spec(benchmark_model))
  apply_model_shapes!(compiled, benchmark_model)
  apply_default_interface_globals!(compiled, benchmark_model)
  compiled.has_interface_section = true
  compiled
end

function benchmark_workspace(benchmark_model)
  dir = mktempdir(prefix="netlogo-vignette-")
  NetLogoCompare.setup_files(benchmark_model, dir)
  dir
end

function benchmark_runtime(benchmark_model; seed::Integer=1, workspace_dir::Union{Nothing, AbstractString}=nothing)
  compiled = if benchmark_model isa NetLogoCompare.FileBenchmarkModel
    NetLogo.compile_model(
      NetLogoCompare.full_nlogo_source(benchmark_model);
      source_path=NetLogoCompare.nlogo_path(benchmark_model),
    )
  else
    parameter_globals = Set{String}(keys(source_interface_metadata(benchmark_model) === nothing ? Dict{String, Any}() : source_interface_metadata(benchmark_model).defaults))
    delete!(parameter_globals, "RANDOMSEED")
    NetLogo.compile_model(strip_setup_parameter_assignments(NetLogoCompare.netlogo_code(benchmark_model), parameter_globals))
  end
  synthesize_standard_interface!(compiled, benchmark_model)
  runtime = NetLogo.create_runtime(
    compiled;
    seed=seed,
    model_directory=workspace_dir,
    benchmark_runtime_kwargs(benchmark_model)...,
  )
  pre_setup = strip(NetLogoCompare.pre_setup_commands(benchmark_model))
  isempty(pre_setup) || NetLogo.run_commands!(runtime, pre_setup)
  NetLogo.run_commands!(runtime, "random-seed $seed")
  runtime
end

function benchmark_backend(
  name::Symbol;
  seed::Integer=1,
  host::AbstractString="127.0.0.1",
  port::Union{Nothing, Integer}=nothing,
  width::Integer=1280,
  height::Integer=980,
)
  benchmark = benchmark_model(name)
  workspace_dir = benchmark_workspace(benchmark)
  runtime = benchmark_runtime(benchmark; seed=seed, workspace_dir=workspace_dir)
  session = NetLogo.gui_session(runtime)
  chosen_port = port === nothing ? free_local_port() : Int(port)
  backend = NetLogo.start_web_gui(session; host=host, port=chosen_port)
  notebook = NetLogo.notebook_gui(backend; width=width, height=height, title=NetLogoCompare.model_name(benchmark))
  (; benchmark, runtime, session, backend, notebook, port=chosen_port, workspace_dir)
end

function close_bundle!(bundle)
  try
    NetLogo.stop_web_gui!(bundle.backend)
  catch
  end
  if hasproperty(bundle, :workspace_dir)
    dir = getproperty(bundle, :workspace_dir)
    dir isa AbstractString && isdir(dir) && rm(dir; recursive=true, force=true)
  end
  nothing
end

end
