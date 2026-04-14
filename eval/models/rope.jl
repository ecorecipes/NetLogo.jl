# ── Rope (Wave Propagation Along a String) ──────────────────────────
# Source: modelingcommons #1288 (Wilensky 1997)
# Green turtle drives wave, red turtles propagate.

struct RopeModel <: AbstractBenchmarkModel end

model_name(::RopeModel) = "Rope"
n_ticks(::RopeModel) = 500
tracked_globals(::RopeModel) = ["n-visible"]
world_dims(::RopeModel) = (0, 160, -80, 80)
topology(::RopeModel) = (false, false)

function netlogo_code(::RopeModel)
"""
globals [randomSeed friction frequency amplitude n-visible]

turtles-own [
  yvel
  ypos
]

to setup
  clear-all
  set friction 24
  set frequency 10
  set amplitude 30
  set-default-shape turtles "circle"
  create-turtles world-width [
    set xcor who
    set color red
    set size 1.5
    if pxcor = max-pxcor
      [ set color blue ]
    if pxcor = min-pxcor
      [ set color green ]
  ]
  reset-ticks
end

to go
  ask turtles with [color = green]
  [
    ifelse ticks > 100
       [ set ypos amplitude * sin (frequency * ticks) ]
       [ set ypos (ticks / 100) * amplitude * sin (frequency * ticks) ]
    ifelse patch-at 0 (ypos - ycor) != nobody
    [
      set ycor ypos
      show-turtle
    ]
    [ hide-turtle ]
  ]
  ask turtles with [color = red]
  [
    set yvel yvel + ((([ypos] of (turtle (who - 1))) - ypos) +
                     (([ypos] of (turtle (who + 1))) - ypos))
    set yvel ((1000 - friction) / 1000) * yvel
  ]
  ask turtles with [color = red]
  [
    set ypos ypos + yvel
    ifelse patch-at 0 (ypos - ycor) != nobody
      [ set ycor ypos
        show-turtle ]
      [ hide-turtle ]
  ]
  set n-visible count turtles with [not hidden?]
  tick
end
"""
end
