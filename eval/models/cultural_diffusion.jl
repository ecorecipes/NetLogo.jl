# ── Cultural Diffusion of Programming Languages ──────────────────
# Source: modelingcommons #4611
# Array extension: from-list, item, set, to-list, length for census tracking
# Patches represent developers who innovate, adopt, or forget languages.

struct CulturalDiffusionModel <: AbstractBenchmarkModel end

model_name(::CulturalDiffusionModel) = "Cultural Diffusion"
n_ticks(::CulturalDiffusionModel) = 200
tracked_globals(::CulturalDiffusionModel) = ["num-iter", "total-langs-cd"]
world_dims(::CulturalDiffusionModel) = (-8, 8, -8, 8)

function netlogo_code(::CulturalDiffusionModel)
"""
extensions [array]
globals [
  num-iter
  max-capacity
  census
  ProbInnov
  ProbAdoption
  ProbForget
  MaxLang
  total-langs-cd
]

patches-own [langj]

to setup
  clear-all
  set ProbInnov 0.5
  set ProbAdoption 0.9
  set ProbForget 0.0002
  set MaxLang 120
  set num-iter 0
  set max-capacity 3
  set census array:from-list n-values (1 + MaxLang) [5]
  ask patches [set langj (list)]
  set total-langs-cd sum array:to-list census
  reset-ticks
end

to go
  ask patches [adoption]
  set num-iter num-iter + 1
  set total-langs-cd sum array:to-list census
end

to adoption
  let check true
  if (random-float 1.0 < ProbInnov) [
    if length langj < max-capacity [
      let l (1 + random MaxLang)
      if not member? l langj [
        set langj lput l langj
        array:set census l (array:item census l + 1)
      ]
    ]
    set check false
  ]
  if (random-float 1.0 < ProbAdoption) and check [
    let n one-of neighbors
    let langv [langj] of n
    if length langv > 0 [
      let c-total (sum array:to-list census)
      let lv item (most-frequent-known langv c-total) langv
      if not member? lv langj [
        let lenj length langj
        if lenj >= max-capacity [
          let i random lenj
          let f item i langj
          set langj remove-item i langj
          array:set census f (array:item census f - 1)
        ]
        set langj lput lv langj
        array:set census lv (array:item census lv + 1)
      ]
    ]
    set check false
  ]
  if (random-float 1.0 < ProbForget) and check [
    if length langj > 1 [
      let c-total (sum array:to-list census)
      let i (least-frequent-known langj c-total)
      let f item i langj
      array:set census f (array:item census f - 1)
      set langj remove-item i langj
    ]
  ]
end

to-report least-frequent-known [lan c-total]
  if c-total = 0 [report -1]
  if length lan = 0 [report -1]
  if length lan = 1 [report 0]
  let prob map [[x] -> 1.0 - ((array:item census x) / c-total)] lan
  report weighted-rand-index2 lan prob
end

to-report most-frequent-known [lan c-total]
  if c-total = 0 [report -1]
  if length lan = 0 [report -1]
  if length lan = 1 [report 0]
  let prob map [[x] -> (array:item census x) / c-total] lan
  report weighted-rand-index2 lan prob
end

to-report weighted-rand-index2 [values probs]
  let i -1
  let found false
  let nc length probs
  while [not found] [
    set i random nc
    let p item i probs
    if (random-float 1.0 < p) or (p >= 0.9999999999) [
      set found true
    ]
  ]
  report i
end
"""
end
