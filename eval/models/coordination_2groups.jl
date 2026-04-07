# ── Coordination 2 Groups model (modsoc) ───────────────────────────────

struct Coordination2GroupsModel <: AbstractBenchmarkModel end

model_name(::Coordination2GroupsModel) = "Coordination 2 Groups"
n_ticks(::Coordination2GroupsModel) = 200
tracked_globals(::Coordination2GroupsModel) = ["n-norm1"]
world_dims(::Coordination2GroupsModel) = (-16, 16, -16, 16)

function netlogo_code(::Coordination2GroupsModel)
"""
globals [randomSeed norm1-prosocial-benefit norm1-coord-benefit norm1-rarity-cost init-norm1-groupA init-norm1-groupB prob-outgroup-observation n-norm1]
turtles-own [norm1? groupID payoff]

to setup
  clear-all
  set norm1-prosocial-benefit 8
  set norm1-coord-benefit 1
  set norm1-rarity-cost 0.5
  set init-norm1-groupA 0.8
  set init-norm1-groupB 0.22
  set prob-outgroup-observation 0.018
  color-patches
  setup-turtles
  recolor
  set n-norm1 count turtles with [norm1?]
  reset-ticks
end

to color-patches
  ask patches [
    if pxcor < max-pxcor / 2 [set pcolor 0]
    if pxcor > max-pxcor / 2 [set pcolor 1]
    if pxcor = max-pxcor / 2 [set pcolor gray]
  ]
end

to setup-turtles
  ask patches with [pcolor = 0 or pcolor = 1] [
    sprout 1 [set payoff 0 set norm1? false]
  ]
  ask turtles with [pcolor = 0] [
    set groupID 0
    set shape "circle"
    if (random-float 1 < init-norm1-groupA) [set norm1? true]
  ]
  ask turtles with [pcolor = 1] [
    set groupID 1
    set shape "square"
    if (random-float 1 < init-norm1-groupB) [set norm1? true]
  ]
end

to recolor
  ask turtles [
    ifelse norm1? [set color yellow] [set color blue]
  ]
end

to go
  if (count turtles with [norm1?]) = (count turtles) [stop]
  calculate-payoffs
  evolve
  recolor
  set n-norm1 count turtles with [norm1?]
  tick
end

to calculate-payoffs
  let num-agents (count turtles) / 2
  let p1-0 (count turtles with [groupID = 0 and norm1?]) / num-agents
  let norm1-payoff-0 ((p1-0 * (1 + norm1-prosocial-benefit + norm1-coord-benefit)) + ((1 - p1-0) * (1 - norm1-rarity-cost)))
  let norm2-payoff-0 (p1-0 * (1 + norm1-prosocial-benefit) + (1 - p1-0) * 1)
  ask turtles with [groupID = 0 and norm1?] [set payoff norm1-payoff-0]
  ask turtles with [groupID = 0 and not norm1?] [set payoff norm2-payoff-0]
  let p1-1 (count turtles with [groupID = 1 and norm1?]) / num-agents
  let norm1-payoff-1 ((p1-1 * (1 + norm1-prosocial-benefit + norm1-coord-benefit)) + ((1 - p1-1) * (1 - norm1-rarity-cost)))
  let norm2-payoff-1 (p1-1 * (1 + norm1-prosocial-benefit) + (1 - p1-1) * 1)
  ask turtles with [groupID = 1 and norm1?] [set payoff norm1-payoff-1]
  ask turtles with [groupID = 1 and not norm1?] [set payoff norm2-payoff-1]
end

to evolve
  ask turtles [
    let myID groupID
    let otherID groupID
    if random-float 1 < prob-outgroup-observation
      [set otherID ((myID + 1) mod 2)]
    let model one-of other turtles with [groupID = otherID]
    let other-payoff [payoff] of model
    let prob-copy (1 / (1 + exp (-1 * (other-payoff - payoff))))
    if random-float 1 < prob-copy
      [set norm1? [norm1?] of model]
  ]
end

to-report frequency-norm1
  report (count turtles with [norm1?]) / (count turtles)
end

to-report freq-norm1-groupA
  report (count turtles with [norm1? and groupID = 0]) / (count turtles with [groupID = 0])
end

to-report freq-norm1-groupB
  report (count turtles with [norm1? and groupID = 1]) / (count turtles with [groupID = 1])
end
"""
end
