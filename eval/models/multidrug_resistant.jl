# ── MultidrugResistant model (CSS600 ClassModels / GIS) ──────────────

struct MultidrugResistantModel <: AbstractBenchmarkModel end

model_name(::MultidrugResistantModel) = "MultidrugResistant"
n_ticks(::MultidrugResistantModel) = 200
tracked_globals(::MultidrugResistantModel) = ["dead-patients", "recovered-patients"]
world_dims(::MultidrugResistantModel) = (-102, 102, -64, 64)
topology(::MultidrugResistantModel) = (false, false)

const MDR_DIR = "/Users/username/Projects/netlogo/ClassModels/CSS600Models/MultidrugResistant"

function netlogo_code(::MultidrugResistantModel)
    asc_path = joinpath(MDR_DIR, "data", "mincosf1.asc")
"""
extensions [gis]

breed [nurses nurse]
breed [patients patient]
breed [cleaners cleaner]

nurses-own [
  clean
]

globals[
  randomSeed
  elevation-dataset
  death-rate
  patch-patch-spread
  carrier-patch-spread
  dead-patients
  recovered-patients
  num-patients num-nurses num-cleaners
  num-infected-patients num-infected-nurses
  Environmental-spread
  Enhanced-cleaning
  ICU-Isolation
  clean-nurses
]

turtles-own[
  t-infected?
  energy
]

patches-own[
  exit
  elevation
  p-infected?
  p-infect-time
]


to setup
  ca
  set num-patients 20
  set num-nurses 20
  set num-cleaners 15
  set num-infected-patients 1
  set num-infected-nurses 0
  set Environmental-spread 0
  set Enhanced-cleaning false
  set ICU-Isolation false
  set clean-nurses 100
  constants
  file-close
  set elevation-dataset gis:load-dataset "$(asc_path)"
  gis:set-world-envelope gis:envelope-of elevation-dataset
  gis:apply-raster elevation-dataset "elevation"
  ask patches [set p-infected? false ]
  ask patches with [elevation = 0 ][set exit 1]
  ask patches [ifelse (elevation <= 0) or (elevation >= 0)[][set elevation 9999999]]
  show_elevation

  ask n-of num-patients patches with [
    elevation < 9999999 and exit != 1 and (pycor = one-of (range (- 64) (- 53)) or (pycor = one-of (range (- 45) (- 34))))
  ][
    sprout 1 [
      set color gray
      set breed patients
      set size 2
      set shape "person"
      set energy 2419200
      set dead-patients 0
      set recovered-patients 0
    ]
  ]
  ifelse ICU-Isolation [
    ask n-of num-nurses patches with [
      elevation < 9999999 and exit != 1 and pycor = one-of (range (- 51) (- 46))][
      sprout 1 [
        set color blue - 2
        set breed nurses
        set size 2
        set shape "person"
      ]
    ]
    ask n-of num-cleaners patches with [
      elevation < 9999999 and exit != 1 and pycor = one-of (range (- 51) (- 46))][
      sprout 1 [
        set color blue - 2
        set breed cleaners
        set size 2
        set shape "person"
      ]
    ]
  ][
    ask n-of num-nurses patches with [
      elevation < 9999999 and exit != 1][
      sprout 1 [
        set color blue - 2
        set breed nurses
        set size 2
        set shape "person"
      ]
    ]
    ask n-of num-cleaners patches with [
      elevation < 9999999 and exit != 1][
      sprout 1 [
        set color blue - 2
        set breed cleaners
        set size 2
        set shape "person"
      ]
    ]
  ]
  ask turtles [set t-infected? false]
  infect
  recolor
  reset-ticks
end

to infect
  ask n-of num-infected-patients patients [
    set t-infected? true
    set p-infected? true
  ]
  ask n-of num-infected-nurses nurses [
    set t-infected? true
    set p-infected? true
  ]
end

to recolor
  ask nurses [
    set color ifelse-value t-infected? [ green ] [ blue - 2 ]
  ]
  ask patients [
    set color ifelse-value t-infected? [ red ] [ gray ]
  ]
  ask cleaners [
    set color ifelse-value t-infected? [ green ] [ orange ]
  ]
  ask patches [ if elevation < 9999999 and pycor < (- 33) [
    set pcolor ifelse-value p-infected? [ yellow ] [ blue + 4]]
  ]
end

to constants
  set death-rate 0.56
  set patch-patch-spread 0.025
  set carrier-patch-spread Environmental-spread
end

to spread-infection
  ask patches with [ p-infected? ] [
    ask neighbors with [p-infected? = false] [
      if (random-float 100.0 < patch-patch-spread) and pcolor != gray
      [set p-infected? true]
    ]
  ]
  ask patients with [ t-infected? ] [
    ask turtles-here [ set t-infected? true ]
    if random-float 100 < Environmental-spread [set p-infected? true]
  ]
  ask cleaners with [ t-infected? ] [
    ask turtles-here with [breed != patients] [ set t-infected? true ]
    if random-float 100 < Environmental-spread [set p-infected? true]
  ]
  ask nurses with [ t-infected? ] [
    ask turtles-here [ set t-infected? true ]
    if random-float 100 < Environmental-spread [set p-infected? true]
  ]
  ask turtles with [ p-infected? ] [
    set t-infected? true
  ]
  ask patients with [ t-infected? ] [
    set energy energy - 1
  ]
  if Enhanced-cleaning [
    ask cleaners with [ p-infected? ] [
      set p-infected? false
      set t-infected? false
    ]
  ]
end

to go
  if all? patients [t-infected?] [stop]
  if all? patches [p-infected?] [stop]
  spread-infection
  recolor
  death
  move
  tick
end

to death
  ask patients with [ t-infected? ] [
    if energy < 0 [
      ifelse random-float 100 > death-rate
        [ set recovered-patients recovered-patients + 1 set t-infected? false ]
        [ set dead-patients dead-patients + 1 die ]
    ]
  ]
end

to move
  ask nurses [set clean n-of ((clean-nurses * num-nurses) / 100) nurses]
  ask nurses [
    ifelse (not any? turtles-on patch-ahead 1 and [pcolor] of patch-ahead 1 != gray)
    [ fd 1 ][ rt random 180 ]
    if ICU-Isolation and [pycor] of patch-ahead 1 = (- 33) [ rt 180]
    if clean = true and [pycor] of patch-ahead 1 = one-of (range (- 33) (- 45) (- 53)) [set t-infected? false set p-infected? false]
    if not can-move? 1 [rt random 180]
    if t-infected? and any? turtles-on patch-ahead 1 [ask turtles-on patch-ahead 1 [set t-infected? true]]
    if not can-move? 1 and t-infected? = true and p-infected? = false [set p-infected? true]
  ]
  ask cleaners [
    left random 90
    right random 90
    ifelse [pcolor] of patch-ahead 1 != gray
    [fd 1 ] [ rt random 180 ]
    if ICU-Isolation and [pycor] of patch-ahead 1 = (- 33) [ rt 180]
    if not can-move? 1 [rt random 180]
    if not can-move? 1 and t-infected? = true and p-infected? = false [set p-infected? true]
  ]
  ask patients [
    if not t-infected? [
      fd 0.25
      left 90
    ]
  ]
end

to show_elevation
  ask patches [
    ifelse elevation < 9999999
      [ifelse pycor < (- 33) [set pcolor blue + 4][set pcolor pink + 3]]
      [set pcolor gray]
  ]
end
"""
end

function extra_shapes(::MultidrugResistantModel)
"""
person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Rectangle -2674135 true false 60 105 75 120
Rectangle -2674135 true false 225 105 240 120

person service
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Rectangle -13345367 true false 135 90 165 195
"""
end
