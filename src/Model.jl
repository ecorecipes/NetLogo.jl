@enum TokenKind begin
  IdentifierToken
  NumberToken
  StringToken
  LBracketToken
  RBracketToken
  LParenToken
  RParenToken
  CommaToken
  OperatorToken
  NewlineToken
  EofToken
end

struct Token
  kind::TokenKind
  lexeme::String
  value::Any
  span::SourceSpan
end

abstract type AbstractNode end
abstract type AbstractExpr <: AbstractNode end
abstract type AbstractStmt <: AbstractNode end

struct NumberLiteral <: AbstractExpr
  value::Float64
  span::SourceSpan
end

struct StringLiteral <: AbstractExpr
  value::String
  span::SourceSpan
end

struct BoolLiteral <: AbstractExpr
  value::Bool
  span::SourceSpan
end

struct NobodyLiteral <: AbstractExpr
  span::SourceSpan
end

struct ListLiteral <: AbstractExpr
  items::Vector{AbstractExpr}
  span::SourceSpan
end

struct VariableRef <: AbstractExpr
  name::String
  span::SourceSpan
end

struct UnaryExpr <: AbstractExpr
  op::String
  arg::AbstractExpr
  span::SourceSpan
end

struct SymbolArg <: AbstractNode
  name::String
  span::SourceSpan
end

struct ReporterCall <: AbstractExpr
  name::String
  args::Vector{Any}
  span::SourceSpan
end

struct CommandCall <: AbstractStmt
  name::String
  args::Vector{Any}
  span::SourceSpan
end

struct BlockNode <: AbstractNode
  statements::Vector{AbstractStmt}
  span::SourceSpan
end

struct CodeBlockNode <: AbstractNode
  body::Any
  source::String
  span::SourceSpan
end

struct ReporterBlockNode <: AbstractExpr
  params::Vector{String}
  expr::AbstractExpr
  span::SourceSpan
end

struct CommandTaskNode <: AbstractExpr
  params::Vector{String}
  body::BlockNode
  span::SourceSpan
end

struct CallableRefNode <: AbstractExpr
  name::String
  span::SourceSpan
end

spanof(node::AbstractNode) = getfield(node, :span)

struct BreedSpec
  plural::String
  singular::String
  is_link_breed::Bool
  directed::Bool
  owns::Vector{String}
end

struct PlotPenSpec
  name::String
  default_color::Any
  default_interval::Float64
  default_mode::Int
  in_legend::Bool
  setup_code::String
  update_code::String
end

struct PlotSpec
  name::String
  x_axis::String
  y_axis::String
  default_x_min::Float64
  default_x_max::Float64
  default_y_min::Float64
  default_y_max::Float64
  auto_plot_x::Bool
  auto_plot_y::Bool
  legend_open::Bool
  setup_code::String
  update_code::String
  pens::Vector{PlotPenSpec}
end

abstract type InterfaceWidgetSpec end

struct ViewWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  patch_size::Float64
  font_size::Int
  wrap_x::Bool
  wrap_y::Bool
  min_pxcor::Int
  max_pxcor::Int
  min_pycor::Int
  max_pycor::Int
  show_tick_counter::Bool
  tick_counter_label::String
  frame_rate::Float64
end

struct SliderWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  display::String
  variable::String
  minimum::String
  maximum::String
  default_value::Float64
  step::String
  units::String
  direction::String
end

struct SwitchWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  display::String
  variable::String
  on::Bool
end

struct ChooserWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  display::String
  variable::String
  choices::Vector{Any}
  current_choice::Int
end

struct InputBoxWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  variable::String
  value::Any
  multiline::Bool
  value_kind::String
end

struct MonitorWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  display::String
  source::String
  precision::Int
  font_size::Int
end

struct ButtonWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  display::String
  source::String
  forever::Bool
  button_kind::String
  action_key::Union{Nothing, Char}
  disable_until_ticks_start::Bool
end

struct TextBoxWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  display::String
  font_size::Int
  color::Float64
  transparent::Bool
end

struct OutputWidgetSpec <: InterfaceWidgetSpec
  left::Int
  top::Int
  right::Int
  bottom::Int
  font_size::Int
end

struct ProcedureSpec
  name::String
  is_reporter::Bool
  inputs::Vector{String}
  body::BlockNode
  span::SourceSpan
end

mutable struct ModelSpec
  source::String
  globals::Vector{String}
  turtles_own::Vector{String}
  patches_own::Vector{String}
  links_own::Vector{String}
  breeds::Vector{BreedSpec}
  link_breeds::Vector{BreedSpec}
  extensions::Vector{String}
  includes::Vector{String}
  procedures::Dict{String, ProcedureSpec}
  procedure_order::Vector{String}
  plots::Vector{PlotSpec}
  interface_widgets::Vector{InterfaceWidgetSpec}
  interface_globals::Dict{String, Any}
  view_widget::Union{Nothing, ViewWidgetSpec}
  has_interface_section::Bool
end

const CompiledModel = ModelSpec

function ModelSpec(source::String)
  ModelSpec(
    source,
    String[],
    String[],
    String[],
    String[],
    BreedSpec[],
    BreedSpec[],
    String[],
    String[],
    Dict{String, ProcedureSpec}(),
    String[],
    PlotSpec[],
    InterfaceWidgetSpec[],
    Dict{String, Any}(),
    nothing,
    false)
end

function breed_index(breeds::Vector{BreedSpec}, plural::AbstractString)
  # Fast path: names from parser are already uppercase/canonical
  for i in eachindex(breeds)
    breeds[i].plural == plural && return i
  end
  nothing
