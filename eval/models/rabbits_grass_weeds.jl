# ── Rabbits Grass Weeds model (NetLogo models library) ───────────────

struct RabbitsGrassWeedsModel <: AbstractBenchmarkModel end

model_name(::RabbitsGrassWeedsModel) = "Rabbits Grass Weeds"
n_ticks(::RabbitsGrassWeedsModel) = 200
tracked_globals(::RabbitsGrassWeedsModel) = ["num-rabbits", "num-grass", "num-weeds"]
world_dims(::RabbitsGrassWeedsModel) = (-20, 20, -20, 20)

function netlogo_code(::RabbitsGrassWeedsModel)
"""
globals [randomSeed number birth-threshold grass-grow-rate weeds-grow-rate
         grass-energy weed-energy
         num-rabbits num-grass num-weeds]

breed [rabbits rabbit]
rabbits-own [energy]

to setup
  clear-all
  random-seed randomSeed
  resize-world (- 20) 20 (- 20) 20
  set number 150
  set birth-threshold 15
  set grass-grow-rate 15
  set weeds-grow-rate 0
  set grass-energy 5
  set weed-energy 0
  grow-grass-and-weeds
  set-default-shape rabbits "rabbit"
  create-rabbits number [
    set color white
    setxy random-xcor random-ycor
    set energy random 10
  ]
  update-globals
  reset-ticks
end

to go
  if not any? rabbits [ stop ]
  grow-grass-and-weeds
  ask rabbits [
    move
    eat-grass
    eat-weeds
    reproduce
    death
  ]
  update-globals
  tick
end

to update-globals
  set num-rabbits count rabbits
  set num-grass count patches with [pcolor = green]
  set num-weeds count patches with [pcolor = violet]
end

to grow-grass-and-weeds
  ask patches [
    if pcolor = black [
      if random-float 1000 < weeds-grow-rate [
        set pcolor violet
      ]
      if random-float 1000 < grass-grow-rate [
        set pcolor green
      ]
    ]
  ]
end

to move
  rt random 50
  lt random 50
  fd 1
  set energy energy - 0.5
end

to eat-grass
  if pcolor = green [
    set pcolor black
    set energy energy + grass-energy
  ]
end

to eat-weeds
  if pcolor = violet [
    set pcolor black
    set energy energy + weed-energy
  ]
end

to reproduce
  if energy > birth-threshold [
    set energy energy / 2
    hatch 1 [ fd 1 ]
  ]
end

to death
  if energy < 0 [ die ]
end
"""
end
