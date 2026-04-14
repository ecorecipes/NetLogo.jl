# ── COIN (Collective Intelligence) ─────────────────────────────────
# Adapted from netlogomas/coin by Jose M. Vidal

struct CoinModel <: AbstractBenchmarkModel end

model_name(::CoinModel) = "COIN Learning"
n_ticks(::CoinModel) = 200
tracked_globals(::CoinModel) = ["current-utility"]

function netlogo_code(::CoinModel)
"""
globals [
  randomSeed
  num-agents
  discount-rate
  current-utility
  attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  reward0 reward1 reward2 reward3 reward4 reward5 reward6
]

breed [players player]
players-own [u0 u1 u2 u3 u4 u5 u6 last-action-idx]

to-report day-utility [x]
  report x * exp ((0 - x) / 3)
end

to-report global-utility-from-counts [a0 a1 a2 a3 a4 a5 a6]
  report (day-utility a0) + (day-utility a1) + (day-utility a2) +
         (day-utility a3) + (day-utility a4) + (day-utility a5) + (day-utility a6)
end

to recompute-attendance
  set attendance0 0
  set attendance1 0
  set attendance2 0
  set attendance3 0
  set attendance4 0
  set attendance5 0
  set attendance6 0
  ask players [
    if last-action-idx = 0 [ set attendance0 attendance0 + 1 ]
    if last-action-idx = 1 [ set attendance1 attendance1 + 1 ]
    if last-action-idx = 2 [ set attendance2 attendance2 + 1 ]
    if last-action-idx = 3 [ set attendance3 attendance3 + 1 ]
    if last-action-idx = 4 [ set attendance4 attendance4 + 1 ]
    if last-action-idx = 5 [ set attendance5 attendance5 + 1 ]
    if last-action-idx = 6 [ set attendance6 attendance6 + 1 ]
  ]
end

to recompute-rewards
  set current-utility global-utility-from-counts attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  set reward0 1 + current-utility - global-utility-from-counts (attendance0 - 1 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward1 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 - 1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward2 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 - 1 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward3 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 - 1 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward4 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 - 1 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 + (1 / 7))
  set reward5 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 - 1 + (1 / 7)) (attendance6 + (1 / 7))
  set reward6 1 + current-utility - global-utility-from-counts (attendance0 + (1 / 7)) (attendance1 + (1 / 7)) (attendance2 + (1 / 7)) (attendance3 + (1 / 7)) (attendance4 + (1 / 7)) (attendance5 + (1 / 7)) (attendance6 - 1 + (1 / 7))
end

to-report stochastic-choice-7 [w0 w1 w2 w3 w4 w5 w6]
  let total (w0 + w1 + w2 + w3 + w4 + w5 + w6)
  let r random-float total
  if r <= w0 [ report 0 ]
  set r r - w0
  if r <= w1 [ report 1 ]
  set r r - w1
  if r <= w2 [ report 2 ]
  set r r - w2
  if r <= w3 [ report 3 ]
  set r r - w3
  if r <= w4 [ report 4 ]
  set r r - w4
  if r <= w5 [ report 5 ]
  report 6
end

to setup
  clear-all
  set num-agents 63
  set discount-rate 0.98
  set current-utility 0
  create-players num-agents [
    hide-turtle
    setxy 0 who
    set u0 100
    set u1 100
    set u2 100
    set u3 100
    set u4 100
    set u5 100
    set u6 100
    set last-action-idx 0
  ]
  repeat 100 [
    ask players [take-random-action]
    recompute-attendance
    recompute-rewards
    ask players [learn]
  ]
  recompute-attendance
  set current-utility global-utility-from-counts attendance0 attendance1 attendance2 attendance3 attendance4 attendance5 attendance6
  reset-ticks
end

to go
  ask players [take-action]
  recompute-attendance
  recompute-rewards
  ask players [learn]
  tick
end

to take-action
  set last-action-idx stochastic-choice-7 u0 u1 u2 u3 u4 u5 u6
end

to take-random-action
  set last-action-idx random 7
end

to learn
  set u0 u0 * discount-rate
  set u1 u1 * discount-rate
  set u2 u2 * discount-rate
  set u3 u3 * discount-rate
  set u4 u4 * discount-rate
  set u5 u5 * discount-rate
  set u6 u6 * discount-rate
  if last-action-idx = 0 [ set u0 u0 + reward0 ]
  if last-action-idx = 1 [ set u1 u1 + reward1 ]
  if last-action-idx = 2 [ set u2 u2 + reward2 ]
  if last-action-idx = 3 [ set u3 u3 + reward3 ]
  if last-action-idx = 4 [ set u4 u4 + reward4 ]
  if last-action-idx = 5 [ set u5 u5 + reward5 ]
  if last-action-idx = 6 [ set u6 u6 + reward6 ]
end
"""
end
