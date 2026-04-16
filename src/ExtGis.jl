module gis

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  AgentsetType, TurtlesetType, PatchsetType, LinksetType, CommandBlockType, SymbolType,
  OptionalType,
  LogoRuntimeError, logo_string, Context,
  World, Turtle, Patch, Link, live_agentset_members,
  create_turtle!, create_link!, run_block_for_agents!,
  patch_at_coords, set_patch_variable!, patch_variable_value,
  canonical_name

using Shapefile
using DBFTables
import Tables
import Proj
import LibGEOS
import GeoJSON
import GeoInterface as GI
import GeoFormatTypes as GFT
import GeometryOps as GO

# ═══════════════════════════════════════════════════════════════════════════
# GIS Data Types
# ═══════════════════════════════════════════════════════════════════════════

"""Represents a point in GIS coordinate space."""
struct GisVertex
  x::Float64
  y::Float64
end

"""Represents a coordinate system / projection backed by Proj.jl."""
mutable struct GisCoordinateSystem
  prj_text::String    # raw .prj WKT content
  name::String
  crs::Union{Nothing, Proj.CRS}  # Proj.jl CRS object for reprojection
end

function GisCoordinateSystem(prj_text::String, name::String)
  crs = try
    Proj.CRS(prj_text)
  catch
    nothing
  end
  GisCoordinateSystem(prj_text, name, crs)
end

"""A single vector feature with geometry and properties."""
mutable struct GisVectorFeature
  geometry::Any              # Shapefile geometry
  shape_type::Symbol         # :point, :line, :polygon
  properties::Dict{String, Any}
  # Cached values
  _centroid::Union{Nothing, GisVertex}
  _envelope::Union{Nothing, NTuple{4, Float64}}  # (xmin, xmax, ymin, ymax)
end

GisVectorFeature(geom, stype, props) = GisVectorFeature(geom, stype, props, nothing, nothing)

"""A collection of vector features (from a shapefile)."""
mutable struct GisVectorDataset
  features::Vector{GisVectorFeature}
  property_names::Vector{String}
  shape_type::Symbol          # :point, :line, :polygon
  envelope::NTuple{4, Float64}  # (xmin, xmax, ymin, ymax)
  coordinate_system::Union{Nothing, GisCoordinateSystem}
end

"""A grid of numeric values (raster data)."""
mutable struct GisRasterDataset
  data::Matrix{Float64}       # row-major: data[row, col]
  width::Int
  height::Int
  nodata::Float64
  envelope::NTuple{4, Float64}  # (xmin, xmax, ymin, ymax)
  cellsize_x::Float64
  cellsize_y::Float64
  sampling_method::Symbol     # :nearest or :bilinear
  coordinate_system::Union{Nothing, GisCoordinateSystem}
end

"""Coordinate transformation between GIS space and NetLogo world space."""
mutable struct GisTransformation
  # GIS envelope
  gis_xmin::Float64
  gis_xmax::Float64
  gis_ymin::Float64
  gis_ymax::Float64
  # NetLogo world envelope
  nl_xmin::Float64
  nl_xmax::Float64
  nl_ymin::Float64
  nl_ymax::Float64
end

# Global transformation state (per-runtime, stored in observer globals)
const _TRANSFORM_KEY = "__GIS_TRANSFORM__"
const _DRAWING_COLOR_KEY = "__GIS_DRAWING_COLOR__"
const _CRS_KEY = "__GIS_COORDINATE_SYSTEM__"
const _COVERAGE_MIN_KEY = "__GIS_COVERAGE_MIN__"
const _COVERAGE_MAX_KEY = "__GIS_COVERAGE_MAX__"

"""Get the current world coordinate system (set via gis:set-coordinate-system)."""
function _get_world_crs(ctx::Context)::Union{Nothing, GisCoordinateSystem}
  get(ctx.runtime.world.observer.globals, _CRS_KEY, nothing)
end

"""Reproject a (x, y) coordinate pair from src_crs to dst_crs using Proj.jl."""
function _reproject_point(x::Float64, y::Float64, src_crs::GisCoordinateSystem, dst_crs::GisCoordinateSystem)
  (src_crs.crs === nothing || dst_crs.crs === nothing) && return (x, y)
  trans = Proj.Transformation(src_crs.crs, dst_crs.crs; always_xy=true)
  trans(x, y)
end

"""Reproject all features in a vector dataset from its CRS to dst_crs.
Modifies vertices in-place by replacing geometry with GisVertex-based representation."""
function _reproject_dataset!(ds::GisVectorDataset, dst_crs::GisCoordinateSystem)
  src_crs = ds.coordinate_system
  src_crs === nothing && return ds
  (src_crs.crs === nothing || dst_crs.crs === nothing) && return ds
  # Check if CRSes are the same
  src_crs.prj_text == dst_crs.prj_text && return ds
  trans = try
    Proj.Transformation(src_crs.crs, dst_crs.crs; always_xy=true)
  catch
    return ds
  end
  for f in ds.features
    _reproject_feature_vertices!(f, trans)
  end
  # Update dataset envelope
  ds.envelope = _compute_dataset_envelope(ds.features)
  ds.coordinate_system = dst_crs
  ds
end

function _reproject_feature_vertices!(f::GisVectorFeature, trans)
  verts = _extract_all_vertices(f.geometry)
  new_verts = GisVertex[]
  for v in verts
    x, y = trans(v.x, v.y)
    push!(new_verts, GisVertex(x, y))
  end
  # Store transformed vertices as the new geometry representation
  if f.shape_type == :point && length(new_verts) == 1
    f.geometry = new_verts[1]
  else
    f.geometry = _ReProjectedGeometry(f.geometry, new_verts)
  end
  f._centroid = nothing
  f._envelope = nothing
end

"""Wrapper that pairs the original geometry structure with reprojected vertex coords."""
struct _ReProjectedGeometry
  original::Any
  vertices::Vector{GisVertex}
end

function _extract_all_vertices(geom)::Vector{GisVertex}
  verts = GisVertex[]
  if geom isa GisVertex
    push!(verts, geom)
  elseif geom isa Shapefile.Point || geom isa Shapefile.PointM || geom isa Shapefile.PointZ
    push!(verts, GisVertex(Float64(geom.x), Float64(geom.y)))
  elseif geom isa _ReProjectedGeometry
    return geom.vertices
  elseif geom isa _GeoJSONGeometry
    return geom.vertices
  elseif hasproperty(geom, :points)
    for p in geom.points
      push!(verts, GisVertex(Float64(p.x), Float64(p.y)))
    end
  end
  verts
end

function _compute_dataset_envelope(features::Vector{GisVectorFeature})
  isempty(features) && return (0.0, 0.0, 0.0, 0.0)
  xmin = Inf; xmax = -Inf; ymin = Inf; ymax = -Inf
  for f in features
    env = _feature_envelope(f)
    xmin = min(xmin, env[1]); xmax = max(xmax, env[2])
    ymin = min(ymin, env[3]); ymax = max(ymax, env[4])
  end
  (xmin, xmax, ymin, ymax)
end

"""Reproject a raster dataset. Reprojects envelope corners only (no re-gridding)."""
function _reproject_raster_envelope!(ds::GisRasterDataset, dst_crs::GisCoordinateSystem)
  src_crs = ds.coordinate_system
  src_crs === nothing && return ds
  (src_crs.crs === nothing || dst_crs.crs === nothing) && return ds
  src_crs.prj_text == dst_crs.prj_text && return ds
  trans = try
    Proj.Transformation(src_crs.crs, dst_crs.crs; always_xy=true)
  catch
    return ds
  end
  xmin, xmax, ymin, ymax = ds.envelope
  x1, y1 = trans(xmin, ymin)
  x2, y2 = trans(xmax, ymin)
  x3, y3 = trans(xmax, ymax)
  x4, y4 = trans(xmin, ymax)
  new_xmin = min(x1, x2, x3, x4)
  new_xmax = max(x1, x2, x3, x4)
  new_ymin = min(y1, y2, y3, y4)
  new_ymax = max(y1, y2, y3, y4)
  ds.envelope = (new_xmin, new_xmax, new_ymin, new_ymax)
  ds.cellsize_x = (new_xmax - new_xmin) / ds.width
  ds.cellsize_y = (new_ymax - new_ymin) / ds.height
  ds.coordinate_system = dst_crs
  ds
end

# ═══════════════════════════════════════════════════════════════════════════
# Geometry Utilities
# ═══════════════════════════════════════════════════════════════════════════

