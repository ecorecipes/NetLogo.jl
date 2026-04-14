const VoidType = 0
const NumberType = 1
const BooleanType = 2
const StringType = 4
const ListType = 8
const TurtlesetType = 16
const PatchsetType = 32
const LinksetType = 64
const AgentsetType = TurtlesetType | PatchsetType | LinksetType
const NobodyType = 128
const TurtleType = 256
const PatchType = 512
const LinkType = 1024
const CommandType = 2048
const ReporterType = 4096
const AgentType = TurtleType | PatchType | LinkType
const WildcardType = NumberType | BooleanType | StringType | ListType | AgentType | AgentsetType | NobodyType | CommandType | ReporterType
const ReferenceType = 8192
const CommandBlockType = 16384
const BooleanBlockType = 32768
const NumberBlockType = 65536
const OtherBlockType = 131072
const ReporterBlockType = BooleanBlockType | NumberBlockType | OtherBlockType
const RepeatableType = 262144
const OptionalType = 524288
const CodeBlockType = 1048576
const SymbolType = 2097152

const CommandPrecedence = 0
const BooleanPrecedence = 10
const OrPrecedence = BooleanPrecedence
const AndPrecedence = BooleanPrecedence
const XorPrecedence = BooleanPrecedence
const ComparePrecedence = 30
const AddPrecedence = 40
const MultiplyPrecedence = 50
const PowerPrecedence = 55
const PrefixPrecedence = 60
const OfPrecedence = 70
const WhoAreNotPrecedence = 75
const WithPrecedence = 80
const NormalPrecedence = PrefixPrecedence

@enum PrimitiveKind COMMAND REPORTER

struct PrimitiveSyntax
  left::Int
  right::Vector{Int}
  ret::Int
  precedence::Int
  agent_classes::String
  arg_modes::Vector{Symbol}
  introduces_context::Bool
  default_count::Int  # number of args to consume in non-parenthesized form (-1 = no limit)
end

function command_syntax(;
  right::Vector{Int}=Int[],
  precedence::Int=CommandPrecedence,
  agent_classes::String="OTPL",
  arg_modes::Vector{Symbol}=fill(:eval, length(right)),
  introduces_context::Bool=false,
  default_count::Int=-1)
  PrimitiveSyntax(VoidType, right, VoidType, precedence, agent_classes, arg_modes, introduces_context,
    default_count)
end

function reporter_syntax(;
  left::Int=VoidType,
  right::Vector{Int}=Int[],
  ret::Int=WildcardType,
  precedence::Int=NormalPrecedence,
  agent_classes::String="OTPL",
  arg_modes::Vector{Symbol}=fill(:eval, length(right)),
  default_count::Int=-1)
  PrimitiveSyntax(left, right, ret, precedence, agent_classes, arg_modes, false,
    default_count)
end

function primitive_modes(syntax::PrimitiveSyntax)
  modes = Symbol[]
  if syntax.left != VoidType
    push!(modes, effective_arg_mode(syntax.left, :eval))
  end
  for (index, mask) in enumerate(syntax.right)
    fallback = index <= length(syntax.arg_modes) ? syntax.arg_modes[index] : :eval
    push!(modes, effective_arg_mode(mask, fallback))
  end
  modes
end

mutable struct PrimitiveSpec
  name::String
  kind::PrimitiveKind
  syntax::PrimitiveSyntax
  evaluator::Function
  modes::Vector{Symbol}
  all_eval_modes::Bool
end

PrimitiveSpec(
  name::String,
  kind::PrimitiveKind,
  syntax::PrimitiveSyntax,
  evaluator::Function) =
  let modes = primitive_modes(syntax)
    PrimitiveSpec(name, kind, syntax, evaluator, modes, all(mode -> mode == :eval, modes))
  end

mutable struct PrimitiveRegistry
  commands::Dict{String, PrimitiveSpec}
  reporters::Dict{String, PrimitiveSpec}
end

PrimitiveRegistry() = PrimitiveRegistry(Dict{String, PrimitiveSpec}(), Dict{String, PrimitiveSpec}())

canonical_name(name::AbstractString) = uppercase(String(name))
compatible(mask::Int, value::Int) = (mask & value) != 0
strip_flags(mask::Int) = mask & ~(OptionalType | RepeatableType)
is_optional(mask::Int) = compatible(mask, OptionalType)
is_repeatable(mask::Int) = compatible(mask, RepeatableType)

const EXTENSION_REGISTER_HOOKS = (:register_extension!, :register_primitives!)

