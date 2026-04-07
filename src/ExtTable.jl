module table

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  LogoRuntimeError, logo_string, logo_equal,
  Context, AgentSet, AbstractAgent,
  AbstractReporterTaskValue, invoke_reporter_task,
  live_agentset_members, resolve_file_path

# NetLogo tables are ordered dictionaries keyed by any Logo value.
# We use a Vector of pairs to preserve insertion order (matching upstream).
mutable struct LogoTable
  entries::Vector{Pair{Any, Any}}
end

LogoTable() = LogoTable(Pair{Any, Any}[])

function table_find_index(t::LogoTable, key)
  for (i, pair) in enumerate(t.entries)
    logo_equal(first(pair), key) && return i
  end
  0
end

function table_get(t::LogoTable, key)
  idx = table_find_index(t, key)
  idx == 0 && throw(LogoRuntimeError("No value for $(logo_string(key)) in table."))
  last(t.entries[idx])
end

function table_get_or_default(t::LogoTable, key, default_value)
  idx = table_find_index(t, key)
  idx == 0 ? default_value : last(t.entries[idx])
end

function table_put!(t::LogoTable, key, value)
  idx = table_find_index(t, key)
  if idx == 0
    push!(t.entries, key => value)
  else
    t.entries[idx] = key => value
  end
  nothing
end

function table_has_key(t::LogoTable, key)
  table_find_index(t, key) != 0
end

function table_remove!(t::LogoTable, key)
  idx = table_find_index(t, key)
  idx != 0 && deleteat!(t.entries, idx)
  nothing
end

function table_keys(t::LogoTable)
  Any[first(p) for p in t.entries]
end

function table_values(t::LogoTable)
  Any[last(p) for p in t.entries]
end

function table_to_list(t::LogoTable)
  Any[Any[first(p), last(p)] for p in t.entries]
end

function table_from_list(lst)
  t = LogoTable()
  for item in lst
    item isa AbstractVector || throw(LogoRuntimeError("table:from-list expects a list of two-element lists"))
    length(item) == 2 || throw(LogoRuntimeError("table:from-list expects a list of two-element lists, but got a list of length $(length(item))"))
    table_put!(t, item[1], item[2])
  end
  t
end

function table_counts(lst)
  t = LogoTable()
  for item in lst
    idx = table_find_index(t, item)
    if idx == 0
      push!(t.entries, item => 1.0)
    else
      t.entries[idx] = first(t.entries[idx]) => (last(t.entries[idx]) + 1.0)
    end
  end
  t
end

function table_group_items(context::Context, list, task::AbstractReporterTaskValue)
  t = LogoTable()
  for item in list
    key = invoke_reporter_task(context, task, Any[item])
    idx = table_find_index(t, key)
    if idx == 0
      push!(t.entries, key => Any[item])
    else
      push!(last(t.entries[idx])::Vector{Any}, item)
    end
  end
  t
end

function table_group_agents(context::Context, agentset::AgentSet, task::AbstractReporterTaskValue)
  groups = LogoTable()
  k = agentset.kind
  agents = live_agentset_members(agentset)
  for agent in agents
    key = invoke_reporter_task(context, task, Any[]; agent=agent)
    idx = table_find_index(groups, key)
    if idx == 0
      push!(groups.entries, key => AbstractAgent[agent])
    else
      push!(last(groups.entries[idx])::Vector{AbstractAgent}, agent)
    end
  end
  result = LogoTable()
  for pair in groups.entries
    push!(result.entries, first(pair) => AgentSet(k, last(pair)::Vector{AbstractAgent}))
  end
  result
end

# ── JSON serialization ──────────────────────────────────────────────────

function json_escape_string(s::AbstractString)
  buf = IOBuffer()
  write(buf, '"')
  for c in s
    if c == '"';      write(buf, "\\\"")
    elseif c == '\\'; write(buf, "\\\\")
    elseif c == '\n'; write(buf, "\\n")
    elseif c == '\r'; write(buf, "\\r")
    elseif c == '\t'; write(buf, "\\t")
    elseif codepoint(c) < 0x20
      write(buf, "\\u", lpad(string(codepoint(c), base=16), 4, '0'))
    else
      write(buf, c)
    end
  end
  write(buf, '"')
  String(take!(buf))
end

function logo_to_json(value)
  if value === nothing
    return "null"
  elseif value isa Bool
    return value ? "true" : "false"
  elseif value isa Real
    return isinteger(value) ? string(Int64(value)) : string(Float64(value))
  elseif value isa AbstractString
    return json_escape_string(value)
  elseif value isa AbstractVector
    return "[" * join([logo_to_json(v) for v in value], ",") * "]"
  elseif value isa LogoTable
    pairs = String[]
    for p in value.entries
      k = first(p)
      key_str = k isa AbstractString ? k : logo_string(k)
      push!(pairs, json_escape_string(key_str) * ":" * logo_to_json(last(p)))
    end
    return "{" * join(pairs, ",") * "}"
  else
    throw(LogoRuntimeError("table:to-json cannot serialize value of type $(typeof(value))"))
  end
