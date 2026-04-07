# ── Tumor model (NetLogo models library) ─────────────────────────────

struct TumorModel <: AbstractBenchmarkModel end

model_name(::TumorModel) = "Tumor"
n_ticks(::TumorModel) = 50
tracked_globals(::TumorModel) = ["cell-count"]
world_dims(::TumorModel) = (-51, 51, -51, 51)

function netlogo_code(::TumorModel)
"""
globals [randomSeed use-trail cell-count]

turtles-own [stem? age metastatic?]

to setup
  clear-all
  resize-world (- 51) 51 (- 51) 51
  set use-trail true
  ask patches [ set pcolor gray ]
  set-stem
  evaluate-params
  reset-ticks
end

to set-stem
  create-turtles 2 [
    set size 2
    setxy (min-pxcor / 2) 0
    set stem? true
    set metastatic? false
    set color blue
    set age 0
  ]
  ask turtle 1 [
    set metastatic? true
    set heading 90
  ]
  set cell-count 2
end

to go
  ask turtles [
    ifelse use-trail [ pen-down ] [ pen-up ]
    if (who = 1) and (xcor < 25) [ fd 1 ]
    set age age + 1
    move-transitional-cells
    mitosis
    death
  ]
  tick
  evaluate-params
end

to move-transitional-cells
  if (not stem?) [
    set color ( red + 0.25 * age )
    fd 1
    if age < 6 [
      hatch 1 [
        rt random-float 360
        fd 1
      ]
    ]
  ]
end

to mitosis
  if stem? [
    hatch 1 [
      fd 1
      set color red
      set stem? false
      ifelse (who = 1) [ set age 16 ] [ set age 0 ]
    ]
  ]
end

to death
  if (not stem?) and (not metastatic?) and (age > 20) [ die ]
  if (not stem?) and metastatic? and (age > 4) [ die ]
end

to evaluate-params
  set cell-count count turtles
  if (cell-count <= 0) [ stop ]
end
"""
end
