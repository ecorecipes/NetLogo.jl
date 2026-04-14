# ── Simple Market with Table Extension ────────────────────────────────
# Source: modelingcommons #6882 (Simple_Market_Times_Table)
# Table extension: table:make, table:put, table:get, table:keys,
#   table:has-key?, table:length, table:remove
# Market model: traders hold stock in tables, shoppers walk between
# linked traders buying items. Shoppers die when their list is complete.
# Tests heavy table manipulation including foreach over table:keys.

struct SimpleMarketTableModel <: AbstractBenchmarkModel end

model_name(::SimpleMarketTableModel) = "Simple Market Table"
n_ticks(::SimpleMarketTableModel) = 200
tracked_globals(::SimpleMarketTableModel) = ["count shoppers", "sum [paces] of shoppers"]

function world_dims(::SimpleMarketTableModel)
    return (min_pxcor=-16, max_pxcor=16, min_pycor=-16, max_pycor=16)
end

function setup_commands(::SimpleMarketTableModel)
    return ""
end

extra_shapes(::SimpleMarketTableModel) = """
house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120
"""

netlogo_code(::SimpleMarketTableModel) = raw"""
extensions [table]
globals [stock number-of-items number-of-traders number-of-shoppers walking-speed mult modulo]

breed [traders trader]
breed [shoppers shopper]

traders-own [mystock]
shoppers-own [mylist speed paces currstall lastpos]

to setup
  clear-all
  set number-of-items 50
  set number-of-traders 50
  set number-of-shoppers 50
  set walking-speed 0.5
  set mult 5
  set modulo 43
  reset-ticks

  create-all-stocks
  create-all-traders
  layout-circle sort traders max-pxcor
  create-all-shoppers
end

to create-all-stocks
  let x 0
  set stock table:make
  while [x < number-of-items] [
    table:put stock x 0
    set x x + 1
  ]
end

to create-all-traders
  create-traders number-of-traders [
    set shape "house"
    set color red
    set mystock table:make
    set-mystock
  ]
  ask traders [
    let parner (who * mult mod modulo)
    if who != parner [
      if is-trader? turtle parner [
        create-link-with turtle parner
      ]
    ]
    ask my-links [ set color cyan ]
  ]
end

to set-mystock
  let x random 20
  let i 0
  while [i <= x] [
    let y random 50
    let z (random 20) + 1
    table:put mystock y z
    set i i + 1
  ]
end

to create-all-shoppers
  create-shoppers number-of-shoppers [
    set shape "default"
    set color green
    set mylist table:make
    set-mylist
    set speed random-float walking-speed + 0.001
    set paces 0
  ]
  ask shoppers [
    let stall one-of traders
    set currstall stall
    face currstall
    move-to [patch-here] of stall
    set lastpos patch-here
  ]
end

to set-mylist
  let x random 10
  let i 0
  while [i <= x] [
    let y random 50
    let z (random 5) + 1
    table:put mylist y z
    set i i + 1
  ]
end

to go
  if count shoppers <= 0 [ stop ]
  ask shoppers with [table:length mylist > 0] [
    let stall nobody
    ifelse any? [link-neighbors] of currstall [
      set stall one-of [link-neighbors] of currstall
    ] [
      set stall currstall
    ]

    if stall != currstall [
      set currstall stall
      face currstall
      move-to [patch-here] of stall
      let stall-stock nobody
      ask stall [set stall-stock mystock]
      set paces distance lastpos
      set lastpos patch-here
      foreach table:keys mylist [ [key] ->
        let n table:get mylist key
        if table:has-key? stall-stock key [
          let c table:get stall-stock key
          ifelse c >= n [table:put mylist key 0] [table:put mylist key n - c]
          ask stall [table:put mystock key (table:get mystock key - n)]
        ]
      ]
    ]
  ]
  clean-up
  tick
end

to clean-up
  ask shoppers [
    foreach table:keys mylist [ [key] ->
      if table:get mylist key <= 0 [table:remove mylist key]
    ]
    if table:length mylist = 0 [die]
  ]
  ask traders [
    foreach table:keys mystock [ [key] ->
      if table:get mystock key <= 0 [table:remove mystock key]
    ]
    if table:length mystock = 0 [set color white]
  ]
end
"""
