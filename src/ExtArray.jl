module array

import ..NetLogo: logo_string

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  LogoRuntimeError, numeric

# NetLogo arrays are mutable, fixed-size, 0-based indexed collections.
mutable struct LogoArray
  data::Vector{Any}
end

# Pretty-print matching NetLogo's {{array: 1 2 3}} format.
logo_string(a::LogoArray) =
  "{{array: " * join((logo_string(v) for v in a.data), " ") * "}}"

function array_from_list(lst)
  lst isa AbstractVector || throw(LogoRuntimeError("array:from-list expected a list"))
  LogoArray(Any[v for v in lst])
end

function check_index(a::LogoArray, i)
  idx = floor(Int, numeric(i))  # NetLogo 0-based index with standard reporter coercion
  (idx < 0 || idx >= length(a.data)) &&
    throw(LogoRuntimeError("array:item index $idx is out of range [0, $(length(a.data) - 1)]"))
  idx + 1  # convert to Julia 1-based
end

function register_extension!(registry::PrimitiveRegistry)
  register_primitive!(registry, "ARRAY:FROM-LIST", REPORTER,
    reporter_syntax(right=[ListType], ret=WildcardType),
    (ctx, args) -> array_from_list(args[1]))

  register_primitive!(registry, "ARRAY:ITEM", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      args[1] isa LogoArray || throw(LogoRuntimeError("array:item expected an array as the first input"))
      jidx = check_index(args[1], args[2])
      args[1].data[jidx]
    end)

  register_primitive!(registry, "ARRAY:SET", COMMAND,
    command_syntax(right=[WildcardType, NumberType, WildcardType]),
    (ctx, args) -> begin
      args[1] isa LogoArray || throw(LogoRuntimeError("array:set expected an array as the first input"))
      jidx = check_index(args[1], args[2])
      args[1].data[jidx] = args[3]
      nothing
    end)

  register_primitive!(registry, "ARRAY:LENGTH", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      args[1] isa LogoArray || throw(LogoRuntimeError("array:length expected an array as the first input"))
      Float64(length(args[1].data))
    end)

  register_primitive!(registry, "ARRAY:TO-LIST", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      args[1] isa LogoArray || throw(LogoRuntimeError("array:to-list expected an array as the first input"))
      Any[v for v in args[1].data]
    end)
end

end # module array
