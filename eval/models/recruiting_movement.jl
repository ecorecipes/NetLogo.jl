# Recruiting Movement Supporters Model
# nw extension: weak-component-clusters in setup, centrality metrics as reporters
# Simulates social movement recruitment through network ties
# Source: modelingcommons #7582 (Knoke & Wu, 2024)

struct RecruitingMovementModel <: AbstractBenchmarkModel end

model_name(::RecruitingMovementModel) = "Recruiting Movement"
n_ticks(::RecruitingMovementModel) = 100  # model self-stops when no blue adjacent to green
tracked_globals(::RecruitingMovementModel) = ["recruitpct", "resistpct", "neutralpct"]
world_dims(::RecruitingMovementModel) = (-30, 30, -30, 30)
topology(::RecruitingMovementModel) = (false, false)

function netlogo_code(::RecruitingMovementModel)
    return """
extensions [nw]
breed [peoples person]

peoples-own [
  received?
]

globals [
  initial-blue
  initial-red
  initial-green
  recruitpct
  resistpct
  neutralpct
  N-of-people
  N-Initiators
  Average-people-degree
  Resistance-threshold
]

to setup
  clear-all
  set N-of-people 50
  set N-Initiators 2
  set Average-people-degree 6
  set Resistance-threshold 10
  ask patches [set pcolor white]
  setup-peoples
  ask peoples [set size 4]
  ask peoples [set color blue]
  setup-spatially-clustered-network
  ask n-of N-Initiators peoples
    [ receive-invitation ]
  ask links [ set color black ]
  setup-resist
  reset-ticks
end

to setup-peoples
  set-default-shape peoples "person"
  create-peoples N-of-people [
    setxy (random-xcor * 0.90) (random-ycor * 0.90)
  ]
end

to setup-spatially-clustered-network
  let num-links (Average-people-degree * N-of-people) / 2
  while [count links < num-links] [
    ask one-of peoples [
      let choice (min-one-of (other peoples with [not link-neighbor? myself]) [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
  ;; Ensure single connected component
  let components nw:weak-component-clusters
  while [length components > 1] [
    let component1 item 0 components
    let component2 item 1 components
    ask one-of component1 [ create-link-with one-of component2 ]
    set components nw:weak-component-clusters
  ]
end

to setup-resist
  ask peoples with [color = blue] [
    if random 100 <= Resistance-threshold [set color red]
  ]
end

to go
  if not any? peoples with [color = blue and any? link-neighbors with [color = green]]
    [ stop ]
  spread-invitation
  tally
  tick
end

to receive-invitation
  set received? true
  set color green
end

to spread-invitation
  ask peoples with [color = green] [
    ask link-neighbors with [color = blue] [
      receive-invitation
    ]
  ]
end

to tally
  set recruitpct count (peoples with [color = green]) / (count peoples) * 100
  set resistpct count (peoples with [color = red]) / (count peoples) * 100
  set neutralpct count (peoples with [color = blue]) / (count peoples) * 100
end
"""
end
