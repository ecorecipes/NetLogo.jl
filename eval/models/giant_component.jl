# ── Giant Component model (NetLogo models library) ───────────────────

struct GiantComponentModel <: AbstractBenchmarkModel end

model_name(::GiantComponentModel) = "Giant Component"
n_ticks(::GiantComponentModel) = 200
tracked_globals(::GiantComponentModel) = ["giant-component-size", "num-edges", "fraction-in-giant", "num-components"]
world_dims(::GiantComponentModel) = (-45, 45, -45, 45)
topology(::GiantComponentModel) = (false, false)

function netlogo_code(::GiantComponentModel)
"""
globals [randomSeed num-nodes
         component-size giant-component-size giant-start-node
         num-edges fraction-in-giant num-components]

turtles-own [explored?]

to setup
  clear-all
  resize-world (- 45) 45 (- 45) 45
  set num-nodes 80
  set-default-shape turtles "circle"
  make-turtles
  find-all-components
  color-giant-component
  update-globals
  reset-ticks
end

to make-turtles
  crt num-nodes
  layout-circle turtles max-pxcor - 1
end

to go
  if ((2 * count links) >= ((count turtles) * (count turtles - 1))) [
    stop
  ]
  add-edge
  find-all-components
  color-giant-component
  ask links [ set color [color] of end1 ]
  update-globals
  tick
end

to update-globals
  set num-edges count links
  set fraction-in-giant giant-component-size / count turtles
  set num-components length all-components
end

to-report all-components
  let comps []
  ask turtles [ set explored? false ]
  loop [
    let start one-of turtles with [ not explored? ]
    if start = nobody [ report comps ]
    set component-size 0
    ask start [ explore (gray + 2) ]
    set comps lput component-size comps
  ]
end

to find-all-components
  ask turtles [ set explored? false ]
  set giant-component-size 0
  loop [
    let start one-of turtles with [ not explored? ]
    if start = nobody [ stop ]
    set component-size 0
    ask start [ explore (gray + 2) ]
    if component-size > giant-component-size [
      set giant-component-size component-size
      set giant-start-node start
    ]
  ]
end

to explore [new-color]
  if explored? [ stop ]
  set explored? true
  set component-size component-size + 1
  set color new-color
  ask link-neighbors [ explore new-color ]
end

to color-giant-component
  ask turtles [ set explored? false ]
  ask giant-start-node [ explore red ]
end

to add-edge
  let node1 one-of turtles
  let node2 one-of turtles
  ask node1 [
    ifelse link-neighbor? node2 or node1 = node2 [
      add-edge
    ] [
      create-link-with node2
    ]
  ]
end
"""
end
