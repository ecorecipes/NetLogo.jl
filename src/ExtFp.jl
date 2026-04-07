module fp

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER,
  reporter_syntax,
  ListType, WildcardType, NumberType, ReporterType, RepeatableType,
  PrimitiveSyntax, VoidType, NormalPrecedence,
  LogoRuntimeError,
  AbstractReporterTaskValue, ReporterTaskValue, PrimitiveReporterTaskValue, ProcedureReporterTaskValue,
  coerce_reporter_task, primitive_input_bounds,
  Context

import ..NetLogo: invoke_reporter_task, logo_string

# ── Wrapper types for compose / pipe / curry ──────────────────────────────────

struct ComposedReporterTask <: AbstractReporterTaskValue
  reporters::Vector{AbstractReporterTaskValue}   # execution order (first applied first)
  captured_ctx::Context
end

struct CurriedReporterTask <: AbstractReporterTaskValue
  inner::AbstractReporterTaskValue
  fixed_args::Vector{Any}
  captured_ctx::Context
end

# ── invoke_reporter_task dispatches ───────────────────────────────────────────

function invoke_reporter_task(
  context::Context,
  task::ComposedReporterTask,
  actuals::Vector{Any};
  agent=context.agent,
  caller=context.agent)
  current = invoke_reporter_task(context, task.reporters[1], actuals; agent, caller)
  for i in 2:length(task.reporters)
    current = invoke_reporter_task(context, task.reporters[i], Any[current]; agent, caller)
  end
  current
end

function invoke_reporter_task(
  context::Context,
  task::CurriedReporterTask,
  actuals::Vector{Any};
  agent=context.agent,
  caller=context.agent)
  all_args = Any[task.fixed_args..., actuals...]
  invoke_reporter_task(context, task.inner, all_args; agent, caller)
end

# ── logo_string overloads ─────────────────────────────────────────────────────

logo_string(::ComposedReporterTask) = "(anonymous reporter: fp:composed)"
logo_string(::CurriedReporterTask)  = "(anonymous reporter: fp:curried)"

# ── helpers ───────────────────────────────────────────────────────────────────

function reporter_min_inputs(task::AbstractReporterTaskValue)
  task isa ReporterTaskValue          && return length(task.block.params)
  task isa PrimitiveReporterTaskValue && return first(primitive_input_bounds(task.spec.syntax))
  task isa ProcedureReporterTaskValue && return length(task.procedure.inputs)
  task isa CurriedReporterTask        && return max(0, reporter_min_inputs(task.inner) - length(task.fixed_args))
  task isa ComposedReporterTask       && return reporter_min_inputs(task.reporters[1])
  return 0
end

# ── registration ──────────────────────────────────────────────────────────────

