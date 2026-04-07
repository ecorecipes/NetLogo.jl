# ── ExtTime.jl ──────────────────────────────────────────────────────────────
# NetLogo Time extension for date/time operations and discrete event scheduling.
# Implements the primitives from the NetLogo Time extension
# (https://github.com/NetLogo/Time-Extension) using Julia's Dates stdlib.
#
# The module is named `time` so that the extension resolver
# (`resolve_extension_module("time")`) finds it automatically.

module time

using Dates
using Random: shuffle!

import ..NetLogo: logo_string

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType, CommandBlockType,
  LogoRuntimeError, Context

# Parent module reference for accessing internal types and functions
const NL = parentmodule(@__MODULE__)

# ─── Date Type Enum ─────────────────────────────────────────────────────────

@enum DateType DateTimeType=1 DateOnlyType=2 DayDateType=3

function date_type_name(dt::DateType)
  dt == DateTimeType ? "datetime" : dt == DateOnlyType ? "date" : "day"
end

# ─── LogoTime ────────────────────────────────────────────────────────────────

mutable struct LogoTime
  datetime::DateTime
  date_type::DateType
  # Anchoring fields
  is_anchored::Bool
  tick_value::Float64     # periods per tick (e.g. 1 day per tick)
  tick_type::String       # period unit name
  anchor_datetime::DateTime
  world_ref::Any          # reference to World for tick-based updates (or nothing)
end

function LogoTime(dt::DateTime, dtype::DateType=DateTimeType)
  LogoTime(dt, dtype, false, 0.0, "", dt, nothing)
end

function LogoTime(d::Date)
  LogoTime(DateTime(d), DateOnlyType, false, 0.0, "", DateTime(d), nothing)
end

function copy_logotime(lt::LogoTime)
  update_from_tick!(lt)
  LogoTime(lt.datetime, lt.date_type, false, 0.0, "", lt.datetime, nothing)
end

# ─── Display ─────────────────────────────────────────────────────────────────

function format_datetime_default(dt::DateTime)
  ms = Dates.millisecond(dt)
  base = Dates.format(dt, dateformat"yyyy-mm-dd HH:MM:SS")
  ms == 0 && return base
  ms_str = lpad(string(ms), 3, '0')
  ms_str = rstrip(ms_str, '0')
  base * "." * ms_str
end

function logo_string(lt::LogoTime)
  update_from_tick!(lt)
  str = if lt.date_type == DateTimeType
    format_datetime_default(lt.datetime)
  elseif lt.date_type == DateOnlyType
    Dates.format(lt.datetime, dateformat"yyyy-mm-dd")
  else # DayDateType
    Dates.format(lt.datetime, dateformat"mm-dd")
  end
  "{{time: $str}}"
end

# ─── Period Utilities ────────────────────────────────────────────────────────

const PERIOD_MAP = Dict{String, String}(
  "year" => "year", "years" => "year",
  "month" => "month", "months" => "month",
  "week" => "week", "weeks" => "week",
  "day" => "day", "days" => "day",
  "dayofyear" => "dayofyear",
  "hour" => "hour", "hours" => "hour",
  "minute" => "minute", "minutes" => "minute",
  "second" => "second", "seconds" => "second",
  "milli" => "milli", "millis" => "milli",
  "millisecond" => "milli", "milliseconds" => "milli",
)

function resolve_period(unit::AbstractString)
  key = lowercase(strip(String(unit)))
  haskey(PERIOD_MAP, key) || throw(LogoRuntimeError(
    "time: unknown period type '$unit'. " *
    "Expected one of: year, month, week, day, hour, minute, second, milli"))
  PERIOD_MAP[key]
end

function period_to_ms(period::String)
  period == "week"      && return 7.0 * 24 * 60 * 60 * 1000
  period == "day"       && return 24.0 * 60 * 60 * 1000
  period == "dayofyear" && return 24.0 * 60 * 60 * 1000
  period == "hour"      && return 60.0 * 60 * 1000
  period == "minute"    && return 60.0 * 1000
  period == "second"    && return 1000.0
  period == "milli"     && return 1.0
  throw(LogoRuntimeError("time: period '$period' cannot be converted to milliseconds"))
end

