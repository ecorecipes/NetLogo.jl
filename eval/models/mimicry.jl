# ── Mimicry (Batesian Mimicry Evolution) ────────────────────────────
# Source: modelingcommons #1442 (Wilensky 1997)
# Monarchs are toxic, viceroys mimic their color to avoid birds.
# Converted from NetLogo 5 `?` syntax to NetLogo 6 arrow syntax.

struct MimicryModel <: AbstractBenchmarkModel end

model_name(::MimicryModel) = "Mimicry"
n_ticks(::MimicryModel) = 200
tracked_globals(::MimicryModel) = ["n-monarchs", "n-viceroys", "n-birds"]
world_dims(::MimicryModel) = (-20, 20, -20, 20)

function netlogo_code(::MimicryModel)
"""
globals [
  randomSeed
  memory-duration
  mutation-rate
  memory-size
  n-monarchs
  n-viceroys
  n-birds
  carrying-capacity-monarchs
  carrying-capacity-viceroys
  carrying-capacity-birds
  color-range-begin
  color-range-end
  reproduction-chance
]

breed [ monarchs monarch ]
breed [ viceroys viceroy ]
breed [ birds bird ]
birds-own [ memory ]

to setup
  clear-all
  set memory-duration 30
  set mutation-rate 5
  set memory-size 3
  setup-variables
  setup-turtles
  reset-ticks
end

to setup-variables
  set carrying-capacity-monarchs 225
  set carrying-capacity-viceroys 225
  set carrying-capacity-birds 75
  set reproduction-chance 4
  set color-range-begin 15
  set color-range-end 109
end

to setup-turtles
  ask patches [ set pcolor white ]
  create-birds carrying-capacity-birds
  [
    set color black
    set memory []
  ]
  create-monarchs carrying-capacity-monarchs [ set color red ]
  create-viceroys carrying-capacity-viceroys [ set color blue ]
  ask turtles [ setxy random-xcor random-ycor ]
end

to go
  ask birds [ birds-move ]
  ask turtles with [breed != birds] [ butterflies-move ]
  ask turtles with [breed != birds] [ butterflies-get-eaten ]
  ask birds [ birds-forget ]
  ask turtles with [breed != birds] [ butterflies-reproduce ]
  set n-monarchs count monarchs
  set n-viceroys count viceroys
  set n-birds count birds
  tick
end

to birds-move
  set heading 180 + random 180
  fd 1
end

to butterflies-move
  rt random 100
  lt random 100
  fd 1
end

to butterflies-get-eaten
  let bird-here one-of birds-here
  if bird-here != nobody
  [
    if not [color-in-memory? [color] of myself] of bird-here
    [
      if breed = monarchs
        [ ask bird-here [ remember-color [color] of myself ] ]
      die
    ]
  ]
end

to-report color-in-memory? [c]
  foreach memory [ x -> if item 0 x = c [ report true ] ]
  report false
end

to remember-color [c]
  if length memory >= memory-size
  [ set memory but-first memory ]
  set memory lput (list c 0) memory
end

to birds-forget
  set memory map [ x -> list (item 0 x) (1 + item 1 x) ] memory
  set memory filter [ x -> item 1 x <= memory-duration ] memory
end

to butterflies-reproduce
  ifelse breed = monarchs
  [ if random count monarchs < carrying-capacity-monarchs - count monarchs
     [ hatch-butterfly ] ]
  [ if random count viceroys < carrying-capacity-viceroys - count viceroys
     [ hatch-butterfly ] ]
end

to hatch-butterfly
  if random-float 100 < reproduction-chance
  [
    hatch 1
    [
      fd 1
      if random-float 100 < mutation-rate
      [ set color one-of sublist base-colors 1 10 ]
    ]
  ]
end
"""
end