end

turtle_breed_index(model::ModelSpec, plural::AbstractString) = breed_index(model.breeds, plural)
link_breed_index(model::ModelSpec, plural::AbstractString) = breed_index(model.link_breeds, plural)
has_turtle_breed(model::ModelSpec, plural::AbstractString) = turtle_breed_index(model, plural) !== nothing
has_link_breed(model::ModelSpec, plural::AbstractString) = link_breed_index(model, plural) !== nothing

function singular_breed_index(breeds::Vector{BreedSpec}, singular::AbstractString)
  for i in eachindex(breeds)
    breeds[i].singular == singular && return i
  end
  nothing
end

turtle_breed_singular_index(model::ModelSpec, singular::AbstractString) = singular_breed_index(model.breeds, singular)
link_breed_singular_index(model::ModelSpec, singular::AbstractString) = singular_breed_index(model.link_breeds, singular)

function turtle_breed_by_singular(model::ModelSpec, singular::AbstractString)
  index = turtle_breed_singular_index(model, singular)
  index === nothing ? nothing : model.breeds[index]
end

function link_breed_by_singular(model::ModelSpec, singular::AbstractString)
  index = link_breed_singular_index(model, singular)
  index === nothing ? nothing : model.link_breeds[index]
end

function link_breed_by_plural(model::ModelSpec, plural::AbstractString)
  index = link_breed_index(model, plural)
  index === nothing ? nothing : model.link_breeds[index]
end

function set_turtle_breed_owns!(model::ModelSpec, plural::AbstractString, owns::Vector{String})
  index = turtle_breed_index(model, plural)
  index === nothing && return false
  breed = model.breeds[index]
  model.breeds[index] = BreedSpec(breed.plural, breed.singular, breed.is_link_breed, breed.directed, owns)
  true
end

function set_link_breed_owns!(model::ModelSpec, plural::AbstractString, owns::Vector{String})
  index = link_breed_index(model, plural)
  index === nothing && return false
  breed = model.link_breeds[index]
  model.link_breeds[index] = BreedSpec(breed.plural, breed.singular, breed.is_link_breed, breed.directed, owns)
  true
end

struct LogoRuntimeError <: Exception
  message::String
end

Base.showerror(io::IO, err::LogoRuntimeError) = print(io, err.message)

@enum AgentKind begin
  ObserverKind
  TurtleKind
  PatchKind
  LinkKind
end

abstract type AbstractAgent end

mutable struct Observer <: AbstractAgent
  globals::Dict{String, Any}
end

mutable struct Turtle <: AbstractAgent
  id::Int
  xcor::Float64
  ycor::Float64
  heading::Float64
  color::Any
  shape::String
  label::Any
  label_color::Any
  breed::String
  hidden::Bool
  size::Float64
  pen_size::Float64
  pen_mode::String
  own::Dict{String, Any}
  alive::Bool
end

mutable struct Patch <: AbstractAgent
  pxcor::Int
  pycor::Int
  pcolor::Any
  plabel::Any
  plabel_color::Any
  own::Dict{String, Any}
  turtles_here::Vector{Int}
  alive::Bool
end

mutable struct Link <: AbstractAgent
  id::Int
  end1::Int
  end2::Int
  color::Any
  label::Any
  label_color::Any
  hidden::Bool
  breed::String
  directed::Bool
  thickness::Float64
  shape::String
  tie_mode::String
  own::Dict{String, Any}
  alive::Bool
end

struct TurtlePose
  x::Float64
  y::Float64
  heading::Float64
end

TurtlePose(turtle::Turtle) = TurtlePose(turtle.xcor, turtle.ycor, turtle.heading)

struct AgentSet
  kind::AgentKind
  members::Vector{AbstractAgent}
  breed::Union{Nothing, String}
  dynamic::Bool
  world::Any
end

AgentSet(
  kind::AgentKind,
  members::Vector{<:AbstractAgent};
  breed::Union{Nothing, String}=nothing,
  dynamic::Bool=false,
  world=nothing) =
  AgentSet(kind, AbstractAgent[members...], breed, dynamic, world)

agent_is_live(::Observer) = true
agent_is_live(agent::Patch) = agent.alive
agent_is_live(agent::Turtle) = agent.alive
agent_is_live(agent::Link) = agent.alive

function Base.length(agentset::AgentSet)
  # Fast path for dynamic patch agentsets (all patches are always alive)
  if agentset.dynamic && agentset.world isa World
    world = agentset.world::World
    if agentset.kind == PatchKind && (agentset.breed === nothing || agentset.breed == "")
      return length(world.patches)
    end
  end
  count(agent_is_live, current_agentset_members(agentset))
end

function Base.iterate(agentset::AgentSet, state=(current_agentset_members(agentset), 1))
  members, index = state
  @inbounds while index <= length(members)
    agent = members[index]
    if agent_is_live(agent)
      return agent, (members, index + 1)
    end
    index += 1
  end
  nothing
end

live_members(agentset::AgentSet) = AbstractAgent[agent for agent in agentset if true]

@enum TopologyMode begin
  Torus
  VerticalCylinder
  HorizontalCylinder
  BoxTopology
end

mutable struct World
  model::ModelSpec
  min_pxcor::Int
  max_pxcor::Int
  min_pycor::Int
  max_pycor::Int
  topology::TopologyMode
  patch_size::Float64
  patches::Vector{Patch}
  turtles::Vector{Turtle}
  links::Vector{Link}
  observer::Observer
  turtle_breed_shapes::Dict{String, String}
  link_breed_shapes::Dict{String, String}
  next_turtle_id::Int
  next_link_id::Int
  ticks::Float64
  rng::MersenneTwister
  timer_start_ns::UInt64
  drawing::Union{Nothing, Matrix{NTuple{4, Float64}}}
