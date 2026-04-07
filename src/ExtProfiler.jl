module profiler

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, WildcardType, NumberType, CommandBlockType

function register_extension!(registry::PrimitiveRegistry)
  register_primitive!(registry, "PROFILER:START", COMMAND,
    command_syntax(),
    (ctx, args) -> nothing)

  register_primitive!(registry, "PROFILER:STOP", COMMAND,
    command_syntax(),
    (ctx, args) -> nothing)

  register_primitive!(registry, "PROFILER:RESET", COMMAND,
    command_syntax(),
    (ctx, args) -> nothing)

  register_primitive!(registry, "PROFILER:REPORT", REPORTER,
    reporter_syntax(ret=StringType),
    (ctx, args) -> "Profiler not available in headless mode.")

  register_primitive!(registry, "PROFILER:CALLS", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> 0.0)

  register_primitive!(registry, "PROFILER:EXCLUSIVE-TIME", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> 0.0)

  register_primitive!(registry, "PROFILER:INCLUSIVE-TIME", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> 0.0)
end

end # module profiler
