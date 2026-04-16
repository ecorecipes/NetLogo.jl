# ─── System Dynamics section parser & code generator ─────────────────────────
#
# Parses section 6 of .nlogo files (the SD modeler drawing data) and generates
# NetLogo code equivalent to what NetLogo's Translator.scala produces:
#   - globals for stocks, constant converters, and dt
#   - system-dynamics-setup / system-dynamics-go / system-dynamics-do-plot
#   - reporter procedures for rates and non-constant converters

struct SDStock
  name::String
  initial_value::String
  non_negative::Bool
end

struct SDRate
  name::String
  expression::String
  source::Union{String, Nothing}   # stock name or nothing (reservoir)
  sink::Union{String, Nothing}     # stock name or nothing (reservoir)
end

struct SDConverter
  name::String
  expression::String
  is_constant::Bool
end

"""
    extract_sd_section(source::String) -> String

Pull section 6 (0-indexed) from a full .nlogo file.
Returns empty string if the section doesn't exist or is blank.
"""
function extract_sd_section(source::AbstractString)
  sections = split(source, MODEL_SECTION_DELIMITER)
  length(sections) > 6 ? String(strip(sections[7])) : ""
end

"""
    parse_sd_section(sd_text::AbstractString) -> String

Parse the System Dynamics section text and return generated NetLogo code.
Returns empty string if the section is empty or does not contain SD data.
Throws when the section looks like SD data but is malformed.
"""
function parse_sd_section(sd_text::AbstractString)
  text = String(strip(sd_text))
  isempty(text) && return ""
  occursin("org.nlogo.sdm.gui.AggregateDrawing", text) || return ""

  lines = split(text, '\n')
  isempty(lines) && return ""

  # First non-blank line is the dt value
  dt_str = String(strip(lines[1]))
  dt_val = tryparse(Float64, dt_str)
  (dt_val === nothing || dt_val <= 0) &&
    throw(LogoRuntimeError("Could not parse System Dynamics section: invalid dt '$dt_str'"))

  # Build line map and parse elements
  stocks = SDStock[]
  rates_raw = Tuple{Int, String, String}[]  # (line_idx, expression, name)
  rate_extra_tokens = Dict{Int, Vector{String}}()   # line_idx -> remaining tokens after name
  converters = SDConverter[]

  # Maps: line_number -> type marker
  stock_figure_lines = Dict{Int, String}()    # line_num -> stock name (resolved later)
  reservoir_figure_lines = Set{Int}()

  # First pass: identify all elements
  for (i, line) in enumerate(lines)
    s = strip(String(line))

    if contains(s, "org.nlogo.sdm.gui.StockFigure")
      stock_figure_lines[i] = ""  # placeholder
    elseif contains(s, "org.nlogo.sdm.gui.ReservoirFigure") && !contains(s, "WrappedReservoir")
      push!(reservoir_figure_lines, i)
    elseif contains(s, "org.nlogo.sdm.gui.WrappedStock")
      name, initial_expr, non_neg = _parse_wrapped_stock(s)
      name !== nothing ||
        throw(LogoRuntimeError("Could not parse System Dynamics section: invalid stock definition on line $i"))
      push!(stocks, SDStock(name, initial_expr, non_neg))
      # Associate with parent StockFigure (previous line usually)
      if haskey(stock_figure_lines, i - 1)
        stock_figure_lines[i - 1] = name
      end
    elseif contains(s, "org.nlogo.sdm.gui.WrappedRate")
      name, expr, extra = _parse_wrapped_rate(s)
      name !== nothing ||
        throw(LogoRuntimeError("Could not parse System Dynamics section: invalid rate definition on line $i"))
      push!(rates_raw, (i, expr, name))
      rate_extra_tokens[i] = extra
    elseif contains(s, "org.nlogo.sdm.gui.WrappedConverter")
      name, expr = _parse_wrapped_converter(s)
      name !== nothing ||
        throw(LogoRuntimeError("Could not parse System Dynamics section: invalid converter definition on line $i"))
      is_const = _is_constant_expression(expr)
      push!(converters, SDConverter(name, expr, is_const))
    end
  end

  # Build ref lookup: REF number -> stock name
  # REF N refers to line N (1-indexed in the section, i.e. lines[N+1] in 1-indexed Julia)
  # The actual WrappedStock is at line N+1, but StockFigure is at line N.
  # In the SD format, REF numbers correspond to 0-based line indices from after the first line.
  # Actually REF numbers are 1-based indices into the child elements of AggregateDrawing.
  # Let me just build a map from line_index -> stock_name for both StockFigure and ReservoirFigure

  ref_map = Dict{Int, Union{String, Symbol}}()  # line_index -> stock_name or :reservoir
  for (li, sname) in stock_figure_lines
    ref_map[li] = sname
  end
  for li in reservoir_figure_lines
    ref_map[li] = :reservoir
  end

  # Resolve rate source/sink
  rates = SDRate[]
  for (line_idx, expr, name) in rates_raw
    source, sink = _resolve_rate_source_sink(line_idx, rate_extra_tokens, lines, ref_map)
    push!(rates, SDRate(name, expr, source, sink))
  end

  # Generate code
  _generate_sd_code(dt_str, stocks, rates, converters)
