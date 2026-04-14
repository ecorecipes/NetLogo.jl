# ── Spread of Fake News During Crisis ────────────────────────────────
# Source: modelingcommons #6335
# NW extension: generate-random
# Cascade/Bass information diffusion on random networks.

struct FakeNewsModel <: AbstractBenchmarkModel end

model_name(::FakeNewsModel) = "Spread of Fake News"
n_ticks(::FakeNewsModel) = 100
tracked_globals(::FakeNewsModel) = ["pct-aware", "pct-unaware"]

function netlogo_code(::FakeNewsModel)
"""
extensions [nw]

turtles-own [aware? tick-become-aware seed?]

globals [
  num-agents
  mean-degree-of-network
  num-seed-informers
  broadcast-influence
  influence-rate
  cascade-model?
  previous-count
  pct-aware
  pct-unaware
]

to setup
  clear-all
  set num-agents 200
  set mean-degree-of-network 4
  set num-seed-informers 10
  set broadcast-influence 0.01
  set influence-rate 0.3
  set cascade-model? true

  let edge-prob (2 * mean-degree-of-network) / (num-agents - 1)
  nw:generate-random turtles links num-agents edge-prob [
    set aware? false
    setxy random-xcor random-ycor
    set color white
    set shape "person"
    set seed? false
  ]

  ask n-of num-seed-informers turtles [
    set aware? true
    set tick-become-aware -1
    set color orange
    set seed? true
  ]

  set previous-count (count turtles with [aware?])
  set pct-aware (count turtles with [aware?]) / num-agents * 100
  set pct-unaware (count turtles with [not aware?]) / num-agents * 100
  reset-ticks
end

to go
  if not any? turtles with [not aware?] [ stop ]

  ifelse cascade-model? [
    ask turtles with [tick-become-aware = (ticks - 1)] [
      pass-adopt
    ]
    ask turtles with [not aware?] [
      adopt
    ]
  ] [
    ask turtles with [not aware?] [
      adopt-bass-model
    ]
  ]

  if (previous-count = count turtles with [aware?]) and (broadcast-influence = 0) [
    stop
  ]
  set previous-count (count turtles with [aware?])
  set pct-aware (count turtles with [aware?]) / num-agents * 100
  set pct-unaware (count turtles with [not aware?]) / num-agents * 100

  tick
end

to adopt
  if random-float 1 < broadcast-influence [
    set aware? true
    set tick-become-aware ticks
    set color red
  ]
end

to pass-adopt
  let neighbors-unadopted link-neighbors with [not aware?]
  if count neighbors-unadopted > 0 [
    ask neighbors-unadopted [
      if random-float 1 < influence-rate [
        set aware? true
        set tick-become-aware ticks
        set color yellow
      ]
    ]
  ]
end

to adopt-bass-model
  ifelse random-float 1 < broadcast-influence [
    set aware? true
    set color red
  ] [
    let neighbors-adopted link-neighbors with [aware?]
    let total-neighbors link-neighbors
    if count total-neighbors > 0 [
      if not aware? and random-float 1 < (influence-rate * (count neighbors-adopted / count total-neighbors)) [
        set aware? true
        set color yellow
      ]
    ]
  ]
end
"""
end

world_dims(::FakeNewsModel) = (-16, 16, -16, 16, true, true)
