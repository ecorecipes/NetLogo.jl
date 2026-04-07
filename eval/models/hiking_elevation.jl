# ── HikingElevation model (OtherClasses ClassModels / GIS) ───────────

struct HikingElevationModel <: AbstractBenchmarkModel end

model_name(::HikingElevationModel) = "HikingElevation"
n_ticks(::HikingElevationModel) = 200
tracked_globals(::HikingElevationModel) = ["track-elevation"]
world_dims(::HikingElevationModel) = (0, 261, 0, 183)
topology(::HikingElevationModel) = (false, false)

const HIKING_DIR = "/Users/username/Projects/netlogo/ClassModels/OtherClasses/HikingElevation"

function netlogo_code(::HikingElevationModel)
    asc_path = joinpath(HIKING_DIR, "Clipped-Grayson.asc")
"""
extensions [gis]

globals [
  randomSeed
  parkData
  min-elev
  max-elev
  goal-patch-x
  goal-patch-y
  start?
  entrance-patch-x
  entrance-patch-y
  track-elevation
  world-clock
  Percent-Preferring-Steepness
  Mean-hike-time-planned
  Standard-Deviation-hike-time-planned
  num-minutes-per-patch-traversed
  max-elev-change
]

patches-own [
  elevation
  tread-count
]

turtles-own[
  happy?
  steep?
  outbound?
  hike-time-elapsed
  hike-time-planned
  target
  closest
  my-elevation
  my-neighboring-patches
  counter
  turn-around-time
]

to setup
  ca
  reset-ticks
  set Percent-Preferring-Steepness 55
  set Mean-hike-time-planned 480
  set Standard-Deviation-hike-time-planned 5
  set num-minutes-per-patch-traversed 0.5
  set max-elev-change 20
  set parkData gis:load-dataset "$(asc_path)"
  gis:set-world-envelope gis:envelope-of parkData
  gis:apply-raster parkData "elevation"
  display_elevation
  file-close
  ;; Set a fixed goal for headless mode instead of mouse click
  set goal-patch-x 130
  set goal-patch-y 90
  set start? true
  set entrance-patch-x 259
  set entrance-patch-y 50
  ask patches [set tread-count 160]
end

to go
  create-visitors
  ask turtles [
    set my-neighboring-patches (patch-set neighbors)
    compute-nearest-patches
    move-visitors
    if start? [
      set hike-time-elapsed hike-time-elapsed + num-minutes-per-patch-traversed
    ]
  ]
  if is-turtle? turtle 500 [
    set track-elevation [my-elevation] of turtle 500
  ]
  set world-clock world-clock + 1
  tick
end

to display_elevation
  set min-elev gis:minimum-of parkData
  set max-elev gis:maximum-of parkData
  ask patches [set pcolor scale-color black elevation min-elev max-elev]
end

to create-visitors
  set-default-shape turtles "person"
  ask patch 259 50 [sprout 1 [
    set size 5
    set happy? false
    set color rgb 255 150 0
    ifelse (random 100) < Percent-Preferring-Steepness [set steep? true] [set steep? false]
    set outbound? true
    set entrance-patch-x 259
    set entrance-patch-y 50
    set hike-time-elapsed 0
    set hike-time-planned random-normal Mean-hike-time-planned Standard-Deviation-hike-time-planned
  ]]
end

to compute-nearest-patches
  if ([distance-nowrap patch goal-patch-x goal-patch-y] of patch-here <= 1) AND start? AND world-clock > 300 [
    set outbound? false
    set happy? true
    set turn-around-time hike-time-elapsed
  ]
  ask turtles with [ ([distance-nowrap patch entrance-patch-x entrance-patch-y] of patch-here <= 1) AND not outbound?] [
    set hike-time-elapsed 0
    die
  ]
  if (hike-time-elapsed > (hike-time-planned / 4) AND start? AND world-clock > 300) [
    set outbound? false
    set turn-around-time hike-time-elapsed
  ]
  if outbound? [
    set counter 0
    foreach sort-on [distance-nowrap patch goal-patch-x goal-patch-y] my-neighboring-patches [n ->
      if (counter = 0) [
        if (abs([elevation] of n - ([elevation] of patch-here))) < max-elev-change [
          set target n ]]
      set counter counter + 1
      if counter = 1 [ set closest n]
      if counter <= 3 AND outbound? [
        if steep? [
          if (abs([elevation] of n - ([elevation] of patch-here)) > abs([elevation] of target - [elevation] of patch-here)) AND (abs([elevation] of n - ([elevation] of patch-here))) < max-elev-change [
            set target n
          ]
        ]
        if not steep? [
          if (abs([elevation] of n - [elevation] of patch-here) < abs([elevation] of target - [elevation] of patch-here)) AND (abs([elevation] of n - ([elevation] of patch-here))) < max-elev-change [
            set target n
          ]
        ]
      ]
      while [[pxcor] of target = 0 OR [pxcor] of target = 261 OR [pycor] of target = 184 OR [pycor] of target = 0] [ set target one-of neighbors]
    ]
  ]
  if not outbound? [
    set counter 0
    foreach sort-on [distance-nowrap patch entrance-patch-x entrance-patch-y] my-neighboring-patches [n ->
      if counter = 0 [ set target n]
      set counter counter + 1
      if counter = 1 [ set closest n]
      if counter <= 3 [
        if steep? [
          if (abs([elevation] of n - ([elevation] of patch-here)) > abs([elevation] of target - [elevation] of patch-here)) AND (abs([elevation] of n - ([elevation] of patch-here))) < max-elev-change [
            set target n
          ]
        ]
        if not steep? [
          if (abs([elevation] of n - [elevation] of patch-here) < abs([elevation] of target - [elevation] of patch-here)) AND (abs([elevation] of n - ([elevation] of patch-here))) < max-elev-change [
            set target n
          ]
        ]
      ]
      while [[pxcor] of target = 0 OR [pxcor] of target = 261 OR [pycor] of target = 184 OR [pycor] of target = 0] [ set target one-of neighbors]
    ]
  ]
  set my-elevation [elevation] of patch-here
end

to move-visitors
  if patch-here = target [
    set target closest
    set hike-time-elapsed hike-time-elapsed - 1
  ]
  if start? [
    move-to target
  ]
  if not outbound? [set color rgb 170 135 0]
  ask patch-here [set tread-count tread-count - 0.6]
  if tread-count < 0 [ set tread-count 0]
  if tread-count < 100 [
    ask patch-here [set pcolor rgb tread-count 255 tread-count]
  ]
end
"""
end