# ─── Format Conversion (Java/NetLogo → Julia) ───────────────────────────────
# Java SimpleDateFormat: y=year M=month d=day H=hour24 m=minute s=second S=millis
# Julia DateFormat:      y=year m=month d=day H=hour24 M=minute S=second s=millis

function java_to_julia_dateformat(fmt::AbstractString)
  buf = IOBuffer()
  for c in fmt
    if c == 'M'       # Java month → Julia m
      write(buf, 'm')
    elseif c == 'm'   # Java minute → Julia M
      write(buf, 'M')
    elseif c == 's'   # Java second → Julia S
      write(buf, 'S')
    elseif c == 'S'   # Java millisecond → Julia s
      write(buf, 's')
    elseif c == 'u'   # Java 8 proleptic year → Julia y
      write(buf, 'y')
    else              # y, d, H, h, -, /, :, T, space, etc. pass through
      write(buf, c)
    end
  end
  String(take!(buf))
end

# Detect DateType from a Java/NetLogo format string
function detect_date_type_from_format(fmt::AbstractString)
  has_time = any(c -> c in ('H', 'h', 'S', 's', 'K', 'k', 'm'), fmt)
  has_year = any(c -> c in ('Y', 'y', 'u'), fmt)
  has_time && return DateTimeType
  has_year && return DateOnlyType
  return DayDateType
end

# ─── Parsing ─────────────────────────────────────────────────────────────────

function parse_time_components(time_str::AbstractString)
  parts = split(time_str, ":")
  hour = parse(Int, parts[1])
  minute = length(parts) >= 2 ? parse(Int, parts[2]) : 0
  second = 0
  millis = 0
  if length(parts) >= 3
    sec_parts = split(parts[3], ".")
    second = parse(Int, sec_parts[1])
    if length(sec_parts) >= 2
      ms_raw = sec_parts[2]
      ms_str = rpad(ms_raw[1:min(3, length(ms_raw))], 3, '0')
      millis = parse(Int, ms_str)
    end
  end
  (hour, minute, second, millis)
end

function parse_logotime(s)
  str = strip(String(s))

  lowercase(str) == "now" && return LogoTime(now(), DateTimeType)

  # Normalize separators
  normalized = replace(str, "/" => "-")

  # Split on space or T to separate date and time parts
  parts = split(normalized, r"[\sT]", limit=2)
  date_str = parts[1]
  has_time_part = length(parts) > 1

  # Parse date
  date_parts = split(date_str, "-")
  if length(date_parts) == 3
    yr = parse(Int, date_parts[1])
    mo = parse(Int, date_parts[2])
    dy = parse(Int, date_parts[3])
    if has_time_part
      h, mi, sec, ms = parse_time_components(parts[2])
      return LogoTime(DateTime(yr, mo, dy, h, mi, sec, ms), DateTimeType)
    else
      return LogoTime(DateTime(yr, mo, dy), DateOnlyType)
    end
  elseif length(date_parts) == 2
    # DayDate: month-day (no year, use 2000 as default like Java)
    mo = parse(Int, date_parts[1])
    dy = parse(Int, date_parts[2])
    if has_time_part
      h, mi, sec, ms = parse_time_components(parts[2])
      return LogoTime(DateTime(2000, mo, dy, h, mi, sec, ms), DateTimeType)
    else
      return LogoTime(DateTime(2000, mo, dy), DayDateType)
    end
  end

  throw(LogoRuntimeError(
    "time:create - could not parse date string '$s'. " *
    "Expected formats like: yyyy-MM-dd, yyyy-MM-dd HH:mm:ss, MM-dd"))
end

function parse_logotime_with_format(s, fmt)
  str = strip(String(s))
  fmt_str = String(fmt)
  dtype = detect_date_type_from_format(fmt_str)
  julia_fmt = java_to_julia_dateformat(fmt_str)

  try
    df = DateFormat(julia_fmt)
    dt = if dtype == DateOnlyType
      DateTime(Dates.Date(str, df))
    else
      DateTime(str, df)
    end
    # For DayDate, year will be whatever was parsed or default
    if dtype == DayDateType
      dt = DateTime(2000, Dates.month(dt), Dates.day(dt),
                    Dates.hour(dt), Dates.minute(dt),
                    Dates.second(dt), Dates.millisecond(dt))
    end
    return LogoTime(dt, dtype)
  catch e
    throw(LogoRuntimeError(
      "time:create-with-format - could not parse '$str' with format '$fmt_str' " *
      "(Julia format: '$julia_fmt'): $(sprint(showerror, e))"))
  end
