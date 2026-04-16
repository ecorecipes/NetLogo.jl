module NetLogoVignetteSupport

using NetLogo
using Sockets

export benchmark_backend, benchmark_model, benchmark_model_keys, close_bundle!, model_title

const REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const EVAL_MODELS_DIR = joinpath(REPO_ROOT, "eval", "models")
const STANDARD_PEN_COLORS = Float64[55.0, 15.0, 5.0, 105.0, 45.0, 125.0, 85.0, 25.0]
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

benchmark_model_keys() = sort!(collect(keys(MODEL_TYPES)); by=String)

function benchmark_model(name::Union{Symbol, AbstractString})
  key = name isa Symbol ? name : Symbol(String(name))
  type_name = get(MODEL_TYPES, key, nothing)
  type_name === nothing && throw(ArgumentError("No vignette support registered for eval model $(key)."))
  getfield(NetLogoCompare, type_name)()
end

model_title(name::Union{Symbol, AbstractString}) = NetLogoCompare.model_name(benchmark_model(name))

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

function standard_widgets(benchmark_model)
  tracked = NetLogoCompare.tracked_globals(benchmark_model)
  sliders = parameter_widgets(benchmark_model)
  monitor_top = isempty(sliders) ? 132 : maximum(widget.bottom for widget in sliders) + 24
  widgets = NetLogo.InterfaceWidgetSpec[
    NetLogo.TextBoxWidgetSpec(12, 12, 520, 48, NetLogoCompare.model_name(benchmark_model), 18, 0.0, true),
    NetLogo.ButtonWidgetSpec(540, 24, 640, 56, "setup", NetLogoCompare.setup_command(benchmark_model), false, "OBSERVER", nothing, false),
    NetLogo.ButtonWidgetSpec(650, 24, 760, 56, "go once", go_button_source(benchmark_model), false, "OBSERVER", nothing, true),
    NetLogo.ButtonWidgetSpec(770, 24, 860, 56, "go", go_button_source(benchmark_model), true, "OBSERVER", nothing, true),
    NetLogo.MonitorWidgetSpec(540, 80, 655, 120, "Ticks", "ticks", 0, 11),
  ]
  append!(widgets, sliders)
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

parameter_widgets(::NetLogoCompare.AbstractBenchmarkModel) = NetLogo.InterfaceWidgetSpec[]
go_button_source(benchmark_model) = NetLogoCompare.go_command(benchmark_model)

function parameter_widgets(::NetLogoCompare.SIRModel)
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

function apply_default_interface_globals!(compiled::NetLogo.ModelSpec, benchmark_model)
  if benchmark_model isa NetLogoCompare.SIRModel
    merge!(compiled.interface_globals, SIR_DEFAULTS)
  end
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
  append!(compiled.interface_widgets, standard_widgets(benchmark_model))
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
    NetLogo.compile_model(NetLogoCompare.netlogo_code(benchmark_model))
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
