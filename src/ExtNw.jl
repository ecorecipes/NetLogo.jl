module nw

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  TurtlesetType, LinksetType, AgentType, CommandBlockType,
  LogoRuntimeError, World, Turtle, Link, Context,
  live_agentset_members, collection_member, maybe_turtle_by_id,
  logo_equal, AbstractAgent, AgentSet, TurtleKind, BlockNode,
  create_turtle!, create_link!, run_block_for_agents!

function register_extension!(registry::PrimitiveRegistry)
  register_primitive!(registry, "NW:SET-CONTEXT", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType]),
    (ctx, args) -> nw_set_context!(ctx, args[1], args[2]))

  register_primitive!(registry, "NW:GET-CONTEXT", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> nw_get_context(ctx))

  register_primitive!(registry, "NW:TURTLES-IN-RADIUS", REPORTER,
    reporter_syntax(right=[NumberType], ret=TurtlesetType),
    (ctx, args) -> nw_turtles_in_radius(ctx, Int(args[1])))

  register_primitive!(registry, "NW:TURTLES-IN-REVERSE-RADIUS", REPORTER,
    reporter_syntax(right=[NumberType], ret=TurtlesetType),
    (ctx, args) -> nw_turtles_in_reverse_radius(ctx, Int(args[1])))

  register_primitive!(registry, "NW:DISTANCE-TO", REPORTER,
    reporter_syntax(right=[AgentType], ret=WildcardType),
    (ctx, args) -> nw_distance_to(ctx, args[1]))

  register_primitive!(registry, "NW:PATH-TO", REPORTER,
    reporter_syntax(right=[AgentType], ret=WildcardType),
    (ctx, args) -> nw_path_to(ctx, args[1]))

  register_primitive!(registry, "NW:MEAN-PATH-LENGTH", REPORTER,
    reporter_syntax(ret=WildcardType),
    (ctx, args) -> nw_mean_path_length(ctx))

  register_primitive!(registry, "NW:MEAN-WEIGHTED-PATH-LENGTH", REPORTER,
    reporter_syntax(right=[StringType], ret=WildcardType),
    (ctx, args) -> nw_mean_weighted_path_length(ctx, String(args[1])))

  register_primitive!(registry, "NW:CLUSTERING-COEFFICIENT", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> nw_clustering_coefficient(ctx))

  register_primitive!(registry, "NW:BETWEENNESS-CENTRALITY", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> nw_betweenness_centrality(ctx))

  register_primitive!(registry, "NW:CLOSENESS-CENTRALITY", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> nw_closeness_centrality(ctx))

  register_primitive!(registry, "NW:WEIGHTED-DISTANCE-TO", REPORTER,
    reporter_syntax(right=[AgentType, StringType], ret=WildcardType),
    (ctx, args) -> nw_weighted_distance_to(ctx, args[1], String(args[2])))

  register_primitive!(registry, "NW:WEIGHTED-PATH-TO", REPORTER,
    reporter_syntax(right=[AgentType, StringType], ret=WildcardType),
    (ctx, args) -> nw_weighted_path_to(ctx, args[1], String(args[2])))

  register_primitive!(registry, "NW:SAVE-GRAPHML", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> nw_save_graphml(ctx, String(args[1])))

  register_primitive!(registry, "NW:LOAD-GRAPHML", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> throw(LogoRuntimeError("nw:load-graphml is not supported in headless mode")))

  register_primitive!(registry, "NW:SAVE-MATRIX", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> nw_save_matrix(ctx, String(args[1])))

  register_primitive!(registry, "NW:GENERATE-PREFERENTIAL-ATTACHMENT", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType]),
    (ctx, args) -> nw_generate_preferential_attachment(ctx, args[1], args[2], Int(args[3]), args[4]))

  register_primitive!(registry, "NW:GENERATE-RANDOM", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, CommandBlockType]),
    (ctx, args) -> nw_generate_random(ctx, args[1], args[2], Int(args[3]), Float64(args[4]), args[5]))

  register_primitive!(registry, "NW:GENERATE-SMALL-WORLD", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, NumberType, BooleanType, CommandBlockType]),
    (ctx, args) -> nw_generate_small_world(ctx, args[1], args[2], Int(args[3]), Int(args[4]), Float64(args[5]), args[6], args[7]))

  register_primitive!(registry, "NW:GENERATE-STAR", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType]),
    (ctx, args) -> nw_generate_star(ctx, args[1], args[2], Int(args[3]), args[4]))

  register_primitive!(registry, "NW:GENERATE-WHEEL", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType]),
    (ctx, args) -> nw_generate_wheel(ctx, args[1], args[2], Int(args[3]), args[4]))

  register_primitive!(registry, "NW:GENERATE-LATTICE-2D", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, BooleanType, CommandBlockType]),
    (ctx, args) -> nw_generate_lattice_2d(ctx, args[1], args[2], Int(args[3]), Int(args[4]), args[5], args[6]))

  register_primitive!(registry, "NW:GENERATE-RING", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType]),
    (ctx, args) -> nw_generate_ring(ctx, args[1], args[2], Int(args[3]), args[4]))