end

world_width(world::World) = world.max_pxcor - world.min_pxcor + 1
world_height(world::World) = world.max_pycor - world.min_pycor + 1
drawing_width(world::World) = round(Int, world.patch_size * world_width(world))
drawing_height(world::World) = round(Int, world.patch_size * world_height(world))
blank_drawing(world::World) = fill((0.0, 0.0, 0.0, 0.0), drawing_height(world), drawing_width(world))

function default_global_map(model::ModelSpec)
  globals = Dict{String, Any}()
  for name in model.globals
    globals[name] = get(model.interface_globals, name, 0.0)
  end
  globals
end
default_own_map(names::Vector{String}) = Dict{String, Any}(name => 0.0 for name in names)

default_breed_shape(shapes::Dict{String, String}, breed::String, generic_breed::String) =
  get(shapes, breed, get(shapes, generic_breed, "default"))

default_turtle_shape(world::World, breed::AbstractString) =
  default_breed_shape(world.turtle_breed_shapes, canonical_name(breed), "TURTLES")

default_link_shape(world::World, breed::AbstractString) =
  default_breed_shape(world.link_breed_shapes, canonical_name(breed), "LINKS")

set_default_turtle_shape!(world::World, breed::AbstractString, shape::AbstractString) =
  (world.turtle_breed_shapes[canonical_name(breed)] = String(shape); world)

set_default_link_shape!(world::World, breed::AbstractString, shape::AbstractString) =
  (world.link_breed_shapes[canonical_name(breed)] = String(shape); world)

function World(
  model::ModelSpec;
  min_pxcor::Union{Nothing, Integer}=nothing,
  max_pxcor::Union{Nothing, Integer}=nothing,
  min_pycor::Union{Nothing, Integer}=nothing,
  max_pycor::Union{Nothing, Integer}=nothing,
  topology::Union{Nothing, TopologyMode}=nothing,
  patch_size::Union{Nothing, Real}=nothing,
  seed::Integer=1)
  view = model.view_widget
  resolved_min_pxcor = min_pxcor === nothing ? (view === nothing ? -16 : view.min_pxcor) : Int(min_pxcor)
  resolved_max_pxcor = max_pxcor === nothing ? (view === nothing ? 16 : view.max_pxcor) : Int(max_pxcor)
  resolved_min_pycor = min_pycor === nothing ? (view === nothing ? -16 : view.min_pycor) : Int(min_pycor)
  resolved_max_pycor = max_pycor === nothing ? (view === nothing ? 16 : view.max_pycor) : Int(max_pycor)
  resolved_topology = topology === nothing ? (view === nothing ? Torus : topology_from_wraps(view.wrap_x, view.wrap_y)) : topology
  resolved_patch_size = patch_size === nothing ? (view === nothing ? 12.0 : view.patch_size) : Float64(patch_size)
  observer = Observer(default_global_map(model))
  world = World(
    model,
    resolved_min_pxcor,
    resolved_max_pxcor,
    resolved_min_pycor,
    resolved_max_pycor,
    resolved_topology,
    resolved_patch_size,
    Patch[],
    Turtle[],
    Link[],
    observer,
    Dict{String, String}("TURTLES" => "default"),
    Dict{String, String}("LINKS" => "default"),
    0,
    0,
    -1.0,
    MersenneTwister(seed),
    time_ns(),
    nothing)
  rebuild_patches!(world)
  world
end

function patch_index(world::World, x::Int, y::Int)
  if x < world.min_pxcor || x > world.max_pxcor || y < world.min_pycor || y > world.max_pycor
    throw(LogoRuntimeError("patch coordinates out of bounds: ($x, $y)"))
  end
  (world_width(world) * (world.max_pycor - y)) + (x - world.min_pxcor) + 1
end

get_patch(world::World, x::Int, y::Int) = world.patches[patch_index(world, x, y)]

"""Alias for get_patch; used by ExtGis.jl."""
function patch_at_coords(world::World, x::Int, y::Int)
  idx = patch_index(world, x, y)
  (idx < 1 || idx > length(world.patches)) ? nothing : world.patches[idx]
end

function wrap_axis(pos::Float64, mincor::Int, maxcor::Int)
  low = mincor - 0.5
  high = maxcor + 0.5
  span = high - low
  value = mod(pos - low, span) + low
  value == high ? low : value
end

function apply_topology(world::World, x::Float64, y::Float64)
  if world.topology == Torus
    return wrap_axis(x, world.min_pxcor, world.max_pxcor), wrap_axis(y, world.min_pycor, world.max_pycor)
  elseif world.topology == VerticalCylinder
    if y < world.min_pycor - 0.5 || y > world.max_pycor + 0.5
      throw(LogoRuntimeError("y coordinate out of bounds in non-wrapping topology"))
    end
    return wrap_axis(x, world.min_pxcor, world.max_pxcor), y
  elseif world.topology == HorizontalCylinder
    if x < world.min_pxcor - 0.5 || x > world.max_pxcor + 0.5
      throw(LogoRuntimeError("x coordinate out of bounds in non-wrapping topology"))
    end
    return x, wrap_axis(y, world.min_pycor, world.max_pycor)
  else
    if x < world.min_pxcor - 0.5 || x > world.max_pxcor + 0.5 ||
       y < world.min_pycor - 0.5 || y > world.max_pycor + 0.5
      throw(LogoRuntimeError("coordinates out of bounds in box topology"))
    end
    return x, y
  end