end

function _parse_quoted_strings(s::AbstractString)
  # Extract all quoted strings from a line, handling escaped quotes
  results = String[]
  i = 1
  while i <= lastindex(s)
    if s[i] == '"'
      j = i + 1
      buf = IOBuffer()
      while j <= lastindex(s) && s[j] != '"'
        if s[j] == '\\' && j + 1 <= lastindex(s)
          c = s[j + 1]
          if c == 'n'
            write(buf, '\n')
          elseif c == '"'
            write(buf, '"')
          elseif c == '\\'
            write(buf, '\\')
          elseif c == 't'
            write(buf, '\t')
          else
            write(buf, '\\')
            write(buf, c)
          end
          j += 2
        else
          write(buf, s[j])
          j += 1
        end
      end
      j <= lastindex(s) || return nothing
      push!(results, String(take!(buf)))
      i = j + 1
    else
      i = nextind(s, i)
    end
  end
  results
end

function _parse_wrapped_stock(s::AbstractString)
  qs = _parse_quoted_strings(s)
  qs === nothing && return (nothing, "", false)
  length(qs) < 2 && return (nothing, "", false)
  name = qs[1]
  initial_expr = qs[2]
  last_quote_end = findlast('"', s)
  last_quote_end === nothing && return (nothing, "", false)
  extra_str = strip(s[nextind(s, last_quote_end):end])
  tokens = isempty(extra_str) ? String[] : String.(split(extra_str))
  isempty(tokens) && return (nothing, "", false)
  flag = tryparse(Int, last(tokens))
  (flag === nothing || !(flag in (0, 1))) && return (nothing, "", false)
  non_neg = flag == 1
  (name, initial_expr, non_neg)
end

function _parse_wrapped_rate(s::AbstractString)
  qs = _parse_quoted_strings(s)
  qs === nothing && return (nothing, "", String[])
  length(qs) < 2 && return (nothing, "", String[])
  expr = qs[1]
  name = qs[2]
  # Extract remaining tokens after the last quoted string
  last_quote_end = findlast('"', s)
  extra_str = last_quote_end !== nothing ? strip(s[nextind(s, last_quote_end):end]) : ""
  extra = isempty(extra_str) ? String[] : String.(split(extra_str))
  (name, expr, extra)
end

function _parse_wrapped_converter(s::AbstractString)
  qs = _parse_quoted_strings(s)
  qs === nothing && return (nothing, "")
  length(qs) < 2 && return (nothing, "")
  (qs[2], qs[1])  # name is second, expression is first
end

function _is_constant_expression(expr::AbstractString)
  source = strip(String(expr))
  isempty(source) && return false
  try
    read_literal_from_string(source)
    true
  catch err
    err isa LiteralParseError && return false
    rethrow()
  end
end

function _sort_sd_stocks(stocks::Vector{SDStock})
  sort(
    copy(stocks);
    by=s -> (_is_constant_expression(s.initial_value) ? 0 : 1, uppercase(s.name)))
end

