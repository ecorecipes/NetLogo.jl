# ── Wealth Distribution model (NetLogo models library) ───────────────

struct WealthDistModel <: AbstractBenchmarkModel end

model_name(::WealthDistModel) = "Wealth Distribution"
n_ticks(::WealthDistModel) = 50
tracked_globals(::WealthDistModel) = ["gini-index-reserve"]
world_dims(::WealthDistModel) = (-15, 15, -15, 15)

function netlogo_code(::WealthDistModel)
"""
globals [randomSeed grain-growth-interval life-expectancy-max life-expectancy-min
         max-vision metabolism-max num-grain-grown num-people percent-best-land
         max-grain gini-index-reserve lorenz-points]

patches-own [grain-here max-grain-here]
turtles-own [age wealth life-expectancy metabolism vision]

to setup
  clear-all
  resize-world (- 15) 15 (- 15) 15
  set grain-growth-interval 1
  set life-expectancy-max 83
  set life-expectancy-min 1
  set max-vision 5
  set metabolism-max 15
  set num-grain-grown 4
  set num-people 250
  set percent-best-land 10
  set max-grain 50
  setup-patches
  setup-turtles
  update-lorenz-and-gini
  reset-ticks
end

to setup-patches
  ask patches [
    set max-grain-here 0
    if (random-float 100.0) <= percent-best-land [
      set max-grain-here max-grain
      set grain-here max-grain-here
    ]
  ]
  repeat 5 [
    ask patches with [max-grain-here != 0] [ set grain-here max-grain-here ]
    diffuse grain-here 0.25
  ]
  repeat 10 [ diffuse grain-here 0.25 ]
  ask patches [
    set grain-here floor grain-here
    set max-grain-here grain-here
    recolor-patch
  ]
end

to recolor-patch
  set pcolor scale-color yellow grain-here 0 max-grain
end

to setup-turtles
  create-turtles num-people [
    move-to one-of patches
    set size 1.5
    set-initial-turtle-vars
  ]
  recolor-turtles
end

to set-initial-turtle-vars
  face one-of neighbors4
  set life-expectancy life-expectancy-min +
                        random (life-expectancy-max - life-expectancy-min + 1)
  set metabolism 1 + random metabolism-max
  set wealth metabolism + random 50
  set vision 1 + random max-vision
  set age random life-expectancy
end

to recolor-turtles
  let max-wealth max [wealth] of turtles
  ask turtles [
    ifelse (wealth <= max-wealth / 3)
      [ set color red ]
      [ ifelse (wealth <= (max-wealth * 2 / 3))
          [ set color green ]
          [ set color blue ] ]
  ]
end

to go
  ask turtles [ turn-towards-grain ]
  harvest
  ask turtles [ move-eat-age-die ]
  recolor-turtles
  if ticks mod grain-growth-interval = 0
    [ ask patches [ grow-grain ] ]
  update-lorenz-and-gini
  tick
end

to turn-towards-grain
  set heading 0
  let best-direction 0
  let best-amount grain-ahead
  set heading 90
  if (grain-ahead > best-amount) [
    set best-direction 90
    set best-amount grain-ahead
  ]
  set heading 180
  if (grain-ahead > best-amount) [
    set best-direction 180
    set best-amount grain-ahead
  ]
  set heading 270
  if (grain-ahead > best-amount) [
    set best-direction 270
    set best-amount grain-ahead
  ]
  set heading best-direction
end

to-report grain-ahead
  let total 0
  let how-far 1
  repeat vision [
    set total total + [grain-here] of patch-ahead how-far
    set how-far how-far + 1
  ]
  report total
end

to grow-grain
  if (grain-here < max-grain-here) [
    set grain-here grain-here + num-grain-grown
    if (grain-here > max-grain-here) [ set grain-here max-grain-here ]
    recolor-patch
  ]
end

to harvest
  ask turtles [
    set wealth floor (wealth + (grain-here / (count turtles-here)))
  ]
  ask turtles [
    set grain-here 0
    recolor-patch
  ]
end

to move-eat-age-die
  fd 1
  set wealth (wealth - metabolism)
  set age (age + 1)
  if (wealth < 0) or (age >= life-expectancy) [ set-initial-turtle-vars ]
end

to update-lorenz-and-gini
  let sorted-wealths sort [wealth] of turtles
  let total-wealth sum sorted-wealths
  let wealth-sum-so-far 0
  let index 0
  set gini-index-reserve 0
  set lorenz-points []
  repeat num-people [
    set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
    set index (index + 1)
    set gini-index-reserve
      gini-index-reserve +
      (index / num-people) -
      (wealth-sum-so-far / total-wealth)
  ]
end
"""
end
