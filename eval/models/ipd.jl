# ── Iterated Prisoner's Dilemma (Spatial Evolutionary Game) ─────────
# Adapted from model-zoo 3.16-IPD
# Patches play IPD, copy best neighbor's strategy, with mutation

struct IPDModel <: AbstractBenchmarkModel end

model_name(::IPDModel) = "Spatial IPD"
n_ticks(::IPDModel) = 100
tracked_globals(::IPDModel) = ["mean-score"]
world_dims(::IPDModel) = (0, 49, 0, 49)

function netlogo_code(::IPDModel)
"""
globals [randomSeed rewards palette mean-score C-C C-D D-C D-D p-mutate score-memory]

patches-own [
  s-number
  s-list
  previous-outcome
  recent-scores
  N5
]

to-report strategy-from-number [x]
  let s []
  repeat 4 [
    set s fput (x mod 2) s
    set x floor (x / 2)
  ]
  report s
end

to-report number-from-strategy [s]
  report sum (map [[a b] -> a * b] s (reverse n-values 4 [i -> 2 ^ i]))
end

to setup
  clear-all
  set C-C 4
  set C-D 0
  set D-C 5
  set D-D 2
  set p-mutate 0.01
  set score-memory 1
  set rewards (list C-C C-D D-C D-D)
  ask patches [
    set s-number random 16
    set s-list strategy-from-number s-number
    set previous-outcome random 4
    set recent-scores []
    set N5 (patch-set self neighbors4)
  ]
  set mean-score 0
  reset-ticks
end

to go
  ask patches [
    let opponent one-of neighbors4
    let my-go choice
    let their-go [choice] of opponent
    set previous-outcome 2 * my-go + their-go
    update-score
    ask opponent [
      set previous-outcome 2 * their-go + my-go
      update-score
    ]
  ]
  let top-scores patches with-max [ifelse-value (length recent-scores > 0) [mean recent-scores] [0]]
  ask patches [
    ifelse random-float 1 < (1 - p-mutate) [
      set s-number [s-number] of one-of N5 with-max [ifelse-value (length recent-scores > 0) [mean recent-scores] [0]]
      set s-list strategy-from-number s-number
    ]
    [
      mutate-strategy
    ]
  ]
  set mean-score mean [ifelse-value (length recent-scores > 0) [mean recent-scores] [0]] of patches
  tick
end

to mutate-strategy
  let i random 4
  let new-val 1 - item i s-list
  set s-list replace-item i s-list new-val
  set s-number number-from-strategy s-list
end

to-report choice
  report item previous-outcome s-list
end

to update-score
  set recent-scores fput (item previous-outcome rewards) recent-scores
  if length recent-scores > score-memory [
    set recent-scores but-last recent-scores
  ]
end
"""
end
