# ── Percolation model (NetLogo models library) ───────────────────────

struct PercolationModel <: AbstractBenchmarkModel end

model_name(::PercolationModel) = "Percolation"
n_ticks(::PercolationModel) = 200
tracked_globals(::PercolationModel) = ["leading-edge-count", "total-oil"]
world_dims(::PercolationModel) = (0, 149, 0, 220)

function netlogo_code(::PercolationModel)
"""
globals [
  randomSeed
  porosity
  current-row
  total-oil
  leading-edge-count
]

to setup
  clear-all
  resize-world 0 149 0 220
  set porosity 60.5
  set total-oil 0
  ask patches [
    reset-color
  ]
  set current-row patches with [pycor = max-pycor]
  ask current-row [
    if pxcor mod 2 = 1
      [ set pcolor red ]
  ]
  set leading-edge-count count current-row with [pcolor = red]
  reset-ticks
end

to reset-color
    ifelse (pxcor + pycor) mod 2 = 1
      [ set pcolor brown ]
      [ set pcolor gray - 1 ]
end

to go
  if not any? current-row with [pcolor = red]
    [ stop ]
  percolate
  wrap-oil
  set leading-edge-count count current-row with [pcolor = red]
  tick
end

to percolate
  ask current-row with [pcolor = red] [
    ask patches at-points [[-1 -1] [1 -1]]
      [ if (pcolor = brown) and (random-float 100 < porosity)
          [ set pcolor red ] ]
    set pcolor black
    set total-oil total-oil + 1
  ]
  set current-row patch-set [patch-at 0 -1] of current-row
end

to wrap-oil
  if [pycor = min-pycor] of one-of current-row
  [
    ask current-row [
      ask (patch-at 0 -1)
        [ set pcolor [pcolor] of myself ]
    ]
    ask patches with [ pycor < max-pycor ] [
      reset-color
    ]
    set current-row patch-set [patch-at 0 -1] of current-row
  ]
end
"""
end
