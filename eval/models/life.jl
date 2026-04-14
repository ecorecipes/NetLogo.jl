# ── Life model (Conway's Game of Life, NetLogo models library) ───────

struct LifeModel <: AbstractBenchmarkModel end

model_name(::LifeModel) = "Life"
n_ticks(::LifeModel) = 200
tracked_globals(::LifeModel) = ["living-count", "density"]
world_dims(::LifeModel) = (-50, 50, -50, 50)

function netlogo_code(::LifeModel)
"""
globals [randomSeed initial-density living-count density]

patches-own [
  living?
  live-neighbors
]

to setup
  clear-all
  resize-world (- 50) 50 (- 50) 50
  set initial-density 35.0
  ask patches [
    ifelse random-float 100.0 < initial-density [
      cell-birth
    ] [
      cell-death
    ]
  ]
  update-globals
  reset-ticks
end

to go
  ask patches [
    set live-neighbors count neighbors with [living?]
  ]
  ask patches [
    ifelse live-neighbors = 3 [
      cell-birth
    ] [
      if live-neighbors != 2 [
        cell-death
      ]
    ]
  ]
  update-globals
  tick
end

to update-globals
  set living-count count patches with [living?]
  set density living-count / count patches
end

to cell-birth
  set living? true
  set pcolor 123
end

to cell-death
  set living? false
  set pcolor 79
end
"""
end