end

# ─── Time Formatting ────────────────────────────────────────────────────────

function show_logotime(lt::LogoTime, fmt)
  update_from_tick!(lt)
  julia_fmt = java_to_julia_dateformat(String(fmt))
  try
    return Dates.format(lt.datetime, DateFormat(julia_fmt))
  catch e
    throw(LogoRuntimeError(
      "time:show - could not format time with '$fmt': $(sprint(showerror, e))"))
  end
end

# ─── Component Extraction ───────────────────────────────────────────────────

function get_component(component, lt::LogoTime)
  lt isa LogoTime || throw(LogoRuntimeError("time:get expected a LogoTime as the second argument"))
  update_from_tick!(lt)
  dt = lt.datetime
  comp = lowercase(strip(String(component)))

  comp == "year"      && return Float64(Dates.year(dt))
  comp == "month"     && return Float64(Dates.month(dt))
  comp == "day"       && return Float64(Dates.day(dt))
  comp == "hour"      && return Float64(Dates.hour(dt))
  comp == "minute"    && return Float64(Dates.minute(dt))
  comp == "second"    && return Float64(Dates.second(dt))
  comp == "milli"     && return Float64(Dates.millisecond(dt))
  comp == "dayofweek" && return Float64(Dates.dayofweek(dt))  # 1=Mon, 7=Sun (ISO)
  comp == "dayofyear" && return Float64(Dates.dayofyear(dt))

  throw(LogoRuntimeError(
    "time:get - unknown component '$component'. " *
    "Expected: year, month, day, hour, minute, second, milli, dayofweek, dayofyear"))
end

# ─── Time Arithmetic ────────────────────────────────────────────────────────

function time_plus(lt::LogoTime, amount, unit_str)
  lt isa LogoTime || throw(LogoRuntimeError("time:plus expected a LogoTime as the first argument"))
  update_from_tick!(lt)
  period = resolve_period(unit_str)
  n = Float64(amount)

  new_dt = if period == "year"
    lt.datetime + Dates.Year(round(Int, n))
  elseif period == "month"
    lt.datetime + Dates.Month(round(Int, n))
  else
    ms = period_to_ms(period) * n
    lt.datetime + Dates.Millisecond(round(Int64, ms))
  end
  LogoTime(new_dt, lt.date_type)
end

# ─── Time Difference ────────────────────────────────────────────────────────

function full_years_between(dt1::DateTime, dt2::DateTime)
  if dt1 <= dt2
    y = Dates.year(dt2) - Dates.year(dt1)
    if dt1 + Dates.Year(y) > dt2
      y -= 1
    end
    return Float64(y)
  else
    return -full_years_between(dt2, dt1)
  end
end

function full_months_between(dt1::DateTime, dt2::DateTime)
  if dt1 <= dt2
    m = (Dates.year(dt2) - Dates.year(dt1)) * 12 + (Dates.month(dt2) - Dates.month(dt1))
    if dt1 + Dates.Month(m) > dt2
      m -= 1
    end
    return Float64(m)
  else
    return -full_months_between(dt2, dt1)
  end
end

function difference_between(lt1::LogoTime, lt2::LogoTime, unit_str)
  update_from_tick!(lt1)
  update_from_tick!(lt2)
  period = resolve_period(unit_str)

  if period == "year"
    return full_years_between(lt1.datetime, lt2.datetime)
  elseif period == "month"
    return full_months_between(lt1.datetime, lt2.datetime)
  end

  # Duration-based: convert to milliseconds
  dt1 = lt1.date_type == DateOnlyType ? DateTime(Dates.Date(lt1.datetime)) : lt1.datetime
  dt2 = lt2.date_type == DateOnlyType ? DateTime(Dates.Date(lt2.datetime)) : lt2.datetime
  ms = Float64(Dates.value(dt2 - dt1))
  return ms / period_to_ms(period)
end

