# ── Prisoner's Dilemma Simple model (modsoc) ──────────────────────────

struct PDSimpleModel <: AbstractBenchmarkModel end

model_name(::PDSimpleModel) = "PD Simple"
n_ticks(::PDSimpleModel) = 100
tracked_globals(::PDSimpleModel) = ["n-cooperators"]
world_dims(::PDSimpleModel) = (-16, 16, -16, 16)

function netlogo_code(::PDSimpleModel)
"""
globals [randomSeed init-coop-freq payoff-benefit payoff-cost n-cooperators]
turtles-own [strategy payoff]

to setup
  clear-all
  set init-coop-freq 0.5
  set payoff-benefit 1
  set payoff-cost 0.1
  make-agents
  recolor
  set n-cooperators count turtles with [strategy = 1]
  reset-ticks
end

to make-agents
  ask patches [
    sprout 1 [
      ifelse random-float 1 < init-coop-freq [set strategy 1] [set strategy 0]
      set shape "circle"
      set payoff 0
    ]
  ]
end

to recolor
  ask turtles [
    if strategy = 0 [set color red]
    if strategy = 1 [set color blue]
  ]
end

to go
  if (all? turtles [strategy = 0] or all? turtles [strategy = 1]) [stop]
  play-game
  evolve
  recolor
  set n-cooperators count turtles with [strategy = 1]
  tick
end

to play-game
  ask turtles [
    set payoff 0
    let neighbors-C count (turtles-on neighbors4) with [strategy = 1]
    let neighbors-D count (turtles-on neighbors4) with [strategy = 0]
    if (strategy = 1)
      [set payoff (neighbors-C * (payoff-benefit - payoff-cost) - neighbors-D * payoff-cost)]
    if (strategy = 0)
      [set payoff (neighbors-C * payoff-benefit)]
  ]
end

to evolve
  ask turtles [
    let best-neighbor max-one-of (turtles-on neighbors4) [payoff]
    if ([payoff] of best-neighbor) > payoff
      [set strategy [strategy] of best-neighbor]
  ]
end
"""
end