end

round_patch_coord(pos::Float64) = floor(Int, pos + 0.5)

function patch_for_position(world::World, x::Float64, y::Float64)
  wrapped_x, wrapped_y = apply_topology(world, x, y)
  get_patch(world, round_patch_coord(wrapped_x), round_patch_coord(wrapped_y))
end

function reset_patch_memberships!(world::World)
  for patch in world.patches
    empty!(patch.turtles_here)
  end
  nothing
end

function invalidate_patches!(world::World)
  foreach(patch -> (patch.alive = false), world.patches)
  nothing
end

function register_turtle_on_patch!(world::World, turtle::Turtle)
  patch = patch_for_position(world, turtle.xcor, turtle.ycor)
  if turtle.id ∉ patch.turtles_here
    push!(patch.turtles_here, turtle.id)
  end
  nothing
end

function unregister_turtle_from_patch!(world::World, turtle::Turtle)
  patch = patch_for_position(world, turtle.xcor, turtle.ycor)
  th = patch.turtles_here
  tid = turtle.id
  idx = findfirst(==(tid), th)
  idx !== nothing && deleteat!(th, idx)
  nothing
end

function rebuild_patches!(world::World)
  invalidate_patches!(world)
  patches = Patch[]
  for y in reverse(world.min_pycor:world.max_pycor)
    for x in world.min_pxcor:world.max_pxcor
      push!(patches, Patch(x, y, 0.0, nothing, 9.9, default_own_map(world.model.patches_own), Int[], true))
    end
  end
  world.patches = patches
  reset_patch_memberships!(world)
  nothing
end

function reset_globals!(world::World)
  empty!(world.observer.globals)
  for (name, value) in default_global_map(world.model)
    world.observer.globals[name] = value
  end
  nothing
end

clear_globals!(world::World) = reset_globals!(world)

function clear_patches!(world::World)
  for patch in world.patches
    patch.pcolor = 0.0
    patch.plabel = nothing
    patch.plabel_color = 9.9
    patch.own = default_own_map(world.model.patches_own)
  end
  nothing
end

function clear_turtles!(world::World; reset_ids::Bool=true)
  foreach(turtle -> (turtle.alive = false), world.turtles)
  foreach(link -> (link.alive = false), world.links)
  empty!(world.turtles)
  empty!(world.links)
  reset_patch_memberships!(world)
  if reset_ids
    world.next_turtle_id = 0
    world.next_link_id = 0
  end
  nothing
end

function clear_links!(world::World; reset_ids::Bool=false)
  foreach(link -> (link.alive = false), world.links)
  empty!(world.links)
  if reset_ids
    world.next_link_id = 0
  end
  nothing
end

function clear_all!(world::World)
  clear_turtles!(world)
  rebuild_patches!(world)
  reset_globals!(world)
  world.ticks = -1.0
  world.drawing === nothing || clear_drawing!(world)
  nothing
end

topology_from_wraps(wrap_x::Bool, wrap_y::Bool) =
  wrap_x ?
  (wrap_y ? Torus : VerticalCylinder) :
  (wrap_y ? HorizontalCylinder : BoxTopology)

function set_topology!(world::World, wrap_x::Bool, wrap_y::Bool)
  world.topology = topology_from_wraps(wrap_x, wrap_y)
  world
end

function resize_world!(world::World, min_pxcor::Int, max_pxcor::Int, min_pycor::Int, max_pycor::Int)
  clear_turtles!(world)
  world.min_pxcor = min_pxcor
  world.max_pxcor = max_pxcor
  world.min_pycor = min_pycor
  world.max_pycor = max_pycor
  rebuild_patches!(world)
  world.drawing === nothing || clear_drawing!(world)
  world
end

function clear_drawing!(world::World)
  world.drawing = blank_drawing(world)
  nothing
end

function default_turtle_own(world::World, breed::String)
  values = default_own_map(world.model.turtles_own)
  for breed_spec in world.model.breeds
    if breed_spec.plural == breed
      foreach(name -> values[name] = 0.0, breed_spec.owns)
    end
  end
  values
end

function default_link_own(world::World, breed::String)
  values = default_own_map(world.model.links_own)
  for breed_spec in world.model.link_breeds
    if breed_spec.plural == breed
      foreach(name -> values[name] = 0.0, breed_spec.owns)
    end
  end
  values
end

function is_directed_link_breed(model::ModelSpec, breed::String)
  canonical = canonical_name(breed)
  canonical == "LINKS" && return false
  spec = link_breed_by_plural(model, canonical)
  spec === nothing && throw(LogoRuntimeError("unknown link breed $breed"))
  spec.directed
end

copy_logo_slot_value(value) = value
copy_logo_slot_value(value::AbstractAgent) = value
copy_logo_slot_value(value::AgentSet) = value
copy_logo_slot_value(value::AbstractVector) = Any[copy_logo_slot_value(item) for item in value]
copy_logo_slot_value(value::Tuple) = tuple((copy_logo_slot_value(item) for item in value)...)
copy_logo_slot_value(value::Pair) = copy_logo_slot_value(first(value)) => copy_logo_slot_value(last(value))
copy_logo_slot_value(value::AbstractDict) =
  Dict(copy_logo_slot_value(key) => copy_logo_slot_value(item) for (key, item) in pairs(value))

