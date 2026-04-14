# ── Crystallization Directed ────────────────────────────────────────
# Source: modelingcommons #1334 (Wilensky 2002)
# Metal atoms cool from edges, crystallize when below melting temp.

struct CrystallizationModel <: AbstractBenchmarkModel end

model_name(::CrystallizationModel) = "Crystallization"
n_ticks(::CrystallizationModel) = 200
tracked_globals(::CrystallizationModel) = ["ave-metal-temp", "num-frozen"]
world_dims(::CrystallizationModel) = (-16, 16, -16, 16)
topology(::CrystallizationModel) = (false, false)

extra_shapes(::CrystallizationModel) = """t
true
0
Rectangle -7500403 true true 90 0 210 300
Rectangle -7500403 true true 0 0 300 90"""

function netlogo_code(::CrystallizationModel)
"""
globals [
  randomSeed
  room-temp
  init-metal-temp
  melting-temp
  width
  height
  histogram?
  heat-top?
  heat-bottom?
  heat-right?
  heat-left?
  ave-metal-temp
  num-frozen
  temp-range
  colors
  pens
]

turtles-own [
  temp
  neighboring-turtles
  sides-exposed
]

to setup
  clear-all
  set room-temp 20
  set init-metal-temp 1550
  set melting-temp 500
  set width 31
  set height 31
  set histogram? true
  set heat-top? false
  set heat-bottom? false
  set heat-right? false
  set heat-left? false
  set colors sentence (white - 1) [cyan sky blue violet magenta red]
  set pens []
  set temp-range (init-metal-temp - melting-temp) / (length colors - 1)
  let ymax (height + 1) / 2
  let xmax (width + 1) / 2
  let neighbor-offsets [[-1  1] [ 0  1] [1  1]
                        [-1  0] [ 0  0] [1  0]
                        [-1 -1] [ 0 -1] [1 -1]]
  ask patches [
    if ((abs pycor) < ymax) and ((abs pxcor) < xmax)
    [
      sprout 1
      [
        set shape "T"
        set temp init-metal-temp
        set-color
      ]
    ]
  ]
  ask patches [
    if (heat-top? and (pycor = ymax) and (abs pxcor <= xmax)) or (heat-left? and (pxcor = (- xmax)) and (abs pycor <= ymax)) or (heat-right? and (pxcor = xmax) and (abs pycor <= ymax)) or (heat-bottom? and (pycor = (- ymax)) and (abs pxcor <= xmax))
    [ set pcolor 16 ]
  ]
  ask turtles [
    set neighboring-turtles turtles at-points neighbor-offsets
    set sides-exposed count (patches at-points neighbor-offsets) with [(not any? turtles-here) and (pcolor = black)]
  ]
  set ave-metal-temp init-metal-temp
  reset-ticks
end

to go
  if (max ([temp] of turtles) < melting-temp) [ stop ]
  set num-frozen 0
  ask turtles [ cool-turtles ]
  ask turtles [ set-color ]
  ask turtles [ rotate ]
  set ave-metal-temp (mean [temp] of turtles)
  tick
end

to rotate
  if (temp >= melting-temp) [
    let frozen-neighbors (neighboring-turtles with [temp <= melting-temp])
    ifelse (any? frozen-neighbors)
      [ set heading ([heading] of (one-of frozen-neighbors)) ]
      [ rt random-float 360 ]
  ]
end

to cool-turtles
  let total-temp ((sum [temp] of neighboring-turtles) +
                  (room-temp * sides-exposed) + temp)
  set temp (total-temp / (count neighboring-turtles + sides-exposed + 1))
end

to set-color
  let index (floor ((temp - melting-temp) / temp-range)) + 1
  ifelse (index < 1) [
    set color white - 1
    set num-frozen (num-frozen + 1)
  ]
  [
    if index >= length colors
      [ set index (length colors) - 1 ]
    set color item index colors
  ]
end
"""
end
