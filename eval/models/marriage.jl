# ── Marriage Problem (Stable Matching / Deferred Acceptance) ───────
# Adapted from netlogomas/marriage-problem by Jose M. Vidal

struct MarriageModel <: AbstractBenchmarkModel end

model_name(::MarriageModel) = "Marriage Problem"
n_ticks(::MarriageModel) = 200
tracked_globals(::MarriageModel) = ["num-bachelors"]
world_dims(::MarriageModel) = (-16, 16, -16, 16)

function netlogo_code(::MarriageModel)
"""
globals [randomSeed num-bachelors num-people]

breed [men man]
breed [women woman]

men-own [preferences]
women-own [preferences]

to setup
  clear-all
  set num-people 32
  create-women num-people [
    set heading 0
    set shape "circle"
    set color pink
    set size 1.5
    setxy random-xcor random-ycor
  ]
  let list-of-women sort women
  create-men num-people [
    set preferences shuffle list-of-women
    set heading 0
    set shape "circle"
    set color cyan
    set size 1.5
    setxy random-xcor random-ycor
  ]
  let list-of-men sort men
  ask women [
    set preferences shuffle list-of-men
  ]
  ask men [update-link]
  set num-bachelors count men with [not any? my-out-links]
  reset-ticks
end

to go
  if (all? women [count my-in-links = 1]) [ stop ]
  ifelse (ticks mod 2 = 0) [
    ask men with [not any? my-out-links] [update-link]
  ][
    ask women with [any? in-link-neighbors] [turn-down-proposals]
  ]
  set num-bachelors count men with [not any? my-out-links]
  tick
end

to update-link
  if empty? preferences [ stop ]
  create-link-to first preferences
end

to turn-down-proposals
  let suitors sort-by [[a b] -> position a preferences < position b preferences] in-link-neighbors
  if (length suitors <= 1) [ stop ]
  foreach (but-first suitors) [s ->
    ask s [
      ask my-out-links [die]
      set preferences but-first preferences
    ]
  ]
end
"""
end
