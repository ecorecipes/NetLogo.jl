# ── Erosion model (NetLogo models library) ──────────────────────────

struct ErosionModel <: AbstractBenchmarkModel end

model_name(::ErosionModel) = "Erosion"
n_ticks(::ErosionModel) = 200
tracked_globals(::ErosionModel) = ["mean-elevation", "total-water"]
world_dims(::ErosionModel) = (-25, 25, -25, 25)
topology(::ErosionModel) = (false, false)  # bounded — drains need `count neighbors != 8`

function netlogo_code(::ErosionModel)
"""
globals [randomSeed show-water? drains land
         bumpy? hill? terrain-smoothness rainfall soil-hardness
         mean-elevation total-water]

patches-own [elevation water drain?]

to setup
  clear-all
  resize-world (- 25) 25 (- 25) 25
  set show-water? true
  set bumpy? true
  set hill? false
  set terrain-smoothness 6
  set rainfall 0.1
  set soil-hardness 0.8
  ask patches [
    ifelse bumpy?
      [ ifelse hill?
          [ set elevation -100 * (distancexy 0 0 / max-pxcor) + 100 + random 100 ]
          [ set elevation random 125 ] ]
      [ set elevation 100 ]
    set water 0
    set drain? false
  ]
  if bumpy? [
    repeat terrain-smoothness [ diffuse elevation 0.5 ]
  ]
  ask patches with [count neighbors != 8]
    [ set drain? true
      set elevation -10000000 ]
  set drains patches with [drain?]
  set land patches with [not drain?]
  ask land [ recolor ]
  update-globals
  reset-ticks
end

to recolor
  ifelse water = 0 or not show-water?
    [ set pcolor scale-color white elevation -250 100 ]
    [ set pcolor scale-color blue (min list water 75) 100 -10 ]
end

to go
  ask land [
    if random-float 1.0 < rainfall [
      set water water + 1
    ]
  ]
  ask land [ if water > 0 [ flow ] ]
  ask drains [
    set water 0
    set elevation -10000000
  ]
  ask land [ recolor ]
  update-globals
  tick
end

to flow
  let target min-one-of neighbors [elevation + water]
  let amount min list water (0.5 * (elevation + water - [elevation] of target - [water] of target))
  if amount > 0 [
    let erosion amount * (1 - soil-hardness)
    set elevation elevation - erosion
    set amount min list water (0.5 * (elevation + water - [elevation] of target - [water] of target))
    set water water - amount
    ask target [ set water water + amount ]
  ]
end

to update-globals
  set mean-elevation mean [elevation] of land
  set total-water sum [water] of land
end
"""
end
