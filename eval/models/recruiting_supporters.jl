# ── Recruiting Movement Supporters ─────────────────────────────────
# Source: modelingcommons #7582 (Knoke & Wu 2024)
# NW extension: weak-component-clusters, closeness-centrality,
#               betweenness-centrality, clustering-coefficient, mean-path-length
# Social-network recruitment: neutrals turn green via green link-neighbors,
# resisters (red) never convert; stops when no more neutrals can be reached.

struct RecruitingSupportersModel <: AbstractBenchmarkModel end

model_name(::RecruitingSupportersModel) = "Recruiting Supporters"
n_ticks(::RecruitingSupportersModel) = 50  # model self-stops, but cap at 50
tracked_globals(::RecruitingSupportersModel) = ["recruitpct", "resistpct", "neutralpct"]

function netlogo_code(::RecruitingSupportersModel)
"""
extensions [nw]
breed [peoples people]

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
  set N-of-people 30
  set N-Initiators 1
  set Average-people-degree 4
  set Resistance-threshold 20

  ask patches [set pcolor white]
  setup-peoples
  ask peoples [set size 4]
  ask peoples [set color blue]
  setup-spatially-clustered-network
  ask n-of N-Initiators peoples
    [ receive-invitation ]
  ask links [ set color black ]
  setup-resist
  tally
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

  let components nw:weak-component-clusters
  while [length components > 1] [
    let component1 item 0 components
    let component2 item 1 components
    ask one-of component1 [ create-link-with one-of component2 ]
    set components nw:weak-component-clusters
  ]

  repeat 10 [
    layout-spring peoples links 0.3 (world-width / (sqrt N-of-people)) 1
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
