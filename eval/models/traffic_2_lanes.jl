# ── Traffic 2 Lanes model (NetLogo models library) ───────────────────

struct Traffic2LanesModel <: AbstractBenchmarkModel end

model_name(::Traffic2LanesModel) = "Traffic 2 Lanes"
n_ticks(::Traffic2LanesModel) = 200
tracked_globals(::Traffic2LanesModel) = ["mean-speed", "num-lane-changes"]
world_dims(::Traffic2LanesModel) = (-25, 25, -10, 10)

function netlogo_code(::Traffic2LanesModel)
"""
globals
[
  randomSeed
  number
  speed-up
  slow-down
  look-ahead
  selected-car
  mean-speed
  num-lane-changes
]

turtles-own
[
  speed
  speed-limit
  lane
  target-lane
  patience
  max-patience
  change?
]

to setup
  clear-all
  resize-world (- 25) 25 (- 10) 10
  set number 54
  set speed-up 38.0
  set slow-down 77.0
  set look-ahead 1
  set num-lane-changes 0
  draw-road
  set-default-shape turtles "default"
  crt number
  [ setup-cars ]
  set selected-car one-of turtles
  ask selected-car
  [ set color red ]
  update-tracked-globals
  reset-ticks
end

to draw-road
  ask patches
  [
    set pcolor green
    if ((pycor > -4) and (pycor < 4))
    [ set pcolor gray ]
    if ((pycor = 0) and ((pxcor mod 3) = 0))
    [ set pcolor yellow ]
    if ((pycor = 4) or (pycor = -4))
    [ set pcolor black ]
  ]
end

to setup-cars
  set color black
  set lane (random 2)
  set target-lane lane
  ifelse (lane = 0)
  [ setxy random-xcor -2 ]
  [ setxy random-xcor  2 ]
  set heading 90
  set speed 0.1 + random 9.9
  set speed-limit (((random 11) / 10) + 1)
  set change? false
  set max-patience ((random 50) + 10)
  set patience (max-patience - (random 10))
  loop
  [
    ifelse any? other turtles-here
    [ fd 1 ]
    [ stop ]
  ]
end

to drive
  set num-lane-changes 0
  ask turtles
  [
    ifelse (any? turtles-at 1 0)
    [
      set speed ([speed] of (one-of (turtles-at 1 0)))
      decelerate
    ]
    [
      ifelse (look-ahead = 2)
      [
        ifelse (any? turtles-at 2 0)
        [
          set speed ([speed] of (one-of turtles-at 2 0))
          decelerate
        ]
        [accelerate]
      ]
      [accelerate]
    ]
    if (speed < 0.01)
    [ set speed 0.01 ]
    if (speed > speed-limit)
    [ set speed speed-limit ]
    ifelse (change? = false)
    [ signal ]
    [ change-lanes ]
    ifelse (any? turtles-at 1 0) and (xcor != min-pxcor - .5)
    [ set speed [speed] of (one-of turtles-at 1 0) ]
    [
      ifelse ((any? turtles-at 2 0) and (speed > 1.0))
      [
        set speed ([speed] of (one-of turtles-at 2 0))
        fd 1
      ]
      [jump speed]
    ]
  ]
  update-tracked-globals
  tick
end

to accelerate
  set speed (speed + (speed-up / 1000))
end

to decelerate
  set speed (speed - (slow-down / 1000))
end

to change-lanes
  ifelse (patience <= 0)
  [
    ifelse (max-patience <= 1)
    [ set max-patience (random 10) + 1 ]
    [ set max-patience (max-patience - (random 5)) ]
    set patience max-patience
    ifelse (target-lane = 0)
    [
      set target-lane 1
      set lane 0
    ]
    [
      set target-lane 0
      set lane 1
    ]
  ]
  [ set patience (patience - 1) ]

  ifelse (target-lane = lane)
  [
    ifelse (target-lane = 0)
    [
      set target-lane 1
      set change? false
    ]
    [
      set target-lane 0
      set change? false
    ]
  ]
  [
    ifelse (target-lane = 1)
    [
      ifelse (pycor = 2)
      [
        set lane 1
        set change? false
        set num-lane-changes num-lane-changes + 1
      ]
      [
        ifelse (not any? turtles-at 0 1)
        [ set ycor (ycor + 1) ]
        [
          ifelse (not any? turtles-at 1 0)
          [ set xcor (xcor + 1) ]
          [
            decelerate
            if (speed <= 0)
            [ set speed 0.1 ]
          ]
        ]
      ]
    ]
    [
      ifelse (pycor = -2)
      [
        set lane 0
        set change? false
        set num-lane-changes num-lane-changes + 1
      ]
      [
        ifelse (not any? turtles-at 0 -1)
        [ set ycor (ycor - 1) ]
        [
          ifelse (not any? turtles-at 1 0)
          [ set xcor (xcor + 1) ]
          [
            decelerate
            if (speed <= 0)
            [ set speed 0.1 ]
          ]
        ]
      ]
    ]
  ]
end

to signal
  ifelse (any? turtles-at 1 0)
  [
    if ([speed] of (one-of (turtles-at 1 0))) < (speed)
    [ set change? true ]
  ]
  [ set change? false ]
end

to go
  drive
end

to update-tracked-globals
  ifelse any? turtles [
    set mean-speed mean [speed] of turtles
  ][
    set mean-speed 0
  ]
end
"""
end
