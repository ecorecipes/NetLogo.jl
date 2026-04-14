# Drug Use and Overdose Model
# nw extension: network-based epidemiological dynamics
# Simulates drug use spreading through social networks with overdose risk
# Source: modelingcommons #4428

struct DrugUseOverdoseModel <: AbstractBenchmarkModel end

model_name(::DrugUseOverdoseModel) = "Drug Use Overdose"
n_ticks(::DrugUseOverdoseModel) = 200
tracked_globals(::DrugUseOverdoseModel) = ["number-overdoses", "num-drug-users", "num-alive"]
world_dims(::DrugUseOverdoseModel) = (-16, 16, -16, 16)
topology(::DrugUseOverdoseModel) = (true, true)

function netlogo_code(::DrugUseOverdoseModel)
    return """
extensions [nw]
globals [number-overdoses num-drug-users num-alive
         population-size percent-drug-user drug-availability]

turtles-own [
  unemployed?
  resilience
  drug-user?
  drug-level
]

to setup
  clear-all
  set population-size 50
  set percent-drug-user 20
  set drug-availability 15
  set number-overdoses 0
  ;; create turtles
  create-turtles population-size [
    set shape "person"
    set color blue
    setxy random-xcor random-ycor
    set drug-user? false
    set drug-level 0
    set unemployed? false
  ]
  ;; seed initial drug users
  ask n-of ((percent-drug-user / 100) * count turtles) turtles [
    set drug-user? true
    set drug-level random-float 0.5
    if unemployed? [
      set drug-level drug-level + 0.2
    ]
  ]
  ;; create social network
  ask turtles [
    create-links-with n-of (min list (random 4) (count other turtles in-radius 10))
                      other turtles in-radius 10
  ]
  ;; create drug-availability patches
  ask n-of drug-availability patches [
    set pcolor red
  ]
  update-stats
  reset-ticks
end

to go
  ask turtles [
    rt 40
    lt 10
    fd 2
    start-drugs
    if drug-level > 0.5 [
      set drug-user? true
    ]
    if drug-user? [
      increase-drug-network
      overdose
    ]
  ]
  update-stats
  tick
end

to start-drugs
  if random 100 < drug-level and (pcolor = red) [
    set drug-level drug-level + 0.1
    set drug-user? true
  ]
end

to increase-drug-network
  if any? link-neighbors [
    ask one-of link-neighbors [
      set drug-level drug-level + 0.1
    ]
  ]
end

to overdose
  if (drug-level > 0.6) and (any? link-neighbors) and (sum [drug-level] of link-neighbors > 1.2) [
    set number-overdoses number-overdoses + 1
    die
  ]
  if drug-level > 2 [
    set number-overdoses number-overdoses + 1
    die
  ]
end

to update-stats
  set num-drug-users count turtles with [drug-user?]
  set num-alive count turtles
end
"""
end
