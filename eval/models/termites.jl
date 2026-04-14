# ── Termites model (NetLogo models library) ──────────────────────────

struct TermitesModel <: AbstractBenchmarkModel end

model_name(::TermitesModel) = "Termites"
n_ticks(::TermitesModel) = 200
tracked_globals(::TermitesModel) = ["num-chip-patches", "num-carrying"]
world_dims(::TermitesModel) = (-100, 100, -100, 100)

function netlogo_code(::TermitesModel)
"""
globals [randomSeed number density num-chip-patches num-carrying]

to setup
  clear-all
  resize-world (- 100) 100 (- 100) 100
  set number 400
  set density 20.0
  set-default-shape turtles "bug"
  ask patches [
    if random-float 100 < density [
      set pcolor yellow
    ]
  ]
  create-turtles number [
    set color white
    setxy random-xcor random-ycor
    set size 5
  ]
  update-globals
  reset-ticks
end

to go
  ask turtles [
    search-for-chip
    find-new-pile
    put-down-chip
  ]
  update-globals
  tick
end

to update-globals
  set num-chip-patches count patches with [pcolor = yellow]
  set num-carrying count turtles with [color = orange]
end

to search-for-chip
  ifelse pcolor = yellow [
    set pcolor black
    set color orange
    fd 20
  ] [
    wiggle
    search-for-chip
  ]
end

to find-new-pile
  if pcolor != yellow [
    wiggle
    find-new-pile
  ]
end

to put-down-chip
  ifelse pcolor = black [
    set pcolor yellow
    set color white
    get-away
  ] [
    rt random 360
    fd 1
    put-down-chip
  ]
end

to get-away
  rt random 360
  fd 20
  if pcolor != black [
    get-away
  ]
end

to wiggle
  fd 1
  rt random 50
  lt random 50
end
"""
end
