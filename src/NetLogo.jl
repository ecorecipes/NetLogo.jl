"""
    NetLogo

Headless-first, clean-room Julia implementation of the NetLogo language and runtime.
"""
module NetLogo

using Colors
using Dates
using EzXML
using FileIO
using Random
using Serialization
using ImageIO
using JSON

include("Source.jl")
include("Syntax.jl")
include("Model.jl")
include("Parser.jl")
include("SystemDynamics.jl")
include("Runtime.jl")
include("ExtCsv.jl")
include("ExtTable.jl")
include("ExtNw.jl")
include("ExtProfiler.jl")
include("ExtSound.jl")
include("ExtGis.jl")
include("ExtArray.jl")
include("ExtLevelSpace.jl")
include("ExtBitmap.jl")
include("ExtFp.jl")
include("ExtMatrix.jl")
include("ExtStore.jl")
include("ExtRnd.jl")
include("ExtTime.jl")
include("ExtBitstring.jl")
include("GUI.jl")

@doc raw"""
    SourceSpan

Source-location range used for parser diagnostics and error reporting.
""" SourceSpan

@doc raw"""
    Diagnostic

Parser or static-analysis error annotated with a `SourceSpan`.
""" Diagnostic

@doc raw"""
    TokenKind

Enumeration of lexical token categories produced by [`tokenize`](@ref).
""" TokenKind

@doc raw"""
    Token

Lexical token with kind, original lexeme, parsed value, and source span.
""" Token

@doc raw"""
    BlockNode

AST node representing a command block in parsed NetLogo source.
""" BlockNode

@doc raw"""
    ProcedureSpec

Parsed procedure definition, including its inputs, body, and source span.
""" ProcedureSpec

@doc raw"""
    ModelSpec

Parsed model representation containing declarations, procedures, widgets, plots, and metadata.
""" ModelSpec

@doc raw"""
    CompiledModel

Alias for [`ModelSpec`](@ref), retained as the compiled-model API surface.
""" CompiledModel

@doc raw"""
    LogoRuntimeError

Runtime exception type raised for NetLogo execution errors.
""" LogoRuntimeError

@doc raw"""
    AgentKind

Enumeration of NetLogo agent categories: observer, turtle, patch, and link.
""" AgentKind

@doc raw"""
    Observer

Observer agent value that owns the global variable map for a running model.
""" Observer

@doc raw"""
    Turtle

Concrete turtle agent record used by the runtime world state.
""" Turtle

@doc raw"""
    Patch

Concrete patch agent record used by the runtime world state.
""" Patch

@doc raw"""
    Link

Concrete link agent record used by the runtime world state.
""" Link

@doc raw"""
    AgentSet

Typed collection of live NetLogo agents, with optional breed and dynamic-world metadata.
""" AgentSet

@doc raw"""
    TopologyMode

Enumeration of supported 2D world topologies.
""" TopologyMode

@doc raw"""
    Torus

Topology mode that wraps on both axes.
""" Torus

@doc raw"""
    VerticalCylinder

Topology mode that wraps on the x-axis but not the y-axis.
""" VerticalCylinder

@doc raw"""
    HorizontalCylinder

Topology mode that wraps on the y-axis but not the x-axis.
""" HorizontalCylinder

@doc raw"""
    BoxTopology

Topology mode that does not wrap on either axis.
""" BoxTopology

@doc raw"""
    RuntimeState

Mutable runtime container holding the compiled model, world state, primitive registry, files, plots, and output buffers.
""" RuntimeState

@doc raw"""
    Context

Execution context for evaluating procedures and blocks against a specific current agent.
""" Context

@doc raw"""
    tokenize(source)

Tokenize NetLogo source text into a vector of source-spanned lexical tokens.
""" tokenize

@doc raw"""
    parse_model(source; source_path=nothing, extension_host=Main)

Parse NetLogo source into a [`ModelSpec`](@ref), resolving declarations, procedures, widgets, includes, and extension metadata.

Set `source_path` when parsing file-backed models so relative `__includes` paths are resolved correctly.
""" parse_model

@doc raw"""
    compile_model(source; source_path=nothing, extension_host=Main)
    compile_model(model::ModelSpec; source_path=nothing)

Compile NetLogo source into a [`CompiledModel`](@ref). Passing an existing `ModelSpec` returns it unchanged for API symmetry.
""" compile_model

