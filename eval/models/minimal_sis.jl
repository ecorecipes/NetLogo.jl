# ── Minimal SIS Model ─────────────────────────────────────────────
# Source: modelingcommons #7696
# Array extension: from-list, item for shuffled contact selection
# SIS epidemic on a ring of agents with basic reproduction number.

struct MinimalSISModel <: AbstractBenchmarkModel end

model_name(::MinimalSISModel) = "Minimal SIS"
n_ticks(::MinimalSISModel) = 100
tracked_globals(::MinimalSISModel) = ["reproduction-number", "new-infected"]
world_dims(::MinimalSISModel) = (-16, 16, -16, 16)
extra_shapes(::MinimalSISModel) = """
person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
"""

function netlogo_code(::MinimalSISModel)
"""
extensions [array]
globals [reproduction-number old-infected new-infected basic-reproduction-number population]

breed [individuals individual]
individuals-own [
  state
  marked?
]

to setup
  clear-all
  set basic-reproduction-number 2
  set population 31
  make-turtles
  set reproduction-number basic-reproduction-number
  set new-infected 1
  recolor
  reset-ticks
end

to make-turtles
  set-default-shape individuals "person"
  create-ordered-individuals population [
    set size 0.1
    jump 0.35
    set state "SUSCEPTIBLE"
    set marked? false
  ]
  ask individual 0 [set state "INFECTED"]
end

to go
  if new-infected > 0 [a-go]
end

to a-go
  set old-infected new-infected
  clear-links
  ask individuals [infect]
  set new-infected 0
  ask individuals [update]
  ifelse old-infected = 0
    [set reproduction-number 0]
    [set reproduction-number (new-infected / old-infected)]
  recolor
end

to recolor
  ask individuals [
    ifelse state = "SUSCEPTIBLE"
      [set color blue]
      [set color red]
  ]
end

to infect
  if state = "INFECTED" [
    let values array:from-list shuffle range (population - 1)
    let index 0
    repeat basic-reproduction-number [
      let i2 array:item values index
      let i3 ((i2 + 1 + who) mod population)
      ask individual i3 [set marked? true]
      create-link-with individual i3
      set index (index + 1)
    ]
  ]
end

to update
  ifelse marked? and state = "SUSCEPTIBLE" [
    set state "INFECTED"
    set new-infected (new-infected + 1)
  ] [
    if state = "INFECTED" [set state "SUSCEPTIBLE"]
  ]
  set marked? false
end
"""
end
