# ── Sugarscape Sexual Reproduction (Matrix Extension) ─────────────────
# Source: modelingcommons #7148 (Sugarscape_Sexual_Reproduction)
# Matrix extension: matrix:from-row-list, matrix:get-row for 50x50 landscape
# Based on Epstein & Axtell's Growing Artificial Societies ch.3.
# Population with sugar metabolism, vision, sexual reproduction.
# Tracks population count over time.

struct SugarscapeSexualModel <: AbstractBenchmarkModel end

model_name(::SugarscapeSexualModel) = "Sugarscape Sexual"
n_ticks(::SugarscapeSexualModel) = 200
tracked_globals(::SugarscapeSexualModel) = ["count turtles"]

function world_dims(::SugarscapeSexualModel)
    return (min_pxcor=0, max_pxcor=49, min_pycor=0, max_pycor=49)
end

function setup_commands(::SugarscapeSexualModel)
    return ""
end

netlogo_code(::SugarscapeSexualModel) = raw"""
extensions [matrix]
globals [initial-population visualization]

turtles-own [
  sugar
  metabolism
  vision
  vision-points
  sexo
  edad
  muerte
  fertilidadc
  fertilidadf
  dotacion
]

patches-own [
  psugar
  max-psugar
]

to setup
  clear-all
  set initial-population 200
  set visualization "no-visualization"
  create-turtles initial-population [ turtle-setup ]
  setup-patches
  reset-ticks
end

to turtle-setup
  set color red
  set shape "person"
  move-to one-of patches with [not any? other turtles-here]
  set sugar random-in-range 50 100
  set dotacion sugar
  set metabolism random-in-range 1 4
  set vision random-in-range 1 6
  set vision-points []
  foreach (range 1 (vision + 1)) [ n ->
    set vision-points sentence vision-points (list (list 0 n) (list n 0) (list 0 (- n)) (list (- n) 0))
  ]
  set muerte 60 + random 40
  set sexo random 2
  set edad 0
  set fertilidadc 12 + random 3
  ifelse sexo = 1
    [set fertilidadf 50 + random 10]
    [set fertilidadf 40 + random 10]
  run visualization
end

to setup-patches
  let m matrix:from-row-list [[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 2 2 2 2 2 2 2 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 3 3 4 4 4 4 3 3 3 3 3 3 3 2 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 3 3 3 3 3 3 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2]
[0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 3]
[0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3]
[0 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3]
[0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3]
[0 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3]
[0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 3]
[0 0 0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2]
[0 0 0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 3 3 3 3 3 3 2]
[1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 4 4 4 4 3 3 3 3 3 3 3 2 2]
[1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2]
[1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2]
[1 1 1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2]
[1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2]
[1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2]
[1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1]
[1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1]
[1 1 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1]
[1 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1]
[1 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1]
[2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1]
[2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1]
[2 2 2 2 2 2 3 3 3 3 3 3 3 4 4 4 4 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1]
[2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 0 0 0]
[2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 3 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0]
[2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 3 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0]
[2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0]
[2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0]
[2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0]
[2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2 2 2 2 2 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0]
[2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 3 2 2 2 2 2 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0]
[2 2 2 2 2 3 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0]
[2 2 2 2 2 3 3 3 3 3 3 4 4 4 4 4 4 4 4 3 3 3 3 3 3 2 2 2 2 2 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0]
[2 2 2 2 2 2 3 3 3 3 3 3 3 4 4 4 4 3 3 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0]
[2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0]
[2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 3 3 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 1 2 2 2 2 2 2 2 2 2 2 3 3 3 3 3 3 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
[1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]]
  let i 0
  let j 0
  let rowx 49
  repeat 50 [
    repeat 50 [
      let row-i matrix:get-row m i
      ask patches with [pxcor = i and pycor = j] [
        set max-psugar item rowx row-i
        set psugar max-psugar
        patch-recolor
      ]
      set rowx rowx - 1
      set j j + 1
    ]
    set i i + 1
    set j 0
    set rowx 49
  ]
end

to go
  if not any? turtles [ stop ]
  ask patches [
    patch-growback
    patch-recolor
  ]
  ask turtles [
    turtle-move
    turtle-eat
    if sugar <= 0 [ die ]
    if edad = muerte [ die ]
    set edad edad + 1
    if (edad >= fertilidadc) and (edad <= fertilidadf) and (sugar >= dotacion) [
      sexear
    ]
    run visualization
  ]
  tick
end

to parir [metaP visionP metaM visionM dotacionP dotacionM]
  hatch 1 [
    move-to patch-ahead 1
    set color green
    ifelse (random 2 = 0) [set metabolism metaM] [set metabolism metaP]
    ifelse (random 2 = 0) [set vision visionM] [set vision visionP]
    set vision-points []
    foreach (range 1 (vision + 1)) [ n ->
      set vision-points sentence vision-points (list (list 0 n) (list n 0) (list 0 (- n)) (list (- n) 0))
    ]
    ifelse (random 2 = 0) [set sexo 0] [set sexo 1]
    set muerte 60 + random 40
    set edad 0
    set fertilidadc 12 + random 3
    ifelse sexo = 1 [set fertilidadf 50 + random 10] [set fertilidadf 40 + random 10]
    let sugarH (dotacionP / 2) + (dotacionM / 2)
    set sugar sugarH
    set dotacion sugar
  ]
end

to sexear
  let sexoc sexo
  let metaP metabolism
  let visionP vision
  let bnacio false
  let dotacionP dotacion
  let bvacio false
  let metaM 0
  let visionM 0
  let dotacionM 0
  let vecindario turtles-on neighbors4
  if count vecindario > 0 [
    ask vecindario [
      set metaM metabolism
      set visionM vision
      set dotacionM dotacion
      repeat 4 [
        if (sexoc != sexo) and (edad >= fertilidadc) and (edad <= fertilidadf) and (sugar >= dotacion) and (not any? turtles-on patch-ahead 1) [
          parir metaP visionP metaM visionM dotacionP dotacionM
          set sugar sugar - (dotacionM / 2)
          set bnacio true
        ]
        set heading heading + 90
      ]
      if (sexoc != sexo) and (edad >= fertilidadc) and (edad <= fertilidadf) and (sugar >= dotacion) and (bnacio = false) [
        set bvacio true
      ]
    ]
    if bvacio = true [
      repeat 4 [
        if not any? turtles-on patch-ahead 1 [
          parir metaP visionP metaM visionM dotacionP dotacionM
          set bnacio true
        ]
        set heading heading + 90
      ]
    ]
  ]
  if bnacio = true [
    set sugar sugar - (dotacionP / 2)
  ]
end

to turtle-move
  let move-candidates (patch-set patch-here (patches at-points vision-points) with [not any? turtles-here])
  let possible-winners move-candidates with-max [psugar]
  if any? possible-winners [
    move-to min-one-of possible-winners [distance myself]
  ]
end

to turtle-eat
  set sugar (sugar - metabolism + psugar)
  set psugar 0
end

to patch-recolor
  set pcolor (yellow + 4.9 - psugar)
end

to patch-growback
  if psugar < max-psugar [set psugar psugar + 1]
end

to-report random-in-range [low high]
  report low + random (high - low + 1)
end

to no-visualization
  set color red
end

to color-agents-by-vision
  set color red - (vision - 3.5)
end

to color-agents-by-metabolism
  set color red + (metabolism - 2.5)
end

to color-agents-by-culture
  set color red
end
"""
