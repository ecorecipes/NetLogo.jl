# ── Complex Quality Improvement Network ──────────────────────────────
# Source: modelingcommons #7245 (Bill Wilson, Massey University 2020-2023)
# NW extension: generate-preferential-attachment, betweenness-centrality,
#   eigenvector-centrality, closeness-centrality, louvain-communities
# PDSA quality improvement cycle on social network.

struct CQINModel <: AbstractBenchmarkModel end

model_name(::CQINModel) = "Quality Improvement Network"
n_ticks(::CQINModel) = 100
tracked_globals(::CQINModel) = ["num-updated", "num-resistant", "num-adjusted"]
setup_command(::CQINModel) = "setup"
go_command(::CQINModel) = "go-full-cycle"

function netlogo_code(::CQINModel)
"""
extensions [nw]

directed-link-breed [ directed-edges directed-edge ]
undirected-link-breed [ undirected-edges undirected-edge ]

globals [
  signal
  iteration-count
  network-source
  network-type
  number-of-nodes
  node-degree
  links-to-use
  schema-share-effectiveness
  schema-check-frequency
  rejection-chance
  rejection-threshold
  problem-space-complexity
  problem-solving-effectiveness
  coevolution-constraints
  initial-detection-size
  learning-gain
  planned-iterations
  signal-base
  signal-increment
  signal-target
  max-non-co-operating
  num-updated
  num-resistant
  num-adjusted
]

turtles-own [
  susceptible?
  updated?
  agreed?
  implemented?
  reviewed?
  adjusted?
  resistant?
  schema-check-timer
]

to setup
  clear-all
  set network-source "Generate"
  set network-type "preferential-attachment"
  set number-of-nodes 94
  set node-degree 3
  set links-to-use "directed"
  set schema-share-effectiveness 85
  set schema-check-frequency 1
  set rejection-chance 10
  set rejection-threshold 25
  set problem-space-complexity 90
  set problem-solving-effectiveness 60
  set coevolution-constraints 50
  set initial-detection-size 14
  set learning-gain 1.1
  set planned-iterations 20
  set signal-base 0
  set signal-increment 10
  set signal-target 100
  set max-non-co-operating 0.5
  set iteration-count 0

  if network-source = "Generate" [ create-network ]
  set signal (signal-base + 0)
  set-default-shape turtles "person"
  reset-ticks
end

to create-network
  if network-type = "random" [
    setup-nodes
    setup-spatially-clustered-network
  ]
  if network-type = "preferential-attachment" [
    create-preferential-attachment
  ]
end

to setup-nodes
  set-default-shape turtles "person"
  create-turtles number-of-nodes [
    setxy (random-xcor * 0.9) (random-ycor * 0.9)
    set size 1.5
    become-susceptible
    set schema-check-timer random schema-check-frequency
  ]
end

to create-preferential-attachment
  nw:generate-preferential-attachment turtles links (number-of-nodes) (node-degree) [
    set size 2
    set shape "person"
    set color blue
    set updated? false
    set susceptible? true
    set resistant? false
    become-susceptible
    set schema-check-timer random schema-check-frequency
  ]
end

to setup-spatially-clustered-network
  let num-links (node-degree * number-of-nodes) / 2
  while [count links < num-links] [
    ask one-of turtles [
      let choice (min-one-of (other turtles with [not link-neighbor? myself]) [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
  repeat 10 [
    layout-spring turtles links 0.3 (world-width / (sqrt number-of-nodes)) 1
  ]
end

to cycle
  ask turtles [
    set color blue
    set adjusted? false
    set susceptible? true
    set resistant? false
    become-susceptible
    set schema-check-timer random schema-check-frequency
  ]
  set iteration-count iteration-count + 1
  ask n-of initial-detection-size turtles [ become-updated ]
  ask links [ set color yellow ]
end

to become-susceptible
  set susceptible? true
  set updated? false
  set agreed? false
  set implemented? false
  set reviewed? false
  set adjusted? false
  set resistant? false
  set color blue
end

to become-updated
  set updated? true
  set susceptible? false
  set agreed? false
  set implemented? false
  set reviewed? false
  set adjusted? false
  set resistant? false
  set color red
end

to become-agreed
  set agreed? true
  set susceptible? false
  set updated? false
  set implemented? false
  set reviewed? false
  set adjusted? false
  set resistant? false
  set color green
end

to become-implemented
  set implemented? true
  set susceptible? false
  set updated? false
  set agreed? false
  set reviewed? false
  set adjusted? false
  set resistant? false
  set color brown
end

to become-reviewed
  set reviewed? true
  set susceptible? false
  set updated? false
  set agreed? false
  set implemented? false
  set adjusted? false
  set resistant? false
  set color pink
end

to become-adjusted
  set adjusted? true
  set susceptible? false
  set updated? false
  set agreed? false
  set implemented? false
  set reviewed? false
  set resistant? false
  set color orange
end

to become-resistant
  set susceptible? false
  set updated? false
  set agreed? false
  set implemented? false
  set reviewed? false
  set adjusted? false
  set resistant? true
  set color gray
  ask my-links [ set color gray - 2 ]
end

to go-full-cycle
  cycle
  repeat 5 [ go ]
  repeat 5 [ go-2 ]
  repeat 5 [ go-3 ]
  repeat 5 [ go-4 ]
  repeat 5 [ go-5 ]
end

to go
  if count turtles with [resistant?] >= count turtles * max-non-co-operating [ stop ]
  if all? turtles [updated? or resistant?] [ stop ]
  if iteration-count = planned-iterations + 1 [ stop ]
  if signal = signal-target [ stop ]
  ask turtles [
    set schema-check-timer schema-check-timer + 1
    if schema-check-timer >= schema-check-frequency [ set schema-check-timer 0 ]
  ]
  spread-signal
  do-schema-checks
  set num-updated count turtles with [updated?]
  set num-resistant count turtles with [resistant?]
  set num-adjusted count turtles with [adjusted?]
  tick
end

to go-2
  if count turtles with [resistant?] >= count turtles * max-non-co-operating [ stop ]
  if all? turtles [agreed? or resistant?] [ stop ]
  if iteration-count = planned-iterations + 1 [ stop ]
  if signal = signal-target [ stop ]
  ask turtles [
    set schema-check-timer schema-check-timer + 2
    if schema-check-timer >= schema-check-frequency [ set schema-check-timer 0 ]
  ]
  problem-solve
  do-schema-checks-2
  set num-updated count turtles with [updated?]
  set num-resistant count turtles with [resistant?]
  set num-adjusted count turtles with [adjusted?]
  tick
end

to go-3
  if count turtles with [resistant?] >= count turtles * max-non-co-operating [ stop ]
  if all? turtles [implemented? or resistant?] [ stop ]
  if iteration-count = planned-iterations + 1 [ stop ]
  if signal = signal-target [ stop ]
  ask turtles [
    set schema-check-timer schema-check-timer + 3
    if schema-check-timer >= schema-check-frequency [ set schema-check-timer 0 ]
  ]
  implement
  do-schema-checks-3
  set num-updated count turtles with [updated?]
  set num-resistant count turtles with [resistant?]
  set num-adjusted count turtles with [adjusted?]
  tick
end

to go-4
  if count turtles with [resistant?] >= count turtles * max-non-co-operating [ stop ]
  if all? turtles [reviewed? or resistant?] [ stop ]
  if iteration-count = planned-iterations + 1 [ stop ]
  if signal = signal-target [ stop ]
  ask turtles [
    set schema-check-timer schema-check-timer + 4
    if schema-check-timer >= schema-check-frequency [ set schema-check-timer 0 ]
  ]
  review
  do-schema-checks-4
  set num-updated count turtles with [updated?]
  set num-resistant count turtles with [resistant?]
  set num-adjusted count turtles with [adjusted?]
  tick
end

to go-5
  if count turtles with [resistant?] >= count turtles * max-non-co-operating [ stop ]
  if all? turtles [adjusted? or resistant?] [ stop ]
  if iteration-count = planned-iterations + 1 [ stop ]
  if signal = signal-target [ stop ]
  ask turtles [
    set schema-check-timer schema-check-timer + 5
    if schema-check-timer >= schema-check-frequency [ set schema-check-timer 0 ]
  ]
  adjust
  do-schema-checks-5
  set num-updated count turtles with [updated?]
  set num-resistant count turtles with [resistant?]
  set num-adjusted count turtles with [adjusted?]
  tick
end

to spread-signal
  ask turtles with [updated?] [
    ask link-neighbors with [susceptible? and not resistant?] [
      if random-float 100 < (schema-share-effectiveness) * (learning-gain ^ iteration-count)
        [ become-updated ]
    ]
  ]
end

to problem-solve
  ask turtles with [updated?] [
    ask link-neighbors with [updated? and not resistant?] [
      if random-float 100 < (schema-share-effectiveness) * (learning-gain ^ iteration-count) * (problem-solving-effectiveness * (learning-gain ^ iteration-count)) / problem-space-complexity
        [ become-agreed ]
    ]
  ]
end

to implement
  ask turtles with [agreed?] [
    ask link-neighbors with [agreed? and not resistant?] [
      if random-float 100 < (schema-share-effectiveness * (learning-gain ^ iteration-count)) * ((problem-solving-effectiveness * (learning-gain ^ iteration-count)) / problem-space-complexity) * ((100 - coevolution-constraints) / 100)
        [ become-implemented ]
    ]
  ]
end

to review
  ask turtles with [implemented?] [
    ask link-neighbors with [implemented? and not resistant?] [
      if random-float 100 < (schema-share-effectiveness) * (learning-gain ^ iteration-count)
        [ become-reviewed ]
    ]
  ]
end

to adjust
  ask turtles with [reviewed?] [
    ask link-neighbors with [reviewed? and not resistant?] [
      if random-float 100 < (schema-share-effectiveness) * (learning-gain ^ iteration-count) * (problem-solving-effectiveness * (learning-gain ^ iteration-count)) / problem-space-complexity * (100 - coevolution-constraints) / 100
        [ become-adjusted ]
    ]
  ]
end

to do-schema-checks
  ask turtles with [updated? and schema-check-timer = 0] [
    if random 100 < (rejection-threshold * (0.8 + (problem-space-complexity / 100))) [
      ifelse random 100 < (rejection-chance * (0.8 + (problem-space-complexity / 100)))
        [ become-resistant ]
        [ become-updated ]
    ]
  ]
end

to do-schema-checks-2
  ask turtles with [updated? and schema-check-timer = 0] [
    if random 100 < (rejection-threshold * (0.8 + (problem-space-complexity / 100))) [
      ifelse random 100 < (rejection-chance * (0.8 + (problem-space-complexity / 100)))
        [ become-resistant ]
        [ become-agreed ]
    ]
  ]
end

to do-schema-checks-3
  ask turtles with [agreed? and schema-check-timer = 0] [
    if random 100 < (rejection-threshold * (0.8 + (problem-space-complexity / 100))) [
      ifelse random 100 < (rejection-chance * (0.8 + (problem-space-complexity / 100)))
        [ become-resistant ]
        [ become-implemented ]
    ]
  ]
end

to do-schema-checks-4
  ask turtles with [implemented? and schema-check-timer = 0] [
    if random 100 < (rejection-threshold * (0.8 + (problem-space-complexity / 100))) [
      ifelse random 100 < (rejection-chance * (0.8 + (problem-space-complexity / 100)))
        [ become-resistant ]
        [ become-reviewed ]
    ]
  ]
end

to do-schema-checks-5
  ask turtles with [reviewed? and schema-check-timer = 0] [
    if random 100 < (rejection-threshold * (0.8 + (problem-space-complexity / 100))) [
      ifelse random 100 < (rejection-chance * (0.8 + (problem-space-complexity / 100)))
        [ become-resistant ]
        [ become-adjusted ]
    ]
  ]
  if count turtles with [resistant?] < count turtles * max-non-co-operating [
    set signal (signal-base + (signal-increment * iteration-count))
  ]
end

to-report get-links-to-use
  report ifelse-value links-to-use = "directed"
    [ directed-edges ]
    [ undirected-edges ]
end

to centrality [ measure ]
  nw:set-context turtles links
  ask turtles [
    let res (runresult measure)
    ifelse is-number? res [
      set label precision res 2
      set size res
    ] [
      set label res
      set size 1
    ]
  ]
  normalize-sizes-and-colors
end

to normalize-sizes-and-colors
  if count turtles > 0 [
    let sizes sort [ size ] of turtles
    let delta last sizes - first sizes
    ifelse delta = 0 [
      ask turtles [ set size 1 ]
    ] [
      ask turtles [ set size ((size - first sizes) / delta) * 2 + 0.5 ]
    ]
    ask turtles [ set color scale-color red size 0 5 ]
  ]
end

to community-detection
  nw:set-context turtles get-links-to-use
  color-clusters nw:louvain-communities
end

to color-clusters [ clusters ]
  ask turtles [ set color gray ]
  ask links [ set color gray - 2 ]
  let n length clusters
  let idx 0
  repeat n [
    let cluster item idx clusters
    let hue (360 * idx / n)
    ask cluster [
      set color hsb hue 100 100
      ask my-links with [ member? other-end cluster ] [ set color hsb hue 100 75 ]
    ]
    set idx idx + 1
  ]
end
"""
end
