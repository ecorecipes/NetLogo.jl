module bitstring

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType, RepeatableType, OptionalType,
  LogoRuntimeError, logo_string, is_logo_number, numeric,
  NormalPrecedence

# ---------------------------------------------------------------------------
# LogoBitstring type — immutable fixed-length bit vector
# ---------------------------------------------------------------------------

struct LogoBitstring
    bits::BitVector
end

Base.length(b::LogoBitstring) = length(b.bits)

function Base.show(io::IO, b::LogoBitstring)
    print(io, "{{bitstring: ")
    for bit in b.bits
        print(io, bit ? '1' : '0')
    end
    print(io, "}}")
end

# For NetLogo's `word` / `print` stringification
function logo_string_bitstring(b::LogoBitstring)
    buf = IOBuffer()
    print(buf, "{{bitstring: ")
    for bit in b.bits
        print(buf, bit ? '1' : '0')
    end
    print(buf, "}}")
    String(take!(buf))
end

function ensure_bitstring(v, label::String="argument")
    v isa LogoBitstring && return v
    throw(LogoRuntimeError("$label expected a bitstring, got $(typeof(v))"))
end

function ensure_same_length(a::LogoBitstring, b::LogoBitstring)
    length(a) == length(b) && return
    throw(LogoRuntimeError("bitstring operations require equal-length bitstrings ($(length(a)) vs $(length(b)))"))
end

function ensure_valid_index(bs::LogoBitstring, idx::Int)
    0 <= idx < length(bs) && return
    throw(LogoRuntimeError("bitstring index $idx out of range [0, $(length(bs)-1)]"))
end

# ---------------------------------------------------------------------------
# Creators
# ---------------------------------------------------------------------------

function bs_make(len::Int, val::Bool=false)
    len >= 0 || throw(LogoRuntimeError("bitstring length must be non-negative"))
    LogoBitstring(BitVector(fill(val, len)))
end

function bs_from_list(lst::AbstractVector)
    bits = BitVector(undef, length(lst))
    for (i, item) in enumerate(lst)
        if item isa Bool
            bits[i] = item
        elseif is_logo_number(item)
            v = numeric(item)
            if v == 1.0
                bits[i] = true
            elseif v == 0.0
                bits[i] = false
            else
                throw(LogoRuntimeError("bitstring:from-list: numeric value must be 0 or 1, got $v"))
            end
        elseif item isa AbstractString
            s = uppercase(String(item))
            if s in ("TRUE", "T", "YES", "Y", "1")
                bits[i] = true
            elseif s in ("FALSE", "F", "NO", "N", "0")
                bits[i] = false
            else
                throw(LogoRuntimeError("bitstring:from-list: unrecognized string value \"$item\""))
            end
        else
            throw(LogoRuntimeError("bitstring:from-list: unsupported element type $(typeof(item))"))
        end
    end
    LogoBitstring(bits)
end

function bs_from_string(s::AbstractString)
    bits = BitVector(undef, length(s))
    for (i, c) in enumerate(s)
        if c in ('1', 'T', 't', 'Y', 'y')
            bits[i] = true
        elseif c in ('0', 'F', 'f', 'N', 'n')
            bits[i] = false
        else
            throw(LogoRuntimeError("bitstring:from-string: unrecognized character '$c'"))
        end
    end
    LogoBitstring(bits)
end

function bs_random(len::Int, p_true::Float64, rng)
    len >= 0 || throw(LogoRuntimeError("bitstring length must be non-negative"))
    bits = BitVector(undef, len)
    for i in 1:len
        bits[i] = rand(rng) < p_true
    end
    LogoBitstring(bits)
end

function bs_cat(a::LogoBitstring, b::LogoBitstring)
    LogoBitstring(vcat(a.bits, b.bits))
end

# ---------------------------------------------------------------------------
# Accessors
# ---------------------------------------------------------------------------

bs_get(bs::LogoBitstring, idx::Int) = (ensure_valid_index(bs, idx); bs.bits[idx + 1])
bs_first(bs::LogoBitstring) = (length(bs) > 0 || throw(LogoRuntimeError("bitstring is empty")); bs.bits[1])
bs_last(bs::LogoBitstring) = (length(bs) > 0 || throw(LogoRuntimeError("bitstring is empty")); bs.bits[end])

function bs_but_first(bs::LogoBitstring)
    length(bs) > 0 || throw(LogoRuntimeError("bitstring is empty"))
    LogoBitstring(bs.bits[2:end])
end

function bs_but_last(bs::LogoBitstring)
    length(bs) > 0 || throw(LogoRuntimeError("bitstring is empty"))
    LogoBitstring(bs.bits[1:end-1])
end

