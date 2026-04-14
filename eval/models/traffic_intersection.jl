# ── Traffic Intersection model (NetLogo models library) ──────────────

struct TrafficIntersectionModel <: AbstractBenchmarkModel end

model_name(::TrafficIntersectionModel) = "Traffic Intersection"
n_ticks(::TrafficIntersectionModel) = 200
tracked_globals(::TrafficIntersectionModel) = ["waiting-overall", "waiting-eastbound", "waiting-northbound"]
world_dims(::TrafficIntersectionModel) = (-17, 17, -17, 17)
topology(::TrafficIntersectionModel) = (false, false)  # bounded: cars die at edges

function netlogo_code(::TrafficIntersectionModel)
"""
globals [
  randomSeed
  freq-north
  freq-east
  speed-limit
  max-accel
  max-brake
  green-length
  yellow-length
  auto?
  stop-light
  waiting-overall
  waiting-eastbound
  waiting-northbound
]

turtles-own [ speed ]
patches-own [ clear-in ]

to setup
  clear-all
  resize-world (- 17) 17 (- 17) 17
  set freq-north 60
  set freq-east 100
  set speed-limit 5
  set max-accel 2
  set max-brake 4
  set green-length 12
  set yellow-length 3
  set auto? true
  set-default-shape turtles "default"
  ask patches
    [ set pcolor green - 1
      if abs pxcor <= 1 or abs pycor <= 1
        [ set pcolor black ]
    ]
  set stop-light "north"
  draw-stop-light
  update-tracked-globals
  reset-ticks
end

to draw-stop-light
  ask patches with [abs pxcor <= 1 and abs pycor <= 1]
    [ set pcolor black ]
  ifelse stop-light = "north"
  [ ask patch 0 -1 [ set pcolor red ]
    ask patch -1 0 [ set pcolor green ]
  ]
  [ ask patch 0 -1 [ set pcolor green ]
    ask patch -1 0 [ set pcolor red ]
  ]
end

to go
  move-cars
  make-new-cars
  if auto?
  [ if ticks mod (green-length + yellow-length) = 0
    [ switch ]
    if ticks mod (green-length + yellow-length) > green-length
    [ ask patches with [pcolor = green]
      [ set pcolor yellow ]
    ]
  ]
  update-tracked-globals
  tick
end

to make-new-cars
  if (random-float 100 < freq-north) and not any? turtles-on patch 0 min-pycor
    [
      crt 1
        [ set ycor min-pycor
          set heading 0
          set color 5 + 10 * random 14
          set speed min (list clear-ahead speed-limit)
        ]
    ]
  if (random-float 100 < freq-east) and not any? turtles-on patch min-pxcor 0
    [
      crt 1
        [ set xcor min-pxcor
          set heading 90
          set color 5 + 10 * random 14
          set speed min (list clear-ahead speed-limit)
        ]
    ]
end

to move-cars
  ask turtles [ move ]
  check-for-collisions
end

to move
  let clear-to clear-ahead
  ifelse clear-to > speed
  [ if speed < speed-limit
    [ set speed speed + min (list max-accel (clear-to - 1 - speed)) ]
    if speed > speed-limit
    [ set speed speed-limit ]
  ]
  [ set speed speed - min (list max-brake (speed - (clear-to - 1)))
    if speed < 0 [ set speed 0 ]
  ]
  repeat speed
  [
    fd 1
    if not can-move? 1
    [ die ]
    if pcolor = orange
    [ set clear-in 5
      die
    ]
  ]
end

to-report clear-ahead
  let n 1
  repeat max-accel + speed
  [ if (n * dx + pxcor <= max-pxcor) and (n * dy + pycor <= max-pycor)
    [ if([pcolor] of patch-ahead n = red) or
        ([pcolor] of patch-ahead n = orange) or
        (any? turtles-on patch-ahead n)
      [ report n ]
      set n n + 1
    ]
  ]
  report n
end

to check-for-collisions
  ask patches with [ pcolor = orange ]
  [ set clear-in clear-in - 1
    if clear-in = 0
    [ set pcolor black ]
  ]
  ask patches with [ count turtles-here > 1 ]
  [
    set pcolor orange
    set clear-in 5
    ask turtles-here [ die ]
  ]
end

to switch
  ifelse stop-light = "north"
  [ set stop-light "east"
    draw-stop-light
  ]
  [ set stop-light "north"
    draw-stop-light
  ]
end

to update-tracked-globals
  set waiting-overall count turtles with [speed = 0]
  set waiting-eastbound count turtles with [heading = 90 and speed = 0]
  set waiting-northbound count turtles with [heading = 0 and speed = 0]
end
"""
end
