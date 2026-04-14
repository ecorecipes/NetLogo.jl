# ── Slime model (NetLogo models library) ─────────────────────────────

struct SlimeModel <: AbstractBenchmarkModel end

model_name(::SlimeModel) = "Slime"
n_ticks(::SlimeModel) = 200
tracked_globals(::SlimeModel) = ["total-chemical", "max-chemical", "mean-chemical"]
world_dims(::SlimeModel) = (-40, 40, -40, 40)

function netlogo_code(::SlimeModel)
"""
globals [randomSeed population sniff-threshold sniff-angle
         wiggle-angle wiggle-bias evaporation-rate diffusion-rate deposit-amount
         total-chemical max-chemical mean-chemical]

patches-own [chemical]

to setup
  clear-all
  resize-world (- 40) 40 (- 40) 40
  set population 400
  set sniff-threshold 1.0
  set sniff-angle 45
  set wiggle-angle 40
  set wiggle-bias 0
  set evaporation-rate 0.9
  set diffusion-rate 1.0
  set deposit-amount 2.0
  crt population [
    set color red
    set size 2
    setxy random-xcor random-ycor
  ]
  ask patches [ set chemical 0 ]
  update-globals
  reset-ticks
end

to go
  ask turtles [
    if chemical > sniff-threshold [
      turn-toward-chemical
    ]
    rt random-float wiggle-angle - random-float wiggle-angle + wiggle-bias
    fd 1
    set chemical chemical + deposit-amount
  ]
  diffuse chemical diffusion-rate
  ask patches [
    set chemical chemical * evaporation-rate
    set pcolor scale-color green chemical 0.1 3
  ]
  update-globals
  tick
end

to update-globals
  set total-chemical sum [chemical] of patches
  set max-chemical max [chemical] of patches
  set mean-chemical mean [chemical] of patches
end

to turn-toward-chemical
  let ahead [chemical] of patch-ahead 1
  let myright [chemical] of patch-right-and-ahead sniff-angle 1
  let myleft [chemical] of patch-left-and-ahead sniff-angle 1
  ifelse (myright >= ahead) and (myright >= myleft) [
    rt sniff-angle
  ] [
    if myleft >= ahead [
      lt sniff-angle
    ]
  ]
end
"""
end
