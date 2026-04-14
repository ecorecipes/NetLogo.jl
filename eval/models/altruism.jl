# ── Altruism model (NetLogo models library) ──────────────────────────

struct AltruismModel <: AbstractBenchmarkModel end

model_name(::AltruismModel) = "Altruism"
n_ticks(::AltruismModel) = 200
tracked_globals(::AltruismModel) = ["num-altruists", "num-selfish", "num-harsh"]
world_dims(::AltruismModel) = (-20, 20, -20, 20)

function netlogo_code(::AltruismModel)
"""
globals [randomSeed altruistic-probability selfish-probability
         benefit-from-altruism cost-of-altruism disease harshness
         num-altruists num-selfish num-harsh]

patches-own [
  benefit-out
  altruism-benefit
  fitness
  self-weight self-fitness
  alt-weight alt-fitness
  harsh-weight harsh-fitness
]

to setup
  clear-all
  resize-world (- 20) 20 (- 20) 20
  set altruistic-probability 0.26
  set selfish-probability 0.26
  set benefit-from-altruism 0.48
  set cost-of-altruism 0.13
  set disease 0
  set harshness 0
  ask patches [ initialize ]
  update-globals
  reset-ticks
end

to initialize
  let ptype random-float 1.0
  ifelse (ptype < altruistic-probability) [
    set benefit-out 1
    set pcolor pink
  ] [
    set benefit-out 0
    ifelse (ptype < altruistic-probability + selfish-probability) [
      set pcolor green
    ] [
      set pcolor black
    ]
  ]
end

to go
  if all? patches [pcolor != pink and pcolor != green] [ stop ]
  ask patches [
    set altruism-benefit benefit-from-altruism * (benefit-out + sum [benefit-out] of neighbors4) / 5
  ]
  ask patches [
    perform-fitness-check
  ]
  lottery
  update-globals
  tick
end

to update-globals
  set num-altruists count patches with [pcolor = pink]
  set num-selfish count patches with [pcolor = green]
  set num-harsh count patches with [pcolor = black]
end

to perform-fitness-check
  if (pcolor = green) [
    set fitness (1 + altruism-benefit)
  ]
  if (pcolor = pink) [
    set fitness ((1 - cost-of-altruism) + altruism-benefit)
  ]
  if (pcolor = black) [
    set fitness harshness
  ]
end

to lottery
  ask patches [ record-neighbor-fitness ]
  ask patches [ find-lottery-weights ]
  ask patches [ next-generation ]
end

to record-neighbor-fitness
  set alt-fitness 0
  set self-fitness 0
  set harsh-fitness 0
  if (pcolor = pink) [
    set alt-fitness fitness
  ]
  if (pcolor = green) [
    set self-fitness fitness
  ]
  if (pcolor = black) [
    set harsh-fitness fitness
  ]
  update-fitness-from-neighbor 1 0
  update-fitness-from-neighbor -1 0
  update-fitness-from-neighbor 0 1
  update-fitness-from-neighbor 0 -1
end

to update-fitness-from-neighbor [x y]
  let neighbor-color [pcolor] of patch-at x y
  let neighbor-fitness [fitness] of patch-at x y
  if (neighbor-color = pink) [
    set alt-fitness (alt-fitness + neighbor-fitness)
  ]
  if (neighbor-color = green) [
    set self-fitness (self-fitness + neighbor-fitness)
  ]
  if (neighbor-color = black) [
    set harsh-fitness (harsh-fitness + neighbor-fitness)
  ]
end

to find-lottery-weights
  let fitness-sum alt-fitness + self-fitness + harsh-fitness + disease
  ifelse (fitness-sum > 0) [
    set alt-weight (alt-fitness / fitness-sum)
    set self-weight (self-fitness / fitness-sum)
    set harsh-weight ((harsh-fitness + disease) / fitness-sum)
  ] [
    set alt-weight 0
    set self-weight 0
    set harsh-weight 0
  ]
end

to next-generation
  let breed-chance random-float 1.0
  ifelse (breed-chance < alt-weight) [
    set pcolor pink
    set benefit-out 1
  ] [
    ifelse (breed-chance < (alt-weight + self-weight)) [
      set pcolor green
      set benefit-out 0
    ] [
      clear-patch
    ]
  ]
end

to clear-patch
  set pcolor black
  set altruism-benefit 0
  set fitness 0
  set alt-weight 0
  set self-weight 0
  set harsh-weight 0
  set alt-fitness 0
  set self-fitness 0
  set harsh-fitness 0
end
"""
end
