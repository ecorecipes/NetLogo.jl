module nw

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  TurtlesetType, LinksetType, AgentType, CommandBlockType, OptionalType,
  LogoRuntimeError, World, Turtle, Link, Context,
  live_agentset_members, collection_member, maybe_turtle_by_id,
  logo_equal, AbstractAgent, AgentSet, TurtleKind, LinkKind, BlockNode,
  create_turtle!, create_link!, kill_link!, run_block_for_agents!,
  all_turtles, all_links

import Graphs

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
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType | OptionalType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :eval, :block]),
    (ctx, args) -> begin
      # Support both 3-arg (no min-degree) and 4-arg (with min-degree) forms
      if length(args) >= 4 && args[4] isa Number
        nw_generate_preferential_attachment(ctx, args[1], args[2], Int(args[3]), Int(args[4]), get(args, 5, nothing))
      else
        nw_generate_preferential_attachment(ctx, args[1], args[2], Int(args[3]), 1, get(args, 4, nothing))
      end
    end)

  register_primitive!(registry, "NW:GENERATE-RANDOM", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_random(ctx, args[1], args[2], Int(args[3]), Float64(args[4]), get(args, 5, nothing)))

  register_primitive!(registry, "NW:GENERATE-SMALL-WORLD", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, NumberType, BooleanType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_small_world(ctx, args[1], args[2], Int(args[3]), Int(args[4]), Float64(args[5]), args[6], get(args, 7, nothing)))

  register_primitive!(registry, "NW:GENERATE-STAR", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_star(ctx, args[1], args[2], Int(args[3]), get(args, 4, nothing)))

  register_primitive!(registry, "NW:GENERATE-WHEEL", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_wheel(ctx, args[1], args[2], Int(args[3]), get(args, 4, nothing)))

  register_primitive!(registry, "NW:GENERATE-LATTICE-2D", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, BooleanType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_lattice_2d(ctx, args[1], args[2], Int(args[3]), Int(args[4]), args[5], get(args, 6, nothing)))

  register_primitive!(registry, "NW:GENERATE-RING", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_ring(ctx, args[1], args[2], Int(args[3]), get(args, 4, nothing)))

  register_primitive!(registry, "NW:WEAK-COMPONENT-CLUSTERS", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> nw_weak_component_clusters(ctx))

  register_primitive!(registry, "NW:PAGE-RANK", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> nw_page_rank(ctx))

  register_primitive!(registry, "NW:EIGENVECTOR-CENTRALITY", REPORTER,
    reporter_syntax(ret=NumberType),
    (ctx, args) -> nw_eigenvector_centrality(ctx))

  register_primitive!(registry, "NW:LOUVAIN-COMMUNITIES", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> nw_louvain_communities(ctx))

  register_primitive!(registry, "NW:MAXIMAL-CLIQUES", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> nw_maximal_cliques(ctx))

  register_primitive!(registry, "NW:BIGGEST-MAXIMAL-CLIQUES", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> nw_biggest_maximal_cliques(ctx))

  register_primitive!(registry, "NW:MODULARITY", REPORTER,
    reporter_syntax(right=[ListType], ret=NumberType),
    (ctx, args) -> nw_modularity(ctx, args[1]))

  register_primitive!(registry, "NW:BICOMPONENT-CLUSTERS", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> nw_bicomponent_clusters(ctx))

  register_primitive!(registry, "NW:SET-SNAPSHOT", COMMAND,
    command_syntax(),
    (ctx, args) -> nw_set_snapshot(ctx))

  register_primitive!(registry, "NW:LOAD-MATRIX", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> nw_load_matrix(ctx, String(args[1])))

  register_primitive!(registry, "NW:GENERATE-WATTS-STROGATZ", COMMAND,
    command_syntax(right=[TurtlesetType, LinksetType, NumberType, NumberType, NumberType, BooleanType, CommandBlockType | OptionalType], arg_modes=[:eval, :eval, :eval, :eval, :eval, :eval, :block]),
    (ctx, args) -> nw_generate_watts_strogatz(ctx, args[1], args[2], Int(args[3]), Int(args[4]), Float64(args[5]), args[6], get(args, 7, nothing)))

  register_primitive!(registry, "NW:WEIGHTED-CLOSENESS-CENTRALITY", REPORTER,
    reporter_syntax(right=[StringType], ret=NumberType),
    (ctx, args) -> nw_weighted_closeness_centrality(ctx, String(args[1])))

  register_primitive!(registry, "NW:TURTLES-ON-PATH-TO", REPORTER,
    reporter_syntax(right=[AgentType], ret=TurtlesetType),
    (ctx, args) -> nw_turtles_on_path_to(ctx, args[1]))

  register_primitive!(registry, "NW:TURTLES-ON-WEIGHTED-PATH-TO", REPORTER,
    reporter_syntax(right=[AgentType, StringType], ret=TurtlesetType),
    (ctx, args) -> nw_turtles_on_weighted_path_to(ctx, args[1], String(args[2])))
