module bitmap

using Base64
using Colors: RGB, red, green, blue
using FileIO

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  LogoRuntimeError, Context,
  get_patch, world_width, world_height,
  resolve_file_path

import ..NetLogo: logo_string

# ---------------------------------------------------------------------------
# LogoBitmap – a simple in-memory RGB image
# ---------------------------------------------------------------------------

mutable struct LogoBitmap
  width::Int
  height::Int
  pixels::Matrix{NTuple{3, UInt8}}  # (R, G, B) – row-major (height × width)
end

LogoBitmap(w::Int, h::Int) =
  LogoBitmap(w, h, fill((UInt8(0), UInt8(0), UInt8(0)), h, w))

logo_string(bmp::LogoBitmap) = "{{bitmap: $(bmp.width)x$(bmp.height)}}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function ensure_bitmap(value, opname::AbstractString)
  value isa LogoBitmap ||
    throw(LogoRuntimeError("$opname expected a bitmap as the first input"))
  value
end

function channel_to_uint8(value::Real)
  numeric = Float64(value)
  scaled = 0.0 <= numeric <= 1.0 ? 255.0 * numeric : numeric
  UInt8(clamp(round(Int, scaled), 0, 255))
end

pixel_to_rgb(pixel::Real) = begin
  gray = channel_to_uint8(pixel)
  (gray, gray, gray)
end
pixel_to_rgb(pixel::NTuple{3, <:Real}) =
  (channel_to_uint8(pixel[1]), channel_to_uint8(pixel[2]), channel_to_uint8(pixel[3]))
pixel_to_rgb(pixel::NTuple{4, <:Real}) =
  (channel_to_uint8(pixel[1]), channel_to_uint8(pixel[2]), channel_to_uint8(pixel[3]))
pixel_to_rgb(pixel) = (
  channel_to_uint8(red(pixel)),
  channel_to_uint8(green(pixel)),
  channel_to_uint8(blue(pixel)),
)

function bitmap_from_image(image)
  ndims(image) >= 2 || throw(LogoRuntimeError("bitmap:import: unsupported image format"))
  height = size(image, 1)
  width = size(image, 2)
  pixels = Matrix{NTuple{3, UInt8}}(undef, height, width)
  for row in 1:height, col in 1:width
    pixels[row, col] = pixel_to_rgb(image[row, col])
  end
  LogoBitmap(width, height, pixels)
end

function bitmap_to_image(bmp::LogoBitmap)
  image = Matrix{RGB{Float32}}(undef, bmp.height, bmp.width)
  for row in 1:bmp.height, col in 1:bmp.width
    r, g, b = bmp.pixels[row, col]
    image[row, col] = RGB{Float32}(Float32(r) / 255f0, Float32(g) / 255f0, Float32(b) / 255f0)
  end
  image
end

function bitmap_import(path::AbstractString)
  resolved = resolve_file_path(path)
  isfile(resolved) || throw(LogoRuntimeError("bitmap:import: file not found: $resolved"))
  try
    bitmap_from_image(FileIO.load(resolved))
  catch err
    err isa LogoRuntimeError && rethrow()
    throw(LogoRuntimeError("bitmap:import: $(sprint(showerror, err))"))
  end
end

function bitmap_export(bmp::LogoBitmap, path::AbstractString)
  resolved = resolve_file_path(path)
  try
    FileIO.save(resolved, bitmap_to_image(bmp))
  catch err
    throw(LogoRuntimeError("bitmap:export: $(sprint(showerror, err))"))
  end
  nothing
end

function bitmap_from_base64(text::AbstractString)
  payload = strip(String(text))
  if startswith(lowercase(payload), "data:") && occursin(",", payload)
    payload = split(payload, ","; limit=2)[2]
  end
  payload = replace(payload, r"\s+" => "")
  bytes =
    try
      Base64.base64decode(payload)
    catch err
      throw(LogoRuntimeError("bitmap:from-base64: $(sprint(showerror, err))"))
    end
  mktempdir() do dir
    path = joinpath(dir, "bitmap.png")
    open(path, "w") do io
      write(io, bytes)
    end
    bitmap_import(path)
  end
end

function bitmap_to_base64(bmp::LogoBitmap)
  mktempdir() do dir
    path = joinpath(dir, "bitmap.png")
    bitmap_export(bmp, path)
    Base64.base64encode(read(path))
  end
end

# ---------------------------------------------------------------------------
# Core pixel operations (no external dependencies)
# ---------------------------------------------------------------------------

function bitmap_scaled(bmp::LogoBitmap, new_w::Int, new_h::Int)
  new_w >= 1 || throw(LogoRuntimeError("bitmap:scaled width must be at least 1"))
  new_h >= 1 || throw(LogoRuntimeError("bitmap:scaled height must be at least 1"))
  out = Matrix{NTuple{3, UInt8}}(undef, new_h, new_w)
  for r in 1:new_h
    src_r = clamp(round(Int, (r - 0.5) * bmp.height / new_h + 0.5), 1, bmp.height)
    for c in 1:new_w
      src_c = clamp(round(Int, (c - 0.5) * bmp.width / new_w + 0.5), 1, bmp.width)
      out[r, c] = bmp.pixels[src_r, src_c]
    end
  end
  LogoBitmap(new_w, new_h, out)
end

function bitmap_difference_rgb(a::LogoBitmap, b::LogoBitmap)
  a.width == b.width && a.height == b.height ||
    throw(LogoRuntimeError("bitmap:difference-rgb requires bitmaps of equal dimensions"))
  out = Matrix{NTuple{3, UInt8}}(undef, a.height, a.width)
  for i in eachindex(a.pixels)
    r1, g1, b1 = a.pixels[i]
    r2, g2, b2 = b.pixels[i]
    out[i] = (UInt8(abs(Int(r1) - Int(r2))),
              UInt8(abs(Int(g1) - Int(g2))),
              UInt8(abs(Int(b1) - Int(b2))))
  end
  LogoBitmap(a.width, a.height, out)
