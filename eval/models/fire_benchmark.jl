# ── Fire Benchmark (Modeling Commons #2451) ───────────────────────────

struct FireBenchmarkModel <: AbstractBenchmarkModel end

model_name(::FireBenchmarkModel) = "FireBenchmark"
n_ticks(::FireBenchmarkModel) = 100
tracked_globals(::FireBenchmarkModel) = ["burned-trees", "burning-count"]
world_dims(::FireBenchmarkModel) = (-40, 40, -40, 40)

function netlogo_code(::FireBenchmarkModel)
"""
globals [density initial-trees burned-trees burning-count fire-front burning-front]
patches-own [tree? heat next-fire]

to setup
  clear-all
  set density 64
  ask patches [
    set tree? false
    set heat 0
    set next-fire false
    if pxcor > 1 + min-pxcor [
      if (random 100) < density [
        set tree? true
        set pcolor green
      ]
    ]
    if pxcor = 1 + min-pxcor [
      set tree? false
      set heat 14
      set pcolor red
    ]
  ]
  set initial-trees count patches with [tree?]
  set burned-trees 0
  set fire-front patches with [heat > 0]
  set burning-front fire-front
  set burning-count count burning-front
  reset-ticks
end

to go
  if burning-count = 0 [ stop ]
  ask fire-front [
    ask neighbors4 with [tree?] [
      set next-fire true
    ]
  ]
  let new-fire-front patches with [next-fire]
  ask new-fire-front [
    set next-fire false
    set tree? false
    set heat 14
    set pcolor red
  ]
  ask burning-front [
    set heat heat - 1
    set pcolor pcolor - 0.3
  ]
  let still-burning burning-front with [heat > 0]
  set burned-trees burned-trees + count new-fire-front
  set fire-front new-fire-front
  set burning-front (patch-set new-fire-front still-burning)
  set burning-count count burning-front
  tick
end
"""
end