end

# ── NW context state (stored on runtime via agent properties) ──────────

mutable struct NwContext
  turtleset::Any
  linkset::Any
end

const NW_CONTEXT_KEY = :__nw_context__

# NwGraph: adjacency-list representation of the NW context graph
struct NwGraph
  turtles::Vector{Turtle}
  id_to_idx::Dict{Int, Int}
  adj::Vector{Vector{Int}}
  n::Int
end

# Cache for bulk-computed Graphs.jl metrics (betweenness, pagerank, etc.)
# Invalidated per tick + context identity so recomputation happens only when needed.
mutable struct NwMetricCache
  tick::Int
  context_id::UInt64  # hash of turtleset/linkset identity
  betweenness::Union{Nothing, Vector{Float64}}
  pagerank::Union{Nothing, Vector{Float64}}
  eigenvector::Union{Nothing, Vector{Float64}}
  closeness::Union{Nothing, Vector{Float64}}
  graph::Union{Nothing, NwGraph}
end
NwMetricCache() = NwMetricCache(-1, UInt64(0), nothing, nothing, nothing, nothing, nothing)

function get_nw_cache(ctx::Context)::NwMetricCache
  key = "__NW_METRIC_CACHE__"
  if haskey(ctx.runtime.world.observer.globals, key)
    return ctx.runtime.world.observer.globals[key]::NwMetricCache
  end
  cache = NwMetricCache()
  ctx.runtime.world.observer.globals[key] = cache
  cache
end

function nw_context_id(nc::NwContext)::UInt64
  hash((objectid(nc.turtleset), objectid(nc.linkset)))
end

function get_cached_graph(ctx::Context)::NwGraph
  cache = get_nw_cache(ctx)
  nc = get_nw_context(ctx)
  cid = nw_context_id(nc)
  tick = ctx.runtime.world.ticks
  n_links = length(ctx.runtime.world.links)
  n_turtles = length(ctx.runtime.world.turtles)
  if cache.graph !== nothing && cache.tick == tick && cache.context_id == cid &&
     cache.graph.n == n_turtles && n_links == get(ctx.runtime.world.observer.globals, "__NW_LINK_COUNT__", -1)
    return cache.graph
  end
  g = build_nw_graph(ctx)
  cache.tick = tick
  cache.context_id = cid
  cache.betweenness = nothing
  cache.pagerank = nothing
  cache.eigenvector = nothing
  cache.closeness = nothing
  cache.graph = g
  ctx.runtime.world.observer.globals["__NW_LINK_COUNT__"] = n_links
  g
end

