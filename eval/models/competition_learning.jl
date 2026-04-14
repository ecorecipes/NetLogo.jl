# ── Competition and Learning in a Game Community ──────────────────
# Source: modelingcommons #5990
# NW + RND extensions: weighted-one-of for opponent selection
# Players compete, learn strategies, with preferential rematching.

struct CompetitionLearningModel <: AbstractBenchmarkModel end

model_name(::CompetitionLearningModel) = "Competition Learning"
n_ticks(::CompetitionLearningModel) = 200
tracked_globals(::CompetitionLearningModel) = ["mean-strategy-cl", "min-strategy-cl"]
world_dims(::CompetitionLearningModel) = (-16, 16, -16, 16)
extra_shapes(::CompetitionLearningModel) = """
person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
"""

function netlogo_code(::CompetitionLearningModel)
"""
extensions [nw rnd]

globals [
  num-nodes
  start-wt
  match-wt
  start-strat-max
  base-learn
  partner-learn
  mean-strategy-cl
  min-strategy-cl
]

turtles-own [strategy plays plays-to-99 wins played?]
links-own [matches-real matches-for-choosing]

to setup
  clear-all
  set num-nodes 20
  set start-wt 0.05
  set match-wt 15
  set start-strat-max 0.3
  set base-learn 0.07
  set partner-learn 0.07

  crt num-nodes
  layout-circle turtles (world-width / 2 - 1)
  ask turtles [
    set shape "person"
    set strategy random-float start-strat-max
    set color scale-color green strategy 1 0
    set plays 0
    set plays-to-99 0
    set wins 0
    set played? false
    create-links-with other turtles
  ]
  ask links [
    set matches-for-choosing start-wt
    set matches-real 0
  ]
  ask patches [set pcolor gray]
  set mean-strategy-cl mean [strategy] of turtles
  set min-strategy-cl min [strategy] of turtles
  reset-ticks
end

to go
  ask one-of turtles with [not played?] [
    let player1 self
    let player2 nobody
    let match-link rnd:weighted-one-of (my-links with [[not played?] of other-end]) [matches-for-choosing]
    if match-link != nobody [
      ask self [ask match-link [set player2 other-end]]
      update-match-link match-link
      compete player1 player2
    ]
  ]
  if count turtles with [not played?] < 2 [
    ask turtles [set played? false]
    visualize
    set mean-strategy-cl mean [strategy] of turtles
    set min-strategy-cl min [strategy] of turtles
  ]
  if min [strategy] of turtles >= 0.999 [
    visualize
    set mean-strategy-cl mean [strategy] of turtles
    set min-strategy-cl min [strategy] of turtles
    stop
  ]
end

to update-match-link [the-match-link]
  ask the-match-link [
    set matches-for-choosing matches-for-choosing + match-wt
    set matches-real matches-real + 1
  ]
end

to compete [player1 player2]
  ask player1 [
    set color red
    set played? true
    set plays plays + 1
  ]
  ask player2 [
    set color blue
    set played? true
    set plays plays + 1
  ]
  let strategy1 [strategy] of player1
  let strategy2 [strategy] of player2
  ask player1 [set strategy strategy + ((1 - strategy) * base-learn)]
  ask player2 [set strategy strategy + ((1 - strategy) * base-learn)]
  if strategy1 > strategy2 [
    ask player1 [set wins wins + 1]
    ask player2 [set strategy strategy + ((strategy1 - strategy2) * partner-learn)]
  ]
  if strategy1 < strategy2 [
    ask player2 [set wins wins + 1]
    ask player1 [set strategy strategy + ((strategy2 - strategy1) * partner-learn)]
  ]
  ask (turtle-set player1 player2) [
    if strategy < 0.99 [set plays-to-99 plays-to-99 + 1]
  ]
end

to visualize
  ask links [
    set color scale-color green matches-real max [matches-real] of links min [matches-real] of links
    ifelse matches-real = 0 [hide-link] [show-link]
  ]
  ask turtles [set color scale-color green strategy 1 0]
end
"""
end
