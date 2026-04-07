module ls

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType, CommandBlockType, ReporterBlockType,
  LogoRuntimeError, logo_string, Context,
  RuntimeState, CompiledModel, ModelSpec,
  run_string!, runresult_string,
  resolve_file_path, netlogo_random_seed,
  OfPrecedence

using Random: MersenneTwister

# compile_model, load_model, and create_runtime are defined later in NetLogo.jl
# (after extension includes), so we access them through the parent module at runtime.
const _parent = parentmodule(@__MODULE__)
_compile_model(args...; kw...) = _parent.compile_model(args...; kw...)
_create_runtime(args...; kw...) = _parent.create_runtime(args...; kw...)
_load_model(args...; kw...)    = _parent.load_model(args...; kw...)

mutable struct ChildModel
  id::Int
  runtime::RuntimeState
  name::String
  path::String
end

# ---------------------------------------------------------------------------
# Per-parent storage helpers – kept in the parent observer's globals dict
# under reserved keys so they persist across ticks.
# ---------------------------------------------------------------------------

function _get_models(ctx::Context)::Dict{Int, ChildModel}
  g = ctx.runtime.world.observer.globals
  get!(g, "__LS_MODELS") do
    Dict{Int, ChildModel}()
  end
end

function _next_id!(ctx::Context)::Int
  g = ctx.runtime.world.observer.globals
  id = get(g, "__LS_NEXT_ID", 0)
  g["__LS_NEXT_ID"] = id + 1
  id
end

function _get_model(ctx::Context, id)::ChildModel
  models = _get_models(ctx)
  model_id = round(Int, id)
  haskey(models, model_id) || throw(LogoRuntimeError("ls: model $model_id does not exist"))
  models[model_id]
end

function _resolve_ids(id_or_list)::Vector{Int}
  if id_or_list isa AbstractVector
    [round(Int, x) for x in id_or_list]
  else
    [round(Int, id_or_list)]
  end
end

# ---------------------------------------------------------------------------
# Child-model code execution helpers
# ---------------------------------------------------------------------------

function _child_run!(child_runtime::RuntimeState, code::AbstractString)
  root = Context(child_runtime, child_runtime.world.observer,
    [Dict{String, Any}()], nothing, false, 1)
  run_string!(root, code)
  nothing
end

function _child_report(child_runtime::RuntimeState, code::AbstractString)
  root = Context(child_runtime, child_runtime.world.observer,
    [Dict{String, Any}()], nothing, false, 1)
  runresult_string(root, code)
end

# ---------------------------------------------------------------------------
# Primitive registration
# ---------------------------------------------------------------------------

