# ── Infinite Life model (model-zoo) ──────────────────────────────────

struct InfiniteLifeModel <: AbstractBenchmarkModel end

model_name(::InfiniteLifeModel) = "Infinite Life"
n_ticks(::InfiniteLifeModel) = 20
tracked_globals(::InfiniteLifeModel) = ["count cells"]
world_dims(::InfiniteLifeModel) = (-16, 16, -16, 16)

function netlogo_code(::InfiniteLifeModel)
"""
extensions [matrix]

globals [
  neighbor-offsets
  current-scale
  centre-xy
]

breed [cells cell]
breed [new-cells new-cell]

turtles-own [
  lattice-site
]

to setup
  clear-all
  ask patches [set pcolor white]
  set-default-shape turtles "square"
  set current-scale 1
  set centre-xy [0 0]
  set neighbor-offsets (list [-1 1] [0 1] [1 1] [-1 0] [1 0] (list -1 -1) (list 0 -1) (list 1 -1))
  ask patches [
    if random-float 1 < 0.35 [
      sprout-cells 1 [
        set color black
        set size current-scale
        set lattice-site (list pxcor pycor)
      ]
    ]
  ]
  reset-ticks
end

to zoom-out
  zoom -1
end

to zoom-in
  zoom 1
end

to zoom [factor]
  let zoom-factor 2 ^ (factor / 2)
  set centre-xy mean-centre [lattice-site] of cells
  set current-scale zoom-factor * current-scale
  ask turtles [
    set-world-xy
    set size max (list current-scale 0.24)
  ]
end

to-report lattice-x
  report item 0 lattice-site
end

to-report lattice-y
  report item 1 lattice-site
end

to-report mean-centre [list-of-coords]
  report map [x -> mean x] transpose list-of-coords
end

to-report transpose [list-of-lists]
  let IJ matrix:from-row-list list-of-lists
  let JI matrix:transpose IJ
  report matrix:to-row-list JI
end

to go
  if not any? turtles [ setup ]
  rescale
  create-next-gen
  weed-new-cells
  flip-cells
  tick
end

to rescale
  let needed? true
  while [needed?] [
    let max-x max [lattice-x] of cells + 1
    let max-y max [lattice-y] of cells + 1
    let min-x min [lattice-x] of cells - 1
    let min-y min [lattice-y] of cells - 1
    let top-right lattice-coords (list max-pxcor max-pycor)
    let bottom-left lattice-coords (list min-pxcor min-pycor)
    ifelse (max-x > item 0 top-right) or (max-y > item 1 top-right) or
       (min-x < item 0 bottom-left) or (min-y < item 1 bottom-left) [
       zoom-out
    ]
    [
      set needed? false
    ]
  ]
end

to-report world-coords [xy]
  report (map [[a b] -> current-scale * (a - b)] xy centre-xy)
end

to-report lattice-coords [pxpy]
  report (map [[a b] -> round (a / current-scale) + b] pxpy centre-xy)
end

to set-world-xy
  let wxwy world-coords lattice-site
  setxy item 0 wxwy item 1 wxwy
end

to create-next-gen
  foreach get-candidate-spots [ spot ->
    create-new-cells 1 [
      set color gray
      set lattice-site spot
      set-world-xy
      set size max (list current-scale 0.24)
    ]
  ]
end

to weed-new-cells
  ask new-cells [
    let nghbrs neighbouring-lattice-sites
    let nearby-cells (turtle-set cells-here cells-on neighbors)
    let xy lattice-site
    let live-n count nearby-cells with [member? lattice-site nghbrs]
    let alive? any? nearby-cells with [xy = lattice-site]
    ifelse alive?
    [ if not (live-n = 2 or live-n = 3) [die] ]
    [ if live-n != 3 [die] ]
  ]
end

to flip-cells
  ask cells [ die ]
  ask new-cells [
    set color black
    set breed cells
  ]
end

to-report neighbouring-lattice-sites
  let x lattice-x
  let y lattice-y
  report map [offset -> list (x + item 0 offset) (y + item 1 offset)] neighbor-offsets
end

to-report get-candidate-spots
  let neighbouring-sites [neighbouring-lattice-sites] of cells
  set neighbouring-sites reduce [[a b] -> sentence a b] neighbouring-sites
  report remove-duplicates sentence neighbouring-sites [lattice-site] of cells
end
"""
end
