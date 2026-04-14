# ── SuperDiffuser Model of Behavior Change in a Network ──────────
# Source: modelingcommons #7468 (Boster et al. 2012 operationalization)
# NW extension: generate-preferential-attachment, betweenness-centrality,
#               clustering-coefficient
# Diffusion on a preferential-attachment network with persuasion mechanics.
# Adopters persuade non-adopters; attitude accumulates until threshold.
# Stops when network saturates or attitude equilibrium holds 50 ticks.

struct SuperDiffuserModel <: AbstractBenchmarkModel end

model_name(::SuperDiffuserModel) = "SuperDiffuser"
n_ticks(::SuperDiffuserModel) = 200
tracked_globals(::SuperDiffuserModel) = ["current-adopted"]

function netlogo_code(::SuperDiffuserModel)
"""
extensions [nw]

turtles-own [
  adopted?
  pers-one
  attitude
  pers-power
  adopt-friends
  non-adopt-friends
  message
]

globals [
  status-quo?
  status-quo-counter
  initial-degree
  initial-between
  initial-pers-power
  initial-pers-likely
  adopted-at-tick
  current-adopted
  init-adopted2
  num-agents
  min-links
  percent-adopted-start
  avg-attitude
  avg-pers-power
  avg-pers-one
  adopt-threshold
  social-influence
]

to setup
  ca
  reset-ticks
  set num-agents 100
  set min-links 2
  set percent-adopted-start 0.05
  set avg-attitude 2
  set avg-pers-power 0.25
  set avg-pers-one 10
  set adopt-threshold 5
  set social-influence 0.05

  set status-quo? false
  set status-quo-counter 0
  nw:generate-preferential-attachment turtles links num-agents min-links
  repeat 30 [ layout-spring turtles links 0.2 5 1 ]

  ask turtles [set adopted? false]
  set init-adopted2 ((num-agents) * (percent-adopted-start))
  ask n-of init-adopted2 turtles [set adopted? true]

  ask turtles [
    set shape "person"
    set message 0
    set-pers-one
    set-attitude
    set-pers-power
    recolor
  ]

  set initial-degree mean ( [ count link-neighbors ] of turtles with [ adopted? = true ] )
  set initial-between mean ( [ nw:betweenness-centrality ] of turtles with [ adopted? = true ] )
  set initial-pers-power mean [pers-power] of turtles with [adopted? = true]
  set initial-pers-likely mean [pers-one] of turtles with [adopted? = true]
  set adopted-at-tick count turtles with [adopted? = true]
  set current-adopted adopted-at-tick
end

to set-pers-one
  set pers-one ( random-normal avg-pers-one 20 )
  if pers-one > 100 [ set pers-one 100 ]
  if pers-one < 0 [ set pers-one 0 ]
end

to set-attitude
  set attitude ( random-normal avg-attitude 1 )
  if attitude > 3.9 [ set attitude 3.9 ]
  if attitude < 1.0 [ set attitude 1.0 ]
end

to set-pers-power
  set pers-power ( random-normal avg-pers-power .1 )
  if pers-power > 2 [ set pers-power 2 ]
  if pers-power < 0 [ set pers-power 0 ]
end

to recolor
  ifelse adopted? = true [
    set color red ] [
    set color white ]
end

to update-friends
  set adopt-friends count link-neighbors with [ adopted? = true ]
  set non-adopt-friends count link-neighbors with [ adopted? = false ]
end

to-report global-clustering-coefficient
  let closed-triplets sum [ nw:clustering-coefficient * count my-links * (count my-links - 1) ] of turtles
  let triplets sum [ count my-links * (count my-links - 1) ] of turtles
  report closed-triplets / triplets
end

to go
  let status-quo-before? status-quo?
  set status-quo? true
  ask turtles [
    update-friends
    if adopted? = true and non-adopt-friends > 0 [ persuade ]
    if adopted? = false [ update-attitude ]
  ]
  ifelse status-quo-before? = true and status-quo? = true [
    set status-quo-counter status-quo-counter + 1 ] [
    set status-quo-counter 0 ]
  tick
  if ticks < 1001 [set adopted-at-tick sentence (adopted-at-tick) (count turtles with [adopted? = true])]
  set current-adopted count turtles with [adopted? = true]
  if status-quo-counter = 50 [ stop ]
  if ( not any? turtles with [ not adopted? ] ) [ stop ]
end

to persuade
  if ( random 100 < pers-one ) [
    ask one-of link-neighbors with [ adopted? = false ] [
      set message [ pers-power ] of myself ] ]
end

to update-attitude
  let old-attitude attitude
  set attitude attitude + message + ( adopt-friends * social-influence )
  if attitude > 7 [ set attitude 7 ]
  if attitude >= adopt-threshold [ set adopted? true ]
  recolor
  set message 0
  if old-attitude != attitude [ set status-quo? false ]
end
"""
end
