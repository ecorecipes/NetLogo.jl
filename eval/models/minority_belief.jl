# ── Minority Belief Spread ─────────────────────────────────────────
# Source: modelingcommons #5129
# NW extension: nw:generate-preferential-attachment, layout-spring
# Belief diffusion on network; stops when all adopt new belief.

struct MinorityBeliefModel <: AbstractBenchmarkModel end

model_name(::MinorityBeliefModel) = "Minority Belief Spread"
n_ticks(::MinorityBeliefModel) = 500
tracked_globals(::MinorityBeliefModel) = ["n-magenta", "n-yellow", "n-cyan"]

extra_shapes(::MinorityBeliefModel) = """
target
false
0
Circle -7500403 false true 0 0 300
Circle -7500403 false true 30 30 240
Circle -7500403 false true 60 60 180
Circle -7500403 false true 90 90 120
Circle -7500403 true true 120 120 60
"""

function netlogo_code(::MinorityBeliefModel)
"""
extensions [nw]
globals [n-magenta n-yellow n-cyan Number_turtles Connection-probability Percentage_of_belivers Network_type]
turtles-own [ belief ]
breed [constants constant]
breed [opens open]

to setup
  clear-all
  set-default-shape turtles "person"
  set Number_turtles 200
  set Connection-probability 0.02
  set Percentage_of_belivers 0.14
  set Network_type "Preferential-attachment"
  if Network_type = "Random" [ nw:generate-random turtles links Number_turtles Connection-probability ]
  if Network_type = "Preferential-attachment" [ nw:generate-preferential-attachment turtles links Number_turtles 1 ]
  if Network_type = "Small-world" [ nw:generate-small-world turtles links world-width / 2 world-height / 2 2.0 false ]
  ask turtles [
    setxy random-xcor random-ycor
    set color cyan
    set belief random 2
    if belief = 1 [ set color yellow ]
  ]
  ask n-of (Percentage_of_belivers * Number_turtles) turtles [
    set breed constants
    set color magenta
    set shape "target"
    set belief 2
  ]
  ask turtles with [breed != constants] [ set breed opens ]
  update-counts
  reset-ticks
end

to go
  ask turtles [
    ifelse random 2 = 1 [ speak listen ] [ listen speak ]
  ]
  update-counts
  if (count turtles with [color = magenta]) / (count turtles) = 1 [ stop ]
  tick
end

to update-counts
  set n-magenta count turtles with [color = magenta]
  set n-yellow count turtles with [color = yellow]
  set n-cyan count turtles with [color = cyan]
end

to speak
  if breed = constants [
    ask in-link-neighbors with [breed = opens] [
      if belief != 2 and random-float 1.0 < 0.1 [
        set belief belief + 1
        if belief = 2 [ set color magenta ]
        if belief = 1 [ set color yellow ]
      ]
    ]
  ]
  if breed = opens [
    if belief = 2 and random-float 1.0 < 0.04 [
      ask in-link-neighbors with [belief = 1 and belief = 0] [
        set belief belief + 1
        if belief = 1 [ set color yellow ]
        if belief = 2 [ set color magenta ]
      ]
    ]
    if belief = 0 and random-float 1.0 < 0.04 [
      ask in-link-neighbors with [belief = 1 and belief = 2] [
        set belief belief - 1
        if belief = 1 [ set color yellow ]
        if belief = 0 [ set color white ]
      ]
    ]
  ]
end

to listen
  let belief_list (list 3)
  if breed = opens and random-float 1.0 < 0.04 [
    ask in-link-neighbors [ set belief_list fput belief belief_list ]
    foreach belief_list [ x -> if (x = 0 and belief != 0) [ set belief belief - 1 if belief = 0 [ set color white ] if belief = 1 [ set color yellow ] ] if (x = 2 and belief != 2) [ set belief belief + 1 if belief = 2 [ set color magenta ] if belief = 1 [ set color yellow ] ] ]
  ]
end
"""
end
