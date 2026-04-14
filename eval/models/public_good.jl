# ── Public Good model ────────────────────────────────────────────────

struct PublicGoodModel <: AbstractBenchmarkModel end

model_name(::PublicGoodModel) = "Public Good"
n_ticks(::PublicGoodModel) = 100  # capped: exponential growth exceeds double precision at ~105 ticks
tracked_globals(::PublicGoodModel) = ["mean-money", "mean-investment", "bank"]
world_dims(::PublicGoodModel) = (-4, 4, -4, 4)

function netlogo_code(::PublicGoodModel)
"""
globals [randomSeed num-agents initial-money multiplier
         fraction-put-in punishment-cost punish?
         bank mean-money mean-investment]

turtles-own [
  my-money
  investment
]

to setup
  clear-all
  resize-world (- 4) 4 (- 4) 4
  set num-agents 10
  set initial-money 10
  set multiplier 2
  set fraction-put-in 0.5
  set punishment-cost 1
  set punish? false
  set bank 0
  create-turtles num-agents [
    set my-money initial-money
    set investment 0
    set shape "circle"
    setxy random-xcor random-ycor
  ]
  update-globals
  reset-ticks
end

to go
  ask turtles [
    set investment round (fraction-put-in * my-money)
    set my-money my-money - investment
  ]
  set bank sum [investment] of turtles
  set bank bank * multiplier
  let share bank / count turtles
  ask turtles [
    set my-money my-money + share
  ]
  if punish? [
    ask turtles [
      set my-money my-money - punishment-cost
    ]
    ask max-one-of turtles [my-money] [
      set my-money my-money - punishment-cost
    ]
  ]
  update-globals
  tick
end

to update-globals
  set mean-money mean [my-money] of turtles
  set mean-investment mean [investment] of turtles
end
"""
end
