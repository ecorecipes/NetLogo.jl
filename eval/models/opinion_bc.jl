# ── Opinion Dynamics Bounded Confidence model (modsoc) ─────────────────

struct OpinionBCModel <: AbstractBenchmarkModel end

model_name(::OpinionBCModel) = "Opinion Dynamics BC"
n_ticks(::OpinionBCModel) = 5000
tracked_globals(::OpinionBCModel) = ["mean-opinion", "sd-opinion"]
world_dims(::OpinionBCModel) = (-16, 16, -16, 16)

function netlogo_code(::OpinionBCModel)
"""
globals [randomSeed learning-rate confidence-threshold spatial-interactions? mean-opinion sd-opinion]
turtles-own [opinion]

to setup
  clear-all
  set learning-rate 0.3
  set confidence-threshold 0.3
  set spatial-interactions? false
  ask patches [
    sprout 1 [
      set opinion (random-float 2) - 1
      set shape "circle"
    ]
  ]
  update-colors
  update-stats
  reset-ticks
end

to go
  ask one-of turtles [
    let x1 opinion
    let other-turtle one-of other turtles
    if spatial-interactions? [set other-turtle one-of other turtles-on neighbors4]
    let x2 [opinion] of other-turtle
    if (abs (x1 - x2) < confidence-threshold) [
      let x1-new (x1 + learning-rate * (x2 - x1))
      let x2-new (x2 + learning-rate * (x1 - x2))
      set opinion x1-new
      ask other-turtle [set opinion x2-new]
    ]
  ]
  update-colors
  update-stats
  tick
end

to update-stats
  set mean-opinion mean [opinion] of turtles
  set sd-opinion standard-deviation [opinion] of turtles
end

to update-colors
  ask turtles [
    set color (opinion + 1) * 9.9 / 2
  ]
end
"""
end
