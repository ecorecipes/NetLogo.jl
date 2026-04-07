# ── Grass-Brush-Trees Ecological Succession ─────────────────────────
# Adapted from model-zoo 3.6-simple-grass-brush-trees
# Three-state interacting particle system (Durrett & Swindle 1991)

struct GrassBrushTreesModel <: AbstractBenchmarkModel end

model_name(::GrassBrushTreesModel) = "Grass Brush Trees"
n_ticks(::GrassBrushTreesModel) = 200
tracked_globals(::GrassBrushTreesModel) = ["n-trees"]
world_dims(::GrassBrushTreesModel) = (0, 49, 0, 49)

function netlogo_code(::GrassBrushTreesModel)
"""
globals [randomSeed N pcolors norm-b-1 norm-b-2 norm-d n-trees birth-rate-1 birth-rate-2]

patches-own [particle-type]

to setup
  clear-all
  set birth-rate-1 6
  set birth-rate-2 2
  set pcolors (list (lime + 2) (green - 1) (green - 3))
  set N count patches
  ask patches [
    set particle-type random 3
    set pcolor item particle-type pcolors
  ]
  set n-trees count patches with [particle-type = 2]
  reset-ticks
end

to go
  repeat N [
    let max-rate max (list birth-rate-1 birth-rate-2)
    set norm-d 1 / max-rate
    set norm-b-1 birth-rate-1 / max-rate
    set norm-b-2 birth-rate-2 / max-rate
    ask one-of patches [
      ifelse random 2 = 1
      [ death-event ]
      [ birth-event ]
    ]
  ]
  set n-trees count patches with [particle-type = 2]
  tick
end

to death-event
  if random-float 1 < norm-d [
    set particle-type 0
    set pcolor item particle-type pcolors
  ]
end

to birth-event
  if particle-type > 0 [
    ifelse particle-type = 1 [
      if random-float 1 < norm-b-1 [
        ask one-of neighbors4 [
          if particle-type = 0 [
            set particle-type 1
            set pcolor item particle-type pcolors
          ]
        ]
      ]
    ]
    [
      if random-float 1 < norm-b-2 [
        ask one-of neighbors4 [
          if particle-type < 2 [
            set particle-type 2
            set pcolor item particle-type pcolors
          ]
        ]
      ]
    ]
  ]
end
"""
end
