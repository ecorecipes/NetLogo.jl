# ── Boiling (Heat Diffusion with Phase Transition) ──────────────────
# Source: modelingcommons #1282
# Patches diffuse heat, warming up mod 212.

struct BoilingModel <: AbstractBenchmarkModel end

model_name(::BoilingModel) = "Boiling"
n_ticks(::BoilingModel) = 200
tracked_globals(::BoilingModel) = ["avg-heat"]
world_dims(::BoilingModel) = (-40, 40, -40, 40)

function netlogo_code(::BoilingModel)
"""
globals [randomSeed avg-heat]

patches-own [heat]

to setup
  clear-all
  ask patches [
    set heat random 212
    set pcolor scale-color red heat 0 212
  ]
  set avg-heat mean [heat] of patches
  reset-ticks
end

to go
  diffuse heat 1
  ask patches [
    set heat (heat + 5) mod 212
    set pcolor scale-color red heat 0 212
  ]
  set avg-heat mean [heat] of patches
  tick
end
"""
end
