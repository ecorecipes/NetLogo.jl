# ── Spreading Groups in Social Networks ──────────────────────────────
# Source: modelingcommons #5015 (Alon Sela 2016, adapted from Adamic/Bakshy)
# NW extension: eigenvector-centrality, page-rank
# Epidemic diffusion on preferential-attachment network with spreading groups.

struct SpreadingGroupsModel <: AbstractBenchmarkModel end

model_name(::SpreadingGroupsModel) = "Spreading Groups"
n_ticks(::SpreadingGroupsModel) = 100
tracked_globals(::SpreadingGroupsModel) = ["num-infected"]

function netlogo_code(::SpreadingGroupsModel)
"""
extensions [nw]
globals [
  new-node
  degrees
  time
  num-infected
  previous-num-infected
  tree-mode?
  spreading-group
  num-nodes
  m
  p
  gamma
  num-infected-init
  reinfect-type
  spreadingGroupRepet
  spreading-group-percent
  Retention-loss
  size-reduction
]

turtles-own [
  infected?
]

to setup
  clear-all
  set num-nodes 100
  set m 2
  set p 0.11
  set gamma 0.5
  set num-infected-init 5
  set reinfect-type "eigenval-centrality"
  set spreadingGroupRepet 2
  set spreading-group-percent 5
  set Retention-loss true
  set size-reduction 1.5

  set tree-mode? false
  set-default-shape turtles "circle"
  set degrees []

  make-node
  let first-node new-node
  let prev-node new-node
  repeat 4 [
    make-node
    make-edge new-node prev-node
    set degrees lput prev-node degrees
    set degrees lput new-node degrees
    set prev-node new-node
  ]
  make-edge new-node first-node

  set time 0
  set num-infected 0
  set previous-num-infected 0

  repeat (num-nodes / 2) [create-preferential-net]

  set spreading-group n-of (num-nodes * spreading-group-percent / 100) turtles
  ask spreading-group [set color orange set size 1]
  repeat spreadingGroupRepet [create-spreading-group]

  repeat (num-nodes / 2 - 4) [create-preferential-net]

  reinfect-once
  reset-ticks
end

to create-preferential-net
  make-node
  repeat m [
    let partner find-partner new-node
    ask partner [set color gray + 2]
    make-edge new-node partner
  ]
end

to create-spreading-group
  ask spreading-group [
    let first-node-who [who] of one-of spreading-group
    let second-node-who [who] of one-of spreading-group
    if (first-node-who != second-node-who) [
      if not is-link? link first-node-who second-node-who [
        ask turtle first-node-who [
          set size 2
          create-link-with turtle second-node-who [
            set color orange
            set thickness 0.5
          ]
        ]
      ]
    ]
  ]
end

to reinfect-once
  set num-infected num-infected-init
  set time 0
  set previous-num-infected 0
  ask turtles [
    set color grey
    set infected? false
    set size 1
  ]

  if (reinfect-type = "random") [
    ask n-of num-infected-init turtles [
      set color red
      set size 2
      set infected? true
    ]
  ]

  if (reinfect-type = "group") [
    ask n-of num-infected-init spreading-group [
      set color red
      set size 2
      set infected? true
    ]
  ]

  if (reinfect-type = "eigenval-centrality") [
    ask max-n-of num-infected-init turtles [nw:eigenvector-centrality] [
      set color red
      set size 2
      set infected? true
    ]
  ]

  if (reinfect-type = "PageRank-Centrality") [
    ask max-n-of num-infected-init turtles [nw:page-rank] [
      set color red
      set size 2
      set infected? true
    ]
  ]
end

to go
  if all? turtles [infected?] [ stop ]

  ask turtles with [infected? = true] [
    let mysize [size] of turtle who
    let prob 0
    ask link-neighbors with [infected? = false] [
      ifelse (Retention-loss = true)
        [set prob p * mysize]
        [set prob p]
      if (random-float 1 <= prob) [
        set infected? true
        set color red
        set num-infected num-infected + 1
      ]
    ]
  ]

  let tmp count turtles with [infected? = true]
  ifelse (tmp = previous-num-infected)
    [ stop ]
    [ set previous-num-infected tmp ]

  ask turtles [
    set size size / size-reduction
    if size < 0.1 [set infected? false]
  ]
  tick
end

to make-node
  create-turtles 1 [
    set color gray + 2
    set size 0.5
    set infected? false
    set new-node self
  ]
end

to-report find-partner [node1]
  let ispref (random-float 1 >= gamma)
  let partner node1
  ifelse ispref
    [ set partner one-of degrees ]
    [ set partner one-of turtles ]
  let checkit true
  while [checkit] [
    ask partner [
      ifelse ((link-neighbor? node1) or (partner = node1)) [
        ifelse ispref
          [ set partner one-of degrees ]
          [ set partner one-of turtles ]
        set checkit true
      ] [
        set checkit false
      ]
    ]
  ]
  report partner
end

to make-edge [node1 node2]
  ask node1 [
    ifelse (node1 = node2)
      [ show "error: self-loop attempted" ]
      [
        create-link-with node2 [ set color grey + 2 ]
        setxy ([xcor] of node2) ([ycor] of node2)
        rt random 360
        fd 8
        set degrees lput node1 degrees
        set degrees lput node2 degrees
      ]
  ]
end
"""
end
