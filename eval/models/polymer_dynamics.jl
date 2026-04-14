# ── Polymer Dynamics (Alternating Chain Walk) ───────────────────────
# Source: modelingcommons #1276 (Wilensky 2005)
# Alternating blue/orange monomers on a chain; move without breaking.

struct PolymerDynamicsModel <: AbstractBenchmarkModel end

model_name(::PolymerDynamicsModel) = "Polymer Dynamics"
n_ticks(::PolymerDynamicsModel) = 200
tracked_globals(::PolymerDynamicsModel) = ["n-turtles"]
world_dims(::PolymerDynamicsModel) = (0, 159, 0, 79)

function netlogo_code(::PolymerDynamicsModel)
"""
globals [
  randomSeed
  n-turtles
  blues
  oranges
]

to setup
  clear-all
  set-default-shape turtles "circle"
  ask patches with [pycor = round (max-pycor / 2) and
                    pxcor < max-pxcor and
                    pxcor > min-pxcor]
    [
      sprout 1 [
        set color item (pxcor mod 2) [blue orange]
      ]
    ]
  set blues turtles with [color = blue]
  set oranges turtles with [color = orange]
  reset-ticks
end

to go
  ask blues   [ move ]
  ask oranges [ move ]
  set n-turtles count turtles
  tick
end

to move
  face one-of neighbors4
  if not breaking-chain? and not crossing-chain?
    [ fd 1 ]
end

to-report breaking-chain?
  report (heading = 0 and any? turtles at-points [[-1 -1] [0 -1] [1 -1]]) or (heading = 90 and any? turtles at-points [[-1 -1] [-1 0] [-1 1]]) or (heading = 180 and any? turtles at-points [[-1 1] [0 1] [1 1]]) or (heading = 270 and any? turtles at-points [[1 -1] [1 0] [1 1]])
end

to-report crossing-chain?
  report (heading = 0 and any? turtles at-points [[-1 2] [0 2] [1 2]]) or (heading = 90 and any? turtles at-points [[2 -1] [2 0] [2 1]]) or (heading = 180 and any? turtles at-points [[-1 -2] [0 -2] [1 -2]]) or (heading = 270 and any? turtles at-points [[-2 -1] [-2 0] [-2 1]])
end
"""
end
