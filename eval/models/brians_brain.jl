# ── Brian's Brain model ──────────────────────────────────────────────

struct BriansBrainModel <: AbstractBenchmarkModel end

model_name(::BriansBrainModel) = "Brian's Brain"
n_ticks(::BriansBrainModel) = 200
tracked_globals(::BriansBrainModel) = ["firing", "refractory", "dead"]
world_dims(::BriansBrainModel) = (-43, 43, -57, 57)

function netlogo_code(::BriansBrainModel)
"""
globals [randomSeed initial-density firing refractory dead]

patches-own [
  firing?
  refractory?
  firing-neighbors
]

to setup
  clear-all
  resize-world (- 43) 43 (- 57) 57
  set initial-density 0.3
  ask patches [
    ifelse random-float 1.0 < initial-density
      [ cell-birth ]
      [ cell-death ]
  ]
  update-globals
  reset-ticks
end

to cell-birth
  set firing? true
  set refractory? false
  set pcolor white
end

to cell-aging
  set firing? false
  set refractory? true
  set pcolor red
end

to cell-death
  set firing? false
  set refractory? false
  set pcolor black
end

to go
  ask patches [
    set firing-neighbors count neighbors with [firing?]
  ]
  ask patches [
    ifelse firing?
      [ cell-aging ]
      [ ifelse refractory?
        [ cell-death ]
        [ if firing-neighbors = 2
          [ cell-birth ] ] ]
  ]
  update-globals
  tick
end

to update-globals
  set firing count patches with [firing?]
  set refractory count patches with [refractory?]
  set dead count patches with [not firing? and not refractory?]
end
"""
end
