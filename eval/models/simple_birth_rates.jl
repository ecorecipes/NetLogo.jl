# ── Simple Birth Rates model (NetLogo models library) ────────────────

struct BirthRatesModel <: AbstractBenchmarkModel end

model_name(::BirthRatesModel) = "Simple Birth Rates"
n_ticks(::BirthRatesModel) = 50
tracked_globals(::BirthRatesModel) = ["red-count", "blue-count"]
world_dims(::BirthRatesModel) = (-25, 25, -25, 25)

function netlogo_code(::BirthRatesModel)
"""
globals [randomSeed blue-fertility carrying-capacity red-fertility
         red-count blue-count]

turtles-own [fertility fertility-remainder]

to setup
  clear-all
  resize-world (- 25) 25 (- 25) 25
  set blue-fertility 2
  set carrying-capacity 200
  set red-fertility 2
  create-turtles carrying-capacity [
    setxy random-xcor random-ycor
    ifelse who < (carrying-capacity / 2)
      [ set color blue ]
      [ set color red ]
    set size 2
  ]
  update-counts
  reset-ticks
end

to go
  reproduce
  grim-reaper
  update-counts
  tick
end

to update-counts
  set red-count count turtles with [color = red]
  set blue-count count turtles with [color = blue]
end

to wander
  rt random-float 30 - random-float 30
  fd 1
end

to reproduce
  ask turtles [
    ifelse color = red [
      set fertility floor red-fertility
      set fertility-remainder red-fertility - (floor red-fertility)
    ] [
      set fertility floor blue-fertility
      set fertility-remainder blue-fertility - (floor blue-fertility)
    ]
    ifelse (random-float 100) < (100 * fertility-remainder)
      [ hatch fertility + 1 [ wander ] ]
      [ hatch fertility     [ wander ] ]
  ]
end

to grim-reaper
  let num-turtles count turtles
  if num-turtles <= carrying-capacity [ stop ]
  let chance-to-die (num-turtles - carrying-capacity) / num-turtles
  ask turtles [
    if random-float 1.0 < chance-to-die [ die ]
  ]
end
"""
end