function register_extension!(registry::PrimitiveRegistry)

  # ===== Model Management =================================================

  # ls:create-models count path
  register_primitive!(registry, "LS:CREATE-MODELS", COMMAND,
    command_syntax(right=[NumberType, StringType]),
    (ctx, args) -> begin
      count = round(Int, args[1])
      path = String(args[2])
      resolved = resolve_file_path(path)
      isfile(resolved) || throw(LogoRuntimeError(
        "ls:create-models: file not found: $resolved"))
      source = read(resolved, String)
      models = _get_models(ctx)
      for _ in 1:count
        id = _next_id!(ctx)
        model = _compile_model(source; source_path=resolved)
        runtime = _create_runtime(model)
        models[id] = ChildModel(id, runtime, basename(resolved), resolved)
      end
      nothing
    end)

  # ls:create-interactive-models – identical to create-models (no GUI)
  register_primitive!(registry, "LS:CREATE-INTERACTIVE-MODELS", COMMAND,
    command_syntax(right=[NumberType, StringType]),
    (ctx, args) -> begin
      count = round(Int, args[1])
      path = String(args[2])
      resolved = resolve_file_path(path)
      isfile(resolved) || throw(LogoRuntimeError(
        "ls:create-interactive-models: file not found: $resolved"))
      source = read(resolved, String)
      models = _get_models(ctx)
      for _ in 1:count
        id = _next_id!(ctx)
        model = _compile_model(source; source_path=resolved)
        runtime = _create_runtime(model)
        models[id] = ChildModel(id, runtime, basename(resolved), resolved)
      end
      nothing
    end)

  # ls:models – report sorted list of all model IDs
  register_primitive!(registry, "LS:MODELS", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> begin
      Any[Float64(k) for k in sort(collect(keys(_get_models(ctx))))]
    end)

  # ls:model-exists?
  register_primitive!(registry, "LS:MODEL-EXISTS?", REPORTER,
    reporter_syntax(right=[NumberType], ret=BooleanType),
    (ctx, args) -> haskey(_get_models(ctx), round(Int, args[1])))

  # ls:close model-id-or-list
  register_primitive!(registry, "LS:CLOSE", COMMAND,
    command_syntax(right=[WildcardType]),
    (ctx, args) -> begin
      models = _get_models(ctx)
      for id in _resolve_ids(args[1])
        haskey(models, id) || throw(LogoRuntimeError(
          "ls:close: model $id does not exist"))
        delete!(models, id)
      end
      nothing
    end)

  # ls:reset – close all child models
  register_primitive!(registry, "LS:RESET", COMMAND,
    command_syntax(),
    (ctx, args) -> begin
      models = _get_models(ctx)
      empty!(models)
      ctx.runtime.world.observer.globals["__LS_NEXT_ID"] = 0
      nothing
    end)

  # ===== Model Interaction =================================================

  # ls:ask model-id-or-list command-string
  register_primitive!(registry, "LS:ASK", COMMAND,
    command_syntax(right=[WildcardType, StringType]),
    (ctx, args) -> begin
      ids = _resolve_ids(args[1])
      code = String(args[2])
      for id in ids
        cm = _get_model(ctx, id)
        _child_run!(cm.runtime, code)
      end
      nothing
    end)

  # ls:of  –  "reporter-string" ls:of model-id-or-list
  register_primitive!(registry, "LS:OF", REPORTER,
    reporter_syntax(left=StringType, right=[WildcardType],
      ret=WildcardType, precedence=OfPrecedence),
    (ctx, args) -> begin
      code = String(args[1])
      ids = _resolve_ids(args[2])
      if length(ids) == 1
        _child_report(_get_model(ctx, ids[1]).runtime, code)
      else
        Any[_child_report(_get_model(ctx, id).runtime, code) for id in ids]
      end
    end)

  # ls:report model-id reporter-string
  register_primitive!(registry, "LS:REPORT", REPORTER,
    reporter_syntax(right=[WildcardType, StringType], ret=WildcardType),
    (ctx, args) -> begin
      ids = _resolve_ids(args[1])
      code = String(args[2])
      if length(ids) == 1
        _child_report(_get_model(ctx, ids[1]).runtime, code)
      else
        Any[_child_report(_get_model(ctx, id).runtime, code) for id in ids]
      end
    end)

  # ls:let var-name value  (sets a local in the current scope)
  register_primitive!(registry, "LS:LET", COMMAND,
    command_syntax(right=[StringType, WildcardType]),
    (ctx, args) -> begin
      varname = uppercase(String(args[1]))
      isempty(ctx.locals) && push!(ctx.locals, Dict{String, Any}())
      ctx.locals[end][varname] = args[2]
      nothing
    end)

  # ls:assign model-id global-name value
  register_primitive!(registry, "LS:ASSIGN", COMMAND,
    command_syntax(right=[WildcardType, StringType, WildcardType]),
    (ctx, args) -> begin
      ids = _resolve_ids(args[1])
      varname = uppercase(String(args[2]))
      value = args[3]
      for id in ids
        cm = _get_model(ctx, id)
        cm.runtime.world.observer.globals[varname] = value
      end
      nothing
    end)

  # ===== Model Properties ==================================================

  # ls:name-of model-id
  register_primitive!(registry, "LS:NAME-OF", REPORTER,
    reporter_syntax(right=[NumberType], ret=StringType),
    (ctx, args) -> _get_model(ctx, args[1]).name)

  # ls:set-name model-id name
  register_primitive!(registry, "LS:SET-NAME", COMMAND,
    command_syntax(right=[NumberType, StringType]),
    (ctx, args) -> begin
      _get_model(ctx, args[1]).name = String(args[2])
      nothing
    end)

  # ls:path-of model-id
  register_primitive!(registry, "LS:PATH-OF", REPORTER,
    reporter_syntax(right=[NumberType], ret=StringType),
    (ctx, args) -> _get_model(ctx, args[1]).path)

  # ls:uses-level-space? model-id
  register_primitive!(registry, "LS:USES-LEVEL-SPACE?", REPORTER,
    reporter_syntax(right=[NumberType], ret=BooleanType),
    (ctx, args) -> begin
      cm = _get_model(ctx, args[1])
      any(ext -> uppercase(String(first(ext))) == "LS",
          cm.runtime.model.extensions)
    end)

  # ls:random-seed model-id seed
  register_primitive!(registry, "LS:RANDOM-SEED", COMMAND,
    command_syntax(right=[NumberType, NumberType]),
    (ctx, args) -> begin
      cm = _get_model(ctx, args[1])
      seed = netlogo_random_seed(args[2])
      cm.runtime.world.rng = MersenneTwister(seed)
      cm.runtime.plot_rng = MersenneTwister(seed)
      nothing
    end)

  # ls:show / ls:hide / ls:show-all / ls:hide-all – NO-OPs in headless
  for name in ("LS:SHOW", "LS:HIDE", "LS:SHOW-ALL", "LS:HIDE-ALL")
    register_primitive!(registry, name, COMMAND,
      command_syntax(right=[WildcardType]),
      (ctx, args) -> nothing)
  end

end # register_extension!

end # module ls
