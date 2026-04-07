# ── DiffusionOfHIV model (CSS600 ClassModels / GIS) ──────────────────

struct DiffusionOfHIVModel <: AbstractBenchmarkModel end

model_name(::DiffusionOfHIVModel) = "DiffusionOfHIV"
n_ticks(::DiffusionOfHIVModel) = 100
tracked_globals(::DiffusionOfHIVModel) = ["pct-infected"]
world_dims(::DiffusionOfHIVModel) = (-200, 200, -200, 200)
topology(::DiffusionOfHIVModel) = (true, true)

const HIV_DIR = "/Users/username/Projects/netlogo/ClassModels/CSS600Models/DiffusionOfHIV"

function netlogo_code(::DiffusionOfHIVModel)
    prj_path = joinpath(HIV_DIR, "data", "states.prj")
    shp_path = joinpath(HIV_DIR, "data", "states.shp")
"""
extensions [ gis ]

globals[
  randomSeed
  us-map-dataset
  num_infected
  num_uninfected
  pct-infected
  chance-to-infect-others1
  list-pctHIV
  Condom-Use
  Risk-assessment
  prob-for-long-distance-travel
]
turtles-own[
  infected?
  coupled?
  partner
  chance-to-infect-others
  age
  traveled?
  last-position
  myID
]
patches-own[
  centroid?
  ID
  popu
  pctHIV
  maxticket
  minticket
  red-here
  green-here
]

to setup
  ca
  reset-ticks
  set Condom-Use false
  set Risk-assessment 2
  set prob-for-long-distance-travel 66
  ; gis:load-coordinate-system removed - not supported in Julia impl
  set us-map-dataset gis:load-dataset "$(shp_path)"
  gis:set-world-envelope gis:envelope-of us-map-dataset

  foreach gis:feature-list-of us-map-dataset
  [ feat -> let center-point gis:location-of gis:centroid-of feat
    if center-point != false [
      if length center-point >= 2 [
        let cx item 0 center-point
        let cy item 1 center-point
        if cx >= min-pxcor and cx <= max-pxcor and cy >= min-pycor and cy <= max-pycor [
          ask patch cx cy [
            set centroid? true
            set ID gis:property-value feat "ID"
            set popu gis:property-value feat "POPU"
            set pctHIV gis:property-value feat "pctHIV"
            set minticket gis:property-value feat "min"
            set maxticket gis:property-value feat "max"
          ]
        ]
      ]
    ]
  ]

  ; drawing operations removed for headless eval
  ; gis:set-drawing-color / gis:fill / gis:draw not needed

  gis:apply-coverage us-map-dataset "ID" "ID"

  let y 1
  while [y <= 49] [
    ask patches with [centroid? = true and ID = y]
    [let popu1 round (popu / 100000)
      set num_infected (round (pctHIV * popu1) )
      set num_uninfected popu1 - num_infected]
    repeat num_infected [ask one-of patches with [ID = y] [sprout 1 [set shape "person" set size 1.5 set infected? true assign-color set age random 5]]]
    repeat num_uninfected [ask one-of patches with [ID = y] [sprout 1 [set shape "person" set size 1.5 set infected? false assign-color set age random 5]]]
    set y y + 1
  ]
  check-switches
end

to go
  ask turtles [if age = 6 [ask patch-here [sprout 1 [set shape "person" set size 1.5
    ifelse random 100 = 1 [set infected? true][set infected? false]
    assign-color set age random 5]]die]]

  check-switches

  ask turtles[
    set myID [ID] of patch-here
    set coupled? false
    set partner nobody]

  ask turtles[
    move
    couple
  ]

  ask turtles with [coupled? = true] [interact]
  ask turtles [set age age + 1]

  ask turtles with [traveled? = true][move-to last-position]

  set pct-infected (count turtles with [color = red]) / (count turtles)
  tick
end

to move
  set traveled? false
  ifelse random 100 < prob-for-long-distance-travel [
    set last-position patch-here
    set traveled? true
    let pick (random 1130 + 1)
    ask patches with [centroid? = true] [if minticket <= pick and maxticket >= pick [ask myself [move-to one-of patches with [ID = [ID] of myself] ]]]
  ][
    let nearby-patches patches in-radius 5
    set nearby-patches nearby-patches with [ID = [myID] of myself]
    if any? nearby-patches [
      move-to one-of nearby-patches
    ]
  ]
end

to couple
  let potential-partner one-of turtles in-radius 5
                          with [not coupled? and myID = [myID] of myself]
  if potential-partner != nobody
  [ set partner potential-partner
    set coupled? true
    ask partner [ set coupled? true ]
    ask partner [ set partner myself ]]
end

to interact
  if infected? = true [ if random-float 100 < chance-to-infect-others [ask partner [set infected? true set color red]]]
end

to assign-color
  ifelse not infected?
    [ set color green ][set color red]
end

to check-switches
  set chance-to-infect-others1 100
  if Condom-Use
    [ set chance-to-infect-others1 chance-to-infect-others1 * 0.2]
  if Risk-assessment = 4
    [set chance-to-infect-others1 0]
  ask turtles with [infected? = true] [set chance-to-infect-others chance-to-infect-others1 ]
end
"""
end
