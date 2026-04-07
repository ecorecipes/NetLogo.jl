# ── Segregation model (NetLogo models library) ───────────────────────

struct SegregationModel <: AbstractBenchmarkModel end

model_name(::SegregationModel) = "Segregation"
n_ticks(::SegregationModel) = 50
tracked_globals(::SegregationModel) = ["percent-similar", "percent-unhappy"]
world_dims(::SegregationModel) = (-12, 12, -12, 12)

function netlogo_code(::SegregationModel)
"""
globals [randomSeed pct-similar-wanted density
         percent-similar percent-unhappy]

turtles-own [happy? similar-nearby other-nearby total-nearby]

to setup
  clear-all
  resize-world (- 12) 12 (- 12) 12
  set pct-similar-wanted 30
  set density 95
  ask patches [
    set pcolor white
    if random 100 < density [
      sprout 1 [
        set color one-of [105 27]
        set size 1
      ]
    ]
  ]
  update-turtles
  update-globals
  reset-ticks
end

to go
  if all? turtles [ happy? ] [ stop ]
  move-unhappy-turtles
  update-turtles
  update-globals
  tick
end

to move-unhappy-turtles
  ask turtles with [ not happy? ] [ find-new-spot ]
end

to find-new-spot
  rt random-float 360
  fd random-float 10
  if any? other turtles-here [ find-new-spot ]
  move-to patch-here
end

to update-turtles
  ask turtles [
    set similar-nearby count (turtles-on neighbors) with [ color = [ color ] of myself ]
    set other-nearby count (turtles-on neighbors) with [ color != [ color ] of myself ]
    set total-nearby similar-nearby + other-nearby
    set happy? similar-nearby >= (pct-similar-wanted * total-nearby / 100)
  ]
end

to update-globals
  let similar-neighbors sum [ similar-nearby ] of turtles
  let total-neighbors sum [ total-nearby ] of turtles
  set percent-similar (similar-neighbors / total-neighbors) * 100
  set percent-unhappy (count turtles with [ not happy? ]) / (count turtles) * 100
end
"""
end
