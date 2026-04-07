# ── Schelling Segregation model ───────────────────────────────────────

struct SchellingModel <: AbstractBenchmarkModel end

model_name(::SchellingModel) = "Schelling Segregation"
n_ticks(::SchellingModel) = 100
tracked_globals(::SchellingModel) = ["percent-similar", "percent-unhappy"]

function netlogo_code(::SchellingModel)
"""
globals [percent-similar percent-unhappy]
turtles-own [happy? similar-nearby other-nearby total-nearby]

to setup
  clear-all
  ask patches [
    if random 100 < 70 [
      sprout 1 [
        set color one-of [red blue]
        set size 1
      ]
    ]
  ]
  update-variables
  reset-ticks
end

to go
  if all? turtles [happy?] [ stop ]
  ask turtles with [not happy?] [
    let target one-of patches with [not any? turtles-here]
    if target != nobody [
      move-to target
    ]
  ]
  update-variables
  tick
end

to update-variables
  ask turtles [
    set similar-nearby count (turtles-on neighbors) with [color = [color] of myself]
    set other-nearby count (turtles-on neighbors) with [color != [color] of myself]
    set total-nearby similar-nearby + other-nearby
    set happy? similar-nearby >= (total-nearby * 30 / 100)
  ]
  let with-neighbors turtles with [total-nearby > 0]
  set percent-similar 0
  if any? with-neighbors [
    set percent-similar mean [100 * similar-nearby / total-nearby] of with-neighbors
  ]
  set percent-unhappy 0
  if any? turtles [
    set percent-unhappy (count turtles with [not happy?]) / (count turtles) * 100
  ]
end
"""
end