function create_turtle!(
  world::World;
  breed::String="TURTLES",
  x::Float64=0.0,
  y::Float64=0.0,
  heading::Union{Nothing, Real}=nothing,
  color=nothing,
  shape::Union{Nothing, AbstractString}=nothing,
  label=nothing,
  label_color=9.9,
  hidden::Bool=false,
  size::Real=1.0,
  pen_size::Real=1.0,
  pen_mode::AbstractString="up",
  own=nothing)
  breed == "TURTLES" || has_turtle_breed(world.model, breed) ||
    throw(LogoRuntimeError("unknown turtle breed $breed"))
  heading_value = heading === nothing ? Float64(rand(world.rng, 0:359)) : Float64(heading)
  color_value = color === nothing ? 5.0 + 10.0 * Float64(rand(world.rng, 0:13)) : copy_logo_slot_value(color)
  shape_value = shape === nothing ? default_turtle_shape(world, breed) : String(shape)
  own_values =
    own === nothing ?
    default_turtle_own(world, breed) :
    Dict{String, Any}(String(name) => copy_logo_slot_value(value) for (name, value) in pairs(own))
  world.next_turtle_id += 1
  turtle = Turtle(
    world.next_turtle_id - 1,
    x,
    y,
    heading_value,
    color_value,
    shape_value,
    copy_logo_slot_value(label),
    copy_logo_slot_value(label_color),
    breed,
    hidden,
    Float64(size),
    Float64(pen_size),
    String(pen_mode),
    own_values,
    true)
  push!(world.turtles, turtle)
  register_turtle_on_patch!(world, turtle)
  turtle
end

function maybe_turtle_by_id(world::World, id::Integer)
  idx = id + 1
  if 1 <= idx <= length(world.turtles)
    turtle = @inbounds world.turtles[idx]
    turtle.id == id && turtle.alive && return turtle
  end
  # Fallback linear scan (e.g., after import-world with reordered turtles)
  for turtle in world.turtles
    turtle.id == id && turtle.alive && return turtle
  end
  nothing
end

function turtle_by_id(world::World, id::Integer)
  turtle = maybe_turtle_by_id(world, id)
  turtle !== nothing && return turtle
  throw(LogoRuntimeError("unknown turtle id $id"))
end

function set_turtle_breed!(world::World, turtle::Turtle, breed::AbstractString)
  canonical = canonical_name(breed)
  canonical == "TURTLES" || has_turtle_breed(world.model, canonical) ||
    throw(LogoRuntimeError("unknown turtle breed $breed"))
  old_breed = turtle.breed
  new_own = default_turtle_own(world, canonical)
  for (name, value) in turtle.own
    haskey(new_own, name) && (new_own[name] = copy_logo_slot_value(value))
  end
  turtle.breed = canonical
  turtle.own = new_own
  canonical != old_breed && (turtle.shape = default_turtle_shape(world, canonical))
  turtle
end

function existing_link(world::World, end1::Turtle, end2::Turtle, breed::String; directed::Union{Nothing, Bool}=nothing)
  canonical = canonical_name(breed)
  for link in world.links
    if link.alive && link.breed == canonical
      directed !== nothing && link.directed != directed && continue
      if link.directed
        link.end1 == end1.id && link.end2 == end2.id && return link
      elseif (link.end1 == end1.id && link.end2 == end2.id) || (link.end1 == end2.id && link.end2 == end1.id)
        return link
      end
    end
  end
  nothing
end

function create_link!(world::World, end1::Turtle, end2::Turtle; breed::String="LINKS", directed::Union{Nothing, Bool}=nothing)
  canonical_breed = canonical_name(breed)
  canonical_breed == "LINKS" || has_link_breed(world.model, canonical_breed) ||
    throw(LogoRuntimeError("unknown link breed $breed"))
  end1.id == end2.id && return nothing
  directed_link = canonical_breed == "LINKS" ? something(directed, false) : is_directed_link_breed(world.model, canonical_breed)
  existing = existing_link(world, end1, end2, canonical_breed; directed=directed_link)
  existing !== nothing && return existing

  world.next_link_id += 1
  link = Link(
    world.next_link_id - 1,
    end1.id,
    end2.id,
    5.0,
    nothing,
    9.9,
    false,
    canonical_breed,
    directed_link,
    0.0,
    default_link_shape(world, canonical_breed),
    "none",
    default_link_own(world, canonical_breed),
    true)
  push!(world.links, link)
  link
end

function kill_link!(world::World, link::Link)
  link.alive = false
  link
end

function kill_turtle!(world::World, turtle::Turtle)
  turtle.alive || return turtle
  unregister_turtle_from_patch!(world, turtle)
  turtle.alive = false
  for link in world.links
    link.alive && (link.end1 == turtle.id || link.end2 == turtle.id) && kill_link!(world, link)
  end
  turtle
end

function move_turtle_to_raw!(world::World, turtle::Turtle, x::Float64, y::Float64)
  unregister_turtle_from_patch!(world, turtle)
  turtle.xcor, turtle.ycor = apply_topology(world, x, y)
  register_turtle_on_patch!(world, turtle)
  turtle
end

set_turtle_heading_raw!(turtle::Turtle, heading::Real) = (turtle.heading = mod(Float64(heading), 360.0); turtle)

function set_turtle_pose_raw!(world::World, turtle::Turtle, x::Float64, y::Float64, heading::Real)
  move_turtle_to_raw!(world, turtle, x, y)
  set_turtle_heading_raw!(turtle, heading)
  turtle
end

signed_heading_delta(old_heading::Real, new_heading::Real) =
  mod(Float64(new_heading) - Float64(old_heading) + 180.0, 360.0) - 180.0

