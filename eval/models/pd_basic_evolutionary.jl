# ── PD Basic Evolutionary model ──────────────────────────────────────

struct PdBasicEvolutionaryModel <: AbstractBenchmarkModel end

model_name(::PdBasicEvolutionaryModel) = "PD Basic Evolutionary"
n_ticks(::PdBasicEvolutionaryModel) = 200
tracked_globals(::PdBasicEvolutionaryModel) = ["cooperators", "defectors", "cc", "dd"]
world_dims(::PdBasicEvolutionaryModel) = (-50, 50, -50, 50)

function netlogo_code(::PdBasicEvolutionaryModel)
"""
globals [randomSeed initial-cooperation Defection-Award
         cooperators defectors cc dd]

patches-own [
  cooperate?
  old-cooperate?
  score
]

to setup
  clear-all
  resize-world (- 50) 50 (- 50) 50
  set initial-cooperation 66.6
  set Defection-Award 1.59
  ask patches [
    ifelse random-float 1.0 < (initial-cooperation / 100)
      [set cooperate? true set old-cooperate? true]
      [set cooperate? false set old-cooperate? false]
  ]
  update-globals
  reset-ticks
end

to go
  ask patches [interact]
  ask patches [select-strategy]
  update-globals
  tick
end

to interact
  let total-cooperaters count neighbors with [cooperate?]
  ifelse cooperate?
    [set score total-cooperaters]
    [set score Defection-Award * total-cooperaters]
end

to select-strategy
  set old-cooperate? cooperate?
  set cooperate? [cooperate?] of max-one-of neighbors [score]
end

to update-globals
  set cooperators count patches with [cooperate?]
  set defectors count patches with [not cooperate?]
  set cc count patches with [old-cooperate? and cooperate?]
  set dd count patches with [not old-cooperate? and not cooperate?]
end
"""
end
