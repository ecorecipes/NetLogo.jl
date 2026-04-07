# ── Particles model (modsoc ch02) ──────────────────────────────────────

struct ParticlesModel <: AbstractBenchmarkModel end

model_name(::ParticlesModel) = "Particles"
n_ticks(::ParticlesModel) = 200
tracked_globals(::ParticlesModel) = ["collisions"]
world_dims(::ParticlesModel) = (-16, 16, -16, 16)

function netlogo_code(::ParticlesModel)
"""
globals [randomSeed num-particles whimsy speed collisions]

to setup
  clear-all
  set num-particles 50
  set whimsy 0
  set speed 0.02
  set-default-shape turtles "default"
  create-turtles num-particles [
    set color green
    set size 2
    setxy random-xcor random-ycor
    set heading random 360
  ]
  set collisions 0
  reset-ticks
end

to go
  ask turtles [
    if whimsy > 0 [
      right random whimsy
      left random whimsy
    ]
    forward speed
    if count turtles in-radius 1 > 1 [
      ask turtles in-radius 1 [
        set heading random 360
        fd 0.1
      ]
      set collisions (collisions + 1)
    ]
  ]
  tick
end
"""
end
