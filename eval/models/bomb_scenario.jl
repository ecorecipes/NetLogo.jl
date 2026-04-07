# ── BombScenario model (CSS645 ClassModels / GIS) ─────────────────────

struct BombScenarioModel <: AbstractBenchmarkModel end

model_name(::BombScenarioModel) = "BombScenario"
n_ticks(::BombScenarioModel) = 50
tracked_globals(::BombScenarioModel) = ["arrestedTotal"]
world_dims(::BombScenarioModel) = (-46, 46, -267, 267)
topology(::BombScenarioModel) = (false, false)

const BOMB_SCENARIO_DIR = "/Users/username/Projects/netlogo/ClassModels/CSS645Models/BombScenario"

function netlogo_code(::BombScenarioModel)
    asc_path = joinpath(BOMB_SCENARIO_DIR, "lenfant_new_clipped3.asc")
"""
extensions [ gis ]

breed [ officers officer ]
breed [ citizens citizen ]
breed [ bombers bomber ]
breed [ bombs bomb ]

globals [
  randomSeed
  gis-dataset
  arrestedTotal
]
turtles-own [
  suspiciousness
  memory
  oldHeading
]
citizens-own [
  inPlace?
  goingDirection
  targetCell
]
patches-own [
  occupied?
  patch-type
  neighborhood
  bombRadius
]

to setup
  ca
  reset-ticks
  set gis-dataset gis:load-dataset "$(asc_path)"
  gis:set-world-envelope gis:envelope-of gis-dataset
  gis:apply-raster gis-dataset "patch-type"
  ask patches [
    set pcolor patch-type
  ]
  ask n-of 5 patches with [ pcolor > 0 ] [
    sprout-officers 1 [
      set color blue
      set shape "person"
      set size 1.0
      set memory []
      set oldHeading (- 1)
    ]
  ]
  ask patches [ set neighborhood (patch-set neighbors patch-here) ]
  ask patches [ set bombRadius (patch-set neighbors patch-here) ]
end

to go
  enter-citizens
  find-best-cell
  police-move
  train-arrive
  bomber-arrive
  bomber-move
  tick
  update-arrested
end

to enter-citizens
  if (ticks mod 5 = 0) [
    create-citizens ( 9 * 5 ) [
      setxy 28 (- 90)
      set goingDirection random 2
      set oldHeading (- 1)
    ]
  ]
end

to bomber-arrive
  if (ticks mod 200 = 0) [
    create-bombers 1 [
      setxy 28 (- 90)
      set memory []
    ]
  ]
end

to train-arrive
  if (ticks mod ( 6 * 60 ) = 0) [
    ask citizens [
      if goingDirection = random 2 [ die ]
      if [patch-type] of one-of neighborhood with [ occupied? = 0 ] > ( [patch-type] of patch-here + 0.1 ) [
        set inPlace? 0
      ]
    ]
  ]
  ask patches [if count citizens-here = 0 [ set occupied? 0 ] ]
end

to find-best-cell
  ask citizens [
    if inPlace? = 0 [
      carefully
        [ set targetcell max-one-of neighborhood with [ occupied? = 0 ] [ [patch-type] of self ] ] [ set inPlace? 1 ]
      if targetcell != patch-here [ face targetcell ]
      let nextCell ifelse-value (patch-ahead 1 = patch-here)
        [ patch-ahead 2 ]
        [ patch-ahead 1 ]
      if [pcolor] of nextCell = 0
        [face max-one-of neighbors [patch-type]]
      fd 1
      if (patch-here = targetcell and occupied? = 0) [ set inPlace? 1 set occupied? 1 ]
    ]
    if inPlace? = 1 [
      if [patch-type] of one-of neighborhood with [ occupied? = 0 ] > ( [patch-type] of patch-here ) [
        set inPlace? 0
        ask patch-here [ set occupied? 0 ]
      ]
    ]
    set suspiciousness suspiciousness + 1
  ]
end

to police-move
  ask officers [
    let target-turtle max-one-of turtles-on neighborhood [ suspiciousness ]
    if target-turtle != nobody [
      if target-turtle != self [ face target-turtle ]
    ]
    let nextCell ifelse-value (patch-ahead 1 = patch-here)
      [ patch-ahead 2 ]
      [ patch-ahead 1 ]
    if [pcolor] of nextCell = 0
      [face max-one-of neighbors [[patch-type] of self] ]
    fd 1
    find-n-frisk
  ]
end

to find-n-frisk
  if any? (turtles-on neighborhood) with [suspiciousness > 1250 ] [
    let stopNfrisk one-of (turtles-on neighborhood) with [suspiciousness > 1250]
    ask stopNfrisk [die]
    set arrestedTotal arrestedTotal + 1
  ]
end

to bomber-move
  ask bombers [
    turn-until-free 0
    fd 1
    set memory lput patch-here memory
    set suspiciousness suspiciousness + 1
    place-bomb
  ]
end

to turn-until-free [ n ]
  let turns 0
  while [turns < 16] [
    let target ifelse-value (patch-ahead 1 = patch-here)
      [ patch-ahead 2 ]
      [ patch-ahead 1 ]
    let seen? member? target memory
    ifelse turns < 8
      [ ifelse seen? or [pcolor] of target = 0 [ lt 45 set turns turns + 1 ] [ stop ] ]
      [ ifelse [pcolor] of target = 0 [ lt 45 set turns turns + 1 ] [ stop ] ]
  ]
end

to place-bomb
  if (6 * (count citizens-on bombRadius) > count citizens-on neighborhood) and
  count citizens-on bombRadius > 10 and
  count officers-on neighbors = 0 [
    hatch-bombs 1 [
      set shape "face sad"
      set size 6.0
    ]
  ]
end

to update-arrested
  ;; no-op, arrestedTotal tracked via global
end
"""
end
