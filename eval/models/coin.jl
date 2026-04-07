# ── COIN (Collective Intelligence) ─────────────────────────────────
# Adapted from netlogomas/coin by Jose M. Vidal

struct CoinModel <: AbstractBenchmarkModel end

model_name(::CoinModel) = "COIN Learning"
n_ticks(::CoinModel) = 200
tracked_globals(::CoinModel) = ["current-utility"]

function netlogo_code(::CoinModel)
"""
globals [actions attendance randomSeed num-agents num-nights discount-rate reward-function current-utility]

breed [players player]
players-own [utility-vector last-action]

to-report add-vectors [v1 v2]
  report (map [[a b] -> a + b] v1 v2)
end

to-report subtract-vectors [v1 v2]
  report (map [[a b] -> a - b] v1 v2)
end

to-report global-utility [att]
  report sum (map [[x] -> x * exp ((0 - x) / (item (num-nights - 1) (list 3 6 8 10 12 15)))] att)
end

to setup
  clear-all
  set num-agents 63
  set num-nights 1
  set discount-rate 0.98
  set reward-function "aristocratic"
  set current-utility 0
  create-players num-agents [
    hide-turtle
    setxy 0 who
    set utility-vector n-values 7 [100]
  ]
  set actions []
  foreach n-values 7 [i -> i] [sd ->
    let start-day sd
    let action n-values 7 [0]
    repeat num-nights [
      set action replace-item start-day action 1
      set start-day (start-day + 1) mod 7
    ]
    set actions lput action actions
  ]
  repeat 100 [
    ask players [take-random-action]
    set attendance reduce [[a b] -> add-vectors a b] [last-action] of players
    ask players [learn]
  ]
  set current-utility global-utility attendance
  reset-ticks
end

to go
  ask players [take-action]
  set attendance reduce [[a b] -> add-vectors a b] [last-action] of players
  ask players [learn]
  set current-utility global-utility attendance
  tick
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

to-report boltzmann-choice [v]
  report stochastic-choice (map [[x] -> exp (x / 3)] v)
end

to take-action
  set last-action item (stochastic-choice utility-vector) actions
end

to take-random-action
  set last-action item (random length actions) actions
end

to-report get-reward
  if (reward-function = "wonderful-life-0") [
    report 1 + (global-utility attendance) - (global-utility (subtract-vectors attendance last-action))
  ]
  if (reward-function = "wonderful-life-1") [
    report 1 + (global-utility attendance) - global-utility (add-vectors (subtract-vectors attendance last-action) (list 1 1 1 1 1 1 1))
  ]
  if (reward-function = "aristocratic") [
    report 1 + (global-utility attendance) - global-utility (add-vectors (subtract-vectors attendance last-action) n-values 7 [1 / 7])
  ]
  report 0
end

to learn
  set utility-vector (map [[x] -> x * discount-rate] utility-vector)
  let idx position last-action actions
  let reward get-reward
  set utility-vector replace-item idx utility-vector ((item idx utility-vector) + reward)
end
"""
end