end

function bitmap_channel(bmp::LogoBitmap, ch::Int)
  (ch < 0 || ch > 2) &&
    throw(LogoRuntimeError("bitmap:channel expects channel 0 (red), 1 (green), or 2 (blue)"))
  idx = ch + 1  # NTuple is 1-indexed
  result = Any[]
  for r in 1:bmp.height
    row = Any[]
    for c in 1:bmp.width
      push!(row, Float64(bmp.pixels[r, c][idx]))
    end
    push!(result, row)
  end
  result
end

function bitmap_to_grayscale(bmp::LogoBitmap)
  out = Matrix{NTuple{3, UInt8}}(undef, bmp.height, bmp.width)
  for i in eachindex(bmp.pixels)
    r, g, b = bmp.pixels[i]
    gray = UInt8(clamp(round(Int, 0.299 * r + 0.587 * g + 0.114 * b), 0, 255))
    out[i] = (gray, gray, gray)
  end
  LogoBitmap(bmp.width, bmp.height, out)
end

function bitmap_average_color(bmp::LogoBitmap)
  n = bmp.width * bmp.height
  n == 0 && return Any[0.0, 0.0, 0.0]
  sr = 0.0; sg = 0.0; sb = 0.0
  for px in bmp.pixels
    sr += px[1]; sg += px[2]; sb += px[3]
  end
  Any[sr / n, sg / n, sb / n]
end

# ---------------------------------------------------------------------------
# copy-to-pcolors – apply bitmap pixels to patch colors
# ---------------------------------------------------------------------------

function bitmap_copy_to_pcolors!(ctx::Context, bmp::LogoBitmap, do_scale::Bool)
  world = ctx.runtime.world
  ww = world_width(world)
  wh = world_height(world)

  src = do_scale ? bitmap_scaled(bmp, ww, wh) : bmp

  x_off = div(ww - src.width, 2)
  y_off = div(wh - src.height, 2)

  for row in 1:min(src.height, wh)
    for col in 1:min(src.width, ww)
      pxcor = world.min_pxcor + x_off + col - 1
      pycor = world.max_pycor - y_off - row + 1
      if pxcor >= world.min_pxcor && pxcor <= world.max_pxcor &&
         pycor >= world.min_pycor && pycor <= world.max_pycor
        patch = get_patch(world, pxcor, pycor)
        r, g, b = src.pixels[row, col]
        patch.pcolor = Any[Float64(r), Float64(g), Float64(b)]
      end
    end
  end
  nothing
end

# ---------------------------------------------------------------------------
# Extension registration
# ---------------------------------------------------------------------------

function register_extension!(registry::PrimitiveRegistry)

  # -- reporters ----------------------------------------------------------

  register_primitive!(registry, "BITMAP:WIDTH", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:width")
      Float64(bmp.width)
    end)

  register_primitive!(registry, "BITMAP:HEIGHT", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:height")
      Float64(bmp.height)
    end)

  register_primitive!(registry, "BITMAP:FROM-VIEW", REPORTER,
    reporter_syntax(ret=WildcardType),
    (ctx, args) -> LogoBitmap(1, 1))  # headless stub

  register_primitive!(registry, "BITMAP:SCALED", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, NumberType], ret=WildcardType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:scaled")
      bitmap_scaled(bmp, round(Int, args[2]), round(Int, args[3]))
    end)

  register_primitive!(registry, "BITMAP:DIFFERENCE-RGB", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      a = ensure_bitmap(args[1], "bitmap:difference-rgb")
      b = ensure_bitmap(args[2], "bitmap:difference-rgb")
      bitmap_difference_rgb(a, b)
    end)

  register_primitive!(registry, "BITMAP:CHANNEL", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType], ret=ListType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:channel")
      bitmap_channel(bmp, round(Int, args[2]))
    end)

  register_primitive!(registry, "BITMAP:TO-GRAYSCALE", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:to-grayscale")
      bitmap_to_grayscale(bmp)
    end)

  register_primitive!(registry, "BITMAP:AVERAGE-COLOR", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:average-color")
      bitmap_average_color(bmp)
    end)

  register_primitive!(registry, "BITMAP:IMPORT", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> bitmap_import(String(args[1])))

  register_primitive!(registry, "BITMAP:FROM-BASE64", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> bitmap_from_base64(String(args[1])))

  register_primitive!(registry, "BITMAP:TO-BASE64", REPORTER,
    reporter_syntax(right=[WildcardType], ret=StringType),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:to-base64")
      bitmap_to_base64(bmp)
    end)

  # -- commands -----------------------------------------------------------

  register_primitive!(registry, "BITMAP:COPY-TO-DRAWING", COMMAND,
    command_syntax(right=[WildcardType, NumberType, NumberType]),
    (ctx, args) -> begin
      ensure_bitmap(args[1], "bitmap:copy-to-drawing")
      nothing  # headless stub
    end)

  register_primitive!(registry, "BITMAP:COPY-TO-PCOLORS", COMMAND,
    command_syntax(right=[WildcardType, BooleanType]),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:copy-to-pcolors")
      bitmap_copy_to_pcolors!(ctx, bmp, args[2])
    end)

  register_primitive!(registry, "BITMAP:EXPORT", COMMAND,
    command_syntax(right=[WildcardType, StringType]),
    (ctx, args) -> begin
      bmp = ensure_bitmap(args[1], "bitmap:export")
      bitmap_export(bmp, String(args[2]))
    end)
end

end # module bitmap