function rotate_clockwise_displacement(dx::Real, dy::Real, delta::Real)
  radians = deg2rad(Float64(delta))
  cosine = cos(radians)
  sine = sin(radians)
  Float64(dx) * cosine + Float64(dy) * sine,
  Float64(dy) * cosine - Float64(dx) * sine
end

function tied_targets(world::World, turtle_id::Int)
  targets = Tuple{Link, Int}[]
  for link in world.links
    link.alive || continue
    link.tie_mode == "none" && continue
    if link.directed
      link.end1 == turtle_id || continue
      push!(targets, (link, link.end2))
    else
      if link.end1 == turtle_id
        push!(targets, (link, link.end2))
      elseif link.end2 == turtle_id
        push!(targets, (link, link.end1))
      end
    end
  end
  targets
end

function plan_tied_turtle_pose!(
  world::World,
  turtle_id::Int,
  requested_pose::TurtlePose,
  snapshot::Dict{Int, TurtlePose},
  planned::Dict{Int, TurtlePose})
  haskey(planned, turtle_id) && return planned[turtle_id]
  old_root = snapshot[turtle_id]
  new_x, new_y = apply_topology(world, requested_pose.x, requested_pose.y)
  new_pose = TurtlePose(new_x, new_y, mod(requested_pose.heading, 360.0))
  planned[turtle_id] = new_pose

  delta = signed_heading_delta(old_root.heading, new_pose.heading)
  for (link, leaf_id) in tied_targets(world, turtle_id)
    haskey(planned, leaf_id) && continue
    haskey(snapshot, leaf_id) || continue
    old_leaf = snapshot[leaf_id]
    dx, dy = shortest_displacement(world, old_root.x, old_root.y, old_leaf.x, old_leaf.y)
    rotated_dx, rotated_dy = rotate_clockwise_displacement(dx, dy, delta)
    leaf_heading = link.tie_mode == "fixed" ? mod(old_leaf.heading + delta, 360.0) : old_leaf.heading
    plan_tied_turtle_pose!(
      world,
      leaf_id,
      TurtlePose(new_pose.x + rotated_dx, new_pose.y + rotated_dy, leaf_heading),
      snapshot,
      planned)
  end
  new_pose
end

function set_turtle_pose!(world::World, turtle::Turtle, x::Float64, y::Float64, heading::Real)
  # Fast path: if no links exist or no tied links, skip tie propagation entirely
  has_ties = false
  for link in world.links
    if link.alive && link.tie_mode != "none"
      has_ties = true
      break
    end
  end
  if !has_ties
    set_turtle_pose_raw!(world, turtle, x, y, heading)
    return turtle
  end

  snapshot = Dict{Int, TurtlePose}()
  for candidate in world.turtles
    candidate.alive || continue
    snapshot[candidate.id] = TurtlePose(candidate)
  end
  planned = Dict{Int, TurtlePose}()
  plan_tied_turtle_pose!(world, turtle.id, TurtlePose(x, y, Float64(heading)), snapshot, planned)
  for id in sort(collect(keys(planned)))
    candidate = maybe_turtle_by_id(world, id)
    candidate === nothing && continue
    pose = planned[id]
    set_turtle_pose_raw!(world, candidate, pose.x, pose.y, pose.heading)
  end
  turtle
end

set_turtle_heading!(world::World, turtle::Turtle, heading::Real) =
  set_turtle_pose!(world, turtle, turtle.xcor, turtle.ycor, heading)

move_turtle_to!(world::World, turtle::Turtle, x::Float64, y::Float64) =
  set_turtle_pose!(world, turtle, x, y, turtle.heading)

turn_turtle!(world::World, turtle::Turtle, delta::Real) =
  set_turtle_heading!(world, turtle, turtle.heading + Float64(delta))

function jump_turtle!(world::World, turtle::Turtle, distance::Real)
  heading_radians = deg2rad(turtle.heading)
  new_x = turtle.xcor + Float64(distance) * sin(heading_radians)
  new_y = turtle.ycor + Float64(distance) * cos(heading_radians)
  move_turtle_to!(world, turtle, new_x, new_y)
end

axis_wraps(world::World, axis::Symbol) =
  world.topology == Torus ||
  (axis == :x && world.topology == VerticalCylinder) ||
  (axis == :y && world.topology == HorizontalCylinder)

function shortest_axis_delta(raw_delta::Real, span::Int, wraps::Bool)
  delta = Float64(raw_delta)
  wraps || return delta
  mod(delta + span / 2, span) - span / 2
end

function shortest_displacement(world::World, source_x::Real, source_y::Real, target_x::Real, target_y::Real)
  dx = shortest_axis_delta(Float64(target_x) - Float64(source_x), world_width(world), axis_wraps(world, :x))
  dy = shortest_axis_delta(Float64(target_y) - Float64(source_y), world_height(world), axis_wraps(world, :y))
  dx, dy
end

function raw_displacement(_world::World, source_x::Real, source_y::Real, target_x::Real, target_y::Real)
  Float64(target_x) - Float64(source_x), Float64(target_y) - Float64(source_y)
end

agent_position(agent::Turtle) = agent.xcor, agent.ycor
agent_position(agent::Patch) = Float64(agent.pxcor), Float64(agent.pycor)

function distance_between(world::World, source_x::Real, source_y::Real, target_x::Real, target_y::Real)
  dx, dy = shortest_displacement(world, source_x, source_y, target_x, target_y)
  hypot(dx, dy)
end

function distance_between_nowrap(world::World, source_x::Real, source_y::Real, target_x::Real, target_y::Real)
  dx, dy = raw_displacement(world, source_x, source_y, target_x, target_y)
  hypot(dx, dy)
