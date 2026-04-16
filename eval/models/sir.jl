# ── SIR (Susceptible-Infected-Recovered) epidemic model ───────────────

struct SIRModel <: AbstractBenchmarkModel end

model_name(::SIRModel) = "SIR Epidemic"
n_ticks(::SIRModel) = 200
tracked_globals(::SIRModel) = ["num-susceptible", "num-infected", "num-recovered"]

function netlogo_code(::SIRModel)
"""
globals [
  population initial-infected initial-recovered
  infection-probability infection-radius recovery-days
  movement-step turn-range
  num-susceptible num-infected num-recovered
]
turtles-own [state days-infected]

to setup
  clear-all
  let total max list 0 round population
  let recovered-count min list total (max list 0 round initial-recovered)
  let infected-count min list (total - recovered-count) (max list 0 round initial-infected)
  create-turtles total [
    setxy random-xcor random-ycor
    set state "S"
    set days-infected 0
    set color green
  ]
  ask n-of recovered-count turtles [
    set state "R"
    set color gray
  ]
  ask n-of infected-count turtles with [state = "S"] [
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
    rt random-float (2 * turn-range) - turn-range
    fd movement-step
  ]
  ask turtles with [state = "I"] [
    ask turtles in-radius infection-radius with [state = "S"] [
      if random-float 1.0 < infection-probability [
        set state "I"
        set color red
        set days-infected 1
      ]
    ]
    set days-infected days-infected + 1
    if days-infected > recovery-days [
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