function _envelope_of_points(points)
  isempty(points) && return (0.0, 0.0, 0.0, 0.0)
  xmin = Inf; xmax = -Inf; ymin = Inf; ymax = -Inf
  for p in points
    x, y = _point_coords(p)
    xmin = min(xmin, x); xmax = max(xmax, x)
    ymin = min(ymin, y); ymax = max(ymax, y)
  end
  (xmin, xmax, ymin, ymax)
end

function _point_coords(p)
  if p isa GisVertex
    return (p.x, p.y)
  elseif hasproperty(p, :x) && hasproperty(p, :y)
    return (Float64(p.x), Float64(p.y))
  else
    error("Cannot extract coordinates from $(typeof(p))")
  end
end

function _all_points(geom)
  points = Tuple{Float64, Float64}[]
  _collect_points!(points, geom)
  points
end

function _collect_points!(pts, geom)
  if geom isa _ReProjectedGeometry
    for v in geom.vertices
      push!(pts, (v.x, v.y))
    end
  elseif geom isa _GeoJSONGeometry
    for v in geom.vertices
      push!(pts, (v.x, v.y))
    end
  elseif geom isa GisVertex
    push!(pts, (geom.x, geom.y))
  elseif hasproperty(geom, :x) && hasproperty(geom, :y)
    push!(pts, (Float64(geom.x), Float64(geom.y)))
  elseif hasproperty(geom, :points)
    for p in geom.points
      _collect_points!(pts, p)
    end
  elseif geom isa AbstractVector
    for sub in geom
      _collect_points!(pts, sub)
    end
  elseif hasproperty(geom, :rings)
    for ring in geom.rings
      _collect_points!(pts, ring)
    end
  end
end

function _feature_envelope(feat::GisVectorFeature)
  if feat._envelope !== nothing
    return feat._envelope
  end
  pts = _all_points(feat.geometry)
  if isempty(pts)
    env = (0.0, 0.0, 0.0, 0.0)
  else
    xmin = minimum(p[1] for p in pts)
    xmax = maximum(p[1] for p in pts)
    ymin = minimum(p[2] for p in pts)
    ymax = maximum(p[2] for p in pts)
    env = (xmin, xmax, ymin, ymax)
  end
  feat._envelope = env
  env
end

function _feature_centroid(feat::GisVectorFeature)
  if feat._centroid !== nothing
    return feat._centroid
  end
  c = _feature_centroid_geos(feat)
  feat._centroid = c
  c
end

