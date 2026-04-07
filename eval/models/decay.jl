# ── Radioactive Decay model (NetLogo models library) ─────────────────

struct DecayModel <: AbstractBenchmarkModel end

model_name(::DecayModel) = "Radioactive Decay"
n_ticks(::DecayModel) = 200
tracked_globals(::DecayModel) = ["decays"]
world_dims(::DecayModel) = (-45, 45, -45, 45)

function netlogo_code(::DecayModel)
"""
globals [randomSeed decay-chance number-nuclei decays last-count]

to setup
  clear-all
  resize-world (- 45) 45 (- 45) 45
  set decay-chance 3
  set number-nuclei 2500
  set-default-shape turtles "circle"
  ask n-of number-nuclei patches [
    sprout 1 [ set color cyan ]
  ]
  set last-count number-nuclei
  set decays 0
  reset-ticks
end

to go
  if all? turtles [color = blue - 3] [ stop ]
  set decays 0
  ask turtles with [color = cyan] [
    if random-float 100.0 < decay-chance [
      set color yellow
      set decays decays + 1
    ]
  ]
  ask turtles with [color = yellow] [ set color blue - 3 ]
  tick
end
"""
end
