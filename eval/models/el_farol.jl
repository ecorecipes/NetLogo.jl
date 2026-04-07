# ── El Farol model (NetLogo models library) ──────────────────────────

struct ElFarolModel <: AbstractBenchmarkModel end

model_name(::ElFarolModel) = "El Farol"
n_ticks(::ElFarolModel) = 50
tracked_globals(::ElFarolModel) = ["attendance"]
world_dims(::ElFarolModel) = (-17, 17, -17, 17)

function netlogo_code(::ElFarolModel)
"""
globals [randomSeed memory-size number-strategies overcrowding-threshold
         attendance history home-patches bar-patches crowded-patch]

turtles-own [strategies best-strategy attend? prediction]

to setup
  clear-all
  resize-world (- 17) 17 (- 17) 17
  set memory-size 5
  set number-strategies 10
  set overcrowding-threshold 60
  set home-patches patches with [pycor < 0 or (pxcor < 0 and pycor >= 0)]
  ask home-patches [ set pcolor green ]
  set bar-patches patches with [pxcor > 0 and pycor > 0]
  ask bar-patches [ set pcolor blue ]
  set history n-values (memory-size * 2) [random 100]
  set attendance first history
  ask patch (0.75 * max-pxcor) (0.5 * max-pycor) [
    set crowded-patch self
    set plabel-color yellow
  ]
  create-turtles 100 [
    set color white
    move-to-empty-one-of home-patches
    set strategies n-values number-strategies [random-strategy]
    set best-strategy first strategies
    update-strategies
  ]
  reset-ticks
end

to go
  ask turtles [
    set prediction predict-attendance best-strategy sublist history 0 memory-size
    set attend? (prediction <= overcrowding-threshold)
  ]
  ask turtles [
    ifelse attend?
      [ move-to-empty-one-of bar-patches
        set attendance attendance + 1 ]
      [ move-to-empty-one-of home-patches ]
  ]
  set attendance count turtles-on bar-patches
  set history fput attendance but-last history
  ask turtles [ update-strategies ]
  tick
end

to update-strategies
  let best-score memory-size * 100 + 1
  foreach strategies [ the-strategy ->
    let score 0
    let week 1
    repeat memory-size [
      set prediction predict-attendance the-strategy sublist history week (week + memory-size)
      set score score + abs (item (week - 1) history - prediction)
      set week week + 1
    ]
    if (score <= best-score) [
      set best-score score
      set best-strategy the-strategy
    ]
  ]
end

to-report random-strategy
  report n-values (memory-size + 1) [1.0 - random-float 2.0]
end

to-report predict-attendance [strategy subhistory]
  report 100 * first strategy + sum (map [ [weight week] -> weight * week ] butfirst strategy subhistory)
end

to move-to-empty-one-of [locations]
  move-to one-of locations
  while [any? other turtles-here] [
    move-to one-of locations
  ]
end
"""
end
