# ── Misinformation Diffusion (SBFC framework) ────────────────────
# Source: modelingcommons #7872
# NW extension: generate-preferential-attachment
# Barabási–Albert network with SBFC misinformation spreading,
# forgetting, and fact-checking dynamics.

struct MisinformationSBFCModel <: AbstractBenchmarkModel end

model_name(::MisinformationSBFCModel) = "Misinformation SBFC"
n_ticks(::MisinformationSBFCModel) = 300
tracked_globals(::MisinformationSBFCModel) = ["num-believers-sbfc", "num-factcheckers-sbfc", "num-susceptibles-sbfc"]
world_dims(::MisinformationSBFCModel) = (-16, 16, -16, 16)
topology(::MisinformationSBFCModel) = (false, false)
extra_shapes(::MisinformationSBFCModel) = """
person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
"""

function netlogo_code(::MisinformationSBFCModel)
"""
extensions [ nw ]

globals [
  number-of-agents
  pForget
  pVerify
  beta-spreadingRate
  alpha-hoaxCredibility
  beta-fc-spread
  pForget-FC
  Type-of-network
  num-believers-sbfc
  num-factcheckers-sbfc
  num-susceptibles-sbfc
]

turtles-own [ state ]
links-own [ weigth ]

to setup
  ca
  set number-of-agents 100
  set pForget 0.2
  set pVerify 0.4
  set beta-spreadingRate 0.45
  set alpha-hoaxCredibility 0.25
  set beta-fc-spread 0.55
  set pForget-FC 0.05
  set Type-of-network "BA"
  setup-var
  setup-turtles
  set num-believers-sbfc count turtles with [state = "B"]
  set num-factcheckers-sbfc count turtles with [state = "F"]
  set num-susceptibles-sbfc count turtles with [state = "S"]
  reset-ticks
end

to go
  spreading
  forgetting
  veryfing
  set num-believers-sbfc count turtles with [state = "B"]
  set num-factcheckers-sbfc count turtles with [state = "F"]
  set num-susceptibles-sbfc count turtles with [state = "S"]
end

to setup-var
  set-default-shape turtles "person"
end

to setup-turtles
  nw:generate-preferential-attachment turtles links number-of-agents 3
  init-edges
end

to init-edges
  ask links [ set color 3 ]
  ask turtles [
    setxy random-xcor random-ycor
    ifelse random 100 <= 90 [ set state "S" ] [ set state "B" ]
  ]
end

to spreading
  ask turtles with [state = "S"] [
    let nB count link-neighbors with [state = "B"]
    let nF count link-neighbors with [state = "F"]
    let _1PlusA  (1 + alpha-hoaxCredibility)
    let _1MinusA (1 - alpha-hoaxCredibility)
    let den (nB * _1PlusA + nF * _1MinusA)
    let f 0
    let g 0
    if den != 0 [
      set f beta-spreadingRate * (nB * _1PlusA  / den)
      set g beta-fc-spread     * (nF * _1MinusA / den)
    ]
    let r random-float 1
    ifelse r < f [
      set state "B"
    ] [
      if r < (f + g) [
        set state "F"
      ]
    ]
  ]
end

to forgetting
  ask turtles with [state = "B"] [
    if random-float 1 < pForget [
      set state "S"
    ]
  ]
  ask turtles with [state = "F"] [
    if random-float 1 < pForget-FC [
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
"""
end
