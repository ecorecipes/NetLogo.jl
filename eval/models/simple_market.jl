# ── Simple Market Random ──────────────────────────────────────────
# Source: modelingcommons #6881
# Table extension: trader stock and shopper shopping lists
# Shoppers visit traders in a circular layout and buy items.

struct SimpleMarketModel <: AbstractBenchmarkModel end

model_name(::SimpleMarketModel) = "Simple Market"
n_ticks(::SimpleMarketModel) = 200
tracked_globals(::SimpleMarketModel) = ["active-shoppers", "empty-traders"]
world_dims(::SimpleMarketModel) = (-16, 16, -16, 16)
topology(::SimpleMarketModel) = (false, false)
extra_shapes(::SimpleMarketModel) = """
house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120
"""

function netlogo_code(::SimpleMarketModel)
"""
extensions [table]

globals [
  stock
  number-of-items
  number-of-traders
  number-of-shoppers
  walking-speed
  active-shoppers
  empty-traders
]

breed [traders trader]
breed [shoppers shopper]

traders-own [mystock]
shoppers-own [mylist speed paces currstall lastpos]

to setup
  clear-all
  set number-of-items 50
  set number-of-traders 50
  set number-of-shoppers 50
  set walking-speed 1.0
  create-all-stocks
  create-all-traders
  layout-circle sort traders max-pxcor
  create-all-shoppers
  set active-shoppers count shoppers
  set empty-traders count traders with [color = white]
  reset-ticks
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
    while [ patch-here != [patch-here] of stall ] [ forward 0.05 * speed ]
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
  if (count shoppers <= 0) [ stop ]
  ask shoppers with [table:length mylist > 0] [
    let stall one-of traders
    if stall != currstall [
      set currstall stall
      face currstall
      while [ patch-here != [patch-here] of stall ] [ forward 0.05 * speed ]
      let stall-stock nobody
      ask stall [ set stall-stock mystock ]
      set paces distance lastpos
      set lastpos patch-here
      foreach ( table:keys mylist ) [
        [key] ->
        let n table:get mylist key
        if table:has-key? stall-stock key [
          let c table:get stall-stock key
          ifelse c >= n [ table:put mylist key 0 ] [ table:put mylist key n - c ]
          ask stall [ table:put mystock key (table:get mystock key - n) ]
        ]
      ]
    ]
  ]
  clean-up
  set active-shoppers count shoppers
  set empty-traders count traders with [color = white]
end

to clean-up
  ask shoppers [
    foreach (table:keys mylist) [
      [key] ->
      if table:get mylist key <= 0 [ table:remove mylist key ]
    ]
    if table:length mylist = 0 [ die ]
  ]
  ask traders [
    foreach (table:keys mystock) [
      [key] ->
      if table:get mystock key <= 0 [ table:remove mystock key ]
    ]
    if table:length mystock = 0 [ set color white ]
  ]
end
"""
end
