# ── Cooperation model (NetLogo models library) ──────────────────────

struct CooperationModel <: AbstractBenchmarkModel end

model_name(::CooperationModel) = "Cooperation"
n_ticks(::CooperationModel) = 200
tracked_globals(::CooperationModel) = ["num-cooperative", "num-greedy"]
world_dims(::CooperationModel) = (-10, 10, -10, 10)

function netlogo_code(::CooperationModel)
"""
globals [randomSeed initial-cows cooperative-probability stride-length metabolism
         reproduction-threshold reproduction-cost
         grass-energy max-grass-height low-high-threshold
         high-growth-chance low-growth-chance
         num-cooperative num-greedy]

turtles-own [energy]
patches-own [grass]

breed [cooperative-cows cooperative-cow]
breed [greedy-cows greedy-cow]

to setup
  clear-all
  random-seed randomSeed
  resize-world (- 10) 10 (- 10) 10
  set initial-cows 20
  set cooperative-probability 0.5
  set stride-length 0.08
  set metabolism 6
  set reproduction-threshold 102
  set reproduction-cost 54
  set grass-energy 51
  set max-grass-height 10
  set low-high-threshold 5
  set high-growth-chance 77
  set low-growth-chance 30
  setup-cows
  ask patches [
    set grass max-grass-height
    color-grass
  ]
  update-globals
  reset-ticks
end

to setup-cows
  set-default-shape turtles "cow"
  crt initial-cows [
    setxy random-xcor random-ycor
    set energy metabolism * 4
    ifelse (random-float 1.0 < cooperative-probability) [
      set breed cooperative-cows
      set color red - 1.5
    ] [
      set breed greedy-cows
      set color sky - 2
    ]
  ]
end

to go
  if not any? turtles [ stop ]
  ask turtles [
    move
    eat
    reproduce
  ]
  ask patches [
    grow-grass
    color-grass
  ]
  update-globals
  tick
end

to update-globals
  set num-cooperative count cooperative-cows
  set num-greedy count greedy-cows
end

to reproduce
  if energy > reproduction-threshold [
    set energy energy - reproduction-cost
    hatch 1
  ]
end

to grow-grass
  ifelse (grass >= low-high-threshold) [
    if high-growth-chance >= random-float 100 [
      set grass grass + 1
    ]
  ] [
    if low-growth-chance >= random-float 100 [
      set grass grass + 1
    ]
  ]
  if grass > max-grass-height [
    set grass max-grass-height
  ]
end

to color-grass
  set pcolor scale-color (green - 1) grass 0 (2 * max-grass-height)
end

to move
  rt random 360
  fd stride-length
  set energy energy - metabolism
  if energy < 0 [ die ]
end

to eat
  ifelse breed = cooperative-cows [
    eat-cooperative
  ] [
    if breed = greedy-cows [
      eat-greedy
    ]
  ]
end

to eat-cooperative
  if grass > low-high-threshold [
    set grass grass - 1
    set energy energy + grass-energy
  ]
end

to eat-greedy
  if grass > 0 [
    set grass grass - 1
    set energy energy + grass-energy
  ]
end
"""
end
