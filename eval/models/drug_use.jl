# ── Drug Use and Overdose ────────────────────────────────────────
# Source: modelingcommons #4428
# NW extension: declared but model uses standard link operations
# Epidemiological network model of drug use spread.
# Turtles move, pick up drugs from environment, reinforce neighbors'
# drug levels, and overdose (die) when drug level exceeds thresholds.

struct DrugUseModel <: AbstractBenchmarkModel end

model_name(::DrugUseModel) = "Drug Use"
n_ticks(::DrugUseModel) = 200
tracked_globals(::DrugUseModel) = ["number-overdoses"]

function netlogo_code(::DrugUseModel)
"""
extensions [ nw ]

globals [
  number-overdoses
  population-size
  percent-drug-user
  drug-availability
]

turtles-own [
  unemployed?
  resilience
  drug-user?
  drug-level
]

to setup
  ca
  set population-size 50
  set percent-drug-user 20
  set drug-availability 5

  setup-turtles
  setup-network
  setup-drugsites
  reset-ticks
end

to setup-turtles
  crt population-size [
    set shape "person"
    set color blue
    setxy random-xcor random-ycor
    set drug-user? false
    set drug-level 0
    set unemployed? false
  ]
  ask n-of ((percent-drug-user / 100) * count turtles) turtles [
    set drug-user? true
    set drug-level random-float .5
    if unemployed? [
      set drug-level drug-level + .2
    ]
  ]
end

to setup-network
  ask turtles [
    create-links-with n-of (random 4) other turtles in-radius 10
  ]
end

to setup-drugsites
  ask n-of drug-availability patches [
    set pcolor red
  ]
end

to go
  ask turtles [
    rt 40
    lt 10
    fd 2
    start-drugs
    if drug-level > .5 [
      set drug-user? true
    ]
    if drug-user? [
      increase-drug-network
      overdose
    ]
  ]
  tick
end

to start-drugs
  if random 100 < drug-level and (pcolor = red) [
    set drug-level drug-level + .1
    set drug-user? true
  ]
end

to increase-drug-network
  if any? link-neighbors [
    ask one-of link-neighbors [
      set drug-level drug-level + .1
    ]
  ]
end

to overdose
  if (drug-level > .6) and (sum [drug-level] of link-neighbors > 1.2) [
    set number-overdoses number-overdoses + 1
    die
  ]
  if drug-level > 2 [
    set number-overdoses number-overdoses + 1
    die
  ]
end
"""
end