end

# ── JSON deserialization ─────────────────────────────────────────────────

mutable struct JsonParser
  s::String
  pos::Int
end
JsonParser(s::String) = JsonParser(String(s), 1)

function json_skip_ws!(p::JsonParser)
  while p.pos <= length(p.s) && p.s[p.pos] in (' ', '\t', '\n', '\r')
    p.pos += 1
  end
end

function json_peek(p::JsonParser)
  json_skip_ws!(p)
  p.pos > length(p.s) && throw(LogoRuntimeError("table:from-json unexpected end of input"))
  p.s[p.pos]
end

function json_parse_value!(p::JsonParser)
  c = json_peek(p)
  if c == '"';                       return json_parse_string!(p)
  elseif c == '{';                   return json_parse_object!(p)
  elseif c == '[';                   return json_parse_array!(p)
  elseif c == 't';                   return json_parse_literal!(p, "true", true)
  elseif c == 'f';                   return json_parse_literal!(p, "false", false)
  elseif c == 'n';                   return json_parse_literal!(p, "null", nothing)
  elseif c == '-' || isdigit(c);     return json_parse_number!(p)
  else
    throw(LogoRuntimeError("table:from-json unexpected character '$(c)' at position $(p.pos)"))
  end
end

function json_parse_string!(p::JsonParser)
  p.pos += 1  # skip opening quote
  buf = IOBuffer()
  while p.pos <= length(p.s)
    c = p.s[p.pos]
    if c == '"'
      p.pos += 1
      return String(take!(buf))
    elseif c == '\\'
      p.pos += 1
      p.pos > length(p.s) && throw(LogoRuntimeError("table:from-json unexpected end in string escape"))
      esc = p.s[p.pos]
      if     esc == '"';  write(buf, '"')
      elseif esc == '\\'; write(buf, '\\')
      elseif esc == '/';  write(buf, '/')
      elseif esc == 'n';  write(buf, '\n')
      elseif esc == 'r';  write(buf, '\r')
      elseif esc == 't';  write(buf, '\t')
      elseif esc == 'b';  write(buf, '\b')
      elseif esc == 'f';  write(buf, '\f')
      elseif esc == 'u'
        p.pos + 4 > length(p.s) && throw(LogoRuntimeError("table:from-json incomplete unicode escape"))
        hex_str = p.s[p.pos+1:p.pos+4]
        p.pos += 4
        write(buf, Char(parse(UInt16, hex_str, base=16)))
      else
        throw(LogoRuntimeError("table:from-json unknown escape '\\$(esc)'"))
      end
      p.pos += 1
    else
      write(buf, c)
      p.pos += 1
    end
  end
  throw(LogoRuntimeError("table:from-json unterminated string"))
end

function json_parse_number!(p::JsonParser)
  start = p.pos
  p.s[p.pos] == '-' && (p.pos += 1)
  while p.pos <= length(p.s) && isdigit(p.s[p.pos]); p.pos += 1; end
  if p.pos <= length(p.s) && p.s[p.pos] == '.'
    p.pos += 1
    while p.pos <= length(p.s) && isdigit(p.s[p.pos]); p.pos += 1; end
  end
  if p.pos <= length(p.s) && p.s[p.pos] in ('e', 'E')
    p.pos += 1
    p.pos <= length(p.s) && p.s[p.pos] in ('+', '-') && (p.pos += 1)
    while p.pos <= length(p.s) && isdigit(p.s[p.pos]); p.pos += 1; end
  end
  token = p.s[start:p.pos-1]
  try
    Float64(parse(Float64, token))
  catch err
    throw(LogoRuntimeError("table:from-json invalid number '$(token)': $(sprint(showerror, err))"))
  end
end

function json_parse_literal!(p::JsonParser, literal::String, value)
  for c in literal
    (p.pos > length(p.s) || p.s[p.pos] != c) &&
      throw(LogoRuntimeError("table:from-json expected '$(literal)' at position $(p.pos)"))
    p.pos += 1
  end
  value
end

function json_parse_object!(p::JsonParser)
  p.pos += 1  # skip '{'
  t = LogoTable()
  json_peek(p) == '}' && (p.pos += 1; return t)
  while true
    json_peek(p) != '"' && throw(LogoRuntimeError("table:from-json expected string key in object"))
    key = json_parse_string!(p)
    json_skip_ws!(p)
    (p.pos > length(p.s) || p.s[p.pos] != ':') &&
      throw(LogoRuntimeError("table:from-json expected ':' after key"))
    p.pos += 1
    val = json_parse_value!(p)
    table_put!(t, key, val)
    c = json_peek(p)
    if c == '}';    p.pos += 1; return t
    elseif c == ','; p.pos += 1
    else throw(LogoRuntimeError("table:from-json expected ',' or '}' in object"))
    end
  end
end

