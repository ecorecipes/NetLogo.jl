# ── DLA Simple (Diffusion-Limited Aggregation) ──────────────────────
# Source: modelingcommons #1352
# Turtles random-walk; when adjacent to green, they stick and die.

struct DLASimpleModel <: AbstractBenchmarkModel end

model_name(::DLASimpleModel) = "DLA Simple"
n_ticks(::DLASimpleModel) = 200
tracked_globals(::DLASimpleModel) = ["n-remaining"]
world_dims(::DLASimpleModel) = (-100, 100, -100, 100)

function netlogo_code(::DLASimpleModel)
"""
globals [randomSeed wiggle-angle num-particles n-remaining]

to setup
  clear-all
  set wiggle-angle 60
  set num-particles 2500
  ask patch 0 0
    [ set pcolor green ]
  create-turtles num-particles
    [ set color red
      set size 1.5
      setxy random-xcor random-ycor ]
  set n-remaining count turtles
  reset-ticks
end

to go
  ask turtles
    [ right random wiggle-angle
      left random wiggle-angle
      forward 1
      if any? neighbors with [pcolor = green]
        [ set pcolor green
          die ] ]
  set n-remaining count turtles
  tick
end
"""
end