end

# ── NW context state (stored on runtime via agent properties) ──────────

mutable struct NwContext
  turtleset::Any
  linkset::Any
end

const NW_CONTEXT_KEY = :__nw_context__

function get_nw_context(ctx::Context)
  haskey(ctx.runtime.world.observer.globals, "__NW_CONTEXT__") || throw(LogoRuntimeError("You must set the nw context first using nw:set-context"))
  ctx.runtime.world.observer.globals["__NW_CONTEXT__"]::NwContext
end

function nw_set_context!(ctx::Context, turtleset, linkset)
  ctx.runtime.world.observer.globals["__NW_CONTEXT__"] = NwContext(turtleset, linkset)
  nothing
end

function nw_get_context(ctx::Context)
  nc = get_nw_context(ctx)
  Any[nc.turtleset, nc.linkset]
end

# ── BFS utility ────────────────────────────────────────────────────────

function nw_neighbors(world::World, turtle::Turtle, linkset, turtleset)
  neighbors = Turtle[]
  for link in live_agentset_members(linkset)
    link isa Link || continue
    link.alive || continue
    other_id = nothing
    if link.end1 == turtle.id
      other_id = link.end2
    elseif link.end2 == turtle.id
      other_id = link.end1
    end
    if other_id !== nothing
      other = maybe_turtle_by_id(world, other_id)
      if other !== nothing && other.alive && collection_member(other, turtleset)
        push!(neighbors, other)
      end
    end
  end
  neighbors
end

function nw_bfs_distances(world::World, source::Turtle, linkset, turtleset)
  dist = Dict{Int, Int}(source.id => 0)
  queue = Turtle[source]
  while !isempty(queue)
    current = popfirst!(queue)
    d = dist[current.id]
    for nb in nw_neighbors(world, current, linkset, turtleset)
      if !haskey(dist, nb.id)
        dist[nb.id] = d + 1
        push!(queue, nb)
      end
    end
  end
  dist
end

function nw_bfs_path(world::World, source::Turtle, target::Turtle, linkset, turtleset)
  if source.id == target.id
    return Turtle[source]
  end
  prev = Dict{Int, Turtle}()
  visited = Set{Int}([source.id])
  queue = Turtle[source]
  found = false
  while !isempty(queue)
    current = popfirst!(queue)
    for nb in nw_neighbors(world, current, linkset, turtleset)
      if !in(nb.id, visited)
        push!(visited, nb.id)
        prev[nb.id] = current
        if nb.id == target.id
          found = true
          break
        end
        push!(queue, nb)
      end
    end
    found && break
  end
  !found && return false
  path = Turtle[target]
  current = target
  while current.id != source.id
    current = prev[current.id]
    pushfirst!(path, current)
  end
  Any[t for t in path]
end

# ── Primitives ─────────────────────────────────────────────────────────

function nw_turtles_in_radius(ctx::Context, radius::Int)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  source = ctx.agent::Turtle
  dist = nw_bfs_distances(world, source, nc.linkset, nc.turtleset)
  result = Turtle[]
  for t in live_agentset_members(nc.turtleset)
    t isa Turtle || continue
    t.alive || continue
    d = get(dist, t.id, -1)
    d >= 0 && d <= radius && push!(result, t)
  end
  AgentSet(TurtleKind, result; breed="TURTLES")
