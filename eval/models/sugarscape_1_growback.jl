# ── Sugarscape 1 Immediate Growback model ────────────────────────────

struct Sugarscape1GrowbackModel <: AbstractBenchmarkModel end

model_name(::Sugarscape1GrowbackModel) = "Sugarscape 1 Growback"
n_ticks(::Sugarscape1GrowbackModel) = 200
tracked_globals(::Sugarscape1GrowbackModel) = ["population", "mean-sugar", "max-sugar", "min-sugar"]
world_dims(::Sugarscape1GrowbackModel) = (0, 49, 0, 49)

function netlogo_code(::Sugarscape1GrowbackModel)
"""
globals [randomSeed initial-population
         population mean-sugar max-sugar min-sugar]

turtles-own [
  sugar
  metabolism
  vision
  vision-points
]

patches-own [
  psugar
  max-psugar
]

to setup
  clear-all
  resize-world 0 49 0 49
  set initial-population 400
  setup-patches
  create-turtles initial-population [ turtle-setup ]
  update-globals
  reset-ticks
end

to turtle-setup
  set color red
  set shape "circle"
  move-to one-of patches with [not any? other turtles-here]
  set sugar random-in-range 5 25
  set metabolism random-in-range 1 4
  set vision random-in-range 1 6
  set vision-points []
  foreach n-values vision [i -> i + 1] [d ->
    set vision-points sentence vision-points
      (list (list 0 d) (list d 0) (list 0 (- d)) (list (- d) 0))
  ]
end

to setup-patches
  ask patches [
    let d1 distancexy 35 35
    let d2 distancexy 15 15
    let d min list d1 d2
    set max-psugar 0
    if d <= 20 [set max-psugar 1]
    if d <= 15 [set max-psugar 2]
    if d <= 10 [set max-psugar 3]
    if d <= 5  [set max-psugar 4]
    set psugar max-psugar
    patch-recolor
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
  ]
  update-globals
  tick
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
  set psugar max-psugar
end

to-report random-in-range [low high]
  report low + random (high - low + 1)
end

to update-globals
  ifelse any? turtles [
    set population count turtles
    set mean-sugar mean [sugar] of turtles
    set max-sugar max [sugar] of turtles
    set min-sugar min [sugar] of turtles
  ] [
    set population 0
    set mean-sugar 0
    set max-sugar 0
    set min-sugar 0
  ]
end
"""
end