function _resolve_rate_source_sink(
  rate_line_idx::Int,
  rate_extra_tokens::Dict{Int, Vector{String}},
  lines::AbstractVector,
  ref_map::Dict{Int, Union{String, Symbol}}
)
  extra = get(rate_extra_tokens, rate_line_idx, String[])

  # Count REF pairs on the rate line itself
  rate_refs = Int[]
  i = 1
  while i <= length(extra)
    if uppercase(extra[i]) == "REF" && i + 1 <= length(extra)
      ref_num = tryparse(Int, extra[i + 1])
      ref_num !== nothing && push!(rate_refs, ref_num)
      i += 2
    else
      i += 1
    end
  end

  # Check if next line is a WrappedReservoir
  reservoir_line_idx = rate_line_idx + 1
  reservoir_line = reservoir_line_idx <= length(lines) ? strip(String(lines[reservoir_line_idx])) : ""
  has_reservoir = contains(reservoir_line, "WrappedReservoir")

  if length(rate_refs) >= 2
    # Both source and sink are stocks (Pattern 1)
    source = _lookup_ref(rate_refs[1], ref_map)
    sink = _lookup_ref(rate_refs[2], ref_map)
    return (source, sink)
  end

  if has_reservoir
    # Parse reservoir line for REF tokens and standalone numbers
    res_tokens = String.(split(reservoir_line))
    # Skip past "org.nlogo.sdm.gui.WrappedReservoir"
    start_idx = 1
    for j in eachindex(res_tokens)
      if contains(res_tokens[j], "WrappedReservoir")
        start_idx = j + 1
        break
      end
    end
    res_remaining = res_tokens[start_idx:end]

    # Collect REF numbers from reservoir line
    res_refs = Int[]
    standalone_nums = Int[]
    j = 1
    while j <= length(res_remaining)
      if uppercase(res_remaining[j]) == "REF" && j + 1 <= length(res_remaining)
        ref_num = tryparse(Int, res_remaining[j + 1])
        ref_num !== nothing && push!(res_refs, ref_num)
        j += 2
      else
        num = tryparse(Int, res_remaining[j])
        num !== nothing && push!(standalone_nums, num)
        j += 1
      end
    end

    if length(rate_refs) == 1
      # Pattern 3: Rate has 1 REF (source stock), reservoir indicates sink is reservoir
      source = _lookup_ref(rate_refs[1], ref_map)
      return (source, nothing)
    else
      # Pattern 2: Rate has 0 REFs, reservoir has REF for the stock
      if !isempty(res_refs)
        sink = _lookup_ref(res_refs[1], ref_map)
        return (nothing, sink)
      end
    end
  end

  # Fallback: no source/sink resolvable
  (nothing, nothing)
end

function _lookup_ref(ref_num::Int, ref_map::Dict{Int, Union{String, Symbol}})
  # REF N: the element is at line index N (1-based from the SD lines array).
  # StockFigure is at line N, WrappedStock (with the name) is at line N+1.
  # But we indexed StockFigure lines in the ref_map.
  # The ref_num corresponds to line index in 1-based indexing of the lines array
  # (since lines[1] is the dt line, and lines[2] is the AggregateDrawing line,
  #  the actual children start at line 3 which would be index 3 in 1-based).
  # Actually, REF numbers appear to be 1-based indices into the children of AggregateDrawing.
  #
  # Looking at the data: For Exponential Growth,
  #   Line 1 (0-based): dt=0.001
  #   Line 2 (0-based): AggregateDrawing
  #   Line 3 (0-based): StockFigure  -> this is child 1
  #   Line 4 (0-based): WrappedStock
  #   Line 5 (0-based): ReservoirFigure -> this is child 2
  # REF 2 points to ReservoirFigure (line index 5 in 0-based, or 4 in 0-based from children)
  #
  # Actually from the Python analysis, using 0-based from the start of the section:
  #   Line 2 (0-based) = StockFigure
  #   Line 4 (0-based) = ReservoirFigure
  #   REF 2 with +1 = line 3 (0-based) = WrappedStock "stock"
  # No wait, the Python showed:
  #   REF 2, resolved as stock at REF+1=3 which is WrappedStock
  # But we want StockFigure at line 2 (which maps to stock name "stock").
  #
  # So REF N maps to line index N (1-based) in the lines array, which is
  # index (N+1) in 1-based Julia indexing (since Julia lines[1] = line 0 of 0-based).
  #
  # Actually, let me re-check. The ref_map uses the Julia enumerate index (1-based).
  # In the parsing loop, `for (i, line) in enumerate(lines)`, i goes from 1.
  # Line 1 (i=1) = dt
  # Line 2 (i=2) = AggregateDrawing
  # Line 3 (i=3) = StockFigure   <- stock_figure_lines[3] = "stock"
  # Line 4 (i=4) = WrappedStock
  # Line 5 (i=5) = ReservoirFigure  <- reservoir_figure_lines has 5
  #
  # From the 0-based Python analysis:
  #   StockFigure at 0-based line 2, which is Julia 1-based line 3
  #   ReservoirFigure at 0-based line 4, which is Julia 1-based line 5
  #   REF 2 -> corresponds to 0-based line 2 -> Julia 1-based line 3
  #
  # So REF N (from the file) = 0-based line N = Julia 1-based line N+1
  # The StockFigure is at Julia index ref_num + 1
  julia_idx = ref_num + 1
  val = get(ref_map, julia_idx, nothing)
  if val === nothing
    return nothing
  elseif val === :reservoir
    return nothing
  else
    return val::String
  end