# ─── Time Comparisons ───────────────────────────────────────────────────────

function effective_dt(lt::LogoTime)
  update_from_tick!(lt)
  lt.datetime
end

function is_before(lt1::LogoTime, lt2::LogoTime)
  effective_dt(lt1) < effective_dt(lt2)
end

function is_after(lt1::LogoTime, lt2::LogoTime)
  effective_dt(lt1) > effective_dt(lt2)
end

function is_equal(lt1::LogoTime, lt2::LogoTime)
  effective_dt(lt1) == effective_dt(lt2)
end

function is_between(lt::LogoTime, start_lt::LogoTime, end_lt::LogoTime)
  t = effective_dt(lt)
  s = effective_dt(start_lt)
  e = effective_dt(end_lt)
  s <= t && t <= e
end

# ─── Anchoring ───────────────────────────────────────────────────────────────

function anchor_to_ticks!(ctx::Context, lt::LogoTime, tick_val, unit_str)
  lt.tick_value = Float64(tick_val)
  lt.tick_type = resolve_period(unit_str)
  lt.is_anchored = true
  lt.anchor_datetime = lt.datetime
  lt.world_ref = ctx.runtime.world
  lt
end

function update_from_tick!(lt::LogoTime)
  lt.is_anchored || return
  world = lt.world_ref
  world === nothing && return
  current_tick = world.ticks
  current_tick >= 0 || return
  elapsed_periods = current_tick * lt.tick_value
  lt.datetime = add_periods(lt.anchor_datetime, lt.tick_type, elapsed_periods)
  nothing
end

function add_periods(dt::DateTime, period_type::String, amount::Float64)
  if period_type == "year"
    dt + Dates.Year(round(Int, amount))
  elseif period_type == "month"
    dt + Dates.Month(round(Int, amount))
  else
    ms = period_to_ms(period_type) * amount
    dt + Dates.Millisecond(round(Int64, ms))
  end
end

# ─── Discrete Event Scheduler ───────────────────────────────────────────────

mutable struct ScheduledEvent
  id::Int64
  tick::Float64
  agent::Any          # Agent, AgentSet, "observer" string, or nothing
  task::Any           # AbstractCommandTaskValue
  repeat_interval::Float64      # 0 for non-repeating
  repeat_interval_period_type::Union{Nothing, String}
  shuffled::Bool
end

mutable struct EventSchedule
  events::Vector{ScheduledEvent}
  next_id::Int64
  is_anchored::Bool
  anchor_time::Union{Nothing, LogoTime}
  tick_type::String
  tick_value::Float64
end

EventSchedule() = EventSchedule(ScheduledEvent[], 0, false, nothing, "", 0.0)

function next_event_id!(schedule::EventSchedule)
  schedule.next_id += 1
  schedule.next_id
end

function get_schedule(ctx::Context)::EventSchedule
  g = ctx.runtime.world.observer.globals
  get!(g, "__TIME_SCHEDULE") do
    EventSchedule()
  end
end

# Convert a LogoTime to a tick number using the schedule anchor
function time_to_tick(schedule::EventSchedule, lt::LogoTime)
  schedule.is_anchored || throw(LogoRuntimeError(
    "time: a LogoEvent can only be scheduled at a LogoTime " *
    "if the discrete event schedule has been anchored to a LogoTime"))
  anchor_dt = schedule.anchor_time.datetime
  target_dt = lt.datetime
  period = schedule.tick_type

  if period == "year"
    elapsed = full_years_between(anchor_dt, target_dt)
  elseif period == "month"
    elapsed = full_months_between(anchor_dt, target_dt)
  else
    ms = Float64(Dates.value(target_dt - anchor_dt))
    elapsed = ms / period_to_ms(period)
  end
  elapsed / schedule.tick_value
end

function resolve_event_tick(schedule::EventSchedule, tick_or_time)
  if tick_or_time isa LogoTime
    return time_to_tick(schedule, tick_or_time)
  end
  Float64(tick_or_time)
end

# ─── Schedule Event Functions ────────────────────────────────────────────────