function get_nw_context(ctx::Context)
  if haskey(ctx.runtime.world.observer.globals, "__NW_CONTEXT__")
    return ctx.runtime.world.observer.globals["__NW_CONTEXT__"]::NwContext
  end
  world = ctx.runtime.world
  return NwContext(all_turtles(world), all_links(world))
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
  dist = nw_dijkstra_distance(world, source, target, nc.linkset, nc.turtleset, weight_var)
  isfinite(dist) ? dist : false
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
  Inf
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
  g = get_cached_graph(ctx)
  n = g.n
  n <= 1 && return 0.0

  ug = build_graphs_jl_graph(g)
  total = 0.0
  count = 0
  for i in 1:n
    ds = Graphs.dijkstra_shortest_paths(ug, i)
    for j in 1:n
      i == j && continue
      d = ds.dists[j]
      (d == typemax(Float64) || d < 0) && return false  # disconnected
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
      isfinite(d) || return false
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
  source = ctx.agent::Turtle
  g = get_cached_graph(ctx)
  n = g.n
  n < 3 && return 0.0
  idx = get(g.id_to_idx, source.id, 0)
  idx == 0 && return 0.0

  cache = get_nw_cache(ctx)
  if cache.betweenness === nothing
    # Compute for ALL nodes at once using Brandes' O(nm) algorithm
    ug = build_graphs_jl_graph(g)
    # Graphs.jl betweenness_centrality returns normalized values by default;
    # NetLogo returns raw (unnormalized) betweenness counts.
    cache.betweenness = Graphs.betweenness_centrality(ug, normalize=false)
  end
  cache.betweenness[idx]
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
  source = ctx.agent::Turtle
  g = get_cached_graph(ctx)
  n = g.n
  n <= 1 && return 0.0
  idx = get(g.id_to_idx, source.id, 0)
  idx == 0 && return 0.0

  cache = get_nw_cache(ctx)
  if cache.closeness === nothing
    ug = build_graphs_jl_graph(g)
    # Graphs.jl closeness_centrality returns n_reachable / sum_distances
    # but returns 0.0 for disconnected nodes. NetLogo returns 0.0 if ANY
    # node is unreachable, otherwise (n-1)/total_distance.
    # We compute our own to match NetLogo semantics exactly.
    cc = zeros(Float64, n)
    for i in 1:n
      ds = Graphs.dijkstra_shortest_paths(ug, i)
      total = 0.0
      reachable = 0
      all_reachable = true
      for j in 1:n
        j == i && continue
        d = ds.dists[j]
        if d == typemax(Float64) || d < 0
          all_reachable = false
          break
        end
        total += d
        reachable += 1
      end
      cc[i] = (!all_reachable || reachable == 0) ? 0.0 : reachable / total
    end
    cache.closeness = cc
  end
  cache.closeness[idx]
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

function nw_generate_preferential_attachment(ctx::Context, turtleset, linkset, num_nodes::Int, min_degree::Int, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)
  nodes = Turtle[]
  num_nodes >= 1 || return nothing
  min_degree = max(1, min_degree)

  first_node = nw_make_turtle!(world, turtle_breed)
  push!(nodes, first_node)

  for _ in 2:num_nodes
    new_node = nw_make_turtle!(world, turtle_breed)
    if !isempty(nodes)
      targets_needed = min(min_degree, length(nodes))
      chosen = Set{Int}()
      for _ in 1:targets_needed
        degrees = Float64[max(1.0, sum(l -> (l isa Link && l.alive && (l.end1 == n.id || l.end2 == n.id)) ? 1.0 : 0.0,
                                            live_agentset_members(linkset); init=0.0) + 1.0) for n in nodes]
        for ci in chosen
          degrees[ci] = 0.0
        end
        total = sum(degrees)
        total <= 0.0 && break
        r = rand(world.rng) * total
        cumulative = 0.0
        target_idx = 1
        for (i, d) in enumerate(degrees)
          cumulative += d
          if r <= cumulative
            target_idx = i
            break
          end
        end
        push!(chosen, target_idx)
        nw_make_link!(world, new_node, nodes[target_idx], link_breed)
      end
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
      kill_link!(world, link)
      nw_make_link!(world, nodes[src_idx], target, link_breed)
    end
  end

  if cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[nodes...], cmd_block)
  end
  nothing
