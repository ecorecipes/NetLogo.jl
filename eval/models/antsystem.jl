# ── Ant System (TSP optimizer) ─────────────────────────────────────
# Adapted from netlogomas/AntSystem by Jose M. Vidal

struct AntSystemModel <: AbstractBenchmarkModel end

model_name(::AntSystemModel) = "Ant System TSP"
n_ticks(::AntSystemModel) = 100
tracked_globals(::AntSystemModel) = ["best-tour-cost"]
world_dims(::AntSystemModel) = (-8, 8, -8, 8)

function netlogo_code(::AntSystemModel)
"""
globals [best-tour best-tour-cost node-diameter randomSeed
         as-alpha as-beta as-rho num-of-nodes num-of-ants]

breed [nodes node]
breed [ants ant]

links-own [node-a node-b cost pheromone]
ants-own [tour tour-cost]

to-report calculate-distance [a b]
  let diff-x [xcor] of a - [xcor] of b
  let diff-y [ycor] of a - [ycor] of b
  report sqrt (diff-x ^ 2 + diff-y ^ 2)
end

to setup
  clear-all
  resize-world (- 8) 8 (- 8) 8
  set node-diameter 1.5
  set as-alpha 1
  set as-beta 5
  set as-rho 0.5
  set num-of-nodes 10
  set num-of-ants 15
  set-default-shape nodes "circle"

  setup-nodes
  setup-links
  setup-ants

  set best-tour get-random-path
  set best-tour-cost get-tour-length best-tour
  reset-ticks
end

to setup-nodes
  let x-range n-values (max-pxcor) [i -> i + 1]
  let y-range n-values (max-pycor) [i -> i + 1]
  create-nodes num-of-nodes [
    setxy one-of x-range one-of y-range
    set color yellow
    set size node-diameter
  ]
end

to setup-links
  let remaining-nodes [self] of nodes
  while [not empty? remaining-nodes] [
    let a first remaining-nodes
    set remaining-nodes but-first remaining-nodes
    ask a [
      foreach remaining-nodes [nd ->
        create-link-with nd [
          hide-link
          set color red
          set thickness 0.3
          set node-a a
          set node-b nd
          set cost max list 1 (ceiling calculate-distance a nd)
          set pheromone random-float 0.1
        ]
      ]
    ]
  ]
end

to setup-ants
  create-ants num-of-ants [
    hide-turtle
    set tour []
    set tour-cost 0
  ]
end

to go
  ask ants [
    set tour get-as-path
    set tour-cost get-tour-length tour
    if tour-cost < best-tour-cost [
      set best-tour tour
      set best-tour-cost tour-cost
    ]
  ]
  update-pheromone
  tick
end

to-report get-random-path
  let origin one-of nodes
  report fput origin lput origin [self] of nodes with [self != origin]
end

to-report get-as-path
  let origin one-of nodes
  let new-tour (list origin)
  let remaining-nodes [self] of nodes with [self != origin]
  let current-node origin
  while [not empty? remaining-nodes] [
    let next-node choose-next-node current-node remaining-nodes
    set new-tour lput next-node new-tour
    set remaining-nodes remove next-node remaining-nodes
    set current-node next-node
  ]
  set new-tour lput origin new-tour
  report new-tour
end

to-report choose-next-node [current-node remaining-nodes]
  let probabilities calculate-probabilities current-node remaining-nodes
  let rand-num random-float 1
  report last first filter [p -> first p >= rand-num] probabilities
end

to-report calculate-probabilities [current-node remaining-nodes]
  let transition-probabilities []
  let denominator 0
  foreach remaining-nodes [nd ->
    ask current-node [
      let next-link link-with nd
      let transition-probability ([pheromone] of next-link ^ as-alpha) * ((1 / [cost] of next-link) ^ as-beta)
      set transition-probabilities lput (list transition-probability nd) transition-probabilities
      set denominator (denominator + transition-probability)
    ]
  ]
  let probabilities []
  foreach transition-probabilities [tp ->
    let transition-probability first tp
    let destination-node last tp
    set probabilities lput (list (transition-probability / denominator) destination-node) probabilities
  ]
  set probabilities sort-by [[a b] -> first a < first b] probabilities
  let normalized-probabilities []
  let total 0
  foreach probabilities [p ->
    set total (total + first p)
    set normalized-probabilities lput (list total last p) normalized-probabilities
  ]
  report normalized-probabilities
end

to update-pheromone
  ask links [
    set pheromone (pheromone * (1 - as-rho))
  ]
  ask ants [
    let pheromone-increment (100 / tour-cost)
    foreach get-tour-links tour [lnk ->
      ask lnk [ set pheromone (pheromone + pheromone-increment) ]
    ]
  ]
end

to-report get-tour-links [tour-nodes]
  let tour-links []
  let idx 0
  while [idx < length tour-nodes - 1] [
    let a item idx tour-nodes
    let b item (idx + 1) tour-nodes
    ask a [ set tour-links lput link-with b tour-links ]
    set idx idx + 1
  ]
  report tour-links
end

to-report get-tour-length [tour-nodes]
  report reduce [[a b] -> a + b] (map [[lnk] -> [cost] of lnk] get-tour-links tour-nodes)
end
"""
end
