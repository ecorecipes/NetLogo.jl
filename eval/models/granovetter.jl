# ── Granovetter's threshold model of collective behaviour ────────────

struct GranovetterModel <: AbstractBenchmarkModel end

model_name(::GranovetterModel) = "Granovetter"
n_ticks(::GranovetterModel) = 200
tracked_globals(::GranovetterModel) = ["percent-rioting", "num-rioting"]
world_dims(::GranovetterModel) = (-16, 16, -16, 16)

function netlogo_code(::GranovetterModel)
"""
globals [randomSeed number-of-agents network threshold-distribution
         number-of-links rewire-prop mean-threshold sd-threshold
         percent-rioting num-rioting]

turtles-own [threshold riot?]

to setup
  clear-all
  resize-world (- 16) 16 (- 16) 16
  set-default-shape turtles "circle"
  set number-of-agents 20
  set network "random"
  set threshold-distribution "normal"
  set number-of-links 2
  set rewire-prop 0.2
  set mean-threshold 25
  set sd-threshold 10
  create-agents
  update-globals
  reset-ticks
end

to go
  ask turtles [
    let prop-rioting 100 * count link-neighbors with [riot? = true] / count link-neighbors
    if prop-rioting >= threshold [
      set riot? true
      set color red
    ]
  ]
  update-globals
  tick
end

to create-agents
  crt number-of-agents [
    set riot? false
    set color blue
    set threshold round (random-normal mean-threshold sd-threshold)
    if threshold < 0 [set threshold 0]
    if threshold > 100 [set threshold 100]
  ]
  arrange-turtles
  if network = "random" [
    ask turtles [create-links-with n-of number-of-links other turtles with [link-with myself = nobody]]
  ]
  if network = "small-world" [
    let max-who 1 + max [who] of turtles
    let sorted sort ([who] of turtles)
    foreach sorted [t ->
      ask turtle t [
        let i 1
        repeat number-of-links [
          create-link-with turtle ((t + i) mod max-who)
          set i i + 1
        ]
      ]
    ]
    repeat round (rewire-prop * number-of-agents) [
      ask one-of turtles [
        ask one-of my-links [die]
        create-link-with one-of other turtles with [link-with myself = nobody]
      ]
    ]
  ]
  if network = "fully connected" [
    ask turtles [create-links-with other turtles with [link-with myself = nobody]]
  ]
end

to arrange-turtles
  let the-turtles sort [who] of turtles
  let angle 360 / number-of-agents
  let dist max-pxcor - 1
  let i 0
  foreach the-turtles [t ->
    ask turtle t [
      setxy (dist * cos (angle * i)) (dist * sin (angle * i))
    ]
    set i i + 1
  ]
end

to update-globals
  set num-rioting count turtles with [riot?]
  set percent-rioting 100 * num-rioting / count turtles
end
"""
end
