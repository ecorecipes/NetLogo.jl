# ── Bayesian Updating model (modsoc) ───────────────────────────────────

struct BayesianModel <: AbstractBenchmarkModel end

model_name(::BayesianModel) = "Bayesian Updating"
n_ticks(::BayesianModel) = 200
tracked_globals(::BayesianModel) = ["prob-true"]
world_dims(::BayesianModel) = (-5, 5, -5, 5)

function netlogo_code(::BayesianModel)
"""
globals [randomSeed initial-prior false-positive-rate power true-hypothesis? prob-true]

to setup
  clear-all
  set initial-prior 0.1
  set false-positive-rate 0.05
  set power 0.5
  set true-hypothesis? false
  set prob-true initial-prior
  ifelse true-hypothesis?
    [ask patches [set pcolor green]]
    [ask patches [set pcolor red]]
  reset-ticks
end

to go
  ifelse true-hypothesis? [
    ifelse random-float 1 < power [
      ask patches [set pcolor green]
      set prob-true (power * prob-true) / ((power * prob-true) + (false-positive-rate * (1 - prob-true)))
    ] [
      ask patches [set pcolor red]
      set prob-true ((1 - power) * prob-true) / (((1 - power) * prob-true) + ((1 - false-positive-rate) * (1 - prob-true)))
    ]
  ] [
    ifelse random-float 1 < false-positive-rate [
      ask patches [set pcolor green]
      set prob-true (power * prob-true) / ((power * prob-true) + (false-positive-rate * (1 - prob-true)))
    ] [
      ask patches [set pcolor red]
      set prob-true ((1 - power) * prob-true) / (((1 - power) * prob-true) + ((1 - false-positive-rate) * (1 - prob-true)))
    ]
  ]
  tick
end
"""
end
