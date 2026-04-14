# ── BlackBox ─────────────────────────────────────────────────────
# Source: modelingcommons #4209
# matrix + rnd extensions: tests matrix:from-row-list, matrix:get-row,
# matrix:set-row, matrix:set-column, rnd:weighted-one-of
# Converted from old ? syntax to modern [[x] -> ...] lambdas.

struct BlackBoxModel <: AbstractBenchmarkModel end

model_name(::BlackBoxModel) = "BlackBox"
n_ticks(::BlackBoxModel) = 500
tracked_globals(::BlackBoxModel) = ["Q4t", "Q3t"]
world_dims(::BlackBoxModel) = (0, 19, 0, 19)
topology(::BlackBoxModel) = (false, false)

function netlogo_code(::BlackBoxModel)
"""
globals [ColorList Quad3Matrix Quad4Matrix Quad2Matrix NQuad2Matrix matrixlist Q1self Q1neighbor Q4t Q3t]
extensions [matrix rnd]

to setup
  clear-all
  set ColorList [0 4 105 125 85 55 15 25 137 139.9]
  set matrixlist [0 1 2 3 4 5 6 7 8 9]
  ask patches [set pcolor (item (random 10) ColorList)]
  let i 12
  let j 10
  while [i < 18] [
    while [j < 20] [
      ifelse random 2 = 1 [ask patch i j [set pcolor 139.9]] [ask patch i j [set pcolor 0]]
      set j (j + 1)
    ]
    set j 10
    set i (i + 1)
  ]

  setmatrices
  set Q1self [.99 .99 .813 .705 .652 .610 .545 .537 .507 .5]
  set Q1neighbor .499
  reset-ticks
end

to setmatrices
  set Quad4Matrix matrix:from-row-list
  [
    [1 0 0 0 0 0 0 0 0 0]
    [.4 0 .1 .05 .1 .05 .1 .05 .1 .05]
    [.55 0 0 0 .15 0 .15 0 .15 0]
    [.4 .05 .1 0 .1 .05 .1 .05 .1 .05]
    [.55 0 .15 0 0 0 .15 0 .15 0]
    [.5 0 0 0 0 .5 0 0 0 0]
    [.55 0 .15 0 .15 0 0 0 .15 0]
    [.4 .05 .1 .05 .1 .05 .1 0 .1 .05]
    [.55 0 .15 0 .15 0 .15 0 0 0]
    [.4 .05 .1 .05 .1 .05 .1 .05 .1 0]
  ]

  set Quad3Matrix matrix:from-row-list
  [
    [1 0 0 0 0 0 0 0 0 0]
    [.71 0 .07 .05 .04 .03 .05 .02 .01 .02]
    [.58 0 0 0 .25 0 .06 0 .11 0]
    [.55 .03 .06 0 .03 .01 .07 .01 .05 .19]
    [.6 0 .07 0 0 0 .25 0 .08 0]
    [.5 0 0 0 0 .5 0 0 0 0]
    [.77 0 .09 0 .09 0 0 0 .05 0]
    [.52 .05 .09 .01 .07 .03 .01 0 .09 .13]
    [.55 0 .16 0 .19 0 .1 0 0 0]
    [.56 .12 .02 .02 .07 .01 .09 .03 .08 0]
  ]

  set Quad2Matrix matrix:from-row-list
  [
    [1 0 0 0 0 0 0 0 0 0]
    [.4 0 .1 .05 .1 .05 .1 .05 .1 .05]
    [.55 0 0 0 .15 0 .15 0 .15 0]
    [.4 .05 .1 0 .1 .05 .1 .05 .1 .05]
    [.55 0 .15 0 0 0 .15 0 .15 0]
    [.5 0 0 0 0 .5 0 0 0 0]
    [.55 0 .15 0 .15 0 0 0 .15 0]
    [.4 .05 .1 .05 .1 .05 .1 0 .1 .05]
    [.55 0 .15 0 .15 0 .15 0 0 0]
    [.4 .05 .1 .05 .1 .05 .1 .05 .1 0]
  ]

  set NQuad2Matrix matrix:from-row-list
  [
    [1 0 0 0 0 0 0 0 0 0]
    [0 0 .17 .08 .17 .08 .17 .08 .17 .08]
    [0 0 0 0 .33 0 .33 0 .33 0]
    [0 .08 .17 0 .17 .08 .17 .08 .17 .08]
    [0 0 .33 0 0 0 .33 0 .33 0]
    [0 0 0 0 0 1 0 0 0 0]
    [0 0 .33 0 .33 0 0 0 .33 0]
    [0 .08 .17 .08 .17 .08 .17 0 .17 .08]
    [0 0 .33 0 .33 0 .33 0 0 0]
    [0 .08 .17 .08 .17 .08 .17 .08 .17 0]
  ]
end

to go
  ask one-of patches with [pxcor > 9 and pycor < 10] [set pcolor quad4]
  UpdateQ4

  ask one-of patches with [pxcor < 10 and pycor < 10] [set pcolor quad3]
  UpdateQ3

  ask one-of patches with [pxcor < 10 and pycor > 9] [set pcolor quad1]

  ask one-of patches with [pxcor > 9 and pycor > 9] [set pcolor quad2]

  if sum ([pcolor] of patches with [pxcor > 9 and pycor < 10]) = 0
  [set Q4t ticks]

  if sum ([pcolor] of patches with [pxcor < 10 and pycor < 10]) = 0
  [set Q3t ticks]
end

to UpdateQ4
  let idx 0
  while [idx < 10] [
    if (count patches with [pcolor = (item idx colorlist) and pxcor > 9 and pycor < 10]) = 0 [
      matrix:set-column Quad4Matrix idx [0 0 0 0 0 0 0 0 0 0]
      let row 0
      while [row < 10] [
        let rowsum sum (matrix:get-row Quad4Matrix row)
        if rowsum > 0 [
          let sums (1 / rowsum)
          matrix:set-row Quad4Matrix row (map [[x] -> x * sums] (matrix:get-row Quad4Matrix row))
        ]
        set row row + 1
      ]
    ]
    set idx idx + 1
  ]
end

to-report quad4
  let row-probs matrix:get-row Quad4Matrix (position pcolor colorlist)
  report item (rnd:weighted-one-of-list (n-values length ColorList [[i] -> i]) [[idx] -> item idx row-probs]) ColorList
end

to UpdateQ3
  let idx 0
  while [idx < 10] [
    if (count patches with [pcolor = (item idx colorlist) and pxcor < 10 and pycor < 10]) = 0 [
      matrix:set-column Quad3Matrix idx [0 0 0 0 0 0 0 0 0 0]
      let row 0
      while [row < 10] [
        let rowsum sum (matrix:get-row Quad3Matrix row)
        if rowsum > 0 [
          let sums (1 / rowsum)
          matrix:set-row Quad3Matrix row (map [[x] -> x * sums] (matrix:get-row Quad3Matrix row))
        ]
        set row row + 1
      ]
    ]
    set idx idx + 1
  ]
end

to-report quad3
  let row-probs matrix:get-row Quad3Matrix (position pcolor colorlist)
  report item (rnd:weighted-one-of-list (n-values length ColorList [[i] -> i]) [[idx] -> item idx row-probs]) ColorList
end

to-report quad1
  let CTP [0 0 0 0 0 0 0 0 0 0]
  let temp (position pcolor colorlist)
  set CTP replace-item temp CTP ((item temp Q1self) + (item temp CTP))

  ask neighbors with [pycor > 9 and pxcor < 10] [
    set temp (position pcolor colorlist)
    set CTP replace-item temp CTP (Q1neighbor + (item temp CTP))
  ]

  let btemp 8 - (count neighbors with [pycor > 9 and pxcor < 10])
  set CTP replace-item 0 CTP (btemp * Q1neighbor + (item 0 CTP))

  let temp2 max CTP
  let temp3 position temp2 CTP

  report (item temp3 colorlist)
end

to-report quad2
  if pxcor = 18 [
    if (pcolor = 0) [report 0]
    let tempx pxcor
    let tempy pycor
    ifelse (([pcolor] of patch (tempx - 1) tempy = 139.9) and ([pcolor] of patch (tempx - 2) tempy = 139.9))
    [report (item (10 - (position pcolor colorlist)) colorlist)]
    [ifelse random 10 = 0 [report 0] [report (item (10 - (position pcolor colorlist)) colorlist)]]
  ]

  if (pxcor = 10 or pxcor = 11) [
    let row-probs matrix:get-row Quad2Matrix (position pcolor colorlist)
    report item (rnd:weighted-one-of-list (n-values length ColorList [[i] -> i]) [[idx] -> item idx row-probs]) ColorList
  ]

  if pxcor = 19 [
    let tempx pxcor
    let tempy pycor
    ifelse (([pcolor] of patch (tempx - 1) tempy = 139.9) and ([pcolor] of patch (tempx - 2) tempy = 139.9))
    [
      let row-probs matrix:get-row NQuad2Matrix (position pcolor colorlist)
      report item (rnd:weighted-one-of-list (n-values length ColorList [[i] -> i]) [[idx] -> item idx row-probs]) ColorList
    ]
    [
      let row-probs matrix:get-row Quad2Matrix (position pcolor colorlist)
      report item (rnd:weighted-one-of-list (n-values length ColorList [[i] -> i]) [[idx] -> item idx row-probs]) ColorList
    ]
  ]

  if pxcor > 11 and pxcor < 18 [
    report 139.9
  ]

  report pcolor
end
"""
end
