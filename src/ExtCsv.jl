module csv

using CSV: CSV as CSVLib
using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  LogoRuntimeError, logo_string, is_logo_number, numeric,
  resolve_file_path

function register_extension!(registry::PrimitiveRegistry)
  # ── row primitives ─────────────────────────────────────────────────
  register_primitive!(registry, "CSV:FROM-ROW", REPORTER,
    reporter_syntax(right=[StringType], ret=ListType),
    (ctx, args) -> csv_from_row(String(args[1]), ","))

  register_primitive!(registry, "CSV:FROM-ROW-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[StringType, StringType], ret=ListType),
    (ctx, args) -> csv_from_row(String(args[1]), String(args[2])))

  register_primitive!(registry, "CSV:TO-ROW", REPORTER,
    reporter_syntax(right=[ListType], ret=StringType),
    (ctx, args) -> csv_to_row(args[1], ","))

  register_primitive!(registry, "CSV:TO-ROW-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[ListType, StringType], ret=StringType),
    (ctx, args) -> csv_to_row(args[1], String(args[2])))

  # ── string primitives ──────────────────────────────────────────────
  register_primitive!(registry, "CSV:FROM-STRING", REPORTER,
    reporter_syntax(right=[StringType], ret=ListType),
    (ctx, args) -> csv_from_string(String(args[1]), ","))

  register_primitive!(registry, "CSV:FROM-STRING-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[StringType, StringType], ret=ListType),
    (ctx, args) -> csv_from_string(String(args[1]), String(args[2])))

  register_primitive!(registry, "CSV:TO-STRING", REPORTER,
    reporter_syntax(right=[ListType], ret=StringType),
    (ctx, args) -> csv_to_string(args[1], ","))

  register_primitive!(registry, "CSV:TO-STRING-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[ListType, StringType], ret=StringType),
    (ctx, args) -> csv_to_string(args[1], String(args[2])))

  # ── file primitives ────────────────────────────────────────────────
  register_primitive!(registry, "CSV:FROM-FILE", REPORTER,
    reporter_syntax(right=[StringType], ret=ListType),
    (ctx, args) -> csv_from_file(String(args[1]), ','))

  register_primitive!(registry, "CSV:FROM-FILE-WITH-DELIMITER", REPORTER,
    reporter_syntax(right=[StringType, StringType], ret=ListType),
    (ctx, args) -> csv_from_file(String(args[1]), first(String(args[2]))))

  register_primitive!(registry, "CSV:TO-FILE", COMMAND,
    command_syntax(right=[StringType, ListType]),
    (ctx, args) -> begin csv_to_file(String(args[1]), args[2], ','); nothing end)

  register_primitive!(registry, "CSV:TO-FILE-WITH-DELIMITER", COMMAND,
    command_syntax(right=[StringType, ListType, StringType]),
    (ctx, args) -> begin csv_to_file(String(args[1]), args[2], first(String(args[3]))); nothing end)
end

# ── value coercion (NetLogo semantics) ───────────────────────────────
function csv_parse_value(field::AbstractString)
  stripped = strip(field)
  isempty(stripped) && return ""
  stripped == "true"  && return true
  stripped == "false" && return false
  parsed = tryparse(Float64, stripped)
  parsed !== nothing && return parsed
  String(stripped)
end

# ── CSV.jl–backed row splitting ──────────────────────────────────────
function csv_split_row_csvjl(line::AbstractString, delim::Char)
  rows = CSVLib.File(IOBuffer(line); header=false, delim=delim,
                     types=String, silencewarnings=true)
  isempty(rows) && return String[""]
  row = first(rows)
  String[something(row[i], "") for i in 1:length(CSVLib.getnames(rows))]
end

function csv_from_row(line::AbstractString, delimiter::AbstractString)
  delim = isempty(delimiter) ? ',' : first(delimiter)
  fields = csv_split_row_csvjl(line, delim)
  Any[csv_parse_value(f) for f in fields]
end

function csv_from_string(text::AbstractString, delimiter::AbstractString)
  delim = isempty(delimiter) ? ',' : first(delimiter)
  rows = CSVLib.File(IOBuffer(rstrip(text)); header=false, delim=delim,
                     types=String, silencewarnings=true)
  ncols = length(CSVLib.getnames(rows))
  result = Any[]
  for row in rows
    push!(result, Any[csv_parse_value(something(row[i], "")) for i in 1:ncols])
  end
  result
end

# ── file I/O ─────────────────────────────────────────────────────────
function csv_from_file(path::AbstractString, delim::Char)
  resolved = resolve_file_path(path)
  isfile(resolved) || throw(LogoRuntimeError("csv:from-file: file not found: \"$path\""))
  rows = CSVLib.File(resolved; header=false, delim=delim,
                     types=String, silencewarnings=true)
  ncols = length(CSVLib.getnames(rows))
  result = Any[]
  for row in rows
    push!(result, Any[csv_parse_value(something(row[i], "")) for i in 1:ncols])
  end
  result
end

function csv_to_file(path::AbstractString, data, delim::Char)
  data isa AbstractVector || throw(LogoRuntimeError("csv:to-file expected a list of lists"))
  resolved = resolve_file_path(path)
  mkpath(dirname(resolved))
  delimiter = string(delim)
  open(resolved, "w") do io
    for (i, row) in enumerate(data)
      write(io, csv_to_row(row, delimiter))
      i < length(data) && write(io, '\n')
    end
  end
  nothing
end

# ── output formatting ────────────────────────────────────────────────
function csv_quote_field(value, delimiter::AbstractString)
  str = if value isa Bool
    value ? "true" : "false"
  elseif is_logo_number(value)
    v = numeric(value)
    isinteger(v) ? string(Int(v)) : string(v)
  elseif value isa AbstractString
    String(value)
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