function register_extension!(registry::PrimitiveRegistry)

  # ── fp:take ─────────────────────────────────────────────────────────────────
  # (fp:take n list) → first n items; error if n < 0
  register_primitive!(registry, "FP:TAKE", REPORTER,
    reporter_syntax(right=[NumberType, ListType], ret=ListType),
    (ctx, args) -> begin
      n = Int(floor(args[1]))
      n < 0 && throw(LogoRuntimeError("fp:take: first argument must be a positive number"))
      list = args[2]::AbstractVector
      Any[list[1:min(n, length(list))]...]
    end)

  # ── fp:drop ─────────────────────────────────────────────────────────────────
  # (fp:drop n list) → drop first n items; error if n < 0
  register_primitive!(registry, "FP:DROP", REPORTER,
    reporter_syntax(right=[NumberType, ListType], ret=ListType),
    (ctx, args) -> begin
      n = Int(floor(args[1]))
      n < 0 && throw(LogoRuntimeError("fp:drop: first argument must be a positive number"))
      list = args[2]::AbstractVector
      n >= length(list) ? Any[] : Any[list[(n + 1):end]...]
    end)

  # ── fp:scan ─────────────────────────────────────────────────────────────────
  # (fp:scan reporter list) → like reduce but collects intermediates
  register_primitive!(registry, "FP:SCAN", REPORTER,
    reporter_syntax(right=[ReporterType, ListType], ret=ListType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:scan")
      list = args[2]::AbstractVector
      isempty(list) && return Any[]
      result = Any[list[1]]
      for i in 2:length(list)
        accumulated = invoke_reporter_task(ctx, reporter, Any[result[end], list[i]])
        push!(result, accumulated)
      end
      result
    end)

  # ── fp:find ─────────────────────────────────────────────────────────────────
  # (fp:find reporter list) → first matching item, or false
  register_primitive!(registry, "FP:FIND", REPORTER,
    reporter_syntax(right=[ReporterType, ListType], ret=WildcardType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:find")
      list = args[2]::AbstractVector
      for item in list
        result = invoke_reporter_task(ctx, reporter, Any[item])
        result isa Bool || throw(LogoRuntimeError("fp:find: the reporter does not return a boolean value"))
        result && return item
      end
      false
    end)

  # ── fp:find-indices ─────────────────────────────────────────────────────────
  # (fp:find-indices reporter list) → 0-based indices where reporter is true
  register_primitive!(registry, "FP:FIND-INDICES", REPORTER,
    reporter_syntax(right=[ReporterType, ListType], ret=ListType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:find-indices")
      list = args[2]::AbstractVector
      indices = Any[]
      for (i, item) in enumerate(list)
        result = invoke_reporter_task(ctx, reporter, Any[item])
        result isa Bool || throw(LogoRuntimeError("fp:find-indices: the reporter does not return a boolean value"))
        result && push!(indices, Float64(i - 1))
      end
      indices
    end)

  # ── fp:zip ──────────────────────────────────────────────────────────────────
  # (fp:zip list1 list2 …) → list of sub-lists pairing positional elements
  register_primitive!(registry, "FP:ZIP", REPORTER,
    reporter_syntax(right=[ListType, ListType | RepeatableType], ret=ListType),
    (ctx, args) -> begin
      lists = AbstractVector[a::AbstractVector for a in args]
      isempty(lists) && return Any[]
      min_len = minimum(length(l) for l in lists)
      Any[Any[l[i] for l in lists] for i in 1:min_len]
    end)

  # ── fp:unzip ────────────────────────────────────────────────────────────────
  # (fp:unzip list-of-lists) → transpose (inverse of zip)
  register_primitive!(registry, "FP:UNZIP", REPORTER,
    reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> begin
      list = args[1]::AbstractVector
      isempty(list) && return Any[]
      for item in list
        item isa AbstractVector || throw(LogoRuntimeError("fp:unzip: input must be a list of lists"))
      end
      max_len = maximum(length(sub::AbstractVector) for sub in list)
      Any[Any[sub[i] for sub in list if i <= length(sub::AbstractVector)] for i in 1:max_len]
    end)

  # ── fp:flatten ──────────────────────────────────────────────────────────────
  # (fp:flatten nested-list) → recursively flatten
  register_primitive!(registry, "FP:FLATTEN", REPORTER,
    reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> begin
      function flatten_rec(lst, out)
        for item in lst
          if item isa AbstractVector
            flatten_rec(item, out)
          else
            push!(out, item)
          end
        end
      end
      result = Any[]
      flatten_rec(args[1]::AbstractVector, result)
      result
    end)

  # ── fp:compose ──────────────────────────────────────────────────────────────
  # (fp:compose f g …) → right-to-left: f(g(…(x)))
  # Java source reverses args then chains.  First in reversed list is applied first.
  register_primitive!(registry, "FP:COMPOSE", REPORTER,
    reporter_syntax(right=[ReporterType, ReporterType | RepeatableType], ret=ReporterType),
    (ctx, args) -> begin
      reporters = AbstractReporterTaskValue[coerce_reporter_task(a, "fp:compose") for a in reverse(args)]
      # Validate non-first reporters take exactly 1 input
      for i in 2:length(reporters)
        mi = reporter_min_inputs(reporters[i])
        mi == 1 || throw(LogoRuntimeError("fp:compose: one or more reporters have invalid number of arguments"))
      end
      ComposedReporterTask(reporters, ctx)
    end)

  # ── fp:pipe ─────────────────────────────────────────────────────────────────
  # (fp:pipe f g …) → left-to-right: …(g(f(x)))
  register_primitive!(registry, "FP:PIPE", REPORTER,
    reporter_syntax(right=[ReporterType, ReporterType | RepeatableType], ret=ReporterType),
    (ctx, args) -> begin
      reporters = AbstractReporterTaskValue[coerce_reporter_task(a, "fp:pipe") for a in args]
      for i in 2:length(reporters)
        mi = reporter_min_inputs(reporters[i])
        mi == 1 || throw(LogoRuntimeError("fp:pipe: one or more reporters have invalid number of arguments"))
      end
      ComposedReporterTask(reporters, ctx)
    end)

  # ── fp:curry ────────────────────────────────────────────────────────────────
  # (fp:curry reporter val …) → partially-applied reporter
  register_primitive!(registry, "FP:CURRY", REPORTER,
    reporter_syntax(right=[ReporterType, WildcardType | RepeatableType], ret=ReporterType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:curry")
      fixed = Any[args[2:end]...]
      CurriedReporterTask(reporter, fixed, ctx)
    end)

  # ── fp:iterate ──────────────────────────────────────────────────────────────
  # (fp:iterate reporter init n) → [init, f(init), f(f(init)), …]  (n+1 elements)
  register_primitive!(registry, "FP:ITERATE", REPORTER,
    reporter_syntax(right=[ReporterType, WildcardType, NumberType], ret=ListType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:iterate")
      mi = reporter_min_inputs(reporter)
      (mi != 1) && throw(LogoRuntimeError("fp:iterate: the reporter should take a single argument"))
      current = args[2]
      n = Int(floor(args[3]))
      result = Any[current]
      for _ in 1:n
        current = invoke_reporter_task(ctx, reporter, Any[current])
        push!(result, current)
      end
      result
    end)

  # ── fp:iterate-last ─────────────────────────────────────────────────────────
  # (fp:iterate-last reporter init n) → f^n(init)
  register_primitive!(registry, "FP:ITERATE-LAST", REPORTER,
    reporter_syntax(right=[ReporterType, WildcardType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:iterate-last")
      mi = reporter_min_inputs(reporter)
      (mi != 1) && throw(LogoRuntimeError("fp:iterate-last: the reporter should take a single argument"))
      current = args[2]
      n = Int(floor(args[3]))
      for _ in 1:n
        current = invoke_reporter_task(ctx, reporter, Any[current])
      end
      current
    end)

  # ── fp:apply ────────────────────────────────────────────────────────────────
  # (fp:apply reporter arg-list) → invoke reporter with unpacked args
  register_primitive!(registry, "FP:APPLY", REPORTER,
    reporter_syntax(right=[ReporterType, ListType], ret=WildcardType),
    (ctx, args) -> begin
      reporter = coerce_reporter_task(args[1], "fp:apply")
      arguments = args[2]::AbstractVector
      mi = reporter_min_inputs(reporter)
      if mi > length(arguments)
        throw(LogoRuntimeError(
          "fp:apply: the reporter requires at least $mi argument$(mi == 1 ? "" : "s") but the list only has $(length(arguments)) element$(length(arguments) == 1 ? "" : "s")"))
      end
      invoke_reporter_task(ctx, reporter, Any[arguments...])
    end)

end # register_extension!

end # module fp
