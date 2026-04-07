# ── Voronoi Voter model (model-zoo) ──────────────────────────────────

struct VoronoiVoterModel <: AbstractBenchmarkModel end

model_name(::VoronoiVoterModel) = "Voronoi Voter"
n_ticks(::VoronoiVoterModel) = 100
tracked_globals(::VoronoiVoterModel) = ["n-colors"]
world_dims(::VoronoiVoterModel) = (-100, 100, -100, 100)

function netlogo_code(::VoronoiVoterModel)
"""
extensions [profiler]

globals [ palette n-colors ]

breed [points point]
undirected-link-breed [tri-edges tri-edge]

patches-own [parent]
points-own [voronoi-polygon]

to setup
  clear-all
  ask patches [ set parent nobody ]
  set palette [red orange yellow green blue sky violet brown]
  set-default-shape points "circle"
  make-points
  ask patches [
    set parent nobody
  ]
  ask patches [
    assign-to-points
  ]
  ask points [
    triangulate
  ]
  reset-ticks
end

to make-points
  create-points 500 [
    set size 3
    set color one-of palette
    setxy random-xcor random-ycor
    set voronoi-polygon patch-set nobody
  ]
end

to assign-to-points
  ;; simplified: always find nearest point (avoids let in patch/turtle context issue)
  set parent min-one-of points [distance myself]
  set pcolor [color] of parent
  ask parent [
    set voronoi-polygon (patch-set voronoi-polygon myself)
  ]
end

to triangulate
  ask other (turtle-set [parent] of (patch-set [neighbors4] of voronoi-polygon)) [
    create-tri-edge-with myself []
  ]
end

to go
  if length remove-duplicates [color] of points = 1 [stop]
  repeat count points [
    ask one-of points [
      set color [color] of one-of link-neighbors
      ask voronoi-polygon [set pcolor [color] of myself]
    ]
  ]
  set n-colors length remove-duplicates [color] of points
  tick
end
"""
end
