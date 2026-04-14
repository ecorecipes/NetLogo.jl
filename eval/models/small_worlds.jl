# ── Small Worlds model (NetLogo models library) ────────────────────

struct SmallWorldsModel <: AbstractBenchmarkModel end

model_name(::SmallWorldsModel) = "Small Worlds"
n_ticks(::SmallWorldsModel) = 80
tracked_globals(::SmallWorldsModel) = ["clustering-coefficient", "average-path-length", "num-rewired"]
world_dims(::SmallWorldsModel) = (-17, 17, -17, 17)

function netlogo_code(::SmallWorldsModel)
"""
globals [randomSeed num-nodes rewiring-probability
         clustering-coefficient average-path-length
         clustering-coefficient-of-lattice average-path-length-of-lattice
         infinity num-rewired]

turtles-own [
  node-clustering-coefficient
  distance-from-other-turtles
]

links-own [
  rewired?
]

to setup
  clear-all
  resize-world (- 17) 17 (- 17) 17
  set num-nodes 40
  set rewiring-probability 0.3
  set infinity 99999
  set-default-shape turtles "circle"
  crt num-nodes [ set color gray + 2 ]
  layout-circle (sort turtles) max-pxcor - 1
  let success? false
  while [not success?] [
    wire-them
    set success? do-calculations
  ]
  set clustering-coefficient-of-lattice clustering-coefficient
  set average-path-length-of-lattice average-path-length
  set num-rewired 0
  reset-ticks
end

to go
  let potential-edges links with [not rewired?]
  if not any? potential-edges [ stop ]
  ask one-of potential-edges [
    set rewired? true
    if random-float 1 < rewiring-probability [
      let node1 end1
      if [count link-neighbors] of end1 < (count turtles - 1) [
        let node2 one-of turtles with [(self != node1) and (not link-neighbor? node1)]
        ask node1 [ create-link-with node2 [ set color cyan set rewired? true ] ]
        set num-rewired num-rewired + 1
        die
      ]
    ]
  ]
  do-calculations
  tick
end

to wire-them
  let n 0
  while [n < count turtles] [
    make-edge turtle n turtle ((n + 1) mod count turtles)
    make-edge turtle n turtle ((n + 2) mod count turtles)
    set n n + 1
  ]
end

to make-edge [node1 node2]
  ask node1 [ create-link-with node2 [ set rewired? false ] ]
end

to-report do-calculations
  let connected? true
  find-path-lengths
  let num-connected-pairs sum [length remove infinity (remove 0 distance-from-other-turtles)] of turtles
  ifelse (num-connected-pairs != (count turtles * (count turtles - 1))) [
    set average-path-length infinity
    set connected? false
  ] [
    set average-path-length (sum [sum distance-from-other-turtles] of turtles) / num-connected-pairs
  ]
  find-clustering-coefficient
  report connected?
end

to find-clustering-coefficient
  ifelse all? turtles [count link-neighbors <= 1] [
    set clustering-coefficient 0
  ] [
    let total 0
    ask turtles with [count link-neighbors <= 1]
      [ set node-clustering-coefficient "undefined" ]
    ask turtles with [count link-neighbors > 1] [
      let hood link-neighbors
      set node-clustering-coefficient (2 * count links with [in-neighborhood? hood] /
                                        ((count hood) * (count hood - 1)))
      set total total + node-clustering-coefficient
    ]
    set clustering-coefficient total / count turtles with [count link-neighbors > 1]
  ]
end

to-report in-neighborhood? [hood]
  report (member? end1 hood and member? end2 hood)
end

to find-path-lengths
  ask turtles [ set distance-from-other-turtles [] ]
  let i 0
  let j 0
  let k 0
  let node1 one-of turtles
  let node2 one-of turtles
  let node-count count turtles
  while [i < node-count] [
    set j 0
    while [j < node-count] [
      set node1 turtle i
      set node2 turtle j
      ifelse i = j [
        ask node1 [ set distance-from-other-turtles lput 0 distance-from-other-turtles ]
      ] [
        ifelse [link-neighbor? node1] of node2 [
          ask node1 [ set distance-from-other-turtles lput 1 distance-from-other-turtles ]
        ] [
          ask node1 [ set distance-from-other-turtles lput infinity distance-from-other-turtles ]
        ]
      ]
      set j j + 1
    ]
    set i i + 1
  ]
  set i 0
  set j 0
  let dummy 0
  while [k < node-count] [
    set i 0
    while [i < node-count] [
      set j 0
      while [j < node-count] [
        set dummy ((item k [distance-from-other-turtles] of turtle i) +
                    (item j [distance-from-other-turtles] of turtle k))
        if dummy < (item j [distance-from-other-turtles] of turtle i) [
          ask turtle i [
            set distance-from-other-turtles replace-item j distance-from-other-turtles dummy
          ]
        ]
        set j j + 1
      ]
      set i i + 1
    ]
    set k k + 1
  ]
end
"""
end
