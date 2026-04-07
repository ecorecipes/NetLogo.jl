# ── Heat Diffusion model ──────────────────────────────────────────────

struct DiffusionModel <: AbstractBenchmarkModel end

model_name(::DiffusionModel) = "Heat Diffusion"
n_ticks(::DiffusionModel) = 100
tracked_globals(::DiffusionModel) = ["max-temp", "mean-temp"]

function netlogo_code(::DiffusionModel)
"""
globals [max-temp mean-temp]
patches-own [temp]

to setup
  clear-all
  ask patches [
    set temp 0
  ]
  ask patch 0 0 [
    set temp 100
    ask neighbors [ set temp 50 ]
  ]
  recolor
  update-stats
  reset-ticks
end

to go
  diffuse temp 0.5
  ask patches [
    set temp temp * 0.99
  ]
  ask patch 0 0 [ set temp 100 ]
  recolor
  update-stats
  tick
end

to recolor
  ask patches [
    set pcolor scale-color red temp 0 100
  ]
end

to update-stats
  set max-temp max [temp] of patches
  set mean-temp mean [temp] of patches
end
"""
end
