# ── Mousetraps (Modeling Commons #1188) ───────────────────────────────

struct MousetrapsModel <: AbstractBenchmarkModel end

model_name(::MousetrapsModel) = "Mousetraps"
n_ticks(::MousetrapsModel) = 150
tracked_globals(::MousetrapsModel) = ["traps-triggered", "balls-in-air"]
world_dims(::MousetrapsModel) = (-80, 80, -80, 80)
topology(::MousetrapsModel) = (false, false)

function netlogo_code(::MousetrapsModel)
"""
globals [max-distance traps-triggered balls-in-air]

to setup
  clear-all
  set max-distance 4.5
  set traps-triggered 0
  ask patches [ set pcolor blue + 3 ]
  set-default-shape turtles "circle"
  crt 1 [
    set color white
    set size 1.5
  ]
  set balls-in-air count turtles
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask turtles [
    ifelse pcolor = red
      [ die ]
      [
        set pcolor red
        set traps-triggered traps-triggered + 1
        hatch 1 [ move ]
        move
      ]
  ]
  set balls-in-air count turtles
  tick
end

to move
  rt random-float 360
  fd random-float max-distance
end
"""
end
