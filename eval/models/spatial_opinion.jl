# ── Spatial Opinion Dynamics ─────────────────────────────────────
# Source: modelingcommons #4530
# rnd extension: tests rnd:weighted-one-of with list-of-pairs
# Converted old [last ?] syntax to modern [[x] -> last x] lambda.

struct SpatialOpinionModel <: AbstractBenchmarkModel end

model_name(::SpatialOpinionModel) = "Spatial Opinion Dynamics"
n_ticks(::SpatialOpinionModel) = 50
tracked_globals(::SpatialOpinionModel) = ["fizz", "left-freq", "right-freq"]
world_dims(::SpatialOpinionModel) = (-5, 5, -5, 5)

function netlogo_code(::SpatialOpinionModel)
"""
extensions [rnd]

globals [
  fizz
  left-freq
  right-freq
  influence
  max-entrench
  init-attitude
  opinion-amplification
  rnd-initial
  positive-to-negative-ratio
  radius-size
]

turtles-own [
  old-attitude
  new-attitude
  id-neighbors
]

to setup
  clear-all
  set influence "linear"
  set max-entrench 3
  set init-attitude 2
  set opinion-amplification 0.1
  set rnd-initial true
  set positive-to-negative-ratio 0.5
  set radius-size 20

  ask patches [set pcolor gray]
  set-default-shape turtles "square"
  make-turtle-distribution
  ask turtles [
    set size 1.2
    set old-attitude new-attitude
  ]
  set fizz 0
  measure-frequency-over-time
  reset-ticks
end

to go
  ask turtles [ local-interactions ]
  set fizz (count turtles with [old-attitude != new-attitude]) / count turtles
  ask turtles [
    set old-attitude new-attitude
  ]
  measure-frequency-over-time
end

to local-interactions
  let j nobody
  ifelse influence = "max-inf" or influence = "min-inf" [
    if influence = "max-inf" [
      set j max-one-of turtles-on neighbors [abs old-attitude]
    ]
    if influence = "min-inf" [
      set j min-one-of turtles-on neighbors [abs old-attitude]
    ]
  ]
  [
    let localsum 0
    let pairlist []
    ask turtles-on neighbors [
      set localsum localsum + abs influence-function [old-attitude] of self
    ]
    ask turtles-on neighbors [
      let prob 0
      if localsum != 0 [set prob (abs influence-function [old-attitude] of self) / localsum]
      let pair []
      set pair lput self pair
      set pair lput prob pair
      set pairlist lput pair pairlist
    ]
    set j first rnd:weighted-one-of-list pairlist [[x] -> last x]
  ]
  if is-turtle? j [
    ifelse random-float 1 < opinion-amplification [
      if [old-attitude] of j > 0 [
        if abs old-attitude < max-entrench [
          ifelse old-attitude = -1 [set new-attitude 1] [ set new-attitude old-attitude + 1 ]
        ]
      ]
      if [old-attitude] of j < 0 [
        if abs old-attitude < max-entrench [
          ifelse old-attitude = 1 [set new-attitude -1] [set new-attitude old-attitude - 1 ]
        ]
      ]
    ]
    [
      if [old-attitude] of j > old-attitude [
        ifelse old-attitude = -1 [set new-attitude 1] [ set new-attitude old-attitude + 1]
      ]
      if [old-attitude] of j < old-attitude [
        ifelse old-attitude = 1 [ set new-attitude -1][set new-attitude old-attitude - 1 ]
      ]
    ]
  ]
end

to-report influence-function [item1]
  if influence = "linear" [
    ifelse item1 = 0 [report 1] [report item1]
  ]
  if influence = "square" [
    ifelse item1 = 0 [report 1] [report (item1 ^ 2)]
  ]
  if influence = "uniform" [
    if item1 < 0 [report -1]
    if item1 > 0 [report 1]
  ]
  if influence = "co-linear" [
    ifelse item1 = 0 [report 1] [report (max-entrench + 1 - abs item1) ]
  ]
  if influence = "co-square" [
    ifelse item1 = 0 [report 1] [report (max-entrench + 1 - abs item1) ^ 2 ]
  ]
end

to make-turtle-distribution
  ifelse rnd-initial [
    ask patches [
      ifelse random-float 1 < positive-to-negative-ratio [
        sprout 1 [
          set new-attitude (random init-attitude) + 1
        ]
      ]
      [
        sprout 1 [
          set new-attitude 0 - (random init-attitude) - 1
        ]
      ]
    ]
  ]
  [
    ask patches [
      ifelse (abs pxcor) ^ 2 + (abs pycor) ^ 2 <= radius-size ^ 2 [
        sprout 1 [
          set new-attitude max-entrench
        ]
      ]
      [
        sprout 1 [
          set new-attitude (0 - max-entrench)
        ]
      ]
    ]
  ]
end

to measure-frequency-over-time
  set left-freq count turtles with [old-attitude <= -1] / count turtles
  set right-freq count turtles with [old-attitude >= 1] / count turtles
end
"""
end
