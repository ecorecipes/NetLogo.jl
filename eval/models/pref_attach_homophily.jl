# ── Preferential Attachment Homophily Networks (NW Extension) ──────────
# Source: modelingcommons #4403 (Preferential_Attachment,_Homophily_etc._Networks)
# NW extension: nw:set-context, nw:betweenness-centrality, nw:closeness-centrality
# Network formation model combining homophily (link to similar wealth)
# and resource dependence (link to wealthier nodes).
# Tests NW centrality metrics + network construction dynamics.

struct PrefAttachHomophilyModel <: AbstractBenchmarkModel end

model_name(::PrefAttachHomophilyModel) = "Pref Attach Homophily"
n_ticks(::PrefAttachHomophilyModel) = 150
tracked_globals(::PrefAttachHomophilyModel) = ["number-homophily", "count links"]

function world_dims(::PrefAttachHomophilyModel)
    return (min_pxcor=-25, max_pxcor=25, min_pycor=-25, max_pycor=25)
end

function setup_commands(::PrefAttachHomophilyModel)
    return ""
end

netlogo_code(::PrefAttachHomophilyModel) = raw"""
extensions [nw]

globals [number-homophily number-contagion flag
         number-of-nodes number-of-links probability-of-homophily layout-on? plot-on?]

turtles-own [wealth my-probability-of-homophily]

to setup
  clear-all
  set number-of-nodes 80
  set number-of-links 150
  set probability-of-homophily 95
  set layout-on? true
  set plot-on? false
  nw:set-context turtles links
  ask patches [set pcolor white]
  create-turtles number-of-nodes [
    set wealth random 20
    set shape "circle"
    set color scale-color green wealth -5 25
    set size 1
    setxy random-xcor random-ycor
    set my-probability-of-homophily random probability-of-homophily
  ]
  reset-ticks
end

to go
  if not any? turtles [stop]
  ask links [set color gray]
  ask one-of turtles [
    let partner find-partner wealth
    if partner != nobody [
      make-node-homophily partner
    ]
  ]
  if number-homophily >= number-of-links [
    ask links [set color gray]
    stop
  ]
  set number-homophily number-homophily + 1
  tick
  if layout-on? [layout]
end

to make-node-homophily [node]
  create-link-with node [set color red]
  move-to node
  fd 8
end

to-report find-partner [w]
  ifelse random 100 < my-probability-of-homophily [
    report one-of other turtles with [wealth = w or wealth = w - 1 or wealth = w + 1]
  ] [
    report one-of other turtles with [wealth > w]
  ]
end

to resize-nodes
  ifelse all? turtles [size <= 1] [
    ask turtles [set size sqrt sqrt count link-neighbors]
  ] [
    ask turtles [set size 1]
  ]
end

to layout
  repeat 3 [
    let factor sqrt count turtles
    if factor = 0 [set factor 1]
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
  ]
end
"""
