# ── Basic Contact Process 2D (Spatial Birth-Death) ──────────────────
# Adapted from model-zoo 3.4-BasicContactProcess2D
# Lattice-based stochastic birth-death process

struct ContactProcessModel <: AbstractBenchmarkModel end

model_name(::ContactProcessModel) = "Contact Process 2D"
n_ticks(::ContactProcessModel) = 200
tracked_globals(::ContactProcessModel) = ["p-occupied"]
world_dims(::ContactProcessModel) = (-25, 24, -25, 24)

function netlogo_code(::ContactProcessModel)
"""
globals [randomSeed N p-occupied initial-pop p-death]

to setup
  clear-all
  set initial-pop 1800
  set p-death 0.607
  set N count patches
  ask patches [
    ifelse random N < initial-pop
    [ set pcolor black ]
    [ set pcolor white ]
  ]
  set p-occupied count patches with [pcolor = black] / N
  reset-ticks
end

to go
  if not any? patches with [pcolor = black] [ stop ]
  repeat N [
    ask one-of patches [
      ifelse pcolor = black
      [ death-event ]
      [ birth-event ]
    ]
  ]
  set p-occupied count patches with [pcolor = black] / N
  tick
end

to death-event
  if random-float 1 < p-death [
    set pcolor white
  ]
end

to birth-event
  set pcolor [pcolor] of one-of neighbors4
end
"""
end
