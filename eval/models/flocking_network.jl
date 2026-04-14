# ── Flocking with Network Links ───────────────────────────────────
# Source: modelingcommons #3632
# NW extension: declared but not actively used for graph algorithms
# Turtles form positive/negative weighted links based on distance
# and adjust heading via coupling, coherence, separation, alignment.

struct FlockingNetworkModel <: AbstractBenchmarkModel end

model_name(::FlockingNetworkModel) = "Flocking Network"
n_ticks(::FlockingNetworkModel) = 200
tracked_globals(::FlockingNetworkModel) = ["num-links-fn", "avg-heading-fn"]
world_dims(::FlockingNetworkModel) = (-40, 40, -40, 40)

function netlogo_code(::FlockingNetworkModel)
"""
extensions [nw]

globals [
  population
  maximum-separation
  minimum-separation
  coupling-strength
  coherence-strength
  separation-strength
  alignment-strength
  showlink
  showlabel
  num-links-fn
  avg-heading-fn
]

turtles-own [
  positiv-neighbors
  negativ-neighbors
  avg-head-pos
  avg-head-neg
]

undirected-link-breed [ positiv-links positiv-link ]
undirected-link-breed [ negativ-links negativ-link ]

positiv-links-own [ weight ]
negativ-links-own [ weight ]

to setup
  clear-all
  set population 200
  set maximum-separation 3
  set minimum-separation 1
  set coupling-strength 0.5
  set coherence-strength 0.5
  set separation-strength 0.5
  set alignment-strength 0.5
  set showlink false
  set showlabel false
  crt population [
    setxy random-xcor random-ycor
  ]
  reset-ticks
end

to go
  ask positiv-links [ die ]
  ask negativ-links [ die ]
  ask turtles [ flock ]
  if not showlink [ ask links [ hide-link ] ]
  ask turtles [ fd 1 ]
  set num-links-fn count links
  set avg-heading-fn mean [heading] of turtles
end

to flock
  find-negativ-neighbors
  find-positiv-neighbors
  link-negativ-neighbors
  link-positiv-neighbors
  ifelse showlabel [
    set label word count positiv-neighbors ","
    set label word label count negativ-neighbors
  ] [
    set label ""
  ]
  set avg-head-pos 0
  set avg-head-neg 0
  if any? positiv-neighbors [
    set avg-head-pos mean [[heading] of self] of positiv-neighbors
  ]
  if any? negativ-neighbors [
    set avg-head-neg mean [[heading] of self] of negativ-neighbors
  ]
  set heading heading + coupling-strength * ( coherence-strength * (avg-head-pos - heading) + separation-strength * ( 180 + avg-head-neg - heading ) + alignment-strength * ( (0.5 * (avg-head-neg + avg-head-pos)) - heading))
end

to find-negativ-neighbors
  set negativ-neighbors other turtles in-radius minimum-separation
end

to find-positiv-neighbors
  let my-neg-neigh negativ-neighbors
  ifelse any? negativ-neighbors [
    set positiv-neighbors other turtles in-radius maximum-separation with [ not member? self my-neg-neigh ]
  ] [
    set positiv-neighbors other turtles in-radius maximum-separation
  ]
end

to link-negativ-neighbors
  if any? negativ-neighbors [
    create-negativ-links-with negativ-neighbors [
      set color red
      set weight separation-strength
    ]
  ]
end

to link-positiv-neighbors
  if any? positiv-neighbors [
    create-positiv-links-with positiv-neighbors [
      set color blue
      set weight coherence-strength
    ]
  ]
end
"""
end
