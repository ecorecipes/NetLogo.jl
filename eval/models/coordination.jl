# ── Coordination model (modsoc) ────────────────────────────────────────

struct CoordinationModel <: AbstractBenchmarkModel end

model_name(::CoordinationModel) = "Coordination"
n_ticks(::CoordinationModel) = 200
tracked_globals(::CoordinationModel) = ["n-norm1"]
world_dims(::CoordinationModel) = (-16, 16, -16, 16)

function netlogo_code(::CoordinationModel)
"""
globals [randomSeed init-norm1 coordination-benefit n-norm1]
turtles-own [norm1? payoff]

to setup
  clear-all
  set init-norm1 0.5
  set coordination-benefit 1
  ask patches [
    sprout 1 [
      set shape "circle"
      ifelse random-float 1 < init-norm1 [set norm1? true] [set norm1? false]
    ]
  ]
  recolor
  set n-norm1 count turtles with [norm1?]
  reset-ticks
end

to go
  if (count turtles with [norm1?]) = (count turtles) or
     (count turtles with [norm1?]) = 0
    [stop]
  calculate-payoffs
  evolve
  recolor
  set n-norm1 count turtles with [norm1?]
  tick
end

to calculate-payoffs
  let p1 (count turtles with [norm1?]) / (count turtles)
  let norm1-payoff 1 + (p1 * coordination-benefit)
  let norm2-payoff 1 + ((1 - p1) * coordination-benefit)
  ask turtles with [norm1?] [set payoff norm1-payoff]
  ask turtles with [not norm1?] [set payoff norm2-payoff]
end

to evolve
  ask turtles [
    let model one-of other turtles
    if [norm1?] of model != [norm1?] of self [
      let other-payoff [payoff] of model
      let prob-copy (1 / (1 + exp (-1 * (other-payoff - payoff))))
      if random-float 1 < prob-copy
        [set norm1? [norm1?] of model]
    ]
  ]
end

to recolor
  ask turtles [
    ifelse norm1? [set color yellow] [set color blue]
  ]
end

to-report freq-norm1
  report (count turtles with [norm1?]) / (count turtles)
end
"""
end
