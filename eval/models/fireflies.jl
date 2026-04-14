# ── Fireflies model (NetLogo models library) ────────────────────────

struct FirefliesModel <: AbstractBenchmarkModel end

model_name(::FirefliesModel) = "Fireflies"
n_ticks(::FirefliesModel) = 200
tracked_globals(::FirefliesModel) = ["num-flashing"]
world_dims(::FirefliesModel) = (-35, 35, -35, 35)

function netlogo_code(::FirefliesModel)
"""
globals [randomSeed number cycle-length flash-length flashes-to-reset
         show-dark-fireflies? strategy num-flashing]

turtles-own [
  clock
  threshold
  reset-level
  window
]

to setup
  clear-all
  resize-world (- 35) 35 (- 35) 35
  set number 1500
  set cycle-length 10
  set flash-length 1
  set flashes-to-reset 1
  set show-dark-fireflies? true
  set strategy "delay"
  crt number [
    setxy random-xcor random-ycor
    set clock random (round cycle-length)
    set threshold flash-length
    ifelse strategy = "delay"
      [ set reset-level threshold
        set window -1 ]
      [ set reset-level 0
        set window (threshold + 1) ]
    set size 2
    recolor
  ]
  set num-flashing count turtles with [color = yellow]
  reset-ticks
end

to go
  ask turtles [
    move
    increment-clock
    if (clock > window) and (clock >= threshold)
      [ look ]
  ]
  ask turtles [ recolor ]
  set num-flashing count turtles with [color = yellow]
  tick
end

to recolor
  ifelse (clock < threshold)
    [ st
      set color yellow ]
    [ set color gray - 2
      ifelse show-dark-fireflies?
        [ st ]
        [ ht ] ]
end

to move
  rt random-float 90 - random-float 90
  fd 1
end

to increment-clock
  set clock (clock + 1)
  if clock = cycle-length
    [ set clock 0 ]
end

to look
  if count turtles in-radius 1 with [color = yellow] >= flashes-to-reset
    [ set clock reset-level ]
end
"""
end
