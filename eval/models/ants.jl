# ── Ants model (NetLogo models library) ──────────────────────────────

struct AntsModel <: AbstractBenchmarkModel end

model_name(::AntsModel) = "Ants"
n_ticks(::AntsModel) = 200
tracked_globals(::AntsModel) = ["total-food"]
world_dims(::AntsModel) = (-35, 35, -35, 35)

function netlogo_code(::AntsModel)
"""
globals [randomSeed diffusion-rate evaporation-rate population total-food]

patches-own [chemical food nest? nest-scent food-source-number]

to setup
  clear-all
  resize-world (- 35) 35 (- 35) 35
  set diffusion-rate 50
  set evaporation-rate 10
  set population 125
  set-default-shape turtles "bug"
  create-turtles population [
    set size 2
    set color red
  ]
  setup-patches
  set total-food sum [food] of patches
  reset-ticks
end

to setup-patches
  ask patches [
    setup-nest
    setup-food
    recolor-patch
  ]
end

to setup-nest
  set nest? (distancexy 0 0) < 5
  set nest-scent 200 - distancexy 0 0
end

to setup-food
  if (distancexy (0.6 * max-pxcor) 0) < 5
    [ set food-source-number 1 ]
  if (distancexy (-0.6 * max-pxcor) (-0.6 * max-pycor)) < 5
    [ set food-source-number 2 ]
  if (distancexy (-0.8 * max-pxcor) (0.8 * max-pycor)) < 5
    [ set food-source-number 3 ]
  if food-source-number > 0
    [ set food one-of [1 2] ]
end

to recolor-patch
  ifelse nest?
    [ set pcolor violet ]
    [ ifelse food > 0
      [ if food-source-number = 1 [ set pcolor cyan ]
        if food-source-number = 2 [ set pcolor sky  ]
        if food-source-number = 3 [ set pcolor blue ] ]
      [ set pcolor scale-color green chemical 0.1 5 ] ]
end

to go
  ask turtles [
    if who >= ticks [ stop ]
    ifelse color = red
      [ look-for-food ]
      [ return-to-nest ]
    wiggle
    fd 1
  ]
  diffuse chemical (diffusion-rate / 100)
  ask patches [
    set chemical chemical * (100 - evaporation-rate) / 100
    recolor-patch
  ]
  set total-food sum [food] of patches
  tick
end

to return-to-nest
  ifelse nest?
    [ set color red
      rt 180 ]
    [ set chemical chemical + 60
      uphill-nest-scent ]
end

to look-for-food
  if food > 0 [
    set color orange + 1
    set food food - 1
    rt 180
    stop
  ]
  if (chemical >= 0.05) and (chemical < 2)
    [ uphill-chemical ]
end

to uphill-chemical
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead) [
    ifelse scent-right > scent-left
      [ rt 45 ]
      [ lt 45 ]
  ]
end

to uphill-nest-scent
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead) [
    ifelse scent-right > scent-left
      [ rt 45 ]
      [ lt 45 ]
  ]
end

to wiggle
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical] of p
end
"""
end
