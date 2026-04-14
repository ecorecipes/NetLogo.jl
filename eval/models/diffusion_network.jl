# ── Diffusione in Social Network and Utility Function ─────────────
# Source: modelingcommons #7017
# NW extension: generate-preferential-attachment with directed links
# Idea diffusion on a Barabási–Albert network with utility functions.
# Agents adopt red/grey ideas based on weighted incoming influence.

struct DiffusionNetworkModel <: AbstractBenchmarkModel end

model_name(::DiffusionNetworkModel) = "Diffusion Network"
n_ticks(::DiffusionNetworkModel) = 20
tracked_globals(::DiffusionNetworkModel) = ["num-red-dn", "num-grey-dn"]
world_dims(::DiffusionNetworkModel) = (-16, 16, -16, 16)
topology(::DiffusionNetworkModel) = (true, true)
extra_shapes(::DiffusionNetworkModel) = """
person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
"""

function netlogo_code(::DiffusionNetworkModel)
"""
extensions [nw]
breed [group person]
directed-link-breed [influences influence]
links-own [weight alternative]
group-own [p utility preferences oldsum]
globals [
  changing
  members
  threshold
  num-red-dn
  num-grey-dn
]

to setup
  clear-all
  set members 100
  set threshold 0.5
  set changing true
  nw:generate-preferential-attachment group influences members 1 [
    set color grey
    setxy random-xcor random-ycor
    set shape "person"
    set size 2
  ]
  ask influences [set weight (round (1000 * random-float 1) / 1000)]
  ask group [set p random 2]
  ask group [if (p = 1) [set color red]]
  ask group [if (p = 0) [set p -1 set color grey]]
  set num-red-dn count group with [color = red]
  set num-grey-dn count group with [color = grey]
  reset-ticks
end

to go
  if (changing = false) [stop]
  set changing false
  ask influences [if [color] of end1 = red [set color red]]
  ask group [
    let summer 0
    ask my-in-links [
      let netweight (weight * ([p] of end1))
      set summer (summer + netweight)
    ]
    set oldsum precision oldsum 3
    set summer precision summer 3
    if (oldsum != summer) [set changing true]
    set oldsum summer
    let oldcolor color
    ifelse (summer > threshold) [
      set p 1
      set color red
    ] [
      if (summer < threshold * -1) [
        set p -1
        set color grey
      ]
    ]
  ]
  ask influences [set alternative weight * [p] of end1]
  ask group [
    ifelse any? my-in-influences [
      set preferences [alternative] of my-in-influences
      set utility max preferences
    ] [
      set utility p
    ]
  ]
  set num-red-dn count group with [color = red]
  set num-grey-dn count group with [color = grey]
end
"""
end
