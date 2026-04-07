# ── SIR (Susceptible-Infected-Recovered) epidemic model ───────────────

struct SIRModel <: AbstractBenchmarkModel end

model_name(::SIRModel) = "SIR Epidemic"
n_ticks(::SIRModel) = 200
tracked_globals(::SIRModel) = ["num-susceptible", "num-infected", "num-recovered"]

function netlogo_code(::SIRModel)
"""
globals [num-susceptible num-infected num-recovered]
turtles-own [state days-infected]

to setup
  clear-all
  create-turtles 200 [
    setxy random-xcor random-ycor
    set state "S"
    set days-infected 0
    set color green
  ]
  ask n-of 5 turtles [
    set state "I"
    set color red
    set days-infected 1
  ]
  update-counts
  reset-ticks
end

to go
  if num-infected = 0 [ stop ]
  ask turtles [
    rt random 50 - 25
    fd 1
  ]
  ask turtles with [state = "I"] [
    ask turtles in-radius 1.5 with [state = "S"] [
      if random-float 1.0 < 0.15 [
        set state "I"
        set color red
        set days-infected 1
      ]
    ]
    set days-infected days-infected + 1
    if days-infected > 14 [
      set state "R"
      set color gray
    ]
  ]
  update-counts
  tick
end

to update-counts
  set num-susceptible count turtles with [state = "S"]
  set num-infected count turtles with [state = "I"]
  set num-recovered count turtles with [state = "R"]
end
"""
end
