module csv

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  LogoRuntimeError, logo_string, is_logo_number, numeric

function register_extension!(registry::PrimitiveRegistry)
  register_primitive!(registry, "CSV:FROM-ROW", REPORTER,
    reporter_syntax(right=[StringType], ret=ListType),
    (ctx, args) -> csv_from_row(String(args[1]), ","))

  register_primitive!(registry, "CSV:FROM-ROW-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[StringType, StringType], ret=ListType),
    (ctx, args) -> csv_from_row(String(args[1]), String(args[2])))

  register_primitive!(registry, "CSV:FROM-STRING", REPORTER,
    reporter_syntax(right=[StringType], ret=ListType),
    (ctx, args) -> csv_from_string(String(args[1]), ","))

  register_primitive!(registry, "CSV:FROM-STRING-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[StringType, StringType], ret=ListType),
    (ctx, args) -> csv_from_string(String(args[1]), String(args[2])))

  register_primitive!(registry, "CSV:TO-ROW", REPORTER,
    reporter_syntax(right=[ListType], ret=StringType),
    (ctx, args) -> csv_to_row(args[1], ","))

  register_primitive!(registry, "CSV:TO-ROW-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[ListType, StringType], ret=StringType),
    (ctx, args) -> csv_to_row(args[1], String(args[2])))

  register_primitive!(registry, "CSV:TO-STRING", REPORTER,
    reporter_syntax(right=[ListType], ret=StringType),
    (ctx, args) -> csv_to_string(args[1], ","))

  register_primitive!(registry, "CSV:TO-STRING-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[ListType, StringType], ret=StringType),
    (ctx, args) -> csv_to_string(args[1], String(args[2])))
end

function csv_parse_value(field::AbstractString)
  stripped = strip(field)
  isempty(stripped) && return ""
  if stripped == "true"
    return true
  elseif stripped == "false"
    return false
  end
  parsed = tryparse(Float64, stripped)
  parsed !== nothing && return parsed
  String(stripped)
end

function csv_split_row(line::AbstractString, delimiter::AbstractString)
  delim_char = isempty(delimiter) ? ',' : first(delimiter)
  fields = String[]
  current = IOBuffer()
  in_quotes = false
  chars = collect(line)
  i = 1
  while i <= length(chars)
    c = chars[i]
    if in_quotes
      if c == '"'
        if i < length(chars) && chars[i + 1] == '"'
          write(current, '"')
          i += 1
        else
          in_quotes = false
        end
      else
        write(current, c)
      end
    else
      if c == '"'
        in_quotes = true
      elseif c == delim_char
        push!(fields, String(take!(current)))
      else
        write(current, c)
      end
    end
    i += 1
  end
  push!(fields, String(take!(current)))
  fields
end

function csv_from_row(line::AbstractString, delimiter::AbstractString)
  fields = csv_split_row(line, delimiter)
  Any[csv_parse_value(f) for f in fields]
end

function csv_from_string(text::AbstractString, delimiter::AbstractString)
  lines = split(rstrip(text), '\n')
  Any[csv_from_row(line, delimiter) for line in lines]
end

function csv_quote_field(value, delimiter::AbstractString)
  str = if value isa Bool
    value ? "true" : "false"
  elseif is_logo_number(value)
    v = numeric(value)
    isinteger(v) ? string(Int(v)) : string(v)
  elseif value isa AbstractString
    String(value)
  elseif value isa AbstractVector
    logo_string(value)
  else
    logo_string(value)
  end
  delim_char = isempty(delimiter) ? ',' : first(delimiter)
  if contains(str, delim_char) || contains(str, '"') || contains(str, '\n')
    return "\"" * replace(str, "\"" => "\"\"") * "\""
  end
  str
end

function csv_to_row(values, delimiter::AbstractString)
  values isa AbstractVector || throw(LogoRuntimeError("csv:to-row expected a list"))
  join((csv_quote_field(v, delimiter) for v in values), delimiter)
end

function csv_to_string(rows, delimiter::AbstractString)
  rows isa AbstractVector || throw(LogoRuntimeError("csv:to-string expected a list of lists"))
  join((csv_to_row(row, delimiter) for row in rows), "\n")
end

end # module csv
