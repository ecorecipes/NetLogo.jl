# ── Shepherds model (NetLogo models library) ─────────────────────────

struct ShepherdsModel <: AbstractBenchmarkModel end

model_name(::ShepherdsModel) = "Shepherds"
n_ticks(::ShepherdsModel) = 200
tracked_globals(::ShepherdsModel) = ["herding-efficiency", "num-sheep-visible"]
world_dims(::ShepherdsModel) = (-25, 25, -25, 25)

function netlogo_code(::ShepherdsModel)
"""
breed [sheep a-sheep]
breed [shepherds shepherd]

globals
[
  randomSeed
  num-sheep
  num-shepherds
  sheep-speed
  sheepless-neighborhoods
  herding-efficiency
  num-sheep-visible
]

patches-own
[
  sheep-nearby
]

shepherds-own
[
  carried-sheep
  found-herd?
]

to setup
  clear-all
  resize-world (- 25) 25 (- 25) 25
  set num-sheep 150
  set num-shepherds 30
  set sheep-speed 0.02
  set-default-shape sheep "default"
  set-default-shape shepherds "person"
  ask patches
    [ set pcolor green + (random-float 0.8) - 0.4 ]
  create-sheep num-sheep
    [ set color white
      set size 1.5
      setxy random-xcor random-ycor ]
  create-shepherds num-shepherds
    [ set color brown
      set size 1.5
      set carried-sheep nobody
      set found-herd? false
      setxy random-xcor random-ycor ]
  update-tracked-globals
  reset-ticks
end

to go
  ask shepherds
  [ ifelse carried-sheep = nobody
      [ search-for-sheep ]
    [ ifelse found-herd?
        [ find-empty-spot ]
      [ find-new-herd ] ]
    wiggle
    fd 1
    if carried-sheep != nobody
    [ ask carried-sheep [ move-to myself ] ] ]
  ask sheep with [not hidden?]
  [ wiggle
    fd sheep-speed ]
  update-tracked-globals
  tick
end

to wiggle
  rt random 50 - random 50
end

to search-for-sheep
  set carried-sheep one-of sheep-here with [not hidden?]
  if (carried-sheep != nobody)
    [ ask carried-sheep
        [ ht ]
      set color blue
      fd 1 ]
end

to find-new-herd
  if any? sheep-here with [not hidden?]
    [ set found-herd? true ]
end

to find-empty-spot
  if all? sheep-here [hidden?]
    [ ask carried-sheep
        [ st ]
      set color brown
      set carried-sheep nobody
      set found-herd? false
      rt random 360
      fd 20 ]
end

to update-tracked-globals
  ask patches
    [ set sheep-nearby (sum [count sheep-here] of neighbors) ]
  set sheepless-neighborhoods (count patches with [sheep-nearby = 0])
  let visible-sheep sheep with [not hidden?]
  ifelse any? visible-sheep [
    ;; herding efficiency: largest cluster / total visible sheep * 100
    ;; We approximate cluster size by finding max sheep-nearby + sheep on that patch
    let non-empty-patches patches with [any? visible-sheep-here]
    ifelse any? non-empty-patches [
      set herding-efficiency (sheepless-neighborhoods / (count patches with [not any? visible-sheep-here])) * 100
    ][
      set herding-efficiency 0
    ]
    set num-sheep-visible count visible-sheep
  ][
    set herding-efficiency 0
    set num-sheep-visible 0
  ]
end

to-report visible-sheep-here
  report sheep-here with [not hidden?]
end
"""
end