function validate_schedule_args(args, prim_name::String)
  agent = args[1]
  task = args[2]
  is_valid_agent = agent isa NL.AbstractAgent ||
                   agent isa NL.AgentSet ||
                   (agent isa String && lowercase(agent) == "observer")
  is_valid_agent || throw(LogoRuntimeError(
    "time: $prim_name expected an agent, agentset, or the string \"observer\" " *
    "as the first argument"))
  isa(task, NL.AbstractCommandTaskValue) || throw(LogoRuntimeError(
    "time: $prim_name expected a command task as the second argument"))
  nothing
end

function schedule_event!(ctx::Context, args, prim_name::String;
                         shuffled::Bool=false,
                         repeating::Bool=false,
                         with_period::Bool=false)
  validate_schedule_args(args, prim_name)
  schedule = get_schedule(ctx)
  agent = args[1]
  task = args[2]
  tick = resolve_event_tick(schedule, args[3])

  repeat_interval = 0.0
  repeat_period_type = nothing

  if repeating
    repeat_interval = Float64(args[4])
    repeat_interval <= 0 && throw(LogoRuntimeError(
      "time: $prim_name repeat interval must be a positive number"))

    if with_period
      period_str = resolve_period(args[5])
      if period_str in ("month", "year")
        # Month/year periods are kept as-is (variable-length)
        repeat_period_type = period_str
      else
        # Convert other periods to tick intervals
        schedule.is_anchored || throw(LogoRuntimeError(
          "time: a repeating event can only use a period type " *
          "if the schedule has been anchored"))
        ms_per_period = period_to_ms(period_str) * repeat_interval
        ms_per_tick = period_to_ms(schedule.tick_type) * schedule.tick_value
        repeat_interval = ms_per_period / ms_per_tick
        repeat_period_type = nothing
      end
    end
  end

  event = ScheduledEvent(
    next_event_id!(schedule),
    tick, agent, task,
    repeat_interval, repeat_period_type,
    shuffled)
  push!(schedule.events, event)
  nothing
end

# ─── Event Execution ────────────────────────────────────────────────────────

function execute_event!(ctx::Context, event::ScheduledEvent)
  task = event.task
  agent_arg = event.agent
  invoke = NL.invoke_command_task
  observer = ctx.runtime.world.observer
  empty_actuals = Any[]

  if agent_arg isa String && lowercase(agent_arg) == "observer"
    invoke(ctx, task, empty_actuals; agent=observer)
  elseif agent_arg isa NL.AgentSet
    members = NL.AbstractAgent[a for a in agent_arg]
    if event.shuffled
      shuffle!(ctx.runtime.world.rng, members)
    end
    for agent in members
      NL.agent_is_live(agent) || continue
      invoke(ctx, task, empty_actuals; agent=agent, caller=observer)
    end
  elseif agent_arg isa NL.AbstractAgent
    NL.agent_is_live(agent_arg) || return
    invoke(ctx, task, empty_actuals; agent=agent_arg, caller=observer)
  else
    throw(LogoRuntimeError("time: cannot execute event for agent: $(NL.logo_string(agent_arg))"))
  end
  nothing
end

function reschedule_event!(schedule::EventSchedule, event::ScheduledEvent)
  event.repeat_interval <= 0 && return
  new_tick = if event.repeat_interval_period_type !== nothing
    # Month/year period-based rescheduling
    period = event.repeat_interval_period_type
    schedule.is_anchored || return
    anchor_dt = schedule.anchor_time.datetime
    current_dt = add_periods(anchor_dt, schedule.tick_type, event.tick * schedule.tick_value)
    next_dt = add_periods(current_dt, period, event.repeat_interval)
    time_to_tick(schedule, LogoTime(next_dt, DateTimeType))
  else
    event.tick + event.repeat_interval
  end
  new_event = ScheduledEvent(
    next_event_id!(schedule),
    new_tick, event.agent, event.task,
    event.repeat_interval, event.repeat_interval_period_type,
    event.shuffled)
  push!(schedule.events, new_event)
  nothing
end