end

function nw_turtles_in_reverse_radius(ctx::Context, radius::Int)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  target = ctx.agent::Turtle
  result = Turtle[]
  for t in live_agentset_members(nc.turtleset)
    t isa Turtle || continue
    t.alive || continue
    dist = nw_bfs_distances(world, t, nc.linkset, nc.turtleset)
    d = get(dist, target.id, -1)
    d >= 0 && d <= radius && push!(result, t)
  end
  AgentSet(TurtleKind, result; breed="TURTLES")
end

function nw_distance_to(ctx::Context, target)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  target isa Turtle || throw(LogoRuntimeError("nw:distance-to expected a turtle"))
  source = ctx.agent::Turtle
  dist = nw_bfs_distances(world, source, nc.linkset, nc.turtleset)
  d = get(dist, target.id, -1)
  d < 0 ? false : Float64(d)
end

function nw_path_to(ctx::Context, target)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  target isa Turtle || throw(LogoRuntimeError("nw:path-to expected a turtle"))
  source = ctx.agent::Turtle
  nw_bfs_path(world, source, target, nc.linkset, nc.turtleset)
end

function nw_weighted_distance_to(ctx::Context, target, weight_var::String)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  target isa Turtle || throw(LogoRuntimeError("nw:weighted-distance-to expected a turtle"))
  source = ctx.agent::Turtle
  nw_dijkstra_distance(world, source, target, nc.linkset, nc.turtleset, weight_var)
end

function nw_weighted_path_to(ctx::Context, target, weight_var::String)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  target isa Turtle || throw(LogoRuntimeError("nw:weighted-path-to expected a turtle"))
  source = ctx.agent::Turtle
  nw_dijkstra_path(world, source, target, nc.linkset, nc.turtleset, weight_var)
end

function get_link_weight(link::Link, weight_var::String)
  key = uppercase(weight_var)
  haskey(link.own, key) || throw(LogoRuntimeError("Links don't have a variable called $weight_var"))
  Float64(link.own[key])
end

function nw_dijkstra_distance(world::World, source::Turtle, target::Turtle, linkset, turtleset, weight_var::String)
  if source.id == target.id
    return 0.0
  end
  dist = Dict{Int, Float64}(source.id => 0.0)
  visited = Set{Int}()
  pq = [(0.0, source)]
  while !isempty(pq)
    sort!(pq, by=first)
    d, current = popfirst!(pq)
    current.id in visited && continue
    push!(visited, current.id)
    current.id == target.id && return d
    for link in live_agentset_members(linkset)
      link isa Link || continue
      link.alive || continue
      other_id = nothing
      if link.end1 == current.id
        other_id = link.end2
      elseif link.end2 == current.id
        other_id = link.end1
      end
      other_id === nothing && continue
      nb = maybe_turtle_by_id(world, other_id)
      nb === nothing && continue
      nb.alive || continue
      collection_member(nb, turtleset) || continue
      nb.id in visited && continue
      w = get_link_weight(link, weight_var)
      nd = d + w
      if nd < get(dist, nb.id, Inf)
        dist[nb.id] = nd
        push!(pq, (nd, nb))
      end
    end
  end
  false
end

function nw_dijkstra_path(world::World, source::Turtle, target::Turtle, linkset, turtleset, weight_var::String)
  if source.id == target.id
    return Any[source]
  end
  dist = Dict{Int, Float64}(source.id => 0.0)
  prev = Dict{Int, Turtle}()
  visited = Set{Int}()
  pq = [(0.0, source)]
  while !isempty(pq)
    sort!(pq, by=first)
    d, current = popfirst!(pq)
    current.id in visited && continue
    push!(visited, current.id)
    current.id == target.id && break
    for link in live_agentset_members(linkset)
      link isa Link || continue
      link.alive || continue
      other_id = nothing
      if link.end1 == current.id
        other_id = link.end2
      elseif link.end2 == current.id
        other_id = link.end1
      end
      other_id === nothing && continue
      nb = maybe_turtle_by_id(world, other_id)
      nb === nothing && continue
      nb.alive || continue
      collection_member(nb, turtleset) || continue
      nb.id in visited && continue
      w = get_link_weight(link, weight_var)
      nd = d + w
      if nd < get(dist, nb.id, Inf)
        dist[nb.id] = nd
        prev[nb.id] = current
        push!(pq, (nd, nb))
      end
    end
  end
  !haskey(prev, target.id) && target.id != source.id && return false
  path = Turtle[target]
  current = target
  while current.id != source.id
    current = prev[current.id]
    pushfirst!(path, current)
  end
  Any[t for t in path]
