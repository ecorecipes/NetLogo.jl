# ── Pareto Learning (2-agent Q-learning game) ──────────────────────
# Adapted from netlogomas/paretolearn by Jose M. Vidal

struct ParetoLearnModel <: AbstractBenchmarkModel end

model_name(::ParetoLearnModel) = "Pareto Learning"
n_ticks(::ParetoLearnModel) = 500
tracked_globals(::ParetoLearnModel) = ["eu-cooperate", "eu-defect"]

function netlogo_code(::ParetoLearnModel)
"""
globals [cooperate defect randomSeed exploration-rate eu-cooperate eu-defect]

breed [learners learner]

learners-own [n n-joint alpha epsilon action]

to-report utility [my-action his-action]
  report item his-action (item my-action payoffs-matrix)
end

to-report payoffs-matrix
  report (list (list 3 0) (list 5 1))
end

to setup
  clear-all
  set cooperate 0
  set defect 1
  set exploration-rate 0
  set eu-cooperate 0
  set eu-defect 0
  create-learners 2 [
    set heading 0
    set color gray
    set size 2
    set epsilon exploration-rate
    set n (list (list 1 1) (list 1 1))
  ]
  ask learner 0 [ set xcor (- 5) ]
  ask learner 1 [ set xcor 5 ]
  reset-ticks
end

to go
  ask learners [take-action]
  ask learners [adapt]
  ask learner 0 [
    set eu-cooperate get-expected-utility cooperate
    set eu-defect get-expected-utility defect
  ]
  tick
end

to-report nij [my-action his-action]
  report item my-action (item his-action n)
end

to-report ni [my-action]
  report (item my-action (item 0 n)) + (item my-action (item 1 n))
end

to update-count [my-action his-action]
  let c nij my-action his-action
  set n replace-item his-action n (replace-item my-action (item his-action n) (c + 1))
end

to-report get-expected-utility [my-action]
  report sum (map [[a] -> (utility my-action a) * ((nij my-action a) / (ni my-action))] (list 0 1))
end

to-report stochastic-choice [v]
  let r random-float sum v
  let idx 0
  let base-prob 0
  repeat length v [
    set base-prob base-prob + (item idx v)
    if (r <= base-prob) [ report idx ]
    set idx idx + 1
  ]
  report 0
end

to take-action
  ifelse (ticks < 400) [
    set action random 2
  ][
    let evector (map [[a] -> get-expected-utility a] (list 0 1))
    let best-action position (max evector) evector
    ifelse (random-float 1 < 1 - epsilon) [
      set action best-action
    ][
      set action (best-action + 1) mod 2
    ]
  ]
  ifelse (action = 0) [
    set color green
  ][
    set color red
  ]
end

to adapt
  let his-action (first [action] of other learners)
  update-count action his-action
end
"""
end