function execute_schedule!(ctx::Context, schedule::EventSchedule, until_tick::Float64)
  world = ctx.runtime.world
  world.ticks >= 0 || throw(LogoRuntimeError(
    "time:go requires the tick counter to be started. Use RESET-TICKS first."))

  # Sort events by (tick, id) for stable execution order
  sort!(schedule.events, by=e -> (e.tick, e.id))

  while !isempty(schedule.events)
    event = schedule.events[1]
    event.tick <= until_tick || break

    popfirst!(schedule.events)

    # Advance ticks to event time
    if event.tick > world.ticks
      world.ticks = event.tick
    end

    execute_event!(ctx, event)
    reschedule_event!(schedule, event)

    # Re-sort after rescheduling
    sort!(schedule.events, by=e -> (e.tick, e.id))
  end

  # Advance ticks to until_tick if specified and greater than current
  if isfinite(until_tick) && until_tick > world.ticks
    world.ticks = until_tick
  end
  nothing
end

function show_schedule(schedule::EventSchedule)
  if isempty(schedule.events)
    return "Schedule is empty"
  end
  sorted = sort(schedule.events, by=e -> (e.tick, e.id))
  lines = String[]
  for e in sorted
    agent_str = if e.agent isa String
      e.agent
    elseif e.agent isa NL.AgentSet
      "agentset ($(length(collect(e.agent))))"
    elseif e.agent isa NL.AbstractAgent
      NL.logo_string(e.agent)
    else
      string(e.agent)
    end
    repeat_str = e.repeat_interval > 0 ? " repeat=$(e.repeat_interval)" : ""
    shuffled_str = e.shuffled ? " shuffled" : ""
    push!(lines, "tick=$(e.tick) agent=$(agent_str)$(repeat_str)$(shuffled_str)")
  end
  join(lines, "\n")
end

# ─── Type checking helper ───────────────────────────────────────────────────

function require_logotime(val, prim_name::String)
  val isa LogoTime || throw(LogoRuntimeError(
    "time: $prim_name expected a LogoTime but got $(NL.logo_string(val))"))
  val
end

# ─── Registration ───────────────────────────────────────────────────────────

