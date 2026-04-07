# ── Rise of Radicalism model (CSS645 ClassModels / GIS) ──────────────

struct RiseOfRadicalismModel <: AbstractBenchmarkModel end

model_name(::RiseOfRadicalismModel) = "Rise of Radicalism"
n_ticks(::RiseOfRadicalismModel) = 50
tracked_globals(::RiseOfRadicalismModel) = ["percent-radicals", "overtaken-townships", "total-radicalism?"]
world_dims(::RiseOfRadicalismModel) = (-377, 377, -277, 277)
topology(::RiseOfRadicalismModel) = (true, true)

const RADICALISM_DIR = "/Users/username/Projects/netlogo/ClassModels/CSS645Models/Rise_of_Radicalism"

function netlogo_code(::RiseOfRadicalismModel)
    png_path = joinpath(RADICALISM_DIR, "data", "KIMB_1.png")
    dem_path = joinpath(RADICALISM_DIR, "data", "KIMB_DEM_1.asc")
    tslb_path = joinpath(RADICALISM_DIR, "data", "KIMB_YSLB_2.asc")
    veg_path = joinpath(RADICALISM_DIR, "data", "KIMB_VEG_1.asc")
    wet_path = joinpath(RADICALISM_DIR, "data", "KIMB_WET_2.asc")
