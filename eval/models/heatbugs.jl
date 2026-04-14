# ── Heatbugs model (NetLogo models library) ──────────────────────────

struct HeatbugsModel <: AbstractBenchmarkModel end

model_name(::HeatbugsModel) = "Heatbugs"
n_ticks(::HeatbugsModel) = 200
tracked_globals(::HeatbugsModel) = ["mean-unhappiness", "max-unhappiness"]
world_dims(::HeatbugsModel) = (0, 99, 0, 99)

function netlogo_code(::HeatbugsModel)
"""
globals [randomSeed bug-count min-ideal-temp max-ideal-temp min-output-heat max-output-heat
         evaporation-rate diffusion-rate random-move-chance
         color-by-unhappiness?
         mean-unhappiness max-unhappiness]

turtles-own
[
  ideal-temp
  output-heat
  unhappiness
]

patches-own
[
  temp
]

to setup
  clear-all
  resize-world 0 99 0 99
  set bug-count 100
  set min-ideal-temp 10
  set max-ideal-temp 40
  set min-output-heat 5
  set max-output-heat 25
  set evaporation-rate 0.01
  set diffusion-rate 0.9
  set random-move-chance 0
  set color-by-unhappiness? false

  ask n-of bug-count patches [
    sprout 1 [
      set ideal-temp  min-ideal-temp  + random (max-ideal-temp  - min-ideal-temp)
      set output-heat min-output-heat + random (max-output-heat - min-output-heat)
      set unhappiness abs (ideal-temp - temp)
      set color scale-color lime ideal-temp ( min-ideal-temp - ( max-ideal-temp - min-ideal-temp ) / 2 )
                                             ( max-ideal-temp + ( max-ideal-temp - min-ideal-temp ) / 2 )
      face one-of neighbors
      set size 2
    ]
  ]
  update-tracked-globals
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  diffuse temp diffusion-rate
  ask patches [ set temp temp * (1 - evaporation-rate) ]
  ask turtles [ step ]
  recolor-patches
  update-tracked-globals
  tick
end

to step
  set unhappiness abs (ideal-temp - temp)
  if unhappiness > 0
    [ ifelse random-float 100 < random-move-chance
        [ bug-move one-of neighbors ]
        [ bug-move best-patch ] ]
  set temp temp + output-heat
end

to-report best-patch
  ifelse temp < ideal-temp
    [ let winner max-one-of neighbors [temp]
      ifelse [temp] of winner > temp
        [ report winner ]
        [ report patch-here ] ]
    [ let winner min-one-of neighbors [temp]
      ifelse [temp] of winner < temp
        [ report winner ]
        [ report patch-here ] ]
end

to bug-move [target]
  if target = patch-here [ stop ]
  if not any? turtles-on target [
    face target
    move-to target
    stop
  ]
  set target one-of neighbors with [not any? turtles-here]
  if target != nobody [ move-to target ]
end

to recolor-patches
  ask patches [ set pcolor scale-color red temp 0 150 ]
end

to update-tracked-globals
  ifelse any? turtles [
    set mean-unhappiness mean [unhappiness] of turtles
    set max-unhappiness max [unhappiness] of turtles
  ][
    set mean-unhappiness 0
    set max-unhappiness 0
  ]
end
"""
end
