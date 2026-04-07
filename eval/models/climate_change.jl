# ── Climate Change model (NetLogo models library) ────────────────────

struct ClimateModel <: AbstractBenchmarkModel end

model_name(::ClimateModel) = "Climate Change"
n_ticks(::ClimateModel) = 200
tracked_globals(::ClimateModel) = ["temperature"]
world_dims(::ClimateModel) = (-24, 24, -8, 22)

function netlogo_code(::ClimateModel)
"""
globals [randomSeed albedo sun-brightness sky-top earth-top temperature]

breed [rays ray]
breed [IRs IR]
breed [heats heat]
breed [CO2s CO2]

to setup
  clear-all
  resize-world (- 24) 24 (- 8) 22
  set albedo 0.6
  set sun-brightness 1
  setup-world
  set temperature 12
  reset-ticks
end

to setup-world
  set sky-top max-pycor - 5
  set earth-top 0
  ask patches [
    if pycor > sky-top [ set pcolor scale-color white pycor 22 15 ]
    if pycor <= sky-top and pycor > earth-top [ set pcolor scale-color blue pycor -20 20 ]
    if pycor < earth-top [ set pcolor red + 3 ]
    if pycor = earth-top [ update-albedo ]
  ]
end

to go
  run-sunshine
  ask patches with [pycor = earth-top] [ update-albedo ]
  run-heat
  run-IR
  run-CO2
  tick
end

to update-albedo
  set pcolor scale-color green albedo 0 1
end

to run-sunshine
  ask rays [
    if not can-move? 0.3 [ die ]
    fd 0.3
  ]
  create-sunshine
  encounter-earth
end

to create-sunshine
  if 10 * sun-brightness > random 50 [
    create-rays 1 [
      set heading 160
      set color yellow
      setxy (random 10) + min-pxcor max-pycor
    ]
  ]
end

to encounter-earth
  ask rays with [ycor <= earth-top] [
    ifelse 100 * albedo > random 100
      [ set heading 180 - heading ]
      [ rt random 45 - random 45
        set color red - 2 + random 4
        set breed heats ]
  ]
end

to run-heat
  set temperature 0.99 * temperature + 0.01 * (12 + 0.1 * count heats)
  ask heats [
    let dist 0.5 * random-float 1
    ifelse can-move? dist
      [ fd dist ]
      [ set heading 180 - heading ]
    if ycor >= earth-top [
      ifelse temperature > 20 + random 40
              and xcor > 0 and xcor < max-pxcor - 8
        [ set breed IRs
          set heading 20
          set color magenta ]
        [ set heading 100 + random 160 ]
    ]
  ]
end

to run-IR
  ask IRs [
    if not can-move? 0.3 [ die ]
    fd 0.3
    if ycor <= earth-top [
      set breed heats
      rt random 45
      lt random 45
      set color red - 2 + random 4
    ]
    if any? CO2s-here [ set heading 180 - heading ]
  ]
end

to run-CO2
  ask CO2s [
    rt random 51 - 25
    let dist 0.05 + random-float 0.1
    if [not shade-of? blue pcolor] of patch-ahead dist
      [ set heading 180 - heading ]
    fd dist
  ]
end
"""
end
