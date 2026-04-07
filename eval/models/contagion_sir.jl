# ── Contagion SIR model (modsoc) ───────────────────────────────────────

struct ContagionSIRModel <: AbstractBenchmarkModel end

model_name(::ContagionSIRModel) = "Contagion SIR"
n_ticks(::ContagionSIRModel) = 200
tracked_globals(::ContagionSIRModel) = ["n-infected", "n-immune"]
world_dims(::ContagionSIRModel) = (-16, 16, -16, 16)

function netlogo_code(::ContagionSIRModel)
"""
globals [randomSeed num-turtles init-infected speed turning-angle transmissibility spontaneous-infect recovery-rate remove-recovered? n-infected n-immune]
turtles-own [infected? immune?]

to setup
  clear-all
  set num-turtles 500
  set init-infected 3
  set speed 1
  set turning-angle 360
  set transmissibility 0.1
  set spontaneous-infect 0
  set recovery-rate 0.01
  set remove-recovered? false
  setup-turtles
  setup-infected
  recolor
  set n-infected count turtles with [infected?]
  set n-immune count turtles with [immune?]
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set color white
    set infected? false
    set immune? false
    setxy random-xcor random-ycor
  ]
end

to setup-infected
  if init-infected > num-turtles [set init-infected 1]
  ask n-of init-infected turtles [set infected? true]
end

to recolor
  ask turtles [
    ifelse infected? [set color red]
      [ifelse immune? [set color grey] [set color white]]
  ]
end

to go
  infect-susceptibles
  recover-infecteds
  recolor
  move
  set n-infected count turtles with [infected?]
  set n-immune count turtles with [immune?]
  tick
end

to infect-susceptibles
  ask turtles with [not infected? and not immune?] [
    let infected-neighbors (count other turtles with [color = red] in-radius 1)
    if (random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect)))
      [set infected? true]
  ]
end

to recover-infecteds
  ask turtles with [infected? and color = red] [
    if random-float 1 < recovery-rate [
      set infected? false
      if remove-recovered? [set immune? true]
    ]
  ]
end

to move
  ask turtles [
    left random turning-angle
    right random turning-angle
    fd speed
  ]
end

to-report prop-infected
  report (count turtles with [infected?]) / num-turtles
end
"""
end
