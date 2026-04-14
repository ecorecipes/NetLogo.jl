# ── Leonardi Technology Adoption Model 3 (Table + NW Extensions) ───────
# Source: modelingcommons #4075 (Leonardi_Model_3)
# Table extension: table:make, table:put, table:get, table:length,
#   table:keys, table:has-key?, table:clear
# NW extension: nw:set-context, nw:eigenvector-centrality,
#   nw:weak-component-clusters, nw:distance-to, nw:mean-path-length
# Technology adoption model: people form expectations about a technology
# through social and material interactions. Tracks usage convergence.

struct LeonardiTechAdoptionModel <: AbstractBenchmarkModel end

model_name(::LeonardiTechAdoptionModel) = "Leonardi Tech Adoption"
n_ticks(::LeonardiTechAdoptionModel) = 100
tracked_globals(::LeonardiTechAdoptionModel) = [
    "count people with [not empty? usage]",
    "count people with [persistence > 0]"
]

function world_dims(::LeonardiTechAdoptionModel)
    return (min_pxcor=-16, max_pxcor=16, min_pycor=-16, max_pycor=16)
end

topology(::LeonardiTechAdoptionModel) = (false, false)

extra_shapes(::LeonardiTechAdoptionModel) = """
box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
"""

netlogo_code(::LeonardiTechAdoptionModel) = raw"""
extensions [table nw]

globals [social-influence material-influence team-radius
         number-expecting-a number-expecting-b number-expecting-both number-no-expectations
         technology-affordances limited-persistence tech-transparency
         can-learn-unexpectedly auto-total-people use-can-fail
         proportion-material-influence add-num-eigenvector]

breed [people person]
breed [expectations expectation]
breed [technologies technology]

people-own [usage understanding influencer persistence teams node-clustering-coefficient eigen-cent]
expectations-own [feature strength]
technologies-own [affordances]

directed-link-breed [holds hold]
undirected-link-breed [connections connection]

to setup
  clear-all

  set number-expecting-a 1
  set number-expecting-b 55
  set number-expecting-both 0
  set number-no-expectations 44
  set technology-affordances ["a"]
  set limited-persistence true
  set tech-transparency 0.1
  set can-learn-unexpectedly true
  set auto-total-people 100
  set use-can-fail true
  set proportion-material-influence 0.05
  set add-num-eigenvector "off"

  create-people total-num [
    setxy random-pxcor random-pycor
    set shape "person"
    set size 1.6
    set usage []
    color-code usage 0.8
    set teams []
    set understanding table:make
  ]

  ask n-of number-expecting-a people with [table:length understanding < 1] [
    table:put understanding "a" 1
  ]
  ask n-of number-expecting-b people with [table:length understanding < 1] [
    table:put understanding "b" 1
  ]
  ask n-of number-expecting-both people with [table:length understanding < 1] [
    table:put understanding "a" 1
    table:put understanding "b" 1
  ]

  build-network
  calculate-centralities

  ask people [
    update-expectations
    ifelse limited-persistence
      [set persistence 3]
      [set persistence 1000]
  ]

  ask expectations [format-expectations]

  adopt-technology

  set social-influence []
  set material-influence []

  reset-ticks
end

to build-network
  nw:set-context people connections
  set-team-radius

  while [any? people with [teams = []]] [
    ask one-of people with [teams = []] [
      set teams (list who)
      let candidates other people in-radius team-radius with [length teams < 4]
      let n-members min (list (1 + random 4) (count candidates))
      if n-members > 0 [
        ask n-of n-members candidates [
          set teams fput [who] of myself teams
          set teams (sentence teams)
        ]
      ]
    ]
  ]

  let roll-call 0
  while [roll-call <= total-num] [
    ask people [
      if member? roll-call teams [
        if any? other people with [member? roll-call teams and not connection-neighbor? myself] [
          create-connections-with other people with [member? roll-call teams and not connection-neighbor? myself]
        ]
      ]
    ]
    set roll-call roll-call + 1
  ]

  fix-network
  make-small
end

to set-team-radius
  set team-radius 1
  while [any? people with [count other people in-radius team-radius < 4]] [
    set team-radius team-radius + 1
  ]
end

to fix-network
  let clusters nw:weak-component-clusters
  while [length clusters > 1] [
    let c1 first clusters
    let c2 item 1 clusters
    let p1 one-of c1
    let p2 one-of c2
    ask p1 [create-connection-with p2]
    set clusters nw:weak-component-clusters
  ]
end

to make-small
  ask n-of (ceiling (total-num / 10)) people [
    create-connection-with one-of other people
  ]
end

to calculate-centralities
  ask people [set eigen-cent nw:eigenvector-centrality]
end

to update-expectations
  ask people with [table:length understanding != count out-hold-neighbors] [
    ask out-hold-neighbors [die]
    let instructions table:keys understanding
    while [instructions != []] [
      hatch-expectations 1 [
        create-hold-from myself
        ask my-in-holds [hide-link]
        set feature first instructions
        set strength [table:get understanding first instructions] of myself
        set instructions but-first instructions
      ]
    ]
  ]
  ask expectations [format-expectations]
end

to format-expectations
  if strength > 1 [set strength 1]
  if strength < -1 [set strength -1]
  if strength > 0 [show-turtle set shape "circle" set size 0.5]
  if strength < 0 [show-turtle set shape "x" set size 0.6]
  if strength = 0 [hide-turtle]
  let holder one-of in-hold-neighbors
  if holder != nobody [
    let hx [xcor] of holder
    let hy [ycor] of holder
    let x-offset ifelse-value (feature = "a") [-0.5] [0.5]
    let nx max (list min-pxcor (min (list max-pxcor (hx + x-offset))))
    let ny max (list min-pycor (min (list max-pycor (hy + 0.5))))
    setxy nx ny
  ]
  color-code feature 1.5
end

to adopt-technology
  create-technologies 1 [
    set shape "box"
    set size 3
    set affordances table:make
    let instructions (sentence technology-affordances)
    while [instructions != []] [
      table:put affordances first instructions 1
      set instructions but-first instructions
    ]
    color-code (table:keys affordances) -2.5
  ]
end

to color-code [thing number]
  if member? "a" thing and not member? "b" thing [set color blue + number]
  if member? "b" thing and not member? "a" thing [set color yellow + number]
  if member? "a" thing and member? "b" thing [set color green + number]
  if not member? "a" thing and not member? "b" thing [set color gray + number]
end

to go
  if all? people [persistence = 0] [stop]

  ask people [
    interact
    update-expectations
  ]
  update-influences
  tick
end

to interact
  set influencer nobody
  if persistence > 0 [determine-influencer]

  if is-person? influencer [
    learn-from ([understanding] of influencer) 1 0.2
  ]

  if is-technology? influencer [
    ifelse table:length understanding > 0
      [use-technology]
      [learn-from ([affordances] of influencer) tech-transparency 1]
    set persistence persistence - 1
  ]
end

to determine-influencer
  if random-float 1 < 0.25 [
    ifelse random-float 1 < proportion-material-influence
      [set influencer one-of technologies]
      [set influencer one-of connection-neighbors]
  ]
end

to learn-from [source chance influence]
  if table:length source > 0 and random-float 1 < chance [
    let insight one-of table:keys source
    if not table:has-key? understanding insight [
      table:put understanding insight 0
    ]
    let direction 1
    if table:get source insight > 0 [set direction 1]
    if table:get source insight < 0 [set direction -1]
    table:put understanding insight table:get understanding insight + influence * direction
    if abs table:get understanding insight > 1 [
      table:put understanding insight direction
    ]
    ask out-hold-neighbors with [feature = insight] [
      set strength [table:get understanding insight] of myself
    ]
  ]
end

to use-technology
  if can-learn-unexpectedly [
    if random-float 1 < 0.05 [
      learn-from ([affordances] of influencer) tech-transparency 1
    ]
  ]
  if any? out-hold-neighbors with [strength > 0] [
    let use-feat [feature] of one-of out-hold-neighbors with [strength > 0]
    let chance-use-works 1
    if use-can-fail [set chance-use-works 0.95]
    ifelse table:has-key? [affordances] of influencer use-feat and random-float 1 < chance-use-works [
      table:put understanding use-feat 1
      set usage lput use-feat usage
      set usage remove-duplicates usage
      color-code usage 0.8
    ] [
      table:put understanding use-feat -1
      set usage remove use-feat usage
      color-code usage 0.8
    ]
    ask out-hold-neighbors with [feature = use-feat] [
      set strength [table:get understanding use-feat] of myself
    ]
  ]
end

to update-influences
  if any? people with [persistence > 0] [
    set social-influence fput (count people with [is-person? influencer] / count people with [persistence > 0]) social-influence
    set material-influence fput (count people with [is-technology? influencer] / count people with [persistence > 0]) material-influence
  ]
end

to-report total-num
  report number-expecting-a + number-expecting-b + number-expecting-both + number-no-expectations
end
"""
