module matrix

using LinearAlgebra
import ..NetLogo: logo_string
using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType, CommandBlockType,
  ReporterBlockType,
  LogoRuntimeError, error_logo_string, Context,
  is_logo_number, numeric,
  AbstractReporterTaskValue, invoke_reporter_task

# ---------------------------------------------------------------------------
# LogoMatrix wrapper
# ---------------------------------------------------------------------------

mutable struct LogoMatrix
  data::Matrix{Float64}
end

function logo_string(m::LogoMatrix)
  rows, cols = size(m.data)
  parts = String[]
  for r in 1:rows
    row_str = join((error_logo_string(m.data[r, c]) for c in 1:cols), " ")
    push!(parts, "[ $row_str ]")
  end
  "{{matrix:  [ " * join(parts, " ") * " ]}}"
end

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function ensure_matrix(val, prim::String)
  val isa LogoMatrix || throw(LogoRuntimeError("$prim expected a matrix"))
  val
end

function check_row(m::LogoMatrix, r, prim::String)
  rows = size(m.data, 1)
  ri = Int(r)
  (ri < 0 || ri >= rows) &&
    throw(LogoRuntimeError("$prim: row index $ri is out of range [0, $(rows - 1)]"))
  ri + 1
end

function check_col(m::LogoMatrix, c, prim::String)
  cols = size(m.data, 2)
  ci = Int(c)
  (ci < 0 || ci >= cols) &&
    throw(LogoRuntimeError("$prim: column index $ci is out of range [0, $(cols - 1)]"))
  ci + 1
end

function nested_list_to_matrix(lst, prim::String)
  lst isa AbstractVector || throw(LogoRuntimeError("$prim expected a list of lists"))
  isempty(lst) && throw(LogoRuntimeError("$prim: list is empty"))
  rows = length(lst)
  first_row = lst[1]
  first_row isa AbstractVector || throw(LogoRuntimeError("$prim expected a list of lists"))
  cols = length(first_row)
  cols == 0 && throw(LogoRuntimeError("$prim: row length is 0"))
  mat = zeros(Float64, rows, cols)
  for r in 1:rows
    row = lst[r]
    row isa AbstractVector || throw(LogoRuntimeError("$prim expected a list of lists"))
    length(row) != cols &&
      throw(LogoRuntimeError("$prim: all rows must be the same length"))
    for c in 1:cols
      mat[r, c] = numeric(row[c])
    end
  end
  mat
end

function matrix_to_row_list(m::LogoMatrix)
  rows, cols = size(m.data)
  Any[Any[m.data[r, c] for c in 1:cols] for r in 1:rows]
end

function matrix_to_column_list(m::LogoMatrix)
  rows, cols = size(m.data)
  Any[Any[m.data[r, c] for r in 1:rows] for c in 1:cols]
end

# Simple linear regression helper: y = a + b*x
# Returns (constant, slope, R²)
function simple_linear_regression(ys::Vector{Float64})
  n = length(ys)
  n < 2 && return (ys[1], 0.0, 0.0)
  xs = collect(0.0:(n - 1))
  x_mean = mean(xs)
  y_mean = mean(ys)
  ss_xy = sum((xs .- x_mean) .* (ys .- y_mean))
  ss_xx = sum((xs .- x_mean) .^ 2)
  slope = ss_xx == 0.0 ? 0.0 : ss_xy / ss_xx
  constant = y_mean - slope * x_mean
  ss_tot = sum((ys .- y_mean) .^ 2)
  ss_res = sum((ys .- (constant .+ slope .* xs)) .^ 2)
  r_squared = ss_tot == 0.0 ? 0.0 : 1.0 - ss_res / ss_tot
  (constant, slope, r_squared)
end

function mean(v)
  sum(v) / length(v)
end

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

