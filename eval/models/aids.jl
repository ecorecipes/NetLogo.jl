# ── AIDS model (NetLogo models library) ─────────────────────────────

struct AidsModel <: AbstractBenchmarkModel end

model_name(::AidsModel) = "AIDS"
n_ticks(::AidsModel) = 200
tracked_globals(::AidsModel) = ["num-uninfected", "num-infected-unknown", "num-infected-known", "pct-infected"]
world_dims(::AidsModel) = (-12, 12, -12, 12)

function netlogo_code(::AidsModel)
"""
globals [randomSeed initial-people
         average-commitment average-coupling-tendency
         average-condom-use average-test-frequency
         infection-chance symptoms-show
         slider-check-1 slider-check-2 slider-check-3 slider-check-4
         num-uninfected num-infected-unknown num-infected-known pct-infected]

turtles-own [
  infected?
  known?
  infection-length
  coupled?
  couple-length
  commitment
  coupling-tendency
  condom-use
  test-frequency
  partner
  righty?
]

to setup
  clear-all
  resize-world (- 12) 12 (- 12) 12
  set initial-people 300
  set average-commitment 50
  set average-coupling-tendency 5
  set average-condom-use 0
  set average-test-frequency 0
  set infection-chance 50
  set symptoms-show 200.0
  set slider-check-1 average-commitment
  set slider-check-2 average-coupling-tendency
  set slider-check-3 average-condom-use
  set slider-check-4 average-test-frequency
  setup-people
  update-globals
  reset-ticks
end

to setup-people
  crt initial-people [
    setxy random-xcor random-ycor
    set known? false
    set coupled? false
    set partner nobody
    set righty? (random 2 = 0)
    set infected? (who < initial-people * 0.025)
    if infected?
      [ set infection-length random-float symptoms-show ]
    assign-commitment
    assign-coupling-tendency
    assign-condom-use
    assign-test-frequency
    assign-color
  ]
end

to assign-color
  ifelse not infected?
    [ set color green ]
    [ ifelse known?
      [ set color red ]
      [ set color blue ] ]
end

to assign-commitment
  set commitment random-near average-commitment
end

to assign-coupling-tendency
  set coupling-tendency random-near average-coupling-tendency
end

to assign-condom-use
  set condom-use random-near average-condom-use
end

to assign-test-frequency
  set test-frequency random-near average-test-frequency
end

to-report random-near [center]
  let result 0
  repeat 40
    [ set result (result + random-float center) ]
  report result / 20
end

to go
  if all? turtles [known?] [ stop ]
  ask turtles [
    if infected?
      [ set infection-length infection-length + 1 ]
    if coupled?
      [ set couple-length couple-length + 1 ]
  ]
  ask turtles [
    if not coupled? [ move ]
  ]
  ask turtles [
    if not coupled? and righty? and (random-float 10.0 < coupling-tendency)
      [ couple ]
  ]
  ask turtles [ uncouple ]
  ask turtles [ infect ]
  ask turtles [ test ]
  ask turtles [ assign-color ]
  update-globals
  tick
end

to move
  rt random-float 360
  fd 1
end

to couple
  let potential-partner one-of (turtles-at -1 0) with [not coupled? and not righty?]
  if potential-partner != nobody [
    if random-float 10.0 < [coupling-tendency] of potential-partner [
      set partner potential-partner
      set coupled? true
      ask partner [ set coupled? true ]
      ask partner [ set partner myself ]
      move-to patch-here
      ask potential-partner [ move-to patch-here ]
      set pcolor gray - 3
      ask (patch-at -1 0) [ set pcolor gray - 3 ]
    ]
  ]
end

to uncouple
  if coupled? and righty? [
    if (couple-length > commitment) or
       ([couple-length] of partner) > ([commitment] of partner) [
      set coupled? false
      set couple-length 0
      ask partner [ set couple-length 0 ]
      set pcolor black
      ask (patch-at -1 0) [ set pcolor black ]
      ask partner [ set partner nobody ]
      ask partner [ set coupled? false ]
      set partner nobody
    ]
  ]
end

to infect
  if coupled? and infected? and not known? [
    if random-float 11 > condom-use or
       random-float 11 > ([condom-use] of partner) [
      if random-float 100 < infection-chance [
        ask partner [ set infected? true ]
      ]
    ]
  ]
end

to test
  if random-float 52 < test-frequency [
    if infected?
      [ set known? true ]
  ]
  if infection-length > symptoms-show [
    if random-float 100 < 5
      [ set known? true ]
  ]
end

to update-globals
  set num-uninfected count turtles with [not infected?]
  set num-infected-unknown count turtles with [infected? and not known?]
  set num-infected-known count turtles with [infected? and known?]
  ifelse any? turtles
    [ set pct-infected (count turtles with [infected?] / count turtles) * 100 ]
    [ set pct-infected 0 ]
end
"""
end