end

function _generate_sd_code(
  dt_str::AbstractString,
  stocks::Vector{SDStock},
  rates::Vector{SDRate},
  converters::Vector{SDConverter}
)
  io = IOBuffer()

  constant_converters = filter(c -> c.is_constant, converters)
  variable_converters = filter(c -> !c.is_constant, converters)
  sorted_stocks = _sort_sd_stocks(stocks)

  # ── globals ──
  global_names = String[]
  for c in sort(constant_converters; by=c -> c.name)
    push!(global_names, c.name)
  end
  for s in sorted_stocks
    push!(global_names, s.name)
  end
  push!(global_names, "dt")

  println(io, "globals [")
  for g in global_names
    println(io, "  ", g)
  end
  println(io, "]")
  println(io)

  # ── system-dynamics-setup ──
  println(io, "to system-dynamics-setup")
  println(io, "  reset-ticks")
  println(io, "  set dt ", dt_str)
  for c in sort(constant_converters; by=c -> c.name)
    println(io, "  set ", c.name, " ", c.expression)
  end
  for s in sorted_stocks
    println(io, "  set ", s.name, " ", s.initial_value)
  end
  println(io, "end")
  println(io)

  # ── system-dynamics-go ──
  println(io, "to system-dynamics-go")

  # Compute variable converters and rates as local variables
  for c in sort(variable_converters; by=c -> c.name)
    println(io, "  let local-", c.name, " ", c.name)
  end
  for r in sort(rates; by=r -> r.name)
    println(io, "  let local-", r.name, " ", r.name)
  end

  # Build inflows/outflows per stock
  stock_inflows = Dict{String, Vector{String}}()
  stock_outflows = Dict{String, Vector{String}}()
  for s in stocks
    stock_inflows[s.name] = String[]
    stock_outflows[s.name] = String[]
  end
  for r in rates
    if r.source !== nothing && haskey(stock_outflows, r.source)
      push!(stock_outflows[r.source], r.name)
    end
    if r.sink !== nothing && haskey(stock_inflows, r.sink)
      push!(stock_inflows[r.sink], r.name)
    end
  end

  # Update stock values
  for s in sorted_stocks
    inflows = get(stock_inflows, s.name, String[])
    outflows = get(stock_outflows, s.name, String[])

    # Build the expression: stock + inflows - outflows
    parts = String[s.name]
    for inf in sort(inflows)
      push!(parts, "+ local-" * inf)
    end
    for outf in sort(outflows)
      push!(parts, "- local-" * outf)
    end
    inner = "( " * join(parts, " ") * " )"

    if s.non_negative
      println(io, "  let new-", s.name, " max( list 0 ", inner, " )")
    else
      println(io, "  let new-", s.name, " ", inner)
    end
  end

  for s in sorted_stocks
    println(io, "  set ", s.name, " new-", s.name)
  end

  println(io, "  tick-advance dt")
  println(io, "end")
  println(io)

  # ── system-dynamics-do-plot ──
  println(io, "to system-dynamics-do-plot")
  for s in sorted_stocks
    println(io, "  if plot-pen-exists? \"", s.name, "\" [")
    println(io, "    set-current-plot-pen \"", s.name, "\"")
    println(io, "    plotxy ticks ", s.name)
    println(io, "  ]")
  end
  println(io, "end")
  println(io)

  # ── Rate reporters ──
  for r in sort(rates; by=r -> r.name)
    println(io, "to-report ", r.name)
    println(io, "  report ( ", r.expression, " ) * dt")
    println(io, "end")
    println(io)
  end

  # ── Variable converter reporters ──
  for c in sort(variable_converters; by=c -> c.name)
    println(io, "to-report ", c.name)
    println(io, "  report ", c.expression)
    println(io, "end")
    println(io)
  end

  String(take!(io))
end
