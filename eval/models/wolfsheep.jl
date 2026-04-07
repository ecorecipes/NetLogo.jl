# ── Wolf Sheep Predation model ────────────────────────────────────────

struct WolfSheepModel <: AbstractBenchmarkModel end

model_name(::WolfSheepModel) = "Wolf Sheep Predation"
n_ticks(::WolfSheepModel) = 200
tracked_globals(::WolfSheepModel) = ["num-wolves", "num-sheep", "num-grass"]

function netlogo_code(::WolfSheepModel)
"""
globals [num-wolves num-sheep num-grass]
breed [wolves wolf]
breed [sheep a-sheep]
turtles-own [energy]
patches-own [countdown]

to setup
  clear-all
  ask patches [
    set countdown random 20
    ifelse countdown <= 0 [
      set pcolor green
    ] [
      set pcolor brown
    ]
  ]
  create-sheep 100 [
    setxy random-xcor random-ycor
    set color white
    set energy random 10
    set shape "circle"
    set size 0.5
  ]
  create-wolves 50 [
    setxy random-xcor random-ycor
    set color black
    set energy random 10
    set shape "circle"
    set size 0.5
  ]
  update-counts
  reset-ticks
end

to go
  if not any? turtles [ stop ]
  ask sheep [
    move
    set energy energy - 1
    eat-grass
    maybe-reproduce 4
    if energy <= 0 [ die ]
  ]
  ask wolves [
    move
    set energy energy - 1
    eat-sheep
    maybe-reproduce 5
    if energy <= 0 [ die ]
  ]
  ask patches [ grow-grass ]
  update-counts
  tick
end

to move
  rt random 50 - 25
  fd 1
end

to eat-grass
  if [pcolor] of patch-here = green [
    set energy energy + 4
    ask patch-here [
      set pcolor brown
      set countdown 20
    ]
  ]
end

to eat-sheep
  let prey one-of sheep-here
  if prey != nobody [
    ask prey [ die ]
    set energy energy + 20
  ]
end

to maybe-reproduce [threshold]
  if random 100 < threshold [
    set energy energy / 2
    hatch 1 [
      rt random 360
      fd 1
    ]
  ]
end

to grow-grass
  if pcolor = brown [
    set countdown countdown - 1
    if countdown <= 0 [
      set pcolor green
    ]
  ]
end

to update-counts
  set num-wolves count wolves
  set num-sheep count sheep
  set num-grass count patches with [pcolor = green]
end
"""
end