end

function link_length(world::World, link::Link)
  end1 = turtle_by_id(world, link.end1)
  end2 = turtle_by_id(world, link.end2)
  distance_between(world, end1.xcor, end1.ycor, end2.xcor, end2.ycor)
end

function heading_towards(world::World, source_x::Real, source_y::Real, target_x::Real, target_y::Real)
  dx, dy = shortest_displacement(world, source_x, source_y, target_x, target_y)
  dx == 0.0 && dy == 0.0 && throw(LogoRuntimeError("no heading is defined from a point to itself"))
  mod(rad2deg(atan(dx, dy)), 360.0)
end

function heading_towards_nowrap(world::World, source_x::Real, source_y::Real, target_x::Real, target_y::Real)
  dx, dy = raw_displacement(world, source_x, source_y, target_x, target_y)
  dx == 0.0 && dy == 0.0 && throw(LogoRuntimeError("no heading is defined from a point to itself"))
  mod(rad2deg(atan(dx, dy)), 360.0)
end

function patch_at_heading_and_distance(world::World, source_x::Real, source_y::Real, heading::Real, distance::Real)
  heading_radians = deg2rad(Float64(heading))
  target_x = Float64(source_x) + Float64(distance) * sin(heading_radians)
  target_y = Float64(source_y) + Float64(distance) * cos(heading_radians)
  maybe_patch(world, target_x, target_y)
end

function living_turtles(world::World)
  [turtle for turtle in world.turtles if turtle.alive]
end

function current_agentset_members(agentset::AgentSet)
  if !agentset.dynamic || !(agentset.world isa World)
    return agentset.members
  end

  world = agentset.world::World
  if agentset.kind == TurtleKind
    breed = agentset.breed
    if breed === nothing || breed == "TURTLES"
      return AbstractAgent[t for t in world.turtles if t.alive]
    end
    canonical_breed = canonical_name(breed)
    return AbstractAgent[t for t in world.turtles if t.alive && t.breed == canonical_breed]
  elseif agentset.kind == LinkKind
    breed = agentset.breed
    if breed === nothing || breed == "LINKS"
      return AbstractAgent[l for l in world.links if l.alive]
    end
    canonical_breed = canonical_name(breed)
    return AbstractAgent[l for l in world.links if l.alive && l.breed == canonical_breed]
  end

  # Patches are always all alive — return backing array directly to avoid allocation
  return world.patches
end

function all_turtles(world::World)
  AgentSet(TurtleKind, AbstractAgent[]; breed="TURTLES", dynamic=true, world=world)
end

function all_patches(world::World)
  AgentSet(PatchKind, AbstractAgent[]; dynamic=true, world=world)
end

function living_links(world::World)
  [link for link in world.links if link.alive]
end

function all_links(world::World)
  AgentSet(LinkKind, AbstractAgent[]; breed="LINKS", dynamic=true, world=world)
end

function breed_agentset(world::World, breed::AbstractString)
  canonical = canonical_name(breed)
  canonical == "TURTLES" && return all_turtles(world)
  has_turtle_breed(world.model, canonical) || throw(LogoRuntimeError("unknown turtle breed $breed"))
  AgentSet(TurtleKind, AbstractAgent[]; breed=canonical, dynamic=true, world=world)
end

function link_breed_agentset(world::World, breed::AbstractString)
  canonical = canonical_name(breed)
  canonical == "LINKS" && return all_links(world)
  has_link_breed(world.model, canonical) || throw(LogoRuntimeError("unknown link breed $breed"))
  AgentSet(LinkKind, AbstractAgent[]; breed=canonical, dynamic=true, world=world)
end

function maybe_patch(world::World, x::Real, y::Real)
  try
    wrapped_x, wrapped_y = apply_topology(world, Float64(x), Float64(y))
    get_patch(world, round_patch_coord(wrapped_x), round_patch_coord(wrapped_y))
  catch err
    if err isa LogoRuntimeError
      return NOBODY
    end
    rethrow()
  end
end

function turtles_on_patch(world::World, patch::Patch; breed::Union{Nothing, AbstractString}=nothing)
  canonical_breed = breed === nothing ? "TURTLES" : canonical_name(breed)
  breed === nothing || has_turtle_breed(world.model, canonical_breed) || throw(LogoRuntimeError("unknown turtle breed $breed"))
  members = sizehint!(Turtle[], length(patch.turtles_here))
  for id in patch.turtles_here
    turtle = maybe_turtle_by_id(world, id)
    turtle === nothing && continue
    (breed === nothing || turtle.breed == canonical_breed) && push!(members, turtle)
  end
  AgentSet(TurtleKind, members; breed=canonical_breed)
end

function patch_variable_value(patch::Patch, name::AbstractString)
  canonical = canonical_name(name)
  if canonical == "PXCOR"
    return Float64(patch.pxcor)
  elseif canonical == "PYCOR"
    return Float64(patch.pycor)
  elseif canonical == "PCOLOR"
    return patch.pcolor
  elseif canonical == "PLABEL"
    return patch.plabel
  elseif canonical == "PLABEL-COLOR"
    return patch.plabel_color
  elseif haskey(patch.own, canonical)
    return patch.own[canonical]
  end
  throw(LogoRuntimeError("unknown patch variable $name"))
end

function set_patch_variable!(patch::Patch, name::AbstractString, value)
  canonical = canonical_name(name)
  if canonical == "PXCOR" || canonical == "PYCOR"
    throw(LogoRuntimeError("$canonical is read-only"))
  elseif canonical == "PCOLOR"
    patch.pcolor = value
  elseif canonical == "PLABEL"
    patch.plabel = value
  elseif canonical == "PLABEL-COLOR"
    patch.plabel_color = value
  else
    patch.own[canonical] = value
  end
  value
