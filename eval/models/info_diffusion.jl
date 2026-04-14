# ── Information Diffusion Process Model ────────────────────────────
# Source: modelingcommons #6403
# NW extension: generate-preferential-attachment (Barabási–Albert)
# Hoax spreading: S→B (believer) or S→F (fact-checker) via neighbors,
# with forgetting (B/F→S) and verifying (B→F). Stops at tick 300.

struct InfoDiffusionModel <: AbstractBenchmarkModel end

model_name(::InfoDiffusionModel) = "Info Diffusion"
n_ticks(::InfoDiffusionModel) = 300
tracked_globals(::InfoDiffusionModel) = ["num-believers", "num-factcheckers", "num-susceptibles"]

function netlogo_code(::InfoDiffusionModel)
"""
extensions [nw]

turtles-own [state]
links-own [weigth]

globals [
  pForget
  pVerify
  beta-spreadingRate
  alpha-hoaxCredibility
  number-of-agents
  num-believers
  num-factcheckers
  num-susceptibles
]

to setup
  clear-all
  set pForget 0.18
  set pVerify 0.05
  set beta-spreadingRate 0.50
  set alpha-hoaxCredibility 0.30
  set number-of-agents 100

  set-default-shape turtles "person"
  nw:generate-preferential-attachment turtles links number-of-agents 3

  ask links [set color 3]
  ask turtles [
    setxy random-xcor random-ycor
    ifelse random 100 <= 90 [ set state "S" ][ set state "B" ]
  ]
  update-counts
  reset-ticks
end

to go
  tick
  if ticks > 300 [stop]
  spreading
  forgetting
  veryfing
  update-counts
end

to spreading
  ask turtles with [state = "S"] [
    let nB count link-neighbors with [state = "B"]
    let nF count link-neighbors with [state = "F"]
    let _1PlusA (1 + alpha-hoaxCredibility)
    let _1MinusA (1 - alpha-hoaxCredibility)
    let den (nB * _1PlusA + nF * _1MinusA)
    let f 0
    let g 0
    if den != 0 [
      set f beta-spreadingRate * (nB * _1PlusA / den)
      set g beta-spreadingRate * (nF * _1MinusA / den)
    ]
    let random-val-f random-float 1
    ifelse random-val-f < f
    [ set state "B" ]
    [ if random-val-f < (f + g) [ set state "F" ] ]
  ]
end

to forgetting
  ask turtles with [state = "B" or state = "F"] [
    if random-float 1 < pForget [
      set state "S"
    ]
  ]
end

to veryfing
  ask turtles with [state = "B"] [
    if random-float 1 < pVerify [
      set state "F"
    ]
  ]
end

to update-counts
  set num-believers count turtles with [state = "B"]
  set num-factcheckers count turtles with [state = "F"]
  set num-susceptibles count turtles with [state = "S"]
end
"""
end
