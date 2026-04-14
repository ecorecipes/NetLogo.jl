# ── Slow Spread of Environmentally Friendly Action ───────────────────
# Source: modelingcommons #7196
# NW extension: generate-preferential-attachment, louvain-communities, maximal-cliques,
#               set-context, clustering-coefficient, mean-path-length
# Opinion dynamics with community structure and weighted ties.

struct SlowSpreadModel <: AbstractBenchmarkModel end

model_name(::SlowSpreadModel) = "Slow Spread Env Action"
n_ticks(::SlowSpreadModel) = 200
tracked_globals(::SlowSpreadModel) = ["pct-green", "pct-grey"]

function netlogo_code(::SlowSpreadModel)
"""
extensions [nw]
breed [AgentAs AgentA]
breed [AgentBs AgentB]
breed [hardliners hardliner]

links-own [weight]
turtles-own [community clique]

globals [
  n-greys
  n-greens
  k-degree
  group-openness
  prop-hard
  activation-threshold
  threshold-strong
  moving
  strong-ties
  log-threshold
  countervailing-contagion
  hub-weak
  pct-green
  pct-grey
]

to setup
  clear-all
  set n-greys 200
  set n-greens 20
  set k-degree 6
  set group-openness 0.05
  set prop-hard 0.1
  set activation-threshold 0.75
  set threshold-strong 5
  set moving true
  set strong-ties true
  set log-threshold false
  set countervailing-contagion true
  set hub-weak true

  nw:generate-preferential-attachment AgentAs links n-greys k-degree [set color grey]
  nw:generate-preferential-attachment AgentBs links n-greens k-degree [set color green]

  ask AgentBs [ if random-float 1 < group-openness [create-links-with AgentAs] ]
  ask AgentAs [ if random-float 1 < group-openness [create-links-with AgentBs] ]

  ask turtles [
    set size 1
    set shape "person"
    setxy random-xcor random-ycor
  ]

  ask n-of (int (prop-hard * n-greys)) AgentAs [set breed hardliners]
  ask n-of (int (prop-hard * n-greens)) AgentBs [set breed hardliners]
  ask hardliners [set shape "person"]

  foreach nw:louvain-communities [ [comm] ->
    ask comm [ set community comm ]
  ]
  foreach nw:maximal-cliques [ [cliq] ->
    ask cliq [ set clique cliq ]
  ]

  nw:set-context turtles links
  weight-clusters nw:louvain-communities
  tally
  reset-ticks
end

to weight-clusters [ clusters ]
  ask links [ set weight 1 ]
  foreach clusters [ [cluster] ->
    ask cluster [
      ask my-links [ if member? other-end cluster [ set weight 2 ] ]
    ]
  ]
  if hub-weak [
    let max-neighbors (max [count link-neighbors] of turtles)
    let hub turtles with [count link-neighbors > max-neighbors - 10]
    if any? hub [
      ask hub [
        ask my-links [ set weight 1 ]
      ]
    ]
  ]
end

to go
  if (all? turtles [color = green]) [ stop ]
  if (all? turtles [color = grey]) [ stop ]

  if moving [ move ]
  ask turtles [ interact-agent ]
  tally
  tick
end

to move
  ask one-of links [
    if random-float 100 < 1 [ die ]
  ]
  ask one-of turtles [
    if random-float 100 < 1 [
      create-link-with one-of other turtles [ set weight random 3 ]
    ]
  ]
end

to interact-agent
  let count-total count link-neighbors
  let count-weak 0
  let count-strong 0
  let strong-links (my-links) with [weight = 2]
  if any? strong-links [
    set count-strong count link-neighbors with [color != [color] of myself]
  ]
  let weak-links (my-links) with [weight < 2]
  if any? weak-links [
    set count-weak count link-neighbors with [color != [color] of myself]
  ]
  ifelse log-threshold [
    let activation-probability 1 / (1 + exp (-(count-weak - (activation-threshold * count-total)) * 5))
    if random-float 1 < activation-probability [
      if breed != hardliners [set color green]
    ]
  ] [
    if count-weak >= (count-total * activation-threshold) + (random 6) [
      if breed != hardliners [set color green]
    ]
  ]
  if strong-ties [
    if count-strong >= threshold-strong + random 4 [
      if breed != hardliners [set color green]
    ]
  ]
end

to tally
  let total count turtles
  set pct-green count turtles with [color = green] / total * 100
  set pct-grey count turtles with [color = grey] / total * 100
end
"""
end