end

function patch_neighbors(world::World, patch::Patch; four_way::Bool=false)
  deltas = four_way ?
    ((1, 0), (-1, 0), (0, 1), (0, -1)) :
    ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
  # Pre-allocate with max capacity; avoid Dict for common case
  max_n = four_way ? 4 : 8
  members = Vector{AbstractAgent}()
  sizehint!(members, max_n)
  px, py = patch.pxcor, patch.pycor
  for (dx, dy) in deltas
    neighbor = maybe_patch(world, px + dx, py + dy)
    neighbor === NOBODY && continue
    neighbor.pxcor == px && neighbor.pycor == py && continue
    # Check for duplicates (only possible at edges with wrapping)
    dup = false
    @inbounds for i in eachindex(members)
      existing = members[i]::Patch
      if existing.pxcor == neighbor.pxcor && existing.pycor == neighbor.pycor
        dup = true
        break
      end
    end
    dup || push!(members, neighbor)
  end
  sort!(members, by = p -> patch_index(world, (p::Patch).pxcor, (p::Patch).pycor))
  AgentSet(PatchKind, members)
end

function _read_patch_own(patch::Patch, canonical::String)
  if canonical == "PXCOR"
    return Float64(patch.pxcor)
  elseif canonical == "PYCOR"
    return Float64(patch.pycor)
  elseif canonical == "PCOLOR"
    return patch.pcolor
  elseif canonical == "PLABEL"
    return patch.plabel
  elseif canonical == "PLABEL-COLOR"
    return patch.plabel_color
  else
    return get(patch.own, canonical, nothing)
  end
end

function _write_patch_own!(patch::Patch, canonical::String, value)
  if canonical == "PCOLOR"
    patch.pcolor = value
  elseif canonical == "PLABEL"
    patch.plabel = value
  elseif canonical == "PLABEL-COLOR"
    patch.plabel_color = value
  else
    patch.own[canonical] = value
  end
  nothing
end

function diffuse_patches!(world::World, variable::AbstractString, amount::Real; four_way::Bool=false)
  canonical = canonical_name(variable)
  n = length(world.patches)
  old_values = Vector{Float64}(undef, n)
  @inbounds for i in 1:n
    value = _read_patch_own(world.patches[i], canonical)
    (value === nothing || !(value isa Real)) && throw(LogoRuntimeError("diffuse requires a numeric patch variable"))
    old_values[i] = Float64(value)
  end

  deltas = four_way ?
    ((1, 0), (-1, 0), (0, 1), (0, -1)) :
    ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))

  new_values = Vector{Float64}(undef, n)
  # Scratch buffer for neighbor indices to detect duplicates
  nbuf = Vector{Int}(undef, four_way ? 4 : 8)
  @inbounds for i in 1:n
    patch = world.patches[i]
    px, py = patch.pxcor, patch.pycor
    old_value = old_values[i]
    neighbor_sum = 0.0
    neighbor_count = 0
    for (dx, dy) in deltas
      np = maybe_patch(world, px + dx, py + dy)
      np === NOBODY && continue
      np.pxcor == px && np.pycor == py && continue
      j = patch_index(world, np.pxcor, np.pycor)
      # Check for duplicates (wrap edges)
      dup = false
      for k in 1:neighbor_count
        if nbuf[k] == j
          dup = true
          break
        end
      end
      dup && continue
      neighbor_count += 1
      nbuf[neighbor_count] = j
      neighbor_sum += old_values[j]
    end
    if neighbor_count == 0
      new_values[i] = old_value
    else
      avg = neighbor_sum / neighbor_count
      new_values[i] = old_value + Float64(amount) * (avg - old_value)
    end
  end

  @inbounds for i in 1:n
    _write_patch_own!(world.patches[i], canonical, new_values[i])
  end
  nothing
end

function my_links(world::World, turtle::Turtle; breed::Union{Nothing, String}=nothing, mode::Symbol=:all)
  canonical_breed = breed === nothing ? nothing : canonical_name(breed)
  members = Link[]
  for link in living_links(world)
    canonical_breed !== nothing && link.breed != canonical_breed && continue
    touches = link.end1 == turtle.id || link.end2 == turtle.id
    if mode == :all
      touches && push!(members, link)
    elseif mode == :in
      ((link.directed && link.end2 == turtle.id) || (!link.directed && touches)) && push!(members, link)
    elseif mode == :out
      ((link.directed && link.end1 == turtle.id) || (!link.directed && touches)) && push!(members, link)
    end
  end
  AgentSet(LinkKind, members; breed=canonical_breed)
end

function link_neighbors(world::World, turtle::Turtle; breed::Union{Nothing, String}=nothing, mode::Symbol=:all)
  ids = Set{Int}()
  for raw_link in my_links(world, turtle; breed=breed, mode=mode)
    link = raw_link::Link
    if mode == :in
      push!(ids, link.directed ? link.end1 : (link.end1 == turtle.id ? link.end2 : link.end1))
    elseif mode == :out
      push!(ids, link.directed ? link.end2 : (link.end1 == turtle.id ? link.end2 : link.end1))
    else
      push!(ids, link.end1 == turtle.id ? link.end2 : link.end1)
    end
  end
  members = [turtle_by_id(world, id) for id in sort(collect(ids))]
  AgentSet(TurtleKind, members; breed="TURTLES")
end