@doc raw"""
    load_model(path; extension_host=Main)

Read a `.nlogo` model from disk, resolve its includes relative to `path`, and compile it into a [`CompiledModel`](@ref).
""" load_model

@doc raw"""
    create_runtime(model; extension_host=Main, kwargs...)

Create a fresh executable runtime for a compiled model. Keyword arguments are forwarded to the world/runtime constructor, including common options such as `seed`, topology overrides, and world bounds.
""" create_runtime

@doc raw"""
    call!(runtime, procedure_name, args...)

Invoke a NetLogo procedure by name against an existing runtime.
""" call!

@doc raw"""
    load_turtle_shapes!(runtime, text)

Parse upstream NetLogo turtle-shape text and register the resulting custom shapes into a runtime.
""" load_turtle_shapes!

@doc raw"""
    parse_turtle_shapes_text(text)

Parse the upstream turtle-shape text format into the internal shape representation used by headless rendering.
""" parse_turtle_shapes_text

@doc raw"""
    register_primitive!(registry, name, kind, syntax, evaluator)

Register a primitive implementation in a primitive registry. This is the low-level hook used by built-in and external extensions.
""" register_primitive!

@doc raw"""
    netlogo"..."

Compile NetLogo source embedded in a Julia string literal.
""" var"@netlogo_str"

export AgentKind,
  AgentSet,
  BlockNode,
  BoxTopology,
  CompiledModel,
  Context,
  Diagnostic,
  GUISession,
  HorizontalCylinder,
  Link,
  LogoRuntimeError,
  ModelSpec,
  NotebookGUI,
  Observer,
  Patch,
  ProcedureSpec,
  RuntimeState,
  SourceSpan,
  Token,
  TokenKind,
  TopologyMode,
  Torus,
  Turtle,
  VerticalCylinder,
  WebGUIBackend,
  call!,
  compile_model,
  create_runtime,
  gui_session,
  gui_state,
  load_model,
  load_turtle_shapes!,
  notebook_gui,
  parse_model,
  parse_turtle_shapes_text,
  pluto_gui,
  press_gui_button!,
  register_primitive!,
  run_commands!,
  runresult,
  set_gui_widget!,
  start_web_gui,
  stop_web_gui!,
  tokenize,
  web_gui_url,
  @netlogo_str

compile_model(model::ModelSpec; source_path::Union{Nothing, AbstractString}=nothing) = model
function compile_model(
  source::AbstractString;
  source_path::Union{Nothing, AbstractString}=nothing,
  extension_host::Module=Main)
  compile_model(parse_model(source; source_path=source_path, extension_host=extension_host))
end

function load_model(path::AbstractString; extension_host::Module=Main)
  resolved = resolve_file_path(path)
  isfile(resolved) || throw(LogoRuntimeError("The file $(resolved) cannot be found"))
  compile_model(read(resolved, String); source_path=resolved, extension_host=extension_host)
end

function parse_model(
  source::AbstractString;
  source_path::Union{Nothing, AbstractString}=nothing,
  extension_host::Module=Main)
  parse_model(String(source), build_default_registry(); source_path=source_path, extension_host=extension_host)
end

function create_runtime(model::ModelSpec; extension_host::Module=Main, kwargs...)
  registry = build_default_registry()
  load_extensions!(registry, model.extensions; host_module=extension_host)
  create_runtime(model, registry; kwargs...)
end

function call!(runtime::RuntimeState, procedure_name::AbstractString, args...)
  call!(runtime, procedure_name, Any[args...])
end

"""
    runresult(runtime, expr_string)

Evaluate a NetLogo reporter expression string and return the result.
"""
function runresult(runtime::RuntimeState, source::AbstractString)
  ctx = Context(runtime, runtime.world.observer, EMPTY_SCOPE_STACK, nothing, false, 1, EMPTY_EVERY_STATE)
  runresult_string(ctx, source)
end

"""
    run_commands!(runtime, command_string)

Compile and execute an arbitrary NetLogo command string (one or more statements)
in the observer context. This is the command analogue of `runresult`.
"""
function run_commands!(runtime::RuntimeState, source::AbstractString)
  ctx = Context(runtime, runtime.world.observer, EMPTY_SCOPE_STACK, nothing, false, 1, EMPTY_EVERY_STATE)
  run_string!(ctx, source)
  nothing
end

macro netlogo_str(source)
  :(NetLogo.compile_model($source))
end

end