function json_parse_array!(p::JsonParser)
  p.pos += 1  # skip '['
  result = Any[]
  json_peek(p) == ']' && (p.pos += 1; return result)
  while true
    push!(result, json_parse_value!(p))
    c = json_peek(p)
    if c == ']';    p.pos += 1; return result
    elseif c == ','; p.pos += 1
    else throw(LogoRuntimeError("table:from-json expected ',' or ']' in array"))
    end
  end
end

function json_to_logo(json_str::AbstractString)
  p = JsonParser(json_str)
  result = json_parse_value!(p)
  json_skip_ws!(p)
  p.pos <= length(p.s) && throw(LogoRuntimeError("table:from-json unexpected content after value"))
  result
end

function register_extension!(registry::PrimitiveRegistry)
  register_primitive!(registry, "TABLE:MAKE", REPORTER,
    reporter_syntax(ret=WildcardType),
    (ctx, args) -> LogoTable())

  register_primitive!(registry, "TABLE:MAKE-FROM", REPORTER,
    reporter_syntax(right=[ListType], ret=WildcardType),
    (ctx, args) -> table_from_list(args[1]))

  register_primitive!(registry, "TABLE:FROM-LIST", REPORTER,
    reporter_syntax(right=[ListType], ret=WildcardType),
    (ctx, args) -> table_from_list(args[1]))

  register_primitive!(registry, "TABLE:GET", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:get expected a table as the first input"))
      table_get(args[1], args[2])
    end)

  register_primitive!(registry, "TABLE:GET-OR-DEFAULT", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:get-or-default expected a table as the first input"))
      table_get_or_default(args[1], args[2], args[3])
    end)

  register_primitive!(registry, "TABLE:HAS-KEY?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:has-key? expected a table as the first input"))
      table_has_key(args[1], args[2])
    end)

  register_primitive!(registry, "TABLE:PUT", COMMAND,
    command_syntax(right=[WildcardType, WildcardType, WildcardType]),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:put expected a table as the first input"))
      table_put!(args[1], args[2], args[3])
    end)

  register_primitive!(registry, "TABLE:REMOVE", COMMAND,
    command_syntax(right=[WildcardType, WildcardType]),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:remove expected a table as the first input"))
      table_remove!(args[1], args[2])
    end)

  register_primitive!(registry, "TABLE:CLEAR", COMMAND,
    command_syntax(right=[WildcardType]),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:clear expected a table as the first input"))
      empty!(args[1].entries)
      nothing
    end)

  register_primitive!(registry, "TABLE:KEYS", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:keys expected a table as the first input"))
      table_keys(args[1])
    end)

  register_primitive!(registry, "TABLE:VALUES", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:values expected a table as the first input"))
      table_values(args[1])
    end)

  register_primitive!(registry, "TABLE:LENGTH", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:length expected a table as the first input"))
      Float64(length(args[1].entries))
    end)

  register_primitive!(registry, "TABLE:TO-LIST", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:to-list expected a table as the first input"))
      table_to_list(args[1])
    end)

  register_primitive!(registry, "TABLE:COUNTS", REPORTER,
    reporter_syntax(right=[ListType], ret=WildcardType),
    (ctx, args) -> table_counts(args[1]))

  register_primitive!(registry, "TABLE:GROUP-ITEMS", REPORTER,
    reporter_syntax(right=[ListType, WildcardType], ret=WildcardType, arg_modes=[:eval, :reporter_task]),
    (ctx, args) -> begin
      args[1] isa AbstractVector || throw(LogoRuntimeError("table:group-items expected a list as the first input"))
      table_group_items(ctx, args[1], args[2])
    end)

  register_primitive!(registry, "TABLE:GROUP-AGENTS", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType, arg_modes=[:eval, :reporter_task]),
    (ctx, args) -> begin
      args[1] isa AgentSet || throw(LogoRuntimeError("table:group-agents expected an agentset as the first input"))
      table_group_agents(ctx, args[1], args[2])
    end)

  register_primitive!(registry, "TABLE:TO-JSON", REPORTER,
    reporter_syntax(right=[WildcardType], ret=StringType),
    (ctx, args) -> begin
      args[1] isa LogoTable || throw(LogoRuntimeError("table:to-json expected a table as the first input"))
      logo_to_json(args[1])
    end)

  register_primitive!(registry, "TABLE:FROM-JSON", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> begin
      result = json_to_logo(args[1])
      result isa LogoTable || throw(LogoRuntimeError("table:from-json expected a JSON object at top level"))
      result
    end)

  register_primitive!(registry, "TABLE:FROM-JSON-FILE", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> begin
      filepath = resolve_file_path(String(args[1]))
      isfile(filepath) || throw(LogoRuntimeError("table:from-json-file file not found: $(args[1])"))
      json_str = read(filepath, String)
      result = json_to_logo(json_str)
      result isa LogoTable || throw(LogoRuntimeError("table:from-json-file expected a JSON object at top level"))
      result
    end)
end

end # module table
