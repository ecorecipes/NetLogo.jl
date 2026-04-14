# Simple Market Random Model
# table extension: table:make, table:put, table:get, table:has-key?, table:keys,
#                  table:length, table:remove in go loop
# Simulates shoppers visiting traders to buy items from random inventories
# Source: modelingcommons #6881

struct SimpleMarketRandomModel <: AbstractBenchmarkModel end

model_name(::SimpleMarketRandomModel) = "Simple Market Random"
n_ticks(::SimpleMarketRandomModel) = 200  # model self-stops when shoppers = 0
tracked_globals(::SimpleMarketRandomModel) = ["num-shoppers-left", "num-traders-with-stock"]
world_dims(::SimpleMarketRandomModel) = (-16, 16, -16, 16)
topology(::SimpleMarketRandomModel) = (false, false)

function extra_shapes(::SimpleMarketRandomModel)
    return """
house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120
"""
end

function netlogo_code(::SimpleMarketRandomModel)
    return """
extensions [table]
globals [stock num-shoppers-left num-traders-with-stock
         number-of-items number-of-traders number-of-shoppers]

breed [traders trader]
breed [shoppers shopper]

traders-own [mystock]
shoppers-own [mylist currstall lastpos]

to setup
  clear-all
  set number-of-items 50
  set number-of-traders 20
  set number-of-shoppers 20
  create-all-stocks
  create-all-traders
  layout-circle sort traders max-pxcor
  create-all-shoppers
  update-counts
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
  ]
  ask shoppers [
    let stall one-of traders
    set currstall stall
    move-to stall
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
  if (count shoppers <= 0) [stop]
  ask shoppers with [table:length mylist > 0] [
    let stall one-of traders
    if stall != currstall [
      set currstall stall
      move-to stall
      let stall-stock nobody
      ask stall [set stall-stock mystock]
      set lastpos patch-here
      foreach ( table:keys mylist ) [
        [key] ->
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
  update-counts
  tick
end

to clean-up
  ask shoppers [
    foreach (table:keys mylist) [
      [key] ->
      if table:get mylist key <= 0 [table:remove mylist key]
    ]
    if table:length mylist = 0 [die]
  ]
  ask traders [
    foreach (table:keys mystock) [
      [key] ->
      if table:get mystock key <= 0 [table:remove mystock key]
    ]
    if table:length mystock = 0 [set color white]
  ]
end

to update-counts
  set num-shoppers-left count shoppers
  set num-traders-with-stock count traders with [color = red]
end
"""
end