function is_module_identifier(name::AbstractString)
  text = String(name)
  isempty(text) && return false
  first_char = first(text)
  (isletter(first_char) || first_char == '_') || return false
  all(c -> isletter(c) || isnumeric(c) || c == '_', text)
end

function extension_name_candidates(name::AbstractString)
  raw = strip(String(name))
  isempty(raw) && return Symbol[]

  candidates = Symbol[]
  function add_candidate(text::AbstractString)
    is_module_identifier(text) || return
    symbol = Symbol(text)
    symbol in candidates || push!(candidates, symbol)
  end

  add_candidate(raw)
  add_candidate(lowercase(raw))
  add_candidate(uppercase(raw))

  parts = filter(!isempty, split(raw, r"[^A-Za-z0-9_]+"))
  if !isempty(parts)
    add_candidate(join(uppercasefirst(lowercase(part)) for part in parts))
  end

  candidates
end

function lookup_extension_module(candidate::Symbol, host_module::Module)
  for module_ref in (host_module, @__MODULE__)
    if isdefined(module_ref, candidate)
      value = getfield(module_ref, candidate)
      value isa Module && return value
    end
  end
  nothing
end

function resolve_extension_module(name::AbstractString; host_module::Module=Main)
  for candidate in extension_name_candidates(name)
    module_ref = lookup_extension_module(candidate, host_module)
    module_ref !== nothing && return module_ref
    try
      Core.eval(host_module, Expr(:import, candidate))
    catch err
      err isa InterruptException && rethrow()
    end
    module_ref = lookup_extension_module(candidate, host_module)
    module_ref !== nothing && return module_ref
  end
  nothing
end

function extension_register_hook(module_ref::Module)
  for hook_name in EXTENSION_REGISTER_HOOKS
    if isdefined(module_ref, hook_name)
      hook = getfield(module_ref, hook_name)
      hook isa Function && return hook
    end
  end
  nothing
end

function throw_extension_load_error(message::AbstractString, span::Union{Nothing, SourceSpan}=nothing)
  text = String(message)
  if span === nothing
    throw(LogoRuntimeError(text))
  else
    throw(Diagnostic(text, span))
  end
end

function load_extension!(
  registry::PrimitiveRegistry,
  extension_name::AbstractString;
  host_module::Module=Main,
  span::Union{Nothing, SourceSpan}=nothing)
  module_ref = resolve_extension_module(extension_name; host_module=host_module)
  module_ref === nothing &&
    throw_extension_load_error("Could not load extension $(extension_name)", span)

  hook = extension_register_hook(module_ref)
  hook === nothing &&
    throw_extension_load_error(
      "Extension $(extension_name) must define register_extension! or register_primitives!",
      span)

  hook(registry)
  registry
end

function load_extensions!(
  registry::PrimitiveRegistry,
  extension_names::AbstractVector{<:AbstractString};
  host_module::Module=Main)
  seen = Set{String}()
  for extension_name in extension_names
    key = canonical_name(extension_name)
    key in seen && continue
    push!(seen, key)
    load_extension!(registry, extension_name; host_module=host_module)
  end
  registry
end

function load_extensions!(
  registry::PrimitiveRegistry,
  extension_specs::AbstractVector{<:Pair};
  host_module::Module=Main)
  seen = Set{String}()
  for spec in extension_specs
    extension_name = String(first(spec))
    key = canonical_name(extension_name)
    key in seen && continue
    push!(seen, key)
    load_extension!(registry, extension_name; host_module=host_module, span=last(spec))
  end
  registry
end

function effective_arg_mode(mask::Int, fallback::Symbol=:eval)
  if compatible(mask, ReporterBlockType)
    :reporter_block
  elseif compatible(mask, CodeBlockType)
    :code_block
  elseif compatible(mask, CommandBlockType)
    :block
  elseif compatible(mask, SymbolType)
    :symbol
  else
    fallback
  end
end

function register_primitive!(
  registry::PrimitiveRegistry,
  name::AbstractString,
  kind::PrimitiveKind,
  syntax::PrimitiveSyntax,
  evaluator::Function)
  spec = PrimitiveSpec(canonical_name(name), kind, syntax, evaluator)
  if kind == COMMAND
    registry.commands[spec.name] = spec
  else
    registry.reporters[spec.name] = spec
  end
  spec
end

get_command(registry::PrimitiveRegistry, name::AbstractString) =
  get(registry.commands, name, nothing)

get_reporter(registry::PrimitiveRegistry, name::AbstractString) =
  get(registry.reporters, name, nothing)
