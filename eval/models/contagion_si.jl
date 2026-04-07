# ── Contagion SI model (modsoc) ────────────────────────────────────────

struct ContagionSIModel <: AbstractBenchmarkModel end

model_name(::ContagionSIModel) = "Contagion SI"
n_ticks(::ContagionSIModel) = 200
tracked_globals(::ContagionSIModel) = ["n-infected"]
world_dims(::ContagionSIModel) = (-16, 16, -16, 16)

function netlogo_code(::ContagionSIModel)
"""
globals [randomSeed num-turtles init-infected speed turning-angle transmissibility spontaneous-infect n-infected]
turtles-own [infected?]

to setup
  clear-all
  set num-turtles 300
  set init-infected 3
  set speed 0.5
  set turning-angle 60
  set transmissibility 0.01
  set spontaneous-infect 0
  setup-turtles
  setup-infected
  recolor
  set n-infected count turtles with [infected?]
  reset-ticks
end

to setup-turtles
  create-turtles num-turtles [
    set shape "circle"
    set infected? false
    setxy random-xcor random-ycor
  ]
end

to setup-infected
  if init-infected > num-turtles [set init-infected 1]
  ask n-of init-infected turtles [set infected? true]
end

to recolor
  ask turtles [
    ifelse infected? [set color red] [set color white]
  ]
end

to go
  if (count turtles with [infected?]) = num-turtles [stop]
  infect-susceptibles
  recolor
  move
  set n-infected count turtles with [infected?]
  tick
end

to infect-susceptibles
  ask turtles with [not infected?] [
    let infected-neighbors (count other turtles with [color = red] in-radius 1)
    if random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect))
      [set infected? true]
  ]
end

to move
  ask turtles [
    left random turning-angle
    right random turning-angle
    fd speed
  ]
end
"""
end
