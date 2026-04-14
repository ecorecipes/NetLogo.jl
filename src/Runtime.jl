struct NobodyValue end
const NOBODY = NobodyValue()

struct StopSignal <: Exception end

struct ReportSignal <: Exception
  value::Any
end

mutable struct RuntimeFileState
  path::String
  mode::Symbol
  content::Vector{Char}
  position::Int
  line::Int
  column::Int
  writer::Union{Nothing, IOStream}
end

RuntimeFileState(path::String) = RuntimeFileState(path, :none, Char[], 1, 1, 1, nothing)

mutable struct PlotPenState
  name::String
  temporary::Bool
  default_color::Any
  default_interval::Float64
  default_mode::Int
  default_hidden::Bool
  default_in_legend::Bool
  setup_code::String
  update_code::String
  x::Float64
  color::Any
  interval::Float64
  mode::Int
  is_down::Bool
  hidden::Bool
  in_legend::Bool
  points::Vector{Any}
end

mutable struct PlotPointState
  x::Float64
  y::Float64
  is_down::Bool
  color::Any
end

mutable struct PlotState
  name::String
  pens::Vector{PlotPenState}
  current_pen::Union{Nothing, PlotPenState}
  auto_plot_x::Bool
  auto_plot_y::Bool
  default_x_min::Float64
  default_x_max::Float64
  default_y_min::Float64
  default_y_max::Float64
  x_min::Float64
  x_max::Float64
  y_min::Float64
  y_max::Float64
  setup_code::String
  update_code::String
  legend_open::Bool
end

mutable struct PlotManagerState
  plots::Vector{PlotState}
  current_plot::Union{Nothing, PlotState}
end

const PLOT_PEN_LINE_MODE = 0
const PLOT_PEN_BAR_MODE = 1
const PLOT_PEN_POINT_MODE = 2

struct LiteralParseError <: Exception
  message::String
  line::Int
  column::Int
end

mutable struct RuntimeState
  model::CompiledModel
  world::World
  registry::PrimitiveRegistry
  error_messages::Vector{String}
  open_files::Dict{String, RuntimeFileState}
  current_file::Union{Nothing, String}
  perspective_subject::Any
  command_output::String
  output_area::String
  plot_manager::PlotManagerState
  plot_rng::MersenneTwister
  custom_turtle_shapes::Dict{String, Any}
  prepared_arg_buffers::Vector{Vector{Any}}
  prepared_arg_depth::Base.RefValue{Int}
  agent_iteration_buffers::Vector{Vector{AbstractAgent}}
  agent_iteration_depth::Base.RefValue{Int}
  scope_stack_buffers::Vector{Vector{Dict{String, Any}}}
  scope_stack_depth::Base.RefValue{Int}
end

struct WorldPersistenceSnapshot
  world::World
  perspective_subject::Any
  output_area::String
  plot_manager::Union{Nothing, PlotManagerState}
  plot_rng::Union{Nothing, MersenneTwister}
  command_output::Union{Nothing, String}
end

# Backward-compatible constructor for old snapshots without new fields
WorldPersistenceSnapshot(world::World, perspective_subject::Any, output_area::String) =
  WorldPersistenceSnapshot(world, perspective_subject, output_area, nothing, nothing, nothing)

mutable struct Context
  runtime::RuntimeState
  agent::AbstractAgent
  locals::Vector{Dict{String, Any}}
  caller::Union{Nothing, AbstractAgent}
  in_ask::Bool
  string_scope_depth::Int
  every_state::Dict{Tuple{Int, Any}, UInt64}
end

Context(
  runtime::RuntimeState,
  agent::AbstractAgent,
  locals::Vector{Dict{String, Any}},
  caller::Union{Nothing, AbstractAgent},
  in_ask::Bool,
  string_scope_depth::Int) =
  Context(runtime, agent, locals, caller, in_ask, string_scope_depth, Dict{Tuple{Int, Any}, UInt64}())

# Dict pool for scope frames — avoids repeated allocation/GC of empty Dicts
const _SCOPE_DICT_POOL = Dict{String, Any}[]
const _EVERY_STATE_POOL = Dict{Tuple{Int, Any}, UInt64}[]
const EMPTY_SCOPE_STACK = Dict{String, Any}[]
const EMPTY_EVERY_STATE = Dict{Tuple{Int, Any}, UInt64}()

function _get_scope_dict()
  if !isempty(_SCOPE_DICT_POOL)
    return pop!(_SCOPE_DICT_POOL)
  end
  return Dict{String, Any}()
end

function _return_scope_dict!(d::Dict{String, Any})
  empty!(d)
  if length(_SCOPE_DICT_POOL) < 64
    push!(_SCOPE_DICT_POOL, d)
  end
  nothing
end

function _get_every_state_dict()
  if !isempty(_EVERY_STATE_POOL)
    return pop!(_EVERY_STATE_POOL)
  end
  return Dict{Tuple{Int, Any}, UInt64}()
end

function _return_every_state_dict!(d::Dict{Tuple{Int, Any}, UInt64})
  empty!(d)
  if length(_EVERY_STATE_POOL) < 64
    push!(_EVERY_STATE_POOL, d)
  end
  nothing
end

@inline function maybe_acquire_every_state!(
  context::Context,
  uses_every::Bool)
  if uses_every
    child_every_state = _get_every_state_dict()
    context.every_state = child_every_state
    return child_every_state
  end
  return nothing
end

@inline function restore_every_state!(
  context::Context,
  saved_every_state::Dict{Tuple{Int, Any}, UInt64},
  child_every_state::Union{Nothing, Dict{Tuple{Int, Any}, UInt64}})
  context.every_state = saved_every_state
  child_every_state === nothing || _return_every_state_dict!(child_every_state)
  nothing
end

@inline function copy_scope_stack(scopes::Vector{Dict{String, Any}})
  copied = Vector{Dict{String, Any}}(undef, length(scopes))
  !isempty(scopes) && copyto!(copied, 1, scopes, 1, length(scopes))
  copied
end

@inline function extend_scope_stack(scopes::Vector{Dict{String, Any}}, frame::Dict{String, Any})
  count = length(scopes)
  extended = Vector{Dict{String, Any}}(undef, count + 1)
  count > 0 && copyto!(extended, 1, scopes, 1, count)
  extended[count + 1] = frame
  extended
end

abstract type AbstractReporterTaskValue end
abstract type AbstractCommandTaskValue end

struct ReporterTaskValue <: AbstractReporterTaskValue
  block::ReporterBlockNode
  locals::Vector{Dict{String, Any}}
  model_source::String
  source_span::SourceSpan
  string_scope_depth::Int
end

struct PrimitiveReporterTaskValue <: AbstractReporterTaskValue
  spec::PrimitiveSpec
end

struct ProcedureReporterTaskValue <: AbstractReporterTaskValue
  procedure::ProcedureSpec
end

struct CommandTaskValue <: AbstractCommandTaskValue
  task::CommandTaskNode
  locals::Vector{Dict{String, Any}}
  model_source::String
  source_span::SourceSpan
  string_scope_depth::Int
end

struct PrimitiveCommandTaskValue <: AbstractCommandTaskValue
  spec::PrimitiveSpec
end

struct ProcedureCommandTaskValue <: AbstractCommandTaskValue
  procedure::ProcedureSpec
end

copy_plot_color(value) = value isa AbstractVector ? deepcopy(value) : value

function default_plot_pen(name::AbstractString, temporary::Bool=false)
  default_color = 0.0
  PlotPenState(
    String(name),
    temporary,
    default_color,
    1.0,
    PLOT_PEN_LINE_MODE,
    false,
    true,
    "",
    "",
    0.0,
    copy_plot_color(default_color),
    1.0,
    PLOT_PEN_LINE_MODE,
    true,
    false,
    true,
    Any[])
end

function create_plot_pen!(plot::PlotState, name::AbstractString; temporary::Bool=false)
  pen = default_plot_pen(name, temporary)
  push!(plot.pens, pen)
  plot.current_pen === nothing && (plot.current_pen = pen)
  pen
end

function default_plot(name::AbstractString)
  plot = PlotState(String(name), PlotPenState[], nothing, true, true, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0, 0.0, 10.0, "", "", false)
  create_plot_pen!(plot, "pen1")
  create_plot_pen!(plot, "pen2")
  plot.current_pen = first(plot.pens)
  plot
end

default_plot_manager() = PlotManagerState(PlotState[default_plot("plot1"), default_plot("plot2")], nothing)

function plot_pen_from_spec(spec::PlotPenSpec)
  PlotPenState(
    spec.name,
    false,
    spec.default_color,
    spec.default_interval,
    spec.default_mode,
    false,
    spec.in_legend,
    spec.setup_code,
    spec.update_code,
    0.0,
    copy_plot_color(spec.default_color),
    spec.default_interval,
    spec.default_mode,
    true,
    false,
    spec.in_legend,
    Any[])
end

function plot_from_spec(spec::PlotSpec)
  pens = [plot_pen_from_spec(pen_spec) for pen_spec in spec.pens]
  PlotState(
    spec.name,
    pens,
    isempty(pens) ? nothing : first(pens),
    spec.auto_plot_x,
    spec.auto_plot_y,
    spec.default_x_min,
    spec.default_x_max,
    spec.default_y_min,
    spec.default_y_max,
    spec.default_x_min,
    spec.default_x_max,
    spec.default_y_min,
    spec.default_y_max,
    spec.setup_code,
    spec.update_code,
    spec.legend_open)
end

function plot_manager_from_model(model::ModelSpec)
  model.has_interface_section || return default_plot_manager()
  PlotManagerState([plot_from_spec(spec) for spec in model.plots], nothing)
end

function create_runtime(
  model::ModelSpec,
  registry::PrimitiveRegistry;
  min_pxcor::Union{Nothing, Integer}=nothing,
  max_pxcor::Union{Nothing, Integer}=nothing,
  min_pycor::Union{Nothing, Integer}=nothing,
  max_pycor::Union{Nothing, Integer}=nothing,
  topology::Union{Nothing, TopologyMode}=nothing,
  patch_size::Union{Nothing, Real}=nothing,
  seed::Integer=1)
  world = World(model; min_pxcor=min_pxcor, max_pxcor=max_pxcor, min_pycor=min_pycor, max_pycor=max_pycor, topology=topology, patch_size=patch_size, seed=seed)
  rt = RuntimeState(
    model,
    world,
    registry,
    String[],
    Dict{String, RuntimeFileState}(),
    nothing,
    NOBODY,
    "",
    "",
    plot_manager_from_model(model),
    copy(world.rng),
    Dict{String, Any}(),
    Vector{Vector{Any}}(),
    Ref(0),
    Vector{Vector{AbstractAgent}}(),
    Ref(0),
    Vector{Vector{Dict{String, Any}}}(),
    Ref(0))
  if !isempty(model.turtle_shapes_text)
    load_turtle_shapes!(rt, model.turtle_shapes_text)
  end
  rt
end

function load_turtle_shapes!(runtime::RuntimeState, text::AbstractString)
  shapes = parse_turtle_shapes_text(text)
  merge!(runtime.custom_turtle_shapes, shapes)
  runtime
end

function load_turtle_shapes_file!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  isfile(resolved) || throw(LogoRuntimeError("The file $(resolved) cannot be found"))
  load_turtle_shapes!(runtime, read(resolved, String))
end

const COLOR_CONSTANT_VALUES = Dict{String, Float64}(
  "BLACK" => 0.0,
  "GRAY" => 5.0,
  "GREY" => 5.0,
  "WHITE" => 9.9,
  "RED" => 15.0,
  "ORANGE" => 25.0,
  "BROWN" => 35.0,
  "YELLOW" => 45.0,
  "GREEN" => 55.0,
  "LIME" => 65.0,
  "TURQUOISE" => 75.0,
  "CYAN" => 85.0,
  "SKY" => 95.0,
  "BLUE" => 105.0,
  "VIOLET" => 115.0,
  "MAGENTA" => 125.0,
  "PINK" => 135.0)
const BASE_COLOR_VALUES = Float64[5.0 + 10.0 * index for index in 0:13]
const DEFAULT_SHAPE_NAMES = [
  "default", "airplane", "arrow", "box", "bug", "butterfly", "car", "circle", "circle 2",
  "cow", "cylinder", "dot", "face happy", "face neutral", "face sad", "fish", "flag", "flower",
  "house", "leaf", "line", "line half", "pentagon", "person", "plant", "sheep", "square",
  "square 2", "star", "target", "tree", "triangle", "triangle 2", "truck", "turtle", "wheel",
  "wolf", "x"
]
const DEFAULT_LINK_SHAPE_NAMES = ["default"]
const RGBAColor = NTuple{4, Float64}

abstract type TurtleShapeElement end

struct TurtlePolygonElement <: TurtleShapeElement
  points::Vector{NTuple{2, Float64}}
  color::Union{Nothing, RGBAColor}
end

struct TurtleCircleElement <: TurtleShapeElement
  center::NTuple{2, Float64}
  radius::Float64
  color::Union{Nothing, RGBAColor}
end

struct TurtleSegmentElement <: TurtleShapeElement
  start::NTuple{2, Float64}
  stop::NTuple{2, Float64}
  width::Float64
  color::Union{Nothing, RGBAColor}
end

struct TurtleShapeSpec
  rotatable::Bool
  elements::Tuple
end

shape_polygon(points; color=nothing) =
  TurtlePolygonElement([(Float64(x), Float64(y)) for (x, y) in points], color)
shape_circle(center, radius; color=nothing) =
  TurtleCircleElement((Float64(center[1]), Float64(center[2])), Float64(radius), color)
shape_segment(start, stop, width; color=nothing) =
  TurtleSegmentElement((Float64(start[1]), Float64(start[2])), (Float64(stop[1]), Float64(stop[2])), Float64(width), color)
shape_point300(point) = ((Float64(point[1]) - 150.0) / 300.0, (150.0 - Float64(point[2])) / 300.0)
shape_polygon300(points; color=nothing) = shape_polygon((shape_point300(point) for point in points); color=color)
shape_circle300(x, y, diameter; color=nothing) =
  shape_circle(
    shape_point300((Float64(x) + Float64(diameter) / 2.0, Float64(y) + Float64(diameter) / 2.0)),
    Float64(diameter) / 600.0;
    color=color)
shape_segment300(start, stop, width=15; color=nothing) =
  shape_segment(shape_point300(start), shape_point300(stop), Float64(width) / 300.0; color=color)
shape_rectangle300(left, top, right, bottom; color=nothing) =
  shape_polygon300([(left, top), (right, top), (right, bottom), (left, bottom)]; color=color)

function java_color_to_rgba(color_int::Integer)
  unsigned = reinterpret(UInt32, Int32(color_int))
  r = Float64((unsigned >> 16) & 0xFF)
  g = Float64((unsigned >> 8) & 0xFF)
  b = Float64(unsigned & 0xFF)
  a = Float64((unsigned >> 24) & 0xFF)
  (r, g, b, a)
end

function parse_shape_element_line(line::AbstractString)
  parts = split(strip(line))
  isempty(parts) && return nothing
  kind = parts[1]
  if kind == "Polygon"
    color_int = parse(Int, parts[2])
    marked = parts[4] == "true"
    color = marked ? nothing : java_color_to_rgba(color_int)
    coords = [parse(Int, p) for p in parts[5:end]]
    length(coords) >= 4 || return nothing
    points = [(coords[i], coords[i+1]) for i in 1:2:length(coords)]
    return shape_polygon300(points; color=color)
  elseif kind == "Circle"
    color_int = parse(Int, parts[2])
    marked = parts[4] == "true"
    color = marked ? nothing : java_color_to_rgba(color_int)
    x = parse(Int, parts[5])
    y = parse(Int, parts[6])
    diameter = parse(Int, parts[7])
    return shape_circle300(x, y, diameter; color=color)
  elseif kind == "Rectangle"
    color_int = parse(Int, parts[2])
    marked = parts[4] == "true"
    color = marked ? nothing : java_color_to_rgba(color_int)
    left = parse(Int, parts[5])
    top = parse(Int, parts[6])
    right = parse(Int, parts[7])
    bottom = parse(Int, parts[8])
    if left == right || top == bottom
      # Degenerate rectangle → render as segment
      return shape_segment300((left, top), (right, bottom), 10; color=color)
    end
    return shape_rectangle300(left, top, right, bottom; color=color)
  elseif kind == "Line"
    # Line has 3 header fields: kind, color, marked (no "filled")
    color_int = parse(Int, parts[2])
    marked = parts[3] == "true"
    color = marked ? nothing : java_color_to_rgba(color_int)
    x1 = parse(Int, parts[4])
    y1 = parse(Int, parts[5])
    x2 = parse(Int, parts[6])
    y2 = parse(Int, parts[7])
    return shape_segment300((x1, y1), (x2, y2), 15; color=color)
  end
  nothing
end

function parse_turtle_shapes_text(text::AbstractString)
  shapes = Dict{String, Any}()
  lines = split(text, '\n')
  i = 1
  while i <= length(lines)
    # Skip blank lines
    while i <= length(lines) && isempty(strip(lines[i]))
      i += 1
    end
    i > length(lines) && break
    # Shape name
    name = lowercase(strip(String(lines[i])))
    i += 1
    i > length(lines) && break
    # Rotatable flag
    rotatable = strip(lines[i]) == "true"
    i += 1
    i > length(lines) && break
    # Editing education (rotation angle) - skip
    i += 1
    # Parse elements until blank line or EOF
    elements = TurtleShapeElement[]
    while i <= length(lines) && !isempty(strip(lines[i]))
      elem = parse_shape_element_line(lines[i])
      elem !== nothing && push!(elements, elem)
      i += 1
    end
    if !isempty(elements)
      shapes[name] = TurtleShapeSpec(rotatable, Tuple(elements))
    end
  end
  shapes
end

const SHAPE_BLACK = (0.0, 0.0, 0.0, 255.0)
const SHAPE_BROWN = (157.0, 110.0, 72.0, 255.0)
const SHAPE_GREEN = (89.0, 176.0, 60.0, 255.0)
const SHAPE_WHITE = (255.0, 255.0, 255.0, 255.0)
const DEFAULT_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon([(0.0, 0.58), (0.46, -0.08), (0.16, -0.08), (0.16, -0.55), (-0.16, -0.55), (-0.16, -0.08), (-0.46, -0.08)]),
))
const TRIANGLE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon([(0.0, 0.58), (0.52, -0.45), (-0.52, -0.45)]),
))
const TRIANGLE2_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon([(0.0, 0.58), (0.52, -0.45), (-0.52, -0.45)]),
  shape_polygon([(0.0, 0.18), (0.22, -0.28), (-0.22, -0.28)]; color=SHAPE_BLACK),
))
const SQUARE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon([(-0.5, 0.5), (0.5, 0.5), (0.5, -0.5), (-0.5, -0.5)]),
))
const SQUARE2_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon([(-0.5, 0.5), (0.5, 0.5), (0.5, -0.5), (-0.5, -0.5)]),
  shape_polygon([(-0.2, 0.2), (0.2, 0.2), (0.2, -0.2), (-0.2, -0.2)]; color=SHAPE_BLACK),
))
const CIRCLE2_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle((0.0, 0.0), 0.5),
  shape_circle((0.0, 0.0), 0.18; color=SHAPE_BLACK),
))
const CIRCLE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle((0.0, 0.0), 0.5),
))
const LINE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_segment((0.0, -0.5), (0.0, 0.5), 0.1),
))
const LINE_HALF_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_segment((0.0, 0.0), (0.0, 0.5), 0.1),
))
const X_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_segment((-0.45, -0.45), (0.45, 0.45), 0.1),
  shape_segment((-0.45, 0.45), (0.45, -0.45), 0.1),
))
const TARGET_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle((0.0, 0.0), 0.5),
  shape_circle((0.0, 0.0), 0.35; color=SHAPE_BLACK),
  shape_circle((0.0, 0.0), 0.2; color=SHAPE_WHITE),
  shape_circle((0.0, 0.0), 0.08; color=SHAPE_BLACK),
))
const BUG_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_circle((0.0, 0.24), 0.16),
  shape_circle((0.0, 0.0), 0.2),
  shape_circle((0.0, -0.26), 0.16),
  shape_segment((-0.1, 0.3), (-0.3, 0.48), 0.05; color=SHAPE_BLACK),
  shape_segment((0.1, 0.3), (0.3, 0.48), 0.05; color=SHAPE_BLACK),
  shape_segment((-0.15, 0.1), (-0.42, 0.22), 0.05; color=SHAPE_BLACK),
  shape_segment((0.15, 0.1), (0.42, 0.22), 0.05; color=SHAPE_BLACK),
  shape_segment((-0.16, -0.04), (-0.44, -0.04), 0.05; color=SHAPE_BLACK),
  shape_segment((0.16, -0.04), (0.44, -0.04), 0.05; color=SHAPE_BLACK),
  shape_segment((-0.15, -0.18), (-0.4, -0.3), 0.05; color=SHAPE_BLACK),
  shape_segment((0.15, -0.18), (0.4, -0.3), 0.05; color=SHAPE_BLACK),
))
const CAR_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon([(-0.5, -0.15), (-0.38, 0.14), (0.12, 0.14), (0.34, 0.02), (0.48, -0.15), (0.48, -0.36), (-0.5, -0.36)]),
  shape_polygon([(-0.18, 0.14), (-0.02, 0.34), (0.22, 0.34), (0.34, 0.14)]),
  shape_polygon([(-0.08, 0.28), (0.18, 0.28), (0.25, 0.16), (-0.02, 0.16)]; color=SHAPE_WHITE),
  shape_circle((-0.26, -0.36), 0.12; color=SHAPE_BLACK),
  shape_circle((0.28, -0.36), 0.12; color=SHAPE_BLACK),
))
const AIRPLANE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon300([(150, 0), (135, 15), (120, 60), (120, 105), (15, 165), (15, 195), (120, 180), (135, 240), (105, 270), (120, 285), (150, 270), (180, 285), (210, 270), (165, 240), (180, 180), (285, 195), (285, 165), (180, 105), (180, 60), (165, 15)]),
))
const BUTTERFLY_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon300([(150, 165), (209, 199), (225, 225), (225, 255), (195, 270), (165, 255), (150, 240)]),
  shape_polygon300([(150, 165), (89, 198), (75, 225), (75, 255), (105, 270), (135, 255), (150, 240)]),
  shape_polygon300([(139, 148), (100, 105), (55, 90), (25, 90), (10, 105), (10, 135), (25, 180), (40, 195), (85, 194), (139, 163)]),
  shape_polygon300([(162, 150), (200, 105), (245, 90), (275, 90), (290, 105), (290, 135), (275, 180), (260, 195), (215, 195), (162, 165)]),
  shape_polygon300([(150, 255), (135, 225), (120, 150), (135, 120), (150, 105), (165, 120), (180, 150), (165, 225)]; color=SHAPE_BLACK),
  shape_circle300(135, 90, 30; color=SHAPE_BLACK),
  shape_segment300((150, 105), (195, 60), 10; color=SHAPE_BLACK),
  shape_segment300((150, 105), (105, 60), 10; color=SHAPE_BLACK),
))
const COW_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(200, 193), (197, 249), (179, 249), (177, 196), (166, 187), (140, 189), (93, 191), (78, 179), (72, 211), (49, 209), (48, 181), (37, 149), (25, 120), (25, 89), (45, 72), (103, 84), (179, 75), (198, 76), (252, 64), (272, 81), (293, 103), (285, 121), (255, 121), (242, 118), (224, 167)]),
  shape_polygon300([(73, 210), (86, 251), (62, 249), (48, 208)]),
  shape_polygon300([(25, 114), (16, 195), (9, 204), (23, 213), (25, 200), (39, 123)]),
))
const FACEHAPPY_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(8, 8, 285),
  shape_circle300(60, 75, 60; color=SHAPE_BLACK),
  shape_circle300(180, 75, 60; color=SHAPE_BLACK),
  shape_polygon300([(150, 255), (90, 239), (62, 213), (47, 191), (67, 179), (90, 203), (109, 218), (150, 225), (192, 218), (210, 203), (227, 181), (251, 194), (236, 217), (212, 240)]; color=SHAPE_BLACK),
))
const FACENEUTRAL_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(8, 7, 285),
  shape_circle300(60, 75, 60; color=SHAPE_BLACK),
  shape_circle300(180, 75, 60; color=SHAPE_BLACK),
  shape_rectangle300(60, 195, 240, 225; color=SHAPE_BLACK),
))
const FACESAD_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(8, 8, 285),
  shape_circle300(60, 75, 60; color=SHAPE_BLACK),
  shape_circle300(180, 75, 60; color=SHAPE_BLACK),
  shape_polygon300([(150, 168), (90, 184), (62, 210), (47, 232), (67, 244), (90, 220), (109, 205), (150, 198), (192, 205), (210, 220), (227, 242), (251, 229), (236, 206), (212, 183)]; color=SHAPE_BLACK),
))
const FISH_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(44, 131), (21, 87), (15, 86), (0, 120), (15, 150), (0, 180), (13, 214), (20, 212), (45, 166)]; color=SHAPE_WHITE),
  shape_polygon300([(135, 195), (119, 235), (95, 218), (76, 210), (46, 204), (60, 165)]; color=SHAPE_WHITE),
  shape_polygon300([(75, 45), (83, 77), (71, 103), (86, 114), (166, 78), (135, 60)]; color=SHAPE_WHITE),
  shape_polygon300([(30, 136), (151, 77), (226, 81), (280, 119), (292, 146), (292, 160), (287, 170), (270, 195), (195, 210), (151, 212), (30, 166)]),
  shape_circle300(215, 106, 30; color=SHAPE_BLACK),
))
const FLOWER_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(135, 120), (165, 165), (180, 210), (180, 240), (150, 300), (165, 300), (195, 240), (195, 195), (165, 135)]; color=SHAPE_GREEN),
  shape_circle300(85, 132, 38),
  shape_circle300(130, 147, 38),
  shape_circle300(192, 85, 38),
  shape_circle300(85, 40, 38),
  shape_circle300(177, 40, 38),
  shape_circle300(177, 132, 38),
  shape_circle300(70, 85, 38),
  shape_circle300(130, 25, 38),
  shape_circle300(96, 51, 108),
  shape_circle300(113, 68, 74; color=SHAPE_BLACK),
  shape_polygon300([(189, 233), (219, 188), (249, 173), (279, 188), (234, 218)]; color=SHAPE_GREEN),
  shape_polygon300([(180, 255), (150, 210), (105, 210), (75, 240), (135, 240)]; color=SHAPE_GREEN),
))
const LEAF_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(150, 210), (135, 195), (120, 210), (60, 210), (30, 195), (60, 180), (60, 165), (15, 135), (30, 120), (15, 105), (40, 104), (45, 90), (60, 90), (90, 105), (105, 120), (120, 120), (105, 60), (120, 60), (135, 30), (150, 15), (165, 30), (180, 60), (195, 60), (180, 120), (195, 120), (210, 105), (240, 90), (255, 90), (263, 104), (285, 105), (270, 120), (285, 135), (240, 165), (240, 180), (270, 195), (240, 210), (180, 210), (165, 195)]),
  shape_polygon300([(135, 195), (135, 240), (120, 255), (105, 255), (105, 285), (135, 285), (165, 240), (165, 195)]),
))
const SHEEP_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(203, 65, 88; color=SHAPE_WHITE),
  shape_circle300(70, 65, 162; color=SHAPE_WHITE),
  shape_circle300(150, 105, 120; color=SHAPE_WHITE),
  shape_polygon300([(218, 120), (240, 165), (255, 165), (278, 120)]),
  shape_circle300(214, 72, 67),
  shape_rectangle300(164, 223, 179, 298; color=SHAPE_WHITE),
  shape_polygon300([(45, 285), (30, 285), (30, 240), (15, 195), (45, 210)]; color=SHAPE_WHITE),
  shape_circle300(3, 83, 150; color=SHAPE_WHITE),
  shape_rectangle300(65, 221, 80, 296; color=SHAPE_WHITE),
  shape_polygon300([(195, 285), (210, 285), (210, 240), (240, 210), (195, 210)]; color=SHAPE_WHITE),
  shape_polygon300([(276, 85), (285, 105), (302, 99), (294, 83)]),
  shape_polygon300([(219, 85), (210, 105), (193, 99), (201, 83)]),
))
const TRUCK_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_rectangle300(4, 45, 195, 187),
  shape_polygon300([(296, 193), (296, 150), (259, 134), (244, 104), (208, 104), (207, 194)]),
  shape_segment300((195, 60), (195, 105), 10; color=SHAPE_WHITE),
  shape_polygon300([(238, 112), (252, 141), (219, 141), (218, 112)]; color=SHAPE_BLACK),
  shape_circle300(234, 174, 42; color=SHAPE_BLACK),
  shape_rectangle300(181, 185, 214, 194),
  shape_circle300(144, 174, 42; color=SHAPE_BLACK),
  shape_circle300(24, 174, 42; color=SHAPE_BLACK),
  shape_circle300(24, 174, 42),
  shape_circle300(144, 174, 42),
  shape_circle300(234, 174, 42),
))
const WOLF_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(253, 133), (245, 131), (245, 133)]; color=SHAPE_BLACK),
  shape_polygon300([(2, 194), (13, 197), (30, 191), (38, 193), (38, 205), (20, 226), (20, 257), (27, 265), (38, 266), (40, 260), (31, 253), (31, 230), (60, 206), (68, 198), (75, 209), (66, 228), (65, 243), (82, 261), (84, 268), (100, 267), (103, 261), (77, 239), (79, 231), (100, 207), (98, 196), (119, 201), (143, 202), (160, 195), (166, 210), (172, 213), (173, 238), (167, 251), (160, 248), (154, 265), (169, 264), (178, 247), (186, 240), (198, 260), (200, 271), (217, 271), (219, 262), (207, 258), (195, 230), (192, 198), (210, 184), (227, 164), (242, 144), (259, 145), (284, 151), (277, 141), (293, 140), (299, 134), (297, 127), (273, 119), (270, 105)]),
  shape_polygon300([(-1, 195), (14, 180), (36, 166), (40, 153), (53, 140), (82, 131), (134, 133), (159, 126), (188, 115), (227, 108), (236, 102), (238, 98), (268, 86), (269, 92), (281, 87), (269, 103), (269, 113)]),
))
const FLAG_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_rectangle300(60, 15, 75, 300),
  shape_polygon300([(90, 150), (270, 90), (90, 30)]),
  shape_segment300((75, 135), (90, 135), 12),
  shape_segment300((75, 45), (90, 45), 12),
))
const HOUSE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_rectangle300(45, 120, 255, 285),
  shape_rectangle300(120, 210, 180, 285; color=SHAPE_BLACK),
  shape_polygon300([(15, 120), (150, 15), (285, 120)]),
  shape_segment300((30, 120), (270, 120), 10; color=SHAPE_BLACK),
))
const PENTAGON_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(150, 15), (15, 120), (60, 285), (240, 285), (285, 120)]),
))
const PERSON_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(110, 5, 80),
  shape_polygon300([(105, 90), (120, 195), (90, 285), (105, 300), (135, 300), (150, 225), (165, 300), (195, 300), (210, 285), (180, 195), (195, 90)]),
  shape_rectangle300(127, 79, 172, 94),
  shape_polygon300([(195, 90), (240, 150), (225, 180), (165, 105)]),
  shape_polygon300([(105, 90), (60, 150), (75, 180), (135, 105)]),
))
const PLANT_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_rectangle300(135, 90, 165, 300),
  shape_polygon300([(135, 255), (90, 210), (45, 195), (75, 255), (135, 285)]),
  shape_polygon300([(165, 255), (210, 210), (255, 195), (225, 255), (165, 285)]),
  shape_polygon300([(135, 180), (90, 135), (45, 120), (75, 180), (135, 210)]),
  shape_polygon300([(165, 180), (165, 210), (225, 180), (255, 120), (210, 135)]),
  shape_polygon300([(135, 105), (90, 60), (45, 45), (75, 105), (135, 135)]),
  shape_polygon300([(165, 105), (165, 135), (225, 105), (255, 45), (210, 60)]),
  shape_polygon300([(135, 90), (120, 45), (150, 15), (180, 45), (165, 90)]),
))
const STAR_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_polygon300([(151, 1), (185, 108), (298, 108), (207, 175), (242, 282), (151, 216), (59, 282), (94, 175), (3, 108), (116, 108)]),
))
const TREE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(118, 3, 94),
  shape_circle300(65, 21, 108),
  shape_circle300(116, 41, 127),
  shape_circle300(45, 90, 120),
  shape_circle300(104, 74, 152),
  shape_rectangle300(120, 195, 180, 300; color=SHAPE_BROWN),
))
const TURTLE_TURTLE_RENDER_SHAPE = TurtleShapeSpec(true, (
  shape_polygon300([(215, 204), (240, 233), (246, 254), (228, 266), (215, 252), (193, 210)]),
  shape_polygon300([(195, 90), (225, 75), (245, 75), (260, 89), (269, 108), (261, 124), (240, 105), (225, 105), (210, 105)]),
  shape_polygon300([(105, 90), (75, 75), (55, 75), (40, 89), (31, 108), (39, 124), (60, 105), (75, 105), (90, 105)]),
  shape_polygon300([(132, 85), (134, 64), (107, 51), (108, 17), (150, 2), (192, 18), (192, 52), (169, 65), (172, 87)]),
  shape_polygon300([(85, 204), (60, 233), (54, 254), (72, 266), (85, 252), (107, 210)]),
  shape_polygon300([(119, 75), (179, 75), (209, 101), (224, 135), (220, 225), (175, 261), (128, 261), (81, 224), (74, 135), (88, 99)]),
))
const WHEEL_TURTLE_RENDER_SHAPE = TurtleShapeSpec(false, (
  shape_circle300(3, 3, 294),
  shape_circle300(30, 30, 240; color=SHAPE_BLACK),
  shape_segment300((150, 285), (150, 15), 10),
  shape_segment300((15, 150), (285, 150), 10),
  shape_circle300(120, 120, 60),
  shape_segment300((216, 40), (79, 269), 10),
  shape_segment300((40, 84), (269, 221), 10),
  shape_segment300((40, 216), (269, 79), 10),
  shape_segment300((84, 40), (221, 269), 10),
))
label_glyph(row1, row2, row3, row4, row5) =
  (String(row1), String(row2), String(row3), String(row4), String(row5))
const LABEL_GLYPH_WIDTH = 3
const LABEL_GLYPH_HEIGHT = 5
const LABEL_GLYPH_SPACING = 1
const SPACE_LABEL_GLYPH = label_glyph("...", "...", "...", "...", "...")
const QUESTION_LABEL_GLYPH = label_glyph("##.", "..#", ".#.", "...", ".#.")
const LABEL_FONT_GLYPHS = Dict{Char, NTuple{5, String}}(
  ' ' => SPACE_LABEL_GLYPH,
  '!' => label_glyph(".#.", ".#.", ".#.", "...", ".#."),
  '"' => label_glyph("#.#", "#.#", "...", "...", "..."),
  '\'' => label_glyph(".#.", ".#.", "...", "...", "..."),
  '(' => label_glyph("..#", ".#.", ".#.", ".#.", "..#"),
  ')' => label_glyph("#..", ".#.", ".#.", ".#.", "#.."),
  '+' => label_glyph(".#.", ".#.", "###", ".#.", ".#."),
  ',' => label_glyph("...", "...", "...", ".#.", "#.."),
  '-' => label_glyph("...", "...", "###", "...", "..."),
  '.' => label_glyph("...", "...", "...", "...", ".#."),
  '/' => label_glyph("..#", "..#", ".#.", "#..", "#.."),
  '0' => label_glyph(".#.", "#.#", "#.#", "#.#", ".#."),
  '1' => label_glyph(".#.", "##.", ".#.", ".#.", "###"),
  '2' => label_glyph("##.", "..#", ".#.", "#..", "###"),
  '3' => label_glyph("##.", "..#", ".#.", "..#", "##."),
  '4' => label_glyph("#.#", "#.#", "###", "..#", "..#"),
  '5' => label_glyph("###", "#..", "##.", "..#", "##."),
  '6' => label_glyph(".##", "#..", "##.", "#.#", ".#."),
  '7' => label_glyph("###", "..#", ".#.", ".#.", ".#."),
  '8' => label_glyph(".#.", "#.#", ".#.", "#.#", ".#."),
  '9' => label_glyph(".#.", "#.#", ".##", "..#", "##."),
  ':' => label_glyph("...", ".#.", "...", ".#.", "..."),
  ';' => label_glyph("...", ".#.", "...", ".#.", "#.."),
  '<' => label_glyph("..#", ".#.", "#..", ".#.", "..#"),
  '=' => label_glyph("...", "###", "...", "###", "..."),
  '>' => label_glyph("#..", ".#.", "..#", ".#.", "#.."),
  '?' => QUESTION_LABEL_GLYPH,
  '[' => label_glyph("##.", "#..", "#..", "#..", "##."),
  '\\' => label_glyph("#..", "#..", ".#.", "..#", "..#"),
  ']' => label_glyph(".##", "..#", "..#", "..#", ".##"),
  '_' => label_glyph("...", "...", "...", "...", "###"),
  'A' => label_glyph(".#.", "#.#", "###", "#.#", "#.#"),
  'B' => label_glyph("##.", "#.#", "##.", "#.#", "##."),
  'C' => label_glyph(".##", "#..", "#..", "#..", ".##"),
  'D' => label_glyph("##.", "#.#", "#.#", "#.#", "##."),
  'E' => label_glyph("###", "#..", "##.", "#..", "###"),
  'F' => label_glyph("###", "#..", "##.", "#..", "#.."),
  'G' => label_glyph(".##", "#..", "#.#", "#.#", ".##"),
  'H' => label_glyph("#.#", "#.#", "###", "#.#", "#.#"),
  'I' => label_glyph("###", ".#.", ".#.", ".#.", "###"),
  'J' => label_glyph("..#", "..#", "..#", "#.#", ".#."),
  'K' => label_glyph("#.#", "#.#", "##.", "#.#", "#.#"),
  'L' => label_glyph("#..", "#..", "#..", "#..", "###"),
  'M' => label_glyph("#.#", "###", "###", "#.#", "#.#"),
  'N' => label_glyph("#.#", "###", "###", "###", "#.#"),
  'O' => label_glyph(".#.", "#.#", "#.#", "#.#", ".#."),
  'P' => label_glyph("##.", "#.#", "##.", "#..", "#.."),
  'Q' => label_glyph(".#.", "#.#", "#.#", ".##", "..#"),
  'R' => label_glyph("##.", "#.#", "##.", "#.#", "#.#"),
  'S' => label_glyph(".##", "#..", ".#.", "..#", "##."),
  'T' => label_glyph("###", ".#.", ".#.", ".#.", ".#."),
  'U' => label_glyph("#.#", "#.#", "#.#", "#.#", "###"),
  'V' => label_glyph("#.#", "#.#", "#.#", "#.#", ".#."),
  'W' => label_glyph("#.#", "#.#", "###", "###", "#.#"),
  'X' => label_glyph("#.#", "#.#", ".#.", "#.#", "#.#"),
  'Y' => label_glyph("#.#", "#.#", ".#.", ".#.", ".#."),
  'Z' => label_glyph("###", "..#", ".#.", "#..", "###"),
)
const NETLOGO_VERSION_STRING = "7.0.4-beta1"
const TURTLE_REFERENCE_BUILTINS = String[
  "WHO", "COLOR", "HEADING", "XCOR", "YCOR", "SHAPE", "LABEL",
  "LABEL-COLOR", "BREED", "HIDDEN?", "SIZE", "PEN-SIZE", "PEN-MODE",
]
const PATCH_REFERENCE_BUILTINS = String["PXCOR", "PYCOR", "PCOLOR", "PLABEL", "PLABEL-COLOR"]
const LINK_REFERENCE_BUILTINS = String[
  "END1", "END2", "COLOR", "LABEL", "LABEL-COLOR", "HIDDEN?",
  "BREED", "THICKNESS", "SHAPE", "TIE-MODE",
]
const BASE_COLOR_RGBS = NTuple{3, Float64}[
  (141.0, 141.0, 141.0),
  (215.0, 50.0, 41.0),
  (241.0, 106.0, 21.0),
  (157.0, 110.0, 72.0),
  (236.0, 236.0, 41.0),
  (89.0, 176.0, 60.0),
  (44.0, 209.0, 59.0),
  (29.0, 159.0, 120.0),
  (84.0, 196.0, 196.0),
  (45.0, 141.0, 190.0),
  (52.0, 93.0, 169.0),
  (124.0, 80.0, 164.0),
  (167.0, 27.0, 106.0),
  (217.0, 99.0, 127.0)]
const COLOR_LIGHT_SHADE_SPAN = 4.9999
const COLOR_DARK_BRIGHTNESS_SCALE = 0.05
const COLOR_SAMPLE_CACHE = Ref{Union{Nothing, Vector{Tuple{Float64, NTuple{3, Float64}}}}}(nothing)

source_fragment(source::String, span::SourceSpan) =
  span.stop >= span.start ? source[span.start:span.stop] : ""

function visible_string_scopes(context::Context)
  depth = min(context.string_scope_depth, length(context.locals))
  deepcopy(context.locals[1:depth])
end

function visible_string_scope_names(context::Context)
  names = Set{String}()
  for scope in visible_string_scopes(context)
    union!(names, keys(scope))
  end
  names
end

function runtime_parse_error(err)
  err isa Diagnostic || throw(err)
  LogoRuntimeError(err.message)
end

agent_kind(::Observer) = ObserverKind
agent_kind(::Turtle) = TurtleKind
agent_kind(::Patch) = PatchKind
agent_kind(::Link) = LinkKind

function agent_allowed(agent_classes::String, kind::AgentKind)
  index =
    kind == ObserverKind ? 1 :
    kind == TurtleKind ? 2 :
    kind == PatchKind ? 3 : 4
  agent_classes[index] != '-'
end

numeric(value::Bool) = throw(LogoRuntimeError("expected a number, got Bool"))
numeric(value::Real) = Float64(value)
numeric(value) = throw(LogoRuntimeError("expected a number, got $(typeof(value))"))

logical(value::Bool) = value
logical(value) = throw(LogoRuntimeError("expected a boolean, got $(typeof(value))"))

logo_string(value::AbstractString) = String(value)
logo_string(value::Bool) = lowercase(string(value))
logo_string(::NobodyValue) = "nobody"
logo_string(value::CommandTaskValue) = "(anonymous command: $(source_fragment(value.model_source, value.source_span)))"
logo_string(value::ReporterTaskValue) = "(anonymous reporter: $(source_fragment(value.model_source, value.source_span)))"
logo_string(value::Turtle) = value.alive ? "(turtle $(value.id))" : "nobody"
logo_string(value::Patch) = value.alive ? "(patch $(value.pxcor) $(value.pycor))" : "nobody"
logo_string(value::Link) = value.alive ? "(link $(value.end1) $(value.end2))" : "nobody"
function logo_string(value::AgentSet)
  noun =
    value.kind == TurtleKind ? "turtles" :
    value.kind == PatchKind ? "patches" :
    "links"
  "(agentset, $(length(value)) $noun)"
end

logo_string(value::AbstractVector) = "[" * join((logo_string(item) for item in value), " ") * "]"
logo_string(value) = string(value)

escape_logo_string(value::AbstractString) = replace(String(value), "\\" => "\\\\", "\"" => "\\\"")
readable_logo_string(value::AbstractString) = "\"" * escape_logo_string(value) * "\""
readable_logo_string(value::AbstractVector) = "[" * join((readable_logo_string(item) for item in value), " ") * "]"
readable_logo_string(value) = error_logo_string(value)

function error_logo_string(value)
  if is_logo_number(value)
    number = Float64(value)
    if isfinite(number) && number == round(number)
      return string(Int(round(number)))
    end
    return string(number)
  elseif value isa AbstractString
    return String(value)
  end
  return logo_string(value)
end

aggregate_logo_string(value::AbstractString) = String(value)
aggregate_logo_string(value::AbstractVector) = "[" * join((aggregate_logo_string(item) for item in value), " ") * "]"
aggregate_logo_string(value) = is_logo_number(value) ? error_logo_string(value) : logo_string(value)

error_readable_logo_string(value::AbstractString) = "\"" * escape_logo_string(value) * "\""
error_readable_logo_string(value::AbstractVector) = "[" * join((error_readable_logo_string(item) for item in value), " ") * "]"
error_readable_logo_string(value) = error_logo_string(value)

code_identifier(name::AbstractString) = lowercase(String(name))
code_param_block(params::Vector{String}) =
  isempty(params) ? "[ ]" : "[ " * join((code_identifier(param) for param in params), " ") * " ]"

function normalize_code_fragment(fragment::AbstractString)
  text = strip(String(fragment))
  text = replace(text, r"\[(\S)" => s"[ \1")
  replace(text, r"(\S)\]" => s"\1 ]")
end

render_code_fragment(context::Context, node::AbstractNode) =
  normalize_code_fragment(source_fragment(context.runtime.model.source, spanof(node)))

render_code_value(context::Context, value::NumberLiteral) = error_logo_string(value.value)
render_code_value(context::Context, value::StringLiteral) = readable_logo_string(value.value)
render_code_value(context::Context, value::BoolLiteral) = logo_string(value.value)
render_code_value(context::Context, value::NobodyLiteral) = "nobody"
render_code_value(context::Context, value::VariableRef) = code_identifier(value.name)
render_code_value(context::Context, value::CallableRefNode) = code_identifier(value.name)
render_code_value(context::Context, value::SymbolArg) = code_identifier(value.name)
render_code_value(context::Context, value::AbstractExpr) = render_code_fragment(context, value)

function render_code_value(context::Context, value::ListLiteral)
  rendered = join((render_code_value(context, item) for item in value.items), " ")
  isempty(rendered) ? "[ ]" : "[ " * rendered * " ]"
end

render_code_value(context::Context, value::UnaryExpr) = value.op * render_code_value(context, value.arg)
render_code_value(context::Context, value::ReporterBlockNode) =
  code_param_block(value.params) * " -> " * render_code_value(context, value.expr)
render_code_value(context::Context, value::CommandTaskNode) =
  code_param_block(value.params) * " -> " * render_code_block(context, value.body)

function render_code_argument(context::Context, arg)
  arg isa BlockNode && return "[ " * render_code_block(context, arg) * " ]"
  arg isa AbstractNode && return render_code_value(context, arg)
  normalize_code_fragment(string(arg))
end

function render_code_value(context::Context, value::ReporterCall)
  spec = get_reporter(context.runtime.registry, value.name)
  if spec !== nothing && spec.syntax.left != VoidType && !isempty(value.args)
    parts = String[render_code_value(context, value.args[1]), code_identifier(value.name)]
    append!(parts, (render_code_argument(context, arg) for arg in value.args[2:end]))
    return join(parts, " ")
  end

  parts = String[code_identifier(value.name)]
  append!(parts, (render_code_argument(context, arg) for arg in value.args))
  join(parts, " ")
end

function render_code_statement(context::Context, stmt::CommandCall)
  parts = String[code_identifier(stmt.name)]
  append!(parts, (render_code_argument(context, arg) for arg in stmt.args))
  join(parts, " ")
end

render_code_statement(context::Context, stmt::AbstractStmt) = render_code_fragment(context, stmt)
render_code_block(context::Context, block::BlockNode) = join((render_code_statement(context, stmt) for stmt in block.statements), " ")
render_code_value(context::Context, value::BlockNode) = render_code_block(context, value)
function render_code_block(context::Context, block::CodeBlockNode)
  block.body isa AbstractString && return normalize_code_fragment(block.body)
  try
    return render_code_value(context, block.body)
  catch err
    err isa MethodError || rethrow()
    return normalize_code_fragment(block.source)
  end
end

display_logo_string(value::AbstractString) = String(value)
display_logo_string(value::AbstractVector) = "[" * join((display_logo_string(item) for item in value), " ") * "]"
display_logo_string(value) = error_logo_string(value)

function label_display_string(value)
  value === nothing && return ""
  replace(display_logo_string(value), '\n' => ' ', '\r' => ' ', '\t' => ' ')
end

function label_glyph(character::AbstractChar)
  if haskey(LABEL_FONT_GLYPHS, character)
    return LABEL_FONT_GLYPHS[character]
  end
  uppercase_text = uppercase(String(character))
  if length(uppercase_text) == 1
    uppercase_character = first(uppercase_text)
    return get(LABEL_FONT_GLYPHS, uppercase_character, QUESTION_LABEL_GLYPH)
  end
  QUESTION_LABEL_GLYPH
end

label_render_scale(world::World) = max(1, round(Int, max(world.patch_size, 1.0) / 5.0))

function label_text_dimensions(text::AbstractString, scale::Integer)
  characters = collect(String(text))
  isempty(characters) && return 0, 0
  width =
    length(characters) * LABEL_GLYPH_WIDTH * scale +
    (length(characters) - 1) * LABEL_GLYPH_SPACING * scale
  width, LABEL_GLYPH_HEIGHT * scale
end

function draw_label_text_raster!(raster, anchor_column::Float64, anchor_row::Float64, text::AbstractString, color::RGBAColor; scale::Integer=1, erase::Bool=false)
  characters = collect(String(text))
  isempty(characters) && return nothing
  text_width, text_height = label_text_dimensions(text, scale)
  start_column = floor(Int, anchor_column) - text_width + 1
  start_row = floor(Int, anchor_row) - text_height + 1
  pixels = Set{Tuple{Int, Int}}()
  current_column = start_column

  for character in characters
    glyph = label_glyph(character)
    for glyph_row in 1:LABEL_GLYPH_HEIGHT
      for glyph_column in 1:LABEL_GLYPH_WIDTH
        glyph[glyph_row][glyph_column] == '#' || continue
        base_row = start_row + (glyph_row - 1) * scale
        base_column = current_column + (glyph_column - 1) * scale
        for row_offset in 0:(scale - 1)
          raster_row = base_row + row_offset
          1 <= raster_row <= size(raster, 1) || continue
          for column_offset in 0:(scale - 1)
            raster_column = base_column + column_offset
            1 <= raster_column <= size(raster, 2) || continue
            push!(pixels, (raster_row, raster_column))
          end
        end
      end
    end
    current_column += (LABEL_GLYPH_WIDTH + LABEL_GLYPH_SPACING) * scale
  end

  paint_raster_pixels!(raster, pixels, color; erase=erase)
  nothing
end

output_agent_label(::Observer) = "observer"
output_agent_label(value::Turtle) = value.alive ? "turtle $(value.id)" : "nobody"
output_agent_label(value::Patch) = value.alive ? "patch $(value.pxcor) $(value.pycor)" : "nobody"
output_agent_label(value::Link) = value.alive ? "link $(value.end1) $(value.end2)" : "nobody"

function output_object_text(value; owner::Union{Nothing, AbstractAgent}=nothing, add_newline::Bool=false, readable::Bool=false)
  caption = owner === nothing ? "" : output_agent_label(owner)
  message =
    readable ?
    ((owner === nothing ? " " : "") * readable_logo_string(value)) :
    display_logo_string(value)
  buffer = IOBuffer()
  if !isempty(caption)
    print(buffer, caption, ": ")
  end
  print(buffer, message)
  add_newline && print(buffer, '\n')
  String(take!(buffer))
end

resolve_file_path(path::AbstractString) = normpath(abspath(String(path)))

function current_file_state(runtime::RuntimeState)
  path = runtime.current_file
  path === nothing && throw(LogoRuntimeError("No file has been opened."))
  state = get(runtime.open_files, path, nothing)
  state === nothing && throw(LogoRuntimeError("No file has been opened."))
  state::RuntimeFileState
end

function close_file_state!(state::RuntimeFileState)
  if state.writer !== nothing
    flush(state.writer)
    close(state.writer)
  end
  state.writer = nothing
  state.content = Char[]
  state.position = 1
  state.line = 1
  state.column = 1
  state.mode = :none
  nothing
end

function open_file!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  if !haskey(runtime.open_files, resolved)
    runtime.open_files[resolved] = RuntimeFileState(resolved)
  end
  runtime.current_file = resolved
  nothing
end

function close_current_file!(runtime::RuntimeState)
  runtime.current_file === nothing && return nothing
  path = runtime.current_file
  state = get(runtime.open_files, path, nothing)
  if state !== nothing
    close_file_state!(state)
    delete!(runtime.open_files, path)
  end
  runtime.current_file = nothing
  nothing
end

function close_all_files!(runtime::RuntimeState)
  for state in values(runtime.open_files)
    close_file_state!(state::RuntimeFileState)
  end
  empty!(runtime.open_files)
  runtime.current_file = nothing
  nothing
end

plot_name_key(name::AbstractString) = canonical_name(name)

function find_plot(manager::PlotManagerState, name::AbstractString)
  target = plot_name_key(name)
  findfirst(plot -> plot_name_key(plot.name) == target, manager.plots)
end

function find_plot_pen(plot::PlotState, name::AbstractString)
  target = plot_name_key(name)
  findfirst(pen -> plot_name_key(pen.name) == target, plot.pens)
end

function require_current_plot(runtime::RuntimeState)
  plot = runtime.plot_manager.current_plot
  plot === nothing && throw(LogoRuntimeError("There is no current plot"))
  plot
end

function require_current_plot_pen(runtime::RuntimeState)
  plot = require_current_plot(runtime)
  pen = plot.current_pen
  pen === nothing && throw(LogoRuntimeError("Plot '$(plot.name)' has no pens!"))
  pen
end

function set_current_plot!(runtime::RuntimeState, name::AbstractString)
  index = find_plot(runtime.plot_manager, name)
  index === nothing && throw(LogoRuntimeError("no such plot: \"$(String(name))\""))
  runtime.plot_manager.current_plot = runtime.plot_manager.plots[index]
  nothing
end

function plot_pen_exists(runtime::RuntimeState, name::AbstractString)
  plot = require_current_plot(runtime)
  find_plot_pen(plot, name) !== nothing
end

function create_temporary_plot_pen!(runtime::RuntimeState, name::AbstractString)
  plot = require_current_plot(runtime)
  index = find_plot_pen(plot, name)
  if index === nothing
    plot.current_pen = create_plot_pen!(plot, name; temporary=true)
  else
    plot.current_pen = plot.pens[index]
  end
  nothing
end

function set_current_plot_pen!(runtime::RuntimeState, name::AbstractString)
  plot = require_current_plot(runtime)
  index = find_plot_pen(plot, name)
  index === nothing && throw(LogoRuntimeError("There is no pen named \"$(String(name))\" in the current plot"))
  plot.current_pen = plot.pens[index]
  nothing
end

function soft_reset_plot_pen!(pen::PlotPenState)
  pen.x = 0.0
  pen.is_down = true
  empty!(pen.points)
  nothing
end

function hard_reset_plot_pen!(pen::PlotPenState)
  if pen.temporary
    soft_reset_plot_pen!(pen)
  else
    pen.x = 0.0
    pen.color = copy_plot_color(pen.default_color)
    pen.interval = pen.default_interval
    pen.mode = pen.default_mode
    pen.is_down = true
    pen.hidden = pen.default_hidden
    pen.in_legend = pen.default_in_legend
    empty!(pen.points)
  end
  nothing
end

function approximate_plot_limit(raw_limit::Float64, range::Float64)
  places = Int(3.0 - floor(log10(range)))
  if raw_limit < 0
    return -round(abs(raw_limit); digits=places)
  end
  round(raw_limit; digits=places)
end

function pretty_plot_range(range::Float64)
  tmag = 10.0^(floor(log10(range)) - 1.0) * 2.0
  ceil(range / tmag) * tmag
end

function expand_plot_range(minimum::Float64, maximum::Float64, new_value::Float64)
  shift = -minimum
  temp_max = maximum + shift
  temp_value = new_value + shift
  if temp_value < 0
    temp_range = temp_max - temp_value
    new_range = pretty_plot_range(temp_range)
    raw_min = (temp_max - new_range) - shift
    return approximate_plot_limit(raw_min, temp_range)
  end

  temp_range = temp_value
  new_range = pretty_plot_range(temp_range)
  raw_max = new_range - shift
  approximate_plot_limit(raw_max, temp_range)
end

function grow_plot_range_x!(plot::PlotState, x::Float64)
  if x > plot.x_max
    plot.x_max = expand_plot_range(plot.x_min, plot.x_max, x)
  end
  if x < plot.x_min
    plot.x_min = expand_plot_range(plot.x_min, plot.x_max, x)
  end
  nothing
end

function grow_plot_range_y!(plot::PlotState, y::Float64)
  if y > plot.y_max
    plot.y_max = expand_plot_range(plot.y_min, plot.y_max, y)
  end
  if y < plot.y_min
    plot.y_min = expand_plot_range(plot.y_min, plot.y_max, y)
  end
  nothing
end

function perhaps_grow_plot_ranges!(plot::PlotState, pen::PlotPenState, x::Float64, y::Float64)
  if plot.auto_plot_x
    if pen.mode == PLOT_PEN_BAR_MODE
      grow_plot_range_x!(plot, x + pen.interval)
    end
    grow_plot_range_x!(plot, x)
  end
  plot.auto_plot_y && grow_plot_range_y!(plot, y)
  nothing
end

function append_plot_point!(pen::PlotPenState, x::Float64, y::Float64)
  push!(pen.points, PlotPointState(x, y, pen.is_down, copy_plot_color(pen.color)))
  nothing
end

function plot_pen_y!(pen::PlotPenState, y::Float64)
  had_points = !isempty(pen.points)
  had_points && (pen.x += pen.interval)
  append_plot_point!(pen, pen.x, y)
  nothing
end

function plot_pen_xy!(pen::PlotPenState, x::Float64, y::Float64)
  pen.x = x
  append_plot_point!(pen, x, y)
  nothing
end

function plot_y!(runtime::RuntimeState, y_value)
  plot = require_current_plot(runtime)
  pen = require_current_plot_pen(runtime)
  y = numeric(y_value)
  plot_pen_y!(pen, y)
  pen.is_down && perhaps_grow_plot_ranges!(plot, pen, pen.x, y)
  nothing
end

function plot_xy!(runtime::RuntimeState, x_value, y_value)
  plot = require_current_plot(runtime)
  pen = require_current_plot_pen(runtime)
  x = numeric(x_value)
  y = numeric(y_value)
  plot_pen_xy!(pen, x, y)
  pen.is_down && perhaps_grow_plot_ranges!(plot, pen, x, y)
  nothing
end

function plot_histogram_bars(x_min::Float64, x_max::Float64, interval::Float64, values::Vector{Float64})
  bars = zeros(Int, floor(Int, (x_max - x_min) / interval))
  ceiling = 0
  for value in values
    bar = floor(Int, ((value - x_min) / interval) * (1 + 3.2e-15))
    index = bar + 1
    if 1 <= index <= length(bars)
      bars[index] += 1
      ceiling = max(ceiling, bars[index])
    end
  end
  bars, ceiling
end

function histogram!(runtime::RuntimeState, values_value)
  plot = require_current_plot(runtime)
  pen = require_current_plot_pen(runtime)
  pen.interval > 0 || throw(LogoRuntimeError(
    "You cannot histogram with a plot-pen-interval of $(error_logo_string(pen.interval))."))
  values = Float64[numeric(value) for value in list_argument(values_value, "histogram") if is_logo_number(value)]
  bars, ceiling = plot_histogram_bars(plot.x_min, plot.x_max, pen.interval, values)
  soft_reset_plot_pen!(pen)
  plot.auto_plot_y && grow_plot_range_y!(plot, Float64(ceiling))
  for (index, height) in enumerate(bars)
    height > 0 || continue
    x = plot.x_min + (index - 1) * pen.interval
    plot_pen_xy!(pen, x, Float64(height))
  end
  nothing
end

function set_histogram_num_bars!(runtime::RuntimeState, num_bars_value)
  num_bars = netlogo_exact_int(num_bars_value)
  num_bars >= 1 || throw(LogoRuntimeError("You cannot make a histogram with $(num_bars) bars."))
  plot = require_current_plot(runtime)
  pen = require_current_plot_pen(runtime)
  pen.interval = (plot.x_max - plot.x_min) / num_bars
  nothing
end

function set_plot_pen_interval!(runtime::RuntimeState, interval_value)
  require_current_plot_pen(runtime).interval = numeric(interval_value)
  nothing
end

function set_plot_pen_mode!(runtime::RuntimeState, mode_value)
  mode = netlogo_exact_int(mode_value)
  (PLOT_PEN_LINE_MODE <= mode <= PLOT_PEN_POINT_MODE) ||
    throw(LogoRuntimeError("$(mode) is not a valid plot pen mode (valid modes are 0, 1, and 2)"))
  require_current_plot_pen(runtime).mode = mode
  nothing
end

function set_plot_pen_color!(runtime::RuntimeState, color_value)
  require_current_plot_pen(runtime).color = normalize_color_slot_value(color_value)
  nothing
end

function set_plot_pen_down!(runtime::RuntimeState, is_down::Bool)
  require_current_plot_pen(runtime).is_down = is_down
  nothing
end

function set_plot_pen_hidden!(runtime::RuntimeState, hidden::Bool)
  require_current_plot_pen(runtime).hidden = hidden
  nothing
end

function reset_plot_pen!(runtime::RuntimeState)
  hard_reset_plot_pen!(require_current_plot_pen(runtime))
  nothing
end

function clear_plot_state!(plot::PlotState)
  filter!(pen -> !pen.temporary, plot.pens)
  foreach(hard_reset_plot_pen!, plot.pens)
  plot.current_pen = isempty(plot.pens) ? nothing : first(plot.pens)
  plot.auto_plot_x = true
  plot.auto_plot_y = true
  plot.x_min = plot.default_x_min
  plot.x_max = plot.default_x_max
  plot.y_min = plot.default_y_min
  plot.y_max = plot.default_y_max
  nothing
end

function clear_current_plot!(runtime::RuntimeState)
  clear_plot_state!(require_current_plot(runtime))
  nothing
end

function clear_all_plots!(runtime::RuntimeState)
  foreach(clear_plot_state!, runtime.plot_manager.plots)
  nothing
end

has_plot_callback_code(source::AbstractString) = !isempty(strip(String(source)))

function parse_plot_callback_block(runtime::RuntimeState, source::AbstractString)
  try
    parse_runtime_commands(String(source), runtime.model, runtime.registry, Set{String}())
  catch err
    throw(runtime_parse_error(err))
  end
end

function with_plot_randomness!(thunk::Function, context::Context)
  saved_rng = context.runtime.world.rng
  try
    context.runtime.world.rng = context.runtime.plot_rng
    return thunk()
  finally
    context.runtime.plot_rng = context.runtime.world.rng
    context.runtime.world.rng = saved_rng
  end
end

function run_plot_callback_code!(context::Context, source::AbstractString)
  has_plot_callback_code(source) || return false
  block = parse_plot_callback_block(context.runtime, source)
  child = Context(context.runtime, context.runtime.world.observer, [Dict{String, Any}()], nothing, false, 0)
  with_plot_randomness!(child) do
    try
      execute_block!(child, block, false)
      false
    catch signal
      if signal isa StopSignal
        true
      else
        rethrow()
      end
    end
  end
end

function run_plot_callbacks!(context::Context; setup::Bool)
  manager = context.runtime.plot_manager
  old_current_plot = manager.current_plot
  try
    for plot in manager.plots
      manager.current_plot = plot
      stopped = run_plot_callback_code!(context, setup ? plot.setup_code : plot.update_code)
      if !stopped
        old_current_pen = plot.current_pen
        try
          for pen in plot.pens
            pen.temporary && continue
            plot.current_pen = pen
            run_plot_callback_code!(context, setup ? pen.setup_code : pen.update_code)
          end
        finally
          plot.current_pen = old_current_pen
        end
      end
    end
  finally
    manager.current_plot = old_current_plot
  end
  nothing
end

setup_plots!(context::Context) = run_plot_callbacks!(context; setup=true)
update_plots!(context::Context) = run_plot_callbacks!(context; setup=false)

function clear_all_runtime!(runtime::RuntimeState)
  clear_all!(runtime.world)
  clear_output_area!(runtime)
  clear_all_plots!(runtime)
  nothing
end

function reset_ticks_command!(context::Context)
  reset_ticks!(context.runtime.world)
  setup_plots!(context)
  update_plots!(context)
  nothing
end

function tick_command!(context::Context)
  tick_advance!(context.runtime.world, 1.0)
  update_plots!(context)
  nothing
end

function clear_all_and_reset_ticks_command!(context::Context)
  clear_all_runtime!(context.runtime)
  reset_ticks_command!(context)
  nothing
end

plot_autoplot(plot::PlotState) = plot.auto_plot_x && plot.auto_plot_y
plot_autoplot(runtime::RuntimeState) = plot_autoplot(require_current_plot(runtime))
plot_autoplot_x(runtime::RuntimeState) = require_current_plot(runtime).auto_plot_x
plot_autoplot_y(runtime::RuntimeState) = require_current_plot(runtime).auto_plot_y
plot_name(runtime::RuntimeState) = require_current_plot(runtime).name
plot_x_min(runtime::RuntimeState) = require_current_plot(runtime).x_min
plot_x_max(runtime::RuntimeState) = require_current_plot(runtime).x_max
plot_y_min(runtime::RuntimeState) = require_current_plot(runtime).y_min
plot_y_max(runtime::RuntimeState) = require_current_plot(runtime).y_max

function set_plot_autoplot!(runtime::RuntimeState, x_enabled::Bool, y_enabled::Bool)
  plot = require_current_plot(runtime)
  plot.auto_plot_x = x_enabled
  plot.auto_plot_y = y_enabled
  nothing
end

function set_plot_range!(runtime::RuntimeState, min_value, max_value; is_x::Bool)
  min_number = numeric(min_value)
  max_number = numeric(max_value)
  min_number < max_number || throw(LogoRuntimeError(
    "the minimum must be less than the maximum, but $(min_number) is greater than or equal to $(max_number)"))
  plot = require_current_plot(runtime)
  if is_x
    plot.x_min = min_number
    plot.x_max = max_number
  else
    plot.y_min = min_number
    plot.y_max = max_number
  end
  nothing
end

file_exists(path::AbstractString) = ispath(resolve_file_path(path))

function delete_file!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  haskey(runtime.open_files, resolved) &&
    throw(LogoRuntimeError("You need to close the file before deletion"))
  rm(resolved)
  nothing
end

function ensure_file_mode!(runtime::RuntimeState, requested_mode::Symbol)
  state = current_file_state(runtime)
  if state.mode == :none
    if requested_mode == :read
      isfile(state.path) || throw(LogoRuntimeError("The file $(state.path) cannot be found"))
      state.content = collect(read(state.path, String))
      state.position = 1
      state.line = 1
      state.column = 1
      state.mode = :read
    elseif requested_mode == :write
      state.writer = open(state.path, "a")
      state.mode = :write
    else
      throw(ArgumentError("invalid file mode"))
    end
  elseif state.mode == :read && requested_mode != :read
    throw(LogoRuntimeError("You can only use READING primitives with this file"))
  elseif state.mode != requested_mode
    throw(LogoRuntimeError("You can only use WRITING primitives with this file"))
  end
  state
end

file_at_end(state::RuntimeFileState) = state.position > length(state.content)

function consume_file_char!(state::RuntimeFileState)
  char = state.content[state.position]
  state.position += 1
  if char == '\n' || char == '\r'
    state.line += 1
    state.column = 1
  else
    state.column += 1
  end
  char
end

function skip_file_whitespace!(state::RuntimeFileState)
  while !file_at_end(state) && state.content[state.position] in (' ', '\t', '\n', '\r')
    consume_file_char!(state)
  end
  nothing
end

file_literal_error(message::AbstractString, line::Int, column::Int) =
  LiteralParseError(String(message), line, column)
file_literal_error(state::RuntimeFileState, message::AbstractString) =
  file_literal_error(message, state.line, state.column)
format_literal_parse_error(error::LiteralParseError) =
  "$(error.message) (line number $(error.line), character $(error.column))"

function parse_file_string!(state::RuntimeFileState)
  start_line = state.line
  start_column = state.column
  consume_file_char!(state)
  buffer = IOBuffer()
  while !file_at_end(state)
    current = consume_file_char!(state)
    if current == '\\' && !file_at_end(state)
      next_char = state.content[state.position]
      escaped = decode_logo_string_escape(next_char)
      if escaped !== nothing
        consume_file_char!(state)
        print(buffer, escaped)
        continue
      end
    elseif current == '"'
      return String(take!(buffer))
    end
    print(buffer, current)
  end
  throw(file_literal_error("Expected a literal value.", start_line, start_column))
end

function parse_file_number_value(lexeme::String, line::Int, column::Int)
  try
    if occursin('.', lexeme)
      return parse(Float64, lexeme)
    end
    integer = parse(BigInt, lexeme)
    abs(integer) <= BigInt(9007199254740992) ||
      throw(file_literal_error("$(lexeme) is too large to be represented exactly as an integer in NetLogo", line, column))
    return Float64(integer)
  catch err
    err isa LiteralParseError && rethrow()
    throw(file_literal_error("Expected a literal value.", line, column))
  end
end

function parse_file_number!(state::RuntimeFileState; negative::Bool=false)
  start_line = state.line
  start_column = state.column
  buffer = IOBuffer()
  if negative
    print(buffer, consume_file_char!(state))
  end
  saw_digit = false
  while !file_at_end(state)
    current = state.content[state.position]
    if isdigit(current) || current == '.'
      saw_digit |= isdigit(current)
      print(buffer, consume_file_char!(state))
    else
      break
    end
  end
  saw_digit || throw(file_literal_error("Expected a literal value.", start_line, start_column))
  parse_file_number_value(String(take!(buffer)), start_line, start_column)
end

function parse_file_identifier!(state::RuntimeFileState; allow_constants::Bool=false)
  start_line = state.line
  start_column = state.column
  buffer = IOBuffer()
  while !file_at_end(state) && is_identifier_part(state.content[state.position])
    print(buffer, consume_file_char!(state))
  end
  identifier = uppercase(String(take!(buffer)))
  if identifier == "TRUE"
    return true
  elseif identifier == "FALSE"
    return false
  elseif identifier == "NOBODY"
    return NOBODY
  elseif allow_constants && identifier == "E"
    return MathConstants.e
  elseif allow_constants && identifier == "PI"
    return π
  end
  throw(file_literal_error("Expected a literal value.", start_line, start_column))
end

function parse_file_parenthesized_literal!(state::RuntimeFileState; allow_constants::Bool=false)
  consume_file_char!(state)
  skip_file_whitespace!(state)
  file_at_end(state) && throw(file_literal_error(state, "Expected a literal value."))
  value = parse_file_literal!(state; allow_constants=allow_constants)
  skip_file_whitespace!(state)
  file_at_end(state) && throw(file_literal_error(state, "Expected a closing parenthesis."))
  state.content[state.position] == ')' || throw(file_literal_error(state, "Expected a closing parenthesis."))
  consume_file_char!(state)
  value
end

function parse_file_list!(state::RuntimeFileState; allow_constants::Bool=false)
  open_line = state.line
  open_column = state.column
  consume_file_char!(state)
  result = Any[]
  skip_file_whitespace!(state)
  while !file_at_end(state) && state.content[state.position] != ']'
    push!(result, parse_file_literal!(state; allow_constants=allow_constants))
    skip_file_whitespace!(state)
  end
  file_at_end(state) && throw(file_literal_error("No closing bracket for this open bracket.", open_line, open_column))
  consume_file_char!(state)
  result
end

function parse_file_literal!(state::RuntimeFileState; allow_constants::Bool=false)
  file_at_end(state) && throw(EOFError())
  current = state.content[state.position]
  if current == '['
    parse_file_list!(state; allow_constants=allow_constants)
  elseif current == '('
    parse_file_parenthesized_literal!(state; allow_constants=allow_constants)
  elseif current == '"'
    parse_file_string!(state)
  elseif current == '-'
    (state.position < length(state.content) && isdigit(state.content[state.position + 1])) ||
      throw(file_literal_error(state, "Expected a literal value."))
    parse_file_number!(state; negative=true)
  elseif isdigit(current)
    parse_file_number!(state)
  elseif is_identifier_start(current)
    parse_file_identifier!(state; allow_constants=allow_constants)
  else
    throw(file_literal_error(state, "Expected a literal value."))
  end
end

function read_current_file_literal!(runtime::RuntimeState)
  state = ensure_file_mode!(runtime, :read)
  skip_file_whitespace!(state)
  file_at_end(state) && throw(EOFError())
  value = parse_file_literal!(state; allow_constants=true)
  skip_file_whitespace!(state)
  value
end

function read_literal_from_string(source::AbstractString)
  state = RuntimeFileState("")
  state.mode = :read
  state.content = collect(String(source))
  skip_file_whitespace!(state)
  file_at_end(state) && throw(file_literal_error(state, "Expected a literal value."))
  value = parse_file_literal!(state; allow_constants=true)
  skip_file_whitespace!(state)
  file_at_end(state) || throw(file_literal_error(state, "Extra characters after literal."))
  value
end

function read_current_file_line!(runtime::RuntimeState)
  state = ensure_file_mode!(runtime, :read)
  file_at_end(state) && throw(EOFError())
  buffer = IOBuffer()
  while !file_at_end(state)
    current = state.content[state.position]
    if current == '\r'
      consume_file_char!(state)
      if !file_at_end(state) && state.content[state.position] == '\n'
        consume_file_char!(state)
      end
      break
    elseif current == '\n'
      consume_file_char!(state)
      break
    end
    print(buffer, consume_file_char!(state))
  end
  String(take!(buffer))
end

function read_current_file_characters!(runtime::RuntimeState, count::Int)
  count >= 0 || throw(LogoRuntimeError("file-read-characters expects a nonnegative integer"))
  state = ensure_file_mode!(runtime, :read)
  file_at_end(state) && throw(EOFError())
  buffer = IOBuffer()
  remaining = count
  while remaining > 0 && !file_at_end(state)
    print(buffer, consume_file_char!(state))
    remaining -= 1
  end
  String(take!(buffer))
end

function current_file_at_end(runtime::RuntimeState)
  state = ensure_file_mode!(runtime, :read)
  file_at_end(state)
end

function flush_current_file!(runtime::RuntimeState)
  runtime.current_file === nothing && return nothing
  state = get(runtime.open_files, runtime.current_file, nothing)
  if state !== nothing && state.writer !== nothing
    flush(state.writer)
  end
  nothing
end

function write_current_file!(runtime::RuntimeState, text::AbstractString)
  state = ensure_file_mode!(runtime, :write)
  print(state.writer, text)
  nothing
end

function write_command_output!(runtime::RuntimeState, text::AbstractString)
  runtime.command_output *= String(text)
  nothing
end

function write_output_area!(runtime::RuntimeState, text::AbstractString)
  runtime.output_area *= String(text)
  nothing
end

function clear_output_area!(runtime::RuntimeState)
  runtime.output_area = ""
  nothing
end

plot_csv_encode(value::AbstractString) = "\"" * replace(String(value), "\"" => "\"\"") * "\""
plot_csv_header_row(values::AbstractVector{<:AbstractString}) = join((plot_csv_encode(value) for value in values), ",")
plot_csv_string(value::AbstractString) = String(value)
plot_csv_string(value::Bool) = lowercase(string(value))
plot_csv_string(value::Real) = string(value)
plot_csv_string(value::AbstractVector) = display_logo_string(value)
plot_csv_string(value) = error_logo_string(value)
plot_csv_data_row(values) = join((plot_csv_encode(plot_csv_string(value)) for value in values), ",")

function plot_export_timestamp_string()
  current = Dates.now(Dates.UTC)
  Dates.format(current, dateformat"mm/dd/yyyy HH:MM:SS") * ":" * lpad(string(Dates.millisecond(current)), 3, '0') * " +0000"
end

function export_plot_header!(io::IO, export_type::AbstractString)
  println(io, plot_csv_encode("export-$(String(export_type)) data ($(NETLOGO_VERSION_STRING))"))
  println(io, plot_csv_encode(""))
  println(io, plot_csv_encode(plot_export_timestamp_string()))
  println(io)
  nothing
end

function export_plot_interface_globals!(io::IO)
  println(io, plot_csv_encode("MODEL SETTINGS"))
  println(io)
  println(io)
  println(io)
  nothing
end

function export_plot_intro!(io::IO, plot::PlotState)
  println(io, plot_csv_encode(plot.name))
  println(io, plot_csv_header_row([
    "x min", "x max", "y min", "y max",
    "autoplot?", "current pen", "legend open?", "number of pens",
  ]))
  println(io, plot_csv_data_row(Any[
    plot.x_min,
    plot.x_max,
    plot.y_min,
    plot.y_max,
    plot_autoplot(plot),
    plot.current_pen === nothing ? "" : plot.current_pen.name,
    plot.legend_open,
    length(plot.pens),
  ]))
  println(io)
  nothing
end

function export_plot_pens!(io::IO, plot::PlotState)
  println(io, plot_csv_header_row(["pen name", "pen down?", "mode", "interval", "color", "x"]))
  for pen in plot.pens
    println(io, plot_csv_data_row(Any[pen.name, pen.is_down, pen.mode, pen.interval, pen.color, pen.x]))
  end
  println(io)
  nothing
end

function export_plot_points!(io::IO, plot::PlotState)
  if isempty(plot.pens)
    println(io)
    println(io)
    return nothing
  end

  for (index, pen) in enumerate(plot.pens)
    index > 1 && print(io, ",,,,")
    print(io, plot_csv_encode(pen.name))
  end
  println(io)

  headers = String[]
  for _ in plot.pens
    append!(headers, ["x", "y", "color", "pen down?"])
  end
  println(io, plot_csv_header_row(headers))

  max_points = maximum(length(pen.points) for pen in plot.pens)
  for row in 1:max_points
    for (column, pen) in enumerate(plot.pens)
      if row <= length(pen.points)
        point = pen.points[row]
        print(io, plot_csv_encode(plot_csv_string(point.x)))
        print(io, ",")
        print(io, plot_csv_encode(plot_csv_string(point.y)))
        print(io, ",")
        print(io, plot_csv_encode(plot_csv_string(point.color)))
        print(io, ",")
        print(io, plot_csv_encode(plot_csv_string(point.is_down)))
        column < length(plot.pens) && print(io, ",")
      else
        if column < length(plot.pens)
          print(io, ",,,,")
        else
          print(io, ",,,")
        end
      end
    end
    println(io)
  end
  nothing
end

function export_plot_body!(io::IO, plot::PlotState)
  export_plot_intro!(io, plot)
  export_plot_pens!(io, plot)
  export_plot_points!(io, plot)
  nothing
end

function export_plot!(runtime::RuntimeState, plot_name::AbstractString, path::AbstractString)
  index = find_plot(runtime.plot_manager, plot_name)
  index === nothing && throw(LogoRuntimeError("no such plot: \"$(plot_name)\""))
  resolved = resolve_file_path(path)
  open(resolved, "w") do io
    export_plot_header!(io, "plot")
    export_plot_interface_globals!(io)
    export_plot_body!(io, runtime.plot_manager.plots[index])
  end
  nothing
end

function export_all_plots!(runtime::RuntimeState, path::AbstractString)
  isempty(runtime.plot_manager.plots) && throw(LogoRuntimeError("there are no plots to export"))
  resolved = resolve_file_path(path)
  open(resolved, "w") do io
    export_plot_header!(io, "plots")
    export_plot_interface_globals!(io)
    for plot in runtime.plot_manager.plots
      export_plot_body!(io, plot)
      println(io)
    end
  end
  nothing
end

function export_output!(runtime::RuntimeState, path::AbstractString)
  resolved_path = String(path)
  isempty(resolved_path) && throw(LogoRuntimeError("Can't export to empty pathname."))
  resolved = resolve_file_path(resolved_path)
  open(resolved, "w") do io
    for line in eachsplit(runtime.output_area, '\n'; keepempty=false)
      println(io, line)
    end
  end
  nothing
end

function export_world!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  snapshot = WorldPersistenceSnapshot(
    runtime.world,
    current_perspective_subject!(runtime),
    runtime.output_area,
    deepcopy(runtime.plot_manager),
    copy(runtime.plot_rng),
    runtime.command_output
  )
  open(resolved, "w") do io
    Serialization.serialize(io, snapshot)
  end
  nothing
end

function render_view_pixels(runtime::RuntimeState)
  world = runtime.world
  height = max(1, drawing_height(world))
  width = max(1, drawing_width(world))
  patch_rows = world_height(world)
  patch_columns = world_width(world)
  pixels = Matrix{NTuple{4, Float64}}(undef, height, width)

  for row in 1:height
    patch_row = min(patch_rows - 1, floor(Int, ((row - 1) * patch_rows) / height))
    pycor = world.max_pycor - patch_row
    for column in 1:width
      patch_column = min(patch_columns - 1, floor(Int, ((column - 1) * patch_columns) / width))
      pxcor = world.min_pxcor + patch_column
      patch = get_patch(world, pxcor, pycor)
      pixels[row, column] = extract_rgba_channels(patch.pcolor)
    end
  end

  render_patch_labels!(pixels, world; topology_wrap=true)

  if world.drawing !== nothing
    @assert size(world.drawing) == size(pixels)
    for index in eachindex(pixels, world.drawing)
      pixels[index] = composite_rgba_over(pixels[index], world.drawing[index])
    end
  end

  render_live_view_agents!(pixels, world; topology_wrap=true, custom_shapes=runtime.custom_turtle_shapes)
  pixels
end

function colorant_view_image(runtime::RuntimeState)
  rgba_colorant_image(render_view_pixels(runtime))
end

function rgba_colorant_image(pixels::AbstractMatrix{<:NTuple{4, <:Real}})
  map(pixels) do pixel
    RGBA{Float32}(
      clamp(Float64(pixel[1]), 0.0, 255.0) / 255.0,
      clamp(Float64(pixel[2]), 0.0, 255.0) / 255.0,
      clamp(Float64(pixel[3]), 0.0, 255.0) / 255.0,
      clamp(Float64(pixel[4]), 0.0, 255.0) / 255.0,
    )
  end
end

function export_view!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  try
    FileIO.save(resolved, colorant_view_image(runtime))
  catch err
    throw(LogoRuntimeError("export-view: $(sprint(showerror, err))"))
  end
  nothing
end

function export_drawing!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  drawing = runtime.world.drawing === nothing ? blank_drawing(runtime.world) : runtime.world.drawing
  try
    FileIO.save(resolved, rgba_colorant_image(drawing))
  catch err
    throw(LogoRuntimeError("export-drawing: $(sprint(showerror, err))"))
  end
  nothing
end

function import_world!(runtime::RuntimeState, path::AbstractString)
  resolved = resolve_file_path(path)
  isfile(resolved) || throw(LogoRuntimeError("The file $(resolved) cannot be found"))
  snapshot = open(resolved, "r") do io
    Serialization.deserialize(io)
  end
  snapshot isa WorldPersistenceSnapshot || throw(LogoRuntimeError("The file $(resolved) is not a world export"))
  runtime.world = snapshot.world
  runtime.world.model = runtime.model
  rebuild_turtle_breed_members!(runtime.world)
  runtime.perspective_subject = snapshot.perspective_subject
  runtime.output_area = snapshot.output_area
  if snapshot.plot_manager !== nothing
    runtime.plot_manager = snapshot.plot_manager
  end
  if snapshot.plot_rng !== nothing
    runtime.plot_rng = snapshot.plot_rng
  end
  if snapshot.command_output !== nothing
    runtime.command_output = snapshot.command_output
  end
  nothing
end

rounded_image_channel(value) = Float64(round(Int, 255.0 * clamp(Float64(value), 0.0, 1.0)))

function image_rgba_channels(pixel)
  rounded_image_channel(red(pixel)),
  rounded_image_channel(green(pixel)),
  rounded_image_channel(blue(pixel)),
  rounded_image_channel(alpha(pixel))
end

function image_rgba_channels(pixel::NTuple{4, T}) where {T <: Real}
  Float64(pixel[1]),
  Float64(pixel[2]),
  Float64(pixel[3]),
  Float64(pixel[4])
end

function load_patch_import_image(path::AbstractString, opname::AbstractString)
  resolved = resolve_file_path(path)
  isfile(resolved) || throw(LogoRuntimeError("The file $(resolved) cannot be found"))
  try
    image = FileIO.load(resolved)
    ndims(image) >= 2 || throw(LogoRuntimeError("$(lowercase(opname)): unsupported image format"))
    return image
  catch err
    err isa LogoRuntimeError && rethrow()
    throw(LogoRuntimeError("$(lowercase(opname)): $(sprint(showerror, err))"))
  end
end

function sampled_image_rgba(image, source_x::Float64, source_y::Float64)
  height, width = size(image, 1), size(image, 2)
  x = clamp(source_x, 1.0, Float64(width))
  y = clamp(source_y, 1.0, Float64(height))
  x0 = clamp(floor(Int, x), 1, width)
  x1 = min(x0 + 1, width)
  y0 = clamp(floor(Int, y), 1, height)
  y1 = min(y0 + 1, height)
  fx = x1 == x0 ? 0.0 : x - Float64(x0)
  fy = y1 == y0 ? 0.0 : y - Float64(y0)

  r00, g00, b00, a00 = image_rgba_channels(image[y0, x0])
  r10, g10, b10, a10 = image_rgba_channels(image[y0, x1])
  r01, g01, b01, a01 = image_rgba_channels(image[y1, x0])
  r11, g11, b11, a11 = image_rgba_channels(image[y1, x1])

  interpolate(c00, c10, c01, c11) =
    (1.0 - fx) * (1.0 - fy) * c00 +
    fx * (1.0 - fy) * c10 +
    (1.0 - fx) * fy * c01 +
    fx * fy * c11

  interpolate(r00, r10, r01, r11),
  interpolate(g00, g10, g01, g11),
  interpolate(b00, b10, b01, b11),
  interpolate(a00, a10, a01, a11)
end

function import_patch_colors!(runtime::RuntimeState, path::AbstractString; as_netlogo_colors::Bool=true, opname::AbstractString="import-pcolors")
  image = load_patch_import_image(path, opname)
  image_height, image_width = size(image, 1), size(image, 2)
  scale_x = world_width(runtime.world) / Float64(image_width)
  scale_y = world_height(runtime.world) / Float64(image_height)
  scale = min(scale_x, scale_y)

  scaled_width =
    isapprox(scale, 1.0; atol=1e-12) ?
    image_width :
    max(1, round(Int, image_width * scale))
  scaled_height =
    isapprox(scale, 1.0; atol=1e-12) ?
    image_height :
    max(1, round(Int, image_height * scale))

  scaled_width = min(scaled_width, world_width(runtime.world))
  scaled_height = min(scaled_height, world_height(runtime.world))
  width_offset = fld(world_width(runtime.world) - scaled_width, 2)
  height_offset = fld(world_height(runtime.world) - scaled_height, 2)
  identity_scale = isapprox(scale, 1.0; atol=1e-12)

  current_pxcor = runtime.world.min_pxcor + width_offset
  for column in 1:scaled_width
    source_x = identity_scale ? Float64(column) : ((Float64(column) - 0.5) / scale) + 0.5
    current_pycor = runtime.world.max_pycor - height_offset
    for row in 1:scaled_height
      source_y = identity_scale ? Float64(row) : ((Float64(row) - 0.5) / scale) + 0.5
      red_channel, green_channel, blue_channel, alpha_channel = sampled_image_rgba(image, source_x, source_y)
      if !isapprox(alpha_channel, 0.0; atol=1e-12)
        patch = get_patch(runtime.world, current_pxcor, current_pycor)
        patch.pcolor =
          as_netlogo_colors ?
          approximate_rgb_color(red_channel, green_channel, blue_channel) :
          rgb_list(red_channel, green_channel, blue_channel)
      end
      current_pycor -= 1
    end
    current_pxcor += 1
  end
  nothing
end

function composite_rgba_over(destination::NTuple{4, Float64}, source::NTuple{4, Float64})
  destination_alpha = clamp(destination[4], 0.0, 255.0) / 255.0
  source_alpha = clamp(source[4], 0.0, 255.0) / 255.0
  out_alpha = source_alpha + destination_alpha * (1.0 - source_alpha)
  out_alpha <= eps(Float64) && return (0.0, 0.0, 0.0, 0.0)
  blend_channel(index) =
    ((source[index] * source_alpha) + (destination[index] * destination_alpha * (1.0 - source_alpha))) / out_alpha
  (
    blend_channel(1),
    blend_channel(2),
    blend_channel(3),
    255.0 * out_alpha,
  )
end

function import_drawing!(runtime::RuntimeState, path::AbstractString; opname::AbstractString="import-drawing")
  image = load_patch_import_image(path, opname)
  drawing = runtime.world.drawing === nothing ? blank_drawing(runtime.world) : runtime.world.drawing
  image_height, image_width = size(image, 1), size(image, 2)
  target_height, target_width = size(drawing, 1), size(drawing, 2)
  scale_x = target_width / Float64(image_width)
  scale_y = target_height / Float64(image_height)
  scale = min(scale_x, scale_y)

  scaled_width =
    isapprox(scale, 1.0; atol=1e-12) ?
    image_width :
    max(1, round(Int, image_width * scale))
  scaled_height =
    isapprox(scale, 1.0; atol=1e-12) ?
    image_height :
    max(1, round(Int, image_height * scale))

  scaled_width = min(scaled_width, target_width)
  scaled_height = min(scaled_height, target_height)
  width_offset = fld(target_width - scaled_width, 2)
  height_offset = fld(target_height - scaled_height, 2)
  identity_scale = isapprox(scale, 1.0; atol=1e-12)

  for column in 1:scaled_width
    source_x = identity_scale ? Float64(column) : ((Float64(column) - 0.5) / scale) + 0.5
    target_x = width_offset + column
    for row in 1:scaled_height
      source_y = identity_scale ? Float64(row) : ((Float64(row) - 0.5) / scale) + 0.5
      target_y = height_offset + row
      sampled = sampled_image_rgba(image, source_x, source_y)
      drawing[target_y, target_x] = composite_rgba_over(drawing[target_y, target_x], sampled)
    end
  end

  runtime.world.drawing = drawing
  nothing
end

function rescale_drawing!(world::World)
  world.drawing === nothing && return nothing
  old_drawing = world.drawing
  new_drawing = blank_drawing(world)
  old_height, old_width = size(old_drawing, 1), size(old_drawing, 2)
  new_height, new_width = size(new_drawing, 1), size(new_drawing, 2)
  if old_height == new_height && old_width == new_width
    world.drawing = copy(old_drawing)
    return nothing
  end

  scale_x = new_width / Float64(old_width)
  scale_y = new_height / Float64(old_height)
  for column in 1:new_width
    source_x = ((Float64(column) - 0.5) / scale_x) + 0.5
    for row in 1:new_height
      source_y = ((Float64(row) - 0.5) / scale_y) + 0.5
      new_drawing[row, column] = sampled_image_rgba(old_drawing, source_x, source_y)
    end
  end

  world.drawing = new_drawing
  nothing
end

function random_state_snapshot(world::World)
  io = IOBuffer()
  Serialization.serialize(io, copy(world.rng))
  Any[Float64(byte) for byte in take!(io)]
end

is_logo_number(value) = value isa Real && !(value isa Bool)

wrap_color_number(value) = mod(numeric(value), 140.0)
color_family_index(value) = floor(Int, wrap_color_number(value) / 10.0)
color_family_start(value) = 10.0 * color_family_index(value)
color_base_number(value) = 5.0 + 10.0 * color_family_index(value)
rounded_rgb_channel(value::Real) = Int(floor(clamp(Float64(value), 0.0, 255.0) + 0.5))
canonical_rgb_component(value::Real) =
  isapprox(Float64(value), round(Float64(value)); atol=1e-9) ? Float64(round(Float64(value))) : Float64(value)

rgb_list_shape_error() = LogoRuntimeError("An rgb list must contain 3 or 4 numbers 0-255")
rgb_list_range_error() = LogoRuntimeError("RGB values must be 0-255")
invalid_color_error() =
  LogoRuntimeError("Color must be a number or a valid RGB/A color list with 3 - 4 numbers that have values between 0 and 255.")

function base_color_rgb(family::Int)
  0 <= family < length(BASE_COLOR_RGBS) || throw(LogoRuntimeError("unknown color family"))
  BASE_COLOR_RGBS[family + 1]
end

function rgb_to_hsb_channels(red::Real, green::Real, blue::Real)
  red_fraction = clamp(Float64(red), 0.0, 255.0) / 255.0
  green_fraction = clamp(Float64(green), 0.0, 255.0) / 255.0
  blue_fraction = clamp(Float64(blue), 0.0, 255.0) / 255.0
  max_channel = max(red_fraction, green_fraction, blue_fraction)
  min_channel = min(red_fraction, green_fraction, blue_fraction)
  delta = max_channel - min_channel

  hue =
    if delta <= eps(Float64)
      0.0
    elseif max_channel == red_fraction
      60.0 * mod((green_fraction - blue_fraction) / delta, 6.0)
    elseif max_channel == green_fraction
      60.0 * (((blue_fraction - red_fraction) / delta) + 2.0)
    else
      60.0 * (((red_fraction - green_fraction) / delta) + 4.0)
    end
  saturation = max_channel <= eps(Float64) ? 0.0 : 100.0 * delta / max_channel
  brightness = 100.0 * max_channel
  hue, saturation, brightness
end

function hsb_to_rgb_channels(hue_value, saturation_value, brightness_value)
  hue = mod(numeric(hue_value), 360.0)
  saturation = clamp(numeric(saturation_value), 0.0, 100.0) / 100.0
  brightness = clamp(numeric(brightness_value), 0.0, 100.0) / 100.0

  chroma = brightness * saturation
  segment = hue / 60.0
  second = chroma * (1.0 - abs(mod(segment, 2.0) - 1.0))

  red_prime, green_prime, blue_prime =
    if segment < 1.0
      chroma, second, 0.0
    elseif segment < 2.0
      second, chroma, 0.0
    elseif segment < 3.0
      0.0, chroma, second
    elseif segment < 4.0
      0.0, second, chroma
    elseif segment < 5.0
      second, 0.0, chroma
    else
      chroma, 0.0, second
    end

  match = brightness - chroma
  255.0 * (red_prime + match), 255.0 * (green_prime + match), 255.0 * (blue_prime + match)
end

function color_number_rgb(color_value)
  wrapped = wrap_color_number(color_value)
  family = color_family_index(wrapped)
  shade = wrapped - 10.0 * family

  if family == 0
    gray_value = first(base_color_rgb(0))
    if shade <= 5.0
      channel = gray_value * (shade / 5.0)
      return channel, channel, channel
    end
    blend = min(1.0, (shade - 5.0) / COLOR_LIGHT_SHADE_SPAN)
    channel = gray_value + (255.0 - gray_value) * blend
    return channel, channel, channel
  end

  base_red, base_green, base_blue = base_color_rgb(family)
  hue, saturation, brightness = rgb_to_hsb_channels(base_red, base_green, base_blue)
  if shade <= 5.0
    blend = shade / 5.0
    shaded_brightness = brightness * (COLOR_DARK_BRIGHTNESS_SCALE + (1.0 - COLOR_DARK_BRIGHTNESS_SCALE) * blend)
    return hsb_to_rgb_channels(hue, saturation, shaded_brightness)
  end

  blend = min(1.0, (shade - 5.0) / COLOR_LIGHT_SHADE_SPAN)
  shaded_saturation = saturation * (1.0 - blend)
  shaded_brightness = brightness + (100.0 - brightness) * blend
  hsb_to_rgb_channels(hue, shaded_saturation, shaded_brightness)
end

function validated_rgb_list(value; assignment::Bool=false)
  value isa AbstractVector || throw(assignment ? invalid_color_error() : invalid_color_error())
  (length(value) == 3 || length(value) == 4) || throw(assignment ? rgb_list_shape_error() : invalid_color_error())

  channels = Float64[]
  for item in value
    (item isa Real && !(item isa Bool)) || throw(assignment ? rgb_list_shape_error() : invalid_color_error())
    channel = Float64(item)
    0.0 <= channel <= 255.0 || throw(assignment ? rgb_list_range_error() : invalid_color_error())
    push!(channels, channel)
  end
  channels
end

function extract_rgb_channels(value)
  if is_logo_number(value)
    return color_number_rgb(value)
  elseif value isa AbstractVector
    channels = validated_rgb_list(value)
    return channels[1], channels[2], channels[3]
  end
  throw(invalid_color_error())
end

function extract_rgba_channels(value)
  if is_logo_number(value)
    red, green, blue = color_number_rgb(value)
    return red, green, blue, 255.0
  elseif value isa AbstractVector
    channels = validated_rgb_list(value)
    if length(channels) == 4
      return channels[1], channels[2], channels[3], channels[4]
    end
    return channels[1], channels[2], channels[3], 255.0
  end
  throw(invalid_color_error())
end

pen_draw_mode(turtle::Turtle) =
  turtle.pen_mode == "down" ? :draw :
  turtle.pen_mode == "erase" ? :erase :
  :none

function drawing_buffer!(world::World; erase::Bool=false)
  if world.drawing === nothing
    erase && return nothing
    world.drawing = blank_drawing(world)
  end
  world.drawing
end

function world_to_drawing_coordinates(world::World, x::Real, y::Real)
  column = ((Float64(x) - world.min_pxcor + 0.5) * world.patch_size) + 0.5
  row = ((world.max_pycor - Float64(y) + 0.5) * world.patch_size) + 0.5
  column, row
end

function label_wrap_offsets(
  raster,
  world::World,
  anchor_x::Real,
  anchor_y::Real,
  text_width::Integer,
  text_height::Integer)
  anchor_column, anchor_row = world_to_drawing_coordinates(world, anchor_x, anchor_y)
  x_offsets = Float64[0.0]
  y_offsets = Float64[0.0]

  if axis_wraps(world, :x)
    end_column = floor(Int, anchor_column)
    start_column = end_column - Int(text_width) + 1
    end_column > size(raster, 2) && push!(x_offsets, -Float64(world_width(world)))
    start_column < 1 && push!(x_offsets, Float64(world_width(world)))
  end

  if axis_wraps(world, :y)
    end_row = floor(Int, anchor_row)
    start_row = end_row - Int(text_height) + 1
    # World-space Y increases upward while raster rows increase downward.
    end_row > size(raster, 1) && push!(y_offsets, Float64(world_height(world)))
    start_row < 1 && push!(y_offsets, -Float64(world_height(world)))
  end

  offsets = Tuple{Float64, Float64}[]
  for x_offset in unique(x_offsets), y_offset in unique(y_offsets)
    push!(offsets, (x_offset, y_offset))
  end
  offsets
end

function raster_brush_pixels(raster, column::Float64, row::Float64; width::Real=1.0)
  radius = max(Float64(width), 1.0) / 2.0
  radius_squared = radius^2 + 1e-9
  min_column = max(1, floor(Int, column - radius))
  max_column = min(size(raster, 2), ceil(Int, column + radius))
  min_row = max(1, floor(Int, row - radius))
  max_row = min(size(raster, 1), ceil(Int, row + radius))
  pixels = Tuple{Int, Int}[]

  for raster_row in min_row:max_row
    for raster_column in min_column:max_column
      if (raster_column - column)^2 + (raster_row - row)^2 <= radius_squared
        push!(pixels, (raster_row, raster_column))
      end
    end
  end
  pixels
end

function paint_raster_pixels!(raster, pixels, color::NTuple{4, Float64}; erase::Bool=false)
  for (raster_row, raster_column) in pixels
    raster[raster_row, raster_column] =
      erase ?
      (0.0, 0.0, 0.0, 0.0) :
      composite_rgba_over(raster[raster_row, raster_column], color)
  end
  nothing
end

function paint_raster_brush!(raster, column::Float64, row::Float64, color::NTuple{4, Float64}; width::Real=1.0, erase::Bool=false)
  paint_raster_pixels!(raster, raster_brush_pixels(raster, column, row; width=width), color; erase=erase)
  nothing
end

function paint_drawing_brush!(world::World, column::Float64, row::Float64, color::NTuple{4, Float64}; width::Real=1.0, erase::Bool=false)
  drawing = drawing_buffer!(world; erase=erase)
  drawing === nothing && return nothing
  paint_raster_brush!(drawing, column, row, color; width=width, erase=erase)
  nothing
end

function wrapped_world_line_segments(world::World, start_x::Real, start_y::Real, end_x::Real, end_y::Real)
  startX = Float64(start_x)
  startY = Float64(start_y)
  xdiff = Float64(end_x) - startX
  ydiff = Float64(end_y) - startY
  distX = xdiff
  distY = ydiff
  miny = world.min_pycor - 0.5
  maxy = world.max_pycor + 0.4999999
  minx = world.min_pxcor - 0.5
  maxx = world.max_pxcor + 0.4999999
  pixel_size = 1.0 / world.patch_size
  segments = NTuple{4, Float64}[]

  count = 0
  while count < 100
    endX = startX + distX
    endY = startY + distY
    newStartX = 0.0
    newStartY = 0.0
    wrapped = false

    if axis_wraps(world, :y) && endY < miny
      endY = miny
      endX = (xdiff * (endY - startY)) / ydiff + startX
      newStartY = maxy
      newStartX = endX
      if isapprox(newStartX, minx; atol=1e-12)
        newStartX = maxx
      elseif isapprox(newStartX, maxx; atol=1e-12)
        newStartX = minx
      end
      wrapped = true
    elseif axis_wraps(world, :y) && endY > maxy
      endY = maxy
      endX = (xdiff * (endY - startY)) / ydiff + startX
      newStartX = endX
      newStartY = miny
      if isapprox(newStartX, minx; atol=1e-12)
        newStartX = maxx
      elseif isapprox(newStartX, maxx; atol=1e-12)
        newStartX = minx
      end
      wrapped = true
    end

    if axis_wraps(world, :x) && endX < minx
      endX = minx
      endY = (ydiff * (endX - startX)) / xdiff + startY
      newStartX = maxx
      newStartY = endY
      if isapprox(newStartY, miny; atol=1e-12)
        newStartY = maxy
      elseif isapprox(newStartY, maxy; atol=1e-12)
        newStartY = miny
      end
      wrapped = true
    elseif axis_wraps(world, :x) && endX > maxx
      endX = maxx
      endY = (ydiff * (endX - startX)) / xdiff + startY
      newStartX = minx
      newStartY = endY
      if isapprox(newStartY, miny; atol=1e-12)
        newStartY = maxy
      elseif isapprox(newStartY, maxy; atol=1e-12)
        newStartY = miny
      end
      wrapped = true
    end

    push!(segments, (startX, startY, endX, endY))
    distX -= (endX - startX)
    distY -= (endY - startY)
    abs(distX) < pixel_size && abs(distY) < pixel_size && break
    wrapped || break
    startX = newStartX
    startY = newStartY
    count += 1
  end

  segments
end

function draw_raster_segment!(raster, world::World, start_x::Real, start_y::Real, end_x::Real, end_y::Real, color::NTuple{4, Float64}; width::Real=1.0, erase::Bool=false)
  start_column, start_row = world_to_drawing_coordinates(world, start_x, start_y)
  end_column, end_row = world_to_drawing_coordinates(world, end_x, end_y)
  delta_column = end_column - start_column
  delta_row = end_row - start_row
  steps = max(1, ceil(Int, 2 * max(abs(delta_column), abs(delta_row))))
  pixels = Set{Tuple{Int, Int}}()
  for step in 0:steps
    fraction = step / steps
    union!(pixels, raster_brush_pixels(
      raster,
      start_column + fraction * delta_column,
      start_row + fraction * delta_row;
      width=width))
  end
  paint_raster_pixels!(raster, pixels, color; erase=erase)
  nothing
end

function draw_wrapped_raster_line!(raster, world::World, start_x::Real, start_y::Real, end_x::Real, end_y::Real, color::NTuple{4, Float64}; width::Real=1.0, erase::Bool=false)
  for (segment_start_x, segment_start_y, segment_end_x, segment_end_y) in
    wrapped_world_line_segments(world, start_x, start_y, end_x, end_y)
    draw_raster_segment!(raster, world, segment_start_x, segment_start_y, segment_end_x, segment_end_y, color; width=width, erase=erase)
  end
  nothing
end

function draw_drawing_segment!(world::World, start_x::Real, start_y::Real, end_x::Real, end_y::Real, color::NTuple{4, Float64}; width::Real=1.0, erase::Bool=false)
  drawing = drawing_buffer!(world; erase=erase)
  drawing === nothing && return nothing
  draw_raster_segment!(drawing, world, start_x, start_y, end_x, end_y, color; width=width, erase=erase)
end

function draw_wrapped_drawing_line!(world::World, start_x::Real, start_y::Real, end_x::Real, end_y::Real, color::NTuple{4, Float64}; width::Real=1.0, erase::Bool=false)
  drawing = drawing_buffer!(world; erase=erase)
  drawing === nothing && return nothing
  draw_wrapped_raster_line!(drawing, world, start_x, start_y, end_x, end_y, color; width=width, erase=erase)
end

visual_turtle_scale(world::World, turtle::Turtle) = max(turtle.size, 1.0 / world.patch_size)
visual_turtle_diameter(world::World, turtle::Turtle) = world.patch_size * visual_turtle_scale(world, turtle)
visual_link_width(world::World, link::Link) = max(world.patch_size * link.thickness, 1.0)

function turtle_shape_spec(shape::AbstractString)
  normalized = lowercase(String(shape))
  if normalized in ("default", "arrow")
    DEFAULT_TURTLE_RENDER_SHAPE
  elseif normalized == "airplane"
    AIRPLANE_TURTLE_RENDER_SHAPE
  elseif normalized == "triangle"
    TRIANGLE_TURTLE_RENDER_SHAPE
  elseif normalized == "triangle 2"
    TRIANGLE2_TURTLE_RENDER_SHAPE
  elseif normalized in ("square", "box")
    SQUARE_TURTLE_RENDER_SHAPE
  elseif normalized == "square 2"
    SQUARE2_TURTLE_RENDER_SHAPE
  elseif normalized in ("circle", "cylinder")
    CIRCLE_TURTLE_RENDER_SHAPE
  elseif normalized == "circle 2"
    CIRCLE2_TURTLE_RENDER_SHAPE
  elseif normalized == "line"
    LINE_TURTLE_RENDER_SHAPE
  elseif normalized == "line half"
    LINE_HALF_TURTLE_RENDER_SHAPE
  elseif normalized == "x"
    X_TURTLE_RENDER_SHAPE
  elseif normalized == "target"
    TARGET_TURTLE_RENDER_SHAPE
  elseif normalized == "bug"
    BUG_TURTLE_RENDER_SHAPE
  elseif normalized == "butterfly"
    BUTTERFLY_TURTLE_RENDER_SHAPE
  elseif normalized == "car"
    CAR_TURTLE_RENDER_SHAPE
  elseif normalized == "cow"
    COW_TURTLE_RENDER_SHAPE
  elseif normalized == "face happy"
    FACEHAPPY_TURTLE_RENDER_SHAPE
  elseif normalized == "face neutral"
    FACENEUTRAL_TURTLE_RENDER_SHAPE
  elseif normalized == "face sad"
    FACESAD_TURTLE_RENDER_SHAPE
  elseif normalized == "fish"
    FISH_TURTLE_RENDER_SHAPE
  elseif normalized == "flag"
    FLAG_TURTLE_RENDER_SHAPE
  elseif normalized == "flower"
    FLOWER_TURTLE_RENDER_SHAPE
  elseif normalized == "house"
    HOUSE_TURTLE_RENDER_SHAPE
  elseif normalized == "leaf"
    LEAF_TURTLE_RENDER_SHAPE
  elseif normalized == "pentagon"
    PENTAGON_TURTLE_RENDER_SHAPE
  elseif normalized == "person"
    PERSON_TURTLE_RENDER_SHAPE
  elseif normalized == "plant"
    PLANT_TURTLE_RENDER_SHAPE
  elseif normalized == "sheep"
    SHEEP_TURTLE_RENDER_SHAPE
  elseif normalized == "star"
    STAR_TURTLE_RENDER_SHAPE
  elseif normalized == "tree"
    TREE_TURTLE_RENDER_SHAPE
  elseif normalized == "truck"
    TRUCK_TURTLE_RENDER_SHAPE
  elseif normalized == "turtle"
    TURTLE_TURTLE_RENDER_SHAPE
  elseif normalized == "wheel"
    WHEEL_TURTLE_RENDER_SHAPE
  elseif normalized == "wolf"
    WOLF_TURTLE_RENDER_SHAPE
  else
    nothing
  end
end

function turtle_shape_spec(shape::AbstractString, custom_shapes::Dict{String, Any})
  result = turtle_shape_spec(shape)
  result !== nothing && return result
  get(custom_shapes, lowercase(String(shape)), nothing)
end

fixed_shape_color(color::Nothing, agent_color::RGBAColor) = agent_color
fixed_shape_color(color::RGBAColor, agent_color::RGBAColor) = color

function raster_segment_pixels(raster, start_column::Float64, start_row::Float64, end_column::Float64, end_row::Float64; width::Real=1.0)
  delta_column = end_column - start_column
  delta_row = end_row - start_row
  steps = max(1, ceil(Int, 2 * max(abs(delta_column), abs(delta_row))))
  pixels = Set{Tuple{Int, Int}}()
  for step in 0:steps
    fraction = step / steps
    union!(pixels, raster_brush_pixels(
      raster,
      start_column + fraction * delta_column,
      start_row + fraction * delta_row;
      width=width))
  end
  pixels
end

function polygon_contains_pixel(points::AbstractVector{<:NTuple{2, Float64}}, column::Float64, row::Float64)
  inside = false
  previous_index = lastindex(points)
  for index in eachindex(points)
    current_column, current_row = points[index]
    previous_column, previous_row = points[previous_index]
    intersects = ((current_row > row) != (previous_row > row)) &&
      (column <= (previous_column - current_column) * (row - current_row) / (previous_row - current_row) + current_column)
    intersects && (inside = !inside)
    previous_index = index
  end
  inside
end

function raster_polygon_pixels(raster, points::AbstractVector{<:NTuple{2, Float64}})
  pixels = Set{Tuple{Int, Int}}()
  min_column = max(1, floor(Int, minimum(point[1] for point in points)))
  max_column = min(size(raster, 2), ceil(Int, maximum(point[1] for point in points)))
  min_row = max(1, floor(Int, minimum(point[2] for point in points)))
  max_row = min(size(raster, 1), ceil(Int, maximum(point[2] for point in points)))

  for row in min_row:max_row
    for column in min_column:max_column
      polygon_contains_pixel(points, Float64(column), Float64(row)) && push!(pixels, (row, column))
    end
  end

  previous_index = lastindex(points)
  for index in eachindex(points)
    start_column, start_row = points[previous_index]
    end_column, end_row = points[index]
    union!(pixels, raster_segment_pixels(raster, start_column, start_row, end_column, end_row))
    previous_index = index
  end
  pixels
end

function transform_turtle_shape_point(world::World, turtle::Turtle, point::NTuple{2, Float64}, rotatable::Bool)
  offset_x = point[1] * visual_turtle_scale(world, turtle)
  offset_y = point[2] * visual_turtle_scale(world, turtle)
  if rotatable
    offset_x, offset_y = rotate_clockwise_displacement(offset_x, offset_y, turtle.heading)
  end
  center_column, center_row = world_to_drawing_coordinates(world, turtle.xcor, turtle.ycor)
  center_column + offset_x * world.patch_size, center_row - offset_y * world.patch_size
end

function draw_turtle_shape_element!(raster, world::World, turtle::Turtle, element::TurtlePolygonElement, agent_color::RGBAColor; erase::Bool=false, rotatable::Bool=true)
  points = [transform_turtle_shape_point(world, turtle, point, rotatable) for point in element.points]
  paint_raster_pixels!(raster, raster_polygon_pixels(raster, points), fixed_shape_color(element.color, agent_color); erase=erase)
  nothing
end

function draw_turtle_shape_element!(raster, world::World, turtle::Turtle, element::TurtleCircleElement, agent_color::RGBAColor; erase::Bool=false, rotatable::Bool=true)
  center_column, center_row = transform_turtle_shape_point(world, turtle, element.center, rotatable)
  diameter = max(2.0 * element.radius * visual_turtle_diameter(world, turtle), 1.0)
  paint_raster_brush!(raster, center_column, center_row, fixed_shape_color(element.color, agent_color); width=diameter, erase=erase)
  nothing
end

function draw_turtle_shape_element!(raster, world::World, turtle::Turtle, element::TurtleSegmentElement, agent_color::RGBAColor; erase::Bool=false, rotatable::Bool=true)
  start_column, start_row = transform_turtle_shape_point(world, turtle, element.start, rotatable)
  end_column, end_row = transform_turtle_shape_point(world, turtle, element.stop, rotatable)
  width = max(element.width * visual_turtle_diameter(world, turtle), 1.0)
  paint_raster_pixels!(raster, raster_segment_pixels(raster, start_column, start_row, end_column, end_row; width=width), fixed_shape_color(element.color, agent_color); erase=erase)
  nothing
end

function draw_turtle_shape_spec!(raster, world::World, turtle::Turtle, spec::TurtleShapeSpec, agent_color::RGBAColor; erase::Bool=false)
  for element in spec.elements
    draw_turtle_shape_element!(raster, world, turtle, element, agent_color; erase=erase, rotatable=spec.rotatable)
  end
  nothing
end

function draw_link_arrowhead!(raster, world::World, start_x::Real, start_y::Real, end_x::Real, end_y::Real, color::RGBAColor; width::Real=1.0, erase::Bool=false)
  start_column, start_row = world_to_drawing_coordinates(world, start_x, start_y)
  end_column, end_row = world_to_drawing_coordinates(world, end_x, end_y)
  delta_column = end_column - start_column
  delta_row = end_row - start_row
  length = hypot(delta_column, delta_row)
  length <= eps(Float64) && return nothing

  arrow_length = max(2.5 * Float64(width), 0.6 * world.patch_size)
  arrow_width = max(1.5 * Float64(width), 0.4 * world.patch_size)
  unit_column = delta_column / length
  unit_row = delta_row / length
  normal_column = -unit_row
  normal_row = unit_column
  base_column = end_column - unit_column * arrow_length
  base_row = end_row - unit_row * arrow_length
  points = [
    (end_column, end_row),
    (base_column + normal_column * arrow_width / 2.0, base_row + normal_row * arrow_width / 2.0),
    (base_column - normal_column * arrow_width / 2.0, base_row - normal_row * arrow_width / 2.0),
  ]
  paint_raster_pixels!(raster, raster_polygon_pixels(raster, points), color; erase=erase)
  nothing
end

function draw_label_at_world!(
  raster,
  world::World,
  anchor_x::Real,
  anchor_y::Real,
  value,
  color_value;
  erase::Bool=false,
  topology_wrap::Bool=false)
  text = label_display_string(value)
  isempty(text) && return nothing
  scale = label_render_scale(world)
  text_width, text_height = label_text_dimensions(text, scale)
  offsets =
    topology_wrap ?
    label_wrap_offsets(raster, world, anchor_x, anchor_y, text_width, text_height) :
    [(0.0, 0.0)]

  for (x_offset, y_offset) in offsets
    anchor_column, anchor_row = world_to_drawing_coordinates(world, anchor_x + x_offset, anchor_y + y_offset)
    draw_label_text_raster!(
      raster,
      anchor_column,
      anchor_row,
      text,
      extract_rgba_channels(color_value);
      scale=scale,
      erase=erase)
  end
  nothing
end

function draw_patch_label_raster!(raster, world::World, patch::Patch; erase::Bool=false, topology_wrap::Bool=false)
  draw_label_at_world!(
    raster,
    world,
    patch.pxcor + 0.5,
    patch.pycor - 0.5,
    patch.plabel,
    patch.plabel_color;
    erase=erase,
    topology_wrap=topology_wrap)
end

function draw_turtle_label_raster!(raster, world::World, turtle::Turtle; erase::Bool=false, topology_wrap::Bool=false)
  draw_label_at_world!(
    raster,
    world,
    turtle.xcor + 0.5 * turtle.size,
    turtle.ycor - 0.5 * turtle.size,
    turtle.label,
    turtle.label_color;
    erase=erase,
    topology_wrap=topology_wrap)
end

function draw_link_label_raster!(
  raster,
  world::World,
  link::Link,
  end1::Turtle,
  end2::Turtle;
  erase::Bool=false,
  topology_wrap::Bool=false)
  dx, dy = shortest_displacement(world, end1.xcor, end1.ycor, end2.xcor, end2.ycor)
  anchor_x = end1.xcor + dx / 2.0
  anchor_y = end1.ycor + dy / 2.0
  if link.directed
    anchor_x += dx / 4.0
    anchor_y += dy / 4.0
  end
  draw_label_at_world!(
    raster,
    world,
    anchor_x,
    anchor_y,
    link.label,
    link.label_color;
    erase=erase,
    topology_wrap=topology_wrap)
end

function render_patch_labels!(raster, world::World; topology_wrap::Bool=false)
  for patch in world.patches
    patch.alive || continue
    draw_patch_label_raster!(raster, world, patch; topology_wrap=topology_wrap)
  end
  nothing
end

function draw_turtle_raster!(
  raster,
  world::World,
  turtle::Turtle;
  erase::Bool=false,
  include_label::Bool=false,
  topology_wrap::Bool=false,
  custom_shapes::Dict{String, Any}=Dict{String, Any}())
  turtle.hidden && return nothing
  color = extract_rgba_channels(turtle.color)
  shape_name = lowercase(turtle.shape)
  if shape_name == "dot"
    column, row = world_to_drawing_coordinates(world, turtle.xcor, turtle.ycor)
    paint_raster_brush!(raster, column, row, color; width=max(0.4 * visual_turtle_diameter(world, turtle), 1.0), erase=erase)
  else
    spec = turtle_shape_spec(shape_name, custom_shapes)
    if spec === nothing || visual_turtle_diameter(world, turtle) <= 2.0
      column, row = world_to_drawing_coordinates(world, turtle.xcor, turtle.ycor)
      paint_raster_brush!(raster, column, row, color; width=visual_turtle_diameter(world, turtle), erase=erase)
    else
      draw_turtle_shape_spec!(raster, world, turtle, spec, color; erase=erase)
    end
  end
  include_label && draw_turtle_label_raster!(raster, world, turtle; erase=erase, topology_wrap=topology_wrap)
  nothing
end

function draw_link_raster!(
  raster,
  world::World,
  link::Link;
  erase::Bool=false,
  include_label::Bool=true,
  topology_wrap::Bool=false)
  link.hidden && return nothing
  end1 = maybe_turtle_by_id(world, link.end1)
  end2 = maybe_turtle_by_id(world, link.end2)
  (end1 === nothing || end2 === nothing) && return nothing
  dx, dy = shortest_displacement(world, end1.xcor, end1.ycor, end2.xcor, end2.ycor)
  color = extract_rgba_channels(link.color)
  width = visual_link_width(world, link)
  segments = wrapped_world_line_segments(world, end1.xcor, end1.ycor, end1.xcor + dx, end1.ycor + dy)
  for (segment_start_x, segment_start_y, segment_end_x, segment_end_y) in segments
    draw_raster_segment!(raster, world, segment_start_x, segment_start_y, segment_end_x, segment_end_y, color; width=width, erase=erase)
  end
  if link.directed && !isempty(segments)
    segment_start_x, segment_start_y, segment_end_x, segment_end_y = last(segments)
    draw_link_arrowhead!(raster, world, segment_start_x, segment_start_y, segment_end_x, segment_end_y, color; width=width, erase=erase)
  end
  include_label && draw_link_label_raster!(raster, world, link, end1, end2; erase=erase, topology_wrap=topology_wrap)
  nothing
end

# export-view and drawing stamps now share the same headless raster path for
# patch/link/turtle labels, directed-link arrowheads, and the growing set of
# built-in turtle shape geometries.
function render_live_view_agents!(pixels, world::World; topology_wrap::Bool=false, custom_shapes::Dict{String, Any}=Dict{String, Any}())
  for link in world.links
    link.alive || continue
    draw_link_raster!(pixels, world, link; topology_wrap=topology_wrap)
  end
  for turtle in world.turtles
    turtle.alive || continue
    draw_turtle_raster!(pixels, world, turtle; include_label=true, topology_wrap=topology_wrap, custom_shapes=custom_shapes)
  end
  nothing
end

function draw_turtle_pen_motion!(world::World, turtle::Turtle, start_x::Real, start_y::Real)
  mode = pen_draw_mode(turtle)
  mode == :none && return nothing
  dx, dy = shortest_displacement(world, start_x, start_y, turtle.xcor, turtle.ycor)
  abs(dx) <= eps(Float64) && abs(dy) <= eps(Float64) && return nothing
  draw_wrapped_drawing_line!(
    world,
    start_x,
    start_y,
    Float64(start_x) + dx,
    Float64(start_y) + dy,
    extract_rgba_channels(turtle.color);
    width=max(turtle.pen_size, 1.0),
    erase=mode == :erase)
  nothing
end

function apply_turtle_pen_motion!(world::World, old_positions::Dict{Int, NTuple{2, Float64}})
  isempty(old_positions) && return nothing
  if length(old_positions) == 1
    for (turtle_id, (old_x, old_y)) in old_positions
      turtle = maybe_turtle_by_id(world, turtle_id)
      turtle === nothing && continue
      draw_turtle_pen_motion!(world, turtle, old_x, old_y)
    end
    return nothing
  end
  for turtle_id in sort!(collect(keys(old_positions)))
    turtle = maybe_turtle_by_id(world, turtle_id)
    turtle === nothing && continue
    old_x, old_y = old_positions[turtle_id]
    draw_turtle_pen_motion!(world, turtle, old_x, old_y)
  end
  nothing
end

function set_turtle_pose_with_pen!(world::World, turtle::Turtle, x::Float64, y::Float64, heading::Real)
  ensure_live_agent(world, turtle)
  tied_ids = tied_component_ids(world, turtle.id)
  if length(tied_ids) == 1
    if pen_draw_mode(turtle) == :none
      set_turtle_pose!(world, turtle, x, y, heading)
    else
      old_x, old_y = turtle.xcor, turtle.ycor
      set_turtle_pose!(world, turtle, x, y, heading)
      draw_turtle_pen_motion!(world, turtle, old_x, old_y)
    end
    return turtle
  end

  old_positions = Dict{Int, NTuple{2, Float64}}()
  for turtle_id in tied_ids
    candidate = maybe_turtle_by_id(world, turtle_id)
    candidate === nothing && continue
    pen_draw_mode(candidate) == :none && continue
    old_positions[candidate.id] = (candidate.xcor, candidate.ycor)
  end
  set_turtle_pose!(world, turtle, x, y, heading)
  apply_turtle_pen_motion!(world, old_positions)
  turtle
end

move_turtle_to_with_pen!(world::World, turtle::Turtle, x::Float64, y::Float64) =
  set_turtle_pose_with_pen!(world, turtle, x, y, turtle.heading)

function jump_turtle_with_pen!(world::World, turtle::Turtle, distance::Real)
  ensure_live_agent(world, turtle)
  heading_radians = deg2rad(turtle.heading)
  new_x = turtle.xcor + Float64(distance) * sin(heading_radians)
  new_y = turtle.ycor + Float64(distance) * cos(heading_radians)
  move_turtle_to_with_pen!(world, turtle, new_x, new_y)
end

function move_turtle_with_pen_blocking!(world::World, turtle::Turtle, distance::Real)
  ensure_live_agent(world, turtle)
  remaining = Float64(distance)
  while abs(remaining) > 1e-12
    step = abs(remaining) <= 1.0 ? remaining : sign(remaining)
    try
      jump_turtle_with_pen!(world, turtle, step)
    catch err
      err isa LogoRuntimeError && is_topology_bounds_error(err) && return turtle
      rethrow()
    end
    remaining -= step
  end
  turtle
end

function stamp_agent!(world::World, turtle::Turtle; erase::Bool=false, custom_shapes::Dict{String, Any}=Dict{String, Any}())
  ensure_live_agent(world, turtle)
  drawing = drawing_buffer!(world; erase=erase)
  drawing === nothing && return nothing
  draw_turtle_raster!(drawing, world, turtle; erase=erase, custom_shapes=custom_shapes)
  nothing
end

function stamp_agent!(world::World, link::Link; erase::Bool=false)
  ensure_live_agent(world, link)
  drawing = drawing_buffer!(world; erase=erase)
  drawing === nothing && return nothing
  draw_link_raster!(drawing, world, link; erase=erase)
  nothing
end

function normalize_color_slot_value(value)
  if is_logo_number(value)
    return wrap_color_number(value)
  elseif value isa AbstractVector
    channels = validated_rgb_list(value; assignment=true)
    return Any[channels...]
  end
  throw(invalid_color_error())
end

extract_rgb_list(value) = Any[canonical_rgb_component(channel) for channel in extract_rgb_channels(value)]
extract_hsb_list(value) = Any[rgb_to_hsb_channels(extract_rgb_channels(value)...)...]
rgb_list(red_value, green_value, blue_value) =
  Any[Float64(rounded_rgb_channel(numeric(red_value))), Float64(rounded_rgb_channel(numeric(green_value))), Float64(rounded_rgb_channel(numeric(blue_value)))]
hsb_list(hue_value, saturation_value, brightness_value) =
  Any[Float64(rounded_rgb_channel(channel)) for channel in hsb_to_rgb_channels(hue_value, saturation_value, brightness_value)]

function all_color_samples()
  cached = COLOR_SAMPLE_CACHE[]
  cached !== nothing && return cached
  samples = [(index / 10.0, color_number_rgb(index / 10.0)) for index in 0:1399]
  COLOR_SAMPLE_CACHE[] = samples
  samples
end

function approximate_rgb_color(red_value, green_value, blue_value)
  target_red = clamp(numeric(red_value), 0.0, 255.0)
  target_green = clamp(numeric(green_value), 0.0, 255.0)
  target_blue = clamp(numeric(blue_value), 0.0, 255.0)

  best_color = 0.0
  best_distance = Inf
  for (color_value, (sample_red, sample_green, sample_blue)) in all_color_samples()
    distance =
      (sample_red - target_red)^2 +
      (sample_green - target_green)^2 +
      (sample_blue - target_blue)^2
    if distance < best_distance
      best_distance = distance
      best_color = color_value
    end
  end
  best_color
end

approximate_hsb_color(hue_value, saturation_value, brightness_value) =
  approximate_rgb_color(hsb_to_rgb_channels(hue_value, saturation_value, brightness_value)...)

function color_family_number(value)
  if is_logo_number(value)
    return wrap_color_number(value)
  elseif value isa AbstractVector
    return approximate_rgb_color(extract_rgb_channels(value)...)
  end
  throw(invalid_color_error())
end

shade_of(left_value, right_value) =
  color_family_index(color_family_number(left_value)) == color_family_index(color_family_number(right_value))

function scale_color(base_value, number_value, start_value, stop_value)
  base_color = color_family_number(base_value)
  family_start = color_family_start(base_color)
  number = numeric(number_value)
  start = numeric(start_value)
  stop = numeric(stop_value)

  shade =
    if isapprox(start, stop; atol=eps(Float64))
      number <= start ? 0.0 : 9.9999
    elseif stop > start
      clamp((number - start) / (stop - start), 0.0, 1.0) * 10.0
    else
      clamp((start - number) / (start - stop), 0.0, 1.0) * 10.0
    end
  family_start + min(shade, 9.9999)
end

function normalize_tie_mode(value)
  value isa AbstractString || throw(LogoRuntimeError("tie-mode must be one of \"none\", \"fixed\", or \"free\""))
  mode = lowercase(String(value))
  mode in ("none", "fixed", "free") || throw(LogoRuntimeError("tie-mode must be one of \"none\", \"fixed\", or \"free\""))
  mode
end

function current_patch(world::World, agent::Turtle)
  ensure_live_agent(world, agent)
  get_patch(world, round_patch_coord(agent.xcor), round_patch_coord(agent.ycor))
end

current_patch(world::World, agent::Patch) = ensure_live_agent(world, agent)

function current_scope(context::Context)
  if isempty(context.locals)
    push!(context.locals, Dict{String, Any}())
    context.string_scope_depth = max(context.string_scope_depth, 1)
  end
  context.locals[end]
end

function find_local_scope(context::Context, name::String)
  locals = context.locals
  @inbounds for i in length(locals):-1:1
    scope = locals[i]
    haskey(scope, name) && return scope
  end
  nothing
end

function task_arity_error(kind::AbstractString, expected::Int, actual::Int)
  noun = expected == 1 ? "input" : "inputs"
  LogoRuntimeError("$kind expected $expected $noun, but only got $actual")
end

stop_inside_reporter_error() = LogoRuntimeError("STOP is not allowed inside TO-REPORT.")
report_outside_reporter_error() = LogoRuntimeError("REPORT can only be used inside TO-REPORT.")
myself_context_error() = LogoRuntimeError("MYSELF is not defined in this context")

function primitive_input_bounds(syntax::PrimitiveSyntax)
  min_inputs = syntax.left == VoidType ? 0 : 1
  max_inputs = syntax.left == VoidType ? 0 : 1

  for mask in syntax.right
    if is_repeatable(mask)
      return min_inputs, nothing
    elseif is_optional(mask)
      max_inputs += 1
    else
      min_inputs += 1
      max_inputs += 1
    end
  end

  min_inputs, max_inputs
end

function task_scope(params::Vector{String}, actuals::Vector{Any}, reusable::Bool=false)
  length(actuals) >= length(params) || throw(task_arity_error("anonymous procedure", length(params), length(actuals)))
  frame = reusable ? _get_scope_dict() : Dict{String, Any}()
  for i in eachindex(params)
    frame[params[i]] = actuals[i]
  end
  frame
end

block_caller(context::Context) = context.agent isa Observer ? context.caller : context.agent

function myself_agent(context::Context)
  caller = context.caller
  caller === nothing && throw(myself_context_error())
  caller
end

function callable_binding(context::Context, name::String)
  scope = find_local_scope(context, name)
  if scope !== nothing
    return true, scope[name]
  elseif haskey(context.runtime.world.observer.globals, name)
    return true, context.runtime.world.observer.globals[name]
  end
  false, nothing
end

function resolve_callable(context::Context, name::String)
  found, value = callable_binding(context, name)
  found && return value

  reporter = get_reporter(context.runtime.registry, name)
  reporter !== nothing && return PrimitiveReporterTaskValue(reporter)

  command = get_command(context.runtime.registry, name)
  command !== nothing && return PrimitiveCommandTaskValue(command)

  procedure = get(context.runtime.model.procedures, name, nothing)
  if procedure !== nothing
    return procedure.is_reporter ? ProcedureReporterTaskValue(procedure) : ProcedureCommandTaskValue(procedure)
  end

  resolve_variable(context, name)
end

function task_value_phrase(value)
  value isa AbstractReporterTaskValue && return "an anonymous reporter"
  value isa AbstractCommandTaskValue && return "an anonymous command"
  logo_string(value)
end

exact_zero_input_reporter(::AbstractReporterTaskValue) = false

function exact_zero_input_reporter(task::PrimitiveReporterTaskValue)
  minimum_inputs, maximum_inputs = primitive_input_bounds(task.spec.syntax)
  minimum_inputs == 0 && maximum_inputs == 0
end

exact_zero_input_reporter(task::ProcedureReporterTaskValue) = isempty(task.procedure.inputs)

function coerce_reporter_task(value, opname::AbstractString=""; allow_string::Bool=false)
  value isa AbstractReporterTaskValue && return value
  allow_string && value isa AbstractString && return String(value)
  isempty(opname) && throw(LogoRuntimeError(allow_string ? "expected a string or anonymous reporter" : "expected an anonymous reporter"))
  expected = allow_string ? "a string or anonymous reporter" : "an anonymous reporter"
  throw(LogoRuntimeError("$opname expected this input to be $expected, but got $(task_value_phrase(value)) instead"))
end

function coerce_command_task(value, opname::AbstractString=""; allow_string::Bool=false)
  value isa AbstractCommandTaskValue && return value
  allow_string && value isa AbstractString && return String(value)
  isempty(opname) && throw(LogoRuntimeError(allow_string ? "expected a string or anonymous command" : "expected an anonymous command"))
  expected = allow_string ? "a string or anonymous command" : "an anonymous command"
  throw(LogoRuntimeError("$opname expected this input to be $expected, but got $(task_value_phrase(value)) instead"))
end

function get_agent_variable(agent::Observer, world::World, name::String)
  haskey(agent.globals, name) || throw(LogoRuntimeError("unknown variable $name"))
  agent.globals[name]
end

reference_descriptor(kind::String, slot::Int, name::String) = Any[kind, Float64(slot), name]

function reference_descriptor(kind::String, names::Vector{String}, name::String)
  index = findfirst(==(name), names)
  index === nothing ? nothing : reference_descriptor(kind, index - 1, name)
end

function turtle_reference_names(model::ModelSpec, breed::String)
  names = copy(TURTLE_REFERENCE_BUILTINS)
  append!(names, model.turtles_own)
  index = turtle_breed_index(model, breed)
  index === nothing || append!(names, model.breeds[index].owns)
  names
end

patch_reference_names(model::ModelSpec) = String[PATCH_REFERENCE_BUILTINS...; model.patches_own]

function link_reference_names(model::ModelSpec, breed::String)
  names = copy(LINK_REFERENCE_BUILTINS)
  append!(names, model.links_own)
  spec = link_breed_by_plural(model, breed)
  spec === nothing || append!(names, spec.owns)
  names
end

observer_reference(model::ModelSpec, name::String) = reference_descriptor("OBSERVER", model.globals, name)
turtle_reference(model::ModelSpec, breed::String, name::String) = reference_descriptor("TURTLE", turtle_reference_names(model, breed), name)
patch_reference(model::ModelSpec, name::String) = reference_descriptor("PATCH", patch_reference_names(model), name)
link_reference(model::ModelSpec, breed::String, name::String) = reference_descriptor("LINK", link_reference_names(model, breed), name)

function variable_reference(context::Context, name::String)
  model = context.runtime.model
  global_reference = observer_reference(model, name)
  global_reference !== nothing && return global_reference

  agent = context.agent
  if agent isa Turtle
    ensure_live_agent(context.runtime.world, agent)
    reference = turtle_reference(model, agent.breed, name)
    reference !== nothing && return reference
  elseif agent isa Patch
    ensure_live_agent(context.runtime.world, agent)
    reference = patch_reference(model, name)
    reference !== nothing && return reference
  elseif agent isa Link
    ensure_live_agent(context.runtime.world, agent)
    reference = link_reference(model, agent.breed, name)
    reference !== nothing && return reference
  end

  throw(undefined_name_error(name))
end

function get_agent_variable(agent::Turtle, world::World, name::String)
  ensure_live_agent(world, agent)
  if name == "WHO"
    return Float64(agent.id)
  elseif name == "COLOR"
    return agent.color
  elseif name == "HEADING"
    return agent.heading
  elseif name == "XCOR"
    return agent.xcor
  elseif name == "YCOR"
    return agent.ycor
  elseif name == "SHAPE"
    return agent.shape
  elseif name == "LABEL"
    return agent.label
  elseif name == "LABEL-COLOR"
    return agent.label_color
  elseif name == "BREED"
    return breed_agentset(world, agent.breed)
  elseif name == "HIDDEN?"
    return agent.hidden
  elseif name == "SIZE"
    return agent.size
  elseif name == "PEN-SIZE"
    return agent.pen_size
  elseif name == "PEN-MODE"
    return agent.pen_mode
  elseif haskey(agent.own, name)
    return agent.own[name]
  else
    # Turtles can access patch variables of their current patch
    patch = patch_for_position(world, agent.xcor, agent.ycor)
    if patch !== nothing
      if name in ("PXCOR", "PYCOR", "PCOLOR", "PLABEL", "PLABEL-COLOR") ||
         name in world.model.patches_own
        return get_agent_variable(patch, world, name)
      end
    end
  end
  throw(LogoRuntimeError("unknown turtle variable $name"))
end

function get_agent_variable(agent::Patch, world::World, name::String)
  ensure_live_agent(world, agent)
  if name == "PXCOR"
    return Float64(agent.pxcor)
  elseif name == "PYCOR"
    return Float64(agent.pycor)
  elseif name == "PCOLOR"
    return agent.pcolor
  elseif name == "PLABEL"
    return agent.plabel
  elseif name == "PLABEL-COLOR"
    return agent.plabel_color
  elseif haskey(agent.own, name)
    return agent.own[name]
  end
  throw(LogoRuntimeError("unknown patch variable $name"))
end

function get_agent_variable(agent::Link, world::World, name::String)
  ensure_live_agent(world, agent)
  if name == "END1"
    return turtle_by_id(world, agent.end1)
  elseif name == "END2"
    return turtle_by_id(world, agent.end2)
  elseif name == "COLOR"
    return agent.color
  elseif name == "LABEL"
    return agent.label
  elseif name == "LABEL-COLOR"
    return agent.label_color
  elseif name == "HIDDEN?"
    return agent.hidden
  elseif name == "BREED"
    return link_breed_agentset(world, agent.breed)
  elseif name == "THICKNESS"
    return agent.thickness
  elseif name == "SHAPE"
    return agent.shape
  elseif name == "TIE-MODE"
    return agent.tie_mode
  elseif haskey(agent.own, name)
    return agent.own[name]
  end
  throw(LogoRuntimeError("unknown link variable $name"))
end

function set_agent_variable!(world::World, agent::Observer, name::String, value)
  haskey(agent.globals, name) || throw(LogoRuntimeError("unknown global variable $name"))
  agent.globals[name] = value
  value
end

function set_agent_variable!(world::World, agent::Turtle, name::String, value)
  ensure_live_agent(world, agent)
  if name == "WHO"
    throw(LogoRuntimeError("$name is read-only"))
  elseif name == "BREED"
    set_turtle_breed!(world, agent, turtle_breed_name(value))
  elseif name == "COLOR"
    agent.color = normalize_color_slot_value(value)
  elseif name == "HEADING"
    set_turtle_heading!(world, agent, numeric(value))
  elseif name == "XCOR"
    move_turtle_to_with_pen!(world, agent, numeric(value), agent.ycor)
  elseif name == "YCOR"
    move_turtle_to_with_pen!(world, agent, agent.xcor, numeric(value))
  elseif name == "SHAPE"
    agent.shape = String(value)
  elseif name == "LABEL"
    agent.label = value
  elseif name == "LABEL-COLOR"
    agent.label_color = normalize_color_slot_value(value)
  elseif name == "HIDDEN?"
    agent.hidden = logical(value)
  elseif name == "SIZE"
    agent.size = numeric(value)
  elseif name == "PEN-SIZE"
    agent.pen_size = numeric(value)
  elseif name == "PEN-MODE"
    agent.pen_mode = String(value)
  else
    # Check if it's a patch variable — turtles can set their current patch's variables
    if name in ("PCOLOR", "PLABEL", "PLABEL-COLOR") ||
       name in world.model.patches_own
      patch = patch_for_position(world, agent.xcor, agent.ycor)
      if patch !== nothing
        return set_agent_variable!(world, patch, name, value)
      end
    end
    agent.own[name] = value
  end
  value
end

function set_agent_variable!(world::World, agent::Patch, name::String, value)
  ensure_live_agent(world, agent)
  if name == "PXCOR" || name == "PYCOR"
    throw(LogoRuntimeError("$name is read-only"))
  elseif name == "PCOLOR"
    agent.pcolor = normalize_color_slot_value(value)
  elseif name == "PLABEL"
    agent.plabel = value
  elseif name == "PLABEL-COLOR"
    agent.plabel_color = normalize_color_slot_value(value)
  else
    agent.own[name] = value
  end
  value
end

function set_agent_variable!(world::World, agent::Link, name::String, value)
  ensure_live_agent(world, agent)
  if name == "END1" || name == "END2" || name == "BREED"
    throw(LogoRuntimeError("$name is read-only"))
  elseif name == "COLOR"
    agent.color = normalize_color_slot_value(value)
  elseif name == "LABEL"
    agent.label = value
  elseif name == "LABEL-COLOR"
    agent.label_color = normalize_color_slot_value(value)
  elseif name == "HIDDEN?"
    agent.hidden = logical(value)
  elseif name == "THICKNESS"
    agent.thickness = numeric(value)
  elseif name == "SHAPE"
    agent.shape = String(value)
  elseif name == "TIE-MODE"
    agent.tie_mode = normalize_tie_mode(value)
  else
    agent.own[name] = value
  end
  value
end

function resolve_variable(context::Context, name::String)
  scope = find_local_scope(context, name)
  if scope !== nothing
    return scope[name]
  elseif haskey(context.runtime.world.observer.globals, name)
    return context.runtime.world.observer.globals[name]
  elseif has_turtle_breed(context.runtime.model, name)
    return breed_agentset(context.runtime.world, name)
  elseif has_link_breed(context.runtime.model, name)
    return link_breed_agentset(context.runtime.world, name)
  end
  get_agent_variable(context.agent, context.runtime.world, name)
end

function resolve_nonlocal_variable(context::Context, name::String)
  if haskey(context.runtime.world.observer.globals, name)
    return context.runtime.world.observer.globals[name]
  elseif has_turtle_breed(context.runtime.model, name)
    return breed_agentset(context.runtime.world, name)
  elseif has_link_breed(context.runtime.model, name)
    return link_breed_agentset(context.runtime.world, name)
  end
  get_agent_variable(context.agent, context.runtime.world, name)
end

function assign_variable!(context::Context, name::String, value)
  scope = find_local_scope(context, name)
  if scope !== nothing
    scope[name] = value
    return value
  elseif haskey(context.runtime.world.observer.globals, name)
    context.runtime.world.observer.globals[name] = value
    return value
  end
  set_agent_variable!(context.runtime.world, context.agent, name, value)
end

function eval_expr(context::Context, expr::NumberLiteral)
  expr.value
end

function eval_expr(context::Context, expr::StringLiteral)
  expr.value
end

function eval_expr(context::Context, expr::BoolLiteral)
  expr.value
end

function eval_expr(context::Context, expr::NobodyLiteral)
  NOBODY
end

function eval_expr(context::Context, expr::ListLiteral)
  Any[eval_expr(context, item) for item in expr.items]
end

function eval_expr(context::Context, expr::VariableRef)
  expr.search_locals ? resolve_variable(context, expr.name) : resolve_nonlocal_variable(context, expr.name)
end

function eval_expr(context::Context, expr::UnaryExpr)
  expr.op == "-" || throw(LogoRuntimeError("unsupported unary operator $(expr.op)"))
  -numeric(eval_expr(context, expr.arg))
end

eval_expr(context::Context, expr::ReporterBlockNode) =
  ReporterTaskValue(expr, copy_scope_stack(context.locals), context.runtime.model.source, expr.span, context.string_scope_depth)
eval_expr(context::Context, expr::CommandTaskNode) =
  CommandTaskValue(expr, copy_scope_stack(context.locals), context.runtime.model.source, expr.span, context.string_scope_depth)
eval_expr(context::Context, expr::CallableRefNode) = resolve_callable(context, expr.name)

function select_task_actuals(actuals::Vector{Any}, minimum_inputs::Int, maximum_inputs::Union{Nothing, Int}, kind::AbstractString)
  length(actuals) >= minimum_inputs || throw(task_arity_error(kind, minimum_inputs, length(actuals)))
  if maximum_inputs === nothing || length(actuals) <= maximum_inputs
    return actuals
  end
  Any[actuals[1:maximum_inputs]...]
end

function invoke_reporter_task(
  context::Context,
  task::ReporterTaskValue,
  actuals::Vector{Any};
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent)
  reusable_frame = task.block.reusable_frame
  frame = task_scope(task.block.params, actuals, reusable_frame)
  child_locals = acquire_scope_stack_buffer!(context.runtime, task.locals, frame)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = task.string_scope_depth
  try
    return eval_expr(context, task.block.expr)
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    release_scope_stack_buffer!(context.runtime)
    reusable_frame && _return_scope_dict!(frame)
  end
end

function invoke_reporter_task(
  context::Context,
  task::PrimitiveReporterTaskValue,
  actuals::Vector{Any};
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent)
  spec = task.spec
  agent_allowed(spec.syntax.agent_classes, agent_kind(agent)) ||
    throw(LogoRuntimeError("$(spec.name) is not allowed for the current agent"))
  minimum_inputs, maximum_inputs = primitive_input_bounds(spec.syntax)
  child_locals = acquire_scope_stack_buffer!(context.runtime, context.locals)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = saved_scope_depth
  try
    return spec.evaluator(context, select_task_actuals(actuals, minimum_inputs, maximum_inputs, "reporter task"))
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    release_scope_stack_buffer!(context.runtime)
  end
end

function invoke_reporter_task(
  context::Context,
  task::ProcedureReporterTaskValue,
  actuals::Vector{Any};
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent)
  procedure = task.procedure
  direct_expr = simple_report_expr(procedure)
  direct_stmts = direct_expr === nothing ? noscope_statements(procedure.body) : nothing
  selected = select_task_actuals(actuals, length(procedure.inputs), length(procedure.inputs), "reporter task")
  frame = task_scope(procedure.inputs, selected)
  child_locals = acquire_scope_stack_buffer!(context.runtime, EMPTY_SCOPE_STACK, frame)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  saved_every_state = context.every_state
  child_every_state = maybe_acquire_every_state!(context, procedure.body.uses_every)
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = 1
  try
    if direct_expr === nothing
      execute_block_fast!(context, procedure.body, nothing, direct_stmts, false)
    else
      return eval_expr(context, direct_expr)
    end
  catch signal
    if signal isa ReportSignal
      return signal.value
    elseif signal isa StopSignal
      throw(stop_inside_reporter_error())
    end
    rethrow()
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    restore_every_state!(context, saved_every_state, child_every_state)
    release_scope_stack_buffer!(context.runtime)
  end
  throw(LogoRuntimeError("reporter $(procedure.name) did not report a value"))
end

function invoke_command_task(
  context::Context,
  task::CommandTaskValue,
  actuals::Vector{Any};
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent)
  length(actuals) >= length(task.task.params) || throw(task_arity_error("anonymous procedure", length(task.task.params), length(actuals)))
  reusable_frame = task.task.reusable_frame
  direct_stmt = single_noscope_stmt(task.task.body)
  direct_stmts = direct_stmt === nothing ? noscope_statements(task.task.body) : nothing
  frame = task_scope(task.task.params, actuals, reusable_frame)
  child_locals = acquire_scope_stack_buffer!(context.runtime, task.locals, frame)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  saved_every_state = context.every_state
  child_every_state = maybe_acquire_every_state!(context, task.task.body.uses_every)
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = task.string_scope_depth
  try
    execute_block_fast!(context, task.task.body, direct_stmt, direct_stmts, false)
    nothing
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    restore_every_state!(context, saved_every_state, child_every_state)
    release_scope_stack_buffer!(context.runtime)
    reusable_frame && _return_scope_dict!(frame)
  end
end

function invoke_command_task(
  context::Context,
  task::PrimitiveCommandTaskValue,
  actuals::Vector{Any};
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent)
  spec = task.spec
  agent_allowed(spec.syntax.agent_classes, agent_kind(agent)) ||
    throw(LogoRuntimeError("$(spec.name) is not allowed for the current agent"))
  minimum_inputs, maximum_inputs = primitive_task_input_bounds(spec)
  child_locals = acquire_scope_stack_buffer!(context.runtime, context.locals)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = saved_scope_depth
  try
    spec.evaluator(context, select_task_actuals(actuals, minimum_inputs, maximum_inputs, "command task"))
    nothing
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    release_scope_stack_buffer!(context.runtime)
  end
end

function invoke_command_task(
  context::Context,
  task::ProcedureCommandTaskValue,
  actuals::Vector{Any};
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent)
  procedure = task.procedure
  direct_stmt = single_noscope_stmt(procedure.body)
  direct_stmts = direct_stmt === nothing ? noscope_statements(procedure.body) : nothing
  selected = select_task_actuals(actuals, length(procedure.inputs), length(procedure.inputs), "command task")
  frame = task_scope(procedure.inputs, selected)
  child_locals = acquire_scope_stack_buffer!(context.runtime, EMPTY_SCOPE_STACK, frame)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  saved_every_state = context.every_state
  child_every_state = maybe_acquire_every_state!(context, procedure.body.uses_every)
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = 1
  try
    execute_block_fast!(context, procedure.body, direct_stmt, direct_stmts, false)
  catch signal
    if signal isa StopSignal
      return nothing
    elseif signal isa ReportSignal
      throw(report_outside_reporter_error())
    end
    rethrow()
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    restore_every_state!(context, saved_every_state, child_every_state)
    release_scope_stack_buffer!(context.runtime)
  end
  nothing
end

function eval_reporter_task_arg(context::Context, arg, opname::AbstractString=""; allow_string::Bool=false)
  if arg isa ReporterBlockNode
    return ReporterTaskValue(arg, copy_scope_stack(context.locals), context.runtime.model.source, arg.span, context.string_scope_depth)
  elseif arg isa CallableRefNode
    value = resolve_callable(context, arg.name)
    if allow_string && value isa Union{PrimitiveReporterTaskValue, ProcedureReporterTaskValue} && exact_zero_input_reporter(value)
      value = invoke_reporter_task(context, value, Any[])
    end
    return coerce_reporter_task(value, opname; allow_string=allow_string)
  end
  coerce_reporter_task(eval_expr(context, arg), opname; allow_string=allow_string)
end

function eval_command_task_arg(context::Context, arg, opname::AbstractString=""; allow_string::Bool=false)
  if arg isa CommandTaskNode
    return CommandTaskValue(arg, copy_scope_stack(context.locals), context.runtime.model.source, arg.span, context.string_scope_depth)
  elseif arg isa CallableRefNode
    value = resolve_callable(context, arg.name)
    if allow_string && value isa Union{PrimitiveReporterTaskValue, ProcedureReporterTaskValue} && exact_zero_input_reporter(value)
      value = invoke_reporter_task(context, value, Any[])
    end
    return coerce_command_task(value, opname; allow_string=allow_string)
  end
  coerce_command_task(eval_expr(context, arg), opname; allow_string=allow_string)
end

const EMPTY_ACTUALS = Any[]

function eval_reporter_block(
  context::Context,
  block::ReporterBlockNode,
  agent::AbstractAgent,
  caller::Union{Nothing, AbstractAgent},
  actuals::Vector{Any}=EMPTY_ACTUALS)
  if isempty(block.params) && isempty(actuals)
    # Fast path: no params, no actuals — just switch agent context without copying locals
    if agent === context.agent && caller === context.caller
      return eval_expr(context, block.expr)
    end
    saved_agent = context.agent
    saved_caller = context.caller
    context.agent = agent
    context.caller = caller
    try
      return eval_expr(context, block.expr)
    finally
      context.agent = saved_agent
      context.caller = saved_caller
    end
  end
  reusable_frame = block.reusable_frame
  frame = task_scope(block.params, actuals, reusable_frame)
  child_locals = acquire_scope_stack_buffer!(context.runtime, context.locals, frame)
  saved_agent = context.agent
  saved_locals = context.locals
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  saved_scope_depth = context.string_scope_depth
  context.agent = agent
  context.locals = child_locals
  context.caller = caller
  context.in_ask = saved_in_ask
  context.string_scope_depth = saved_scope_depth
  try
    return eval_expr(context, block.expr)
  finally
    context.agent = saved_agent
    context.locals = saved_locals
    context.caller = saved_caller
    context.in_ask = saved_in_ask
    context.string_scope_depth = saved_scope_depth
    release_scope_stack_buffer!(context.runtime)
    reusable_frame && _return_scope_dict!(frame)
  end
end

function eval_reporter_block(
  context::Context,
  block::ReporterBlockNode;
  agent::AbstractAgent=context.agent,
  caller::Union{Nothing, AbstractAgent}=context.agent,
  actuals::Vector{Any}=EMPTY_ACTUALS)
  eval_reporter_block(context, block, agent, caller, actuals)
end

primitive_modes(spec::PrimitiveSpec) = spec.modes

function primitive_task_input_bounds(spec::PrimitiveSpec)
  min_inputs = spec.syntax.left == VoidType ? 0 : 1
  max_inputs = spec.syntax.left == VoidType ? 0 : 1
  modes = spec.modes
  offset = spec.syntax.left == VoidType ? 0 : 1

  for (index, mask) in enumerate(spec.syntax.right)
    mode = modes[index + offset]
    if is_optional(mask) && mode in (:block, :reporter_block)
      continue
    elseif is_repeatable(mask)
      return min_inputs, nothing
    elseif is_optional(mask)
      max_inputs += 1
    else
      min_inputs += 1
      max_inputs += 1
    end
  end

  min_inputs, max_inputs
end

every_agent_key(::Observer) = (:observer, 0)
every_agent_key(agent::Turtle) = (:turtle, agent.id)
every_agent_key(agent::Patch) = (:patch, agent.pxcor, agent.pycor)
every_agent_key(agent::Link) = (:link, agent.id)

function every_interval_ns(value)
  seconds = numeric(value)
  seconds >= 0 || throw(LogoRuntimeError("every expects a non-negative interval"))
  UInt64(round(seconds * 1.0e9))
end

function execute_every!(context::Context, stmt::CommandCall)
  length(stmt.args) == 2 || throw(LogoRuntimeError("every expected 2 arguments"))
  interval_ns = every_interval_ns(eval_expr(context, stmt.args[1]))
  block = stmt.args[2]
  block isa BlockNode || throw(LogoRuntimeError("every expected a command block"))
  key = (stmt.span.start, every_agent_key(context.agent))
  now_ns = time_ns()
  last_run_ns = get(context.every_state, key, nothing)
  if last_run_ns === nothing || now_ns - last_run_ns >= interval_ns
    context.every_state[key] = now_ns
    execute_block!(context, block)
  end
  nothing
end

@inline function acquire_prepared_args!(runtime::RuntimeState, nargs::Int)
  depth_ref = runtime.prepared_arg_depth
  depth_ref[] += 1
  depth = depth_ref[]
  buffers = runtime.prepared_arg_buffers
  if depth > length(buffers)
    push!(buffers, Any[])
  end
  prepared = buffers[depth]
  resize!(prepared, nargs)
  prepared
end

@inline function release_prepared_args!(runtime::RuntimeState)
  runtime.prepared_arg_depth[] -= 1
  nothing
end

@inline function acquire_agent_iteration_buffer!(
  runtime::RuntimeState,
  agents::AbstractVector{<:AbstractAgent})
  depth = runtime.agent_iteration_depth[] + 1
  runtime.agent_iteration_depth[] = depth
  buffers = runtime.agent_iteration_buffers
  if depth > length(buffers)
    push!(buffers, AbstractAgent[])
  end
  prepared = buffers[depth]
  resize!(prepared, length(agents))
  @inbounds for i in eachindex(agents)
    prepared[i] = agents[i]
  end
  prepared
end

@inline function release_agent_iteration_buffer!(runtime::RuntimeState)
  runtime.agent_iteration_depth[] -= 1
  nothing
end

@inline function acquire_scope_stack_buffer!(
  runtime::RuntimeState,
  scopes::Vector{Dict{String, Any}},
  frame::Union{Nothing, Dict{String, Any}}=nothing)
  depth = runtime.scope_stack_depth[] + 1
  runtime.scope_stack_depth[] = depth
  buffers = runtime.scope_stack_buffers
  if depth > length(buffers)
    push!(buffers, Dict{String, Any}[])
  end
  prepared = buffers[depth]
  count = length(scopes)
  extra = frame === nothing ? 0 : 1
  resize!(prepared, count + extra)
  count > 0 && copyto!(prepared, 1, scopes, 1, count)
  frame === nothing || (prepared[count + 1] = frame)
  prepared
end

@inline function release_scope_stack_buffer!(runtime::RuntimeState)
  runtime.scope_stack_depth[] -= 1
  nothing
end

@inline function prepare_eval_args!(prepared::Vector{Any}, context::Context, args::Vector{Any})
  @inbounds for i in eachindex(args)
    prepared[i] = eval_expr(context, args[i])
  end
  prepared
end

function prepare_args!(prepared::Vector{Any}, context::Context, spec::PrimitiveSpec, args::Vector{Any})
  nargs = length(args)
  modes = spec.modes
  nmodes = length(modes)

  if spec.all_eval_modes
    @inbounds for i in 1:nargs
      prepared[i] = eval_expr(context, args[i])
    end
    return prepared
  end

  @inbounds for i in 1:nargs
    arg = args[i]
    mode = i <= nmodes ? modes[i] : :eval
    if mode == :eval
      if arg isa BlockNode
        # BlockNode ended up in :eval position due to optional arg skipping
        prepared[i] = arg
      else
        prepared[i] = eval_expr(context, arg)
      end
    elseif mode == :block || mode == :code_block
      prepared[i] = arg
    elseif mode == :reporter_block
      arg isa ReporterBlockNode || throw(LogoRuntimeError("expected a reporter block"))
      prepared[i] = arg
    elseif mode == :reporter_task
      prepared[i] = eval_reporter_task_arg(context, arg, spec.name; allow_string=spec.name == "RUNRESULT" || spec.name == "RUN-RESULT")
    elseif mode == :command_task
      prepared[i] = eval_command_task_arg(context, arg, spec.name; allow_string=spec.name == "RUN")
    elseif mode == :symbol
      arg isa SymbolArg || throw(LogoRuntimeError("expected a symbolic argument"))
      prepared[i] = arg.name
    else
      prepared[i] = arg
    end
  end
  prepared
end

function eval_boolean_reporter(context::Context, call::ReporterCall)
  if call.name == "NOT"
    return !logical(eval_expr(context, call.args[1]))
  elseif call.name == "AND"
    left = logical(eval_expr(context, call.args[1]))
    left || return false
    return logical(eval_expr(context, call.args[2]))
  elseif call.name == "OR"
    left = logical(eval_expr(context, call.args[1]))
    left && return true
    return logical(eval_expr(context, call.args[2]))
  elseif call.name == "XOR"
    left = logical(eval_expr(context, call.args[1]))
    right = logical(eval_expr(context, call.args[2]))
    return left != right
  end
  throw(LogoRuntimeError("unknown boolean reporter $(call.name)"))
end

function eval_comparison_reporter(context::Context, call::ReporterCall)
  left = eval_expr(context, call.args[1])
  right = eval_expr(context, call.args[2])
  if call.name == "="
    return logo_equal(left, right)
  elseif call.name == "!="
    return !logo_equal(left, right)
  end
  ordering = logo_compare(context.runtime.model, left, right, call.name)
  if call.name == ">"
    return ordering > 0
  elseif call.name == "<"
    return ordering < 0
  elseif call.name == ">="
    return ordering >= 0
  elseif call.name == "<="
    return ordering <= 0
  end
  throw(LogoRuntimeError("unknown comparison reporter $(call.name)"))
end

function call_reporter!(context::Context, call::ReporterCall)
  # Fast path: already-resolved primitive (skips all string comparisons)
  cached = call.cached_prim
  if cached !== nothing
    spec = cached::PrimitiveSpec
    prepared = acquire_prepared_args!(context.runtime, length(call.args))
    try
      prepare_args!(prepared, context, spec, call.args)
      return spec.evaluator(context, prepared)
    finally
      release_prepared_args!(context.runtime)
    end
  end

  # Special-case reporters needing lazy/compound evaluation
  if call.name == "IFELSE-VALUE"
    return ifelse_value(context, call.args)
  elseif call.name == "NOT" || call.name == "AND" || call.name == "OR" || call.name == "XOR"
    return eval_boolean_reporter(context, call)
  elseif call.name == "=" || call.name == "!=" || call.name == ">" || call.name == "<" || call.name == ">=" || call.name == "<="
    return eval_comparison_reporter(context, call)
  elseif call.name == "COUNT"
    value = count_with_fastpath(context, call)
    value !== nothing && return value
    value = count_on_fastpath(context, call)
    value !== nothing && return value
  elseif call.name == "ANY?"
    value = any_turtles_here_fastpath(context, call)
    value !== nothing && return value
    value = any_with_fastpath(context, call)
    value !== nothing && return value
  elseif call.name == "ONE-OF"
    value = one_of_with_fastpath(context, call)
    value !== nothing && return value
  elseif call.name == "SUM"
    value = sum_of_fastpath(context, call)
    value !== nothing && return value
  elseif call.name == "MEAN"
    value = mean_of_fastpath(context, call)
    value !== nothing && return value
  end

  spec = get_reporter(context.runtime.registry, call.name)
  if spec !== nothing
    call.cached_prim = spec
    agent_allowed(spec.syntax.agent_classes, agent_kind(context.agent)) ||
      throw(LogoRuntimeError("$(call.name) is not allowed for the current agent"))
    prepared = acquire_prepared_args!(context.runtime, length(call.args))
    try
      prepare_args!(prepared, context, spec, call.args)
      return spec.evaluator(context, prepared)
    finally
      release_prepared_args!(context.runtime)
    end
  end

  procedure = get(context.runtime.model.procedures, call.name, nothing)
  procedure !== nothing && procedure.is_reporter || throw(LogoRuntimeError("unknown reporter $(call.name)"))
  prepared = acquire_prepared_args!(context.runtime, length(call.args))
  try
    prepare_eval_args!(prepared, context, call.args)
    return invoke_procedure!(context, procedure, prepared)
  finally
    release_prepared_args!(context.runtime)
  end
end

eval_expr(context::Context, expr::ReporterCall) = call_reporter!(context, expr)

@inline function symbol_arg_name(arg)
  arg isa SymbolArg || throw(LogoRuntimeError("expected a symbolic argument"))
  arg.name
end

@inline function command_block_arg(arg)
  arg isa BlockNode || throw(LogoRuntimeError("expected a command block"))
  arg
end

@inline function reporter_block_arg(arg)
  arg isa ReporterBlockNode || throw(LogoRuntimeError("expected a reporter block"))
  arg
end

function execute_stmt!(context::Context, stmt::CommandCall)
  # Fast path: already-resolved primitive command (skips all string comparisons)
  cached = stmt.cached_prim
  if cached !== nothing
    spec = cached::PrimitiveSpec
    prepared = acquire_prepared_args!(context.runtime, length(stmt.args))
    try
      prepare_args!(prepared, context, spec, stmt.args)
      spec.evaluator(context, prepared)
    finally
      release_prepared_args!(context.runtime)
    end
    return nothing
  end

  if stmt.name == "FOREACH"
    length(stmt.args) >= 2 || throw(LogoRuntimeError("foreach expects at least one list and an anonymous command"))
    values = Any[eval_expr(context, arg) for arg in stmt.args[1:(end - 1)]]
    task = eval_command_task_arg(context, stmt.args[end], stmt.name)
    foreach_values!(context, task, values...)
    return nothing
  elseif stmt.name == "EVERY"
    return execute_every!(context, stmt)
  elseif stmt.name == "LET"
    name = symbol_arg_name(stmt.args[1])
    scope = current_scope(context)
    haskey(scope, name) && throw(LogoRuntimeError("There is already a local variable here called $(name)"))
    scope[name] = eval_expr(context, stmt.args[2])
    return nothing
  elseif stmt.name == "SET"
    assign_variable!(context, symbol_arg_name(stmt.args[1]), eval_expr(context, stmt.args[2]))
    return nothing
  elseif stmt.name == "IF"
    logical(eval_expr(context, stmt.args[1])) && execute_block!(context, command_block_arg(stmt.args[2]))
    return nothing
  elseif stmt.name == "IFELSE"
    execute_block!(context, logical(eval_expr(context, stmt.args[1])) ? command_block_arg(stmt.args[2]) : command_block_arg(stmt.args[3]))
    return nothing
  elseif stmt.name == "REPEAT"
    count = Int(floor(numeric(eval_expr(context, stmt.args[1]))))
    count >= 0 || throw(LogoRuntimeError("repeat expects a non-negative count"))
    block = command_block_arg(stmt.args[2])
    for _ in 1:count
      execute_block!(context, block)
    end
    return nothing
  elseif stmt.name == "ASK"
    target = eval_expr(context, stmt.args[1])
    block = command_block_arg(stmt.args[2])
    if target isa AbstractAgent
      run_block_for_agents!(context, target, block, true)
    else
      run_block_for_agents!(context, coerce_agents(context.runtime.world, target), block, true)
    end
    return nothing
  elseif stmt.name == "ASK-CONCURRENT"
    run_block_for_agents!(context, require_agentset_input(context.runtime.world, eval_expr(context, stmt.args[1]), "ASK-CONCURRENT"), command_block_arg(stmt.args[2]), true)
    return nothing
  elseif stmt.name == "WHILE"
    condition = reporter_block_arg(stmt.args[1])
    body = command_block_arg(stmt.args[2])
    while logical(eval_reporter_block(context, condition, context.agent, context.caller))
      execute_block!(context, body)
    end
    return nothing
  end

  spec = get_command(context.runtime.registry, stmt.name)
  if spec !== nothing
    stmt.cached_prim = spec
    agent_allowed(spec.syntax.agent_classes, agent_kind(context.agent)) ||
      throw(LogoRuntimeError("$(stmt.name) is not allowed for the current agent"))
    prepared = acquire_prepared_args!(context.runtime, length(stmt.args))
    try
      prepare_args!(prepared, context, spec, stmt.args)
      spec.evaluator(context, prepared)
    finally
      release_prepared_args!(context.runtime)
    end
    return nothing
  end

  procedure = get(context.runtime.model.procedures, stmt.name, nothing)
  procedure !== nothing && !procedure.is_reporter || throw(LogoRuntimeError("unknown command $(stmt.name)"))
  prepared = acquire_prepared_args!(context.runtime, length(stmt.args))
  try
    prepare_eval_args!(prepared, context, stmt.args)
    invoke_procedure!(context, procedure, prepared)
  finally
    release_prepared_args!(context.runtime)
  end
  nothing
end

function execute_block!(context::Context, block::BlockNode, push_scope::Bool)
  use_scope = push_scope && block.creates_scope
  reusable_scope = use_scope && block.reusable_scope
  d = nothing
  statements = block.statements
  count = length(statements)
  if count == 0
    return nothing
  elseif !use_scope
    return execute_noscope_block!(context, statements)
  end
  agent_is_live(context.agent) || return nothing
  if use_scope
    d = reusable_scope ? _get_scope_dict() : Dict{String, Any}()
    push!(context.locals, d)
  end
  try
    @inbounds begin
      execute_stmt!(context, statements[1])
      for index in 2:count
        agent_is_live(context.agent) || break
        execute_stmt!(context, statements[index])
      end
    end
  finally
    if use_scope
      pop!(context.locals)
      reusable_scope && _return_scope_dict!(d::Dict{String, Any})
    end
  end
  nothing
end

execute_block!(context::Context, block::BlockNode) = execute_block!(context, block, true)

@inline function execute_noscope_block!(context::Context, statements::Vector{AbstractStmt})
  count = length(statements)
  count == 0 && return nothing
  agent_is_live(context.agent) || return nothing
  @inbounds begin
    execute_stmt!(context, statements[1])
    for index in 2:count
      agent_is_live(context.agent) || return nothing
      execute_stmt!(context, statements[index])
    end
  end
  nothing
end

@inline function single_noscope_stmt(block::BlockNode)
  block.creates_scope && return nothing
  length(block.statements) == 1 || return nothing
  block.statements[1]::CommandCall
end

@inline function noscope_statements(block::BlockNode)
  block.creates_scope && return nothing
  length(block.statements) > 1 || return nothing
  block.statements
end

@inline function execute_block_fast!(
  context::Context,
  block::BlockNode,
  direct_stmt::Union{Nothing, CommandCall},
  direct_stmts::Union{Nothing, Vector{AbstractStmt}},
  push_scope::Bool)
  if direct_stmt !== nothing
    execute_stmt!(context, direct_stmt)
  elseif direct_stmts !== nothing
    execute_noscope_block!(context, direct_stmts)
  else
    execute_block!(context, block, push_scope)
  end
end

@inline function simple_report_expr(procedure::ProcedureSpec)
  length(procedure.body.statements) == 1 || return nothing
  stmt = procedure.body.statements[1]
  stmt isa CommandCall || return nothing
  stmt.name == "REPORT" || return nothing
  length(stmt.args) == 1 || return nothing
  stmt.args[1]
end

@inline function restore_procedure_context!(
  context::Context,
  saved_locals::Vector{Dict{String, Any}},
  saved_scope_depth::Int,
  saved_every_state::Dict{Tuple{Int, Any}, UInt64},
  child_every_state::Union{Nothing, Dict{Tuple{Int, Any}, UInt64}},
  frame::Dict{String, Any},
  reusable_frame::Bool)
  context.locals = saved_locals
  context.string_scope_depth = saved_scope_depth
  restore_every_state!(context, saved_every_state, child_every_state)
  release_scope_stack_buffer!(context.runtime)
  reusable_frame && _return_scope_dict!(frame)
  nothing
end

@inline function restore_procedure_context!(
  context::Context,
  saved_locals::Vector{Dict{String, Any}},
  saved_scope_depth::Int,
  saved_every_state::Dict{Tuple{Int, Any}, UInt64},
  child_every_state::Union{Nothing, Dict{Tuple{Int, Any}, UInt64}})
  current_locals = context.locals
  context.locals = saved_locals
  context.string_scope_depth = saved_scope_depth
  restore_every_state!(context, saved_every_state, child_every_state)
  resize!(current_locals, 0)
  release_scope_stack_buffer!(context.runtime)
  nothing
end

@inline procedure_needs_frame(procedure::ProcedureSpec) =
  !isempty(procedure.inputs) || procedure.body.creates_scope || !procedure.reusable_frame

function invoke_procedure!(context::Context, procedure::ProcedureSpec, args::Vector{Any})
  length(args) == length(procedure.inputs) ||
    throw(LogoRuntimeError("procedure $(procedure.name) expected $(length(procedure.inputs)) arguments"))

  # Save context state and reuse the same context to avoid Context allocation
  saved_locals = context.locals
  saved_scope_depth = context.string_scope_depth
  saved_every_state = context.every_state
  child_every_state = maybe_acquire_every_state!(context, procedure.body.uses_every)
  needs_frame = procedure_needs_frame(procedure)
  reusable_frame = procedure.reusable_frame
  direct_stmt = procedure.is_reporter ? nothing : single_noscope_stmt(procedure.body)
  direct_stmts = direct_stmt === nothing ? noscope_statements(procedure.body) : nothing
  if needs_frame
    frame = task_scope(procedure.inputs, args, reusable_frame)
    context.locals = acquire_scope_stack_buffer!(context.runtime, EMPTY_SCOPE_STACK, frame)
    context.string_scope_depth = 1
  else
    frame = nothing
    context.locals = acquire_scope_stack_buffer!(context.runtime, EMPTY_SCOPE_STACK)
    context.string_scope_depth = 0
  end

  if procedure.is_reporter
    direct_expr = simple_report_expr(procedure)
    if direct_expr !== nothing
      try
        value = eval_expr(context, direct_expr)
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        return value
      catch signal
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        if signal isa StopSignal
          throw(stop_inside_reporter_error())
        elseif signal isa ReportSignal
          return signal.value
        end
        rethrow()
      end
    end
    try
      execute_block_fast!(context, procedure.body, nothing, direct_stmts, false)
    catch signal
      if signal isa ReportSignal
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        return signal.value
      elseif signal isa StopSignal
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        throw(stop_inside_reporter_error())
      else
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        rethrow()
      end
    end
    if needs_frame
      restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
    else
      restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
    end
    throw(LogoRuntimeError("the $(procedure.name) procedure failed to report a result"))
  else
    try
      execute_block_fast!(context, procedure.body, direct_stmt, direct_stmts, false)
    catch signal
      if signal isa StopSignal
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        return :stop
      elseif signal isa ReportSignal
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        throw(report_outside_reporter_error())
      else
        if needs_frame
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
        else
          restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
        end
        rethrow()
      end
    end
    if needs_frame
      restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state, frame::Dict{String, Any}, reusable_frame)
    else
      restore_procedure_context!(context, saved_locals, saved_scope_depth, saved_every_state, child_every_state)
    end
    return nothing
  end
end

function call!(runtime::RuntimeState, procedure_name::AbstractString, args::Vector{Any})
  name = canonical_name(procedure_name)
  procedure = get(runtime.model.procedures, name, nothing)
  procedure !== nothing || throw(LogoRuntimeError("unknown procedure $procedure_name"))
  root_every_state = procedure.body.uses_every ? _get_every_state_dict() : EMPTY_EVERY_STATE
  root = Context(runtime, runtime.world.observer, EMPTY_SCOPE_STACK, nothing, false, 1, root_every_state)
  result = nothing
  try
    result = invoke_procedure!(root, procedure, args)
  finally
    root_every_state === EMPTY_EVERY_STATE || _return_every_state_dict!(root_every_state)
  end
  # Reporters return their value; commands return whether stop was called
  procedure.is_reporter ? result : (result === :stop)
end

turtle_singular_name(model::ModelSpec, breed::String) =
  breed == "TURTLES" ? "turtle" :
  let index = turtle_breed_index(model, breed)
    index === nothing ? "turtle" : lowercase(model.breeds[index].singular)
  end

link_singular_name(model::ModelSpec, breed::String) =
  breed == "LINKS" ? "link" :
  let spec = link_breed_by_plural(model, breed)
    spec === nothing ? "link" : lowercase(spec.singular)
  end

dead_agent_message(::World, ::Patch) = "That patch is dead."
dead_agent_message(world::World, agent::Turtle) = "That $(turtle_singular_name(world.model, agent.breed)) is dead."
dead_agent_message(world::World, agent::Link) = "That $(link_singular_name(world.model, agent.breed)) is dead."

ensure_live_agent(::World, agent::Observer) = agent

function ensure_live_agent(world::World, agent::Patch)
  agent.alive || throw(LogoRuntimeError(dead_agent_message(world, agent)))
  agent
end

function ensure_live_agent(world::World, agent::Turtle)
  agent.alive || throw(LogoRuntimeError(dead_agent_message(world, agent)))
  agent
end

function ensure_live_agent(world::World, agent::Link)
  agent.alive || throw(LogoRuntimeError(dead_agent_message(world, agent)))
  agent
end

function live_agentset_members(agentset::AgentSet)
  members = current_agentset_members(agentset)
  agentset.all_live && return members
  live = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  for agent in members
    agent_is_live(agent) && push!(live, agent)
  end
  live
end

function coerce_agents(world::World, value)
  if value isa AgentSet
    return live_agentset_members(value)
  elseif value isa AbstractAgent
    return AbstractAgent[ensure_live_agent(world, value)]
  end
  throw(LogoRuntimeError("expected an agent or agentset"))
end

function require_agentset_input(world::World, value, opname::AbstractString)
  if value isa AgentSet
    return live_agentset_members(value)
  elseif value isa AbstractAgent
    ensure_live_agent(world, value)
    throw(LogoRuntimeError("$opname expected input to be an agentset but got the $(agent_type_name(value)) $(logo_string(value)) instead."))
  end
  throw(LogoRuntimeError("$opname expected input to be an agentset but got $(logo_string(value)) instead."))
end

same_agent(a::Observer, b::Observer) = true
same_agent(a::Turtle, b::Turtle) = a.id == b.id
same_agent(a::Patch, b::Patch) = a.alive && b.alive && a.pxcor == b.pxcor && a.pycor == b.pycor
same_agent(a::Link, b::Link) = a.id == b.id
same_agent(::AbstractAgent, ::AbstractAgent) = false

logo_equal(::NobodyValue, ::NobodyValue) = true
logo_equal(a::AbstractAgent, b::AbstractAgent) = same_agent(a, b)

function logo_equal(a::AgentSet, b::AgentSet)
  left = live_agentset_members(a)
  right = live_agentset_members(b)
  a.kind == b.kind || return false
  length(left) == length(right) || return false
  all(member -> any(other -> same_agent(member, other), right), left)
end

function logo_equal(a::AbstractVector, b::AbstractVector)
  length(a) == length(b) || return false
  all(logo_equal(left, right) for (left, right) in zip(a, b))
end

logo_equal(a, b) = a == b

comparison_label(::Bool) = "true/false value"
comparison_label(value::Real) = "number"
comparison_label(value::AbstractString) = "string"
comparison_label(::NobodyValue) = "nobody"
comparison_label(::Observer) = "observer"
comparison_label(::Turtle) = "turtle"
comparison_label(::Patch) = "patch"
comparison_label(::Link) = "link"
comparison_label(::AgentSet) = "agentset"
comparison_label(::AbstractVector) = "list"
comparison_label(value) = string(typeof(value))

comparison_phrase(value) = value === NOBODY ? "nobody" : "a $(comparison_label(value))"

function comparison_error(opname::AbstractString, left, right)
  LogoRuntimeError("The $opname operator can only be used on two numbers, two strings, or two agents of the same type, but not on $(comparison_phrase(left)) and $(comparison_phrase(right)).")
end

ordering_compare(left, right) = left == right ? 0 : (left < right ? -1 : 1)

link_breed_rank(model::ModelSpec, breed::AbstractString) =
  canonical_name(breed) == "LINKS" ? 0 : something(link_breed_index(model, canonical_name(breed)), length(model.link_breeds) + 1)

agent_sort_key(::ModelSpec, ::Observer) = (0,)
agent_sort_key(::ModelSpec, agent::Turtle) = (1, agent.id)
agent_sort_key(::ModelSpec, agent::Patch) = (2, -agent.pycor, agent.pxcor)

function agent_sort_key(model::ModelSpec, agent::Link)
  breed_rank = link_breed_rank(model, agent.breed)
  if agent.directed
    return (3, breed_rank, 0, agent.end1, agent.end2, agent.id)
  end
  return (3, breed_rank, 1, min(agent.end1, agent.end2), max(agent.end1, agent.end2), agent.id)
end

function logo_compare(model::ModelSpec, left, right, opname::AbstractString)
  if is_logo_number(left) && is_logo_number(right)
    return ordering_compare(Float64(left), Float64(right))
  elseif left isa AbstractString && right isa AbstractString
    return ordering_compare(String(left), String(right))
  elseif left isa AbstractAgent && right isa AbstractAgent && agent_kind(left) == agent_kind(right)
    return ordering_compare(agent_sort_key(model, left), agent_sort_key(model, right))
  end
  throw(comparison_error(opname, left, right))
end

agentset_member_name(kind::AgentKind) =
  kind == TurtleKind ? "turtle" :
  kind == PatchKind ? "patch" :
  "link"

agentset_plural_name(kind::AgentKind) =
  kind == TurtleKind ? "turtles" :
  kind == PatchKind ? "patches" :
  "links"

generic_agentset_breed(kind::AgentKind) =
  kind == TurtleKind ? "TURTLES" :
  kind == LinkKind ? "LINKS" :
  nothing

empty_agentset(kind::AgentKind) =
  AgentSet(kind, AbstractAgent[]; breed=generic_agentset_breed(kind))

function agentset_builder_error(opname::AbstractString, kind::AgentKind, value; from_list::Bool=false)
  member_name = agentset_member_name(kind)
  set_name = "$member_name agentset"
  if from_list
    throw(LogoRuntimeError("List inputs to $opname must only contain $member_name, $set_name, or list elements, but got $(logo_string(value))."))
  end
  throw(LogoRuntimeError("$opname expected input to be a $set_name or $member_name but got $(logo_string(value)) instead."))
end

function collect_agentset_members!(
  seen::Dict{Any, AbstractAgent},
  model::ModelSpec,
  kind::AgentKind,
  value,
  opname::AbstractString;
  from_list::Bool=false)
  if value === NOBODY
    return
  elseif value isa AbstractVector
    for item in value
      collect_agentset_members!(seen, model, kind, item, opname; from_list=true)
    end
    return
  elseif value isa AgentSet
    value.kind == kind || agentset_builder_error(opname, kind, value; from_list=from_list)
    @for_agents agent value begin
      seen[agent_sort_key(model, agent)] = agent
    end
    return
  elseif value isa AbstractAgent
    agent_is_live(value) || return
    agent_kind(value) == kind || agentset_builder_error(opname, kind, value; from_list=from_list)
    seen[agent_sort_key(model, value)] = value
    return
  end
  agentset_builder_error(opname, kind, value; from_list=from_list)
end

function built_agentset_breed(kind::AgentKind, members::Vector{AbstractAgent})
  generic = generic_agentset_breed(kind)
  kind == PatchKind && return nothing
  isempty(members) && return generic

  breeds = Set{String}()
  for member in members
    if member isa Turtle
      push!(breeds, member.breed)
    elseif member isa Link
      push!(breeds, member.breed)
    end
  end
  length(breeds) == 1 ? first(breeds) : generic
end

function build_agentset(opname::AbstractString, model::ModelSpec, kind::AgentKind, values...)
  seen = Dict{Any, AbstractAgent}()
  for value in values
    collect_agentset_members!(seen, model, kind, value, opname)
  end

  members = sort_agents(model, collect(Base.values(seen)))
  owned_agentset(kind, members; breed=built_agentset_breed(kind, members))
end

function coerce_turtles(world::World, value)
  turtles = Turtle[]
  for agent in coerce_agents(world, value)
    agent isa Turtle || throw(LogoRuntimeError("expected turtle targets"))
    push!(turtles, agent)
  end
  turtles
end

function coerce_turtle_collection(world::World, value, opname::AbstractString; shuffle_agentset::Bool=false)
  turtles = Turtle[]
  if value isa AgentSet
    value.kind == TurtleKind || throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle, list of turtles, or turtle agentset"))
    for agent in live_agentset_members(value)
      push!(turtles, agent::Turtle)
    end
    shuffle_agentset && shuffle!(world.rng, turtles)
    return turtles
  elseif value isa Turtle
    return Turtle[ensure_live_agent(world, value)]
  elseif value isa AbstractVector
    for item in value
      item isa Turtle || throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle, list of turtles, or turtle agentset"))
      push!(turtles, ensure_live_agent(world, item)::Turtle)
    end
    return turtles
  end
  throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle, list of turtles, or turtle agentset"))
end

function other_agents(agentset::AgentSet, current::AbstractAgent)
  agentset.kind == agent_kind(current) || return agentset
  if current isa Turtle && agentset.kind == TurtleKind
    breed = agentset.breed
    if breed !== nothing && breed != "TURTLES" && current.breed != breed
      return agentset
    end
  elseif current isa Link && agentset.kind == LinkKind
    breed = agentset.breed
    if breed !== nothing && breed != "LINKS" && current.breed != breed
      return agentset
    end
  end

  members = sizehint!(AbstractAgent[], max(agentset_capacity(agentset) - 1, 0))
  removed = false
  @for_agents agent agentset begin
    if same_agent(agent, current)
      removed = true
    else
      push!(members, agent)
    end
  end
  removed ? owned_agentset(agentset.kind, members; breed=agentset.breed) : agentset
end

function who_are_not(agentset::AgentSet, excluded::AgentSet)
  blocked = live_agentset_members(excluded)
  members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  @for_agents agent agentset begin
    !any(other -> same_agent(agent, other), blocked) && push!(members, agent)
  end
  owned_agentset(agentset.kind, members; breed=agentset.breed)
end

function who_are_not(agentset::AgentSet, excluded::AbstractAgent)
  members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  @for_agents agent agentset begin
    !same_agent(agent, excluded) && push!(members, agent)
  end
  owned_agentset(agentset.kind, members; breed=agentset.breed)
end

function create_links_from_turtle!(
  context::Context,
  breed::String,
  mode::Symbol,
  target_value,
  block::Union{Nothing, BlockNode}=nothing)
  parent = context.agent isa Turtle ? context.agent : throw(LogoRuntimeError("link creation is only available to turtles"))
  created = AbstractAgent[]

  for target in coerce_turtles(context.runtime.world, target_value)
    same_agent(parent, target) && continue
    src, dst =
      (mode == :to || mode == :out) ? (parent, target) :
      (mode == :from || mode == :in) ? (target, parent) :
      (parent, target)
    link = create_link!(context.runtime.world, src, dst; breed=breed, directed=(canonical_name(breed) == "LINKS" ? (mode != :with && mode != :all) : nothing))
    link === nothing && continue
    push!(created, link)
  end

  block !== nothing && run_block_for_agents!(context, created, block, true)

  created
end

link_mode_symbol(name::String) =
  name == "IN" ? :in :
  name == "OUT" ? :out :
  :all

function one_of(rng::AbstractRNG, value)
  if value isa AgentSet
    # Fast path for dynamic special agentsets with known backing arrays
    if value.dynamic && value.world isa World
      world = value.world::World
      if value.kind == PatchKind && (value.breed === nothing || value.breed == "")
        patches = world.patches
        isempty(patches) && return NOBODY
        return @inbounds patches[rand(rng, 1:length(patches))]
      elseif value.kind == TurtleKind && (value.breed === nothing || value.breed == "TURTLES")
        turtles = world.turtles
        isempty(turtles) && return NOBODY
        # Rejection sampling (faster than reservoir when most turtles alive)
        max_tries = length(turtles) * 3
        for _ in 1:max_tries
          t = @inbounds turtles[rand(rng, 1:length(turtles))]
          t.alive && return t
        end
        # Fallback to reservoir if too many dead
      end
    end
    # Fast path for static owned agentsets where all members are live
    if !value.dynamic && value.all_live
      m = value.members
      isempty(m) && return NOBODY
      return @inbounds m[rand(rng, 1:length(m))]
    end
    # Fallback: reservoir sampling (k=1), zero allocation
    chosen = NOBODY
    n = 0
    @for_agents agent value begin
      n += 1
      if rand(rng, 1:n) == 1
        chosen = agent
      end
    end
    return chosen
  elseif value isa AbstractVector
    isempty(value) && throw(LogoRuntimeError("ONE-OF got an empty list as input."))
    return @inbounds value[rand(rng, eachindex(value))]
  elseif value isa AbstractString
    isempty(value) && throw(LogoRuntimeError("ONE-OF got an empty string as input."))
    return string(value[rand(rng, eachindex(value))])
  end
  throw(LogoRuntimeError("one-of expects an agentset, list, or string"))
end

function collection_length(value)
  if value isa AbstractVector || value isa AbstractString
    return Float64(length(value))
  end
  throw(LogoRuntimeError("length expects a list or string"))
end

collection_index(index_value) = Int(floor(numeric(index_value)))

function ensure_nonnegative_collection_index!(index::Int)
  index >= 0 || throw(LogoRuntimeError("$(index) isn't greater than or equal to zero."))
  index
end

function collection_not_found_error(index::Int, value, length_value::Int)
  if value isa AbstractVector
    return LogoRuntimeError(
      "Can't find element $(index) of the list $(error_readable_logo_string(value)), which is only of length $(length_value).")
  elseif value isa AbstractString
    return LogoRuntimeError(
      "Can't find element $(index) of the string $(String(value)), which is only of length $(length_value).")
  end
  return LogoRuntimeError("Can't find element $(index).")
end

function input_type_description(value)
  if is_logo_number(value)
    return "the number $(error_logo_string(value))"
  elseif value isa AbstractString
    return "the string $(error_readable_logo_string(value))"
  elseif value isa AbstractVector
    return "the list $(error_readable_logo_string(value))"
  elseif value isa Bool
    return "the Boolean $(logo_string(value))"
  elseif value === NOBODY
    return "NOBODY"
  elseif value isa AgentSet
    return "the agentset $(agentset_display_name(value))"
  elseif value isa AbstractAgent
    return "the $(agent_type_name(value)) $(logo_string(value))"
  end
  return logo_string(value)
end

function collection_first(value)
  if value isa AbstractVector
    isempty(value) && throw(LogoRuntimeError("List is empty."))
    return first(value)
  elseif value isa AbstractString
    isempty(value) && throw(LogoRuntimeError("first expects a non-empty string"))
    return string(first(value))
  end
  throw(LogoRuntimeError("first expects a list or string"))
end

function collection_last(value)
  if value isa AbstractVector
    isempty(value) && throw(LogoRuntimeError("List is empty."))
    return last(value)
  elseif value isa AbstractString
    isempty(value) && throw(LogoRuntimeError("last expects a non-empty string"))
    return string(last(value))
  end
  throw(LogoRuntimeError("last expects a list or string"))
end

function collection_butfirst(value)
  if value isa AbstractVector
    isempty(value) && throw(LogoRuntimeError("BF got an empty list as input."))
    return length(value) == 1 ? Any[] : copy(@view value[2:end])
  elseif value isa AbstractString
    chars = collect(String(value))
    isempty(chars) && throw(LogoRuntimeError("bf got an empty string as input."))
    return length(chars) == 1 ? "" : join(chars[2:end])
  end
  throw(LogoRuntimeError("butfirst expects a list or string"))
end

function collection_butlast(value)
  if value isa AbstractVector
    isempty(value) && throw(LogoRuntimeError("BL got an empty list as input."))
    return length(value) == 1 ? Any[] : copy(@view value[1:(end - 1)])
  elseif value isa AbstractString
    chars = collect(String(value))
    isempty(chars) && throw(LogoRuntimeError("bl got an empty string as input."))
    return length(chars) == 1 ? "" : join(chars[1:(end - 1)])
  end
  throw(LogoRuntimeError("butlast expects a list or string"))
end

function collection_empty(value)
  if value isa AbstractVector || value isa AbstractString
    return isempty(value)
  end
  throw(LogoRuntimeError("empty? expects a list or string"))
end

function collection_item(index_value, value)
  index = collection_index(index_value)
  slot = index + 1
  if value isa AbstractVector
    1 <= slot <= length(value) || throw(collection_not_found_error(index, value, length(value)))
    return value[slot]
  elseif value isa AbstractString
    chars = collect(String(value))
    1 <= slot <= length(chars) || throw(collection_not_found_error(index, value, length(chars)))
    return string(chars[slot])
  end
  throw(LogoRuntimeError("item expects a list or string"))
end

function numeric_items(value, opname::AbstractString)
  value isa AbstractVector || throw(LogoRuntimeError("$(lowercase(opname)) expects a list"))
  numbers = Float64[]
  for item in value
    is_logo_number(item) && push!(numbers, Float64(item))
  end
  numbers
end

function aggregate_numeric_error(opname::AbstractString, value; min_count::Int=1)
  rendered = aggregate_logo_string(value)
  if min_count == 1
    if opname == "mean" || opname == "median"
      return LogoRuntimeError("Can't find the $opname of a list with no numbers: $(rendered).")
    elseif opname == "min"
      return LogoRuntimeError("Can't find the minimum of a list with no numbers: $(rendered)")
    elseif opname == "max"
      return LogoRuntimeError("Can't find the maximum of a list with no numbers: $(rendered)")
    end
  elseif min_count == 2
    if opname == "variance"
      return LogoRuntimeError("Can't find the variance of a list without at least two numbers: $(rendered).")
    elseif opname == "standard-deviation"
      return LogoRuntimeError("Can't find the standard deviation of a list without at least two numbers: $(rendered)")
    end
  end
  return LogoRuntimeError("$(lowercase(opname)) expects at least one numeric item")
end

function numeric_items!(value, opname::AbstractString; min_count::Int=1)
  numbers = numeric_items(value, opname)
  length(numbers) < min_count && throw(aggregate_numeric_error(opname, value; min_count=min_count))
  numbers
end

function aggregate_sum(value)
  numbers = numeric_items(value, "sum")
  isempty(numbers) ? 0.0 : Base.sum(numbers)
end

function aggregate_mean(value)
  numbers = numeric_items!(value, "mean")
  Base.sum(numbers) / length(numbers)
end

function aggregate_min(value)
  numbers = numeric_items!(value, "min")
  minimum(numbers)
end

function aggregate_max(value)
  numbers = numeric_items!(value, "max")
  maximum(numbers)
end

function aggregate_median(value)
  numbers = sort!(numeric_items!(value, "median"))
  middle = fld(length(numbers), 2) + 1
  if isodd(length(numbers))
    return numbers[middle]
  end
  return (numbers[middle - 1] + numbers[middle]) / 2
end

function aggregate_variance(value)
  numbers = numeric_items!(value, "variance"; min_count=2)
  mean_value = Base.sum(numbers) / length(numbers)
  Base.sum((number - mean_value)^2 for number in numbers) / (length(numbers) - 1)
end

function aggregate_standard_deviation(value)
  numbers = numeric_items!(value, "standard-deviation"; min_count=2)
  mean_value = Base.sum(numbers) / length(numbers)
  sqrt(Base.sum((number - mean_value)^2 for number in numbers) / (length(numbers) - 1))
end

function extreme_agents(context::Context, agentset::AgentSet, block::ReporterBlockNode; mode::Symbol)
  winning_value = mode == :max ? -Inf : Inf
  winners = AbstractAgent[]

  @for_agents agent agentset begin
    value = eval_reporter_block(context, block, agent, block_caller(context))
    is_logo_number(value) || continue
    number = Float64(value)
    if mode == :max
      if number >= winning_value
        if number > winning_value
          winning_value = number
          empty!(winners)
        end
        push!(winners, agent)
      end
    else
      if number <= winning_value
        if number < winning_value
          winning_value = number
          empty!(winners)
        end
        push!(winners, agent)
      end
    end
  end

  owned_agentset(agentset.kind, winners; breed=agentset.breed)
end

function extreme_agent(context::Context, agentset::AgentSet, block::ReporterBlockNode; mode::Symbol)
  winners = extreme_agents(context, agentset, block; mode=mode)
  one_of(context.runtime.world.rng, winners)
end

function extreme_n_agents(context::Context, count_value, agentset::AgentSet, block::ReporterBlockNode; mode::Symbol)
  opname = mode == :max ? "max-n-of" : "min-n-of"
  remaining = sample_size(count_value, opname)
  members = live_agentset_members(agentset)
  total = length(members)
  remaining <= total || throw(LogoRuntimeError("requested $remaining random agents from a set of only $total agents"))

  ordered_members =
    total > 1 ?
    members[randperm(context.runtime.world.rng, total)] :
    members

  grouped = Dict{Float64, Vector{AbstractAgent}}()
  for agent in ordered_members
    value = eval_reporter_block(context, block, agent, block_caller(context))
    is_logo_number(value) || continue
    push!(get!(grouped, Float64(value), AbstractAgent[]), agent)
  end

  selected = AbstractAgent[]
  for key in sort(collect(keys(grouped)); rev = mode == :max)
    for agent in grouped[key]
      remaining == 0 && break
      push!(selected, agent)
      remaining -= 1
    end
    remaining == 0 && break
  end

  AgentSet(agentset.kind, selected; breed=agentset.breed)
end

function sample_size(count_value, opname::AbstractString)
  count = Int(floor(numeric(count_value)))
  count >= 0 || throw(LogoRuntimeError("First input to $(uppercase(opname)) can't be negative."))
  count
end

function sampled_indices(rng::AbstractRNG, count::Int, available::Int)
  count == 0 && return Int[]
  sort(randperm(rng, available)[1:count])
end

function n_of(rng::AbstractRNG, count_value, value::AgentSet; opname::AbstractString="n-of", up_to::Bool=false)
  count = sample_size(count_value, opname)
  available = length(value)
  if up_to
    count = min(count, available)
  elseif count > available
    throw(LogoRuntimeError("Requested $count random agents from a set of only $available agents."))
  end
  indices = sampled_indices(rng, count, available)
  members = live_agentset_members(value)
  AgentSet(value.kind, members[indices]; breed=value.breed)
end

function n_of(rng::AbstractRNG, count_value, value::AbstractVector; opname::AbstractString="n-of", up_to::Bool=false)
  count = sample_size(count_value, opname)
  available = length(value)
  if up_to
    count = min(count, available)
  elseif count > available
    throw(LogoRuntimeError("Requested $count random items from a list of length $available."))
  end
  indices = sampled_indices(rng, count, available)
  Any[value[index] for index in indices]
end

function n_of(rng::AbstractRNG, count_value, value; opname::AbstractString="n-of", up_to::Bool=false)
  throw(LogoRuntimeError("$(lowercase(opname)) expects an agentset or list"))
end

const MAX_SAFE_NETLOGO_INTEGER = 9007199254740992.0
const MIN_RANDOM_SEED = -2147483648
const MAX_RANDOM_SEED = 2147483647

function finite_math_result(value)
  isnan(value) && throw(LogoRuntimeError("math operation produced a non-number"))
  isfinite(value) || throw(LogoRuntimeError("math operation produced a number too large for NetLogo"))
  Float64(value)
end

function netlogo_int(value)
  number = numeric(value)
  abs(number) <= MAX_SAFE_NETLOGO_INTEGER ||
    throw(LogoRuntimeError("$(logo_string(number)) is too large to be represented exactly as an integer in NetLogo"))
  trunc(number)
end

function netlogo_exact_int(value)
  number = numeric(value)
  integer = netlogo_int(number)
  number == integer || throw(LogoRuntimeError("$(logo_string(number)) is not an integer"))
  Int(integer)
end

rounded_world_coord(value) = round(Int, numeric(value))

netlogo_round(value) = floor(numeric(value) + 0.5)

function netlogo_sqrt(value)
  number = numeric(value)
  number >= 0 || throw(LogoRuntimeError("The square root of $(logo_string(number)) is an imaginary number."))
  sqrt(number)
end

function netlogo_ln(value)
  number = numeric(value)
  number > 0 || throw(LogoRuntimeError("Can't take logarithm of $(logo_string(number))."))
  finite_math_result(log(number))
end

function netlogo_log(value, base_value)
  number = numeric(value)
  base = numeric(base_value)
  number > 0 || throw(LogoRuntimeError("Can't take logarithm of $(logo_string(number))."))
  (base > 0 && base != 1.0) || throw(LogoRuntimeError("$(logo_string(base)) isn't a valid base for a logarithm."))
  finite_math_result(log(base, number))
end

netlogo_degrees(value) = numeric(value) * (pi / 180.0)

netlogo_sin(value) = finite_math_result(sin(netlogo_degrees(value)))

netlogo_cos(value) = finite_math_result(cos(netlogo_degrees(value)))

function netlogo_tan(value)
  number = numeric(value)
  normalized = mod(number, 180.0)
  isapprox(normalized, 0.0; atol=1.0e-12) && return 0.0
  isapprox(normalized, 90.0; atol=1.0e-12) && throw(LogoRuntimeError("math operation produced a number too large for NetLogo"))
  finite_math_result(tan(netlogo_degrees(number)))
end

function netlogo_asin(value)
  try
    finite_math_result(asin(numeric(value))) * (180.0 / pi)
  catch err
    err isa DomainError && throw(LogoRuntimeError("math operation produced a non-number"))
    rethrow()
  end
end

function netlogo_acos(value)
  try
    finite_math_result(acos(numeric(value))) * (180.0 / pi)
  catch err
    err isa DomainError && throw(LogoRuntimeError("math operation produced a non-number"))
    rethrow()
  end
end

function netlogo_atan(y_value, x_value)
  y = numeric(y_value)
  x = numeric(x_value)
  (x != 0.0 || y != 0.0) || throw(LogoRuntimeError("atan is undefined when both inputs are zero."))
  mod(finite_math_result(atan(y, x)) * (180.0 / pi), 360.0)
end

netlogo_exp(value) = finite_math_result(exp(numeric(value)))

function netlogo_power(base_value, exponent_value)
  try
    finite_math_result(numeric(base_value) ^ numeric(exponent_value))
  catch err
    err isa DomainError && throw(LogoRuntimeError("math operation produced a non-number"))
    rethrow()
  end
end

function netlogo_divide(left, right)
  divisor = numeric(right)
  divisor == 0.0 && throw(LogoRuntimeError("Division by zero."))
  numeric(left) / divisor
end

function netlogo_mod(left, right)
  divisor = numeric(right)
  divisor == 0.0 && throw(LogoRuntimeError("Division by zero."))
  mod(numeric(left), divisor)
end

function netlogo_remainder(left, right)
  divisor = numeric(right)
  divisor == 0.0 && throw(LogoRuntimeError("Division by zero."))
  rem(numeric(left), divisor)
end

function subtract_headings(left, right)
  difference = mod(numeric(left) - numeric(right) + 180.0, 360.0) - 180.0
  difference == -180.0 && return 180.0
  difference
end

function coerce_spatial_agent(world::World, value)
  if value isa Turtle || value isa Patch
    return ensure_live_agent(world, value)
  end
  throw(LogoRuntimeError("expected a turtle or patch"))
end

function resize_world_command!(world::World, min_pxcor_value, max_pxcor_value, min_pycor_value, max_pycor_value)
  min_pxcor = rounded_world_coord(min_pxcor_value)
  max_pxcor = rounded_world_coord(max_pxcor_value)
  min_pycor = rounded_world_coord(min_pycor_value)
  max_pycor = rounded_world_coord(max_pycor_value)
  (min_pxcor <= 0 <= max_pxcor && min_pycor <= 0 <= max_pycor) ||
    throw(LogoRuntimeError("You must include the point (0, 0) in the world."))
  resize_world!(world, min_pxcor, max_pxcor, min_pycor, max_pycor)
end

function set_patch_size!(world::World, size_value)
  size = numeric(size_value)
  size > 0 || throw(LogoRuntimeError("Patch size must be greater than zero."))
  world.patch_size = size
  world.drawing === nothing || rescale_drawing!(world)
  nothing
end

ticks_started(world::World) = world.ticks >= 0

function require_started_ticks(world::World)
  ticks_started(world) || throw(LogoRuntimeError("The tick counter has not been started yet. Use RESET-TICKS."))
  world
end

function current_ticks(world::World)
  require_started_ticks(world)
  world.ticks
end

clear_ticks!(world::World) = (world.ticks = -1.0; nothing)
reset_ticks!(world::World) = (world.ticks = 0.0; nothing)

function tick_advance!(world::World, amount_value)
  require_started_ticks(world)
  amount = numeric(amount_value)
  amount >= 0 || throw(LogoRuntimeError("Cannot advance the tick counter by a negative amount."))
  world.ticks += amount
  nothing
end

function inspect_agent(world::World, value)
  value isa AbstractAgent || throw(LogoRuntimeError("inspect expects an agent"))
  ensure_live_agent(world, value)
  nothing
end

reset_timer!(world::World) = (world.timer_start_ns = time_ns(); nothing)
timer_value(world::World) = Float64(time_ns() - world.timer_start_ns) / 1.0e9

function wait_seconds(value)
  seconds = numeric(value)
  seconds >= 0 || throw(LogoRuntimeError("wait expects a non-negative interval"))
  sleep(seconds)
  nothing
end

headless_user_cancel() = throw(LogoRuntimeError("model halted by user"))

random_patch_coord(rng::AbstractRNG, mincor::Int, maxcor::Int) = Float64(rand(rng, mincor:maxcor))

function random_agent_coord(rng::AbstractRNG, mincor::Int, maxcor::Int)
  (Float64(mincor) - 0.5) + rand(rng) * Float64(maxcor - mincor + 1)
end

function netlogo_random_normal(rng::AbstractRNG, mean_value, deviation_value)
  deviation = numeric(deviation_value)
  deviation >= 0 || throw(LogoRuntimeError("random-normal's second input can't be negative."))
  numeric(mean_value) + deviation * randn(rng)
end

netlogo_random_exponential(rng::AbstractRNG, mean_value) = numeric(mean_value) * randexp(rng)

function netlogo_random_gamma(rng::AbstractRNG, alpha_value, lambda_value)
  alpha = numeric(alpha_value)
  lambda = numeric(lambda_value)
  (alpha > 0 && lambda > 0) || throw(LogoRuntimeError("random-gamma's inputs must be greater than zero."))
  if alpha < 1
    return netlogo_random_gamma(rng, alpha + 1, lambda) * rand(rng)^(1 / alpha)
  end

  d = alpha - 1 / 3
  c = inv(sqrt(9 * d))
  while true
    x = randn(rng)
    v = (1 + c * x)^3
    v <= 0 && continue
    u = rand(rng)
    if u < 1 - 0.0331 * x^4 || log(u) < 0.5 * x^2 + d * (1 - v + log(v))
      return (d * v) / lambda
    end
  end
end

function poisson_knuth(rng::AbstractRNG, mean::Float64)
  mean == 0 && return 0
  threshold = exp(-mean)
  product = 1.0
  count = 0
  while true
    count += 1
    product *= rand(rng)
    product <= threshold && return count - 1
  end
end

function netlogo_random_poisson(rng::AbstractRNG, mean_value)
  mean = numeric(mean_value)
  mean >= 0 || throw(LogoRuntimeError("random-poisson's input can't be negative."))
  remaining = mean
  total = 0
  while remaining > 20
    total += poisson_knuth(rng, 20.0)
    remaining -= 20
  end
  Float64(total + poisson_knuth(rng, remaining))
end

function netlogo_random_seed(value)
  seed = netlogo_exact_int(value)
  (MIN_RANDOM_SEED <= seed <= MAX_RANDOM_SEED) ||
    throw(LogoRuntimeError("$(logo_string(value)) is not in the allowable range for random seeds (-2147483648 to 2147483647)"))
  seed
end

function precision_value(number_value, places_value)
  number = numeric(number_value)
  places = netlogo_exact_int(places_value)
  if places >= 0
    factor = 10.0^places
    return netlogo_round(number * factor) / factor
  end
  factor = 10.0^(-places)
  netlogo_round(number / factor) * factor
end

function coerce_live_turtle(world::World, value, opname::AbstractString)
  value isa Turtle || throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle"))
  ensure_live_agent(world, value)
end

agent_type_name(::Observer) = "observer"
agent_type_name(::Turtle) = "turtle"
agent_type_name(::Patch) = "patch"
agent_type_name(::Link) = "link"

function require_turtle_input(world::World, value, opname::AbstractString)
  if value === NOBODY
    throw(LogoRuntimeError("$opname expected input to be a turtle but got NOBODY instead."))
  elseif value isa AgentSet
    throw(LogoRuntimeError("$opname expected input to be a turtle but got the agentset $(agentset_display_name(value)) instead."))
  elseif value isa Turtle
    return ensure_live_agent(world, value)
  elseif value isa AbstractAgent
    ensure_live_agent(world, value)
    throw(LogoRuntimeError("$opname expected input to be a turtle but got the $(agent_type_name(value)) $(logo_string(value)) instead."))
  end
  throw(LogoRuntimeError("$opname expected input to be a turtle but got $(logo_string(value)) instead."))
end

function current_perspective_subject!(runtime::RuntimeState)
  subject = runtime.perspective_subject
  if subject isa Turtle || subject isa Patch || subject isa Link
    if !subject.alive
      runtime.perspective_subject = NOBODY
      return NOBODY
    end
  end
  subject === nothing ? NOBODY : subject
end

function set_perspective_subject!(runtime::RuntimeState, subject)
  runtime.perspective_subject = subject
  subject
end

reset_perspective!(runtime::RuntimeState) = set_perspective_subject!(runtime, NOBODY)

function link_relation_matches(link::Link, source::Turtle, target::Turtle; mode::Symbol=:all)
  if mode == :all
    return (link.end1 == source.id && link.end2 == target.id) ||
           (link.end1 == target.id && link.end2 == source.id)
  elseif mode == :out
    return link.directed ?
      (link.end1 == source.id && link.end2 == target.id) :
      ((link.end1 == source.id && link.end2 == target.id) ||
       (link.end1 == target.id && link.end2 == source.id))
  elseif mode == :in
    return link.directed ?
      (link.end1 == target.id && link.end2 == source.id) :
      ((link.end1 == source.id && link.end2 == target.id) ||
       (link.end1 == target.id && link.end2 == source.id))
  end
  false
end

function link_relation_reporter(world::World, source_value, target_value; breed::Union{Nothing, String}=nothing, mode::Symbol=:all)
  source = ensure_live_agent(world, source_value::Turtle)
  target = coerce_live_turtle(world, target_value, "link relation")
  canonical_breed = breed === nothing ? nothing : canonical_name(breed)
  matches = Link[]
  for link in living_links(world)
    canonical_breed !== nothing && link.breed != canonical_breed && continue
    link_relation_matches(link, source, target; mode=mode) && push!(matches, link)
  end
  isempty(matches) ? NOBODY : matches[rand(world.rng, eachindex(matches))]
end

function turtle_breed_name(value)
  value isa AgentSet && value.kind == TurtleKind ||
    throw(LogoRuntimeError("breed must be a turtle breed"))
  value.breed !== nothing || throw(LogoRuntimeError("breed must be a turtle breed"))
  value.breed
end

is_live_agent_value(value) = value isa AbstractAgent && agent_is_live(value)
is_turtle_value(value) = value isa Turtle && agent_is_live(value)
is_patch_value(value) = value isa Patch && agent_is_live(value)
is_link_value(value) = value isa Link && agent_is_live(value)
is_boolean_value(value) = value isa Bool
is_number_value(value) = is_logo_number(value)
is_list_value(value) = value isa AbstractVector
is_anonymous_command_value(value) = value isa AbstractCommandTaskValue
is_anonymous_reporter_value(value) = value isa AbstractReporterTaskValue

function turtle_breed_reporter(world::World, breed::String, id_value)
  turtle = maybe_turtle_by_id(world, netlogo_exact_int(id_value))
  turtle === nothing && return NOBODY
  turtle.breed == breed && return turtle
  actual = turtle_singular_name(world.model, turtle.breed)
  target = uppercase(turtle_singular_name(world.model, breed))
  throw(LogoRuntimeError("$actual $(logo_string(Float64(turtle.id))) is not a $target"))
end

function link_reporter(world::World, breed::String, end1_value, end2_value)
  canonical = canonical_name(breed)
  canonical == "LINKS" || has_link_breed(world.model, canonical) ||
    throw(LogoRuntimeError("unknown link breed $breed"))
  end1 = maybe_turtle_by_id(world, netlogo_exact_int(end1_value))
  end2 = maybe_turtle_by_id(world, netlogo_exact_int(end2_value))
  (end1 === nothing || end2 === nothing) && return NOBODY
  something(existing_link(world, end1, end2, canonical), NOBODY)
end

function is_turtle_breed_value(value, breed::String)
  value isa Turtle && agent_is_live(value) && value.breed == breed
end

function is_link_breed_value(value, breed::String)
  value isa Link && agent_is_live(value) && value.breed == breed
end

function is_directed_link_value(world::World, value)
  value isa Link && agent_is_live(value) && value.directed
end

function is_undirected_link_value(world::World, value)
  value isa Link && agent_is_live(value) && !value.directed
end

function distance_to_target(world::World, source::Union{Turtle, Patch}, target; wrap::Bool=true)
  spatial_target = coerce_spatial_agent(world, target)
  source_x, source_y = agent_position(ensure_live_agent(world, source))
  target_x, target_y = agent_position(spatial_target)
  wrap ? distance_between(world, source_x, source_y, target_x, target_y) :
    distance_between_nowrap(world, source_x, source_y, target_x, target_y)
end

function towards_target(world::World, source::Union{Turtle, Patch}, target; wrap::Bool=true)
  spatial_target = coerce_spatial_agent(world, target)
  source_x, source_y = agent_position(ensure_live_agent(world, source))
  target_x, target_y = agent_position(spatial_target)
  wrap ? heading_towards(world, source_x, source_y, target_x, target_y) :
    heading_towards_nowrap(world, source_x, source_y, target_x, target_y)
end

function distancexy_from(world::World, source::Union{Turtle, Patch}, x_value, y_value; wrap::Bool=true)
  source_x, source_y = agent_position(ensure_live_agent(world, source))
  wrap ? distance_between(world, source_x, source_y, numeric(x_value), numeric(y_value)) :
    distance_between_nowrap(world, source_x, source_y, numeric(x_value), numeric(y_value))
end

function towardsxy_from(world::World, source::Union{Turtle, Patch}, x_value, y_value; wrap::Bool=true)
  source_x, source_y = agent_position(ensure_live_agent(world, source))
  wrap ? heading_towards(world, source_x, source_y, numeric(x_value), numeric(y_value)) :
    heading_towards_nowrap(world, source_x, source_y, numeric(x_value), numeric(y_value))
end

function patch_at_offset(world::World, source::Union{Turtle, Patch}, dx_value, dy_value)
  source_x, source_y = agent_position(ensure_live_agent(world, source))
  maybe_patch(world, source_x + numeric(dx_value), source_y + numeric(dy_value))
end

function turtles_at_offset(
  world::World,
  source::Union{Turtle, Patch},
  dx_value,
  dy_value;
  breed::Union{Nothing, AbstractString}=nothing,
  opname::AbstractString="turtles-at")
  patch = patch_at_offset(world, source, dx_value, dy_value)
  if breed === nothing
    return patch === NOBODY ? AgentSet(TurtleKind, Turtle[]; breed="TURTLES") : turtles_on_sources(world, patch; opname=opname)
  end
  canonical_breed = canonical_name(breed)
  has_turtle_breed(world.model, canonical_breed) || throw(LogoRuntimeError("unknown turtle breed $breed"))
  patch === NOBODY && return AgentSet(TurtleKind, Turtle[]; breed=canonical_breed)
  turtles_on_sources(world, patch; breed=canonical_breed, opname=opname)
end

function validate_radius(radius_value, opname::AbstractString)
  radius = numeric(radius_value)
  radius >= 0 || throw(LogoRuntimeError("$(uppercase(opname)) cannot take a negative radius."))
  radius
end

function spatial_query_agentset(agentset::AgentSet, opname::AbstractString)
  if agentset.kind == TurtleKind || agentset.kind == PatchKind
    return agentset
  end
  throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle or patch agentset"))
end

invalid_points_error() = LogoRuntimeError("Invalid list of points")

function point_query_patch_keys(world::World, points, origin_x::Float64, origin_y::Float64)
  points isa AbstractVector || throw(invalid_points_error())
  patch_keys = Set{Tuple{Int, Int}}()
  for point in points
    point isa AbstractVector || throw(invalid_points_error())
    length(point) == 2 || throw(invalid_points_error())
    is_logo_number(point[1]) && is_logo_number(point[2]) || throw(invalid_points_error())
    patch = maybe_patch(world, origin_x + numeric(point[1]), origin_y + numeric(point[2]))
    patch === NOBODY && continue
    push!(patch_keys, (patch.pxcor, patch.pycor))
  end
  patch_keys
end

function point_query_source_error(opname::AbstractString)
  LogoRuntimeError("$(lowercase(opname)) expects a turtle, patch, turtle agentset, or patch agentset")
end

function source_patch_keys(world::World, value, opname::AbstractString)
  if value isa Patch
    return Set([(value.pxcor, value.pycor)])
  elseif value isa Turtle
    patch = current_patch(world, value)
    return Set([(patch.pxcor, patch.pycor)])
  elseif value isa AgentSet
    if value.kind == PatchKind
      patch_keys = Set{Tuple{Int, Int}}()
      @for_agents member value begin
        patch = member::Patch
        push!(patch_keys, (patch.pxcor, patch.pycor))
      end
      return patch_keys
    elseif value.kind == TurtleKind
      patch_keys = Set{Tuple{Int, Int}}()
      @for_agents member value begin
        patch = current_patch(world, member::Turtle)
        push!(patch_keys, (patch.pxcor, patch.pycor))
      end
      return patch_keys
    end
  end
  throw(point_query_source_error(opname))
end

function agents_at_points(world::World, agentset::AgentSet, points, origin_x::Float64, origin_y::Float64)
  spatial_query_agentset(agentset, "at-points")
  patch_keys = point_query_patch_keys(world, points, origin_x, origin_y)
  if agentset.kind == PatchKind
    members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
    @for_agents member agentset begin
      patch = member::Patch
      (patch.pxcor, patch.pycor) in patch_keys && push!(members, patch)
    end
    return owned_agentset(PatchKind, members)
  end
  members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  @for_agents member agentset begin
    turtle = member::Turtle
    patch = current_patch(world, turtle)
    (patch.pxcor, patch.pycor) in patch_keys && push!(members, turtle)
  end
  owned_agentset(TurtleKind, members; breed=agentset.breed)
end

function turtles_on_sources(
  world::World,
  value;
  breed::Union{Nothing, AbstractString}=nothing,
  opname::AbstractString="turtles-on")
  canonical_breed = breed === nothing ? "TURTLES" : canonical_name(breed)
  breed === nothing || has_turtle_breed(world.model, canonical_breed) || throw(LogoRuntimeError("unknown turtle breed $breed"))
  members = AbstractAgent[]
  # Collect patches from source, then lookup turtles via patch.turtles_here
  if value isa Patch
    _collect_turtles_on_patch!(members, world, value, breed, canonical_breed)
  elseif value isa Turtle
    patch = current_patch(world, value)
    _collect_turtles_on_patch!(members, world, patch, breed, canonical_breed)
  elseif value isa AgentSet
    if value.kind == PatchKind
      @for_agents member value begin
        _collect_turtles_on_patch!(members, world, member::Patch, breed, canonical_breed)
      end
    elseif value.kind == TurtleKind
      seen = Set{Int}()
      @for_agents member value begin
        patch = current_patch(world, member::Turtle)
        for id in patch.turtles_here
          id in seen && continue
          push!(seen, id)
          turtle = maybe_turtle_by_id(world, id)
          turtle === nothing && continue
          (breed === nothing || turtle.breed == canonical_breed) && push!(members, turtle)
        end
      end
    else
      throw(point_query_source_error(opname))
    end
  else
    throw(point_query_source_error(opname))
  end
  owned_agentset(TurtleKind, members; breed=canonical_breed)
end

function count_turtles_on_sources(
  world::World,
  value;
  breed::Union{Nothing, AbstractString}=nothing,
  opname::AbstractString="turtles-on")
  canonical_breed = breed === nothing ? "TURTLES" : canonical_name(breed)
  breed === nothing || has_turtle_breed(world.model, canonical_breed) || throw(LogoRuntimeError("unknown turtle breed $breed"))
  if value isa Patch
    return _count_turtles_on_patch(world, value, breed, canonical_breed)
  elseif value isa Turtle
    return _count_turtles_on_patch(world, current_patch(world, value), breed, canonical_breed)
  elseif value isa AgentSet
    if value.kind == PatchKind
      matched = 0
      members = value.all_live ? current_agentset_members(value) : live_agentset_members(value)
      for member in members
        matched += _count_turtles_on_patch(world, member::Patch, breed, canonical_breed)
      end
      return matched
    elseif value.kind == TurtleKind
      if breed === nothing
        matched = 0
        seen = Set{Tuple{Int, Int}}()
        members = value.all_live ? current_agentset_members(value) : live_agentset_members(value)
        for member in members
          patch = current_patch(world, member::Turtle)
          key = (patch.pxcor, patch.pycor)
          key in seen && continue
          push!(seen, key)
          matched += length(patch.turtles_here)
        end
        return matched
      end
      matched = 0
      seen = Set{Int}()
      members = value.all_live ? current_agentset_members(value) : live_agentset_members(value)
      for member in members
        patch = current_patch(world, member::Turtle)
        for id in patch.turtles_here
          id in seen && continue
          push!(seen, id)
          turtle = maybe_turtle_by_id(world, id)
          turtle === nothing && continue
          (breed === nothing || turtle.breed == canonical_breed) && (matched += 1)
        end
      end
      return matched
    end
  end
  throw(point_query_source_error(opname))
end

function _collect_turtles_on_patch!(members::Vector{AbstractAgent}, world::World, patch::Patch, breed, canonical_breed::String)
  for id in patch.turtles_here
    turtle = maybe_turtle_by_id(world, id)
    turtle === nothing && continue
    (breed === nothing || turtle.breed == canonical_breed) && push!(members, turtle)
  end
end

function _count_turtles_on_patch(world::World, patch::Patch, breed, canonical_breed::String)
  breed === nothing && return length(patch.turtles_here)
  matched = 0
  for id in patch.turtles_here
    turtle = maybe_turtle_by_id(world, id)
    turtle === nothing && continue
    (breed === nothing || turtle.breed == canonical_breed) && (matched += 1)
  end
  matched
end

function patches_on_sources(world::World, value; opname::AbstractString="patches-on")
  patch_keys = source_patch_keys(world, value, opname)
  members = sizehint!(AbstractAgent[], length(world.patches))
  for member in all_patches(world)
    patch = member::Patch
    (patch.pxcor, patch.pycor) in patch_keys && push!(members, patch)
  end
  owned_agentset(PatchKind, members)
end

angular_difference(left::Real, right::Real) = abs(mod(Float64(left) - Float64(right) + 180.0, 360.0) - 180.0)

function agents_in_radius(
  world::World,
  source::Union{Turtle, Patch},
  agentset::AgentSet,
  radius_value;
  opname::AbstractString="in-radius",
  wrap::Bool=true)
  radius = validate_radius(radius_value, opname)
  spatial_query_agentset(agentset, opname)
  source_x, source_y = agent_position(source)

  # Fast path: for turtle agentsets, use patch-grid spatial index
  if agentset.kind == TurtleKind
    return _agents_in_radius_spatial(world, source_x, source_y, agentset, radius, wrap)
  end

  members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  @for_agents target agentset begin
    target isa Turtle || target isa Patch || throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle or patch agentset"))
    target_x, target_y = agent_position(target)
    distance =
      wrap ?
      distance_between(world, source_x, source_y, target_x, target_y) :
      distance_between_nowrap(world, source_x, source_y, target_x, target_y)
    distance <= radius + 1e-9 && push!(members, target)
  end
  owned_agentset(agentset.kind, members; breed=agentset.breed)
end

# Patch-grid spatial index for turtle in-radius queries.
# Instead of scanning all turtles, only check turtles on patches
# within ceil(radius)+1 of the source position.
function _agents_in_radius_spatial(
  world::World,
  source_x::Float64, source_y::Float64,
  agentset::AgentSet,
  radius::Float64,
  wrap::Bool)

  breed_filter = agentset.breed
  threshold = radius + 1e-9
  # Patch scan radius: a turtle at patch (px,py) can be at most ~0.5 from
  # the patch center, so we need patches within ceil(radius + 0.5) of source.
  patch_scan = ceil(Int, radius) + 1
  ww = world_width(world)
  wh = world_height(world)
  min_px = world.min_pxcor
  max_px = world.max_pxcor
  min_py = world.min_pycor
  max_py = world.max_pycor
  src_px = round_patch_coord(source_x)
  src_py = round_patch_coord(source_y)
  x_wraps = axis_wraps(world, :x)
  y_wraps = axis_wraps(world, :y)

  members = AbstractAgent[]
  # Clamp scan range to avoid visiting the same wrapped patch twice.
  # On a torus of width ww, unique offsets span -(ww-1)÷2 .. ww÷2.
  scan_x_neg = x_wraps ? min(patch_scan, (ww - 1) ÷ 2) : patch_scan
  scan_x_pos = x_wraps ? min(patch_scan, ww ÷ 2) : patch_scan
  scan_y_neg = y_wraps ? min(patch_scan, (wh - 1) ÷ 2) : patch_scan
  scan_y_pos = y_wraps ? min(patch_scan, wh ÷ 2) : patch_scan

  for dy_off in -scan_y_neg:scan_y_pos
    py = src_py + dy_off
    if y_wraps
      py = min_py + mod(py - min_py, wh)
    elseif py < min_py || py > max_py
      continue
    end
    for dx_off in -scan_x_neg:scan_x_pos
      px = src_px + dx_off
      if x_wraps
        px = min_px + mod(px - min_px, ww)
      elseif px < min_px || px > max_px
        continue
      end
      patch = world.patches[(ww * (max_py - py)) + (px - min_px) + 1]
      for tid in patch.turtles_here
        turtle = maybe_turtle_by_id(world, tid)
        turtle === nothing && continue
        if breed_filter !== nothing && breed_filter != "TURTLES"
          turtle.breed == breed_filter || continue
        end
        dist = wrap ?
          distance_between(world, source_x, source_y, turtle.xcor, turtle.ycor) :
          distance_between_nowrap(world, source_x, source_y, turtle.xcor, turtle.ycor)
        dist <= threshold && push!(members, turtle)
      end
    end
  end

  owned_agentset(TurtleKind, members; breed=agentset.breed)
end

function agents_in_cone(
  world::World,
  source::Turtle,
  agentset::AgentSet,
  radius_value,
  angle_value;
  opname::AbstractString="in-cone",
  wrap::Bool=true)
  radius = validate_radius(radius_value, opname)
  angle = numeric(angle_value)
  operation = uppercase(opname)
  angle >= 0 || throw(LogoRuntimeError("$operation cannot take a negative angle."))
  angle <= 360 || throw(LogoRuntimeError("$operation cannot take an angle greater than 360."))
  spatial_query_agentset(agentset, opname)
  source_x, source_y = agent_position(source)
  half_angle = angle / 2.0
  members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  @for_agents target agentset begin
    target isa Turtle || target isa Patch || throw(LogoRuntimeError("$(lowercase(opname)) expects a turtle or patch agentset"))
    target_x, target_y = agent_position(target)
    distance =
      wrap ?
      distance_between(world, source_x, source_y, target_x, target_y) :
      distance_between_nowrap(world, source_x, source_y, target_x, target_y)
    distance <= radius + 1e-9 || continue
    if distance <= 1e-9
      push!(members, target)
      continue
    end
    heading =
      wrap ?
      heading_towards(world, source_x, source_y, target_x, target_y) :
      heading_towards_nowrap(world, source_x, source_y, target_x, target_y)
    angular_difference(heading, source.heading) <= half_angle + 1e-9 && push!(members, target)
  end
  owned_agentset(agentset.kind, members; breed=agentset.breed)
end

function both_ends(world::World, link::Link)
  AgentSet(TurtleKind, Turtle[turtle_by_id(world, link.end1), turtle_by_id(world, link.end2)]; breed="TURTLES")
end

function other_end(context::Context)
  world = context.runtime.world
  if context.agent isa Link
    context.caller isa Turtle || throw(LogoRuntimeError("other-end needs a turtle caller when running in a link context"))
    link = context.agent
    caller = context.caller
    if caller.id == link.end1
      return turtle_by_id(world, link.end2)
    elseif caller.id == link.end2
      return turtle_by_id(world, link.end1)
    end
    throw(LogoRuntimeError("caller turtle is not attached to this link"))
  elseif context.agent isa Turtle
    context.caller isa Link || throw(LogoRuntimeError("other-end needs a link caller when running in a turtle context"))
    turtle = context.agent
    link = context.caller
    if turtle.id == link.end1
      return turtle_by_id(world, link.end2)
    elseif turtle.id == link.end2
      return turtle_by_id(world, link.end1)
    end
    throw(LogoRuntimeError("current turtle is not attached to the calling link"))
  end
  throw(LogoRuntimeError("other-end is only available to turtles and links"))
end

function link_neighbor(world::World, turtle::Turtle, target; mode::Symbol=:all, breed::Union{String,Nothing}=nothing)
  target isa Turtle || throw(LogoRuntimeError("expected a turtle neighbor"))
  any(neighbor -> same_agent(target, neighbor::Turtle), link_neighbors(world, turtle; mode=mode, breed=breed))
end

sort_agents(model::ModelSpec, agents::AbstractVector{<:AbstractAgent}) =
  sort(collect(agents), by=agent -> agent_sort_key(model, agent))

function collection_sort(model::ModelSpec, value)
  if value isa AgentSet
    return Any[sort_agents(model, live_agentset_members(value))...]
  elseif value isa AbstractVector
    numbers = Float64[]
    strings = String[]
    agents = AbstractAgent[]
    for item in value
      if is_logo_number(item)
        push!(numbers, Float64(item))
      elseif item isa AbstractString
        push!(strings, String(item))
      elseif item isa AbstractAgent
        push!(agents, item)
      end
    end
    if !isempty(numbers)
      return Any[sort(numbers)...]
    elseif !isempty(strings)
      return Any[sort(strings)...]
    end
    return Any[sort_agents(model, agents)...]
  end
  throw(LogoRuntimeError("sort expects a list or agentset"))
end

function collection_member(needle, value)
  if value isa AbstractVector
    return any(item -> logo_equal(needle, item), value)
  elseif value isa AbstractString
    needle isa AbstractString || throw(LogoRuntimeError("member? expects a string needle when searching a string"))
    return occursin(String(needle), value)
  elseif value isa AgentSet
    needle isa AbstractAgent || throw(LogoRuntimeError("member? expects an agent when searching an agentset"))
    return any(agent -> same_agent(needle, agent), value)
  end
  throw(LogoRuntimeError("member? expects a list, string, or agentset"))
end

function collection_position(needle, value)
  if value isa AbstractVector
    for (index, item) in enumerate(value)
      logo_equal(needle, item) && return Float64(index - 1)
    end
    return false
  elseif value isa AbstractString
    needle isa AbstractString || throw(LogoRuntimeError("position expects a string needle when searching a string"))
    match = findfirst(String(needle), value)
    return match === nothing ? false : Float64(first(match) - 1)
  end
  throw(LogoRuntimeError("position expects a list or string"))
end

function collection_remove(needle, value)
  if value isa AbstractVector
    return Any[item for item in value if !logo_equal(needle, item)]
  elseif value isa AbstractString
    needle isa AbstractString || throw(LogoRuntimeError("remove expects a string needle when removing from a string"))
    return isempty(needle) ? value : replace(value, String(needle) => "")
  end
  throw(LogoRuntimeError("remove expects a list or string"))
end

function collection_remove_item(index_value, value)
  index = ensure_nonnegative_collection_index!(collection_index(index_value))
  slot = index + 1
  if value isa AbstractVector
    1 <= slot <= length(value) || throw(collection_not_found_error(index, value, length(value)))
    result = Any[value...]
    deleteat!(result, slot)
    return result
  elseif value isa AbstractString
    chars = collect(value)
    1 <= slot <= length(chars) || throw(collection_not_found_error(index, value, length(chars)))
    deleteat!(chars, slot)
    return String(chars)
  end
  throw(LogoRuntimeError("remove-item expects a list or string"))
end

function collection_reverse(value)
  if value isa AbstractVector
    return Any[reverse(value)...]
  elseif value isa AbstractString
    return join(reverse(collect(String(value))))
  end
  throw(LogoRuntimeError("reverse expects a list or string"))
end

function collection_shuffle(rng::AbstractRNG, value)
  value isa AbstractVector || throw(LogoRuntimeError("shuffle expects a list"))
  Any[shuffle(rng, value)...]
end

function collection_insert_item(index_value, value, new_item)
  index = ensure_nonnegative_collection_index!(collection_index(index_value))
  if value isa AbstractVector
    index <= length(value) || throw(collection_not_found_error(index, value, length(value)))
    result = Any[value...]
    insert!(result, index + 1, new_item)
    return result
  elseif value isa AbstractString
    new_item isa AbstractString ||
      throw(LogoRuntimeError("INSERT-ITEM expected input to be a string but got $(input_type_description(new_item)) instead."))
    chars = collect(String(value))
    index <= length(chars) || throw(collection_not_found_error(index, value, length(chars)))
    prefix = index == 0 ? "" : join(chars[1:index])
    suffix = index == length(chars) ? "" : join(chars[(index + 1):length(chars)])
    return prefix * String(new_item) * suffix
  end
  throw(LogoRuntimeError("insert-item expects a list or string"))
end

function collection_replace_item(index_value, value, new_item)
  index = ensure_nonnegative_collection_index!(collection_index(index_value))
  slot = index + 1
  if value isa AbstractVector
    1 <= slot <= length(value) || throw(collection_not_found_error(index, value, length(value)))
    result = Any[value...]
    result[slot] = new_item
    return result
  elseif value isa AbstractString
    new_item isa AbstractString ||
      throw(LogoRuntimeError("REPLACE-ITEM expected input to be a string but got $(input_type_description(new_item)) instead."))
    chars = collect(String(value))
    1 <= slot <= length(chars) || throw(collection_not_found_error(index, value, length(chars)))
    prefix = slot == 1 ? "" : join(chars[1:(slot - 1)])
    suffix = slot == length(chars) ? "" : join(chars[(slot + 1):length(chars)])
    return prefix * String(new_item) * suffix
  end
  throw(LogoRuntimeError("replace-item expects a list or string"))
end

function collection_sublist(value, start_value, end_value)
  value isa AbstractVector || throw(LogoRuntimeError("sublist expects a list"))
  start_index = Int(floor(numeric(start_value)))
  end_index = Int(floor(numeric(end_value)))
  start_index >= 0 || throw(LogoRuntimeError("sublist start must be non-negative"))
  end_index <= length(value) || throw(LogoRuntimeError("sublist end index out of bounds"))
  end_index >= start_index || throw(LogoRuntimeError("sublist end must not be smaller than start"))
  start_index <= length(value) || throw(LogoRuntimeError("sublist start index out of bounds"))
  start_index == end_index && return Any[]
  return copy(@view value[(start_index + 1):end_index])
end

function collection_substring(value, start_value, end_value)
  value isa AbstractString || throw(LogoRuntimeError("substring expects a string"))
  chars = collect(String(value))
  start_index = Int(floor(numeric(start_value)))
  end_index = Int(floor(numeric(end_value)))
  start_index >= 0 || throw(LogoRuntimeError("substring start must be non-negative"))
  end_index <= length(chars) || throw(LogoRuntimeError("substring end index out of bounds"))
  end_index >= start_index || throw(LogoRuntimeError("substring end must not be smaller than start"))
  start_index <= length(chars) || throw(LogoRuntimeError("substring start index out of bounds"))
  start_index == end_index && return ""
  return join(chars[(start_index + 1):end_index])
end

function collection_remove_duplicates(value)
  value isa AbstractVector || throw(LogoRuntimeError("remove-duplicates expects a list"))
  result = Any[]
  for item in value
    any(existing -> logo_equal(existing, item), result) || push!(result, item)
  end
  result
end

function collection_modes(value)
  value isa AbstractVector || throw(LogoRuntimeError("modes expects a list"))
  representatives = Any[]
  counts = Int[]

  for item in value
    found = false
    for index in eachindex(representatives)
      if logo_equal(representatives[index], item)
        counts[index] += 1
        found = true
        break
      end
    end

    if !found
      push!(representatives, item)
      push!(counts, 1)
    end
  end

  isempty(representatives) && return Any[]
  peak = maximum(counts)
  Any[representatives[index] for index in eachindex(representatives) if counts[index] == peak]
end

function range_values(args::Vector{Any})
  length(args) >= 1 || throw(LogoRuntimeError("range expects at least one argument"))
  length(args) <= 3 || throw(LogoRuntimeError("range expects at most three arguments"))

  start =
    length(args) == 1 ? 0.0 :
    numeric(args[1])
  stop =
    length(args) == 1 ? numeric(args[1]) :
    numeric(args[2])
  step = length(args) < 3 ? 1.0 : numeric(args[3])
  step != 0 || throw(LogoRuntimeError("The step-size for range must be non-zero."))

  values = Any[]
  current = start
  if step > 0
    while current < stop
      push!(values, current)
      current += step
    end
  else
    while current > stop
      push!(values, current)
      current += step
    end
  end

  values
end

function list_argument(value, opname::AbstractString)
  value isa AbstractVector || throw(LogoRuntimeError("$opname expects a list"))
  value
end

function parallel_lists(opname::AbstractString, values...)
  lists = [list_argument(value, opname) for value in values]
  if !isempty(lists)
    expected = length(first(lists))
    all(length(list) == expected for list in lists) || throw(LogoRuntimeError("$opname expects lists of equal length"))
  end
  lists
end

@inline reporter_task_minimum_inputs(task::ReporterTaskValue) = length(task.block.params)
@inline reporter_task_minimum_inputs(task::PrimitiveReporterTaskValue) = first(primitive_input_bounds(task.spec.syntax))
@inline reporter_task_minimum_inputs(task::ProcedureReporterTaskValue) = length(task.procedure.inputs)

@inline command_task_minimum_inputs(task::CommandTaskValue) = length(task.task.params)
@inline command_task_minimum_inputs(task::PrimitiveCommandTaskValue) = first(primitive_task_input_bounds(task.spec))
@inline command_task_minimum_inputs(task::ProcedureCommandTaskValue) = length(task.procedure.inputs)

function map_values(context::Context, task::AbstractReporterTaskValue, value)
  minimum_inputs = reporter_task_minimum_inputs(task)
  minimum_inputs <= 1 || throw(task_arity_error("reporter task", minimum_inputs, 1))
  list = list_argument(value, "map")
  results = sizehint!(Any[], length(list))
  actuals = Vector{Any}(undef, 1)
  for item in list
    actuals[1] = item
    push!(results, invoke_reporter_task(context, task, actuals))
  end
  results
end

function map_values(context::Context, task::AbstractReporterTaskValue, values...)
  lists = parallel_lists("map", values...)
  minimum_inputs = reporter_task_minimum_inputs(task)
  isempty(lists) && minimum_inputs > 0 && throw(task_arity_error("reporter task", minimum_inputs, 0))
  length(lists) >= minimum_inputs || throw(task_arity_error("reporter task", minimum_inputs, length(lists)))
  count = isempty(lists) ? 0 : length(first(lists))
  results = sizehint!(Any[], count)
  actuals = Vector{Any}(undef, length(lists))
  for index in 1:count
    for i in eachindex(lists)
      @inbounds actuals[i] = lists[i][index]
    end
    push!(results, invoke_reporter_task(context, task, actuals))
  end
  results
end

function filter_values(context::Context, task::AbstractReporterTaskValue, value)
  list = list_argument(value, "filter")
  results = sizehint!(Any[], length(list))
  actuals = Vector{Any}(undef, 1)
  for item in list
    actuals[1] = item
    keep = invoke_reporter_task(context, task, actuals)
    keep isa Bool || throw(LogoRuntimeError("FILTER expected input to be a TRUE/FALSE but got $(keep) instead."))
    keep && push!(results, item)
  end
  results
end

function reduce_values(context::Context, task::AbstractReporterTaskValue, value)
  list = list_argument(value, "reduce")
  isempty(list) && throw(LogoRuntimeError("reduce expects a non-empty list"))
  accumulator = list[1]
  actuals = Vector{Any}(undef, 2)
  for index in 2:length(list)
    actuals[1] = accumulator
    actuals[2] = list[index]
    accumulator = invoke_reporter_task(context, task, actuals)
  end
  accumulator
end

function task_sort_compare(context::Context, task::AbstractReporterTaskValue, left, right)
  if logical(invoke_reporter_task(context, task, Any[right, left]))
    return 1
  elseif logical(invoke_reporter_task(context, task, Any[left, right]))
    return -1
  end
  0
end

function sort_by_values(context::Context, task::AbstractReporterTaskValue, value)
  items =
    if value isa AgentSet
      shuffle(context.runtime.world.rng, Any[live_agentset_members(value)...])
    elseif value isa AbstractVector
      Any[value...]
    else
      throw(LogoRuntimeError("SORT-BY expected input to be a list or agentset but got $(value) instead."))
    end

  length(items) <= 1 && return items
  sort(items, alg=MergeSort, lt=(left, right) -> task_sort_compare(context, task, left, right) < 0)
end

sort_on_key_label(value::Real) = "number"
sort_on_key_label(value::AbstractString) = "string"
sort_on_key_label(value::Turtle) = "turtle"
sort_on_key_label(value::Patch) = "patch"
sort_on_key_label(value::Link) = "link"
sort_on_key_label(value) = string(typeof(value))

sort_on_key_order(value::Real) = Float64(value)
sort_on_key_order(value::AbstractString) = String(value)
sort_on_key_order(model::ModelSpec, value::AbstractAgent) = agent_sort_key(model, value)

function classify_sort_on_key(model::ModelSpec, value)
  if is_logo_number(value)
    return :number, sort_on_key_order(value), sort_on_key_label(value)
  elseif value isa AbstractString
    return :string, sort_on_key_order(value), sort_on_key_label(value)
  elseif value isa AbstractAgent
    return Symbol(sort_on_key_label(value)), sort_on_key_order(model, value), sort_on_key_label(value)
  end
  throw(LogoRuntimeError("SORT-ON works on numbers, strings, or agents of the same type"))
end

function sort_on_values(context::Context, block::ReporterBlockNode, agentset::AgentSet)
  members = live_agentset_members(agentset)
  items = Vector{Any}(undef, length(members))
  for i in eachindex(members)
    @inbounds items[i] = members[i]
  end
  shuffle!(context.runtime.world.rng, items)
  length(items) <= 1 && return items

  expected_kind = nothing
  expected_label = ""
  keyed = Tuple{Any, Any}[]
  for item in items
    key = eval_reporter_block(context, block, item::AbstractAgent, block_caller(context))
    kind, order_key, label = classify_sort_on_key(context.runtime.model, key)
    if expected_kind === nothing
      expected_kind = kind
      expected_label = label
    elseif kind != expected_kind
      throw(LogoRuntimeError("SORT-ON works on numbers, strings, or agents of the same type, but not on a $expected_label and a $label"))
    end
    push!(keyed, (order_key, item))
  end

  Any[last(pair) for pair in sort(keyed, alg=MergeSort, by=first)]
end

function ifelse_value(context::Context, args::Vector{Any})
  index = 1
  while index + 1 <= length(args)
    condition = logical(eval_expr(context, args[index]))
    block = args[index + 1]
    block isa ReporterBlockNode || throw(LogoRuntimeError("ifelse-value expects reporter blocks for branches"))
    condition && return eval_reporter_block(context, block, context.agent, context.caller)
    index += 2
  end

  if index <= length(args)
    block = args[index]
    block isa ReporterBlockNode || throw(LogoRuntimeError("ifelse-value expects reporter blocks for branches"))
    return eval_reporter_block(context, block, context.agent, context.caller)
  end

  throw(LogoRuntimeError("IFELSE-VALUE found no true conditions and no else branch. If you don't wish to error when no conditions are true, add a final else branch."))
end

function carefully_execute!(context::Context, body::BlockNode, handler::BlockNode)
  try
    execute_block!(context, body)
  catch err
    if err isa LogoRuntimeError
      push!(context.runtime.error_messages, err.message)
      try
        execute_block!(context, handler)
      finally
        pop!(context.runtime.error_messages)
      end
      return nothing
    end
    rethrow()
  end
  nothing
end

function with_local_randomness!(context::Context, block::BlockNode)
  saved_rng = copy(context.runtime.world.rng)
  try
    execute_block!(context, block)
  finally
    context.runtime.world.rng = saved_rng
  end
  nothing
end

function string_run_context(context::Context)
  locals = visible_string_scopes(context)
  Context(context.runtime, context.agent, locals, context.caller, context.in_ask, length(locals))
end

function run_string!(context::Context, source::AbstractString)
  source_text = String(source)
  child = string_run_context(context)
  scope = visible_string_scope_names(child)
  block =
    try
      parse_runtime_commands(source_text, child.runtime.model, child.runtime.registry, scope)
    catch err
      throw(runtime_parse_error(err))
    end
  execute_block!(child, block, false)
  nothing
end

function runresult_string(context::Context, source::AbstractString)
  source_text = String(source)
  child = string_run_context(context)
  scope = visible_string_scope_names(child)
  expr =
    try
      parse_runtime_reporter(source_text, child.runtime.model, child.runtime.registry, scope)
    catch err
      throw(runtime_parse_error(err))
    end
  eval_expr(child, expr)
end

function loop_execute!(context::Context, block::BlockNode)
  while true
    execute_block!(context, block)
  end
end

function known_runtime_name(model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String}, name::String)
  name in scope && return true
  name in model.globals && return true
  name in model.turtles_own && return true
  name in model.patches_own && return true
  name in model.links_own && return true
  name in BUILTIN_VARIABLE_NAMES && return true
  has_turtle_breed(model, name) && return true
  has_link_breed(model, name) && return true
  any(name in breed.owns for breed in model.breeds) && return true
  any(name in breed.owns for breed in model.link_breeds) && return true
  get_reporter(registry, name) !== nothing && return true
  get_command(registry, name) !== nothing && return true
  haskey(model.procedures, name)
end

function known_reference_name(model::ModelSpec, name::String)
  name in model.globals && return true
  name in model.turtles_own && return true
  name in model.patches_own && return true
  name in model.links_own && return true
  name in BUILTIN_VARIABLE_NAMES && return true
  any(name in breed.owns for breed in model.breeds) && return true
  any(name in breed.owns for breed in model.link_breeds)
end

undefined_name_error(name::String) = LogoRuntimeError("Nothing named $name has been defined.")

validate_runtime_syntax!(::NumberLiteral, ::ModelSpec, ::PrimitiveRegistry, ::Set{String}) = nothing
validate_runtime_syntax!(::StringLiteral, ::ModelSpec, ::PrimitiveRegistry, ::Set{String}) = nothing
validate_runtime_syntax!(::BoolLiteral, ::ModelSpec, ::PrimitiveRegistry, ::Set{String}) = nothing
validate_runtime_syntax!(::NobodyLiteral, ::ModelSpec, ::PrimitiveRegistry, ::Set{String}) = nothing
validate_runtime_syntax!(::SymbolArg, ::ModelSpec, ::PrimitiveRegistry, ::Set{String}) = nothing

function validate_runtime_syntax!(expr::VariableRef, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  known_runtime_name(model, registry, scope, expr.name) || throw(undefined_name_error(expr.name))
  nothing
end

function validate_runtime_syntax!(expr::UnaryExpr, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  validate_runtime_syntax!(expr.arg, model, registry, scope)
end

function validate_runtime_syntax!(expr::ListLiteral, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  for item in expr.items
    validate_runtime_syntax!(item, model, registry, scope)
  end
  nothing
end

function validate_runtime_syntax!(expr::CallableRefNode, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  known_runtime_name(model, registry, scope, expr.name) || throw(undefined_name_error(expr.name))
  nothing
end

function validate_runtime_syntax!(expr::ReporterBlockNode, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  child_scope = copy(scope)
  union!(child_scope, expr.params)
  validate_runtime_syntax!(expr.expr, model, registry, child_scope)
end

function validate_runtime_syntax!(expr::CommandTaskNode, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  child_scope = copy(scope)
  union!(child_scope, expr.params)
  validate_runtime_syntax!(expr.body, model, registry, child_scope)
end

function validate_runtime_syntax!(expr::ReporterCall, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  if expr.name == "__REFERENCE" && length(expr.args) == 1 && expr.args[1] isa SymbolArg
    known_reference_name(model, expr.args[1].name) || throw(undefined_name_error(expr.args[1].name))
  end
  for arg in expr.args
    validate_runtime_syntax!(arg, model, registry, scope)
  end
  nothing
end

function validate_runtime_syntax!(stmt::CommandCall, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  for arg in stmt.args
    validate_runtime_syntax!(arg, model, registry, scope)
  end
  if stmt.name == "LET" && !isempty(stmt.args) && stmt.args[1] isa SymbolArg
    push!(scope, stmt.args[1].name)
  end
  nothing
end

function validate_runtime_syntax!(block::BlockNode, model::ModelSpec, registry::PrimitiveRegistry, scope::Set{String})
  child_scope = copy(scope)
  for stmt in block.statements
    validate_runtime_syntax!(stmt, model, registry, child_scope)
  end
  nothing
end

function check_syntax_message(context::Context, source::AbstractString)
  source_text = String(source)
  child = string_run_context(context)
  scope = visible_string_scope_names(child)

  try
    block = parse_runtime_commands(source_text, child.runtime.model, child.runtime.registry, scope)
    validate_runtime_syntax!(block, child.runtime.model, child.runtime.registry, scope)
    return ""
  catch err
    command_error = err isa Diagnostic ? err.message : err isa LogoRuntimeError ? err.message : rethrow(err)
    try
      expr = parse_runtime_reporter(source_text, child.runtime.model, child.runtime.registry, scope)
      validate_runtime_syntax!(expr, child.runtime.model, child.runtime.registry, scope)
      return ""
    catch reporter_err
      if reporter_err isa Diagnostic || reporter_err isa LogoRuntimeError
        return command_error
      end
      rethrow(reporter_err)
    end
  end
end

agentset_display_name(agentset::AgentSet) =
  lowercase(something(agentset.breed, generic_agentset_breed(agentset.kind), agentset_plural_name(agentset.kind)))

function canonical_turtle_shape_name(shape::AbstractString)
  normalized = lowercase(String(shape))
  normalized in DEFAULT_SHAPE_NAMES || throw(LogoRuntimeError("\"$shape\" is not a defined turtle shape"))
  normalized
end

function canonical_link_shape_name(shape::AbstractString)
  normalized = lowercase(String(shape))
  normalized in DEFAULT_LINK_SHAPE_NAMES || throw(LogoRuntimeError("\"$shape\" is not a defined link shape"))
  normalized
end

function require_default_shape_target(world::World, value)
  value isa AgentSet || throw(LogoRuntimeError("set-default-shape expected an agentset"))
  value.kind == PatchKind &&
    throw(LogoRuntimeError("cannot set the default shape of patches, because patches do not have a shape"))
  (value.kind == TurtleKind || value.kind == LinkKind) &&
    value.dynamic &&
    value.world === world &&
    value.breed !== nothing &&
    return value
  throw(LogoRuntimeError("set-default-shape can only set the default shape of the entire breed"))
end

function set_default_shape_command!(context::Context, breed_value, shape_value)
  world = context.runtime.world
  breed = require_default_shape_target(world, breed_value)
  shape = String(shape_value)
  if breed.kind == TurtleKind
    set_default_turtle_shape!(world, something(breed.breed), canonical_turtle_shape_name(shape))
  else
    set_default_link_shape!(world, something(breed.breed), canonical_link_shape_name(shape))
  end
  nothing
end

function require_spatial_target(world::World, value, opname::AbstractString)
  if value === NOBODY
    throw(LogoRuntimeError("$opname expected input to be an agent but got NOBODY instead."))
  elseif value isa AgentSet
    throw(LogoRuntimeError("$opname expected input to be an agent but got the agentset $(agentset_display_name(value)) instead."))
  elseif value isa Turtle || value isa Patch
    return ensure_live_agent(world, value)
  elseif value isa Link
    ensure_live_agent(world, value)
  end
  throw(LogoRuntimeError("$opname expected input to be an agent but got $(logo_string(value)) instead."))
end

function face_turtle!(world::World, turtle::Turtle, target; wrap::Bool=true)
  ensure_live_agent(world, turtle)
  target_agent = require_spatial_target(world, target, "FACE")
  target_x, target_y = agent_position(target_agent)
  heading =
    wrap ?
    heading_towards(world, turtle.xcor, turtle.ycor, target_x, target_y) :
    heading_towards_nowrap(world, turtle.xcor, turtle.ycor, target_x, target_y)
  set_turtle_heading!(world, turtle, heading)
  turtle
end

normalize_heading_component(value::Real) =
  isapprox(Float64(value), 0.0; atol=1e-12) ? 0.0 :
  isapprox(Float64(value), 1.0; atol=1e-12) ? 1.0 :
  isapprox(Float64(value), -1.0; atol=1e-12) ? -1.0 :
  Float64(value)

heading_dx(heading::Real) = normalize_heading_component(sin(deg2rad(Float64(heading))))
heading_dy(heading::Real) = normalize_heading_component(cos(deg2rad(Float64(heading))))

function face_turtle_xy!(world::World, turtle::Turtle, x_value, y_value; wrap::Bool=true)
  ensure_live_agent(world, turtle)
  set_turtle_heading!(world, turtle, towardsxy_from(world, turtle, x_value, y_value; wrap=wrap))
  turtle
end

function link_heading(world::World, link::Link)
  ensure_live_agent(world, link)
  end1 = turtle_by_id(world, link.end1)
  end2 = turtle_by_id(world, link.end2)
  if isapprox(end1.xcor, end2.xcor; atol=1e-12) && isapprox(end1.ycor, end2.ycor; atol=1e-12)
    throw(LogoRuntimeError("there is no heading of a link whose endpoints are in the same position"))
  end
  heading_towards(world, end1.xcor, end1.ycor, end2.xcor, end2.ycor)
end

function follow_patch_gradient!(
  world::World,
  turtle::Turtle,
  variable::AbstractString;
  four_way::Bool=false,
  uphill::Bool=true)
  ensure_live_agent(world, turtle)
  source_patch = current_patch(world, turtle)
  neighbors = Patch[neighbor::Patch for neighbor in patch_neighbors(world, source_patch; four_way=four_way)]
  isempty(neighbors) && return turtle

  chosen = Patch[]
  best_value = nothing
  for candidate_any in neighbors
    candidate = candidate_any::Patch
    value = numeric(get_agent_variable(candidate, world, variable))
    if best_value === nothing ||
       (uphill ? value > best_value + 1e-12 : value < best_value - 1e-12)
      empty!(chosen)
      push!(chosen, candidate)
      best_value = value
    elseif isapprox(value, best_value; atol=1e-12)
      push!(chosen, candidate)
    end
  end

  target = chosen[rand(world.rng, eachindex(chosen))]
  set_turtle_pose!(
    world,
    turtle,
    Float64(target.pxcor),
    Float64(target.pycor),
    heading_towards(world, turtle.xcor, turtle.ycor, Float64(target.pxcor), Float64(target.pycor)))
  turtle
end

function move_turtle_to_agent!(world::World, turtle::Turtle, target)
  ensure_live_agent(world, turtle)
  target_agent = require_spatial_target(world, target, "MOVE-TO")
  target_x, target_y = agent_position(target_agent)
  move_turtle_to_with_pen!(world, turtle, target_x, target_y)
end

function home_turtle!(world::World, turtle::Turtle)
  ensure_live_agent(world, turtle)
  set_turtle_pose_with_pen!(world, turtle, 0.0, 0.0, 0.0)
end

function can_move(world::World, turtle::Turtle, distance_value)
  ensure_live_agent(world, turtle)
  distance = numeric(distance_value)
  heading_radians = deg2rad(turtle.heading)
  new_x = turtle.xcor + distance * sin(heading_radians)
  new_y = turtle.ycor + distance * cos(heading_radians)
  try
    apply_topology(world, new_x, new_y)
    true
  catch err
    err isa LogoRuntimeError || rethrow()
    false
  end
end

ordered_turtle_heading(index::Int, count::Int) = count <= 0 ? 0.0 : 360.0 * Float64(index) / Float64(count)
ordered_turtle_color(index::Int) = BASE_COLOR_VALUES[mod(index, length(BASE_COLOR_VALUES)) + 1]
world_circle_center(world::World) = (
  Float64(world.min_pxcor + fld(world_width(world), 2)),
  Float64(world.min_pycor + fld(world_height(world), 2)))

mutable struct RadialLayoutNode
  turtle::Turtle
  parent::Union{Nothing, RadialLayoutNode}
  children::Vector{RadialLayoutNode}
  angle::Float64
  weight::Float64
end

RadialLayoutNode(turtle::Turtle, parent::Union{Nothing, RadialLayoutNode}) =
  RadialLayoutNode(turtle, parent, RadialLayoutNode[], 0.0, -1.0)

radial_layout_depth(node::RadialLayoutNode) = node.parent === nothing ? 0 : 1 + radial_layout_depth(node.parent)

function radial_layout_weight(node::RadialLayoutNode)
  node.weight >= 0.0 && return node.weight
  max_child_weight = 0.0
  for child in node.children
    max_child_weight = max(max_child_weight, radial_layout_weight(child))
  end
  node.weight = max(length(node.children) + 1.0, max_child_weight * 0.8)
  node.weight
end

function layout_radial_arcs!(node::RadialLayoutNode, arc_start::Real, arc_end::Real)
  node.angle = (Float64(arc_start) + Float64(arc_end)) / 2.0
  isempty(node.children) && return nothing

  weight_sum = sum(radial_layout_weight(child) for child in node.children)
  child_start = Float64(arc_start)
  for child in node.children
    child_end = child_start + (Float64(arc_end) - Float64(arc_start)) * radial_layout_weight(child) / weight_sum
    layout_radial_arcs!(child, child_start, child_end)
    child_start = child_end
  end
  nothing
end

function layout_circle_at!(world::World, turtles::Vector{Turtle}, radius_value, center_x::Real, center_y::Real)
  isempty(turtles) && return nothing
  radius = numeric(radius_value)
  count = length(turtles)
  for (index, turtle) in enumerate(turtles)
    heading = ordered_turtle_heading(index - 1, count)
    heading_radians = deg2rad(heading)
    set_turtle_pose!(
      world,
      turtle,
      Float64(center_x) + radius * sin(heading_radians),
      Float64(center_y) + radius * cos(heading_radians),
      heading)
  end
  nothing
end

function layout_circle!(world::World, turtles_value, radius_value)
  turtles = coerce_turtle_collection(world, turtles_value, "layout-circle"; shuffle_agentset=turtles_value isa AgentSet)
  center_x, center_y = world_circle_center(world)
  layout_circle_at!(world, turtles, radius_value, center_x, center_y)
end

function layout_radial!(world::World, turtles_value, links_value, root_value)
  turtles_value isa AgentSet && turtles_value.kind == TurtleKind ||
    throw(LogoRuntimeError("layout-radial expects a turtle agentset"))
  links_value isa AgentSet && links_value.kind == LinkKind ||
    throw(LogoRuntimeError("layout-radial expects a link agentset"))
  root_value isa Turtle || throw(LogoRuntimeError("layout-radial expects a turtle root"))

  root = ensure_live_agent(world, root_value)
  node_ids = Set{Int}()
  for raw_turtle in live_agentset_members(turtles_value)
    push!(node_ids, (raw_turtle::Turtle).id)
  end

  adjacency = Dict{Int, Dict{Int, Turtle}}()
  for raw_link in live_agentset_members(links_value)
    link = raw_link::Link
    end1 = turtle_by_id(world, link.end1)
    end2 = turtle_by_id(world, link.end2)
    get!(adjacency, end1.id, Dict{Int, Turtle}())[end2.id] = end2
    get!(adjacency, end2.id, Dict{Int, Turtle}())[end1.id] = end1
  end

  root_node = RadialLayoutNode(root, nothing)
  queue = RadialLayoutNode[root_node]
  node_lookup = Dict(root.id => root_node)
  last_node = root_node
  queue_index = 1
  while queue_index <= length(queue)
    node = queue[queue_index]
    queue_index += 1
    last_node = node
    neighbors = get(adjacency, node.turtle.id, nothing)
    neighbors === nothing && continue
    for neighbor in sort!(collect(values(neighbors)), by=turtle -> turtle.id)
      neighbor.id in node_ids || continue
      haskey(node_lookup, neighbor.id) && continue
      child = RadialLayoutNode(neighbor, node)
      push!(node.children, child)
      node_lookup[neighbor.id] = child
      push!(queue, child)
    end
  end

  layout_radial_arcs!(root_node, 0.0, 360.0)

  root_x = (world.min_pxcor + world.max_pxcor) / 2.0
  root_y = (world.min_pycor + world.max_pycor) / 2.0
  max_depth = max(1.0, radial_layout_depth(last_node) + 0.2)
  x_dist_to_edge = min(world.max_pxcor - root_x, root_x - world.min_pxcor)
  y_dist_to_edge = min(world.max_pycor - root_y, root_y - world.min_pycor)
  layer_gap = min(x_dist_to_edge, y_dist_to_edge) / max_depth

  nodes = sort!(collect(values(node_lookup)), by=node -> (radial_layout_depth(node), node.turtle.id))
  for node in nodes
    depth = radial_layout_depth(node)
    heading_radians = deg2rad(node.angle)
    set_turtle_pose!(
      world,
      node.turtle,
      root_x + depth * layer_gap * sin(heading_radians),
      root_y + depth * layer_gap * cos(heading_radians),
      node.angle)
  end
  nothing
end

function layout_tutte!(world::World, turtles_value, links_value, radius_value)
  turtles_value isa AgentSet && turtles_value.kind == TurtleKind ||
    throw(LogoRuntimeError("layout-tutte expects a turtle agentset"))
  links_value isa AgentSet && links_value.kind == LinkKind ||
    throw(LogoRuntimeError("layout-tutte expects a link agentset"))

  nodes = Turtle[]
  node_ids = Set{Int}()
  for raw_turtle in live_agentset_members(turtles_value)
    turtle = raw_turtle::Turtle
    push!(nodes, turtle)
    push!(node_ids, turtle.id)
  end

  links = Link[raw_link::Link for raw_link in live_agentset_members(links_value)]
  anchors = Turtle[]
  anchor_ids = Set{Int}()
  for link in links
    end1 = turtle_by_id(world, link.end1)
    end2 = turtle_by_id(world, link.end2)
    if !(end1.id in node_ids) && !(end1.id in anchor_ids)
      push!(anchors, end1)
      push!(anchor_ids, end1.id)
    end
    if !(end2.id in node_ids) && !(end2.id in anchor_ids)
      push!(anchors, end2)
      push!(anchor_ids, end2.id)
    end
  end

  center_x, center_y = world_circle_center(world)
  layout_circle_at!(world, anchors, radius_value, center_x, center_y)
  shuffle!(world.rng, nodes)

  new_x = Float64[]
  new_y = Float64[]
  sizehint!(new_x, length(nodes))
  sizehint!(new_y, length(nodes))
  for turtle in nodes
    fx = 0.0
    fy = 0.0
    degree = 0
    for link in links
      if link.end1 == turtle.id || link.end2 == turtle.id
        other = turtle.id == link.end1 ? turtle_by_id(world, link.end2) : turtle_by_id(world, link.end1)
        fx += other.xcor
        fy += other.ycor
        degree += 1
      end
    end
    degree > 0 || throw(LogoRuntimeError("layout-tutte requires each input turtle to be connected by the linkset"))
    fx = clamp(fx / degree - turtle.xcor, -100.0, 100.0) + turtle.xcor
    fy = clamp(fy / degree - turtle.ycor, -100.0, 100.0) + turtle.ycor
    push!(new_x, clamp(fx, Float64(world.min_pxcor), Float64(world.max_pxcor)))
    push!(new_y, clamp(fy, Float64(world.min_pycor), Float64(world.max_pycor)))
  end

  for index in eachindex(nodes)
    turtle = nodes[index]
    set_turtle_pose!(world, turtle, new_x[index], new_y[index], turtle.heading)
  end
  nothing
end

function layout_spring!(world::World, turtles_value, links_value, spring_value, length_value, repulsion_value)
  turtles_value isa AgentSet && turtles_value.kind == TurtleKind ||
    throw(LogoRuntimeError("layout-spring expects a turtle agentset"))
  links_value isa AgentSet && links_value.kind == LinkKind ||
    throw(LogoRuntimeError("layout-spring expects a link agentset"))

  nodes = Turtle[raw_turtle::Turtle for raw_turtle in live_agentset_members(turtles_value)]
  node_count = length(nodes)
  node_count == 0 && return nothing

  spring_constant = numeric(spring_value)
  spring_length = numeric(length_value)
  repulsion_constant = numeric(repulsion_value)

  shuffle!(world.rng, nodes)
  node_index = Dict{Int, Int}()
  for (index, turtle) in enumerate(nodes)
    node_index[turtle.id] = index
  end

  ax = zeros(Float64, node_count)
  ay = zeros(Float64, node_count)
  deg_count = zeros(Int, node_count)
  links = Link[raw_link::Link for raw_link in live_agentset_members(links_value)]

  for link in links
    end1 = turtle_by_id(world, link.end1)
    end2 = turtle_by_id(world, link.end2)
    if haskey(node_index, end1.id)
      deg_count[node_index[end1.id]] += 1
    end
    if haskey(node_index, end2.id)
      deg_count[node_index[end2.id]] += 1
    end
  end

  for link in links
    end1 = turtle_by_id(world, link.end1)
    end2 = turtle_by_id(world, link.end2)
    dx = 0.0
    dy = 0.0

    end1_index = get(node_index, end1.id, 0)
    end2_index = get(node_index, end2.id, 0)
    end1_degree = end1_index == 0 ? 0 : deg_count[end1_index]
    end2_degree = end2_index == 0 ? 0 : deg_count[end2_index]
    div = max((end1_degree + end2_degree) / 2.0, 1.0)
    dist = distance_between_nowrap(world, end1.xcor, end1.ycor, end2.xcor, end2.ycor)

    if dist == 0.0
      dx += (spring_constant * spring_length) / div
    else
      force = spring_constant * (dist - spring_length) / div
      dx += force * (end2.xcor - end1.xcor) / dist
      dy += force * (end2.ycor - end1.ycor) / dist
    end

    if end1_index != 0
      ax[end1_index] += dx
      ay[end1_index] += dy
    end
    if end2_index != 0
      ax[end2_index] -= dx
      ay[end2_index] -= dy
    end
  end

  for i in 1:node_count
    turtle1 = nodes[i]
    for j in (i + 1):node_count
      turtle2 = nodes[j]
      dx = 0.0
      dy = 0.0
      div = max((deg_count[i] + deg_count[j]) / 2.0, 1.0)

      if turtle2.xcor == turtle1.xcor && turtle2.ycor == turtle1.ycor
        angle = 360.0 * rand(world.rng)
        dx = -(repulsion_constant / div * sin(deg2rad(angle)))
        dy = -(repulsion_constant / div * cos(deg2rad(angle)))
      else
        dist = distance_between_nowrap(world, turtle1.xcor, turtle1.ycor, turtle2.xcor, turtle2.ycor)
        force = repulsion_constant / (dist * dist) / div
        dx = -(force * (turtle2.xcor - turtle1.xcor) / dist)
        dy = -(force * (turtle2.ycor - turtle1.ycor) / dist)
      end

      ax[i] += dx
      ay[i] += dy
      ax[j] -= dx
      ay[j] -= dy
    end
  end

  if node_count > 1
    perturb_amt = (world_width(world) + world_height(world)) / 1.0e10
    ax[1] += rand(world.rng) * perturb_amt - perturb_amt / 2.0
    ay[1] += rand(world.rng) * perturb_amt - perturb_amt / 2.0
  end

  limit = (world_width(world) + world_height(world)) / 50.0
  for (index, turtle) in enumerate(nodes)
    fx = clamp(ax[index], -limit, limit)
    fy = clamp(ay[index], -limit, limit)
    new_x = clamp(turtle.xcor + fx, Float64(world.min_pxcor), Float64(world.max_pxcor))
    new_y = clamp(turtle.ycor + fy, Float64(world.min_pycor), Float64(world.max_pycor))
    move_turtle_to!(world, turtle, new_x, new_y)
  end
  nothing
end

function create_turtles_command!(
  context::Context,
  count_value;
  breed::AbstractString="TURTLES",
  ordered::Bool=false,
  block::Union{Nothing, BlockNode}=nothing)
  world = context.runtime.world
  count = Int(floor(numeric(count_value)))
  count > 0 || return nothing
  canonical_breed = canonical_name(breed)
  canonical_breed == "TURTLES" || has_turtle_breed(context.runtime.model, canonical_breed) ||
    throw(LogoRuntimeError("unknown turtle breed $breed"))

  newborns = AbstractAgent[]
  for index in 0:(count - 1)
    heading = ordered ? ordered_turtle_heading(index, count) : nothing
    color = ordered ? ordered_turtle_color(index) : nothing
    push!(newborns, create_turtle!(world; breed=canonical_breed, heading=heading, color=color))
  end
  block !== nothing && run_block_for_agents!(context, newborns, block, true)
  nothing
end

function inherited_hatch_own(world::World, parent::Turtle, breed::String)
  values = default_turtle_own(world, breed)
  for name in keys(values)
    haskey(parent.own, name) && (values[name] = copy_logo_slot_value(parent.own[name]))
  end
  values
end

function hatch_turtles!(
  context::Context,
  count_value;
  breed::Union{Nothing, AbstractString}=nothing,
  block::Union{Nothing, BlockNode}=nothing)
  world = context.runtime.world
  parent = ensure_live_agent(world, context.agent::Turtle)
  count = Int(floor(numeric(count_value)))
  count > 0 || return nothing
  canonical_breed = breed === nothing ? parent.breed : canonical_name(breed)
  canonical_breed == "TURTLES" || has_turtle_breed(context.runtime.model, canonical_breed) ||
    throw(LogoRuntimeError("unknown turtle breed $breed"))

  newborns = AbstractAgent[]
  for _ in 1:count
    push!(newborns, create_turtle!(
      world;
      breed=canonical_breed,
      x=parent.xcor,
      y=parent.ycor,
      heading=parent.heading,
      color=parent.color,
      shape=canonical_breed == parent.breed ? parent.shape : "default",
      label=parent.label,
      label_color=parent.label_color,
      hidden=parent.hidden,
      size=parent.size,
      pen_size=parent.pen_size,
      pen_mode=parent.pen_mode,
      own=inherited_hatch_own(world, parent, canonical_breed)))
  end
  block !== nothing && run_block_for_agents!(context, newborns, block, true)
  nothing
end

function sprout_turtles!(
  context::Context,
  count_value;
  breed::AbstractString="TURTLES",
  block::Union{Nothing, BlockNode}=nothing)
  world = context.runtime.world
  patch = context.agent::Patch
  count = Int(floor(numeric(count_value)))
  count > 0 || return nothing
  canonical_breed = canonical_name(breed)
  canonical_breed == "TURTLES" || has_turtle_breed(context.runtime.model, canonical_breed) ||
    throw(LogoRuntimeError("unknown turtle breed $breed"))

  newborns = AbstractAgent[]
  for _ in 1:count
    push!(newborns, create_turtle!(world; breed=canonical_breed, x=Float64(patch.pxcor), y=Float64(patch.pycor)))
  end
  block !== nothing && run_block_for_agents!(context, newborns, block, true)
  nothing
end

function die_current_agent!(context::Context)
  if context.agent isa Turtle
    kill_turtle!(context.runtime.world, context.agent)
  elseif context.agent isa Link
    kill_link!(context.runtime.world, context.agent)
  else
    throw(LogoRuntimeError("die is only available to turtles and links"))
  end
  nothing
end

function n_values(context::Context, count_value, task::AbstractReporterTaskValue)
  count = Int(floor(numeric(count_value)))
  count >= 0 || throw(LogoRuntimeError("n-values expects a non-negative count"))
  results = sizehint!(Any[], count)
  actuals = Vector{Any}(undef, 1)
  for index in 0:(count - 1)
    actuals[1] = Float64(index)
    push!(results, invoke_reporter_task(context, task, actuals))
  end
  results
end

function foreach_values!(context::Context, task::AbstractCommandTaskValue, value)
  minimum_inputs = command_task_minimum_inputs(task)
  minimum_inputs <= 1 || throw(task_arity_error("anonymous procedure", minimum_inputs, 1))
  list = list_argument(value, "foreach")
  actuals = Vector{Any}(undef, 1)
  for item in list
    actuals[1] = item
    invoke_command_task(context, task, actuals)
  end
  nothing
end

function foreach_values!(context::Context, task::AbstractCommandTaskValue, values...)
  lists = parallel_lists("foreach", values...)
  minimum_inputs = command_task_minimum_inputs(task)
  isempty(lists) && minimum_inputs > 0 && throw(task_arity_error("anonymous procedure", minimum_inputs, 0))
  length(lists) >= minimum_inputs || throw(task_arity_error("anonymous procedure", minimum_inputs, length(lists)))
  actuals = Vector{Any}(undef, length(lists))
  for index in 1:(isempty(lists) ? 0 : length(first(lists)))
    for i in eachindex(lists)
      @inbounds actuals[i] = lists[i][index]
    end
    invoke_command_task(context, task, actuals)
  end
  nothing
end

function filter_agentset(context::Context, agentset::AgentSet, block::ReporterBlockNode)
  members = sizehint!(AbstractAgent[], agentset_capacity(agentset))
  caller = block_caller(context)
  @for_agents agent agentset begin
    logical(eval_reporter_block(context, block, agent, caller)) && push!(members, agent)
  end
  owned_agentset(agentset.kind, members; breed=agentset.breed)
end

@inline function with_call_components(call::ReporterCall)
  length(call.args) == 1 || return nothing
  arg = call.args[1]
  arg isa ReporterCall || return nothing
  arg.name == "WITH" || return nothing
  length(arg.args) == 2 || return nothing
  arg.args[2] isa ReporterBlockNode || return nothing
  arg.args
end

function count_with_fastpath(context::Context, call::ReporterCall)
  with_args = with_call_components(call)
  with_args === nothing && return nothing
  base = eval_expr(context, with_args[1])
  base isa AgentSet || return nothing
  block = with_args[2]::ReporterBlockNode
  caller = block_caller(context)
  matched = 0
  @for_agents agent base begin
    logical(eval_reporter_block(context, block, agent, caller)) && (matched += 1)
  end
  Float64(matched)
end

"""
Fast path for `any? turtles-here`, `any? other turtles-here`, and breed-here variants.
Returns Bool or nothing (if pattern doesn't match).
"""
function any_turtles_here_fastpath(context::Context, call::ReporterCall)
  length(call.args) == 1 || return nothing
  arg = call.args[1]
  arg isa ReporterCall || return nothing

  # Detect `any? other X` wrapper
  is_other = false
  inner = arg
  if arg.name == "OTHER" && length(arg.args) == 1
    inner_arg = arg.args[1]
    inner_arg isa ReporterCall || return nothing
    is_other = true
    inner = inner_arg
  end

  # Must be TURTLES-HERE (or a breed-here)
  (inner.name == "TURTLES-HERE" || endswith(inner.name, "-HERE")) || return nothing
  length(inner.args) == 0 || return nothing

  agent = context.agent
  (agent isa Turtle || agent isa Patch) || return nothing
  world = context.runtime.world
  patch = agent isa Patch ? agent : current_patch(world, agent)
  th = patch.turtles_here

  # Filter by breed if breed-here variant
  breed_filter = inner.name == "TURTLES-HERE" ? nothing : rstrip_here(inner.name)

  current_id = is_other && agent isa Turtle ? agent.id : -1

  for id in th
    id == current_id && continue
    turtle = maybe_turtle_by_id(world, id)
    turtle === nothing && continue
    if breed_filter !== nothing && turtle.breed != breed_filter
      continue
    end
    return true
  end
  return false
end

@inline function rstrip_here(name::String)
  # "SHEEP-HERE" -> "SHEEP"
  endswith(name, "-HERE") ? name[1:end-5] : name
end

function any_with_fastpath(context::Context, call::ReporterCall)
  with_args = with_call_components(call)
  with_args === nothing && return nothing
  base = eval_expr(context, with_args[1])
  base isa AgentSet || return nothing
  block = with_args[2]::ReporterBlockNode
  caller = block_caller(context)
  @for_agents agent base begin
    logical(eval_reporter_block(context, block, agent, caller)) && return true
  end
  false
end

@inline function of_call_components(call::ReporterCall)
  length(call.args) == 1 || return nothing
  arg = call.args[1]
  arg isa ReporterCall || return nothing
  arg.name == "OF" || return nothing
  length(arg.args) == 2 || return nothing
  arg.args[1] isa ReporterBlockNode || return nothing
  arg.args
end

function sum_of_fastpath(context::Context, call::ReporterCall)
  of_args = of_call_components(call)
  of_args === nothing && return nothing
  target = eval_expr(context, of_args[2])
  target isa AgentSet || return nothing
  block = of_args[1]::ReporterBlockNode
  caller = block_caller(context)
  total = 0.0
  @for_agents agent target begin
    value = eval_reporter_block(context, block, agent, caller)
    is_logo_number(value) && (total += Float64(value))
  end
  total
end

function mean_of_fastpath(context::Context, call::ReporterCall)
  of_args = of_call_components(call)
  of_args === nothing && return nothing
  target = eval_expr(context, of_args[2])
  target isa AgentSet || return nothing
  block = of_args[1]::ReporterBlockNode
  caller = block_caller(context)
  total = 0.0
  matched = 0
  sampled = nothing
  @for_agents agent target begin
    value = eval_reporter_block(context, block, agent, caller)
    if is_logo_number(value)
      total += Float64(value)
      matched += 1
    elseif matched == 0
      sampled === nothing && (sampled = Any[])
      push!(sampled::Vector{Any}, value)
    end
  end
  matched > 0 || throw(aggregate_numeric_error("mean", sampled === nothing ? Any[] : sampled))
  total / matched
end

@inline function count_on_components(call::ReporterCall)
  length(call.args) == 1 || return nothing
  arg = call.args[1]
  arg isa ReporterCall || return nothing
  if arg.name == "TURTLES-ON"
    length(arg.args) == 1 || return nothing
    return (:turtles, nothing, arg.args[1], "turtles-on")
  elseif arg.name == "TURTLE-BREED-ON"
    length(arg.args) == 2 || return nothing
    arg.args[1] isa SymbolArg || return nothing
    breed = symbol_arg_name(arg.args[1])
    return (:turtles, breed, arg.args[2], "$(lowercase(breed))-on")
  elseif arg.name == "PATCHES-ON"
    length(arg.args) == 1 || return nothing
    return (:patches, nothing, arg.args[1], "patches-on")
  end
  nothing
end

function count_on_fastpath(context::Context, call::ReporterCall)
  components = count_on_components(call)
  components === nothing && return nothing
  kind, breed, source_arg, opname = components
  source = eval_expr(context, source_arg)
  if kind == :turtles
    return Float64(count_turtles_on_sources(context.runtime.world, source; breed=breed, opname=opname))
  end
  Float64(length(source_patch_keys(context.runtime.world, source, opname)))
end

function one_of_with_fastpath(context::Context, call::ReporterCall)
  with_args = with_call_components(call)
  with_args === nothing && return nothing
  base = eval_expr(context, with_args[1])
  base isa AgentSet || return nothing
  block = with_args[2]::ReporterBlockNode
  caller = block_caller(context)
  rng = context.runtime.world.rng
  chosen = NOBODY
  matched = 0
  @for_agents agent base begin
    logical(eval_reporter_block(context, block, agent, caller)) || continue
    matched += 1
    rand(rng, 1:matched) == 1 && (chosen = agent)
  end
  chosen
end

function all_agentset(context::Context, agentset::AgentSet, block::ReporterBlockNode)
  caller = block_caller(context)
  @for_agents agent agentset begin
    value = eval_reporter_block(context, block, agent, caller)
    value isa Bool || throw(LogoRuntimeError("ALL? expected a true/false value from $(logo_string(agent)), but got $(error_logo_string(value)) instead."))
    value || return false
  end
  true
end

function of_value(context::Context, block::ReporterBlockNode, target)
  caller = block_caller(context)
  if target isa AgentSet
    _members, _all_live = agentset_members_for_iteration(target)
    result = Vector{Any}(undef, length(_members))
    _j = 0
    @inbounds for _i in eachindex(_members)
      agent = _members[_i]
      if _all_live || agent_is_live(agent)
        _j += 1
        result[_j] = eval_reporter_block(context, block, agent, caller)
      end
    end
    resize!(result, _j)
    return result
  elseif target isa AbstractAgent
    eval_reporter_block(context, block, target, caller)
  else
    throw(LogoRuntimeError("of expects an agent or agentset"))
  end
end

function run_block_for_agents!(
  context::Context,
  agent::AbstractAgent,
  block::BlockNode,
  random_order::Bool)
  direct_stmt = single_noscope_stmt(block)
  direct_stmts = direct_stmt === nothing ? noscope_statements(block) : nothing
  saved_agent = context.agent
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  live_agent = ensure_live_agent(context.runtime.world, agent)
  try
    context.caller = saved_agent
    context.in_ask = true
    context.agent = live_agent
    if block.may_stop
      try
        execute_block_fast!(context, block, direct_stmt, direct_stmts, true)
      catch signal
        signal isa StopSignal || rethrow()
      end
    else
      execute_block_fast!(context, block, direct_stmt, direct_stmts, true)
    end
  finally
    context.agent = saved_agent
    context.caller = saved_caller
    context.in_ask = saved_in_ask
  end
  nothing
end

run_block_for_agents!(context::Context, agent::AbstractAgent, block::BlockNode) =
  run_block_for_agents!(context, agent, block, false)

@inline function execute_small_ask_agent!(
  context::Context,
  agent::AbstractAgent,
  block::BlockNode,
  direct_stmt::Union{Nothing, CommandCall}=single_noscope_stmt(block),
  direct_stmts::Union{Nothing, Vector{AbstractStmt}}=(direct_stmt === nothing ? noscope_statements(block) : nothing))
  agent_is_live(agent) || return nothing
  context.agent = agent
  if block.may_stop
    try
      execute_block_fast!(context, block, direct_stmt, direct_stmts, true)
    catch signal
      signal isa StopSignal || rethrow()
    end
  else
    execute_block_fast!(context, block, direct_stmt, direct_stmts, true)
  end
  nothing
end

function run_block_for_agents!(
  context::Context,
  agents::AbstractVector{<:AbstractAgent},
  block::BlockNode,
  random_order::Bool)
  direct_stmt = single_noscope_stmt(block)
  direct_stmts = direct_stmt === nothing ? noscope_statements(block) : nothing
  saved_agent = context.agent
  saved_caller = context.caller
  saved_in_ask = context.in_ask
  count = length(agents)
  if count == 0
    return nothing
  elseif count == 1
    single = agents[1]
    agent_is_live(single) || return nothing
    return run_block_for_agents!(context, single, block, random_order)
  end
  iter_agents = agents
  used_buffer = false
  try
    context.caller = saved_agent
    context.in_ask = true
    if random_order && count == 2
      first = agents[1]
      second = agents[2]
      if rand(context.runtime.world.rng, Bool)
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
      else
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
      end
    elseif random_order && count == 3
      first = agents[1]
      second = agents[2]
      third = agents[3]
      order = rand(context.runtime.world.rng, 1:6)
      if order == 1
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, third, block, direct_stmt, direct_stmts)
      elseif order == 2
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, third, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
      elseif order == 3
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, third, block, direct_stmt, direct_stmts)
      elseif order == 4
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, third, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
      elseif order == 5
        execute_small_ask_agent!(context, third, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
      else
        execute_small_ask_agent!(context, third, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, second, block, direct_stmt, direct_stmts)
        execute_small_ask_agent!(context, first, block, direct_stmt, direct_stmts)
      end
    else
      if random_order
        shuffled = acquire_agent_iteration_buffer!(context.runtime, agents)
        shuffle!(context.runtime.world.rng, shuffled)
        iter_agents = shuffled
        used_buffer = true
      end
      if direct_stmt === nothing && direct_stmts === nothing
        if block.may_stop
          for agent in iter_agents
            agent_is_live(agent) || continue
            context.agent = agent
            try
              execute_block!(context, block)
            catch signal
              signal isa StopSignal || rethrow()
            end
          end
        else
          for agent in iter_agents
            agent_is_live(agent) || continue
            context.agent = agent
            execute_block!(context, block)
          end
        end
      elseif direct_stmt === nothing
        if block.may_stop
          for agent in iter_agents
            agent_is_live(agent) || continue
            context.agent = agent
            try
              execute_noscope_block!(context, direct_stmts::Vector{AbstractStmt})
            catch signal
              signal isa StopSignal || rethrow()
            end
          end
        else
          for agent in iter_agents
            agent_is_live(agent) || continue
            context.agent = agent
            execute_noscope_block!(context, direct_stmts::Vector{AbstractStmt})
          end
        end
      else
        if block.may_stop
          for agent in iter_agents
            agent_is_live(agent) || continue
            context.agent = agent
            try
              execute_stmt!(context, direct_stmt)
            catch signal
              signal isa StopSignal || rethrow()
            end
          end
        else
          for agent in iter_agents
            agent_is_live(agent) || continue
            context.agent = agent
            execute_stmt!(context, direct_stmt)
          end
        end
      end
    end
  finally
    used_buffer && release_agent_iteration_buffer!(context.runtime)
    context.agent = saved_agent
    context.caller = saved_caller
    context.in_ask = saved_in_ask
  end
  nothing
end

run_block_for_agents!(context::Context, agents::AbstractVector{<:AbstractAgent}, block::BlockNode) =
  run_block_for_agents!(context, agents, block, false)

function build_default_registry()
  registry = PrimitiveRegistry()

  register_primitive!(registry, "CLEAR-ALL", COMMAND, command_syntax(agent_classes="O---"),
    function (ctx, args)
      clear_all_runtime!(ctx.runtime)
    end)
  register_primitive!(registry, "CA", COMMAND, command_syntax(agent_classes="O---"),
    function (ctx, args)
      clear_all_runtime!(ctx.runtime)
    end)
  register_primitive!(registry, "__CLEAR-ALL-AND-RESET-TICKS", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> clear_all_and_reset_ticks_command!(ctx))
  register_primitive!(registry, "CLEAR-GLOBALS", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_globals!(ctx.runtime.world))
  register_primitive!(registry, "CLEAR-DRAWING", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> (ctx.runtime.world.drawing === nothing ? nothing : clear_drawing!(ctx.runtime.world)))
  register_primitive!(registry, "CD", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> (ctx.runtime.world.drawing === nothing ? nothing : clear_drawing!(ctx.runtime.world)))
  register_primitive!(registry, "PEN-DOWN", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "down"
      nothing
    end)
  register_primitive!(registry, "PENDOWN", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "down"
      nothing
    end)
  register_primitive!(registry, "PD", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "down"
      nothing
    end)
  register_primitive!(registry, "PEN-UP", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "up"
      nothing
    end)
  register_primitive!(registry, "PENUP", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "up"
      nothing
    end)
  register_primitive!(registry, "PU", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "up"
      nothing
    end)
  register_primitive!(registry, "PEN-ERASE", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "erase"
      nothing
    end)
  register_primitive!(registry, "PE", COMMAND, command_syntax(agent_classes="-T--"),
    function (ctx, args)
      (ctx.agent::Turtle).pen_mode = "erase"
      nothing
    end)
  register_primitive!(registry, "STAMP", COMMAND, command_syntax(agent_classes="-T-L"),
    (ctx, args) -> begin
      if ctx.agent isa Turtle
        stamp_agent!(ctx.runtime.world, ctx.agent; erase=false, custom_shapes=ctx.runtime.custom_turtle_shapes)
      else
        stamp_agent!(ctx.runtime.world, ctx.agent; erase=false)
      end
    end)
  register_primitive!(registry, "STAMP-ERASE", COMMAND, command_syntax(agent_classes="-T-L"),
    (ctx, args) -> begin
      if ctx.agent isa Turtle
        stamp_agent!(ctx.runtime.world, ctx.agent; erase=true, custom_shapes=ctx.runtime.custom_turtle_shapes)
      else
        stamp_agent!(ctx.runtime.world, ctx.agent; erase=true)
      end
    end)
  # hide/show turtle
  register_primitive!(registry, "HIDE-TURTLE", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> begin (ctx.agent::Turtle).hidden = true; nothing end)
  register_primitive!(registry, "HT", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> begin (ctx.agent::Turtle).hidden = true; nothing end)
  register_primitive!(registry, "SHOW-TURTLE", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> begin (ctx.agent::Turtle).hidden = false; nothing end)
  register_primitive!(registry, "ST", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> begin (ctx.agent::Turtle).hidden = false; nothing end)
  # hide/show link
  register_primitive!(registry, "HIDE-LINK", COMMAND, command_syntax(agent_classes="---L"),
    (ctx, args) -> begin (ctx.agent::Link).hidden = true; nothing end)
  register_primitive!(registry, "SHOW-LINK", COMMAND, command_syntax(agent_classes="---L"),
    (ctx, args) -> begin (ctx.agent::Link).hidden = false; nothing end)
  register_primitive!(registry, "CLEAR-LINKS", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_links!(ctx.runtime.world))
  register_primitive!(registry, "CLEAR-PATCHES", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_patches!(ctx.runtime.world))
  register_primitive!(registry, "CP", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_patches!(ctx.runtime.world))
  register_primitive!(registry, "CLEAR-TICKS", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_ticks!(ctx.runtime.world))
  register_primitive!(registry, "CLEAR-TURTLES", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_turtles!(ctx.runtime.world))
  register_primitive!(registry, "CT", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> clear_turtles!(ctx.runtime.world))
  register_primitive!(registry, "SET-TOPOLOGY", COMMAND, command_syntax(right=[BooleanType, BooleanType], agent_classes="O---"),
    (ctx, args) -> set_topology!(ctx.runtime.world, logical(args[1]), logical(args[2])))
  register_primitive!(registry, "RESIZE-WORLD", COMMAND, command_syntax(right=[NumberType, NumberType, NumberType, NumberType], agent_classes="O---"),
    (ctx, args) -> resize_world_command!(ctx.runtime.world, args[1], args[2], args[3], args[4]))
  register_primitive!(registry, "SET-PATCH-SIZE", COMMAND, command_syntax(right=[NumberType], agent_classes="O---"),
    (ctx, args) -> set_patch_size!(ctx.runtime.world, args[1]))
  register_primitive!(registry, "SET-DEFAULT-SHAPE", COMMAND, command_syntax(right=[AgentsetType, StringType], agent_classes="O---"),
    (ctx, args) -> set_default_shape_command!(ctx, args[1], args[2]))
  register_primitive!(registry, "RESET-TICKS", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> reset_ticks_command!(ctx))
  register_primitive!(registry, "TICK", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> tick_command!(ctx))
  register_primitive!(registry, "TICK-ADVANCE", COMMAND, command_syntax(right=[NumberType], agent_classes="O---"),
    (ctx, args) -> tick_advance!(ctx.runtime.world, args[1]))
  register_primitive!(registry, "RESET-TIMER", COMMAND, command_syntax(agent_classes="O---"), (ctx, args) -> reset_timer!(ctx.runtime.world))
  register_primitive!(registry, "WAIT", COMMAND, command_syntax(right=[NumberType]),
    (ctx, args) -> wait_seconds(args[1]))
  # display/no-display: headless no-ops
  register_primitive!(registry, "DISPLAY", COMMAND, command_syntax(), (ctx, args) -> nothing)
  register_primitive!(registry, "NO-DISPLAY", COMMAND, command_syntax(), (ctx, args) -> nothing)
  register_primitive!(registry, "SHOW", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_command_output!(ctx.runtime, output_object_text(args[1]; owner=ctx.agent, add_newline=true, readable=true))
      nothing
    end)
  register_primitive!(registry, "PRINT", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_command_output!(ctx.runtime, output_object_text(args[1]; add_newline=true))
      nothing
    end)
  register_primitive!(registry, "TYPE", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_command_output!(ctx.runtime, output_object_text(args[1]))
      nothing
    end)
  register_primitive!(registry, "WRITE", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_command_output!(ctx.runtime, output_object_text(args[1]; readable=true))
      nothing
    end)
  register_primitive!(registry, "OUTPUT-SHOW", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_output_area!(ctx.runtime, output_object_text(args[1]; owner=ctx.agent, add_newline=true, readable=true))
      nothing
    end)
  register_primitive!(registry, "OUTPUT-PRINT", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_output_area!(ctx.runtime, output_object_text(args[1]; add_newline=true))
      nothing
    end)
  register_primitive!(registry, "OUTPUT-TYPE", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_output_area!(ctx.runtime, output_object_text(args[1]))
      nothing
    end)
  register_primitive!(registry, "OUTPUT-WRITE", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_output_area!(ctx.runtime, output_object_text(args[1]; readable=true))
      nothing
    end)
  register_primitive!(registry, "CLEAR-OUTPUT", COMMAND, command_syntax(),
    function (ctx, args)
      clear_output_area!(ctx.runtime)
      nothing
    end)
  register_primitive!(registry, "USER-YES-OR-NO?", REPORTER, reporter_syntax(right=[StringType], ret=BooleanType),
    (ctx, args) -> headless_user_cancel())
  register_primitive!(registry, "USER-ONE-OF", REPORTER, reporter_syntax(right=[StringType, ListType], ret=WildcardType),
    (ctx, args) -> headless_user_cancel())
  register_primitive!(registry, "USER-INPUT", REPORTER, reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> headless_user_cancel())
  register_primitive!(registry, "USER-FILE", REPORTER, reporter_syntax(ret=WildcardType),
    (ctx, args) -> false)
  register_primitive!(registry, "USER-NEW-FILE", REPORTER, reporter_syntax(ret=WildcardType),
    (ctx, args) -> false)
  register_primitive!(registry, "USER-DIRECTORY", REPORTER, reporter_syntax(ret=WildcardType),
    (ctx, args) -> false)
  register_primitive!(registry, "USER-MESSAGE", COMMAND, command_syntax(right=[WildcardType]),
    (ctx, args) -> nothing)  # headless: silently ignore

  # BUT-LAST alias (BL/BUTLAST already registered)
  register_primitive!(registry, "BUT-LAST", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_butlast(args[1]))

  # Movie primitives (headless stubs)
  register_primitive!(registry, "MOVIE-START", COMMAND, command_syntax(right=[StringType]),
    (ctx, args) -> nothing)
  register_primitive!(registry, "MOVIE-GRAB-VIEW", COMMAND, command_syntax(),
    (ctx, args) -> nothing)
  register_primitive!(registry, "MOVIE-GRAB-INTERFACE", COMMAND, command_syntax(),
    (ctx, args) -> nothing)
  register_primitive!(registry, "MOVIE-CLOSE", COMMAND, command_syntax(),
    (ctx, args) -> nothing)
  register_primitive!(registry, "MOVIE-CANCEL", COMMAND, command_syntax(),
    (ctx, args) -> nothing)
  register_primitive!(registry, "MOVIE-SET-FRAME-RATE", COMMAND, command_syntax(right=[NumberType]),
    (ctx, args) -> nothing)
  register_primitive!(registry, "MOVIE-STATUS", REPORTER, reporter_syntax(ret=StringType),
    (ctx, args) -> "No movie.")

  # HubNet primitives (headless stubs)
  register_primitive!(registry, "HUBNET-RESET", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-RESET-PERSPECTIVE", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-SEND", COMMAND, command_syntax(right=[WildcardType, StringType, WildcardType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-BROADCAST", COMMAND, command_syntax(right=[StringType, WildcardType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-BROADCAST-CLEAR-OUTPUT", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-BROADCAST-MESSAGE", COMMAND, command_syntax(right=[WildcardType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-FETCH-MESSAGE", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-MESSAGE-WAITING?", REPORTER, reporter_syntax(ret=BooleanType, agent_classes="O---"),
    (ctx, args) -> false)
  register_primitive!(registry, "HUBNET-MESSAGE", REPORTER, reporter_syntax(ret=WildcardType, agent_classes="O---"),
    (ctx, args) -> "")
  register_primitive!(registry, "HUBNET-MESSAGE-SOURCE", REPORTER, reporter_syntax(ret=StringType, agent_classes="O---"),
    (ctx, args) -> "")
  register_primitive!(registry, "HUBNET-MESSAGE-TAG", REPORTER, reporter_syntax(ret=StringType, agent_classes="O---"),
    (ctx, args) -> "")
  register_primitive!(registry, "HUBNET-ENTER-MESSAGE?", REPORTER, reporter_syntax(ret=BooleanType, agent_classes="O---"),
    (ctx, args) -> false)
  register_primitive!(registry, "HUBNET-EXIT-MESSAGE?", REPORTER, reporter_syntax(ret=BooleanType, agent_classes="O---"),
    (ctx, args) -> false)
  register_primitive!(registry, "HUBNET-CLIENTS-LIST", REPORTER, reporter_syntax(ret=ListType, agent_classes="O---"),
    (ctx, args) -> Any[])
  register_primitive!(registry, "HUBNET-KICK-CLIENT", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-KICK-ALL-CLIENTS", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-SET-CLIENT-INTERFACE", COMMAND, command_syntax(right=[StringType, ListType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-SEND-CLEAR-OUTPUT", COMMAND, command_syntax(right=[WildcardType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-SEND-FOLLOW", COMMAND, command_syntax(right=[WildcardType, WildcardType, NumberType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-SEND-WATCH", COMMAND, command_syntax(right=[WildcardType, WildcardType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "HUBNET-SEND-MESSAGE", COMMAND, command_syntax(right=[WildcardType, WildcardType], agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "SET-CURRENT-PLOT", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> set_current_plot!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "CREATE-TEMPORARY-PLOT-PEN", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> create_temporary_plot_pen!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "SET-CURRENT-PLOT-PEN", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> set_current_plot_pen!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "CLEAR-PLOT", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> clear_current_plot!(ctx.runtime))
  register_primitive!(registry, "CLEAR-ALL-PLOTS", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> clear_all_plots!(ctx.runtime))
  register_primitive!(registry, "SETUP-PLOTS", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> setup_plots!(ctx))
  register_primitive!(registry, "UPDATE-PLOTS", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> update_plots!(ctx))
  register_primitive!(registry, "PLOT", COMMAND, command_syntax(right=[NumberType], agent_classes="OTPL"),
    (ctx, args) -> plot_y!(ctx.runtime, args[1]))
  register_primitive!(registry, "PLOTXY", COMMAND, command_syntax(right=[NumberType, NumberType], agent_classes="OTPL"),
    (ctx, args) -> plot_xy!(ctx.runtime, args[1], args[2]))
  register_primitive!(registry, "HISTOGRAM", COMMAND, command_syntax(right=[ListType], agent_classes="OTPL"),
    (ctx, args) -> histogram!(ctx.runtime, args[1]))
  register_primitive!(registry, "SET-HISTOGRAM-NUM-BARS", COMMAND, command_syntax(right=[NumberType], agent_classes="OTPL"),
    (ctx, args) -> set_histogram_num_bars!(ctx.runtime, args[1]))
  register_primitive!(registry, "SET-PLOT-PEN-INTERVAL", COMMAND, command_syntax(right=[NumberType], agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_interval!(ctx.runtime, args[1]))
  register_primitive!(registry, "SET-PLOT-PEN-MODE", COMMAND, command_syntax(right=[NumberType], agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_mode!(ctx.runtime, args[1]))
  register_primitive!(registry, "SET-PLOT-PEN-COLOR", COMMAND, command_syntax(right=[NumberType | ListType], agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_color!(ctx.runtime, args[1]))
  register_primitive!(registry, "PLOT-PEN-DOWN", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_down!(ctx.runtime, true))
  register_primitive!(registry, "PLOT-PEN-UP", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_down!(ctx.runtime, false))
  register_primitive!(registry, "PLOT-PEN-RESET", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> reset_plot_pen!(ctx.runtime))
  register_primitive!(registry, "__PLOT-PEN-HIDE", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_hidden!(ctx.runtime, true))
  register_primitive!(registry, "__PLOT-PEN-SHOW", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_pen_hidden!(ctx.runtime, false))
  register_primitive!(registry, "AUTO-PLOT-ON", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_autoplot!(ctx.runtime, true, true))
  register_primitive!(registry, "AUTO-PLOT-OFF", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_autoplot!(ctx.runtime, false, false))
  register_primitive!(registry, "AUTO-PLOT-X-ON", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_autoplot!(ctx.runtime, true, plot_autoplot_y(ctx.runtime)))
  register_primitive!(registry, "AUTO-PLOT-Y-ON", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_autoplot!(ctx.runtime, plot_autoplot_x(ctx.runtime), true))
  register_primitive!(registry, "AUTO-PLOT-X-OFF", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_autoplot!(ctx.runtime, false, plot_autoplot_y(ctx.runtime)))
  register_primitive!(registry, "AUTO-PLOT-Y-OFF", COMMAND, command_syntax(agent_classes="OTPL"),
    (ctx, args) -> set_plot_autoplot!(ctx.runtime, plot_autoplot_x(ctx.runtime), false))
  register_primitive!(registry, "SET-PLOT-X-RANGE", COMMAND, command_syntax(right=[NumberType, NumberType], agent_classes="OTPL"),
    (ctx, args) -> set_plot_range!(ctx.runtime, args[1], args[2]; is_x=true))
  register_primitive!(registry, "SET-PLOT-Y-RANGE", COMMAND, command_syntax(right=[NumberType, NumberType], agent_classes="OTPL"),
    (ctx, args) -> set_plot_range!(ctx.runtime, args[1], args[2]; is_x=false))
  register_primitive!(registry, "EXPORT-PLOT", COMMAND, command_syntax(right=[StringType, StringType], agent_classes="OTPL"),
    (ctx, args) -> export_plot!(ctx.runtime, String(args[1]), String(args[2])))
  register_primitive!(registry, "EXPORT-ALL-PLOTS", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> export_all_plots!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "EXPORT-OUTPUT", COMMAND, command_syntax(right=[StringType]),
    (ctx, args) -> export_output!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "FOLLOW", COMMAND, command_syntax(right=[TurtleType], agent_classes="O---"),
    (ctx, args) -> set_perspective_subject!(ctx.runtime, require_turtle_input(ctx.runtime.world, args[1], "FOLLOW")))
  register_primitive!(registry, "WATCH", COMMAND, command_syntax(right=[TurtleType], agent_classes="O---"),
    (ctx, args) -> set_perspective_subject!(ctx.runtime, require_turtle_input(ctx.runtime.world, args[1], "WATCH")))
  register_primitive!(registry, "RIDE", COMMAND, command_syntax(right=[TurtleType], agent_classes="O---"),
    (ctx, args) -> set_perspective_subject!(ctx.runtime, require_turtle_input(ctx.runtime.world, args[1], "RIDE")))
  register_primitive!(registry, "RESET-PERSPECTIVE", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> reset_perspective!(ctx.runtime))
  register_primitive!(registry, "__MKDIR", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    function (ctx, args)
      mkpath(String(args[1]))
      nothing
    end)
  register_primitive!(registry, "EXPORT-WORLD", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> export_world!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "EXPORT-VIEW", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> export_view!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "IMPORT-WORLD", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> import_world!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "IMPORT-PCOLORS", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> import_patch_colors!(ctx.runtime, String(args[1]); as_netlogo_colors=true, opname="import-pcolors"))
  register_primitive!(registry, "IMPORT-PCOLORS-RGB", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> import_patch_colors!(ctx.runtime, String(args[1]); as_netlogo_colors=false, opname="import-pcolors-rgb"))
  register_primitive!(registry, "EXPORT-DRAWING", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> export_drawing!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "IMPORT-DRAWING", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> import_drawing!(ctx.runtime, String(args[1]); opname="import-drawing"))
  register_primitive!(registry, "FILE-CLOSE", COMMAND, command_syntax(),
    (ctx, args) -> close_current_file!(ctx.runtime))
  register_primitive!(registry, "FILE-CLOSE-ALL", COMMAND, command_syntax(),
    (ctx, args) -> close_all_files!(ctx.runtime))
  register_primitive!(registry, "FILE-DELETE", COMMAND, command_syntax(right=[StringType]),
    (ctx, args) -> delete_file!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "FILE-FLUSH", COMMAND, command_syntax(),
    (ctx, args) -> flush_current_file!(ctx.runtime))
  register_primitive!(registry, "FILE-OPEN", COMMAND, command_syntax(right=[StringType]),
    (ctx, args) -> open_file!(ctx.runtime, String(args[1])))
  register_primitive!(registry, "FILE-PRINT", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_current_file!(ctx.runtime, display_logo_string(args[1]) * "\n")
      nothing
    end)
  register_primitive!(registry, "FILE-SHOW", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_current_file!(ctx.runtime, "$(output_agent_label(ctx.agent)): $(readable_logo_string(args[1]))\n")
      nothing
    end)
  register_primitive!(registry, "FILE-TYPE", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_current_file!(ctx.runtime, display_logo_string(args[1]))
      nothing
    end)
  register_primitive!(registry, "FILE-WRITE", COMMAND, command_syntax(right=[WildcardType]),
    function (ctx, args)
      write_current_file!(ctx.runtime, " " * readable_logo_string(args[1]))
      nothing
    end)

  register_primitive!(registry, "LET", COMMAND,
    command_syntax(right=[SymbolType, WildcardType], arg_modes=[:symbol, :eval]),
    function (ctx, args)
      haskey(current_scope(ctx), args[1]) && throw(LogoRuntimeError("There is already a local variable here called $(args[1])"))
      current_scope(ctx)[args[1]] = args[2]
      nothing
    end)

  register_primitive!(registry, "SET", COMMAND,
    command_syntax(right=[SymbolType, WildcardType], arg_modes=[:symbol, :eval]),
    function (ctx, args)
      assign_variable!(ctx, args[1], args[2])
      nothing
    end)

  register_primitive!(registry, "IF", COMMAND,
    command_syntax(right=[BooleanType, CommandBlockType], arg_modes=[:eval, :block]),
    function (ctx, args)
      logical(args[1]) && execute_block!(ctx, args[2])
      nothing
    end)

  register_primitive!(registry, "IFELSE", COMMAND,
    command_syntax(right=[BooleanType, CommandBlockType, CommandBlockType], arg_modes=[:eval, :block, :block]),
    function (ctx, args)
      execute_block!(ctx, logical(args[1]) ? args[2] : args[3])
      nothing
    end)
  register_primitive!(registry, "CAREFULLY", COMMAND,
    command_syntax(right=[CommandBlockType, CommandBlockType], arg_modes=[:block, :block]),
    (ctx, args) -> carefully_execute!(ctx, args[1], args[2]))
  register_primitive!(registry, "WITH-LOCAL-RANDOMNESS", COMMAND,
    command_syntax(right=[CommandBlockType], arg_modes=[:block]),
    (ctx, args) -> with_local_randomness!(ctx, args[1]))
  register_primitive!(registry, "WITHOUT-INTERRUPTION", COMMAND,
    command_syntax(right=[CommandBlockType], arg_modes=[:block]),
    function (ctx, args)
      execute_block!(ctx, args[1])
      nothing
    end)
  register_primitive!(registry, "__IGNORE", COMMAND,
    command_syntax(right=[WildcardType]),
    (ctx, args) -> nothing)
  register_primitive!(registry, "INSPECT", COMMAND,
    command_syntax(right=[WildcardType], agent_classes="O---"),
    (ctx, args) -> inspect_agent(ctx.runtime.world, args[1]))

  register_primitive!(registry, "REPEAT", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType], arg_modes=[:eval, :block]),
    function (ctx, args)
      count = Int(floor(numeric(args[1])))
      count >= 0 || throw(LogoRuntimeError("repeat expects a non-negative count"))
      for _ in 1:count
        execute_block!(ctx, args[2])
      end
      nothing
    end)

  register_primitive!(registry, "WHILE", COMMAND,
    command_syntax(right=[BooleanBlockType, CommandBlockType], arg_modes=[:reporter_block, :block]),
    function (ctx, args)
      while logical(eval_reporter_block(ctx, args[1], ctx.agent, ctx.caller))
        execute_block!(ctx, args[2])
      end
      nothing
    end)
  register_primitive!(registry, "EVERY", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType], arg_modes=[:eval, :block]),
    (ctx, args) -> nothing)
  register_primitive!(registry, "LOOP", COMMAND,
    command_syntax(right=[CommandBlockType], arg_modes=[:block]),
    (ctx, args) -> loop_execute!(ctx, args[1]))
  register_primitive!(registry, "RUN", COMMAND,
    command_syntax(right=[WildcardType, WildcardType | RepeatableType], arg_modes=[:command_task, :eval]),
    function (ctx, args)
      if args[1] isa AbstractString
        isempty(args[2:end]) || throw(LogoRuntimeError("run doesn't accept further inputs if the first is a string"))
        run_string!(ctx, args[1])
      else
        invoke_command_task(ctx, args[1], Any[args[2:end]...])
      end
      nothing
    end)
  register_primitive!(registry, "RUNRESULT", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType | RepeatableType], ret=WildcardType, arg_modes=[:reporter_task, :eval], default_count=1),
    function (ctx, args)
      if args[1] isa AbstractString
        isempty(args[2:end]) || throw(LogoRuntimeError("runresult doesn't accept further inputs if the first is a string"))
        return runresult_string(ctx, args[1])
      end
      invoke_reporter_task(ctx, args[1], Any[args[2:end]...])
    end)
  register_primitive!(registry, "RUN-RESULT", REPORTER,
    reporter_syntax(right=[WildcardType, WildcardType | RepeatableType], ret=WildcardType, arg_modes=[:reporter_task, :eval], default_count=1),
    function (ctx, args)
      if args[1] isa AbstractString
        isempty(args[2:end]) || throw(LogoRuntimeError("runresult doesn't accept further inputs if the first is a string"))
        return runresult_string(ctx, args[1])
      end
      invoke_reporter_task(ctx, args[1], Any[args[2:end]...])
    end)
  register_primitive!(registry, "DIFFUSE", COMMAND,
    command_syntax(right=[SymbolType, NumberType], agent_classes="O---", arg_modes=[:symbol, :eval]),
    (ctx, args) -> diffuse_patches!(ctx.runtime.world, args[1], numeric(args[2])))
  register_primitive!(registry, "DIFFUSE4", COMMAND,
    command_syntax(right=[SymbolType, NumberType], agent_classes="O---", arg_modes=[:symbol, :eval]),
    (ctx, args) -> diffuse_patches!(ctx.runtime.world, args[1], numeric(args[2]); four_way=true))

  register_primitive!(registry, "ASK", COMMAND,
    command_syntax(right=[AgentType | AgentsetType, CommandBlockType], arg_modes=[:eval, :block], introduces_context=true),
    function (ctx, args)
      target = args[1]
      if target isa AbstractAgent
        run_block_for_agents!(ctx, target, args[2], true)
      else
        run_block_for_agents!(ctx, coerce_agents(ctx.runtime.world, target), args[2], true)
      end
      nothing
    end)
  register_primitive!(registry, "ASK-CONCURRENT", COMMAND,
    command_syntax(right=[AgentsetType, CommandBlockType], arg_modes=[:eval, :block], introduces_context=true),
    function (ctx, args)
      run_block_for_agents!(ctx, require_agentset_input(ctx.runtime.world, args[1], "ASK-CONCURRENT"), args[2], true)
      nothing
    end)

  create_turtles_impl = (ctx, args) -> create_turtles_command!(ctx, args[1]; block=length(args) > 1 ? args[2] : nothing)
  create_ordered_turtles_impl = (ctx, args) -> create_turtles_command!(ctx, args[1]; ordered=true, block=length(args) > 1 ? args[2] : nothing)
  register_primitive!(registry, "CREATE-TURTLES", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType | OptionalType], agent_classes="O---", arg_modes=[:eval, :block]),
    create_turtles_impl)
  register_primitive!(registry, "CRT", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType | OptionalType], agent_classes="O---", arg_modes=[:eval, :block]),
    create_turtles_impl)
  register_primitive!(registry, "CREATE-ORDERED-TURTLES", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType | OptionalType], agent_classes="O---", arg_modes=[:eval, :block]),
    create_ordered_turtles_impl)
  register_primitive!(registry, "CRO", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType | OptionalType], agent_classes="O---", arg_modes=[:eval, :block]),
    create_ordered_turtles_impl)

  register_primitive!(registry, "CREATE-BREED", COMMAND,
    command_syntax(right=[SymbolType, NumberType, CommandBlockType | OptionalType], agent_classes="O---", arg_modes=[:symbol, :eval, :block]),
    function (ctx, args)
      create_turtles_command!(ctx, args[2]; breed=String(args[1]), block=length(args) > 2 ? args[3] : nothing)
    end)
  register_primitive!(registry, "CREATE-ORDERED-BREED", COMMAND,
    command_syntax(right=[SymbolType, NumberType, CommandBlockType | OptionalType], agent_classes="O---", arg_modes=[:symbol, :eval, :block]),
    function (ctx, args)
      create_turtles_command!(ctx, args[2]; breed=String(args[1]), ordered=true, block=length(args) > 2 ? args[3] : nothing)
    end)
  register_primitive!(registry, "HATCH", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> hatch_turtles!(ctx, args[1]; block=length(args) > 1 ? args[2] : nothing))
  register_primitive!(registry, "HATCH-BREED", COMMAND,
    command_syntax(right=[SymbolType, NumberType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:symbol, :eval, :block]),
    (ctx, args) -> hatch_turtles!(ctx, args[2]; breed=args[1], block=length(args) > 2 ? args[3] : nothing))
  register_primitive!(registry, "SPROUT", COMMAND,
    command_syntax(right=[NumberType, CommandBlockType | OptionalType], agent_classes="--P-", arg_modes=[:eval, :block]),
    (ctx, args) -> sprout_turtles!(ctx, args[1]; block=length(args) > 1 ? args[2] : nothing))
  register_primitive!(registry, "SPROUT-BREED", COMMAND,
    command_syntax(right=[SymbolType, NumberType, CommandBlockType | OptionalType], agent_classes="--P-", arg_modes=[:symbol, :eval, :block]),
    (ctx, args) -> sprout_turtles!(ctx, args[2]; breed=args[1], block=length(args) > 2 ? args[3] : nothing))
  register_primitive!(registry, "CREATE-LINK-WITH", COMMAND,
    command_syntax(right=[TurtleType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> (create_links_from_turtle!(ctx, "LINKS", :with, args[1], length(args) > 1 ? args[2] : nothing); nothing))
  register_primitive!(registry, "CREATE-LINKS-WITH", COMMAND,
    command_syntax(right=[TurtlesetType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> (create_links_from_turtle!(ctx, "LINKS", :with, args[1], length(args) > 1 ? args[2] : nothing); nothing))
  register_primitive!(registry, "CREATE-LINK-TO", COMMAND,
    command_syntax(right=[TurtleType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> (create_links_from_turtle!(ctx, "LINKS", :to, args[1], length(args) > 1 ? args[2] : nothing); nothing))
  register_primitive!(registry, "CREATE-LINKS-TO", COMMAND,
    command_syntax(right=[TurtlesetType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> (create_links_from_turtle!(ctx, "LINKS", :to, args[1], length(args) > 1 ? args[2] : nothing); nothing))
  register_primitive!(registry, "CREATE-LINK-FROM", COMMAND,
    command_syntax(right=[TurtleType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> (create_links_from_turtle!(ctx, "LINKS", :from, args[1], length(args) > 1 ? args[2] : nothing); nothing))
  register_primitive!(registry, "CREATE-LINKS-FROM", COMMAND,
    command_syntax(right=[TurtlesetType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:eval, :block]),
    (ctx, args) -> (create_links_from_turtle!(ctx, "LINKS", :from, args[1], length(args) > 1 ? args[2] : nothing); nothing))
  register_primitive!(registry, "CREATE-LINK-BREED", COMMAND,
    command_syntax(right=[SymbolType, SymbolType, AgentType | AgentsetType, CommandBlockType | OptionalType], agent_classes="-T--", arg_modes=[:symbol, :symbol, :eval, :block]),
    function (ctx, args)
      block = length(args) > 3 ? args[4] : nothing
      create_links_from_turtle!(ctx, args[1], link_mode_symbol(args[2]), args[3], block)
      nothing
    end)
  register_primitive!(registry, "TIE", COMMAND, command_syntax(agent_classes="---L"),
    function (ctx, args)
      (ctx.agent::Link).tie_mode = "fixed"
      nothing
    end)
  register_primitive!(registry, "UNTIE", COMMAND, command_syntax(agent_classes="---L"),
    function (ctx, args)
      (ctx.agent::Link).tie_mode = "none"
      nothing
    end)

  register_primitive!(registry, "FD", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_with_pen_blocking!(ctx.runtime.world, ctx.agent::Turtle, numeric(args[1])))
  register_primitive!(registry, "FORWARD", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_with_pen_blocking!(ctx.runtime.world, ctx.agent::Turtle, numeric(args[1])))
  register_primitive!(registry, "JUMP", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_with_pen_blocking!(ctx.runtime.world, ctx.agent::Turtle, numeric(args[1])))
  register_primitive!(registry, "BK", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_with_pen_blocking!(ctx.runtime.world, ctx.agent::Turtle, -numeric(args[1])))
  register_primitive!(registry, "BACK", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_with_pen_blocking!(ctx.runtime.world, ctx.agent::Turtle, -numeric(args[1])))
  register_primitive!(registry, "RT", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> turn_turtle!(ctx.runtime.world, ctx.agent::Turtle, numeric(args[1])))
  register_primitive!(registry, "RIGHT", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> turn_turtle!(ctx.runtime.world, ctx.agent::Turtle, numeric(args[1])))
  register_primitive!(registry, "LT", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> turn_turtle!(ctx.runtime.world, ctx.agent::Turtle, -numeric(args[1])))
  register_primitive!(registry, "LEFT", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> turn_turtle!(ctx.runtime.world, ctx.agent::Turtle, -numeric(args[1])))
  register_primitive!(registry, "SETXY", COMMAND, command_syntax(right=[NumberType, NumberType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_to_with_pen!(ctx.runtime.world, ctx.agent::Turtle, numeric(args[1]), numeric(args[2])))
  register_primitive!(registry, "HOME", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> home_turtle!(ctx.runtime.world, ctx.agent::Turtle))
  register_primitive!(registry, "LAYOUT-CIRCLE", COMMAND, command_syntax(right=[TurtleType | TurtlesetType | ListType, NumberType], agent_classes="O---"),
    (ctx, args) -> layout_circle!(ctx.runtime.world, args[1], args[2]))
  register_primitive!(registry, "LAYOUT-RADIAL", COMMAND, command_syntax(right=[TurtlesetType, LinksetType, TurtleType], agent_classes="O---"),
    (ctx, args) -> layout_radial!(ctx.runtime.world, args[1], args[2], args[3]))
  register_primitive!(registry, "LAYOUT-SPRING", COMMAND, command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, NumberType], agent_classes="O---"),
    (ctx, args) -> layout_spring!(ctx.runtime.world, args[1], args[2], args[3], args[4], args[5]))
  register_primitive!(registry, "LAYOUT-TUTTE", COMMAND, command_syntax(right=[TurtlesetType, LinksetType, NumberType], agent_classes="O---"),
    (ctx, args) -> layout_tutte!(ctx.runtime.world, args[1], args[2], args[3]))
  register_primitive!(registry, "CAN-MOVE?", REPORTER, reporter_syntax(right=[NumberType], ret=BooleanType, agent_classes="-T--"),
    (ctx, args) -> can_move(ctx.runtime.world, ctx.agent::Turtle, args[1]))
  register_primitive!(registry, "FACE", COMMAND, command_syntax(right=[AgentType], agent_classes="-T--"),
    (ctx, args) -> face_turtle!(ctx.runtime.world, ctx.agent::Turtle, args[1]))
  register_primitive!(registry, "FACE-NOWRAP", COMMAND, command_syntax(right=[AgentType], agent_classes="-T--"),
    (ctx, args) -> face_turtle!(ctx.runtime.world, ctx.agent::Turtle, args[1]; wrap=false))
  register_primitive!(registry, "FACEXY", COMMAND, command_syntax(right=[NumberType, NumberType], agent_classes="-T--"),
    (ctx, args) -> face_turtle_xy!(ctx.runtime.world, ctx.agent::Turtle, args[1], args[2]))
  register_primitive!(registry, "FACEXY-NOWRAP", COMMAND, command_syntax(right=[NumberType, NumberType], agent_classes="-T--"),
    (ctx, args) -> face_turtle_xy!(ctx.runtime.world, ctx.agent::Turtle, args[1], args[2]; wrap=false))
  register_primitive!(registry, "MOVE-TO", COMMAND, command_syntax(right=[AgentType], agent_classes="-T--"),
    (ctx, args) -> move_turtle_to_agent!(ctx.runtime.world, ctx.agent::Turtle, args[1]))
  register_primitive!(registry, "FOLLOW-ME", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> set_perspective_subject!(ctx.runtime, ensure_live_agent(ctx.runtime.world, ctx.agent::Turtle)))
  register_primitive!(registry, "WATCH-ME", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> set_perspective_subject!(ctx.runtime, ensure_live_agent(ctx.runtime.world, ctx.agent::Turtle)))
  register_primitive!(registry, "RIDE-ME", COMMAND, command_syntax(agent_classes="-T--"),
    (ctx, args) -> set_perspective_subject!(ctx.runtime, ensure_live_agent(ctx.runtime.world, ctx.agent::Turtle)))

  register_primitive!(registry, "REPORT", COMMAND, command_syntax(right=[WildcardType]),
    (ctx, args) -> throw(ReportSignal(args[1])))
  register_primitive!(registry, "STOP", COMMAND, command_syntax(), (ctx, args) -> throw(StopSignal()))
  register_primitive!(registry, "DIE", COMMAND, command_syntax(agent_classes="-T-L"),
    (ctx, args) -> die_current_agent!(ctx))

  register_primitive!(registry, "TURTLES", REPORTER, reporter_syntax(ret=TurtlesetType),
    (ctx, args) -> all_turtles(ctx.runtime.world))
  register_primitive!(registry, "LINKS", REPORTER, reporter_syntax(ret=LinksetType),
    (ctx, args) -> all_links(ctx.runtime.world))
  register_primitive!(registry, "PATCHES", REPORTER, reporter_syntax(ret=PatchsetType),
    (ctx, args) -> all_patches(ctx.runtime.world))
  register_primitive!(registry, "NO-TURTLES", REPORTER, reporter_syntax(ret=TurtlesetType),
    (ctx, args) -> empty_agentset(TurtleKind))
  register_primitive!(registry, "NO-PATCHES", REPORTER, reporter_syntax(ret=PatchsetType),
    (ctx, args) -> empty_agentset(PatchKind))
  register_primitive!(registry, "NO-LINKS", REPORTER, reporter_syntax(ret=LinksetType),
    (ctx, args) -> empty_agentset(LinkKind))
  register_primitive!(registry, "OBSERVER", REPORTER, reporter_syntax(ret=AgentType),
    (ctx, args) -> ctx.runtime.world.observer)
  register_primitive!(registry, "TURTLE", REPORTER, reporter_syntax(right=[NumberType], ret=TurtleType | NobodyType),
    function (ctx, args)
      turtle = maybe_turtle_by_id(ctx.runtime.world, netlogo_exact_int(args[1]))
      turtle === nothing ? NOBODY : turtle
    end)
  register_primitive!(registry, "TURTLE-BREED", REPORTER,
    reporter_syntax(right=[SymbolType, NumberType], ret=TurtleType | NobodyType, arg_modes=[:symbol, :eval]),
    (ctx, args) -> turtle_breed_reporter(ctx.runtime.world, String(args[1]), args[2]))
  register_primitive!(registry, "LINK", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=LinkType | NobodyType),
    (ctx, args) -> link_reporter(ctx.runtime.world, "LINKS", args[1], args[2]))
  register_primitive!(registry, "LINK-WITH", REPORTER, reporter_syntax(right=[TurtleType], ret=LinkType | NobodyType, agent_classes="-T--"),
    (ctx, args) -> link_relation_reporter(ctx.runtime.world, ctx.agent::Turtle, args[1]))
  register_primitive!(registry, "IN-LINK-FROM", REPORTER, reporter_syntax(right=[TurtleType], ret=LinkType | NobodyType, agent_classes="-T--"),
    (ctx, args) -> link_relation_reporter(ctx.runtime.world, ctx.agent::Turtle, args[1]; mode=:in))
  register_primitive!(registry, "OUT-LINK-TO", REPORTER, reporter_syntax(right=[TurtleType], ret=LinkType | NobodyType, agent_classes="-T--"),
    (ctx, args) -> link_relation_reporter(ctx.runtime.world, ctx.agent::Turtle, args[1]; mode=:out))
  register_primitive!(registry, "LINK-BREED", REPORTER,
    reporter_syntax(right=[SymbolType, NumberType, NumberType], ret=LinkType | NobodyType, arg_modes=[:symbol, :eval, :eval]),
    (ctx, args) -> link_reporter(ctx.runtime.world, String(args[1]), args[2], args[3]))
  register_primitive!(registry, "LINK-BREED-RELATION", REPORTER,
    reporter_syntax(right=[SymbolType, SymbolType, TurtleType], ret=LinkType | NobodyType, agent_classes="-T--", arg_modes=[:symbol, :symbol, :eval]),
    (ctx, args) -> link_relation_reporter(ctx.runtime.world, ctx.agent::Turtle, args[3]; breed=String(args[1]), mode=link_mode_symbol(String(args[2]))))
  register_primitive!(registry, "SELF", REPORTER, reporter_syntax(ret=AgentType),
    (ctx, args) -> ctx.agent)
  register_primitive!(registry, "MYSELF", REPORTER, reporter_syntax(ret=AgentType | NobodyType),
    (ctx, args) -> myself_agent(ctx))
  register_primitive!(registry, "OTHER", REPORTER, reporter_syntax(right=[AgentsetType], ret=AgentsetType),
    (ctx, args) -> other_agents(args[1], ctx.agent))
  register_primitive!(registry, "WHO-ARE-NOT", REPORTER,
    reporter_syntax(left=AgentsetType, right=[AgentType | AgentsetType], ret=AgentsetType, precedence=WhoAreNotPrecedence),
    (ctx, args) -> who_are_not(args[1], args[2]))
  register_primitive!(registry, "PATCH", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=AgentType | NobodyType),
    (ctx, args) -> maybe_patch(ctx.runtime.world, numeric(args[1]), numeric(args[2])))
  register_primitive!(registry, "PATCH-HERE", REPORTER, reporter_syntax(ret=AgentType, agent_classes="-TP-"),
    function (ctx, args)
      if ctx.agent isa Turtle
        return current_patch(ctx.runtime.world, ctx.agent)
      elseif ctx.agent isa Patch
        return ctx.agent
      end
      throw(LogoRuntimeError("patch-here is only available to turtles and patches"))
    end)
  register_primitive!(registry, "PATCH-AT", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=PatchType | NobodyType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return patch_at_offset(ctx.runtime.world, agent, args[1], args[2])
      end
      throw(LogoRuntimeError("patch-at is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TURTLES-HERE", REPORTER, reporter_syntax(ret=TurtlesetType, agent_classes="-TP-"),
    function (ctx, args)
      if ctx.agent isa Turtle
        return turtles_on_patch(ctx.runtime.world, current_patch(ctx.runtime.world, ctx.agent))
      elseif ctx.agent isa Patch
        return turtles_on_patch(ctx.runtime.world, ctx.agent)
      end
      throw(LogoRuntimeError("turtles-here is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TURTLE-BREED-HERE", REPORTER, reporter_syntax(right=[SymbolType], ret=TurtlesetType, arg_modes=[:symbol], agent_classes="-TP-"),
    function (ctx, args)
      if ctx.agent isa Turtle
        return turtles_on_patch_canonical(ctx.runtime.world, current_patch(ctx.runtime.world, ctx.agent), args[1])
      elseif ctx.agent isa Patch
        return turtles_on_patch_canonical(ctx.runtime.world, ctx.agent, args[1])
      end
      throw(LogoRuntimeError("$(lowercase(args[1]))-here is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TURTLES-AT", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=TurtlesetType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return turtles_at_offset(ctx.runtime.world, agent, args[1], args[2])
      end
      throw(LogoRuntimeError("turtles-at is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TURTLE-BREED-AT", REPORTER,
    reporter_syntax(right=[SymbolType, NumberType, NumberType], ret=TurtlesetType, arg_modes=[:symbol, :eval, :eval], agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return turtles_at_offset(ctx.runtime.world, agent, args[2], args[3]; breed=args[1], opname="$(lowercase(args[1]))-at")
      end
      throw(LogoRuntimeError("$(lowercase(args[1]))-at is only available to turtles and patches"))
    end)
  register_primitive!(registry, "AT-POINTS", REPORTER, reporter_syntax(left=TurtlesetType | PatchsetType, right=[ListType], ret=AgentsetType, precedence=WithPrecedence),
    (ctx, args) -> begin
      agent = ctx.agent
      if agent isa Turtle
        agents_at_points(ctx.runtime.world, args[1], args[2], Float64(agent.xcor), Float64(agent.ycor))
      elseif agent isa Patch
        agents_at_points(ctx.runtime.world, args[1], args[2], Float64(agent.pxcor), Float64(agent.pycor))
      else
        # Observer context: offsets relative to origin (0, 0)
        agents_at_points(ctx.runtime.world, args[1], args[2], 0.0, 0.0)
      end
    end)
  register_primitive!(registry, "TURTLES-ON", REPORTER, reporter_syntax(right=[WildcardType], ret=TurtlesetType),
    (ctx, args) -> turtles_on_sources(ctx.runtime.world, args[1]))
  register_primitive!(registry, "PATCHES-ON", REPORTER, reporter_syntax(right=[WildcardType], ret=PatchsetType),
    (ctx, args) -> patches_on_sources(ctx.runtime.world, args[1]))
  register_primitive!(registry, "TURTLE-BREED-ON", REPORTER, reporter_syntax(right=[SymbolType, WildcardType], ret=TurtlesetType, arg_modes=[:symbol, :eval]),
    (ctx, args) -> turtles_on_sources(ctx.runtime.world, args[2]; breed=args[1], opname="$(lowercase(args[1]))-on"))
  register_primitive!(registry, "PATCH-AHEAD", REPORTER, reporter_syntax(right=[NumberType], ret=PatchType | NobodyType, agent_classes="-T--"),
    function (ctx, args)
      turtle = ctx.agent::Turtle
      patch_at_heading_and_distance(ctx.runtime.world, turtle.xcor, turtle.ycor, turtle.heading, numeric(args[1]))
    end)
  register_primitive!(registry, "PATCH-LEFT-AND-AHEAD", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=PatchType | NobodyType, agent_classes="-T--"),
    function (ctx, args)
      turtle = ctx.agent::Turtle
      patch_at_heading_and_distance(ctx.runtime.world, turtle.xcor, turtle.ycor, turtle.heading - numeric(args[1]), numeric(args[2]))
    end)
  register_primitive!(registry, "PATCH-RIGHT-AND-AHEAD", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=PatchType | NobodyType, agent_classes="-T--"),
    function (ctx, args)
      turtle = ctx.agent::Turtle
      patch_at_heading_and_distance(ctx.runtime.world, turtle.xcor, turtle.ycor, turtle.heading + numeric(args[1]), numeric(args[2]))
    end)
  register_primitive!(registry, "PATCH-AT-HEADING-AND-DISTANCE", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=PatchType | NobodyType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        source_x, source_y = agent_position(agent)
        return patch_at_heading_and_distance(ctx.runtime.world, source_x, source_y, numeric(args[1]), numeric(args[2]))
      end
      throw(LogoRuntimeError("patch-at-heading-and-distance is only available to turtles and patches"))
    end)
  register_primitive!(registry, "IN-RADIUS", REPORTER, reporter_syntax(left=TurtlesetType | PatchsetType, right=[NumberType], ret=AgentsetType, precedence=WithPrecedence, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return agents_in_radius(ctx.runtime.world, agent, args[1], args[2])
      end
      throw(LogoRuntimeError("in-radius is only available to turtles and patches"))
    end)
  register_primitive!(registry, "IN-RADIUS-NOWRAP", REPORTER, reporter_syntax(left=TurtlesetType | PatchsetType, right=[NumberType], ret=AgentsetType, precedence=WithPrecedence, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return agents_in_radius(ctx.runtime.world, agent, args[1], args[2]; opname="in-radius-nowrap", wrap=false)
      end
      throw(LogoRuntimeError("in-radius-nowrap is only available to turtles and patches"))
    end)
  register_primitive!(registry, "IN-CONE", REPORTER, reporter_syntax(left=TurtlesetType | PatchsetType, right=[NumberType, NumberType], ret=AgentsetType, precedence=WithPrecedence, agent_classes="-T--"),
    (ctx, args) -> agents_in_cone(ctx.runtime.world, ctx.agent::Turtle, args[1], args[2], args[3]))
  register_primitive!(registry, "IN-CONE-NOWRAP", REPORTER, reporter_syntax(left=TurtlesetType | PatchsetType, right=[NumberType, NumberType], ret=AgentsetType, precedence=WithPrecedence, agent_classes="-T--"),
    (ctx, args) -> agents_in_cone(ctx.runtime.world, ctx.agent::Turtle, args[1], args[2], args[3]; opname="in-cone-nowrap", wrap=false))
  register_primitive!(registry, "DISTANCE", REPORTER, reporter_syntax(right=[TurtleType | PatchType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return distance_to_target(ctx.runtime.world, agent, args[1])
      end
      throw(LogoRuntimeError("distance is only available to turtles and patches"))
    end)
  register_primitive!(registry, "DISTANCE-NOWRAP", REPORTER, reporter_syntax(right=[TurtleType | PatchType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return distance_to_target(ctx.runtime.world, agent, args[1]; wrap=false)
      end
      throw(LogoRuntimeError("distance-nowrap is only available to turtles and patches"))
    end)
  register_primitive!(registry, "DISTANCEXY", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return distancexy_from(ctx.runtime.world, agent, args[1], args[2])
      end
      throw(LogoRuntimeError("distancexy is only available to turtles and patches"))
    end)
  register_primitive!(registry, "DISTANCEXY-NOWRAP", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return distancexy_from(ctx.runtime.world, agent, args[1], args[2]; wrap=false)
      end
      throw(LogoRuntimeError("distancexy-nowrap is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TOWARDS", REPORTER, reporter_syntax(right=[TurtleType | PatchType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return towards_target(ctx.runtime.world, agent, args[1])
      end
      throw(LogoRuntimeError("towards is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TOWARDS-NOWRAP", REPORTER, reporter_syntax(right=[TurtleType | PatchType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return towards_target(ctx.runtime.world, agent, args[1]; wrap=false)
      end
      throw(LogoRuntimeError("towards-nowrap is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TOWARDSXY", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return towardsxy_from(ctx.runtime.world, agent, args[1], args[2])
      end
      throw(LogoRuntimeError("towardsxy is only available to turtles and patches"))
    end)
  register_primitive!(registry, "TOWARDSXY-NOWRAP", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType, agent_classes="-TP-"),
    function (ctx, args)
      agent = ctx.agent
      if agent isa Turtle || agent isa Patch
        return towardsxy_from(ctx.runtime.world, agent, args[1], args[2]; wrap=false)
      end
      throw(LogoRuntimeError("towardsxy-nowrap is only available to turtles and patches"))
    end)
  register_primitive!(registry, "DX", REPORTER, reporter_syntax(ret=NumberType, agent_classes="-T--"),
    (ctx, args) -> heading_dx((ctx.agent::Turtle).heading))
  register_primitive!(registry, "DY", REPORTER, reporter_syntax(ret=NumberType, agent_classes="-T--"),
    (ctx, args) -> heading_dy((ctx.agent::Turtle).heading))
  register_primitive!(registry, "NEIGHBORS", REPORTER, reporter_syntax(ret=PatchsetType, agent_classes="-TP-"),
    function (ctx, args)
      if ctx.agent isa Turtle
        return patch_neighbors(ctx.runtime.world, current_patch(ctx.runtime.world, ctx.agent))
      elseif ctx.agent isa Patch
        return patch_neighbors(ctx.runtime.world, ctx.agent)
      end
      throw(LogoRuntimeError("neighbors is only available to turtles and patches"))
    end)
  register_primitive!(registry, "NEIGHBORS4", REPORTER, reporter_syntax(ret=PatchsetType, agent_classes="-TP-"),
    function (ctx, args)
      if ctx.agent isa Turtle
        return patch_neighbors(ctx.runtime.world, current_patch(ctx.runtime.world, ctx.agent); four_way=true)
      elseif ctx.agent isa Patch
        return patch_neighbors(ctx.runtime.world, ctx.agent; four_way=true)
      end
      throw(LogoRuntimeError("neighbors4 is only available to turtles and patches"))
    end)
  register_primitive!(registry, "UPHILL", COMMAND,
    command_syntax(right=[SymbolType], agent_classes="-T--", arg_modes=[:symbol]),
    (ctx, args) -> follow_patch_gradient!(ctx.runtime.world, ctx.agent::Turtle, args[1]))
  register_primitive!(registry, "UPHILL4", COMMAND,
    command_syntax(right=[SymbolType], agent_classes="-T--", arg_modes=[:symbol]),
    (ctx, args) -> follow_patch_gradient!(ctx.runtime.world, ctx.agent::Turtle, args[1]; four_way=true))
  register_primitive!(registry, "DOWNHILL", COMMAND,
    command_syntax(right=[SymbolType], agent_classes="-T--", arg_modes=[:symbol]),
    (ctx, args) -> follow_patch_gradient!(ctx.runtime.world, ctx.agent::Turtle, args[1]; uphill=false))
  register_primitive!(registry, "DOWNHILL4", COMMAND,
    command_syntax(right=[SymbolType], agent_classes="-T--", arg_modes=[:symbol]),
    (ctx, args) -> follow_patch_gradient!(ctx.runtime.world, ctx.agent::Turtle, args[1]; four_way=true, uphill=false))
  register_primitive!(registry, "MY-LINKS", REPORTER, reporter_syntax(ret=LinksetType, agent_classes="-T--"),
    (ctx, args) -> my_links(ctx.runtime.world, ctx.agent::Turtle))
  register_primitive!(registry, "MY-IN-LINKS", REPORTER, reporter_syntax(ret=LinksetType, agent_classes="-T--"),
    (ctx, args) -> my_links(ctx.runtime.world, ctx.agent::Turtle; mode=:in))
  register_primitive!(registry, "MY-OUT-LINKS", REPORTER, reporter_syntax(ret=LinksetType, agent_classes="-T--"),
    (ctx, args) -> my_links(ctx.runtime.world, ctx.agent::Turtle; mode=:out))
  register_primitive!(registry, "LINK-NEIGHBORS", REPORTER, reporter_syntax(ret=TurtlesetType, agent_classes="-T--"),
    (ctx, args) -> link_neighbors(ctx.runtime.world, ctx.agent::Turtle))
  register_primitive!(registry, "IN-LINK-NEIGHBORS", REPORTER, reporter_syntax(ret=TurtlesetType, agent_classes="-T--"),
    (ctx, args) -> link_neighbors(ctx.runtime.world, ctx.agent::Turtle; mode=:in))
  register_primitive!(registry, "OUT-LINK-NEIGHBORS", REPORTER, reporter_syntax(ret=TurtlesetType, agent_classes="-T--"),
    (ctx, args) -> link_neighbors(ctx.runtime.world, ctx.agent::Turtle; mode=:out))
  register_primitive!(registry, "MY-LINK-BREED", REPORTER,
    reporter_syntax(right=[SymbolType, SymbolType], ret=LinksetType, agent_classes="-T--", arg_modes=[:symbol, :symbol]),
    (ctx, args) -> my_links(ctx.runtime.world, ctx.agent::Turtle; breed=args[1], mode=link_mode_symbol(args[2])))
  register_primitive!(registry, "LINK-BREED-NEIGHBORS", REPORTER,
    reporter_syntax(right=[SymbolType, SymbolType], ret=TurtlesetType, agent_classes="-T--", arg_modes=[:symbol, :symbol]),
    (ctx, args) -> link_neighbors(ctx.runtime.world, ctx.agent::Turtle; breed=args[1], mode=link_mode_symbol(args[2])))
  register_primitive!(registry, "LINK-NEIGHBOR?", REPORTER,
    reporter_syntax(right=[TurtleType], ret=BooleanType, agent_classes="-T--"),
    (ctx, args) -> link_neighbor(ctx.runtime.world, ctx.agent::Turtle, args[1]))
  register_primitive!(registry, "IN-LINK-NEIGHBOR?", REPORTER,
    reporter_syntax(right=[TurtleType], ret=BooleanType, agent_classes="-T--"),
    (ctx, args) -> link_neighbor(ctx.runtime.world, ctx.agent::Turtle, args[1]; mode=:in))
  register_primitive!(registry, "OUT-LINK-NEIGHBOR?", REPORTER,
    reporter_syntax(right=[TurtleType], ret=BooleanType, agent_classes="-T--"),
    (ctx, args) -> link_neighbor(ctx.runtime.world, ctx.agent::Turtle, args[1]; mode=:out))
  register_primitive!(registry, "LINK-BREED-NEIGHBOR?", REPORTER,
    reporter_syntax(right=[SymbolType, SymbolType, TurtleType], ret=BooleanType, agent_classes="-T--", arg_modes=[:symbol, :symbol, :eval]),
    (ctx, args) -> link_neighbor(ctx.runtime.world, ctx.agent::Turtle, args[3]; breed=args[1], mode=link_mode_symbol(args[2])))
  register_primitive!(registry, "LINK-LENGTH", REPORTER,
    reporter_syntax(ret=NumberType, agent_classes="---L"),
    (ctx, args) -> link_length(ctx.runtime.world, ctx.agent::Link))
  register_primitive!(registry, "LINK-HEADING", REPORTER,
    reporter_syntax(ret=NumberType, agent_classes="---L"),
    (ctx, args) -> link_heading(ctx.runtime.world, ctx.agent::Link))
  register_primitive!(registry, "BOTH-ENDS", REPORTER,
    reporter_syntax(ret=TurtlesetType, agent_classes="---L"),
    (ctx, args) -> both_ends(ctx.runtime.world, ctx.agent::Link))
  register_primitive!(registry, "OTHER-END", REPORTER,
    reporter_syntax(ret=TurtleType, agent_classes="-T-L"),
    (ctx, args) -> other_end(ctx))
  register_primitive!(registry, "WITH", REPORTER,
    reporter_syntax(left=AgentsetType, right=[BooleanBlockType], ret=AgentsetType, precedence=WithPrecedence, arg_modes=[:reporter_block]),
    (ctx, args) -> filter_agentset(ctx, args[1], args[2]))
  register_primitive!(registry, "WITH-MAX", REPORTER,
    reporter_syntax(left=AgentsetType, right=[NumberBlockType], ret=AgentsetType, precedence=WithPrecedence, arg_modes=[:reporter_block]),
    (ctx, args) -> extreme_agents(ctx, args[1], args[2]; mode=:max))
  register_primitive!(registry, "WITH-MIN", REPORTER,
    reporter_syntax(left=AgentsetType, right=[NumberBlockType], ret=AgentsetType, precedence=WithPrecedence, arg_modes=[:reporter_block]),
    (ctx, args) -> extreme_agents(ctx, args[1], args[2]; mode=:min))
  register_primitive!(registry, "OF", REPORTER,
    reporter_syntax(left=ReporterBlockType, right=[AgentType | AgentsetType], ret=WildcardType, precedence=OfPrecedence),
    (ctx, args) -> of_value(ctx, args[1], args[2]))
  register_primitive!(registry, "MIN-ONE-OF", REPORTER,
    reporter_syntax(right=[AgentsetType, NumberBlockType], ret=AgentType | NobodyType, arg_modes=[:eval, :reporter_block]),
    (ctx, args) -> extreme_agent(ctx, args[1], args[2]; mode=:min))
  register_primitive!(registry, "MAX-ONE-OF", REPORTER,
    reporter_syntax(right=[AgentsetType, NumberBlockType], ret=AgentType | NobodyType, arg_modes=[:eval, :reporter_block]),
    (ctx, args) -> extreme_agent(ctx, args[1], args[2]; mode=:max))
  register_primitive!(registry, "MIN-N-OF", REPORTER,
    reporter_syntax(right=[NumberType, AgentsetType, NumberBlockType], ret=AgentsetType, arg_modes=[:eval, :eval, :reporter_block]),
    (ctx, args) -> extreme_n_agents(ctx, args[1], args[2], args[3]; mode=:min))
  register_primitive!(registry, "MAX-N-OF", REPORTER,
    reporter_syntax(right=[NumberType, AgentsetType, NumberBlockType], ret=AgentsetType, arg_modes=[:eval, :eval, :reporter_block]),
    (ctx, args) -> extreme_n_agents(ctx, args[1], args[2], args[3]; mode=:max))
  register_primitive!(registry, "COUNT", REPORTER, reporter_syntax(right=[WildcardType], ret=NumberType),
    function (ctx, args)
      value = args[1]
      if value isa AgentSet
        return Float64(length(value))
      elseif value isa AbstractVector
        return Float64(length(value))
      end
      throw(LogoRuntimeError("count expects an agentset or list"))
    end)
  register_primitive!(registry, "SUM", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_sum(args[1]))
  register_primitive!(registry, "MEAN", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_mean(args[1]))
  register_primitive!(registry, "MEDIAN", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_median(args[1]))
  register_primitive!(registry, "MIN", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_min(args[1]))
  register_primitive!(registry, "MAX", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_max(args[1]))
  register_primitive!(registry, "VARIANCE", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_variance(args[1]))
  register_primitive!(registry, "STANDARD-DEVIATION", REPORTER, reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> aggregate_standard_deviation(args[1]))
  register_primitive!(registry, "MAP", REPORTER,
    reporter_syntax(right=[WildcardType, ListType | RepeatableType], ret=ListType, arg_modes=[:reporter_task, :eval]),
    (ctx, args) -> map_values(ctx, args[1], args[2:end]...))
  register_primitive!(registry, "FILTER", REPORTER,
    reporter_syntax(right=[WildcardType, ListType], ret=ListType, arg_modes=[:reporter_task, :eval]),
    (ctx, args) -> filter_values(ctx, args[1], args[2]))
  register_primitive!(registry, "REDUCE", REPORTER,
    reporter_syntax(right=[WildcardType, ListType], ret=WildcardType, arg_modes=[:reporter_task, :eval]),
    (ctx, args) -> reduce_values(ctx, args[1], args[2]))
  register_primitive!(registry, "N-VALUES", REPORTER,
    reporter_syntax(right=[NumberType, WildcardType], ret=ListType, arg_modes=[:eval, :reporter_task]),
    (ctx, args) -> n_values(ctx, args[1], args[2]))
  register_primitive!(registry, "SORT", REPORTER, reporter_syntax(right=[ListType | AgentsetType], ret=ListType),
    (ctx, args) -> collection_sort(ctx.runtime.model, args[1]))
  register_primitive!(registry, "SORT-ON", REPORTER,
    reporter_syntax(right=[ReporterBlockType, AgentsetType], ret=ListType, arg_modes=[:reporter_block, :eval]),
    (ctx, args) -> sort_on_values(ctx, args[1], args[2]))
  register_primitive!(registry, "SORT-BY", REPORTER,
    reporter_syntax(right=[WildcardType, ListType | AgentsetType], ret=ListType, arg_modes=[:reporter_task, :eval]),
    (ctx, args) -> sort_by_values(ctx, args[1], args[2]))
  register_primitive!(registry, "MEMBER?", REPORTER, reporter_syntax(right=[WildcardType, ListType | StringType | AgentsetType], ret=BooleanType),
    (ctx, args) -> collection_member(args[1], args[2]))
  register_primitive!(registry, "POSITION", REPORTER, reporter_syntax(right=[WildcardType, ListType | StringType], ret=NumberType | BooleanType),
    (ctx, args) -> collection_position(args[1], args[2]))
  register_primitive!(registry, "REVERSE", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_reverse(args[1]))
  register_primitive!(registry, "SHUFFLE", REPORTER, reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> collection_shuffle(ctx.runtime.world.rng, args[1]))
  register_primitive!(registry, "REMOVE", REPORTER, reporter_syntax(right=[WildcardType, ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_remove(args[1], args[2]))
  register_primitive!(registry, "INSERT-ITEM", REPORTER, reporter_syntax(right=[NumberType, ListType | StringType, WildcardType], ret=ListType | StringType),
    (ctx, args) -> collection_insert_item(args[1], args[2], args[3]))
  register_primitive!(registry, "REPLACE-ITEM", REPORTER, reporter_syntax(right=[NumberType, ListType | StringType, WildcardType], ret=ListType | StringType),
    (ctx, args) -> collection_replace_item(args[1], args[2], args[3]))
  register_primitive!(registry, "REMOVE-ITEM", REPORTER, reporter_syntax(right=[NumberType, ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_remove_item(args[1], args[2]))
  register_primitive!(registry, "REMOVE-DUPLICATES", REPORTER, reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> collection_remove_duplicates(args[1]))
  register_primitive!(registry, "SUBLIST", REPORTER, reporter_syntax(right=[ListType, NumberType, NumberType], ret=ListType),
    (ctx, args) -> collection_sublist(args[1], args[2], args[3]))
  register_primitive!(registry, "SUBSTRING", REPORTER, reporter_syntax(right=[StringType, NumberType, NumberType], ret=StringType),
    (ctx, args) -> collection_substring(args[1], args[2], args[3]))
  register_primitive!(registry, "ALL?", REPORTER,
    reporter_syntax(right=[AgentsetType, BooleanBlockType], ret=BooleanType, arg_modes=[:eval, :reporter_block]),
    (ctx, args) -> all_agentset(ctx, args[1], args[2]))
  register_primitive!(registry, "ANY?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    function (ctx, args)
      value = args[1]
      if value isa AgentSet || value isa AbstractVector || value isa AbstractString
        return !isempty(value)
      end
      throw(LogoRuntimeError("any? expects an agentset, list, or string"))
    end)
  register_primitive!(registry, "IS-AGENTSET?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> args[1] isa AgentSet)
  register_primitive!(registry, "IS-AGENT?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_live_agent_value(args[1]))
  register_primitive!(registry, "IS-TURTLE?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_turtle_value(args[1]))
  register_primitive!(registry, "IS-PATCH?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_patch_value(args[1]))
  register_primitive!(registry, "IS-LINK?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_link_value(args[1]))
  register_primitive!(registry, "IS-DIRECTED-LINK?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_directed_link_value(ctx.runtime.world, args[1]))
  register_primitive!(registry, "IS-UNDIRECTED-LINK?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_undirected_link_value(ctx.runtime.world, args[1]))
  register_primitive!(registry, "IS-TURTLE-SET?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> args[1] isa AgentSet && args[1].kind == TurtleKind)
  register_primitive!(registry, "IS-PATCH-SET?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> args[1] isa AgentSet && args[1].kind == PatchKind)
  register_primitive!(registry, "IS-LINK-SET?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> args[1] isa AgentSet && args[1].kind == LinkKind)
  register_primitive!(registry, "IS-TURTLE-BREED?", REPORTER,
    reporter_syntax(right=[SymbolType, WildcardType], ret=BooleanType, arg_modes=[:symbol, :eval]),
    (ctx, args) -> is_turtle_breed_value(args[2], String(args[1])))
  register_primitive!(registry, "IS-LINK-BREED?", REPORTER,
    reporter_syntax(right=[SymbolType, WildcardType], ret=BooleanType, arg_modes=[:symbol, :eval]),
    (ctx, args) -> is_link_breed_value(args[2], String(args[1])))
  register_primitive!(registry, "IS-BOOLEAN?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_boolean_value(args[1]))
  register_primitive!(registry, "IS-NUMBER?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_number_value(args[1]))
  register_primitive!(registry, "IS-LIST?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_list_value(args[1]))
  register_primitive!(registry, "IS-ANONYMOUS-COMMAND?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_anonymous_command_value(args[1]))
  register_primitive!(registry, "IS-COMMAND-TASK?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_anonymous_command_value(args[1]))
  register_primitive!(registry, "IS-ANONYMOUS-REPORTER?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_anonymous_reporter_value(args[1]))
  register_primitive!(registry, "IS-REPORTER-TASK?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> is_anonymous_reporter_value(args[1]))
  register_primitive!(registry, "IS-OBSERVER?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> args[1] isa Observer)
  register_primitive!(registry, "IS-BREED?", REPORTER,
    reporter_syntax(right=[SymbolType, WildcardType], ret=BooleanType, arg_modes=[:symbol, :eval]),
    (ctx, args) -> begin
      breed_name = String(args[1])
      agent = args[2]
      if agent isa Turtle
        return uppercase(agent.breed) == uppercase(breed_name) || uppercase(breed_name) == "TURTLES"
      elseif agent isa Link
        return uppercase(agent.breed) == uppercase(breed_name) || uppercase(breed_name) == "LINKS"
      end
      false
    end)
  register_primitive!(registry, "EMPTY?", REPORTER, reporter_syntax(right=[ListType | StringType], ret=BooleanType),
    (ctx, args) -> collection_empty(args[1]))
  register_primitive!(registry, "ONE-OF", REPORTER, reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> one_of(ctx.runtime.world.rng, args[1]))
  register_primitive!(registry, "IS-STRING?", REPORTER, reporter_syntax(right=[WildcardType], ret=BooleanType),
    (ctx, args) -> args[1] isa AbstractString)
  register_primitive!(registry, "LENGTH", REPORTER, reporter_syntax(right=[WildcardType], ret=NumberType),
    (ctx, args) -> collection_length(args[1]))
  register_primitive!(registry, "FIRST", REPORTER, reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> collection_first(args[1]))
  register_primitive!(registry, "LAST", REPORTER, reporter_syntax(right=[WildcardType], ret=WildcardType),
    (ctx, args) -> collection_last(args[1]))
  register_primitive!(registry, "BUTFIRST", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_butfirst(args[1]))
  register_primitive!(registry, "BUT-FIRST", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_butfirst(args[1]))
  register_primitive!(registry, "BF", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_butfirst(args[1]))
  register_primitive!(registry, "BUTLAST", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_butlast(args[1]))
  register_primitive!(registry, "BL", REPORTER, reporter_syntax(right=[ListType | StringType], ret=ListType | StringType),
    (ctx, args) -> collection_butlast(args[1]))
  register_primitive!(registry, "ITEM", REPORTER, reporter_syntax(right=[NumberType, WildcardType], ret=WildcardType),
    (ctx, args) -> collection_item(args[1], args[2]))
  register_primitive!(registry, "LIST", REPORTER, reporter_syntax(right=[WildcardType | RepeatableType], ret=ListType, default_count=2),
    (ctx, args) -> Any[args...])
  register_primitive!(registry, "MODES", REPORTER, reporter_syntax(right=[ListType], ret=ListType),
    (ctx, args) -> collection_modes(args[1]))
  register_primitive!(registry, "RANGE", REPORTER, reporter_syntax(right=[NumberType | RepeatableType], ret=ListType),
    (ctx, args) -> range_values(args))
  register_primitive!(registry, "SENTENCE", REPORTER, reporter_syntax(right=[WildcardType | RepeatableType], ret=ListType, default_count=2),
    function (ctx, args)
      result = Any[]
      for arg in args
        if arg isa AbstractVector
          append!(result, arg)
        else
          push!(result, arg)
        end
      end
      result
    end)
  register_primitive!(registry, "WORD", REPORTER, reporter_syntax(right=[WildcardType | RepeatableType], ret=StringType, default_count=2),
    (ctx, args) -> join(logo_string(arg) for arg in args))
  register_primitive!(registry, "__APPLY", COMMAND,
    command_syntax(right=[CommandType, ListType], arg_modes=[:command_task, :eval]),
    (ctx, args) -> invoke_command_task(ctx, args[1], list_argument(args[2], "__APPLY")))
  register_primitive!(registry, "__APPLY-RESULT", REPORTER,
    reporter_syntax(right=[ReporterType, ListType], ret=WildcardType, arg_modes=[:reporter_task, :eval]),
    (ctx, args) -> invoke_reporter_task(ctx, args[1], list_argument(args[2], "__APPLY-RESULT")))
  register_primitive!(registry, "__REFERENCE", REPORTER,
    reporter_syntax(right=[SymbolType], ret=ReferenceType, arg_modes=[:symbol]),
    (ctx, args) -> variable_reference(ctx, args[1]))
  register_primitive!(registry, "__SYMBOL", REPORTER,
    reporter_syntax(right=[SymbolType], ret=StringType, arg_modes=[:symbol]),
    (ctx, args) -> code_identifier(args[1]))
  register_primitive!(registry, "__BLOCK", REPORTER,
    reporter_syntax(right=[CodeBlockType], ret=StringType, arg_modes=[:code_block]),
    (ctx, args) -> render_code_block(ctx, args[1]))
  register_primitive!(registry, "FPUT", REPORTER, reporter_syntax(right=[WildcardType, ListType], ret=ListType),
    (ctx, args) -> begin lst = Any[args[1]]; append!(lst, args[2]); lst end)
  register_primitive!(registry, "LPUT", REPORTER, reporter_syntax(right=[WildcardType, ListType], ret=ListType),
    (ctx, args) -> begin lst = Any[args[2]...]; push!(lst, args[1]); lst end)
  register_primitive!(registry, "TURTLE-SET", REPORTER, reporter_syntax(right=[WildcardType | RepeatableType], ret=TurtlesetType),
    (ctx, args) -> build_agentset("TURTLE-SET", ctx.runtime.model, TurtleKind, args...))
  register_primitive!(registry, "PATCH-SET", REPORTER, reporter_syntax(right=[WildcardType | RepeatableType], ret=PatchsetType),
    (ctx, args) -> build_agentset("PATCH-SET", ctx.runtime.model, PatchKind, args...))
  register_primitive!(registry, "LINK-SET", REPORTER, reporter_syntax(right=[WildcardType | RepeatableType], ret=LinksetType),
    (ctx, args) -> build_agentset("LINK-SET", ctx.runtime.model, LinkKind, args...))
  register_primitive!(registry, "N-OF", REPORTER, reporter_syntax(right=[NumberType, AgentsetType | ListType], ret=WildcardType),
    (ctx, args) -> n_of(ctx.runtime.world.rng, args[1], args[2]))
  register_primitive!(registry, "UP-TO-N-OF", REPORTER, reporter_syntax(right=[NumberType, AgentsetType | ListType], ret=WildcardType),
    (ctx, args) -> n_of(ctx.runtime.world.rng, args[1], args[2]; opname="up-to-n-of", up_to=true))
  register_primitive!(registry, "RANDOM", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    function (ctx, args)
      limit = Int(floor(numeric(args[1])))
      limit <= 0 && return 0.0
      Float64(rand(ctx.runtime.world.rng, 0:limit - 1))
    end)
  register_primitive!(registry, "RANDOM-FLOAT", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> rand(ctx.runtime.world.rng) * numeric(args[1]))
  register_primitive!(registry, "RANDOM-PXCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> random_patch_coord(ctx.runtime.world.rng, ctx.runtime.world.min_pxcor, ctx.runtime.world.max_pxcor))
  register_primitive!(registry, "RANDOM-PYCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> random_patch_coord(ctx.runtime.world.rng, ctx.runtime.world.min_pycor, ctx.runtime.world.max_pycor))
  register_primitive!(registry, "RANDOM-XCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> random_agent_coord(ctx.runtime.world.rng, ctx.runtime.world.min_pxcor, ctx.runtime.world.max_pxcor))
  register_primitive!(registry, "RANDOM-YCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> random_agent_coord(ctx.runtime.world.rng, ctx.runtime.world.min_pycor, ctx.runtime.world.max_pycor))
  register_primitive!(registry, "RANDOM-EXPONENTIAL", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_random_exponential(ctx.runtime.world.rng, args[1]))
  register_primitive!(registry, "RANDOM-GAMMA", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> netlogo_random_gamma(ctx.runtime.world.rng, args[1], args[2]))
  register_primitive!(registry, "RANDOM-NORMAL", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> netlogo_random_normal(ctx.runtime.world.rng, args[1], args[2]))
  register_primitive!(registry, "RANDOM-POISSON", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_random_poisson(ctx.runtime.world.rng, args[1]))
  register_primitive!(registry, "ERROR-MESSAGE", REPORTER, reporter_syntax(ret=StringType),
    function (ctx, args)
      isempty(ctx.runtime.error_messages) &&
        throw(LogoRuntimeError("error-message cannot be used outside of CAREFULLY."))
      last(ctx.runtime.error_messages)
    end)
  register_primitive!(registry, "__CHECK-SYNTAX", REPORTER, reporter_syntax(right=[StringType], ret=StringType),
    (ctx, args) -> check_syntax_message(ctx, args[1]))
  register_primitive!(registry, "FILE-AT-END?", REPORTER, reporter_syntax(ret=BooleanType),
    (ctx, args) -> current_file_at_end(ctx.runtime))
  register_primitive!(registry, "FILE-EXISTS?", REPORTER, reporter_syntax(right=[StringType], ret=BooleanType),
    (ctx, args) -> file_exists(String(args[1])))
  register_primitive!(registry, "FILE-READ", REPORTER, reporter_syntax(ret=WildcardType),
    function (ctx, args)
      try
        read_current_file_literal!(ctx.runtime)
      catch err
        err isa EOFError && throw(LogoRuntimeError("The end of file has been reached"))
        err isa LiteralParseError && throw(LogoRuntimeError(format_literal_parse_error(err)))
        rethrow()
      end
    end)
  register_primitive!(registry, "FILE-READ-CHARACTERS", REPORTER, reporter_syntax(right=[NumberType], ret=StringType),
    function (ctx, args)
      try
        read_current_file_characters!(ctx.runtime, netlogo_exact_int(args[1]))
      catch err
        err isa EOFError && throw(LogoRuntimeError("The end of file has been reached"))
        rethrow()
      end
    end)
  register_primitive!(registry, "FILE-READ-LINE", REPORTER, reporter_syntax(ret=StringType),
    function (ctx, args)
      try
        read_current_file_line!(ctx.runtime)
      catch err
        err isa EOFError && throw(LogoRuntimeError("The end of file has been reached"))
        rethrow()
      end
    end)
  register_primitive!(registry, "READ-FROM-STRING", REPORTER, reporter_syntax(right=[StringType], ret=WildcardType),
    function (ctx, args)
      try
        read_literal_from_string(String(args[1]))
      catch err
        err isa LiteralParseError && throw(LogoRuntimeError(err.message))
        rethrow()
      end
    end)
  register_primitive!(registry, "__RANDOM-STATE", REPORTER, reporter_syntax(ret=ListType),
    (ctx, args) -> random_state_snapshot(ctx.runtime.world))
  register_primitive!(registry, "SUBJECT", REPORTER, reporter_syntax(ret=AgentType | NobodyType, agent_classes="O---"),
    (ctx, args) -> current_perspective_subject!(ctx.runtime))
  register_primitive!(registry, "TIMER", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> timer_value(ctx.runtime.world))
  register_primitive!(registry, "DATE-AND-TIME", REPORTER, reporter_syntax(ret=StringType),
    (ctx, args) -> begin
      now_time = Dates.now()
      h24 = Dates.hour(now_time)
      h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24)
      ampm = h24 < 12 ? "AM" : "PM"
      m = Dates.minute(now_time)
      s = Dates.second(now_time)
      ms = Dates.millisecond(now_time)
      d = Dates.day(now_time)
      mon = Dates.monthabbr(now_time)
      y = Dates.year(now_time)
      string(lpad(h12, 2, '0'), ":", lpad(m, 2, '0'), ":", lpad(s, 2, '0'), ".", lpad(ms, 3, '0'),
             " ", ampm, " ", lpad(d, 2, '0'), "-", mon, "-", y)
    end)
  register_primitive!(registry, "TICKS", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> current_ticks(ctx.runtime.world))
  register_primitive!(registry, "WORLD-WIDTH", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(world_width(ctx.runtime.world)))
  register_primitive!(registry, "WORLD-HEIGHT", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(world_height(ctx.runtime.world)))
  register_primitive!(registry, "PATCH-SIZE", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> ctx.runtime.world.patch_size)
  register_primitive!(registry, "PLOT-PEN-EXISTS?", REPORTER, reporter_syntax(right=[StringType], ret=BooleanType, agent_classes="OTPL"),
    (ctx, args) -> plot_pen_exists(ctx.runtime, String(args[1])))
  register_primitive!(registry, "AUTOPLOT?", REPORTER, reporter_syntax(ret=BooleanType, agent_classes="O---"),
    (ctx, args) -> plot_autoplot(ctx.runtime))
  register_primitive!(registry, "AUTOPLOTX?", REPORTER, reporter_syntax(ret=BooleanType, agent_classes="O---"),
    (ctx, args) -> plot_autoplot_x(ctx.runtime))
  register_primitive!(registry, "AUTOPLOTY?", REPORTER, reporter_syntax(ret=BooleanType, agent_classes="O---"),
    (ctx, args) -> plot_autoplot_y(ctx.runtime))
  register_primitive!(registry, "PLOT-NAME", REPORTER, reporter_syntax(ret=StringType, agent_classes="OTPL"),
    (ctx, args) -> plot_name(ctx.runtime))
  register_primitive!(registry, "PLOT-X-MIN", REPORTER, reporter_syntax(ret=NumberType, agent_classes="OTPL"),
    (ctx, args) -> plot_x_min(ctx.runtime))
  register_primitive!(registry, "PLOT-X-MAX", REPORTER, reporter_syntax(ret=NumberType, agent_classes="OTPL"),
    (ctx, args) -> plot_x_max(ctx.runtime))
  register_primitive!(registry, "PLOT-Y-MIN", REPORTER, reporter_syntax(ret=NumberType, agent_classes="OTPL"),
    (ctx, args) -> plot_y_min(ctx.runtime))
  register_primitive!(registry, "PLOT-Y-MAX", REPORTER, reporter_syntax(ret=NumberType, agent_classes="OTPL"),
    (ctx, args) -> plot_y_max(ctx.runtime))
  register_primitive!(registry, "SHAPES", REPORTER, reporter_syntax(ret=ListType),
    (ctx, args) -> Any[DEFAULT_SHAPE_NAMES...])
  register_primitive!(registry, "LINK-SHAPES", REPORTER, reporter_syntax(ret=ListType),
    (ctx, args) -> Any["default"])
  register_primitive!(registry, "NETLOGO-VERSION", REPORTER, reporter_syntax(ret=StringType),
    (ctx, args) -> NETLOGO_VERSION_STRING)
  register_primitive!(registry, "NETLOGO-WEB?", REPORTER, reporter_syntax(ret=BooleanType),
    (ctx, args) -> false)
  register_primitive!(registry, "STOP-INSPECTING", COMMAND, command_syntax(right=[AgentType]),
    (ctx, args) -> nothing)  # headless no-op
  register_primitive!(registry, "EXPORT-INTERFACE", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> nothing)  # headless: no interface to export
  register_primitive!(registry, "HOME-DIRECTORY", REPORTER, reporter_syntax(ret=StringType),
    (ctx, args) -> homedir())
  register_primitive!(registry, "BEHAVIORSPACE-RUN-NUMBER", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> 0.0)
  register_primitive!(registry, "BEHAVIORSPACE-EXPERIMENT-NAME", REPORTER, reporter_syntax(ret=StringType),
    (ctx, args) -> "")
  register_primitive!(registry, "__NANO-TIME", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(time_ns()))
  register_primitive!(registry, "MIN-PXCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(ctx.runtime.world.min_pxcor))
  register_primitive!(registry, "MAX-PXCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(ctx.runtime.world.max_pxcor))
  register_primitive!(registry, "MIN-PYCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(ctx.runtime.world.min_pycor))
  register_primitive!(registry, "MAX-PYCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> Float64(ctx.runtime.world.max_pycor))
  register_primitive!(registry, "NOT", REPORTER, reporter_syntax(right=[BooleanType], ret=BooleanType),
    (ctx, args) -> !logical(args[1]))
  register_primitive!(registry, "ABS", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> abs(numeric(args[1])))
  register_primitive!(registry, "FLOOR", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> floor(numeric(args[1])))
  register_primitive!(registry, "CEILING", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> ceil(numeric(args[1])))
  register_primitive!(registry, "ROUND", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_round(args[1]))
  register_primitive!(registry, "INT", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_int(args[1]))
  register_primitive!(registry, "SQRT", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_sqrt(args[1]))
  register_primitive!(registry, "SIN", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_sin(args[1]))
  register_primitive!(registry, "COS", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_cos(args[1]))
  register_primitive!(registry, "TAN", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_tan(args[1]))
  register_primitive!(registry, "ASIN", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_asin(args[1]))
  register_primitive!(registry, "ACOS", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_acos(args[1]))
  register_primitive!(registry, "ATAN", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> netlogo_atan(args[1], args[2]))
  register_primitive!(registry, "LN", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_ln(args[1]))
  register_primitive!(registry, "LOG", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> netlogo_log(args[1], args[2]))
  register_primitive!(registry, "EXP", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> netlogo_exp(args[1]))
  register_primitive!(registry, "PRECISION", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> precision_value(args[1], args[2]))
  register_primitive!(registry, "BASE-COLORS", REPORTER, reporter_syntax(ret=ListType),
    (ctx, args) -> Any[BASE_COLOR_VALUES...])
  register_primitive!(registry, "WRAP-COLOR", REPORTER, reporter_syntax(right=[NumberType], ret=NumberType),
    (ctx, args) -> wrap_color_number(args[1]))
  register_primitive!(registry, "SHADE-OF?", REPORTER, reporter_syntax(right=[WildcardType, WildcardType], ret=BooleanType),
    (ctx, args) -> shade_of(args[1], args[2]))
  register_primitive!(registry, "RGB", REPORTER, reporter_syntax(right=[NumberType, NumberType, NumberType], ret=ListType),
    (ctx, args) -> rgb_list(args[1], args[2], args[3]))
  register_primitive!(registry, "HSB", REPORTER, reporter_syntax(right=[NumberType, NumberType, NumberType], ret=ListType),
    (ctx, args) -> hsb_list(args[1], args[2], args[3]))
  register_primitive!(registry, "EXTRACT-RGB", REPORTER, reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> extract_rgb_list(args[1]))
  register_primitive!(registry, "EXTRACT-HSB", REPORTER, reporter_syntax(right=[WildcardType], ret=ListType),
    (ctx, args) -> extract_hsb_list(args[1]))
  register_primitive!(registry, "APPROXIMATE-RGB", REPORTER, reporter_syntax(right=[NumberType, NumberType, NumberType], ret=NumberType),
    (ctx, args) -> approximate_rgb_color(args[1], args[2], args[3]))
  register_primitive!(registry, "APPROXIMATE-HSB", REPORTER, reporter_syntax(right=[NumberType, NumberType, NumberType], ret=NumberType),
    (ctx, args) -> approximate_hsb_color(args[1], args[2], args[3]))
  register_primitive!(registry, "SCALE-COLOR", REPORTER, reporter_syntax(right=[WildcardType, NumberType, NumberType, NumberType], ret=NumberType),
    (ctx, args) -> scale_color(args[1], args[2], args[3], args[4]))
  for (color_name, color_value) in COLOR_CONSTANT_VALUES
    let color_name = color_name, color_value = color_value
      register_primitive!(registry, color_name, REPORTER, reporter_syntax(ret=NumberType),
        (ctx, args) -> color_value)
    end
  end
  register_primitive!(registry, "RANDOM-SEED", COMMAND, command_syntax(right=[NumberType]),
    function (ctx, args)
      seed = netlogo_random_seed(args[1])
      ctx.runtime.world.rng = MersenneTwister(seed)
      ctx.runtime.plot_rng = MersenneTwister(seed)
      nothing
    end)
  register_primitive!(registry, "ERROR", COMMAND, command_syntax(right=[StringType]),
    (ctx, args) -> throw(LogoRuntimeError(String(args[1]))))

  register_primitive!(registry, "+", REPORTER, reporter_syntax(left=NumberType, right=[NumberType], ret=NumberType, precedence=AddPrecedence),
    (ctx, args) -> numeric(args[1]) + numeric(args[2]))
  register_primitive!(registry, "-", REPORTER, reporter_syntax(left=NumberType, right=[NumberType], ret=NumberType, precedence=AddPrecedence),
    (ctx, args) -> numeric(args[1]) - numeric(args[2]))
  register_primitive!(registry, "*", REPORTER, reporter_syntax(left=NumberType, right=[NumberType], ret=NumberType, precedence=MultiplyPrecedence),
    (ctx, args) -> numeric(args[1]) * numeric(args[2]))
  register_primitive!(registry, "/", REPORTER, reporter_syntax(left=NumberType, right=[NumberType], ret=NumberType, precedence=MultiplyPrecedence),
    (ctx, args) -> netlogo_divide(args[1], args[2]))
  register_primitive!(registry, "^", REPORTER, reporter_syntax(left=NumberType, right=[NumberType], ret=NumberType, precedence=PowerPrecedence),
    (ctx, args) -> netlogo_power(args[1], args[2]))
  register_primitive!(registry, "MOD", REPORTER, reporter_syntax(left=NumberType, right=[NumberType], ret=NumberType, precedence=MultiplyPrecedence),
    (ctx, args) -> netlogo_mod(args[1], args[2]))
  register_primitive!(registry, "REMAINDER", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> netlogo_remainder(args[1], args[2]))
  register_primitive!(registry, "SUBTRACT-HEADINGS", REPORTER, reporter_syntax(right=[NumberType, NumberType], ret=NumberType),
    (ctx, args) -> subtract_headings(args[1], args[2]))
  register_primitive!(registry, ">", REPORTER, reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=ComparePrecedence),
    (ctx, args) -> logo_compare(ctx.runtime.model, args[1], args[2], ">") > 0)
  register_primitive!(registry, "<", REPORTER, reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=ComparePrecedence),
    (ctx, args) -> logo_compare(ctx.runtime.model, args[1], args[2], "<") < 0)
  register_primitive!(registry, ">=", REPORTER, reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=ComparePrecedence),
    (ctx, args) -> logo_compare(ctx.runtime.model, args[1], args[2], ">=") >= 0)
  register_primitive!(registry, "<=", REPORTER, reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=ComparePrecedence),
    (ctx, args) -> logo_compare(ctx.runtime.model, args[1], args[2], "<=") <= 0)
  register_primitive!(registry, "=", REPORTER, reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=ComparePrecedence),
    (ctx, args) -> logo_equal(args[1], args[2]))
  register_primitive!(registry, "!=", REPORTER, reporter_syntax(left=WildcardType, right=[WildcardType], ret=BooleanType, precedence=ComparePrecedence),
    (ctx, args) -> !logo_equal(args[1], args[2]))
  register_primitive!(registry, "AND", REPORTER, reporter_syntax(left=BooleanType, right=[BooleanType], ret=BooleanType, precedence=AndPrecedence),
    (ctx, args) -> logical(args[1]) && logical(args[2]))
  register_primitive!(registry, "OR", REPORTER, reporter_syntax(left=BooleanType, right=[BooleanType], ret=BooleanType, precedence=OrPrecedence),
    (ctx, args) -> logical(args[1]) || logical(args[2]))
  register_primitive!(registry, "XOR", REPORTER, reporter_syntax(left=BooleanType, right=[BooleanType], ret=BooleanType, precedence=XorPrecedence),
    (ctx, args) -> logical(args[1]) != logical(args[2]))

  # Mouse reporters (headless defaults)
  register_primitive!(registry, "MOUSE-DOWN?", REPORTER, reporter_syntax(ret=BooleanType),
    (ctx, args) -> false)
  register_primitive!(registry, "MOUSE-XCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> 0.0)
  register_primitive!(registry, "MOUSE-YCOR", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> 0.0)
  register_primitive!(registry, "MOUSE-INSIDE?", REPORTER, reporter_syntax(ret=BooleanType),
    (ctx, args) -> false)

  # Math constants
  register_primitive!(registry, "PI", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> π)
  register_primitive!(registry, "E", REPORTER, reporter_syntax(ret=NumberType),
    (ctx, args) -> MathConstants.e)

  # System dynamics stubs
  register_primitive!(registry, "SYSTEM-DYNAMICS-SETUP", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "SYSTEM-DYNAMICS-GO", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "SYSTEM-DYNAMICS-DO-PLOT", COMMAND, command_syntax(agent_classes="O---"),
    (ctx, args) -> nothing)

  # Legacy / internal commands
  register_primitive!(registry, "__SET-LINE-THICKNESS", COMMAND, command_syntax(right=[NumberType], agent_classes="-T--"),
    (ctx, args) -> nothing)
  register_primitive!(registry, "__HUBNET-MAKE-PLOT-NARROWCAST", COMMAND, command_syntax(right=[StringType], agent_classes="O---"),
    (ctx, args) -> nothing)

  register_primitive!(registry, "__HUBNET-CLEAR-PLOT", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> nothing)

  register_primitive!(registry, "__HUBNET-PLOT", COMMAND, command_syntax(right=[StringType, NumberType], agent_classes="OTPL"),
    (ctx, args) -> nothing)

  register_primitive!(registry, "__HUBNET-PLOT-PEN-DOWN", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> nothing)

  register_primitive!(registry, "__HUBNET-PLOT-PEN-UP", COMMAND, command_syntax(right=[StringType], agent_classes="OTPL"),
    (ctx, args) -> nothing)

  registry
end
