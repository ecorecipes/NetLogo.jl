# ── Language Change model (NetLogo models library) ───────────────────

struct LanguageChangeModel <: AbstractBenchmarkModel end

model_name(::LanguageChangeModel) = "Language Change"
n_ticks(::LanguageChangeModel) = 200
tracked_globals(::LanguageChangeModel) = ["mean-state", "num-grammar-0", "num-grammar-1"]
world_dims(::LanguageChangeModel) = (-45, 45, -45, 45)

function netlogo_code(::LanguageChangeModel)
"""
breed [nodes node]

globals [
  randomSeed
  num-nodes
  percent-grammar-1
  update-algorithm
  threshold-val
  alpha
  logistic?
  sink-state-1?
  mean-state
  num-grammar-0
  num-grammar-1
]

nodes-own [
  state
  orig-state
  spoken-state
]

to setup
  clear-all
  resize-world (- 45) 45 (- 45) 45
  set num-nodes 100
  set percent-grammar-1 60
  set update-algorithm "reward"
  set threshold-val 0.3
  set alpha 0.025
  set logistic? true
  set sink-state-1? false
  set-default-shape nodes "circle"
  ask patches [ set pcolor gray ]
  repeat num-nodes [ make-node ]
  distribute-grammars
  create-network
  repeat 100 [ layout ]
  update-tracked-globals
  reset-ticks
end

to make-node
  create-nodes 1 [
    rt random-float 360
    fd max-pxcor
    set size 2
    set state 0.0
  ]
end

to distribute-grammars
  ask nodes [ set state 0 ]
  ask n-of ((percent-grammar-1 / 100) * num-nodes) nodes
    [ set state 1.0 ]
  ask nodes [
    set orig-state state
    set spoken-state state
    update-color
  ]
end

to create-network
  let partner nobody
  let first-node one-of nodes
  let second-node one-of nodes with [self != first-node]
  ask first-node [ create-link-with second-node [ set color white ] ]
  let new-node one-of nodes with [not any? link-neighbors]
  while [new-node != nobody] [
    set partner find-partner
    ask new-node [ create-link-with partner [ set color white ] ]
    layout
    set new-node one-of nodes with [not any? link-neighbors]
  ]
end

to update-color
  set color scale-color red state 0 1
end

to go
  ask nodes [ communicate-via update-algorithm ]
  ask nodes [ update-color ]
  update-tracked-globals
  tick
end

to communicate-via [ algorithm ]
  ifelse (algorithm = "threshold")
  [ listen-threshold ]
  [ ifelse (algorithm = "individual")
    [ listen-individual ]
    [ if (algorithm = "reward")
      [ speak
        ask link-neighbors
        [ listen [spoken-state] of myself ]
   ]]]
end

to listen-threshold
  let grammar-one-sum sum [state] of link-neighbors
  ifelse grammar-one-sum >= (count link-neighbors * threshold-val)
  [ set state 1 ]
  [ if not sink-state-1? [ set state 0 ]
  ]
end

to listen-individual
  set state [state] of one-of link-neighbors
end

to speak
  if logistic?
  [ let gain (alpha + 0.1) * 20
    let filter-val 1 / (1 + exp (- (gain * state - 1) * 5))
    ifelse random-float 1.0 <= filter-val
    [ set spoken-state 1 ]
    [ set spoken-state 0 ]
  ]
  if not logistic?
  [ let biased-val 1.5 * state
    if biased-val >= 1 [ set biased-val 1 ]
    ifelse random-float 1.0 <= biased-val
    [ set spoken-state 1 ]
    [ set spoken-state 0 ]
  ]
end

to listen [heard-state]
  let gamma 0.01
  ifelse random-float 1.0 <= state
  [
    ifelse heard-state = 1
    [ set state state + (gamma * (1 - state)) ]
    [ set state (1 - gamma) * state ]
  ][
    ifelse heard-state = 0
    [ set state state * (1 - gamma) ]
    [ set state gamma + state * (1 - gamma) ]
  ]
end

to-report find-partner
  let pick random-float sum [count link-neighbors] of (nodes with [any? link-neighbors])
  let partner nobody
  ask nodes
  [ if partner = nobody
    [ ifelse count link-neighbors > pick
      [ set partner self]
      [ set pick pick - (count link-neighbors)]
    ]
  ]
  report partner
end

to layout
  layout-spring (turtles with [any? link-neighbors]) links 0.4 6 1
end

to update-tracked-globals
  ifelse any? nodes [
    set mean-state mean [state] of nodes
    set num-grammar-0 count nodes with [state < 0.5]
    set num-grammar-1 count nodes with [state >= 0.5]
  ][
    set mean-state 0
    set num-grammar-0 0
    set num-grammar-1 0
  ]
end
"""
end
