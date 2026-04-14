# ── Solid Diffusion ─────────────────────────────────────────────────
# Source: modelingcommons #1278
# Green and blue atoms swap with vacancies on a lattice.

struct SolidDiffusionModel <: AbstractBenchmarkModel end

model_name(::SolidDiffusionModel) = "Solid Diffusion"
n_ticks(::SolidDiffusionModel) = 200
tracked_globals(::SolidDiffusionModel) = ["n-turtles"]
world_dims(::SolidDiffusionModel) = (-17, 17, -17, 17)
topology(::SolidDiffusionModel) = (false, false)

function netlogo_code(::SolidDiffusionModel)
"""
globals [randomSeed n-turtles]

to setup
  clear-all
  set-default-shape turtles "square"
  ask patches with [pxcor < 0]
    [ sprout 1 [ set color green ] ]
  ask patches with [pxcor > 0]
    [ sprout 1 [ set color blue ] ]
  set n-turtles count turtles
  reset-ticks
end

to go
  ask patches with [not any? turtles-here]
    [ move-atom-to-here ]
  set n-turtles count turtles
  tick
end

to move-atom-to-here
  let atom one-of turtles-on neighbors4
  if atom != nobody [
    ask atom [ move-to myself ]
  ]
end
"""
end