function register_extension!(registry::PrimitiveRegistry)

  # =========================================================================
  # Construction
  # =========================================================================

  register_primitive!(registry, "MATRIX:FROM-ROW-LIST", REPORTER,
    reporter_syntax(right=[ListType], ret=WildcardType),
    (ctx, args) -> LogoMatrix(nested_list_to_matrix(args[1], "matrix:from-row-list")))

  register_primitive!(registry, "MATRIX:FROM-COLUMN-LIST", REPORTER,
    reporter_syntax(right=[ListType], ret=WildcardType),
    (ctx, args) -> begin
      mat = nested_list_to_matrix(args[1], "matrix:from-column-list")
      LogoMatrix(permutedims(mat))
    end)

  register_primitive!(registry, "MATRIX:MAKE-CONSTANT", REPORTER,
    reporter_syntax(right=[NumberType, NumberType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      rows = Int(args[1])
      cols = Int(args[2])
      val = numeric(args[3])
      (rows < 1 || cols < 1) && throw(LogoRuntimeError("matrix:make-constant: dimensions must be positive"))
      LogoMatrix(fill(val, rows, cols))
    end)

  register_primitive!(registry, "MATRIX:MAKE-IDENTITY", REPORTER,
    reporter_syntax(right=[NumberType], ret=WildcardType),
    (ctx, args) -> begin
      n = Int(args[1])
      n < 1 && throw(LogoRuntimeError("matrix:make-identity: size must be positive"))
      LogoMatrix(Matrix{Float64}(I, n, n))
    end)

  register_primitive!(registry, "MATRIX:COPY", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:copy")
      LogoMatrix(copy(m.data))
    end)

  # =========================================================================
  # Access (0-based indexing from NetLogo)
  # =========================================================================

  register_primitive!(registry, "MATRIX:GET", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, NumberType], ret=NumberType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:get")
      jr = check_row(m, args[2], "matrix:get")
      jc = check_col(m, args[3], "matrix:get")
      m.data[jr, jc]
    end)

  register_primitive!(registry, "MATRIX:SET", COMMAND,
    command_syntax(right=[WildcardType, NumberType, NumberType, NumberType]),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:set")
      jr = check_row(m, args[2], "matrix:set")
      jc = check_col(m, args[3], "matrix:set")
      m.data[jr, jc] = numeric(args[4])
      nothing
    end)

  register_primitive!(registry, "MATRIX:GET-ROW", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:get-row")
      jr = check_row(m, args[2], "matrix:get-row")
      Any[m.data[jr, c] for c in 1:size(m.data, 2)]
    end)

  register_primitive!(registry, "MATRIX:GET-COLUMN", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:get-column")
      jc = check_col(m, args[2], "matrix:get-column")
      Any[m.data[r, jc] for r in 1:size(m.data, 1)]
    end)

  register_primitive!(registry, "MATRIX:SET-ROW", COMMAND,
    command_syntax(right=[WildcardType, NumberType, ListType]),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:set-row")
      jr = check_row(m, args[2], "matrix:set-row")
      lst = args[3]
      length(lst) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:set-row: list length $(length(lst)) does not match column count $(size(m.data, 2))"))
      for c in 1:size(m.data, 2)
        m.data[jr, c] = numeric(lst[c])
      end
      nothing
    end)

  register_primitive!(registry, "MATRIX:SET-COLUMN", COMMAND,
    command_syntax(right=[WildcardType, NumberType, ListType]),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:set-column")
      jc = check_col(m, args[2], "matrix:set-column")
      lst = args[3]
      length(lst) != size(m.data, 1) &&
        throw(LogoRuntimeError("matrix:set-column: list length $(length(lst)) does not match row count $(size(m.data, 1))"))
      for r in 1:size(m.data, 1)
        m.data[r, jc] = numeric(lst[r])
      end
      nothing
    end)

  register_primitive!(registry, "MATRIX:SWAP-ROWS", COMMAND,
    command_syntax(right=[WildcardType, NumberType, NumberType]),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:swap-rows")
      jr1 = check_row(m, args[2], "matrix:swap-rows")
      jr2 = check_row(m, args[3], "matrix:swap-rows")
      for c in 1:size(m.data, 2)
        m.data[jr1, c], m.data[jr2, c] = m.data[jr2, c], m.data[jr1, c]
      end
      nothing
    end)

  register_primitive!(registry, "MATRIX:SWAP-COLUMNS", COMMAND,
    command_syntax(right=[WildcardType, NumberType, NumberType]),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:swap-columns")
      jc1 = check_col(m, args[2], "matrix:swap-columns")
      jc2 = check_col(m, args[3], "matrix:swap-columns")
      for r in 1:size(m.data, 1)
        m.data[r, jc1], m.data[r, jc2] = m.data[r, jc2], m.data[r, jc1]
      end
      nothing
    end)

  register_primitive!(registry, "MATRIX:DIMENSIONS", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:dimensions")
      Any[Float64(size(m.data, 1)), Float64(size(m.data, 2))]
    end)

  register_primitive!(registry, "MATRIX:SUBMATRIX", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, NumberType, NumberType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:submatrix")
      rows, cols = size(m.data)
      r1 = Int(args[2]); c1 = Int(args[3])
      r2 = Int(args[4]); c2 = Int(args[5])
      (r1 < 0 || r1 >= rows) &&
        throw(LogoRuntimeError("matrix:submatrix: r1=$r1 out of range [0, $(rows - 1)]"))
      (c1 < 0 || c1 >= cols) &&
        throw(LogoRuntimeError("matrix:submatrix: c1=$c1 out of range [0, $(cols - 1)]"))
      (r2 < 1 || r2 > rows) &&
        throw(LogoRuntimeError("matrix:submatrix: r2=$r2 out of range [1, $rows]"))
      (c2 < 1 || c2 > cols) &&
        throw(LogoRuntimeError("matrix:submatrix: c2=$c2 out of range [1, $cols]"))
      r2 <= r1 && throw(LogoRuntimeError("matrix:submatrix: r2 must be > r1"))
      c2 <= c1 && throw(LogoRuntimeError("matrix:submatrix: c2 must be > c1"))
      # r1,c1 inclusive (0-based), r2,c2 exclusive (0-based) → Julia 1-based
      LogoMatrix(m.data[(r1 + 1):r2, (c1 + 1):c2])
    end)

  register_primitive!(registry, "MATRIX:SET-AND-REPORT", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, NumberType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:set-and-report")
      jr = check_row(m, args[2], "matrix:set-and-report")
      jc = check_col(m, args[3], "matrix:set-and-report")
      new_mat = LogoMatrix(copy(m.data))
      new_mat.data[jr, jc] = numeric(args[4])
      new_mat
    end)

  # =========================================================================
  # Conversion
  # =========================================================================

  register_primitive!(registry, "MATRIX:TO-ROW-LIST", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:to-row-list")
      matrix_to_row_list(m)
    end)

  register_primitive!(registry, "MATRIX:TO-COLUMN-LIST", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:to-column-list")
      matrix_to_column_list(m)
    end)

  # =========================================================================
  # Arithmetic
  # =========================================================================

  register_primitive!(registry, "MATRIX:TIMES", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      a, b = args[1], args[2]
      if a isa LogoMatrix && b isa LogoMatrix
        LogoMatrix(a.data * b.data)
      elseif a isa LogoMatrix && is_logo_number(b)
        LogoMatrix(a.data .* numeric(b))
      elseif is_logo_number(a) && b isa LogoMatrix
        LogoMatrix(numeric(a) .* b.data)
      elseif is_logo_number(a) && is_logo_number(b)
        numeric(a) * numeric(b)
      else
        throw(LogoRuntimeError("matrix:times expected matrices or numbers"))
      end
    end)

  register_primitive!(registry, "MATRIX:TIMES-SCALAR", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:times-scalar")
      LogoMatrix(m.data .* numeric(args[2]))
    end)

  register_primitive!(registry, "MATRIX:PLUS", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      a, b = args[1], args[2]
      if a isa LogoMatrix && b isa LogoMatrix
        size(a.data) != size(b.data) &&
          throw(LogoRuntimeError("matrix:plus: matrices must have the same dimensions"))
        LogoMatrix(a.data .+ b.data)
      elseif a isa LogoMatrix && is_logo_number(b)
        LogoMatrix(a.data .+ numeric(b))
      elseif is_logo_number(a) && b isa LogoMatrix
        LogoMatrix(numeric(a) .+ b.data)
      elseif is_logo_number(a) && is_logo_number(b)
        numeric(a) + numeric(b)
      else
        throw(LogoRuntimeError("matrix:plus expected matrices or numbers"))
      end
    end)

  register_primitive!(registry, "MATRIX:MINUS", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      a, b = args[1], args[2]
      if a isa LogoMatrix && b isa LogoMatrix
        size(a.data) != size(b.data) &&
          throw(LogoRuntimeError("matrix:minus: matrices must have the same dimensions"))
        LogoMatrix(a.data .- b.data)
      elseif a isa LogoMatrix && is_logo_number(b)
        LogoMatrix(a.data .- numeric(b))
      elseif is_logo_number(a) && b isa LogoMatrix
        LogoMatrix(numeric(a) .- b.data)
      elseif is_logo_number(a) && is_logo_number(b)
        numeric(a) - numeric(b)
      else
        throw(LogoRuntimeError("matrix:minus expected matrices or numbers"))
      end
    end)

  register_primitive!(registry, "MATRIX:PLUS-SCALAR", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:plus-scalar")
      LogoMatrix(m.data .+ numeric(args[2]))
    end)

  register_primitive!(registry, "MATRIX:TIMES-ELEMENT-WISE", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      a = ensure_matrix(args[1], "matrix:times-element-wise")
      b = ensure_matrix(args[2], "matrix:times-element-wise")
      size(a.data) != size(b.data) &&
        throw(LogoRuntimeError("matrix:times-element-wise: matrices must have the same dimensions"))
      LogoMatrix(a.data .* b.data)
    end)

  register_primitive!(registry, "MATRIX:MAP", REPORTER,
    reporter_syntax(right=[ReporterBlockType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      task = args[1]
      task isa AbstractReporterTaskValue ||
        throw(LogoRuntimeError("matrix:map expected a reporter task as the first argument"))
      m = ensure_matrix(args[2], "matrix:map")
      rows, cols = size(m.data)
      result = zeros(Float64, rows, cols)
      for r in 1:rows
        for c in 1:cols
          val = invoke_reporter_task(ctx, task, Any[m.data[r, c]])
          result[r, c] = numeric(val)
        end
      end
      LogoMatrix(result)
    end)

  # =========================================================================
  # Linear Algebra
  # =========================================================================

  register_primitive!(registry, "MATRIX:INVERSE", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:inverse")
      size(m.data, 1) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:inverse: matrix must be square"))
      LogoMatrix(inv(m.data))
    end)

  register_primitive!(registry, "MATRIX:TRANSPOSE", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:transpose")
      LogoMatrix(Matrix(transpose(m.data)))
    end)

  register_primitive!(registry, "MATRIX:DET", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:det")
      size(m.data, 1) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:det: matrix must be square"))
      det(m.data)
    end)

  register_primitive!(registry, "MATRIX:RANK", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:rank")
      Float64(rank(m.data))
    end)

  register_primitive!(registry, "MATRIX:TRACE", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:trace")
      size(m.data, 1) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:trace: matrix must be square"))
      tr(m.data)
    end)

  register_primitive!(registry, "MATRIX:SOLVE", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      a = ensure_matrix(args[1], "matrix:solve")
      b = ensure_matrix(args[2], "matrix:solve")
      LogoMatrix(a.data \ b.data)
    end)

  register_primitive!(registry, "MATRIX:REAL-EIGENVALUES", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:real-eigenvalues")
      size(m.data, 1) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:real-eigenvalues: matrix must be square"))
      vals = eigen(m.data).values
      Any[real(v) for v in vals]
    end)

  register_primitive!(registry, "MATRIX:IMAGINARY-EIGENVALUES", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:imaginary-eigenvalues")
      size(m.data, 1) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:imaginary-eigenvalues: matrix must be square"))
      vals = eigen(m.data).values
      Any[imag(v) for v in vals]
    end)

  register_primitive!(registry, "MATRIX:EIGENVECTORS", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:eigenvectors")
      size(m.data, 1) != size(m.data, 2) &&
        throw(LogoRuntimeError("matrix:eigenvectors: matrix must be square"))
      vecs = eigen(m.data).vectors
      LogoMatrix(Matrix{Float64}(real.(vecs)))
    end)

  # =========================================================================
  # Statistics
  # =========================================================================

  register_primitive!(registry, "MATRIX:REGRESS", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:regress")
      rows, cols = size(m.data)
      cols < 2 && throw(LogoRuntimeError("matrix:regress: matrix must have at least 2 columns"))
      rows <= (cols - 1) &&
        throw(LogoRuntimeError("matrix:regress: number of observations must exceed number of independent variables"))
      # First column = dependent variable (Y)
      Y = m.data[:, 1]
      # Remaining columns = independent variables, prepend column of 1s for constant
      X = hcat(ones(rows), m.data[:, 2:end])
      # Solve X * coeffs = Y via least squares
      coeffs = X \ Y
      predicted = X * coeffs
      y_mean = sum(Y) / rows
      ss_tot = sum((Y .- y_mean) .^ 2)
      ss_res = sum((Y .- predicted) .^ 2)
      r_squared = ss_tot == 0.0 ? 0.0 : 1.0 - ss_res / ss_tot
      Any[Any[c for c in coeffs], Any[r_squared, ss_tot, ss_res]]
    end)

  register_primitive!(registry, "MATRIX:FORECAST-LINEAR-GROWTH", REPORTER,
    reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> begin
      lst = args[1]
      isempty(lst) && throw(LogoRuntimeError("matrix:forecast-linear-growth: empty list"))
      ys = Float64[numeric(v) for v in lst]
      n = length(ys)
      if n == 1
        return Any[ys[1], ys[1], 0.0, 0.0]
      end
      constant, slope, r_sq = simple_linear_regression(ys)
      forecast = constant + slope * n
      Any[forecast, constant, slope, r_sq]
    end)

  register_primitive!(registry, "MATRIX:FORECAST-COMPOUND-GROWTH", REPORTER,
    reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> begin
      lst = args[1]
      isempty(lst) && throw(LogoRuntimeError("matrix:forecast-compound-growth: empty list"))
      ys = Float64[numeric(v) for v in lst]
      n = length(ys)
      any(y -> y <= 0.0, ys) &&
        throw(LogoRuntimeError("matrix:forecast-compound-growth: all values must be > 0"))
      if n == 1
        return Any[ys[1], ys[1], 1.0, 0.0]
      end
      log_ys = log.(ys)
      constant_log, slope_log, r_sq = simple_linear_regression(log_ys)
      base_constant = exp(constant_log)
      growth_factor = exp(slope_log)  # 1 + rate
      forecast = base_constant * growth_factor^n
      Any[forecast, base_constant, growth_factor, r_sq]
    end)

  register_primitive!(registry, "MATRIX:FORECAST-CONTINUOUS-GROWTH", REPORTER,
    reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> begin
      lst = args[1]
      isempty(lst) && throw(LogoRuntimeError("matrix:forecast-continuous-growth: empty list"))
      ys = Float64[numeric(v) for v in lst]
      n = length(ys)
      any(y -> y <= 0.0, ys) &&
        throw(LogoRuntimeError("matrix:forecast-continuous-growth: all values must be > 0"))
      if n == 1
        return Any[ys[1], ys[1], 0.0, 0.0]
      end
      log_ys = log.(ys)
      constant_log, rate, r_sq = simple_linear_regression(log_ys)
      base_constant = exp(constant_log)
      forecast = base_constant * exp(rate * n)
      Any[forecast, base_constant, rate, r_sq]
    end)

  # =========================================================================
  # Pretty-print
  # =========================================================================

  register_primitive!(registry, "MATRIX:PRETTY-PRINT-TEXT", REPORTER,
    reporter_syntax(right=[WildcardType], ret=StringType),
    (ctx, args) -> begin
      m = ensure_matrix(args[1], "matrix:pretty-print-text")
      rows, cols = size(m.data)
      # Compute column widths
      strs = [error_logo_string(m.data[r, c]) for r in 1:rows, c in 1:cols]
      col_widths = [maximum(length(strs[r, c]) for r in 1:rows) for c in 1:cols]
      lines = String[]
      for r in 1:rows
        cells = [lpad(strs[r, c], col_widths[c]) for c in 1:cols]
        row_str = join(cells, " ")
        if r == 1
          push!(lines, "[[ $row_str ]")
        else
          push!(lines, " [ $row_str ]")
        end
      end
      if rows == 1
        lines[1] * "]"
      else
        lines[end] = lines[end] * "]"
        join(lines, "\n")
      end
    end)

end # register_extension!

end # module matrix
