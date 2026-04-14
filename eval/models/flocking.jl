# ── Flocking (Boids) ────────────────────────────────────────────────
# Source: modelingcommons #1180 (Wilensky 1998)
# Classic boids: align, cohere, separate.

struct FlockingModel <: AbstractBenchmarkModel end

model_name(::FlockingModel) = "Flocking"
n_ticks(::FlockingModel) = 200
tracked_globals(::FlockingModel) = ["avg-heading"]
world_dims(::FlockingModel) = (-45, 45, -45, 45)

function netlogo_code(::FlockingModel)
"""
globals [randomSeed population max-align-turn max-cohere-turn max-separate-turn vision minimum-separation avg-heading]

turtles-own [
  flockmates
  nearest-neighbor
]

to setup
  clear-all
  set population 200
  set max-align-turn 5
  set max-cohere-turn 3
  set max-separate-turn 1.5
  set vision 3
  set minimum-separation 1
  crt population
    [ set color yellow - 2 + random 7
      set size 1.5
      setxy random-xcor random-ycor ]
  reset-ticks
end

to go
  ask turtles [ flock ]
  repeat 5 [ ask turtles [ fd 0.2 ] ]
  set avg-heading mean [heading] of turtles
  tick
end

to flock
  find-flockmates
  if any? flockmates
    [ find-nearest-neighbor
      ifelse distance nearest-neighbor < minimum-separation
        [ separate ]
        [ align
          cohere ] ]
end

to find-flockmates
  set flockmates other turtles in-radius vision
end

to find-nearest-neighbor
  set nearest-neighbor min-one-of flockmates [distance myself]
end

to separate
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

to align
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading
  let x sum [dx] of flockmates
  let y sum [dy] of flockmates
  ifelse (x = 0) and (y = 0)
    [ report heading ]
    [ report atan x y ]
end

to cohere
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates
  let x mean [sin (towards myself + 180)] of flockmates
  let y mean [cos (towards myself + 180)] of flockmates
  ifelse (x = 0) and (y = 0)
    [ report heading ]
    [ report atan x y ]
end

to turn-towards [new-heading max-turn]
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]
  turn-at-most (subtract-headings heading new-heading) max-turn
end

to turn-at-most [turn max-turn]
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end
"""
end