end

function nw_mean_path_length(ctx::Context)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  turtles = [t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  n = length(turtles)
  n <= 1 && return 0.0
  total = 0.0
  count = 0
  for src in turtles
    dist = nw_bfs_distances(world, src, nc.linkset, nc.turtleset)
    for tgt in turtles
      src.id == tgt.id && continue
      d = get(dist, tgt.id, -1)
      d < 0 && return false  # disconnected
      total += d
      count += 1
    end
  end
  count == 0 ? 0.0 : total / count
end

function nw_mean_weighted_path_length(ctx::Context, weight_var::String)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  turtles = [t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  n = length(turtles)
  n <= 1 && return 0.0
  total = 0.0
  count = 0
  for src in turtles
    for tgt in turtles
      src.id == tgt.id && continue
      d = nw_dijkstra_distance(world, src, tgt, nc.linkset, nc.turtleset, weight_var)
      d === false && return false
      total += d
      count += 1
    end
  end
  count == 0 ? 0.0 : total / count
end

function nw_clustering_coefficient(ctx::Context)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  source = ctx.agent::Turtle
  nbrs = nw_neighbors(world, source, nc.linkset, nc.turtleset)
  k = length(nbrs)
  k < 2 && return 0.0
  triangles = 0
  for i in 1:k
    for j in (i+1):k
      if are_linked(nbrs[i], nbrs[j], nc.linkset)
        triangles += 1
      end
    end
  end
  2.0 * triangles / (k * (k - 1))
end

function are_linked(t1::Turtle, t2::Turtle, linkset)
  for link in live_agentset_members(linkset)
    link isa Link || continue
    link.alive || continue
    if (link.end1 == t1.id && link.end2 == t2.id) || (link.end1 == t2.id && link.end2 == t1.id)
      return true
    end
  end
  false
end

function nw_betweenness_centrality(ctx::Context)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  source = ctx.agent::Turtle
  turtles = [t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  n = length(turtles)
  n < 3 && return 0.0

  bc = 0.0
  for s in turtles
    s.id == source.id && continue
    for t in turtles
      t.id == s.id && continue
      t.id == source.id && continue
      paths = nw_all_shortest_paths(world, s, t, nc.linkset, nc.turtleset)
      isempty(paths) && continue
      through = count(p -> any(v -> v.id == source.id, p[2:end-1]), paths)
      bc += through / length(paths)
    end
  end
  bc
end

function nw_all_shortest_paths(world::World, source::Turtle, target::Turtle, linkset, turtleset)
  if source.id == target.id
    return [Turtle[source]]
  end
  dist = Dict{Int, Int}(source.id => 0)
  paths_to = Dict{Int, Vector{Vector{Turtle}}}(source.id => [Turtle[source]])
  queue = Turtle[source]
  while !isempty(queue)
    current = popfirst!(queue)
    d = dist[current.id]
    for nb in nw_neighbors(world, current, linkset, turtleset)
      nd = d + 1
      if !haskey(dist, nb.id)
        dist[nb.id] = nd
        paths_to[nb.id] = [vcat(p, [nb]) for p in paths_to[current.id]]
        push!(queue, nb)
      elseif dist[nb.id] == nd
        append!(paths_to[nb.id], [vcat(p, [nb]) for p in paths_to[current.id]])
      end
    end
  end
  get(paths_to, target.id, Vector{Turtle}[])
end

function nw_closeness_centrality(ctx::Context)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  source = ctx.agent::Turtle
  turtles = [t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  n = length(turtles)
  n <= 1 && return 0.0
  dist = nw_bfs_distances(world, source, nc.linkset, nc.turtleset)
  total = 0.0
  reachable = 0
  for t in turtles
    t.id == source.id && continue
    d = get(dist, t.id, -1)
    d < 0 && return 0.0
    total += d
    reachable += 1
  end
  reachable == 0 ? 0.0 : reachable / total
end

function nw_save_graphml(ctx::Context, filename::String)
  nc = get_nw_context(ctx)
  turtles = [t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  links = [l for l in live_agentset_members(nc.linkset) if l isa Link && l.alive]

  io = IOBuffer()
  println(io, """<?xml version="1.0" encoding="UTF-8"?>""")
  println(io, """<graphml xmlns="http://graphml.graphstruct.org/graphml">""")
  println(io, """  <graph id="G" edgedefault="undirected">""")
  for t in turtles
    println(io, """    <node id="n$(t.id)"/>""")
  end
  for (i, l) in enumerate(links)
    println(io, """    <edge id="e$i" source="n$(l.end1)" target="n$(l.end2)"/>""")
  end
  println(io, "  </graph>")
  println(io, "</graphml>")
  write(filename, String(take!(io)))
  nothing
end

function nw_save_matrix(ctx::Context, filename::String)
  nc = get_nw_context(ctx)
  turtles = sort!([t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive], by=t -> t.id)
  n = length(turtles)
  id_to_idx = Dict(t.id => i for (i, t) in enumerate(turtles))
  mat = zeros(Int, n, n)
  for l in live_agentset_members(nc.linkset)
    l isa Link || continue
    l.alive || continue
    i = get(id_to_idx, l.end1, 0)
    j = get(id_to_idx, l.end2, 0)
    if i > 0 && j > 0
      mat[i, j] = 1
      mat[j, i] = 1
    end
  end
  io = IOBuffer()
  for i in 1:n
    println(io, join(mat[i, :], " "))
  end
  write(filename, String(take!(io)))
  nothing
end

# ── Network generators ─────────────────────────────────────────────────

function extract_breed_names(turtleset, linkset)
  turtle_breed = "TURTLES"
  link_breed = "LINKS"
  if turtleset isa AgentSet && turtleset.breed !== nothing
    turtle_breed = turtleset.breed
  end
  if linkset isa AgentSet && linkset.breed !== nothing
    link_breed = linkset.breed
  end
  turtle_breed, link_breed
end

function nw_make_turtle!(world::World, turtle_breed::String)
  create_turtle!(world; breed=turtle_breed)
end

function nw_make_link!(world::World, t1::Turtle, t2::Turtle, link_breed::String)
  create_link!(world, t1, t2; breed=link_breed)
end

function nw_generate_preferential_attachment(ctx::Context, turtleset, linkset, num_nodes::Int, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  nodes = Turtle[]
  num_nodes >= 1 || return nothing

  first_node = nw_make_turtle!(world, turtle_breed)
  push!(nodes, first_node)

  for _ in 2:num_nodes
    new_node = nw_make_turtle!(world, turtle_breed)
    if !isempty(nodes)
      # preferential attachment: probability proportional to degree
      degrees = Float64[max(1.0, sum(l -> (l isa Link && l.alive && (l.end1 == n.id || l.end2 == n.id)) ? 1.0 : 0.0,
                                         live_agentset_members(linkset); init=0.0) + 1.0) for n in nodes]
      total = sum(degrees)
      r = rand(world.rng) * total
      cumulative = 0.0
      target = nodes[1]
      for (i, d) in enumerate(degrees)
        cumulative += d
        if r <= cumulative
          target = nodes[i]
          break
        end
      end
      nw_make_link!(world, new_node, target, link_breed)
    end
    push!(nodes, new_node)
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

function nw_generate_random(ctx::Context, turtleset, linkset, num_nodes::Int, connection_prob::Float64, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  nodes = Turtle[]

  for _ in 1:num_nodes
    push!(nodes, nw_make_turtle!(world, turtle_breed))
  end

  for i in 1:num_nodes
    for j in (i+1):num_nodes
      if rand(world.rng) < connection_prob
        nw_make_link!(world, nodes[i], nodes[j], link_breed)
      end
    end
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

function nw_generate_star(ctx::Context, turtleset, linkset, num_nodes::Int, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  num_nodes >= 1 || return nothing
  nodes = Turtle[]

  center = nw_make_turtle!(world, turtle_breed)
  push!(nodes, center)
  for _ in 2:num_nodes
    leaf = nw_make_turtle!(world, turtle_breed)
    nw_make_link!(world, center, leaf, link_breed)
    push!(nodes, leaf)
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

function nw_generate_wheel(ctx::Context, turtleset, linkset, num_nodes::Int, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  num_nodes >= 2 || return nothing
  nodes = Turtle[]

  center = nw_make_turtle!(world, turtle_breed)
  push!(nodes, center)
  for _ in 2:num_nodes
    node = nw_make_turtle!(world, turtle_breed)
    nw_make_link!(world, center, node, link_breed)
    push!(nodes, node)
  end
  # connect rim
  for i in 2:(length(nodes)-1)
    nw_make_link!(world, nodes[i], nodes[i+1], link_breed)
  end
  if length(nodes) > 2
    nw_make_link!(world, nodes[end], nodes[2], link_breed)
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

function nw_generate_ring(ctx::Context, turtleset, linkset, num_nodes::Int, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  num_nodes >= 1 || return nothing
  nodes = Turtle[]

  for _ in 1:num_nodes
    push!(nodes, nw_make_turtle!(world, turtle_breed))
  end
  for i in 1:(num_nodes-1)
    nw_make_link!(world, nodes[i], nodes[i+1], link_breed)
  end
  if num_nodes > 1
    nw_make_link!(world, nodes[end], nodes[1], link_breed)
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

function nw_generate_lattice_2d(ctx::Context, turtleset, linkset, rows::Int, cols::Int, toroidal, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  is_toroidal = toroidal isa Bool ? toroidal : false
  nodes = Matrix{Turtle}(undef, rows, cols)

  for r in 1:rows
    for c in 1:cols
      nodes[r, c] = nw_make_turtle!(world, turtle_breed)
    end
  end

  for r in 1:rows
    for c in 1:cols
      # right neighbor
      if c < cols
        nw_make_link!(world, nodes[r, c], nodes[r, c+1], link_breed)
      elseif is_toroidal && cols > 1
        nw_make_link!(world, nodes[r, c], nodes[r, 1], link_breed)
      end
      # down neighbor
      if r < rows
        nw_make_link!(world, nodes[r, c], nodes[r+1, c], link_breed)
      elseif is_toroidal && rows > 1
        nw_make_link!(world, nodes[r, c], nodes[1, c], link_breed)
      end
    end
  end

  all_nodes = AbstractAgent[nodes[r, c] for r in 1:rows for c in 1:cols]
  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, all_nodes, cmd_block)
  end
  nothing
end

function nw_generate_small_world(ctx::Context, turtleset, linkset, rows::Int, cols::Int, clustering_exp::Float64, toroidal, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  is_toroidal = toroidal isa Bool ? toroidal : false

  # Watts-Strogatz: start with a ring lattice, then rewire
  n = rows * cols
  n >= 1 || return nothing
  nodes = Turtle[]
  for _ in 1:n
    push!(nodes, nw_make_turtle!(world, turtle_breed))
  end

  # Build ring lattice with k=2 (each node connected to 2 nearest neighbors)
  for i in 1:n
    j = i < n ? i + 1 : (is_toroidal ? 1 : 0)
    j > 0 && nw_make_link!(world, nodes[i], nodes[j], link_breed)
  end

  # Rewire with probability clustering_exp
  links_list = [l for l in live_agentset_members(linkset) if l isa Link && l.alive]
  for link in links_list
    if rand(world.rng) < clustering_exp
      src_id = link.end1
      src_idx = findfirst(t -> t.id == src_id, nodes)
      src_idx === nothing && continue
      # pick random target that isn't already connected
      candidates = [t for t in nodes if t.id != src_id && !are_linked(nodes[src_idx], t, linkset)]
      isempty(candidates) && continue
      target = candidates[rand(world.rng, 1:length(candidates))]
      # Remove old link and create new one
      link.alive = false
      nw_make_link!(world, nodes[src_idx], target, link_breed)
    end
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

end # module nw
