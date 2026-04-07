# ── Segregation model (modsoc ch03 Schelling) ─────────────────────────

struct ModsocSegregationModel <: AbstractBenchmarkModel end

model_name(::ModsocSegregationModel) = "Modsoc Segregation"
n_ticks(::ModsocSegregationModel) = 50
tracked_globals(::ModsocSegregationModel) = ["average-similarity", "unhappiness"]
world_dims(::ModsocSegregationModel) = (-16, 16, -16, 16)

function netlogo_code(::ModsocSegregationModel)
"""
globals [randomSeed density similarity-threshold average-similarity unhappiness]
turtles-own [happy? prop-similar-neighbors]

to setup
  clear-all
  set density 0.9
  set similarity-threshold 0.3
  make-turtles
  update-turtles
  update-globals
  reset-ticks
end

to make-turtles
  ask patches [
    if random-float 1 < density [
      sprout 1 [
        set shape "square"
        set color one-of [yellow blue]
      ]
    ]
  ]
end

to go
  if all? turtles [happy?] [stop]
  move-unhappy-turtles
  update-turtles
  update-globals
  tick
end

to move-unhappy-turtles
  ask turtles with [not happy?]
    [move-to one-of patches with [not any? turtles-here]]
end

to update-turtles
  ask turtles [
    let similar-nearby count (turtles-on neighbors) with [color = [color] of myself]
    let total-nearby count (turtles-on neighbors)
    ifelse (total-nearby = 0)
      [set prop-similar-neighbors 1]
      [set prop-similar-neighbors (similar-nearby / total-nearby)]
    set happy? (prop-similar-neighbors >= similarity-threshold)
  ]
end

to update-globals
  let similar-neighbors sum [prop-similar-neighbors] of turtles
  set average-similarity (similar-neighbors / count turtles)
  set unhappiness (count turtles with [not happy?]) / (count turtles)
end
"""
end
