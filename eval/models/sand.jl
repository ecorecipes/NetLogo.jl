# ── Sand (Falling Sand Cellular Automaton) ──────────────────────────
# Source: modelingcommons #1274 (Wilensky 1996)
# Sand grains fall from spouts, pile up following gravity rules.

struct SandModel <: AbstractBenchmarkModel end

model_name(::SandModel) = "Sand"
n_ticks(::SandModel) = 200
tracked_globals(::SandModel) = ["n-brown"]
world_dims(::SandModel) = (-40, 40, -40, 40)
topology(::SandModel) = (true, false)

function netlogo_code(::SandModel)
"""
globals [
  randomSeed
  release-chance
  density
  spacing
  n-brown
  spout-patches
  spout-ycor
  surface-ycor
]

patches-own [
  next-color
]

to setup
  clear-all
  set release-chance 100
  set density 10
  set spacing 3
  set surface-ycor -0.8 * max-pycor
  ask patches with [pycor < surface-ycor]
    [ set pcolor gray ]
  set spout-ycor round (max-pycor * 0.9)
  let spout-space round (max-pxcor * 0.6)
  set spout-patches patches with [(pxcor mod spout-space = 0) and
                                  (pycor = spout-ycor)]
  ask spout-patches
    [ set pcolor blue ]
  reset-ticks
end

to go
  spout
  move-all-sand
  set n-brown count patches with [pcolor = brown]
  tick
end

to spout
  if ticks mod spacing = 0
    [ ask spout-patches with [random-float 100 <= release-chance]
        [ ask patch-at 0 -1 [ set pcolor brown ] ] ]
end

to move-all-sand
  ask patches
    [ set next-color pcolor ]
  ask patches with [pcolor = brown]
    [ ifelse ([pcolor] of patch-at 0 -1 = black)
        [ move 0 ]
        [ ifelse ([pcolor] of patch-at -1 -1 = brown) and
                 ([pcolor] of patch-at  1 -1 = black)
           [ move 1 ]
           [ ifelse ([pcolor] of patch-at -1 -1 = black) and
                    ([pcolor] of patch-at  1 -1 = brown)
              [ move -1 ]
              [ if ([pcolor] of patch-at 1 -1 = black) and
                   ([pcolor] of patch-at -1 -1 = black)
                  [ move one-of [1 -1] ] ] ] ] ]
  ask patches
    [ set pcolor next-color ]
end

to move [x-offset]
  set next-color black
  ask patch-at x-offset -1 [ set next-color brown ]
end
"""
end
