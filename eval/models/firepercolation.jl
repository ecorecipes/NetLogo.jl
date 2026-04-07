# ── Fire Percolation (Contagious Spread) ────────────────────────────
# Adapted from model-zoo 5.3-firePercolation
# Site percolation with fire spreading to green neighbors

struct FirePercolationModel <: AbstractBenchmarkModel end

model_name(::FirePercolationModel) = "Fire Percolation"
n_ticks(::FirePercolationModel) = 100
tracked_globals(::FirePercolationModel) = ["fire-size"]
world_dims(::FirePercolationModel) = (0, 99, 0, 99)

function netlogo_code(::FirePercolationModel)
"""
globals [randomSeed fire-front fire-size p]

to setup
  clear-all
  set p 0.6
  ask n-of (p * count patches) patches [set pcolor green]
  set fire-front patch-set nobody
  set fire-size 0
  reset-ticks
end

to go
  if ticks = 0 [
    ignite-fire
  ]
  ifelse any? fire-front [
    fire-spread
  ]
  [ stop ]
  set fire-size count patches with [pcolor = red]
  tick
end

to ignite-fire
  ask one-of patches with [pcolor = green] [
    set pcolor red
    set fire-front patch-set self
  ]
  set fire-size 1
end

to fire-spread
  let new-fire-front patch-set nobody
  ask fire-front [
    let n-green neighbors4 with [pcolor = green]
    ask n-green [
      set new-fire-front (patch-set new-fire-front self)
    ]
  ]
  ask new-fire-front [set pcolor red]
  set fire-front new-fire-front
end
"""
end
