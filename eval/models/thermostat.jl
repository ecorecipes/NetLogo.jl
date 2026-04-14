# ── Thermostat (Feedback Control) ───────────────────────────────────
# Source: modelingcommons #1286 (Wilensky 1998)
# Particles represent heat; thermostat adds/removes particles.

struct ThermostatModel <: AbstractBenchmarkModel end

model_name(::ThermostatModel) = "Thermostat"
n_ticks(::ThermostatModel) = 200
tracked_globals(::ThermostatModel) = ["temperature"]
world_dims(::ThermostatModel) = (-35, 35, -35, 35)
topology(::ThermostatModel) = (false, false)

function netlogo_code(::ThermostatModel)
"""
globals [
  randomSeed
  initial-temp
  goal-temp
  heater-strength
  insulation
  temperature
  temperatures
]

turtles-own [ new? ]

to setup
  clear-all
  set initial-temp 53
  set goal-temp 67
  set heater-strength 4
  set insulation 50
  set-default-shape turtles "circle"
  set temperature initial-temp
  set temperatures n-values 10 [initial-temp]
  ask patches
  [
    if (((abs pxcor) < 5) and
        (pycor < (max-pxcor - 15)) and
        (pycor > (max-pxcor - 25)))
    [ set pcolor green ]
    if (((abs pycor) <= (max-pxcor - 7)) and
        ((abs pxcor) =  (max-pxcor - 7)))
    [ set pcolor yellow ]
    if (((abs pycor) =  (max-pxcor - 7)) and
        ((abs pxcor) <= (max-pxcor - 7)))
    [ set pcolor yellow ]
  ]
  crt (round (initial-temp * (((world-width - 16) * (world-width - 16)) / 81)))
  [
    set color red
    fd (random-float (max-pxcor - 8))
  ]
  reset-ticks
end

to go
  ask turtles
  [ circulate-heat ]
  take-temperature
  thermo-control
  tick
end

to thermo-control
  ifelse (temperature < goal-temp)
  [
    run-heater
    ask patches
    [
      if (((distancexy 0 0) <= 2))
      [ set pcolor white ]
    ]
  ]
  [
    ask patches
    [
      if (((distancexy 0 0) <= 2))
      [ set pcolor black ]
    ]
  ]
end

to run-heater
  crt heater-strength
  [
    if (new? = 0)
    [ set new? 1 ]
    set color red
  ]
end

to circulate-heat
  if (pcolor = yellow)
  [
    if ((random-float insulation) > 1)
    [
      facexy ((random-float (world-width - 13)) - (max-pxcor - 6))
                            ((random-float (world-width - 14)) - (max-pxcor - 6))
    ]
  ]
  fd 1
  if not can-move? 1
  [ die ]
end

to take-temperature
  set temperatures but-last fput count turtles with [ pcolor = green ] temperatures
  set temperature mean temperatures
end
"""
end
