# ── Forest Fire model (NetLogo models library) ────────────────────────

struct FireModel <: AbstractBenchmarkModel end

model_name(::FireModel) = "Forest Fire"
n_ticks(::FireModel) = 200
tracked_globals(::FireModel) = ["initial-trees", "burned-trees"]
world_dims(::FireModel) = (-125, 125, -125, 125)

function netlogo_code(::FireModel)
"""
globals [randomSeed density initial-trees burned-trees]

breed [fires fire]
breed [embers ember]

to setup
  clear-all
  resize-world (- 125) 125 (- 125) 125
  set density 57
  set-default-shape turtles "square"
  ask patches with [(random-float 100) < density]
    [ set pcolor green ]
  ask patches with [pxcor = min-pxcor]
    [ ignite ]
  set initial-trees count patches with [pcolor = green]
  set burned-trees 0
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask fires
    [ ask neighbors4 with [pcolor = green]
        [ ignite ]
      set breed embers ]
  fade-embers
  tick
end

to ignite
  sprout-fires 1 [ set color red ]
  set pcolor black
  set burned-trees burned-trees + 1
end

to fade-embers
  ask embers
    [ set color color - 0.3
      if color < red - 3.5
        [ set pcolor color
          die ] ]
end
"""
end
