# ── Civilization Growth model (CSS600 ClassModels) ──────────────────────

struct CivilizationGrowthModel <: AbstractBenchmarkModel end

model_name(::CivilizationGrowthModel) = "Civilization Growth"
n_ticks(::CivilizationGrowthModel) = 100
tracked_globals(::CivilizationGrowthModel) = ["n-civs"]
world_dims(::CivilizationGrowthModel) = (-32, 32, -32, 32)
topology(::CivilizationGrowthModel) = (false, false)

function netlogo_code(::CivilizationGrowthModel)
"""
globals [randomSeed number-civs farm-size-uniform? SoL-uniform? n-civs]

breed [civs civ]

civs-own [
  pen-color
  farm
  farm-size
  fs-prev-tick
  farm-RoP
  farm-RoC
  farm-excess
  excess-prev-tick
  SoL
  SoL-max
  SoL-min
  RoExp
  RoExp-prev-tick
  choice
]

patches-own [
  belongs-to
  RoP
  conflict-value
]

to setup
  clear-all
  set number-civs 10
  set farm-size-uniform? false
  set SoL-uniform? true
  setup-civs
  setup-land
  ask turtles
    [ set-farm-in-radius farm-size ]
  set n-civs count civs
  reset-ticks
end

to setup-civs
  create-civs number-civs [
    set shape "person"
    set size 1.3
    set color 28
    setxy random-pxcor random-pycor
    set pen-color one-of [15 25 45 65 75 85 95 105 115 125 135]
    ifelse farm-size-uniform?
      [ set farm-size 3 ]
    [ set farm-size random 5 + 1 ]
  ]
end

to setup-land
  ask patches [ set belongs-to nobody ]
  ask patches [ set RoP random 50 ]
  repeat 5 [ ask patches [
    set RoP mean [RoP] of neighbors]]
  ask patches [ set pcolor scale-color 39 RoP 0 100
  ]
end

to set-farm-in-radius [d]
  move-to one-of patches with [ not any? other patches in-radius d with [belongs-to != nobody] ]
  set farm patches in-radius farm-size
  ask farm [ set belongs-to myself ]
  set farm-RoP sum [ RoP ] of patches in-radius farm-size
  set farm-RoC count patches in-radius farm-size * 23
  set farm-excess (farm-ROP - farm-RoC)
  ask civs [
    ifelse SoL-uniform?
    [ set SoL 0 ]
    [ ifelse farm-excess > 0
      [ set SoL random-float 5 ]
      [ set SoL random-float -5 ]
    ]
  ]
  set SoL-max 5
  set SoL-min -5
  ask farm [ set pcolor scale-color 67 RoP 0 75 ]
end

to go
  ask civs [
    invest
    expand
    conflict ]
  set n-civs count civs
  tick
end

to invest
  let p random 100
  set excess-prev-tick farm-excess
  set RoExp-prev-tick RoExp
  set fs-prev-tick farm-size

  if choice = 0 [
    if (farm-excess > 0 and p <= 40) [
      set farm-RoP ( farm-RoP + farm-excess )
      set choice 1 ]
    if ( farm-excess > 0 and p > 60 and SoL < SoL-max ) [
      set SoL ( SoL + 0.50 )
      set choice 2]
    if ( farm-excess > 0 and p > 60 ) [
      set farm-RoC ( farm-RoC + ( count patches in-radius farm-size * 2 ))
      set choice 2 ]
    if farm-excess < 0 and SoL >= SoL-min [
      set SoL ( SoL - 0.10 )
      set choice 0 ]
  ]
  if choice = 1 [
    if ( farm-excess > 0 and p <= 40 ) [
      set farm-RoP ( farm-RoP + farm-excess )
      set SoL ( SoL + 0.10 )
      set choice 1 ]
  ]
  if choice = 2 [
    if ( farm-excess > 0 and p > 60 and SoL < SoL-max ) [
      set SoL ( SoL + 0.50 )
      set choice 2]
    if ( farm-excess > 0 and p > 60 ) [
      set farm-RoC ( farm-RoC + ( count patches in-radius farm-size * 2 ))
      set choice 2 ]
  ]

  set farm-excess (farm-ROP - farm-RoC)
  set RoExp ((farm-excess - excess-prev-tick) / (excess-prev-tick))
end

to expand
  if RoExp >= 0.50 and RoExp-prev-tick >= 0.50 and ticks >= 5 [
    set farm-size ( farm-size + 1 )
    assess ]
end

to assess
  if farm-size > fs-prev-tick [
    ask (patches in-radius farm-size) with [belongs-to != nobody and belongs-to != myself] [
      set plabel "C"
      set conflict-value 1]
  ]
end

to conflict
  if farm-size <= fs-prev-tick and any? patches in-radius farm-size with [conflict-value = 1] [
    ask patches in-radius farm-size [
      set conflict-value 0
      set plabel "" ]
    die
  ]
  if farm-size > fs-prev-tick [
    expand-civ]
end

to expand-civ
  if RoExp >= 0.50 and RoExp-prev-tick >= 0.50 and ticks >= 5 [
    set farm patches in-radius farm-size
    ask farm [
      set belongs-to myself ]
    let tmp-RoP farm-RoP
    ask patches in-radius farm-size [
      set pcolor scale-color 67 RoP 0 75 ]
  ]
end
"""
end
