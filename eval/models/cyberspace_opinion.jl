# ── CyberspaceOpinion model (CSS600 ClassModels / csv extension) ──────

struct CyberspaceOpinionModel <: AbstractBenchmarkModel end

model_name(::CyberspaceOpinionModel) = "Cyberspace Opinion"
n_ticks(::CyberspaceOpinionModel) = 200
tracked_globals(::CyberspaceOpinionModel) = ["count turtles with [infected?]", "count turtles with [recovered?]"]
world_dims(::CyberspaceOpinionModel) = (-25, 25, -25, 25)

function netlogo_code(::CyberspaceOpinionModel)
"""
extensions [
  CSV
]

globals [
  recover-rate
  extremists

  network_type
  rewiring-probability
  num-nodes-connected
  num-links
  n-extremists-leaders
  threshold-sentiment
]

turtles-own [
  ID
  location
  local-neighbors
  anti-vaccine-sentiment
  extremist?
  vaccinated?
  susceptible?
  infected?
  recovered?
]

links-own [
  rewired?
]

to setup
  clear-all

  set recover-rate 0.001
  set network_type "scale free network"
  set rewiring-probability 0
  set num-nodes-connected 0
  set num-links 0
  set n-extremists-leaders 5
  set threshold-sentiment 0.5

  ask patches [
    sprout 1
  ]

  ask turtles [
    set shape "person"
    set color brown
    set anti-vaccine-sentiment 0
    set extremist? false
    set extremists []
    set location patch-here
    set local-neighbors turtles-on neighbors
    set vaccinated? false
    set susceptible? false
    set infected? false
    set recovered? false
  ]

  ;; Generate network
  generate-network

  ;; Setup opinions and extremism
  setup-opinions
  spread-extremism

  ;; Setup disease
  vaccinate-non-extremists
  infect

  reset-ticks
end

to go
  transmit-disease
end

to generate-network
  if network_type = "random network" [
    ask links [die]
    while [count links < num-links][
      ask one-of turtles [
        create-link-with one-of other turtles [set color cyan]
      ]
    ]
  ]

  if network_type = "small world network"[
    ask links [die]
    ask turtles [
      create-links-with turtles-on neighbors4]

    ask links [
      set rewired? False
    ]

    ask links [
      if (random-float 1) < rewiring-probability
      [
        let node1 end1
        if [count link-neighbors] of end1 < (count turtles - 1)
          [
          let node2 one-of turtles with [(self != node1) and (not link-neighbor? node1)]
          ask node1 [create-link-with node2 [set color cyan set rewired? true]]
          set rewired? true
        ]
      ]

      if (rewired?)
        [
          die
        ]
    ]
  ]

  if network_type = "scale free network" [
    ask links [die]

    let node1 one-of turtles
    ask one-of turtles [
      if node1 != self [
        create-link-with node1
        [set color cyan]
      ]
    ]

    while [count turtles with [count link-neighbors > 1] <= num-nodes-connected]
    [
      let old-node [one-of both-ends] of one-of links
      ask one-of turtles [
        if old-node != nobody and old-node != self
        [
          create-link-with old-node
          [set color cyan]
        ]
      ]
    ]
  ]
end

to hide-network
  ask links [
    hide-link
  ]
end

to show-network
  ask links [
    show-link
  ]
end

to setup-opinions
  set extremists []
  ask turtles [
    set extremist? false
    set color brown
    set anti-vaccine-sentiment 0
  ]
end

to spread-extremism
  assign-sentiment
  assign-leaders-extremists
  cyber-spread-extremism
  local-spread-extremism
end

to assign-sentiment
  ask turtles [
    set anti-vaccine-sentiment median (list -1 (random-normal 0 1) 1)
  ]
end

to assign-leaders-extremists
  let lst (reverse (sort-on [count link-neighbors] turtles))

  set extremists sublist lst 0 n-extremists-leaders

  foreach extremists
  [
    x ->  ask turtles
    [
      set anti-vaccine-sentiment 1
      set extremist? True
      set color cyan
    ]
  ]
end

to cyber-spread-extremism
  let potential-targets []
  foreach extremists
  [
    x -> ask turtles
    [
      set potential-targets lput link-neighbors potential-targets
    ]
  ]

  foreach potential-targets
  [
    x -> ask turtles
    [
      if anti-vaccine-sentiment >= threshold-sentiment [set extremist? True]
    ]
  ]

  ask turtles [
    if extremist? and not member? self extremists [
      set extremists lput self extremists
      set color cyan
    ]
  ]
end

to local-spread-extremism
  let potential-targets []
  foreach extremists [
    x -> ask turtles [set potential-targets lput local-neighbors potential-targets]
  ]

  foreach potential-targets
  [
    x ->
    ask turtles
    [
      if anti-vaccine-sentiment >= threshold-sentiment [set extremist? True]
    ]
  ]

  ask turtles [
    if extremist? and not member? self extremists [
      set extremists lput self extremists
      set color cyan
    ]
  ]
end

to setup-disease
  reset-ticks
  ask turtles [
    set infected? False
    set recovered? false
    set susceptible? False
    set vaccinated? False
  ]
end

to vaccinate-non-extremists
  ask turtles with [extremist? = False][
    set vaccinated? True
  ]
  ask turtles with [extremist? = True] [
    set vaccinated? False
  ]
end

to vaccinate-random-people
  ask turtles [
    set vaccinated? True
  ]

  ask n-of length extremists turtles  [
    set vaccinated? False
  ]
end

to transmit-disease
  spread-disease
  recover
end

to infect
  ask turtles with [vaccinated? = False][
    set susceptible? True
  ]
  let susceptible-turtles turtles with [susceptible? = True]
  if count susceptible-turtles >= 2 [
    ask n-of 2 susceptible-turtles [
      set infected? True
      set color red
    ]
  ]
end

to spread-disease
  ask turtles with [susceptible? = True and recovered? = False] [
    let n-infected-neighbors 0
    ask turtles-on neighbors [
      if infected? = True [
        set n-infected-neighbors n-infected-neighbors + 1
      ]
    ]

    if random-float 1 <= (1 - exp (- 0.05 * n-infected-neighbors)) [
      set infected? True
      set color red
    ]
  ]
  tick
end

to recover
  ask turtles with [infected? = True] [
    if random-float 1 <= 0.001 [
      set recovered? True
      set infected? False
      set susceptible? False
      set color green
    ]
  ]
end

to visualize-info-network
  ask turtles [
    set size (sqrt count my-links) / 3
  ]
  layout-spring turtles links 0.2 2 0.5
  ask turtles [
    facexy 0 0
    fd (distancexy 0 0) / 100
  ]
end

to visualize-physical-space
  ask turtles [
    move-to location
  ]
end

to uniform-size
  ask turtles [
    set size 1
  ]
end

to degree-size
  ask turtles [
    set size (sqrt count my-links) / 3
  ]
end
"""
end
