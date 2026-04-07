# ── Ising model (NetLogo models library) ─────────────────────────────

struct IsingModel <: AbstractBenchmarkModel end

model_name(::IsingModel) = "Ising"
n_ticks(::IsingModel) = 50
tracked_globals(::IsingModel) = ["sum-of-spins"]
world_dims(::IsingModel) = (-20, 20, -20, 20)

function netlogo_code(::IsingModel)
"""
globals [randomSeed probability-of-spin-up temperature sum-of-spins]

patches-own [spin]

to setup
  clear-all
  resize-world (- 20) 20 (- 20) 20
  set probability-of-spin-up 50
  set temperature 2.27
  ask patches [
    ifelse random 100 < probability-of-spin-up
      [ set spin  1 ]
      [ set spin -1 ]
    recolor
  ]
  set sum-of-spins sum [ spin ] of patches
  reset-ticks
end

to go
  repeat 1000 [
    ask one-of patches [ update-spin ]
  ]
  tick
end

to update-spin
  let Ediff 2 * spin * sum [ spin ] of neighbors4
  if (Ediff <= 0) or (temperature > 0 and (random-float 1.0 < exp ((- Ediff) / temperature))) [
    set spin (- spin)
    set sum-of-spins sum-of-spins + 2 * spin
    recolor
  ]
end

to recolor
  ifelse spin = 1
    [ set pcolor blue + 2 ]
    [ set pcolor blue - 2 ]
end
"""
end
