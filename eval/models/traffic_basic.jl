# ── Traffic Basic ─────────────────────────────────────────────────────
# Source: modelingcommons #1474 (Uri Wilensky, 1997)
# Simple 1D traffic model with cars following each other.
# Cars accelerate when road is clear, decelerate when car ahead.

struct TrafficBasicModel <: AbstractBenchmarkModel end

model_name(::TrafficBasicModel) = "Traffic Basic"
n_ticks(::TrafficBasicModel) = 200
tracked_globals(::TrafficBasicModel) = ["mean-speed"]
world_dims(::TrafficBasicModel) = (-25, 25, -4, 4)
topology(::TrafficBasicModel) = (true, false)    # wrap x, no wrap y

function setup_commands(::TrafficBasicModel)
    return "random-seed \$SEED setup"
end

go_command(::TrafficBasicModel) = "go"

function netlogo_code(::TrafficBasicModel)
    return """
globals [ sample-car mean-speed ]
turtles-own [ speed speed-limit speed-min ]

to setup
  clear-all
  ask patches [ setup-road ]
  setup-cars
  set mean-speed mean [speed] of turtles
  reset-ticks
end

to setup-road
  if (pycor < 2) and (pycor > -2) [ set pcolor white ]
end

to setup-cars
  if number-of-cars > world-width [ stop ]
  set-default-shape turtles "default"
  crt number-of-cars [
    set color blue
    set xcor random-xcor
    set heading 90
    set speed 0.1 + random-float 0.9
    set speed-limit 1
    set speed-min 0
    separate-cars
  ]
  set sample-car one-of turtles
  ask sample-car [ set color red ]
end

to separate-cars
  if any? other turtles-here [ fd 1 separate-cars ]
end

to go
  ask turtles [
    let car-ahead one-of turtles-on patch-ahead 1
    ifelse car-ahead != nobody
      [ set speed [speed] of car-ahead
        slow-down-car ]
      [ speed-up-car ]
    if speed < speed-min [ set speed speed-min ]
    if speed > speed-limit [ set speed speed-limit ]
    fd speed
  ]
  set mean-speed mean [speed] of turtles
  tick
end

to slow-down-car
  set speed speed - deceleration
end

to speed-up-car
  set speed speed + acceleration
end
"""
end