"""Test if point (px, py) is inside a polygon defined by rings of (x,y) points."""
function _point_in_polygon(px::Float64, py::Float64, rings::Vector{Vector{Tuple{Float64, Float64}}})
  inside = false
  for ring in rings
    n = length(ring)
    n < 3 && continue
    j = n
    for i in 1:n
      xi, yi = ring[i]
      xj, yj = ring[j]
      if ((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
        inside = !inside
      end
      j = i
    end
  end
  inside
end

"""Extract polygon rings as vectors of (x,y) tuples."""
function _polygon_rings(geom)::Vector{Vector{Tuple{Float64, Float64}}}
  rings = Vector{Tuple{Float64, Float64}}[]
  if geom isa _GeoJSONGeometry
    # Use GeoInterface to get proper ring structure
    gi_geom = geom.gi_geom
    trait = GI.geomtrait(gi_geom)
    if trait isa GI.PolygonTrait
      for ring_gi in GI.getring(gi_geom)
        ring = Tuple{Float64, Float64}[]
        for pt in GI.getpoint(ring_gi)
          coords = GI.coordinates(pt)
          push!(ring, (Float64(coords[1]), Float64(coords[2])))
        end
        push!(rings, ring)
      end
    elseif trait isa GI.MultiPolygonTrait
      for poly in GI.getgeom(gi_geom)
        for ring_gi in GI.getring(poly)
          ring = Tuple{Float64, Float64}[]
          for pt in GI.getpoint(ring_gi)
            coords = GI.coordinates(pt)
            push!(ring, (Float64(coords[1]), Float64(coords[2])))
          end
          push!(rings, ring)
        end
      end
    elseif trait isa GI.LineStringTrait || trait isa GI.MultiLineStringTrait
      # Treat lines as open rings for compatibility
      ring = Tuple{Float64, Float64}[(v.x, v.y) for v in geom.vertices]
      push!(rings, ring)
    else
      ring = Tuple{Float64, Float64}[(v.x, v.y) for v in geom.vertices]
      push!(rings, ring)
    end
  elseif geom isa _ReProjectedGeometry
    # For reprojected geometries, build rings from the transformed vertices
    # using the original geometry's structure for ring boundaries
    orig = geom.original
    verts = geom.vertices
    if hasproperty(orig, :points) && hasproperty(orig, :parts)
      parts = orig.parts
      npts = length(verts)
      for (pi, start_idx) in enumerate(parts)
        end_idx = pi < length(parts) ? parts[pi + 1] - 1 : npts - 1
        ring = Tuple{Float64, Float64}[]
        for i in (start_idx + 1):(end_idx + 1)
          i <= length(verts) || continue
          push!(ring, (verts[i].x, verts[i].y))
        end
        push!(rings, ring)
      end
    else
      ring = Tuple{Float64, Float64}[(v.x, v.y) for v in verts]
      push!(rings, ring)
    end
  elseif hasproperty(geom, :points)
    ring = Tuple{Float64, Float64}[]
    for p in geom.points
      push!(ring, (Float64(p.x), Float64(p.y)))
    end
    push!(rings, ring)
  elseif geom isa AbstractVector
    for sub in geom
      append!(rings, _polygon_rings(sub))
    end
  elseif hasproperty(geom, :rings)
    for r in geom.rings
      ring = Tuple{Float64, Float64}[]
      if hasproperty(r, :points)
        for p in r.points
          push!(ring, (Float64(p.x), Float64(p.y)))
        end
      elseif r isa AbstractVector
        for p in r
          push!(ring, (Float64(p.x), Float64(p.y)))
        end
      end
      push!(rings, ring)
    end
  end
  rings
end

"""Envelopes intersect test."""
function _envelopes_intersect(e1::NTuple{4,Float64}, e2::NTuple{4,Float64})
  !(e1[2] < e2[1] || e2[2] < e1[1] || e1[4] < e2[3] || e2[4] < e1[3])
end

"""Envelope contains point."""
function _envelope_contains_point(env::NTuple{4,Float64}, x::Float64, y::Float64)
  env[1] <= x <= env[2] && env[3] <= y <= env[4]
end

"""Test if feature geometry contains point (px, py)."""
function _feature_contains_point(feat::GisVectorFeature, px::Float64, py::Float64)
  env = _feature_envelope(feat)
  _envelope_contains_point(env, px, py) || return false
  if feat.shape_type == :polygon
    rings = _polygon_rings(feat.geometry)
    return _point_in_polygon(px, py, rings)
  elseif feat.shape_type == :point
    pts = _all_points(feat.geometry)
    for (x, y) in pts
      if abs(x - px) < 1e-10 && abs(y - py) < 1e-10
        return true
      end
    end
    return false
  else
    return false
  end
end

"""Test if two features intersect using LibGEOS for accurate results."""
function _features_intersect(feat1, feat2)
  e1 = _get_envelope(feat1)
  e2 = _get_envelope(feat2)
  _envelopes_intersect(e1, e2) || return false
  # Use LibGEOS for precise intersection test
  g1 = _to_libgeos(feat1)
  g2 = _to_libgeos(feat2)
  (g1 === nothing || g2 === nothing) && return true  # fallback to envelope test
  LibGEOS.intersects(g1, g2)
end

"""Test if feat1 contains feat2 using LibGEOS."""
function _feature_contains(feat1, feat2)
  g1 = _to_libgeos(feat1)
  g2 = _to_libgeos(feat2)
  (g1 === nothing || g2 === nothing) && return false
  LibGEOS.contains(g1, g2)
end

"""Compute DE-9IM relationship between two features using LibGEOS."""
function _feature_relationship(feat1, feat2)::String
  g1 = _to_libgeos(feat1)
  g2 = _to_libgeos(feat2)
  (g1 === nothing || g2 === nothing) && return "FFFFFFFFF"
  ctx = LibGEOS.get_global_context()
  LibGEOS.GEOSRelate_r(ctx, g1.ptr, g2.ptr)
end

"""Test DE-9IM pattern match between two features."""
function _feature_relate_pattern(feat1, feat2, pattern::String)::Bool
  g1 = _to_libgeos(feat1)
  g2 = _to_libgeos(feat2)
  (g1 === nothing || g2 === nothing) && return false
  ctx = LibGEOS.get_global_context()
  LibGEOS.GEOSRelatePattern_r(ctx, g1.ptr, g2.ptr, pattern) == 1
end

"""Convert a GIS feature to a LibGEOS geometry."""
function _to_libgeos(obj)
  if obj isa GisVectorFeature
    return _feature_to_libgeos(obj)
  elseif obj isa GisVectorDataset
    # Convert dataset envelope to a rectangle
    env = obj.envelope
    return _envelope_to_libgeos(env)
  elseif obj isa GisRasterDataset
    env = obj.envelope
    return _envelope_to_libgeos(env)
  elseif obj isa NTuple{4, Float64}
    return _envelope_to_libgeos(obj)
  end
  nothing
end

function _envelope_to_libgeos(env::NTuple{4, Float64})
  xmin, xmax, ymin, ymax = env
  LibGEOS.readgeom("POLYGON(($xmin $ymin, $xmax $ymin, $xmax $ymax, $xmin $ymax, $xmin $ymin))")
end

function _feature_to_libgeos(feat::GisVectorFeature)
  pts = _all_points(feat.geometry)
  isempty(pts) && return nothing
  if feat.shape_type == :point
    length(pts) == 1 && return LibGEOS.readgeom("POINT($(pts[1][1]) $(pts[1][2]))")
    wkt = "MULTIPOINT(" * join(["($(p[1]) $(p[2]))" for p in pts], ", ") * ")"
    return LibGEOS.readgeom(wkt)
  elseif feat.shape_type == :line
    if length(pts) < 2
      return nothing
    end
    rings = _polygon_rings(feat.geometry)  # reuse for line parts
    if length(rings) == 1
      wkt = "LINESTRING(" * join(["$(p[1]) $(p[2])" for p in rings[1]], ", ") * ")"
    else
      parts = ["(" * join(["$(p[1]) $(p[2])" for p in r], ", ") * ")" for r in rings if length(r) >= 2]
      isempty(parts) && return nothing
      wkt = "MULTILINESTRING(" * join(parts, ", ") * ")"
    end
    return LibGEOS.readgeom(wkt)
  elseif feat.shape_type == :polygon
    rings = _polygon_rings(feat.geometry)
    isempty(rings) && return nothing
    # First ring is outer, rest are holes
    parts = String[]
    for ring in rings
      length(ring) < 3 && continue
      # Ensure ring is closed
      r = ring
      if r[1] != r[end]
        r = vcat(r, [r[1]])
      end
      push!(parts, "(" * join(["$(p[1]) $(p[2])" for p in r], ", ") * ")")
    end
    isempty(parts) && return nothing
    wkt = "POLYGON(" * join(parts, ", ") * ")"
    return try
      LibGEOS.readgeom(wkt)
    catch
      nothing
    end
  end
  nothing
end

"""Compute proper centroid using LibGEOS (true centroid, not vertex average)."""
function _feature_centroid_geos(feat::GisVectorFeature)
  g = _feature_to_libgeos(feat)
  if g !== nothing
    c = LibGEOS.centroid(g)
    x = LibGEOS.getGeomX(c)
    y = LibGEOS.getGeomY(c)
    return GisVertex(x, y)
  end
  # Fallback to vertex average
  pts = _all_points(feat.geometry)
  isempty(pts) && return GisVertex(0.0, 0.0)
  GisVertex(sum(p[1] for p in pts) / length(pts), sum(p[2] for p in pts) / length(pts))
end

function _get_envelope(obj)
  if obj isa GisVectorFeature
    return _feature_envelope(obj)
  elseif obj isa GisVectorDataset
    return obj.envelope
  elseif obj isa GisRasterDataset
    return obj.envelope
  elseif obj isa NTuple{4, Float64}
    return obj
  else
    throw(LogoRuntimeError("Cannot get envelope of $(typeof(obj))"))
  end
end

"""Generate a random point inside a polygon feature."""
function _random_point_inside(feat::GisVectorFeature)
  feat.shape_type == :polygon || throw(LogoRuntimeError("gis:random-point-inside requires a polygon feature"))
  env = _feature_envelope(feat)
  rings = _polygon_rings(feat.geometry)
  for _ in 1:10000
    x = env[1] + rand() * (env[2] - env[1])
    y = env[3] + rand() * (env[4] - env[3])
    if _point_in_polygon(x, y, rings)
      return GisVertex(x, y)
    end
  end
  cx = (env[1] + env[2]) / 2
  cy = (env[3] + env[4]) / 2
  GisVertex(cx, cy)
end

# ═══════════════════════════════════════════════════════════════════════════
# Coordinate Transformation
# ═══════════════════════════════════════════════════════════════════════════

function _get_transform(ctx::Context)::Union{Nothing, GisTransformation}
  globals = ctx.runtime.world.observer.globals
  get(globals, _TRANSFORM_KEY, nothing)
end

function _set_transform!(ctx::Context, t::GisTransformation)
  ctx.runtime.world.observer.globals[_TRANSFORM_KEY] = t
end

function _gis_to_netlogo(t::GisTransformation, gx::Float64, gy::Float64)
  nx = t.nl_xmin + (gx - t.gis_xmin) / (t.gis_xmax - t.gis_xmin) * (t.nl_xmax - t.nl_xmin)
  ny = t.nl_ymin + (gy - t.gis_ymin) / (t.gis_ymax - t.gis_ymin) * (t.nl_ymax - t.nl_ymin)
  (nx, ny)
end

function _netlogo_to_gis(t::GisTransformation, nx::Float64, ny::Float64)
  gx = t.gis_xmin + (nx - t.nl_xmin) / (t.nl_xmax - t.nl_xmin) * (t.gis_xmax - t.gis_xmin)
  gy = t.gis_ymin + (ny - t.nl_ymin) / (t.nl_ymax - t.nl_ymin) * (t.gis_ymax - t.gis_ymin)
  (gx, gy)
end

function _make_world_transform(ctx::Context, gis_env::NTuple{4, Float64})
  world = ctx.runtime.world
  nl_xmin = Float64(world.min_pxcor) - 0.5
  nl_xmax = Float64(world.max_pxcor) + 0.5
  nl_ymin = Float64(world.min_pycor) - 0.5
  nl_ymax = Float64(world.max_pycor) + 0.5
  GisTransformation(
    gis_env[1], gis_env[2], gis_env[3], gis_env[4],
    nl_xmin, nl_xmax, nl_ymin, nl_ymax
  )
end

# ═══════════════════════════════════════════════════════════════════════════
# File Loading
# ═══════════════════════════════════════════════════════════════════════════

function _detect_shape_type(shp_table)
  for row in shp_table
    geom = Shapefile.shape(row)
    if geom isa Shapefile.Point || geom isa Shapefile.PointM || geom isa Shapefile.PointZ
      return :point
    elseif geom isa Shapefile.Polyline || geom isa Shapefile.PolylineM || geom isa Shapefile.PolylineZ
      return :line
    elseif geom isa Shapefile.Polygon || geom isa Shapefile.PolygonM || geom isa Shapefile.PolygonZ
      return :polygon
    end
  end
  :unknown
end

function _load_shapefile(filepath::String)::GisVectorDataset
  tbl = Shapefile.Table(filepath)

  # Get column names (exclude :geometry)
  all_cols = Tables.columnnames(tbl)
  col_names = String[String(nm) for nm in all_cols if nm != :geometry]

  shape_type = _detect_shape_type(tbl)

  features = GisVectorFeature[]
  xmin = Inf; xmax = -Inf; ymin = Inf; ymax = -Inf

  for row in tbl
    geom = Shapefile.shape(row)
    props = Dict{String, Any}()
    for nm in col_names
      val = getproperty(row, Symbol(nm))
      props[nm] = val === missing ? "" : (val isa AbstractString ? String(val) : val)
    end
    feat = GisVectorFeature(geom, shape_type, props)
    env = _feature_envelope(feat)
    xmin = min(xmin, env[1]); xmax = max(xmax, env[2])
    ymin = min(ymin, env[3]); ymax = max(ymax, env[4])
    push!(features, feat)
  end

  if isempty(features)
    envelope = (0.0, 0.0, 0.0, 0.0)
  else
    envelope = (xmin, xmax, ymin, ymax)
  end

  # Try loading .prj
  prj_path = replace(filepath, r"\.shp$"i => ".prj")
  coord_sys = nothing
  if isfile(prj_path)
    prj_text = read(prj_path, String)
    coord_sys = GisCoordinateSystem(prj_text, "from_prj")
  end

  GisVectorDataset(features, col_names, shape_type, envelope, coord_sys)
end

function _load_ascii_grid(filepath::String)::GisRasterDataset
  lines = readlines(filepath)
  header = Dict{String, String}()
  data_start = 1

  for (i, line) in enumerate(lines)
    parts = split(strip(line))
    if length(parts) == 2 && !isdigit(first(parts[1]))
      header[lowercase(parts[1])] = parts[2]
      data_start = i + 1
    else
      break
    end
  end

  ncols = parse(Int, get(header, "ncols", "0"))
  nrows = parse(Int, get(header, "nrows", "0"))
  xllcorner = parse(Float64, get(header, "xllcorner", get(header, "xllcenter", "0")))
  yllcorner = parse(Float64, get(header, "yllcorner", get(header, "yllcenter", "0")))
  cellsize = parse(Float64, get(header, "cellsize", "1"))
  nodata = parse(Float64, get(header, "nodata_value", "-9999"))

  data = fill(nodata, nrows, ncols)
  for r in 1:nrows
    line_idx = data_start + r - 1
    if line_idx <= length(lines)
      vals = split(strip(lines[line_idx]))
      for c in 1:min(ncols, length(vals))
        v = tryparse(Float64, vals[c])
        if v !== nothing
          data[r, c] = v
        end
      end
    end
  end

  xmin = xllcorner
  ymin = yllcorner
  xmax = xllcorner + ncols * cellsize
  ymax = yllcorner + nrows * cellsize

  GisRasterDataset(data, ncols, nrows, nodata, (xmin, xmax, ymin, ymax),
    cellsize, cellsize, :bilinear, nothing)
end

"""Load a GeoJSON file and return a GisVectorDataset."""
function _load_geojson(filepath::String)::GisVectorDataset
  geojson_text = read(filepath, String)
  fc = GeoJSON.read(geojson_text)

  features = GisVectorFeature[]
  property_names_set = Set{String}()
  xmin = Inf; xmax = -Inf; ymin = Inf; ymax = -Inf
  detected_type = :point

  for feat_gi in GI.getfeature(fc)
    geom_gi = GI.geometry(feat_gi)
    geom_gi === nothing && continue

    # Determine shape type
    geom_trait = GI.geomtrait(geom_gi)
    shape_type = if geom_trait isa GI.PointTrait || geom_trait isa GI.MultiPointTrait
      :point
    elseif geom_trait isa GI.LineStringTrait || geom_trait isa GI.MultiLineStringTrait
      :line
    elseif geom_trait isa GI.PolygonTrait || geom_trait isa GI.MultiPolygonTrait
      :polygon
    else
      :polygon
    end
    detected_type = shape_type

    # Convert geometry to our GisVertex-based representation
    vertices = GisVertex[]
    _collect_gi_vertices!(vertices, geom_gi)

    geom = if shape_type == :point && length(vertices) == 1
      vertices[1]
    else
      _GeoJSONGeometry(geom_gi, vertices)
    end

    # Extract properties
    props = Dict{String, Any}()
    if hasproperty(feat_gi, :properties)
      for (k, v) in pairs(GI.properties(feat_gi))
        key = String(k)
        props[key] = v === nothing ? "" : v
        push!(property_names_set, key)
      end
    end

    gf = GisVectorFeature(geom, shape_type, props)
    env = _feature_envelope(gf)
    xmin = min(xmin, env[1]); xmax = max(xmax, env[2])
    ymin = min(ymin, env[3]); ymax = max(ymax, env[4])
    push!(features, gf)
  end

  envelope = isempty(features) ? (0.0, 0.0, 0.0, 0.0) : (xmin, xmax, ymin, ymax)
  prop_names = sort(collect(property_names_set))

  # GeoJSON is always WGS84 (EPSG:4326) by specification
  coord_sys = GisCoordinateSystem(
    "GEOGCS[\"GCS_WGS_1984\",DATUM[\"D_WGS_1984\",SPHEROID[\"WGS_1984\",6378137.0,298.257223563]],PRIMEM[\"Greenwich\",0.0],UNIT[\"Degree\",0.0174532925199433]]",
    "WGS_84"
  )

  GisVectorDataset(features, prop_names, detected_type, envelope, coord_sys)
end

"""Wrapper for GeoJSON geometry preserving both GeoInterface geometry and extracted vertices."""
struct _GeoJSONGeometry
  gi_geom::Any
  vertices::Vector{GisVertex}
end

function _collect_gi_vertices!(verts::Vector{GisVertex}, geom)
  trait = GI.geomtrait(geom)
  if trait isa GI.PointTrait
    coords = GI.coordinates(geom)
    push!(verts, GisVertex(Float64(coords[1]), Float64(coords[2])))
  elseif trait isa GI.MultiPointTrait
    for pt in GI.getpoint(geom)
      _collect_gi_vertices!(verts, pt)
    end
  elseif trait isa GI.LineStringTrait
    for pt in GI.getpoint(geom)
      coords = GI.coordinates(pt)
      push!(verts, GisVertex(Float64(coords[1]), Float64(coords[2])))
    end
  elseif trait isa GI.MultiLineStringTrait
    for line in GI.getgeom(geom)
      _collect_gi_vertices!(verts, line)
    end
  elseif trait isa GI.PolygonTrait
    for ring in GI.getring(geom)
      for pt in GI.getpoint(ring)
        coords = GI.coordinates(pt)
        push!(verts, GisVertex(Float64(coords[1]), Float64(coords[2])))
      end
    end
  elseif trait isa GI.MultiPolygonTrait
    for poly in GI.getgeom(geom)
      _collect_gi_vertices!(verts, poly)
    end
  end
end

function _load_dataset(filepath::String)
  ext = lowercase(splitext(filepath)[2])
  if ext == ".shp"
    return _load_shapefile(filepath)
  elseif ext in (".asc", ".grd", ".txt")
    return _load_ascii_grid(filepath)
  elseif ext in (".geojson", ".json")
    return _load_geojson(filepath)
  else
    throw(LogoRuntimeError("gis:load-dataset: unsupported file type '$ext'. Supported: .shp, .asc, .grd, .geojson, .json"))
  end
end

# ═══════════════════════════════════════════════════════════════════════════
# Coverage Application (vector → patches)
# ═══════════════════════════════════════════════════════════════════════════

function _apply_coverage!(ctx::Context, dataset::GisVectorDataset,
                          src_property::String, dest_variable::String)
  transform = _get_transform(ctx)
  transform === nothing && throw(LogoRuntimeError(
    "gis:apply-coverage: No GIS transformation set. Use gis:set-world-envelope first."))

  world = ctx.runtime.world
  dest_var = canonical_name(dest_variable)

  for py in world.min_pycor:world.max_pycor
    for px in world.min_pxcor:world.max_pxcor
      patch = patch_at_coords(world, px, py)
      patch === nothing && continue
      # Convert patch center to GIS coordinates
      gx, gy = _netlogo_to_gis(transform, Float64(px), Float64(py))
      # Find containing feature
      for feat in dataset.features
        if _feature_contains_point(feat, gx, gy)
          val = get(feat.properties, src_property, nothing)
          if val !== nothing
            set_patch_variable!(patch, dest_var, val isa Number ? Float64(val) : val)
          end
          break
        end
      end
    end
  end
  nothing
end

# ═══════════════════════════════════════════════════════════════════════════
# Raster Application (raster → patches)
# ═══════════════════════════════════════════════════════════════════════════

function _apply_raster!(ctx::Context, raster::GisRasterDataset, dest_variable::String)
  transform = _get_transform(ctx)
  transform === nothing && throw(LogoRuntimeError(
    "gis:apply-raster: No GIS transformation set. Use gis:set-world-envelope first."))

  world = ctx.runtime.world
  dest_var = canonical_name(dest_variable)

  for py in world.min_pycor:world.max_pycor
    for px in world.min_pxcor:world.max_pxcor
      patch = patch_at_coords(world, px, py)
      patch === nothing && continue
      gx, gy = _netlogo_to_gis(transform, Float64(px), Float64(py))
      val = _sample_raster(raster, gx, gy)
      if val !== nothing && val != raster.nodata
        set_patch_variable!(patch, dest_var, Float64(val))
      end
    end
  end
  nothing
end

function _sample_raster(raster::GisRasterDataset, gx::Float64, gy::Float64)
  env = raster.envelope
  # Check bounds
  (gx < env[1] || gx > env[2] || gy < env[3] || gy > env[4]) && return nothing
  # Convert to grid coordinates (row, col)
  col_f = (gx - env[1]) / raster.cellsize_x
  row_f = (env[4] - gy) / raster.cellsize_y  # rows are top-to-bottom

  if raster.sampling_method == :nearest
    col = clamp(round(Int, col_f) + 1, 1, raster.width)
    row = clamp(round(Int, row_f) + 1, 1, raster.height)
    return raster.data[row, col]
  else  # bilinear
    c0 = clamp(floor(Int, col_f) + 1, 1, raster.width)
    c1 = clamp(c0 + 1, 1, raster.width)
    r0 = clamp(floor(Int, row_f) + 1, 1, raster.height)
    r1 = clamp(r0 + 1, 1, raster.height)
    fx = col_f - floor(col_f)
    fy = row_f - floor(row_f)
    v00 = raster.data[r0, c0]
    v10 = raster.data[r0, c1]
    v01 = raster.data[r1, c0]
    v11 = raster.data[r1, c1]
    v = v00 * (1-fx)*(1-fy) + v10 * fx*(1-fy) + v01 * (1-fx)*fy + v11 * fx*fy
    return v
  end
end

# ═══════════════════════════════════════════════════════════════════════════
# Vertex Lists for Features
# ═══════════════════════════════════════════════════════════════════════════

function _vertex_lists(feat::GisVectorFeature)
  if feat.shape_type == :point
    pts = _all_points(feat.geometry)
    return Any[Any[Any[p[1], p[2]] for p in pts]]
  elseif feat.shape_type == :line
    pts = _all_points(feat.geometry)
    return Any[Any[Any[p[1], p[2]] for p in pts]]
  else  # polygon
    rings = _polygon_rings(feat.geometry)
    return Any[Any[Any[p[1], p[2]] for p in ring] for ring in rings]
  end
end

# ═══════════════════════════════════════════════════════════════════════════
# Extension Registration
# ═══════════════════════════════════════════════════════════════════════════

function register_extension!(registry::PrimitiveRegistry)

  # ── Dataset Loading ───────────────────────────────────────────────────
  register_primitive!(registry, "GIS:LOAD-DATASET", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> _load_dataset(String(args[1])))

  register_primitive!(registry, "GIS:STORE-DATASET", COMMAND,
    command_syntax(right=[WildcardType, StringType]),
    (ctx, args) -> begin
      ds = args[1]; path = String(args[2])
      if ds isa GisRasterDataset
        open(path, "w") do io
          println(io, "ncols         $(ds.width)")
          println(io, "nrows         $(ds.height)")
          println(io, "xllcorner     $(ds.envelope[1])")
          println(io, "yllcorner     $(ds.envelope[3])")
          println(io, "cellsize      $(ds.cellsize_x)")
          println(io, "NODATA_value  $(ds.nodata)")
          for r in 1:ds.height
            vals = join((ds.data[r, c] == ds.nodata ? string(ds.nodata) :
                         string(ds.data[r, c]) for c in 1:ds.width), " ")
            println(io, vals)
          end
        end
      elseif ds isa GisVectorDataset
        throw(LogoRuntimeError("gis:store-dataset for vector datasets is not supported (use GIS tools to convert)"))
      else
        throw(LogoRuntimeError("gis:store-dataset expected a GIS dataset"))
      end
      nothing
    end)

  register_primitive!(registry, "GIS:TYPE-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=StringType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset && return "VECTOR"
      ds isa GisRasterDataset && return "RASTER"
      throw(LogoRuntimeError("gis:type-of expected a GIS dataset"))
    end)

  # ── Coordinate System ─────────────────────────────────────────────────
  register_primitive!(registry, "GIS:LOAD-COORDINATE-SYSTEM", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> begin
      path = String(args[1])
      isfile(path) || throw(LogoRuntimeError("gis:load-coordinate-system: file not found: $path"))
      GisCoordinateSystem(read(path, String), basename(path))
    end)

  register_primitive!(registry, "GIS:SET-COORDINATE-SYSTEM", COMMAND,
    command_syntax(right=[WildcardType]),
    (ctx, args) -> begin
      arg = args[1]
      crs = if arg isa GisCoordinateSystem
        arg
      elseif arg isa AbstractString
        prj = String(arg)
        # Support well-known CRS names like "WGS_84_Geographic" or EPSG codes
        if startswith(prj, "GEOGCS") || startswith(prj, "PROJCS")
          GisCoordinateSystem(prj, "custom")
        else
          # Try as Proj string or EPSG code
          GisCoordinateSystem(prj, prj)
        end
      else
        throw(LogoRuntimeError("gis:set-coordinate-system expected a coordinate system or WKT string"))
      end
      ctx.runtime.world.observer.globals[_CRS_KEY] = crs
      nothing
    end)

  # ── World Envelope / Transformation ────────────────────────────────────
  register_primitive!(registry, "GIS:SET-WORLD-ENVELOPE", COMMAND,
    command_syntax(right=[ListType]),
    (ctx, args) -> begin
      env = args[1]
      length(env) >= 4 || throw(LogoRuntimeError("gis:set-world-envelope expects a list of 4 numbers"))
      gis_env = (Float64(env[1]), Float64(env[2]), Float64(env[3]), Float64(env[4]))
      _set_transform!(ctx, _make_world_transform(ctx, gis_env))
      nothing
    end)

  register_primitive!(registry, "GIS:SET-WORLD-ENVELOPE-DS", COMMAND,
    command_syntax(right=[ListType]),
    (ctx, args) -> begin
      env = args[1]
      length(env) >= 4 || throw(LogoRuntimeError("gis:set-world-envelope-ds expects a list of 4 numbers"))
      gis_env = (Float64(env[1]), Float64(env[2]), Float64(env[3]), Float64(env[4]))
      _set_transform!(ctx, _make_world_transform(ctx, gis_env))
      nothing
    end)

  register_primitive!(registry, "GIS:WORLD-ENVELOPE", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> begin
      t = _get_transform(ctx)
      t === nothing && throw(LogoRuntimeError("No GIS transformation set"))
      Any[t.gis_xmin, t.gis_xmax, t.gis_ymin, t.gis_ymax]
    end)

  register_primitive!(registry, "GIS:SET-TRANSFORMATION", COMMAND,
    command_syntax(right=[ListType, ListType]),
    (ctx, args) -> begin
      gis_env = args[1]
      nl_env = args[2]
      length(gis_env) >= 4 || throw(LogoRuntimeError("GIS envelope needs 4 numbers"))
      length(nl_env) >= 4 || throw(LogoRuntimeError("NetLogo envelope needs 4 numbers"))
      _set_transform!(ctx, GisTransformation(
        Float64(gis_env[1]), Float64(gis_env[2]), Float64(gis_env[3]), Float64(gis_env[4]),
        Float64(nl_env[1]), Float64(nl_env[2]), Float64(nl_env[3]), Float64(nl_env[4])))
      nothing
    end)

  register_primitive!(registry, "GIS:SET-TRANSFORMATION-DS", COMMAND,
    command_syntax(right=[ListType, ListType]),
    (ctx, args) -> begin
      gis_env = args[1]
      nl_env = args[2]
      length(gis_env) >= 4 || throw(LogoRuntimeError("GIS envelope needs 4 numbers"))
      length(nl_env) >= 4 || throw(LogoRuntimeError("NetLogo envelope needs 4 numbers"))
      _set_transform!(ctx, GisTransformation(
        Float64(gis_env[1]), Float64(gis_env[2]), Float64(gis_env[3]), Float64(gis_env[4]),
        Float64(nl_env[1]), Float64(nl_env[2]), Float64(nl_env[3]), Float64(nl_env[4])))
      nothing
    end)

  # ── Envelope Operations ────────────────────────────────────────────────
  register_primitive!(registry, "GIS:ENVELOPE-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      obj = args[1]
      env = _get_envelope(obj)
      Any[env[1], env[2], env[3], env[4]]
    end)

  register_primitive!(registry, "GIS:ENVELOPE-UNION-OF", REPORTER,
    reporter_syntax(right=[ListType, ListType], ret=ListType),
    (ctx, args) -> begin
      e1 = args[1]; e2 = args[2]
      Any[min(e1[1], e2[1]), max(e1[2], e2[2]), min(e1[3], e2[3]), max(e1[4], e2[4])]
    end)

  # ── Vector Dataset Operations ──────────────────────────────────────────
  register_primitive!(registry, "GIS:PROPERTY-NAMES", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:property-names expected a vector dataset"))
      Any[String(n) for n in ds.property_names]
    end)

  register_primitive!(registry, "GIS:FEATURE-LIST-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:feature-list-of expected a vector dataset"))
      Any[f for f in ds.features]
    end)

  register_primitive!(registry, "GIS:SHAPE-TYPE-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=StringType),
    (ctx, args) -> begin
      obj = args[1]
      if obj isa GisVectorDataset
        return uppercase(string(obj.shape_type))
      elseif obj isa GisVectorFeature
        return uppercase(string(obj.shape_type))
      end
      throw(LogoRuntimeError("gis:shape-type-of expected a vector dataset or feature"))
    end)

  # ── Feature Operations ─────────────────────────────────────────────────
  register_primitive!(registry, "GIS:PROPERTY-VALUE", REPORTER,
    reporter_syntax(right=[WildcardType, StringType], ret=WildcardType),
    (ctx, args) -> begin
      feat = args[1]
      feat isa GisVectorFeature || throw(LogoRuntimeError("gis:property-value expected a vector feature"))
      prop = String(args[2])
      val = get(feat.properties, prop, nothing)
      val === nothing && throw(LogoRuntimeError("No property '$prop' in feature"))
      val isa Number ? Float64(val) : val
    end)

  register_primitive!(registry, "GIS:SET-PROPERTY-VALUE", COMMAND,
    command_syntax(right=[WildcardType, StringType, WildcardType]),
    (ctx, args) -> begin
      feat = args[1]
      feat isa GisVectorFeature || throw(LogoRuntimeError("gis:set-property-value expected a vector feature"))
      feat.properties[String(args[2])] = args[3]
      nothing
    end)

  register_primitive!(registry, "GIS:CENTROID-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      feat = args[1]
      feat isa GisVectorFeature || throw(LogoRuntimeError("gis:centroid-of expected a vector feature"))
      _feature_centroid(feat)
    end)

  register_primitive!(registry, "GIS:RANDOM-POINT-INSIDE", REPORTER,
    reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      feat = args[1]
      feat isa GisVectorFeature || throw(LogoRuntimeError("gis:random-point-inside expected a polygon feature"))
      _random_point_inside(feat)
    end)

  register_primitive!(registry, "GIS:VERTEX-LISTS-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      feat = args[1]
      feat isa GisVectorFeature || throw(LogoRuntimeError("gis:vertex-lists-of expected a vector feature"))
      _vertex_lists(feat)
    end)

  register_primitive!(registry, "GIS:LOCATION-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      v = args[1]
      if v isa GisVertex
        t = _get_transform(ctx)
        if t !== nothing
          nx, ny = _gis_to_netlogo(t, v.x, v.y)
          return Any[nx, ny]
        end
        return Any[v.x, v.y]
      end
      throw(LogoRuntimeError("gis:location-of expected a GIS vertex"))
    end)

  # ── Feature Search ─────────────────────────────────────────────────────
  register_primitive!(registry, "GIS:FIND-FEATURES", REPORTER,
    reporter_syntax(right=[WildcardType, StringType, WildcardType], ret=ListType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:find-features expected a vector dataset"))
      prop = String(args[2])
      value = args[3]
      result = Any[]
      for feat in ds.features
        fval = get(feat.properties, prop, nothing)
        if fval !== nothing
          if (fval isa Number && value isa Number && Float64(fval) == Float64(value)) ||
             (fval isa AbstractString && value isa AbstractString && fval == value)
            push!(result, feat)
          end
        end
      end
      result
    end)

  register_primitive!(registry, "GIS:FIND-ONE-FEATURE", REPORTER,
    reporter_syntax(right=[WildcardType, StringType, WildcardType], ret=WildcardType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:find-one-feature expected a vector dataset"))
      prop = String(args[2])
      value = args[3]
      for feat in ds.features
        fval = get(feat.properties, prop, nothing)
        if fval !== nothing
          if (fval isa Number && value isa Number && Float64(fval) == Float64(value)) ||
             (fval isa AbstractString && value isa AbstractString && fval == value)
            return feat
          end
        end
      end
      throw(LogoRuntimeError("No feature found with $prop = $(logo_string(value))"))
    end)

  register_primitive!(registry, "GIS:FIND-LESS-THAN", REPORTER,
    reporter_syntax(right=[WildcardType, StringType, NumberType], ret=ListType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("Expected vector dataset"))
      prop = String(args[2]); threshold = Float64(args[3])
      Any[f for f in ds.features if begin
        v = get(f.properties, prop, nothing)
        v !== nothing && v isa Number && Float64(v) < threshold
      end]
    end)

  register_primitive!(registry, "GIS:FIND-GREATER-THAN", REPORTER,
    reporter_syntax(right=[WildcardType, StringType, NumberType], ret=ListType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("Expected vector dataset"))
      prop = String(args[2]); threshold = Float64(args[3])
      Any[f for f in ds.features if begin
        v = get(f.properties, prop, nothing)
        v !== nothing && v isa Number && Float64(v) > threshold
      end]
    end)

  register_primitive!(registry, "GIS:FIND-RANGE", REPORTER,
    reporter_syntax(right=[WildcardType, StringType, NumberType, NumberType], ret=ListType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("Expected vector dataset"))
      prop = String(args[2]); lo = Float64(args[3]); hi = Float64(args[4])
      Any[f for f in ds.features if begin
        v = get(f.properties, prop, nothing)
        v !== nothing && v isa Number && lo <= Float64(v) <= hi
      end]
    end)

  register_primitive!(registry, "GIS:PROPERTY-MINIMUM", REPORTER,
    reporter_syntax(right=[WildcardType, StringType], ret=NumberType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("Expected vector dataset"))
      prop = String(args[2])
      vals = Float64[Float64(f.properties[prop]) for f in ds.features
                      if haskey(f.properties, prop) && f.properties[prop] isa Number]
      isempty(vals) && throw(LogoRuntimeError("No numeric values for property '$prop'"))
      minimum(vals)
    end)

  register_primitive!(registry, "GIS:PROPERTY-MAXIMUM", REPORTER,
    reporter_syntax(right=[WildcardType, StringType], ret=NumberType),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("Expected vector dataset"))
      prop = String(args[2])
      vals = Float64[Float64(f.properties[prop]) for f in ds.features
                      if haskey(f.properties, prop) && f.properties[prop] isa Number]
      isempty(vals) && throw(LogoRuntimeError("No numeric values for property '$prop'"))
      maximum(vals)
    end)

  # ── Coverage Application ───────────────────────────────────────────────
  register_primitive!(registry, "GIS:APPLY-COVERAGE", COMMAND,
    command_syntax(right=[WildcardType, SymbolType, SymbolType], arg_modes=[:eval, :symbol, :symbol]),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:apply-coverage expected a vector dataset"))
      _apply_coverage!(ctx, ds, String(args[2]), String(args[3]))
    end)

  register_primitive!(registry, "GIS:APPLY-COVERAGES", COMMAND,
    command_syntax(right=[WildcardType, ListType, ListType]),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:apply-coverages expected a vector dataset"))
      src_props = args[2]; dest_vars = args[3]
      length(src_props) == length(dest_vars) || throw(LogoRuntimeError("Property and variable lists must be same length"))
      for (src, dest) in zip(src_props, dest_vars)
        _apply_coverage!(ctx, ds, String(src), String(dest))
      end
    end)

  register_primitive!(registry, "GIS:COVERAGE-MINIMUM-THRESHOLD", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> begin
      g = ctx.runtime.world.observer.globals
      get(g, "__GIS_COV_MIN_THRESH", 0.1)
    end)

  register_primitive!(registry, "GIS:SET-COVERAGE-MINIMUM-THRESHOLD", COMMAND,
    command_syntax(right=[NumberType]),
    (ctx, args) -> begin
      ctx.runtime.world.observer.globals["__GIS_COV_MIN_THRESH"] = Float64(args[1])
      nothing
    end)

  register_primitive!(registry, "GIS:COVERAGE-MAXIMUM-THRESHOLD", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> begin
      g = ctx.runtime.world.observer.globals
      get(g, "__GIS_COV_MAX_THRESH", 0.33)
    end)

  register_primitive!(registry, "GIS:SET-COVERAGE-MAXIMUM-THRESHOLD", COMMAND,
    command_syntax(right=[NumberType]),
    (ctx, args) -> begin
      ctx.runtime.world.observer.globals["__GIS_COV_MAX_THRESH"] = Float64(args[1])
      nothing
    end)

  # ── Raster Operations ──────────────────────────────────────────────────
  register_primitive!(registry, "GIS:WIDTH-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      Float64(r.width)
    end)

  register_primitive!(registry, "GIS:HEIGHT-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      Float64(r.height)
    end)

  register_primitive!(registry, "GIS:RASTER-VALUE", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, NumberType], ret=NumberType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      col = Int(args[2]) + 1; row = Int(args[3]) + 1
      (1 <= row <= r.height && 1 <= col <= r.width) || throw(LogoRuntimeError("Raster index out of bounds"))
      Float64(r.data[row, col])
    end)

  register_primitive!(registry, "GIS:SET-RASTER-VALUE", COMMAND,
    command_syntax(right=[WildcardType, NumberType, NumberType, NumberType]),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      col = Int(args[2]) + 1; row = Int(args[3]) + 1
      (1 <= row <= r.height && 1 <= col <= r.width) || throw(LogoRuntimeError("Raster index out of bounds"))
      r.data[row, col] = Float64(args[4])
      nothing
    end)

  register_primitive!(registry, "GIS:MINIMUM-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      valid = filter(v -> v != r.nodata, r.data)
      isempty(valid) ? Float64(r.nodata) : Float64(minimum(valid))
    end)

  register_primitive!(registry, "GIS:MAXIMUM-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      valid = filter(v -> v != r.nodata, r.data)
      isempty(valid) ? Float64(r.nodata) : Float64(maximum(valid))
    end)

  register_primitive!(registry, "GIS:APPLY-RASTER", COMMAND,
    command_syntax(right=[WildcardType, SymbolType], arg_modes=[:eval, :symbol]),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      _apply_raster!(ctx, r, String(args[2]))
    end)

  register_primitive!(registry, "GIS:RASTER-SAMPLE", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType, NumberType | OptionalType], ret=NumberType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      local gx::Float64, gy::Float64
      if length(args) >= 3 && args[2] isa Number
        gx = Float64(args[2]); gy = Float64(args[3])
      else
        # args[2] is an agent (turtle or patch) — extract world coordinates and convert to GIS
        agent = args[2]
        local nx::Float64, ny::Float64
        if agent isa Turtle
          nx = agent.xcor; ny = agent.ycor
        elseif agent isa Patch
          nx = Float64(agent.pxcor); ny = Float64(agent.pycor)
        else
          throw(LogoRuntimeError("gis:raster-sample expected coordinates or an agent"))
        end
        transform = _get_transform(ctx)
        if transform !== nothing
          gx, gy = _netlogo_to_gis(transform, nx, ny)
        else
          gx = nx; gy = ny
        end
      end
      val = _sample_raster(r, gx, gy)
      val === nothing ? Float64(r.nodata) : Float64(val)
    end)

  register_primitive!(registry, "GIS:RASTER-WORLD-ENVELOPE", REPORTER,
    reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      Any[r.envelope[1], r.envelope[2], r.envelope[3], r.envelope[4]]
    end)

  register_primitive!(registry, "GIS:CREATE-RASTER", REPORTER,
    reporter_syntax(right=[NumberType, NumberType, ListType], ret=WildcardType),
    (ctx, args) -> begin
      w = Int(args[1]); h = Int(args[2])
      env = args[3]
      length(env) >= 4 || throw(LogoRuntimeError("Envelope needs 4 numbers"))
      data = fill(0.0, h, w)
      envelope = (Float64(env[1]), Float64(env[2]), Float64(env[3]), Float64(env[4]))
      cx = (envelope[2] - envelope[1]) / w
      cy = (envelope[4] - envelope[3]) / h
      GisRasterDataset(data, w, h, -9999.0, envelope, cx, cy, :bilinear, nothing)
    end)

  register_primitive!(registry, "GIS:RESAMPLE", REPORTER,
    reporter_syntax(right=[WildcardType, ListType], ret=WildcardType),
    (ctx, args) -> begin
      src = args[1]
      src isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      dims = args[2]
      new_w = Int(dims[1]); new_h = Int(dims[2])
      new_data = fill(src.nodata, new_h, new_w)
      cx = (src.envelope[2] - src.envelope[1]) / new_w
      cy = (src.envelope[4] - src.envelope[3]) / new_h
      for r in 1:new_h, c in 1:new_w
        gx = src.envelope[1] + (c - 0.5) * cx
        gy = src.envelope[4] - (r - 0.5) * cy
        val = _sample_raster(src, gx, gy)
        if val !== nothing
          new_data[r, c] = val
        end
      end
      GisRasterDataset(new_data, new_w, new_h, src.nodata, src.envelope, cx, cy, src.sampling_method, src.coordinate_system)
    end)

  register_primitive!(registry, "GIS:CONVOLVE", REPORTER,
    reporter_syntax(right=[WildcardType, NumberType, NumberType, ListType, NumberType | OptionalType, NumberType | OptionalType], ret=WildcardType),
    (ctx, args) -> begin
      src = args[1]
      src isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      kw = Int(args[2]); kh = Int(args[3])
      kernel_flat = args[4]
      h_scale = length(args) >= 5 ? Float64(args[5]) : 1.0
      v_scale = length(args) >= 6 ? Float64(args[6]) : 1.0
      length(kernel_flat) == kw * kh || throw(LogoRuntimeError("Kernel size mismatch"))
      kernel = reshape(Float64[Float64(v) for v in kernel_flat], kh, kw)
      new_data = fill(src.nodata, src.height, src.width)
      hw = kw ÷ 2; hh = kh ÷ 2
      for r in 1:src.height, c in 1:src.width
        src.data[r, c] == src.nodata && continue
        total = 0.0; weight = 0.0
        for kr in 1:kh, kc in 1:kw
          sr = r + kr - hh - 1; sc = c + kc - hw - 1
          if 1 <= sr <= src.height && 1 <= sc <= src.width && src.data[sr, sc] != src.nodata
            k = kernel[kr, kc]
            total += src.data[sr, sc] * k
            weight += k
          end
        end
        new_data[r, c] = total * h_scale * v_scale
      end
      GisRasterDataset(new_data, src.width, src.height, src.nodata, src.envelope,
        src.cellsize_x, src.cellsize_y, src.sampling_method, src.coordinate_system)
    end)

  register_primitive!(registry, "GIS:SAMPLING-METHOD-OF", REPORTER,
    reporter_syntax(right=[WildcardType], ret=StringType),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      string(r.sampling_method)
    end)

  register_primitive!(registry, "GIS:SET-SAMPLING-METHOD", COMMAND,
    command_syntax(right=[WildcardType, StringType]),
    (ctx, args) -> begin
      r = args[1]
      r isa GisRasterDataset || throw(LogoRuntimeError("Expected raster dataset"))
      method = lowercase(String(args[2]))
      r.sampling_method = method == "bilinear" ? :bilinear : :nearest
      nothing
    end)

  # ── Spatial Relationship Tests ─────────────────────────────────────────
  register_primitive!(registry, "GIS:INTERSECTS?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> _features_intersect(args[1], args[2]))

  register_primitive!(registry, "GIS:CONTAINS?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      outer = args[1]; inner = args[2]
      if outer isa GisVectorFeature && inner isa GisVertex
        return _feature_contains_point(outer, inner.x, inner.y)
      end
      _feature_contains(outer, inner)
    end)

  register_primitive!(registry, "GIS:CONTAINED-BY?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> begin
      inner = args[1]; outer = args[2]
      if outer isa GisVectorFeature && inner isa GisVertex
        return _feature_contains_point(outer, inner.x, inner.y)
      end
      _feature_contains(outer, inner)
    end)

  register_primitive!(registry, "GIS:HAVE-RELATIONSHIP?", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType, StringType], ret=BooleanType),
    (ctx, args) -> _feature_relate_pattern(args[1], args[2], String(args[3])))

  register_primitive!(registry, "GIS:RELATIONSHIP-OF", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType], ret=StringType),
    (ctx, args) -> _feature_relationship(args[1], args[2]))

  register_primitive!(registry, "GIS:INTERSECTING", REPORTER,
    reporter_syntax(right=[AgentsetType, WildcardType], ret=AgentsetType),
    (ctx, args) -> begin
      agents = args[1]
      geom_obj = args[2]
      t = _get_transform(ctx)
      t === nothing && throw(LogoRuntimeError("No GIS transformation set"))
      geom_env = _get_envelope(geom_obj)
      geos_geom = _to_libgeos(geom_obj)
      matching = Any[]
      for agent in live_agentset_members(agents)
        gx, gy = if agent isa Turtle
          _netlogo_to_gis(t, Float64(agent.xcor), Float64(agent.ycor))
        elseif agent isa Patch
          _netlogo_to_gis(t, Float64(agent.pxcor), Float64(agent.pycor))
        else
          continue
        end
        _envelope_contains_point(geom_env, gx, gy) || continue
        if geos_geom !== nothing
          pt = LibGEOS.readgeom("POINT($gx $gy)")
          LibGEOS.intersects(geos_geom, pt) || continue
        end
        push!(matching, agent)
      end
      matching
    end)

  # ── Drawing (stubs for headless mode) ──────────────────────────────────
  register_primitive!(registry, "GIS:SET-DRAWING-COLOR", COMMAND,
    command_syntax(right=[NumberType]),
    (ctx, args) -> begin
      ctx.runtime.world.observer.globals[_DRAWING_COLOR_KEY] = Float64(args[1])
      nothing
    end)

  register_primitive!(registry, "GIS:DRAWING-COLOR", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> begin
      get(ctx.runtime.world.observer.globals, _DRAWING_COLOR_KEY, 0.0)
    end)

  register_primitive!(registry, "GIS:DRAW", COMMAND,
    command_syntax(right=[WildcardType, NumberType]),
    (ctx, args) -> throw(LogoRuntimeError("gis:draw is not supported in headless mode")))

  register_primitive!(registry, "GIS:FILL", COMMAND,
    command_syntax(right=[WildcardType, NumberType]),
    (ctx, args) -> throw(LogoRuntimeError("gis:fill is not supported in headless mode")))

  register_primitive!(registry, "GIS:PAINT", COMMAND,
    command_syntax(right=[WildcardType, NumberType]),
    (ctx, args) -> throw(LogoRuntimeError("gis:paint is not supported in headless mode")))

  register_primitive!(registry, "GIS:IMPORT-WMS-DRAWING", COMMAND,
    command_syntax(right=[StringType, StringType, NumberType]),
    (ctx, args) -> throw(LogoRuntimeError("gis:import-wms-drawing is not supported in headless mode")))

  # ── Turtle/Patch Dataset Creation ──────────────────────────────────────
  register_primitive!(registry, "GIS:TURTLE-DATASET", REPORTER,
    reporter_syntax(right=[TurtlesetType], ret=WildcardType),
    (ctx, args) -> begin
      t = _get_transform(ctx)
      turtles = live_agentset_members(args[1])
      features = GisVectorFeature[]
      for turtle in turtles
        turtle.alive || continue
        if t !== nothing
          gx, gy = _netlogo_to_gis(t, Float64(turtle.xcor), Float64(turtle.ycor))
        else
          gx, gy = Float64(turtle.xcor), Float64(turtle.ycor)
        end
        geom = GisVertex(gx, gy)
        props = Dict{String, Any}("WHO" => Float64(turtle.id))
        feat = GisVectorFeature(geom, :point, props)
        feat._centroid = geom
        push!(features, feat)
      end
      env = if isempty(features)
        (0.0, 0.0, 0.0, 0.0)
      else
        (minimum(f._centroid !== nothing ? f._centroid.x : 0.0 for f in features),
         maximum(f._centroid !== nothing ? f._centroid.x : 0.0 for f in features),
         minimum(f._centroid !== nothing ? f._centroid.y : 0.0 for f in features),
         maximum(f._centroid !== nothing ? f._centroid.y : 0.0 for f in features))
      end
      GisVectorDataset(features, ["WHO"], :point, env, nothing)
    end)

  register_primitive!(registry, "GIS:PATCH-DATASET", REPORTER,
    reporter_syntax(right=[PatchsetType], ret=WildcardType),
    (ctx, args) -> begin
      patches = live_agentset_members(args[1])
      features = GisVectorFeature[]
      transform = _get_transform(ctx)
      for p in patches
        if transform !== nothing
          gx, gy = _netlogo_to_gis(transform, Float64(p.pxcor), Float64(p.pycor))
        else
          gx, gy = Float64(p.pxcor), Float64(p.pycor)
        end
        half_x = transform !== nothing ?
          abs((transform.gis_xmax - transform.gis_xmin) / (transform.nl_xmax - transform.nl_xmin)) * 0.5 :
          0.5
        half_y = transform !== nothing ?
          abs((transform.gis_ymax - transform.gis_ymin) / (transform.nl_ymax - transform.nl_ymin)) * 0.5 :
          0.5
        ring = [GisVertex(gx - half_x, gy - half_y), GisVertex(gx + half_x, gy - half_y),
                GisVertex(gx + half_x, gy + half_y), GisVertex(gx - half_x, gy + half_y),
                GisVertex(gx - half_x, gy - half_y)]
        props = Dict{String, Any}("PXCOR" => Float64(p.pxcor), "PYCOR" => Float64(p.pycor),
                                   "PCOLOR" => p.pcolor)
        push!(features, GisVectorFeature(ring, :polygon, props))
      end
      env = if isempty(features)
        (0.0, 0.0, 0.0, 0.0)
      else
        xs = [v.x for f in features for v in (f.geometry isa Vector ? f.geometry : [f.geometry])]
        ys = [v.y for f in features for v in (f.geometry isa Vector ? f.geometry : [f.geometry])]
        (minimum(xs), maximum(xs), minimum(ys), maximum(ys))
      end
      GisVectorDataset(features, ["PXCOR", "PYCOR", "PCOLOR"], :polygon, env, nothing)
    end)

  # ── Link Dataset Creation ────────────────────────────────────────────
  register_primitive!(registry, "GIS:LINK-DATASET", REPORTER,
    reporter_syntax(right=[LinksetType], ret=WildcardType),
    (ctx, args) -> begin
      t = _get_transform(ctx)
      links = live_agentset_members(args[1])
      features = GisVectorFeature[]
      world = ctx.runtime.world
      for link in links
        link isa Link || continue
        link.alive || continue
        t1 = get(world.turtles, link.end1, nothing)
        t2 = get(world.turtles, link.end2, nothing)
        (t1 === nothing || t2 === nothing) && continue
        (!t1.alive || !t2.alive) && continue
        if t !== nothing
          gx1, gy1 = _netlogo_to_gis(t, Float64(t1.xcor), Float64(t1.ycor))
          gx2, gy2 = _netlogo_to_gis(t, Float64(t2.xcor), Float64(t2.ycor))
        else
          gx1, gy1 = Float64(t1.xcor), Float64(t1.ycor)
          gx2, gy2 = Float64(t2.xcor), Float64(t2.ycor)
        end
        verts = [GisVertex(gx1, gy1), GisVertex(gx2, gy2)]
        props = Dict{String, Any}("END1" => Float64(link.end1), "END2" => Float64(link.end2))
        feat = GisVectorFeature(_ReProjectedGeometry(nothing, verts), :line, props)
        push!(features, feat)
      end
      env = if isempty(features)
        (0.0, 0.0, 0.0, 0.0)
      else
        _compute_dataset_envelope(features)
      end
      GisVectorDataset(features, ["END1", "END2"], :line, env, nothing)
    end)

  # ── Create Turtles from Points ──────────────────────────────────────
  register_primitive!(registry, "GIS:CREATE-TURTLES-FROM-POINTS", COMMAND,
    command_syntax(right=[WildcardType, StringType, CommandBlockType | OptionalType],
                   arg_modes=[:eval, :eval, :block]),
    (ctx, args) -> begin
      ds = args[1]
      ds isa GisVectorDataset || throw(LogoRuntimeError("gis:create-turtles-from-points expected a vector dataset"))
      ds.shape_type == :point || throw(LogoRuntimeError("gis:create-turtles-from-points expected a point dataset"))
      breed_name = canonical_name(String(args[2]))
      cmd_block = get(args, 3, nothing)
      t = _get_transform(ctx)
      t === nothing && throw(LogoRuntimeError("No GIS transformation set"))
      world = ctx.runtime.world
      new_turtles = Any[]
      for feat in ds.features
        centroid = _feature_centroid(feat)
        nx, ny = _gis_to_netlogo(t, centroid.x, centroid.y)
        turtle = create_turtle!(world; xcor=nx, ycor=ny)
        push!(new_turtles, turtle)
      end
      if cmd_block isa BlockNode
        run_block_for_agents!(ctx, new_turtles, cmd_block)
      end
      nothing
    end)

  # ── Lat/Lon Projection ─────────────────────────────────────────────
  register_primitive!(registry, "GIS:PROJECT-LAT-LON", REPORTER,
    reporter_syntax(right=[NumberType, NumberType], ret=ListType),
    (ctx, args) -> begin
      lat = Float64(args[1])
      lon = Float64(args[2])
      world_crs = _get_world_crs(ctx)
      if world_crs !== nothing && world_crs.crs !== nothing
        # Transform from WGS84 lat/lon to the world coordinate system
        wgs84 = Proj.CRS("EPSG:4326")
        trans = Proj.Transformation(wgs84, world_crs.crs; always_xy=true)
        x, y = trans(lon, lat)
        return Any[x, y]
      end
      # No world CRS set; return lat/lon as-is
      Any[lon, lat]
    end)

end # register_extension!

end # module gis