function register_extension!(registry::PrimitiveRegistry)

  # ── Date/Time Reporters ──────────────────────────────────────────────────

  register_primitive!(registry, "TIME:CREATE", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> parse_logotime(args[1]))

  register_primitive!(registry, "TIME:CREATE-WITH-FORMAT", REPORTER,
    reporter_syntax(right=[StringType, StringType], ret=WildcardType),
    (ctx, args) -> parse_logotime_with_format(args[1], args[2]))

  register_primitive!(registry, "TIME:COPY", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      lt = require_logotime(args[1], "time:copy")
      copy_logotime(lt)
    end)

  register_primitive!(registry, "TIME:SHOW", REPORTER,
    reporter_syntax(right=[WildcardType, StringType], ret=StringType),
    (ctx, args) -> begin
      lt = require_logotime(args[1], "time:show")
      show_logotime(lt, args[2])
    end)

  register_primitive!(registry, "TIME:GET", REPORTER,
    reporter_syntax(right=[StringType, WildcardType], ret=NumberType),
    (ctx, args) -> begin
      lt = require_logotime(args[2], "time:get")
      get_component(args[1], lt)
    end)

  register_primitive!(registry, "TIME:PLUS", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, StringType], ret=WildcardType),
    (ctx, args) -> begin
      lt = require_logotime(args[1], "time:plus")
      time_plus(lt, args[2], args[3])
    end)

  register_primitive!(registry, "TIME:DIFFERENCE-BETWEEN", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType, StringType], ret=NumberType),
    (ctx, args) -> begin
      lt1 = require_logotime(args[1], "time:difference-between")
      lt2 = require_logotime(args[2], "time:difference-between")
      difference_between(lt1, lt2, args[3])
    end)

  register_primitive!(registry, "TIME:IS-BEFORE?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      lt1 = require_logotime(args[1], "time:is-before?")
      lt2 = require_logotime(args[2], "time:is-before?")
      is_before(lt1, lt2)
    end)

  register_primitive!(registry, "TIME:IS-AFTER?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      lt1 = require_logotime(args[1], "time:is-after?")
      lt2 = require_logotime(args[2], "time:is-after?")
      is_after(lt1, lt2)
    end)

  register_primitive!(registry, "TIME:IS-EQUAL?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      lt1 = require_logotime(args[1], "time:is-equal?")
      lt2 = require_logotime(args[2], "time:is-equal?")
      is_equal(lt1, lt2)
    end)

  register_primitive!(registry, "TIME:IS-BETWEEN?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      lt = require_logotime(args[1], "time:is-between?")
      lt_start = require_logotime(args[2], "time:is-between?")
      lt_end = require_logotime(args[3], "time:is-between?")
      is_between(lt, lt_start, lt_end)
    end)

  register_primitive!(registry, "TIME:ANCHOR-TO-TICKS", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, StringType], ret=WildcardType),
    (ctx, args) -> begin
      lt = require_logotime(args[1], "time:anchor-to-ticks")
      anchor_to_ticks!(ctx, lt, args[2], args[3])
    end)

  # ── Discrete Event Scheduler Commands ────────────────────────────────────

  register_primitive!(registry, "TIME:SCHEDULE-EVENT", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType]),
    (ctx, args) -> schedule_event!(ctx, args, "time:schedule-event"))

  register_primitive!(registry, "TIME:SCHEDULE-EVENT-SHUFFLED", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType]),
    (ctx, args) -> schedule_event!(ctx, args, "time:schedule-event-shuffled";
      shuffled=true))

  register_primitive!(registry, "TIME:SCHEDULE-REPEATING-EVENT", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType, NumberType]),
    (ctx, args) -> schedule_event!(ctx, args, "time:schedule-repeating-event";
      repeating=true))

  register_primitive!(registry, "TIME:SCHEDULE-REPEATING-EVENT-SHUFFLED", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType, NumberType]),
    (ctx, args) -> schedule_event!(ctx, args, "time:schedule-repeating-event-shuffled";
      shuffled=true, repeating=true))

  register_primitive!(registry, "TIME:SCHEDULE-REPEATING-EVENT-WITH-PERIOD", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType, NumberType, StringType]),
    (ctx, args) -> schedule_event!(ctx, args,
      "time:schedule-repeating-event-with-period";
      repeating=true, with_period=true))

  register_primitive!(registry, "TIME:SCHEDULE-REPEATING-EVENT-SHUFFLED-WITH-PERIOD", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType, NumberType, StringType]),
    (ctx, args) -> schedule_event!(ctx, args,
      "time:schedule-repeating-event-shuffled-with-period";
      shuffled=true, repeating=true, with_period=true))

  register_primitive!(registry, "TIME:ANCHOR-SCHEDULE", COMMAND,
    command_syntax(right=[WildcardType, NumberType, StringType]),
    (ctx, args) -> begin
      lt = require_logotime(args[1], "time:anchor-schedule")
      schedule = get_schedule(ctx)
      schedule.is_anchored = true
      schedule.anchor_time = copy_logotime(lt)
      schedule.tick_value = Float64(args[2])
      schedule.tick_type = resolve_period(args[3])
      nothing
    end)

  register_primitive!(registry, "TIME:GO", COMMAND,
    command_syntax(right=Int[]),
    (ctx, args) -> begin
      schedule = get_schedule(ctx)
      execute_schedule!(ctx, schedule, Inf)
    end)

  register_primitive!(registry, "TIME:GO-UNTIL", COMMAND,
    command_syntax(right=[WildcardType]),
    (ctx, args) -> begin
      schedule = get_schedule(ctx)
      until_tick = if args[1] isa LogoTime
        time_to_tick(schedule, args[1])
      else
        Float64(args[1])
      end
      execute_schedule!(ctx, schedule, until_tick)
    end)

  register_primitive!(registry, "TIME:CLEAR-SCHEDULE", COMMAND,
    command_syntax(right=Int[]),
    (ctx, args) -> begin
      schedule = get_schedule(ctx)
      empty!(schedule.events)
      schedule.next_id = 0
      nothing
    end)

  # ── Scheduler Reporters ──────────────────────────────────────────────────

  register_primitive!(registry, "TIME:SIZE-OF-SCHEDULE", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> begin
      schedule = get_schedule(ctx)
      Float64(length(schedule.events))
    end)

  register_primitive!(registry, "TIME:SHOW-SCHEDULE", REPORTER,
    reporter_syntax(ret=StringType),
    (ctx, args) -> begin
      schedule = get_schedule(ctx)
      show_schedule(schedule)
    end)

end # register_extension!

end # module time