function bs_sub(bs::LogoBitstring, start::Int, finish::Int)
    start >= 0 || throw(LogoRuntimeError("bitstring:sub start index must be >= 0"))
    finish <= length(bs) || throw(LogoRuntimeError("bitstring:sub finish index out of range"))
    start <= finish || throw(LogoRuntimeError("bitstring:sub start must be <= finish"))
    LogoBitstring(bs.bits[start+1:finish])
end

bs_count0(bs::LogoBitstring) = Float64(count(!, bs.bits))
bs_count1(bs::LogoBitstring) = Float64(count(identity, bs.bits))
bs_all0(bs::LogoBitstring) = !any(bs.bits)
bs_all1(bs::LogoBitstring) = all(bs.bits)
bs_any0(bs::LogoBitstring) = !all(bs.bits)
bs_any1(bs::LogoBitstring) = any(bs.bits)

function bs_to_list(bs::LogoBitstring)
    Any[b for b in bs.bits]
end

# ---------------------------------------------------------------------------
# Setters (return new bitstrings)
# ---------------------------------------------------------------------------

function bs_set(bs::LogoBitstring, pos::Int, val::Bool)
    ensure_valid_index(bs, pos)
    new_bits = copy(bs.bits)
    new_bits[pos + 1] = val
    LogoBitstring(new_bits)
end

function bs_fput(bs::LogoBitstring, val::Bool)
    LogoBitstring(vcat(BitVector([val]), bs.bits))
end

function bs_lput(bs::LogoBitstring, val::Bool)
    LogoBitstring(vcat(bs.bits, BitVector([val])))
end

# ---------------------------------------------------------------------------
# Bitwise operators
# ---------------------------------------------------------------------------

function bs_not(bs::LogoBitstring)
    LogoBitstring(.~(bs.bits))
end

function bs_and(a::LogoBitstring, b::LogoBitstring)
    ensure_same_length(a, b)
    LogoBitstring(a.bits .& b.bits)
end

function bs_or(a::LogoBitstring, b::LogoBitstring)
    ensure_same_length(a, b)
    LogoBitstring(a.bits .| b.bits)
end

function bs_xor(a::LogoBitstring, b::LogoBitstring)
    ensure_same_length(a, b)
    LogoBitstring(a.bits .⊻ b.bits)
end

function bs_parity(a::LogoBitstring, b::LogoBitstring)
    ensure_same_length(a, b)
    LogoBitstring(.~(a.bits .⊻ b.bits))
end

function bs_right_shift(bs::LogoBitstring)
    n = length(bs)
    n == 0 && return bs
    new_bits = BitVector(undef, n)
    new_bits[1] = false
    for i in 2:n
        new_bits[i] = bs.bits[i-1]
    end
    LogoBitstring(new_bits)
end

function bs_gray_code(bs::LogoBitstring)
    n = length(bs)
    n == 0 && return bs
    new_bits = BitVector(undef, n)
    new_bits[1] = bs.bits[1]
    for i in 2:n
        new_bits[i] = bs.bits[i-1] ⊻ bs.bits[i]
    end
    LogoBitstring(new_bits)
end

function bs_inverse_gray_code(bs::LogoBitstring)
    n = length(bs)
    n == 0 && return bs
    new_bits = BitVector(undef, n)
    new_bits[1] = bs.bits[1]
    for i in 2:n
        new_bits[i] = new_bits[i-1] ⊻ bs.bits[i]
    end
    LogoBitstring(new_bits)
end

# ---------------------------------------------------------------------------
# Comparison
# ---------------------------------------------------------------------------

function bs_contains(haystack::LogoBitstring, needle::LogoBitstring)
    hn = length(haystack)
    nn = length(needle)
    nn == 0 && return true
    nn > hn && return false
    for start in 0:(hn - nn)
        match = true
        for j in 1:nn
            if haystack.bits[start + j] != needle.bits[j]
                match = false
                break
            end
        end
        match && return true
    end
    false
end

function bs_match(a::LogoBitstring, b::LogoBitstring)
    ensure_same_length(a, b)
    Float64(count(i -> a.bits[i] == b.bits[i], 1:length(a)))
end

# ---------------------------------------------------------------------------
# Genetic operators
# ---------------------------------------------------------------------------

function bs_mutate(bs::LogoBitstring, pos::Int, rng)
    ensure_valid_index(bs, pos)
    new_bits = copy(bs.bits)
    new_bits[pos + 1] = rand(rng, Bool)
    LogoBitstring(new_bits)
end

function bs_toggle(bs::LogoBitstring, pos::Int)
    ensure_valid_index(bs, pos)
    new_bits = copy(bs.bits)
    new_bits[pos + 1] = !new_bits[pos + 1]
    LogoBitstring(new_bits)
end

