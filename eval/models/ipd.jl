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
globals [randomSeed palette mean-score p-mutate]

patches-own [
  s-number
  previous-outcome
  recent-score
  north-neighbor
  east-neighbor
  south-neighbor
  west-neighbor
]

to setup
  clear-all
  set p-mutate 0.01
  ask patches [
    set s-number random 16
    set previous-outcome random 4
    set recent-score 0
    set north-neighbor patch-at 0 1
    set east-neighbor patch-at 1 0
    set south-neighbor patch-at 0 -1
    set west-neighbor patch-at -1 0
  ]
  set mean-score 0
  reset-ticks
end

to go
  ask patches [
    let opponent north-neighbor
    let r random 4
    if r = 1 [ set opponent east-neighbor ]
    if r = 2 [ set opponent south-neighbor ]
    if r = 3 [ set opponent west-neighbor ]
    let my-go ifelse-value previous-outcome = 0 [
      floor (s-number / 8)
    ] [
      ifelse-value previous-outcome = 1 [
        floor ((s-number mod 8) / 4)
      ] [
        ifelse-value previous-outcome = 2 [
          floor ((s-number mod 4) / 2)
        ] [
          s-number mod 2
        ]
      ]
    ]
    let their-previous [previous-outcome] of opponent
    let their-strategy [s-number] of opponent
    let their-go ifelse-value their-previous = 0 [
      floor (their-strategy / 8)
    ] [
      ifelse-value their-previous = 1 [
        floor ((their-strategy mod 8) / 4)
      ] [
        ifelse-value their-previous = 2 [
          floor ((their-strategy mod 4) / 2)
        ] [
          their-strategy mod 2
        ]
      ]
    ]
    let my-outcome 2 * my-go + their-go
    set previous-outcome my-outcome
    set recent-score 4 + my-go - (4 * their-go) + (my-go * their-go)
    ask opponent [
      set previous-outcome 2 * their-go + my-go
      set recent-score 4 + their-go - (4 * my-go) + (their-go * my-go)
    ]
  ]
  ask patches [
    ifelse random-float 1 < (1 - p-mutate) [
      let best-strategy s-number
      let best-score recent-score
      let tie-count 1

      let north-score [recent-score] of north-neighbor
      ifelse north-score > best-score [
        set best-strategy [s-number] of north-neighbor
        set best-score north-score
        set tie-count 1
      ] [
        if north-score = best-score [
          set tie-count tie-count + 1
          if random tie-count = 0 [ set best-strategy [s-number] of north-neighbor ]
        ]
      ]

      let east-score [recent-score] of east-neighbor
      ifelse east-score > best-score [
        set best-strategy [s-number] of east-neighbor
        set best-score east-score
        set tie-count 1
      ] [
        if east-score = best-score [
          set tie-count tie-count + 1
          if random tie-count = 0 [ set best-strategy [s-number] of east-neighbor ]
        ]
      ]

      let south-score [recent-score] of south-neighbor
      ifelse south-score > best-score [
        set best-strategy [s-number] of south-neighbor
        set best-score south-score
        set tie-count 1
      ] [
        if south-score = best-score [
          set tie-count tie-count + 1
          if random tie-count = 0 [ set best-strategy [s-number] of south-neighbor ]
        ]
      ]

      let west-score [recent-score] of west-neighbor
      ifelse west-score > best-score [
        set best-strategy [s-number] of west-neighbor
        set best-score west-score
        set tie-count 1
      ] [
        if west-score = best-score [
          set tie-count tie-count + 1
          if random tie-count = 0 [ set best-strategy [s-number] of west-neighbor ]
        ]
      ]

      set s-number best-strategy
    ]
    [
      let i random 4
      if i = 0 [
        ifelse s-number >= 8 [ set s-number s-number - 8 ] [ set s-number s-number + 8 ]
      ]
      if i = 1 [
        ifelse (s-number mod 8) >= 4 [ set s-number s-number - 4 ] [ set s-number s-number + 4 ]
      ]
      if i = 2 [
        ifelse (s-number mod 4) >= 2 [ set s-number s-number - 2 ] [ set s-number s-number + 2 ]
      ]
      if i = 3 [
        ifelse (s-number mod 2) = 1 [ set s-number s-number - 1 ] [ set s-number s-number + 1 ]
      ]
    ]
  ]
  set mean-score mean [recent-score] of patches
  tick
end
"""
end
