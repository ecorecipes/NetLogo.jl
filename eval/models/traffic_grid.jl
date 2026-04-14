# ── Traffic Grid model (NetLogo models library) ──────────────────────

struct TrafficGridModel <: AbstractBenchmarkModel end

model_name(::TrafficGridModel) = "Traffic Grid"
n_ticks(::TrafficGridModel) = 200
tracked_globals(::TrafficGridModel) = ["num-cars-stopped", "mean-speed", "mean-wait-time"]
world_dims(::TrafficGridModel) = (-18, 18, -18, 18)

function netlogo_code(::TrafficGridModel)
"""
globals
[
  randomSeed
  grid-size-x
  grid-size-y
  num-cars
  speed-limit
  ticks-per-cycle
  power?
  current-phase
  current-auto?
  grid-x-inc
  grid-y-inc
  acceleration
  phase
  num-cars-stopped
  current-light
  mean-speed
  mean-wait-time
  intersections
  roads
]

turtles-own
[
  speed
  up-car?
  wait-time
]

patches-own
[
  intersection?
  green-light-up?
  my-row
  my-column
  my-phase
  auto?
]

to setup
  clear-all
  resize-world (- 18) 18 (- 18) 18
  set grid-size-x 5
  set grid-size-y 5
  set num-cars 200
  set speed-limit 1.0
  set ticks-per-cycle 20
  set power? true
  set current-phase 0
  set current-auto? true
  setup-globals
  setup-patches
  make-current one-of intersections
  set-default-shape turtles "default"
  if (num-cars > count roads) [ stop ]
  crt num-cars
  [
    setup-cars
    set-car-color
    record-data
  ]
  ask turtles [ set-car-speed ]
  update-tracked-globals
  reset-ticks
end

to setup-globals
  set current-light nobody
  set phase 0
  set num-cars-stopped 0
  set grid-x-inc world-width / grid-size-x
  set grid-y-inc world-height / grid-size-y
  set acceleration 0.099
end

to setup-patches
  ask patches
  [
    set intersection? false
    set auto? false
    set green-light-up? true
    set my-row -1
    set my-column -1
    set my-phase -1
    set pcolor brown + 3
  ]
  set roads patches with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) or
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
  set intersections roads with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) and
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
  ask roads [ set pcolor white ]
  setup-intersections
end

to setup-intersections
  ask intersections
  [
    set intersection? true
    set green-light-up? true
    set my-phase 0
    set auto? true
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
    set-signal-colors
  ]
end

to setup-cars
  set speed 0
  set wait-time 0
  put-on-empty-road
  ifelse intersection?
  [
    ifelse random 2 = 0
    [ set up-car? true ]
    [ set up-car? false ]
  ]
  [
    ifelse (floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0)
    [ set up-car? true ]
    [ set up-car? false ]
  ]
  ifelse up-car?
  [ set heading 180 ]
  [ set heading 90 ]
end

to put-on-empty-road
  move-to one-of roads with [not any? turtles-on self]
end

to go
  update-current
  set-signals
  set num-cars-stopped 0
  ask turtles
  [
    set-car-speed
    fd speed
    record-data
    set-car-color
  ]
  next-phase
  update-tracked-globals
  tick
end

to make-current [light]
  set current-light light
  set current-phase [my-phase] of current-light
  set current-auto? [auto?] of current-light
end

to update-current
  ask current-light [
    set my-phase current-phase
    set auto? current-auto?
  ]
end

to set-signals
  ask intersections with [auto? and phase = floor ((my-phase * ticks-per-cycle) / 100)]
  [
    set green-light-up? (not green-light-up?)
    set-signal-colors
  ]
end

to set-signal-colors
  ifelse power?
  [
    ifelse green-light-up?
    [
      ask patch-at -1 0 [ set pcolor red ]
      ask patch-at 0 1 [ set pcolor green ]
    ]
    [
      ask patch-at -1 0 [ set pcolor green ]
      ask patch-at 0 1 [ set pcolor red ]
    ]
  ]
  [
    ask patch-at -1 0 [ set pcolor white ]
    ask patch-at 0 1 [ set pcolor white ]
  ]
end

to set-car-speed
  ifelse pcolor = red
  [ set speed 0 ]
  [
    ifelse up-car?
    [ set-speed 0 -1 ]
    [ set-speed 1 0 ]
  ]
end

to set-speed [ delta-x delta-y ]
  let turtles-ahead turtles-at delta-x delta-y
  ifelse any? turtles-ahead
  [
    ifelse any? (turtles-ahead with [ up-car? != [up-car?] of myself ])
    [
      set speed 0
    ]
    [
      set speed [speed] of one-of turtles-ahead
      slow-down
    ]
  ]
  [ speed-up ]
end

to slow-down
  ifelse speed <= 0
  [ set speed 0 ]
  [ set speed speed - acceleration ]
end

to speed-up
  ifelse speed > speed-limit
  [ set speed speed-limit ]
  [ set speed speed + acceleration ]
end

to set-car-color
  ifelse speed < (speed-limit / 2)
  [ set color blue ]
  [ set color cyan - 2 ]
end

to record-data
  ifelse speed = 0
  [
    set num-cars-stopped num-cars-stopped + 1
    set wait-time wait-time + 1
  ]
  [ set wait-time 0 ]
end

to next-phase
  set phase phase + 1
  if phase mod ticks-per-cycle = 0
    [ set phase 0 ]
end

to update-tracked-globals
  ifelse any? turtles [
    set mean-speed mean [speed] of turtles
    set mean-wait-time mean [wait-time] of turtles
  ][
    set mean-speed 0
    set mean-wait-time 0
  ]
end
"""
end