function bs_crossover(a::LogoBitstring, b::LogoBitstring, pos::Int)
    ensure_same_length(a, b)
    n = length(a)
    (pos >= 0 && pos <= n) || throw(LogoRuntimeError("bitstring:crossover position $pos out of range [0, $n]"))
    c1 = BitVector(undef, n)
    c2 = BitVector(undef, n)
    for i in 1:pos
        c1[i] = a.bits[i]
        c2[i] = b.bits[i]
    end
    for i in (pos+1):n
        c1[i] = b.bits[i]
        c2[i] = a.bits[i]
    end
    Any[LogoBitstring(c1), LogoBitstring(c2)]
end

function bs_jitter(bs::LogoBitstring, probs::AbstractVector{Float64}, rng)
    n = length(bs)
    np = length(probs)
    np > 0 || throw(LogoRuntimeError("bitstring:jitter requires at least one probability"))
    new_bits = copy(bs.bits)
    for i in 1:n
        p = probs[((i - 1) % np) + 1]
        if rand(rng) < p
            new_bits[i] = !new_bits[i]
        end
    end
    LogoBitstring(new_bits)
end

# ---------------------------------------------------------------------------
# Register extension
# ---------------------------------------------------------------------------

function register_extension!(registry::PrimitiveRegistry)

    # --- Creators ---
    register_primitive!(registry, "BITSTRING:MAKE", REPORTER,
        reporter_syntax(right=[NumberType, BooleanType], ret=WildcardType),
        (ctx, args) -> bs_make(Int(numeric(args[1])), args[2]::Bool))

    register_primitive!(registry, "BITSTRING:FROM-LIST", REPORTER,
        reporter_syntax(right=[ListType], ret=WildcardType),
        (ctx, args) -> bs_from_list(args[1]))

    register_primitive!(registry, "BITSTRING:FROM-STRING", REPORTER,
        reporter_syntax(right=[StringType], ret=WildcardType),
        (ctx, args) -> bs_from_string(String(args[1])))

    register_primitive!(registry, "BITSTRING:RANDOM", REPORTER,
        reporter_syntax(right=[NumberType, OptionalType | NumberType], ret=WildcardType),
        (ctx, args) -> bs_random(Int(numeric(args[1])),
                                 length(args) >= 2 && args[2] !== nothing ? Float64(numeric(args[2])) : 0.5,
                                 ctx.runtime.world.rng))

    register_primitive!(registry, "BITSTRING:CAT", REPORTER,
        reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
        (ctx, args) -> bs_cat(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    # --- Accessors ---
    register_primitive!(registry, "BITSTRING:GET?", REPORTER,
        reporter_syntax(right=[WildcardType, NumberType], ret=BooleanType),
        (ctx, args) -> bs_get(ensure_bitstring(args[1]), Int(numeric(args[2]))))

    register_primitive!(registry, "BITSTRING:FIRST?", REPORTER,
        reporter_syntax(right=[WildcardType], ret=BooleanType),
        (ctx, args) -> bs_first(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:LAST?", REPORTER,
        reporter_syntax(right=[WildcardType], ret=BooleanType),
        (ctx, args) -> bs_last(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:BUT-FIRST", REPORTER,
        reporter_syntax(right=[WildcardType], ret=WildcardType),
        (ctx, args) -> bs_but_first(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:BUT-LAST", REPORTER,
        reporter_syntax(right=[WildcardType], ret=WildcardType),
        (ctx, args) -> bs_but_last(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:SUB", REPORTER,
        reporter_syntax(right=[WildcardType, NumberType, NumberType], ret=WildcardType),
        (ctx, args) -> bs_sub(ensure_bitstring(args[1]), Int(numeric(args[2])), Int(numeric(args[3]))))

    register_primitive!(registry, "BITSTRING:COUNT0", REPORTER,
        reporter_syntax(right=[WildcardType], ret=NumberType),
        (ctx, args) -> bs_count0(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:COUNT1", REPORTER,
        reporter_syntax(right=[WildcardType], ret=NumberType),
        (ctx, args) -> bs_count1(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:ALL0?", REPORTER,
        reporter_syntax(right=[WildcardType], ret=BooleanType),
        (ctx, args) -> bs_all0(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:ALL1?", REPORTER,
        reporter_syntax(right=[WildcardType], ret=BooleanType),
        (ctx, args) -> bs_all1(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:ANY0?", REPORTER,
        reporter_syntax(right=[WildcardType], ret=BooleanType),
        (ctx, args) -> bs_any0(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:ANY1?", REPORTER,
        reporter_syntax(right=[WildcardType], ret=BooleanType),
        (ctx, args) -> bs_any1(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:TO-LIST", REPORTER,
        reporter_syntax(right=[WildcardType], ret=ListType),
        (ctx, args) -> bs_to_list(ensure_bitstring(args[1])))

    # --- Setters ---
    register_primitive!(registry, "BITSTRING:SET", REPORTER,
        reporter_syntax(right=[WildcardType, NumberType, BooleanType], ret=WildcardType),
        (ctx, args) -> bs_set(ensure_bitstring(args[1]), Int(numeric(args[2])), args[3]::Bool))

    register_primitive!(registry, "BITSTRING:FPUT", REPORTER,
        reporter_syntax(right=[WildcardType, BooleanType], ret=WildcardType),
        (ctx, args) -> bs_fput(ensure_bitstring(args[1]), args[2]::Bool))

    register_primitive!(registry, "BITSTRING:LPUT", REPORTER,
        reporter_syntax(right=[WildcardType, BooleanType], ret=WildcardType),
        (ctx, args) -> bs_lput(ensure_bitstring(args[1]), args[2]::Bool))

    # --- Bitwise operators ---
    register_primitive!(registry, "BITSTRING:NOT", REPORTER,
        reporter_syntax(right=[WildcardType], ret=WildcardType),
        (ctx, args) -> bs_not(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:AND", REPORTER,
        reporter_syntax(left=WildcardType, right=[WildcardType], ret=WildcardType, precedence=NormalPrecedence),
        (ctx, args) -> bs_and(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    register_primitive!(registry, "BITSTRING:OR", REPORTER,
        reporter_syntax(left=WildcardType, right=[WildcardType], ret=WildcardType, precedence=NormalPrecedence),
        (ctx, args) -> bs_or(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    register_primitive!(registry, "BITSTRING:XOR", REPORTER,
        reporter_syntax(left=WildcardType, right=[WildcardType], ret=WildcardType, precedence=NormalPrecedence),
        (ctx, args) -> bs_xor(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    register_primitive!(registry, "BITSTRING:PARITY", REPORTER,
        reporter_syntax(left=WildcardType, right=[WildcardType], ret=WildcardType, precedence=NormalPrecedence),
        (ctx, args) -> bs_parity(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    register_primitive!(registry, "BITSTRING:RIGHT-SHIFT", REPORTER,
        reporter_syntax(right=[WildcardType], ret=WildcardType),
        (ctx, args) -> bs_right_shift(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:GRAY-CODE", REPORTER,
        reporter_syntax(right=[WildcardType], ret=WildcardType),
        (ctx, args) -> bs_gray_code(ensure_bitstring(args[1])))

    register_primitive!(registry, "BITSTRING:INVERSE-GRAY-CODE", REPORTER,
        reporter_syntax(right=[WildcardType], ret=WildcardType),
        (ctx, args) -> bs_inverse_gray_code(ensure_bitstring(args[1])))

    # --- Comparison ---
    register_primitive!(registry, "BITSTRING:CONTAINS?", REPORTER,
        reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=NormalPrecedence),
        (ctx, args) -> bs_contains(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    register_primitive!(registry, "BITSTRING:MATCH", REPORTER,
        reporter_syntax(left=WildcardType, right=[WildcardType], ret=NumberType, precedence=NormalPrecedence),
        (ctx, args) -> bs_match(ensure_bitstring(args[1], "first"), ensure_bitstring(args[2], "second")))

    # --- Genetic operators ---
    register_primitive!(registry, "BITSTRING:MUTATE", REPORTER,
        reporter_syntax(right=[WildcardType, NumberType], ret=WildcardType),
        (ctx, args) -> bs_mutate(ensure_bitstring(args[1]), Int(numeric(args[2])), ctx.runtime.world.rng))

    register_primitive!(registry, "BITSTRING:TOGGLE", REPORTER,
        reporter_syntax(right=[WildcardType, NumberType], ret=WildcardType),
        (ctx, args) -> bs_toggle(ensure_bitstring(args[1]), Int(numeric(args[2]))))

    register_primitive!(registry, "BITSTRING:CROSSOVER", REPORTER,
        reporter_syntax(right=[WildcardType, WildcardType, NumberType], ret=ListType),
        (ctx, args) -> bs_crossover(
            ensure_bitstring(args[1], "first"),
            ensure_bitstring(args[2], "second"),
            Int(numeric(args[3]))))

    register_primitive!(registry, "BITSTRING:JITTER", REPORTER,
        reporter_syntax(right=[WildcardType, NumberType | RepeatableType], ret=WildcardType),
        (ctx, args) -> begin
            bs = ensure_bitstring(args[1])
            probs = Float64[numeric(args[i]) for i in 2:length(args)]
            bs_jitter(bs, probs, ctx.runtime.world.rng)
        end)

    # --- Length reporter (common utility) ---
    register_primitive!(registry, "BITSTRING:LENGTH", REPORTER,
        reporter_syntax(right=[WildcardType], ret=NumberType),
        (ctx, args) -> Float64(length(ensure_bitstring(args[1]))))
end

end # module bitstring