end

function nw_weak_component_clusters(ctx::Context)
  g = get_cached_graph(ctx)
  isempty(g.turtles) && return Any[]

  ug = build_graphs_jl_graph(g)
  cc = Graphs.connected_components(ug)

  components = Any[]
  for component_indices in cc
    members = AbstractAgent[g.turtles[i] for i in component_indices]
    push!(components, AgentSet(TurtleKind, members))
  end
  components
end

# ── Helper: build adjacency structure for the current NW context ─────

function build_nw_graph(ctx::Context)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  turtles = Turtle[t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  n = length(turtles)
  id_to_idx = Dict{Int, Int}()
  for (i, t) in enumerate(turtles)
    id_to_idx[t.id] = i
  end
  adj = [Int[] for _ in 1:n]
  for link in live_agentset_members(nc.linkset)
    link isa Link && link.alive || continue
    i = get(id_to_idx, link.end1, 0)
    j = get(id_to_idx, link.end2, 0)
    if i > 0 && j > 0
      push!(adj[i], j)
      push!(adj[j], i)
    end
  end
  NwGraph(turtles, id_to_idx, adj, n)
end

# ── Graphs.jl bridge ─────────────────────────────────────────────────

"""Build a Graphs.SimpleDiGraph from NwGraph adjacency lists.
Each undirected edge in the NwGraph becomes two directed arcs in the SimpleDiGraph,
which is exactly what Graphs.jl expects for undirected-style algorithms on DiGraphs."""
function build_graphs_jl_digraph(g::NwGraph)
  dg = Graphs.SimpleDiGraph(g.n)
  for i in 1:g.n
    for j in g.adj[i]
      Graphs.add_edge!(dg, i, j)
    end
  end
  dg
end

"""Build a Graphs.SimpleGraph (undirected) from NwGraph adjacency lists."""
function build_graphs_jl_graph(g::NwGraph)
  ug = Graphs.SimpleGraph(g.n)
  for i in 1:g.n
    for j in g.adj[i]
      Graphs.add_edge!(ug, i, j)
    end
  end
  ug
end

# Count total edges in the NW context
function count_edges(ctx::Context)
  nc = get_nw_context(ctx)
  m = 0
  for link in live_agentset_members(nc.linkset)
    link isa Link && link.alive || continue
    m += 1
  end
  m
end

# ── PageRank ─────────────────────────────────────────────────────────

function nw_page_rank(ctx::Context)
  source = ctx.agent::Turtle
  g = get_cached_graph(ctx)
  n = g.n
  n == 0 && return 0.0
  idx = get(g.id_to_idx, source.id, 0)
  idx == 0 && return 0.0

  cache = get_nw_cache(ctx)
  if cache.pagerank === nothing
    dg = build_graphs_jl_digraph(g)
    cache.pagerank = Graphs.pagerank(dg, 0.85, 100, 1.0e-6)
  end
  cache.pagerank[idx]
end

# ── Eigenvector centrality ───────────────────────────────────────────

function nw_eigenvector_centrality(ctx::Context)
  source = ctx.agent::Turtle
  g = get_cached_graph(ctx)
  n = g.n
  n == 0 && return 0.0
  idx = get(g.id_to_idx, source.id, 0)
  idx == 0 && return 0.0

  cache = get_nw_cache(ctx)
  if cache.eigenvector === nothing
    ug = build_graphs_jl_graph(g)
    cache.eigenvector = Graphs.eigenvector_centrality(ug)
  end
  cache.eigenvector[idx]
end

# ── Louvain community detection ─────────────────────────────────────

function nw_louvain_communities(ctx::Context)
  g = get_cached_graph(ctx)
  n = g.n
  n == 0 && return Any[]

  m2 = 0  # 2 * number of edges
  for i in 1:n
    m2 += length(g.adj[i])
  end
  m2 == 0 && return Any[AgentSet(TurtleKind, AbstractAgent[g.turtles...])]

  community = collect(1:n)
  k = [Float64(length(g.adj[i])) for i in 1:n]  # degree of each node

  # Maintain running sum of degrees per community for O(1) lookup
  sigma = Dict{Int, Float64}()
  for i in 1:n
    sigma[i] = k[i]
  end

  improved = true
  while improved
    improved = false
    for i in 1:n
      ci = community[i]
      ki = k[i]

      # Compute community→edge weights for neighbors of i
      comm_weights = Dict{Int, Float64}()
      for j in g.adj[i]
        cj = community[j]
        comm_weights[cj] = get(comm_weights, cj, 0.0) + 1.0
      end

      ki_in_ci = get(comm_weights, ci, 0.0)
      sum_ci = get(sigma, ci, 0.0)

      best_gain = 0.0
      best_comm = ci

      for (cj, ki_in_cj) in comm_weights
        cj == ci && continue
        sum_cj = get(sigma, cj, 0.0)
        gain = (ki_in_cj - ki_in_ci) / m2 - ki * (sum_cj - sum_ci + ki) / (m2 * m2) * 2.0
        if gain > best_gain
          best_gain = gain
          best_comm = cj
        end
      end

      if best_comm != ci
        # Update running sums
        sigma[ci] = get(sigma, ci, 0.0) - ki
        sigma[best_comm] = get(sigma, best_comm, 0.0) + ki
        community[i] = best_comm
        improved = true
      end
    end
  end

  # Group turtles by community
  groups = Dict{Int, Vector{AbstractAgent}}()
  for i in 1:n
    c = community[i]
    if !haskey(groups, c)
      groups[c] = AbstractAgent[]
    end
    push!(groups[c], g.turtles[i])
  end
  Any[AgentSet(TurtleKind, members) for members in values(groups)]
end

# ── Maximal cliques (Bron-Kerbosch) ─────────────────────────────────

function nw_maximal_cliques(ctx::Context)
  g = get_cached_graph(ctx)
  n = g.n
  n == 0 && return Any[]

  # Build adjacency as BitSets for fast intersection
  adj_bits = [Set{Int}(g.adj[i]) for i in 1:n]

  cliques = Vector{Vector{Int}}()

  function bron_kerbosch(R::Set{Int}, P::Set{Int}, X::Set{Int})
    if isempty(P) && isempty(X)
      push!(cliques, sort(collect(R)))
      return
    end
    # Pivot: choose u from P ∪ X that maximizes |P ∩ N(u)|
    u = -1
    best_count = -1
    for v in Iterators.flatten((P, X))
      c = length(intersect(P, adj_bits[v]))
      if c > best_count
        best_count = c
        u = v
      end
    end
    candidates = setdiff(P, adj_bits[u])
    for v in candidates
      new_R = union(R, Set{Int}([v]))
      new_P = intersect(P, adj_bits[v])
      new_X = intersect(X, adj_bits[v])
      bron_kerbosch(new_R, new_P, new_X)
      delete!(P, v)
      push!(X, v)
    end
  end

  bron_kerbosch(Set{Int}(), Set{Int}(1:n), Set{Int}())

  Any[AgentSet(TurtleKind, AbstractAgent[g.turtles[i] for i in c]) for c in cliques]
end

function nw_biggest_maximal_cliques(ctx::Context)
  all_cliques = nw_maximal_cliques(ctx)
  isempty(all_cliques) && return Any[]
  max_size = maximum(length(live_agentset_members(c)) for c in all_cliques)
  Any[c for c in all_cliques if length(live_agentset_members(c)) == max_size]
end

# ── Modularity ───────────────────────────────────────────────────────

function nw_modularity(ctx::Context, communities)
  communities isa AbstractVector || throw(LogoRuntimeError("nw:modularity expected a list of turtle agentsets"))
  g = get_cached_graph(ctx)
  n = g.n
  n == 0 && return 0.0

  two_m = 0
  for i in 1:n
    two_m += length(g.adj[i])
  end
  two_m == 0 && return 0.0

  modularity = 0.0
  for community in communities
    community isa AgentSet || throw(LogoRuntimeError("nw:modularity expected a list of turtle agentsets"))
    members = Int[]
    member_set = Set{Int}()
    for agent in live_agentset_members(community)
      agent isa Turtle || throw(LogoRuntimeError("nw:modularity expected turtle agentsets"))
      idx = get(g.id_to_idx, agent.id, 0)
      idx == 0 && continue
      idx in member_set && continue
      push!(members, idx)
      push!(member_set, idx)
    end
    isempty(members) && continue

    internal_degree = 0
    total_degree = 0
    for idx in members
      neighbors = g.adj[idx]
      total_degree += length(neighbors)
      for neighbor in neighbors
        neighbor in member_set && (internal_degree += 1)
      end
    end
    modularity += internal_degree / two_m - (total_degree / two_m)^2
  end
  modularity
end

# ── Biconnected components ───────────────────────────────────────────

function nw_bicomponent_clusters(ctx::Context)
  g = build_nw_graph(ctx)
  n = g.n
  n == 0 && return Any[]

  disc = zeros(Int, n)
  low = zeros(Int, n)
  parent = zeros(Int, n)
  timer = Ref(1)

  # Collect edges in biconnected components
  edge_stack = Tuple{Int,Int}[]
  components = Vector{Set{Int}}()

  function dfs(u::Int)
    disc[u] = timer[]
    low[u] = timer[]
    timer[] += 1
    children = 0
    for v in g.adj[u]
      if disc[v] == 0
        children += 1
        parent[v] = u
        push!(edge_stack, (u, v))
        dfs(v)
        low[u] = min(low[u], low[v])
        # Articulation point check
        if (parent[u] == 0 && children > 1) || (parent[u] != 0 && low[v] >= disc[u])
          comp = Set{Int}()
          while true
            e = pop!(edge_stack)
            push!(comp, e[1])
            push!(comp, e[2])
            e == (u, v) && break
          end
          push!(components, comp)
        end
      elseif v != parent[u] && disc[v] < disc[u]
        push!(edge_stack, (u, v))
        low[u] = min(low[u], disc[v])
      end
    end
  end

  for i in 1:n
    if disc[i] == 0
      dfs(i)
      # Remaining edges on stack form a component
      if !isempty(edge_stack)
        comp = Set{Int}()
        while !isempty(edge_stack)
          e = pop!(edge_stack)
          push!(comp, e[1])
          push!(comp, e[2])
        end
        push!(components, comp)
      end
    end
  end

  Any[AgentSet(TurtleKind, AbstractAgent[g.turtles[i] for i in c]) for c in components]
end

# ── Snapshot ─────────────────────────────────────────────────────────

function nw_set_snapshot(ctx::Context)
  nc = get_nw_context(ctx)
  # Snapshot = freeze the current agentset members as a static agentset
  turtles = Turtle[t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  links = Link[l for l in live_agentset_members(nc.linkset) if l isa Link && l.alive]
  ctx.runtime.world.observer.globals["__NW_CONTEXT__"] = NwContext(
    AgentSet(TurtleKind, AbstractAgent[turtles...]),
    AgentSet(LinkKind, AbstractAgent[links...])
  )
  nothing
end

# ── Load matrix ──────────────────────────────────────────────────────

function nw_load_matrix(ctx::Context, filename::String)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)

  lines = readlines(filename)
  rows = [parse.(Float64, split(strip(line))) for line in lines if !isempty(strip(line))]
  n = length(rows)

  # Create turtles
  turtles = Turtle[]
  for _ in 1:n
    t = nw_make_turtle!(world, "TURTLES")
    push!(turtles, t)
  end

  # Create links from adjacency matrix
  for i in 1:n, j in 1:n
    if rows[i][j] != 0.0
      nw_make_link!(world, turtles[i], turtles[j], "LINKS")
    end
  end
  nothing
end

# ── Watts-Strogatz generator ─────────────────────────────────────────

function nw_generate_watts_strogatz(ctx::Context, turtleset, linkset, num_nodes::Int, neighborhood_size::Int, rewire_prob::Float64, toroidal, cmd_block)
  world = ctx.runtime.world
  turtle_breed, link_breed = extract_breed_names(turtleset, linkset)

  # Create turtles
  turtles = Turtle[]
  for _ in 1:num_nodes
    t = nw_make_turtle!(world, turtle_breed)
    push!(turtles, t)
  end

  # Create ring lattice: each node connected to neighborhood_size nearest neighbors on each side
  for i in 1:num_nodes
    for offset in 1:neighborhood_size
      j = mod1(i + offset, num_nodes)
      if i != j
        nw_make_link!(world, turtles[i], turtles[j], link_breed)
      end
    end
  end

  # Rewire edges with given probability
  rng = world.rng
  for i in 1:num_nodes
    for offset in 1:neighborhood_size
      j = mod1(i + offset, num_nodes)
      if rand(rng) < rewire_prob
        # Pick a random target that isn't i and isn't already a neighbor
        for _ in 1:100  # max attempts
          k = rand(rng, 1:num_nodes)
          k == i && continue
          # Check if already linked
          already = false
          for link in world.links
            !link.alive && continue
            if (link.end1 == turtles[i].id && link.end2 == turtles[k].id) ||
               (link.end1 == turtles[k].id && link.end2 == turtles[i].id)
              already = true
              break
            end
          end
          if !already
            # Remove old link (i→j)
            for link in world.links
              !link.alive && continue
              if (link.end1 == turtles[i].id && link.end2 == turtles[j].id) ||
                 (link.end1 == turtles[j].id && link.end2 == turtles[i].id)
                kill_link!(world, link)
                break
              end
            end
            nw_make_link!(world, turtles[i], turtles[k], link_breed)
            break
          end
        end
      end
    end
  end

  # Run optional command block on new turtles
  if cmd_block !== nothing && cmd_block isa BlockNode
    run_block_for_agents!(ctx, AbstractAgent[turtles...], cmd_block)
  end
  nothing
end

# ── Weighted closeness centrality ────────────────────────────────────

function nw_weighted_closeness_centrality(ctx::Context, weight_var::String)
  world = ctx.runtime.world
  nc = get_nw_context(ctx)
  source = ctx.agent::Turtle
  turtles = [t for t in live_agentset_members(nc.turtleset) if t isa Turtle && t.alive]
  n = length(turtles)
  n <= 1 && return 0.0

  total = 0.0
  for t in turtles
    t.id == source.id && continue
    d = nw_dijkstra_distance(world, source, t, nc.linkset, nc.turtleset, weight_var)
    isfinite(d) || return 0.0
    total += d
  end
  total == 0.0 ? 0.0 : (n - 1) / total
end

# ── Turtles on path to (list of turtles along shortest path) ────────

function nw_turtles_on_path_to(ctx::Context, target)
  path = nw_path_to(ctx, target)
  path isa Vector || return AgentSet(TurtleKind, AbstractAgent[])
  AgentSet(TurtleKind, AbstractAgent[path...])
end

function nw_turtles_on_weighted_path_to(ctx::Context, target, weight_var::String)
  path = nw_weighted_path_to(ctx, target, weight_var)
  path isa Vector || return AgentSet(TurtleKind, AbstractAgent[])
  AgentSet(TurtleKind, AbstractAgent[path...])
end

end # module nw