"""
extensions [gis nw]

breed [local-populations local-population]
breed [area-of-saturations area-of-saturation]
breed [terrorist-cluster terror-cluster]
breed [township area-of-influence]
terrorist-cluster-own [ radicalism l-type influence radio-broadcaster]

globals [
  randomSeed
  scale-free
  avg-green-influence avg-red-influence
  avg-green-radicalism avg-red-radicalism
  percent-radicals percent-neutrals percent-non-radicals
  green-radicalism red-radicalism
  overtaken-townships
  total-radicalism?
  tslb-dataset dem-dataset radical-spread-value-dataset wetness-dataset
  cell-saturation border randmovement
  count-clusters
  component-size giant-component-size giant-start-node
  wd wd-1 wd-2 wd-3 wd-4 wd-5 wd-6 wd-7
  link-distance degree leader-emergence distance-add-cell
  secondary-order-leadership growth information-spread-probability
  max-emergent-leaders num-havens agent-distribution-away-cities
  radio-power num-training-environments
  green-influence red-influence amt-initial-radicalism
  clustered-vs-scale-free-network radio-communication
]

patches-own [
  Wetness cluster elevation radicalism-spread-area
  radical-spread-value tslb slope cell spread-ability
  radicalism-spread-area-time explored? direction-flow
]

to create-cell [ xcor-v ycor-v first-order ]
  let xcor-l xcor-v
  let ycor-l ycor-v
  let radical amt-initial-radicalism * 0.01
  let inf red-influence * 0.01
  let c red

  if ( first-order = 0 ) [
    if random (100) > agent-distribution-away-cities [
      let rx 1.0
      let ry 1.0
      if random (100) < 50 [ set rx -1.0 ]
      if random (100) < 50 [ set ry -1.0 ]
      ask one-of township [
        set xcor-l xcor + (random (20) * rx)
        set ycor-l ycor + (random (20) * ry)
      ]
      if xcor-l > max-pxcor [set xcor-l max-pxcor]
      if xcor-l < min-pxcor [set xcor-l min-pxcor]
      if ycor-l > max-pycor [set ycor-l max-pycor]
      if ycor-l < min-pycor [set ycor-l min-pycor]
    ]
    set radical random (25) * 0.01
    set inf random ( green-influence ) * 0.01
    if radical > 1 [ print radical ]
  ]

  let partner nobody
  create-terrorist-cluster 1 [
    set shape "person"
    set xcor xcor-l
    set ycor ycor-l
    set size 10
    set radio-broadcaster false
    set l-type first-order
    set color c
    set influence inf
    set radicalism radical
    if scale-free = true [
      set partner (min-one-of (other terrorist-cluster with [not link-neighbor? myself] in-radius link-distance)
        [distance myself])
    ]
    if partner != nobody [ create-link-with partner]
  ]
end

to-report find-partner
  report [one-of both-ends] of one-of links
end

to setup-scale-free
  set scale-free not clustered-vs-scale-free-network
end

to setup
  __clear-all-and-reset-ticks
  set-default-shape turtles "circle"
  set link-distance 25
  set degree 8
  set leader-emergence 7
  set distance-add-cell 69
  set secondary-order-leadership 34
  set growth 1.15
  set information-spread-probability 15
  set max-emergent-leaders 219
  set num-havens 9
  set agent-distribution-away-cities 26
  set radio-power 10
  set num-training-environments 5
  set green-influence 51
  set red-influence 50
  set amt-initial-radicalism 67
  set clustered-vs-scale-free-network true
  set radio-communication true
  ; import-pcolors-rgb removed - not supported in headless Julia
  ask patches [set slope 1]
  ask patches [set cell 1]
  ask patches [set radicalism-spread-area-time 1]
  set border patches with [ count neighbors != 8 ]
  setup-patches
  setup-scale-free
  ask one-of patches [ set pcolor 1 ]
  create-influence-areas
end

to create-influence-areas
  repeat ( num-havens ) [
    create-township 1 [
      set shape "house"
      set xcor random-xcor
      set ycor random-ycor
      set size 20
      set color white - 1
    ]
  ]
  repeat ( num-training-environments ) [
    create-terrorist-cluster 1 [
      set shape "flag"
      set xcor random-xcor
      set ycor random-ycor
      set size 15
      set influence red-influence * 0.01
      set radicalism 1.3
      set color red
    ]
  ]
end

to update-links
  if random (100) < 2 and scale-free = false [
    clear-links
    foreach sort-on [ influence ] terrorist-cluster
    [ tc-agent -> ask tc-agent [
      let ld link-distance
      repeat degree [
        let choice (min-one-of (other terrorist-cluster with [not link-neighbor? myself] in-radius ld)
          [distance myself])
        if choice != nobody [
          create-link-with choice
          ask my-links [ set color gray ]
        ]
      ]
    ]]
  ]
end

to emerge-radicals
  if random (100) < secondary-order-leadership [
    let x random-xcor
    let y random-ycor
    let allblack true
    ask one-of patches with [ pcolor = 1 ] [
      ask neighbors4 [ if pcolor != 1 [ set allblack false ] ]
      set x pxcor
      set y pycor
    ]
    if allblack = true [ create-cell x y 1 ]
  ]
end

to create-pro-policy-leader
  if random (100) < leader-emergence [
    let count-leaders count terrorist-cluster with [ l-type = 0 ]
    if count-leaders < max-emergent-leaders [
      let x random-xcor
      let y random-ycor
      create-cell x y 0
      ask patch x y [
        sprout-local-populations 1 [
          ask patches in-cone 1 360 [
            sprout-local-populations 1 [
              set radicalism-spread-area radicalism-spread-area - 100
            ]
          ]
        ]
        ; display removed - GUI only
      ]
    ]
  ]
end

to go
  ask border [ ask turtles-here [ die ] ]
  ask turtles [calc-slope]
  set randmovement random 30

  ask area-of-saturations [
    ask neighbors [set spread-ability (((log (tslb + 1) 2.7) * (radical-spread-value + 1)) * (((log 4 1.8) + 1) / growth))]
  ]
  ask turtles [calc-cellinfluence]

  ask local-populations [
    ask neighbors with [ (randmovement < ((spread-ability * cell) + (slope * 0.5))) and radicalism-spread-area = 100 ][emerge]
    set breed area-of-saturations
  ]
  ask area-of-saturations [
    ask neighbors with [ ((randmovement + (radicalism-spread-area-time * 10)) < ((spread-ability * cell) + (slope * 0.5))) and radicalism-spread-area = 100 ][emerge]
  ]
  set cell-saturation ((count patches with [pcolor = 1]) * 0.0081)
  fade-area-of-saturations
  update-links
  create-pro-policy-leader
  emerge-radicals
  update-network-function
  check-townships
  set-colors
  plot-items
  tick
end

to check-townships
  ask township [
    if ([pcolor] of patch xcor ycor = 1) [ set color red ]
  ]
end

to set-colors
  ask terrorist-cluster [
    if radicalism < 0.3 [ set color green ]
    if radicalism >= 0.3 and radicalism < 0.7 [ set color gray ]
    if radicalism >= 0.8 and radicalism < 0.9 [ set color red ]
    if radicalism >= 0.9 [ set color red ]
  ]
end

to plot-items
  let rad-threshold 0.7
  if count terrorist-cluster != 0 [set percent-radicals count terrorist-cluster with [ radicalism > rad-threshold ] / count terrorist-cluster * 100 ]
  if count terrorist-cluster != 0 [set percent-neutrals count terrorist-cluster with [ radicalism > 0.3 and radicalism < 0.7 ] / count terrorist-cluster * 100 ]
  if count terrorist-cluster != 0 [set percent-non-radicals count terrorist-cluster with [ radicalism < 0.3 ] / count terrorist-cluster * 100 ]
  if count terrorist-cluster != 0 [
    let rad 0
    ask terrorist-cluster [ set rad rad + radicalism ]
    set total-radicalism? ( rad / count terrorist-cluster ) * 100
  ]
  set overtaken-townships ( count township with [ color = red ] / count township ) * 100.0

  set avg-green-influence 0
  set avg-green-radicalism 0
  ask terrorist-cluster with [ l-type = 0 ] [
    set avg-green-influence avg-green-influence + influence
    set avg-green-radicalism avg-green-radicalism + radicalism
  ]
  set avg-green-influence avg-green-influence / count terrorist-cluster
  set avg-green-radicalism avg-green-radicalism / count terrorist-cluster

  let count-leaders count terrorist-cluster with [ l-type = 1 ]
  if count-leaders > 0 [
    set avg-red-influence 0
    set avg-red-radicalism 0
    ask terrorist-cluster with [ l-type = 1 ] [
      set avg-red-influence avg-red-influence + influence
      set avg-red-radicalism avg-red-radicalism + radicalism
    ]
    set avg-red-influence avg-red-influence / count terrorist-cluster
    set avg-red-radicalism avg-red-radicalism / count terrorist-cluster
  ]

  if count terrorist-cluster != 0 [
    let rad 0
    ask terrorist-cluster with [ l-type = 0 ] [ set rad rad + radicalism ]
    let denom count terrorist-cluster with [ l-type = 0 ]
    if denom != 0 [ set green-radicalism ( rad / denom ) * 100 ]
  ]
  if count terrorist-cluster != 0 [
    let rad 0
    ask terrorist-cluster with [ l-type = 1 ] [ set rad rad + radicalism ]
    let denom count terrorist-cluster with [ l-type = 1 ]
    if denom != 0 [ set red-radicalism ( rad / denom ) * 100 ]
  ]
end

to emerge
  sprout-local-populations 1
  [ set radicalism-spread-area radicalism-spread-area - 100 ]
  set pcolor black
end

to fade-area-of-saturations
  ask area-of-saturations [
    set radicalism-spread-area-time radicalism-spread-area-time + 1
    ifelse ( radicalism-spread-area-time > 7 )
      [set pcolor 1 die]
      [set pcolor 1]
  ]
end

to setup-patches
  ask patches [set radicalism-spread-area 100]
  set dem-dataset gis:load-dataset "$(dem_path)"
  set tslb-dataset gis:load-dataset "$(tslb_path)"
  set radical-spread-value-dataset gis:load-dataset "$(veg_path)"
  set wetness-dataset gis:load-dataset "$(wet_path)"
  gis:set-world-envelope (gis:envelope-of tslb-dataset)
  gis:apply-raster dem-dataset "elevation"
  gis:apply-raster tslb-dataset "tslb"
  gis:apply-raster radical-spread-value-dataset "radical-spread-value"
  gis:apply-raster wetness-dataset "wetness"
  ask patches [set tslb tslb + 1]
end

to calc-slope
  let e1 [elevation] of patch-at 0 1
  let s1 (e1 - [elevation] of patch-here) / 0.9
  ask patch-at 0 1 [set slope s1]
  let e2 [elevation] of patch-at 1 0
  let s2 (e2 - [elevation] of patch-here) / 0.9
  ask patch-at 1 0 [set slope s2]
  let e3 [elevation] of patch-at 0 -1
  let s3 (e3 - [elevation] of patch-here) / 0.9
  ask patch-at 0 -1 [set slope s3]
  let e4 [elevation] of patch-at -1 0
  let s4 (e4 - [elevation] of patch-here) / 0.9
  ask patch-at -1 0 [set slope s4]
  let e5 [elevation] of patch-at 1 -1
  let s5 (e5 - [elevation] of patch-here) / 0.9
  ask patch-at 1 -1 [set slope s5]
  let e6 [elevation] of patch-at -1 -1
  let s6 (e6 - [elevation] of patch-here) / 0.9
  ask patch-at -1 -1 [set slope s6]
  let e7 [elevation] of patch-at 1 1
  let s7 (e7 - [elevation] of patch-here) / 0.9
  ask patch-at 1 -1 [set slope s7]
  let e8 [elevation] of patch-at -1 1
  let s8 (e8 - [elevation] of patch-here) / 0.9
  ask patch-at -1 -1 [set slope s8]
end

to calc-cellinfluence
  if (direction-flow = "N")
  [ ask patch-at 0 1 [set cell wd]
    ask patch-at 1 1 [set cell wd-1]
    ask patch-at 1 0 [set cell wd-2]
    ask patch-at 1 -1 [set cell wd-3]
    ask patch-at 0 -1 [set cell wd-4]
    ask patch-at -1 -1 [set cell wd-5]
    ask patch-at -1 0 [set cell wd-6]
    ask patch-at -1 1 [set cell wd-7]]
  if (direction-flow = "NE")
  [ ask patch-at 0 1 [set cell wd-7]
    ask patch-at 1 1 [set cell wd]
    ask patch-at 1 0 [set cell wd-1]
    ask patch-at 1 -1 [set cell wd-2]
    ask patch-at 0 -1 [set cell wd-3]
    ask patch-at -1 -1 [set cell wd-4]
    ask patch-at -1 0 [set cell wd-5]
    ask patch-at -1 1 [set cell wd-6]]
  if (direction-flow = "E")
  [ ask patch-at 0 1 [set cell wd-6]
    ask patch-at 1 1 [set cell wd-7]
    ask patch-at 1 0 [set cell wd]
    ask patch-at 1 -1 [set cell wd-1]
    ask patch-at 0 -1 [set cell wd-2]
    ask patch-at -1 -1 [set cell wd-3]
    ask patch-at -1 0 [set cell wd-4]
    ask patch-at -1 1 [set cell wd-5]]
  if (direction-flow = "SE")
  [ ask patch-at 0 1 [set cell wd-5]
    ask patch-at 1 1 [set cell wd-6]
    ask patch-at 1 0 [set cell wd-7]
    ask patch-at 1 -1 [set cell wd]
    ask patch-at 0 -1 [set cell wd-1]
    ask patch-at -1 -1 [set cell wd-2]
    ask patch-at -1 0 [set cell wd-3]
    ask patch-at -1 1 [set cell wd-4]]
  if (direction-flow = "S")
  [ ask patch-at 0 1 [set cell wd-4]
    ask patch-at 1 1 [set cell wd-5]
    ask patch-at 1 0 [set cell wd-6]
    ask patch-at 1 -1 [set cell wd-7]
    ask patch-at 0 -1 [set cell wd]
    ask patch-at -1 -1 [set cell wd-1]
    ask patch-at -1 0 [set cell wd-2]
    ask patch-at -1 1 [set cell wd-3]]
  if (direction-flow = "SW")
  [ ask patch-at 0 1 [set cell wd-3]
    ask patch-at 1 1 [set cell wd-4]
    ask patch-at 1 0 [set cell wd-5]
    ask patch-at 1 -1 [set cell wd-6]
    ask patch-at 0 -1 [set cell wd-7]
    ask patch-at -1 -1 [set cell wd]
    ask patch-at -1 0 [set cell wd-1]
    ask patch-at -1 1 [set cell wd-2]]
  if (direction-flow = "W")
  [ ask patch-at 0 1 [set cell wd-2]
    ask patch-at 1 1 [set cell wd-3]
    ask patch-at 1 0 [set cell wd-4]
    ask patch-at 1 -1 [set cell wd-5]
    ask patch-at 0 -1 [set cell wd-6]
    ask patch-at -1 -1 [set cell wd-7]
    ask patch-at -1 0 [set cell wd]
    ask patch-at -1 1 [set cell wd-1]]
  if (direction-flow = "NW")
  [ ask patch-at 0 1 [set cell wd-1]
    ask patch-at 1 1 [set cell wd-2]
    ask patch-at 1 0 [set cell wd-3]
    ask patch-at 1 -1 [set cell wd-4]
    ask patch-at 0 -1 [set cell wd-5]
    ask patch-at -1 -1 [set cell wd-6]
    ask patch-at -1 0 [set cell wd-7]
    ask patch-at -1 1 [set cell wd]]
end

to update-network-function
  ask terrorist-cluster [
    ifelse random-float 100 < information-spread-probability and count (link-neighbors) > 0
    [
      let neighbors-num count link-neighbors
      let total 0
      ask link-neighbors [ set total total + radicalism ]
      set total total / neighbors-num
      set radicalism ( total * (1 - influence)) + radicalism * (influence)
      ask my-links [ set color white ]
    ][
      ask my-links [ set color gray ]
    ]
  ]
end
"""
end

function extra_shapes(::RiseOfRadicalismModel)
"""
house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45
"""
end
