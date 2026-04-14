# Forest Dynamic Model — Dewdney (2000)
# table extension: tests table:group-agents, table:values, map count pattern
# Neutral birth-death model tracking species richness & abundance distribution
# Source: modelingcommons #7266

struct ForestDewdneyModel <: AbstractBenchmarkModel end

model_name(::ForestDewdneyModel) = "Forest Dewdney"
n_ticks(::ForestDewdneyModel) = 500
tracked_globals(::ForestDewdneyModel) = ["local-richness", "sp"]
world_dims(::ForestDewdneyModel) = (0, 14, 0, 14)   # 15×15 = 225 trees (small for speed)
topology(::ForestDewdneyModel) = (true, true)

function netlogo_code(::ForestDewdneyModel)
    return """
extensions [table]
globals [i1 k1 x-cor y-cor local-richness-counts local-richness
         hist-frq-local rel-hist-frq-local sp n]
breed [trees a-tree]
trees-own [species]

to setup
  clear-all
  let w1 max-pycor
  let w2 max-pxcor
  set k1 -1
  set n 2
  set sp 0
  while [k1 < w1] [
    set k1 k1 + 1
    set i1 -1
    while [i1 < w2] [
      set i1 i1 + 1
      create-trees 1 [
        setxy i1 k1
        set species random 15
        set shape "circle"
      ]
    ]
  ]
  update-richness
  reset-ticks
end

to update-richness
  set local-richness-counts map count table:values table:group-agents trees [species]
  set local-richness length local-richness-counts
  set hist-frq-local sort-by > map count table:values table:group-agents trees [species]
  let total count trees
  if total > 0 [
    set rel-hist-frq-local map [i -> i / total] hist-frq-local
  ]
end

to go
  ingest-process
  reproduce-process
  update-richness
  tick
end

to ingest-process
  ;; Rare-species protection: don't kill singletons
  let victim nobody
  let attempts 0
  while [victim = nobody and attempts < 100] [
    let candidate one-of trees
    set sp [species] of candidate
    set n count trees with [species = sp]
    if n > 1 [
      set victim candidate
    ]
    set attempts attempts + 1
  ]
  if victim != nobody [
    ask victim [
      set x-cor xcor
      set y-cor ycor
      die
    ]
  ]
end

to reproduce-process
  ask one-of trees [
    hatch 1 [
      set xcor x-cor
      set ycor y-cor
    ]
  ]
end
"""
end
