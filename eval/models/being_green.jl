# ── Being Green model (CSS600 ClassModels) ──────────────────────────────

struct BeingGreenModel <: AbstractBenchmarkModel end

model_name(::BeingGreenModel) = "Being Green"
n_ticks(::BeingGreenModel) = 200
tracked_globals(::BeingGreenModel) = ["n-action-takers"]
world_dims(::BeingGreenModel) = (-16, 16, -16, 16)

function netlogo_code(::BeingGreenModel)
"""
globals [randomSeed initial-people average-locus-of-control average-social-pressure average-sense-of-responsibility average-PBC n-action-takers]

turtles-own [
  action-taker?
  susceptible?
  internal?
  responsible?
  locus-of-control
  sense-of-responsibility
  PBC
  social-pressure
]

to setup
  clear-all
  set initial-people 200
  set average-locus-of-control 50
  set average-social-pressure 50
  set average-sense-of-responsibility 50
  set average-PBC 20
  setup-people
  set n-action-takers count turtles with [action-taker?]
  reset-ticks
end

to setup-people
  crt initial-people [
    setxy random-xcor random-ycor
    set shape "person"
    set action-taker? (who < initial-people * 0.10)
    assign-locus-of-control
    assign-sense-of-responsibility
    assign-PBC
    assign-social-pressure
    assign-color
    ifelse social-pressure > 70 [set susceptible? true] [set susceptible? false]
    ifelse locus-of-control > 70 [set internal? true] [set internal? false]
    ifelse sense-of-responsibility > 70 [set responsible? true] [set responsible? false]
  ]
end

to assign-color
  ifelse action-taker?
    [ set color green ]
    [ set color red ]
end

to assign-locus-of-control
  set locus-of-control random-normal average-locus-of-control 10
end

to assign-sense-of-responsibility
  set sense-of-responsibility random-normal average-sense-of-responsibility 10
end

to assign-PBC
  set PBC random-normal average-PBC 10
end

to assign-social-pressure
  set social-pressure random-normal average-social-pressure 10
end

to go
  if all? turtles [action-taker?]
    [ stop ]
  ask turtles
    [ move ]
  ask turtles with [action-taker?] [ interact ]
  ask turtles [ test ]
  ask turtles [ assign-color ]
  ask turtles [ evaluate-parameters ]
  set n-action-takers count turtles with [action-taker?]
  tick
end

to move
  rt random-float 360
  fd 1
end

to interact
  let nearby-red (turtles-on neighbors) with [not action-taker?]
  if nearby-red != nobody
    [ask nearby-red [influence]]
end

to influence
  if not susceptible?
  [set social-pressure (social-pressure + 1) move]

  if susceptible? and not internal?
  [set PBC (PBC + 5) set locus-of-control (locus-of-control + 1) move]

  if susceptible? and internal? and not responsible?
  [set PBC (PBC + 5)
  set sense-of-responsibility (sense-of-responsibility + 5) move]

  if susceptible? and internal? and responsible?
  [set PBC (PBC + 5) move]
end

to test
  if locus-of-control > 70 and sense-of-responsibility > 70 and
  PBC > 70
  [set action-taker? true set color green]
end

to evaluate-parameters
  ifelse social-pressure > 70 [set susceptible? true] [set susceptible? false]
  ifelse locus-of-control > 70 [set internal? true] [set internal? false]
  ifelse sense-of-responsibility > 70 [set responsible? true] [set responsible? false]
end

to-report action-rate
  ifelse any? turtles
    [ report (count turtles with [action-taker?] / count turtles) * 100 ]
    [ report 0 ]
end
"""
end
