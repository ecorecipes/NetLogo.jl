module palette

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER,
  reporter_syntax, ListType, NumberType, LogoRuntimeError, list_argument,
  numeric

using Colors: RGB, red, green, blue

function rgb_stop(value, opname::AbstractString)
  stop = list_argument(value, opname)
  length(stop) == 3 || throw(LogoRuntimeError("$opname expected each color stop to be an RGB list of length 3"))
  channels = ntuple(i -> begin
    component = numeric(stop[i])
    0.0 <= component <= 255.0 || throw(LogoRuntimeError("$opname expected RGB values between 0 and 255"))
    component
  end, 3)
  RGB{Float64}(channels[1] / 255.0, channels[2] / 255.0, channels[3] / 255.0)
end

function rgb_list(color::RGB{Float64})
  Any[
    Float64(round(Int, clamp(red(color), 0.0, 1.0) * 255.0)),
    Float64(round(Int, clamp(green(color), 0.0, 1.0) * 255.0)),
    Float64(round(Int, clamp(blue(color), 0.0, 1.0) * 255.0)),
  ]
end

function scale_gradient(stops_value, value_value, min_value, max_value)
  opname = "palette:scale-gradient"
  stops = [rgb_stop(stop, opname) for stop in list_argument(stops_value, opname)]
  isempty(stops) && throw(LogoRuntimeError("$opname expected at least one color stop"))
  length(stops) == 1 && return rgb_list(stops[1])

  value = numeric(value_value)
  lower = numeric(min_value)
  upper = numeric(max_value)
  t =
    if upper == lower
      0.0
    else
      clamp((value - lower) / (upper - lower), 0.0, 1.0)
    end

  scaled = t * (length(stops) - 1)
  index = min(floor(Int, scaled) + 1, length(stops) - 1)
  local_t = scaled - (index - 1)
  start_color = stops[index]
  end_color = stops[index + 1]
  blended = RGB{Float64}(
    (1 - local_t) * red(start_color) + local_t * red(end_color),
    (1 - local_t) * green(start_color) + local_t * green(end_color),
    (1 - local_t) * blue(start_color) + local_t * blue(end_color),
  )
  rgb_list(blended)
end

function register_extension!(registry::PrimitiveRegistry)
  register_primitive!(registry, "PALETTE:SCALE-GRADIENT", REPORTER,
    reporter_syntax(right=[ListType, NumberType, NumberType, NumberType], ret=ListType),
    (ctx, args) -> scale_gradient(args[1], args[2], args[3], args[4]))
end

end
