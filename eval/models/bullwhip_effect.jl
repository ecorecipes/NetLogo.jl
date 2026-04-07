# ── Bullwhip Effect model (CSS600 ClassModels) ───────────────────────

struct BullwhipEffectModel <: AbstractBenchmarkModel end

model_name(::BullwhipEffectModel) = "Bullwhip Effect"
n_ticks(::BullwhipEffectModel) = 100
tracked_globals(::BullwhipEffectModel) = ["count customers", "STOCKS"]
world_dims(::BullwhipEffectModel) = (-16, 16, -16, 16)
topology(::BullwhipEffectModel) = (false, false)

function netlogo_code(::BullwhipEffectModel)
"""
extensions [
  matrix
]

globals [
  N_Customers Max_Purchase N_Retailers N_Wholesalers N_Distributors
  retailers_increment wholesalers_increment alien-amount return-in-weeks
  STOCKS
  BUFFERS
  RETURN_FLAG
]

breed [customers customer]
breed [retailers retailer]
breed [retailers2 retailer2]
breed [wholesalers wholesaler]
breed [distributors distributor]
breed [aliens alien]

customers-own [frequency order_to_retailer lucky_number]
retailers-own [stock buffer backorder demand_log prediction prediction_log order_to_wholesaler]
retailers2-own [stock buffer backorder demand_log prediction prediction_log order_to_wholesaler]
wholesalers-own [stock buffer backorder demand_log prediction prediction_log order_to_distributor]
distributors-own [demand_log prediction prediction_log]

to setup
  clear-all
  set N_Customers 100
  set Max_Purchase 50
  set N_Retailers 1
  set N_Wholesalers 1
  set N_Distributors 1
  set retailers_increment 3
  set wholesalers_increment 3
  set alien-amount 400
  set return-in-weeks 10
  random-seed 47822

  create-customers N_Customers [
    set frequency 0
    set size 1
    set color (random-normal 35.5 1)
    set shape "person"
  ]

  create-retailers N_Retailers [
    set stock STOCKS
    set buffer BUFFERS
    set demand_log []
    set backorder 0
    set prediction 0
    set prediction_log [0]
    set size 4
    set shape "truck"
    set color 135
  ]

  create-retailers2 N_Retailers [
    set stock STOCKS
    set buffer BUFFERS
    set demand_log []
    set backorder 0
    set prediction 0
    set prediction_log [0]
    set size 4
    set shape "truck"
    set color 103
  ]

  create-wholesalers N_Wholesalers [
    set stock STOCKS * (count turtles with [breed = retailers]) / (count turtles with [breed = wholesalers])
    set buffer BUFFERS * (count turtles with [breed = retailers]) / (count turtles with [breed = wholesalers])
    set demand_log []
    set prediction 0
    set prediction_log [0]
    set size 4
    set shape "house"
    set color 86
    setxy 9 11
  ]

  create-distributors N_Distributors [
    set demand_log []
    set prediction 0
    set prediction_log [0]
    set size 5
    set shape "house"
    set color 25
    setxy 9 11
  ]

  ask customers [frequency_chooser]
  ask customers [order_chooser]

  ask customers [get_open_customers]
  ask retailers [get_open_not_customers]
  ask retailers2 [get_open_not_customers]
  ask wholesalers [get_open_not_customers]
  ask distributors [get_open_not_customers]

  color-patches
  reset-ticks
end

to go
  step
end

to ten_steps
  repeat 10 [step]
end

to step
  if (RETURN_FLAG >= 1)[
    ifelse (RETURN_FLAG = 1)[
    create-customers (N_Customers - (count turtles with [breed = customers])) [
      set frequency 0
      set size 1
      set color (random-normal 125.5 1)
      set shape "person"
      ask customers with [xcor = 0] [frequency_chooser]
      ask customers with [xcor = 0] [order_chooser]
      ask customers with [xcor = 0] [get_open_customers]
    ]
    set RETURN_FLAG RETURN_FLAG - 1]
    [set RETURN_FLAG RETURN_FLAG - 1]]

  if (((count turtles with [breed = customers]) < N_Customers) and RETURN_FLAG = 0)
  [set RETURN_FLAG return-in-weeks]

  ask customers[whos_shopping]

  ask retailers[update_retailers_demand_log]
  ask retailers2[update_retailers_demand_log]
  ask retailers[make-prediction]
  ask retailers2[make-prediction]
  ask retailers[update_retailers]
  ask retailers2[update_retailers]

  ask wholesalers[update_wholesalers_demand_log]
  ask wholesalers[make-prediction]
  ask wholesalers[update_wholesalers]

  ask distributors[update_distributors_demand_log]
  ask distributors[make-prediction]

  ask customers [frequency_chooser]
  tick
end

to setup-globals
  set STOCKS ((count turtles with [breed = customers]) * (random Max_Purchase * 0.5 + 1))
  set BUFFERS ((count turtles with [breed = customers]) * random Max_Purchase * 0.5)
  set RETURN_FLAG 0
end

to whos_shopping
  set lucky_number random 3
end

to get_open_customers
  setxy random-xcor random-ycor
  while [any? other turtles-here or ycor >= 8 or ycor <= -15 or xcor >= 15 or xcor <= -15 or xcor = 0]
      [get_open_customers]
end

to get_open_not_customers
  setxy random-xcor random-ycor
  while [any? other turtles-here or ycor <= 8 or ycor >= 15 or xcor >= 15 or xcor <= -15]
      [get_open_not_customers]
end

to color-patches
  ask patches [
    set pcolor scale-color
    green 19
    5 30
  ]
end

to link-up
   ask customers [create-link-with one-of other turtles with [breed = retailers or breed = retailers2]]
   ask retailers [create-link-with one-of other turtles with [breed = wholesalers]]
   ask retailers2 [create-link-with one-of other turtles with [breed = wholesalers]]
   ask wholesalers [create-link-with one-of other turtles with [breed = distributors]]
end

to frequency_chooser
  let temp round (random-normal 2 2)
  ifelse (temp > 0)
  [set frequency temp]
  [set frequency 1]
end

to order_chooser
  let temp ((random-normal round(Max_purchase / 2) ((Max_purchase - round(Max_purchase / 2)) / 3)))
  ifelse (temp > 0)
  [ifelse (temp > Max_purchase)
    [set order_to_retailer Max_purchase]
    [set order_to_retailer temp]
  ]
  [set order_to_retailer ((random-float  Max_purchase - 0.1) + 0.1)]
end

to update_retailers_demand_log
  set demand_log lput(sum [order_to_retailer] of customers with [lucky_number = 0]) demand_log
end

to update_retailers
  ifelse (((last demand_log) + backorder) > stock)
  [set backorder ((last demand_log ) - stock)
    set stock 0
    set order_to_wholesaler (backorder + (buffer - stock))
    set stock (stock + backorder + (buffer - stock))]
  [set stock (stock - (last demand_log))
    set backorder 0
    if ((buffer - stock) > 0)
    [set order_to_wholesaler (backorder + (buffer - stock))
     set stock (stock + (backorder + (buffer - stock)))]]
  if (stock - prediction) < buffer
  [set order_to_wholesaler (order_to_wholesaler + (prediction - stock))
   set stock (stock + (order_to_wholesaler + (prediction - stock)))]
end

to update_wholesalers_demand_log
  set demand_log lput(sum [order_to_wholesaler] of retailers) demand_log
end

to update_wholesalers
  ifelse (((last demand_log) + backorder) > stock)
  [set backorder ((last demand_log ) - stock)
    set stock 0
    set order_to_distributor (backorder + (buffer - stock))
    set stock (stock + (backorder + (buffer - stock)))]
  [set stock (stock - (last demand_log))
    set backorder 0
    if ((buffer - stock) > 0)
    [set order_to_distributor (backorder + (buffer - stock))
     set stock (stock + (backorder + (buffer - stock)))]]
  if ((stock - prediction) < buffer)
  [set order_to_distributor (order_to_distributor + (prediction - stock))
   set stock (stock + (order_to_distributor + (prediction - stock)))]
end

to update_distributors_demand_log
  ask distributors[set demand_log lput(sum [order_to_distributor] of wholesalers) demand_log]
end

to make-prediction
  let prediction_holder []
  ifelse (((ticks mod retailers_increment) = 0 and (breed = retailers or breed =  retailers2)) or ((ticks mod wholesalers_increment) = 0 and breed = wholesalers))[
    ifelse (length(demand_log) >= 1) and (max demand_log > 0)
    [ifelse (breed != retailers2) [set prediction_holder matrix:forecast-continuous-growth demand_log]
      [set prediction_holder matrix:forecast-linear-growth demand_log]]
    [set prediction_holder lput(last prediction_log) prediction_holder
      set prediction_holder lput(min demand_log) prediction_holder
      set prediction_holder lput(0) prediction_holder
      set prediction_holder lput(0) prediction_holder]
    set prediction item 0 prediction_holder
    set prediction_log lput(prediction) prediction_log
  ]
  [set prediction_holder lput(last prediction_log) prediction_holder
    set prediction item 0 prediction_holder
    set prediction_log lput(prediction) prediction_log]
end

to lottery_winner
  ask customers [set order_to_retailer (order_to_retailer + random (Max_Purchase)) * frequency]
end

to alien_strike
  create-aliens alien-amount [
    set size 0.5
    set color (random-normal 121 0.5)
    set shape "circle"
    setxy random-pxcor random-pycor
    while [ycor >= 8 or ycor <= -15 or xcor >= 15 or xcor <= -15]
    [setxy random-pxcor random-pycor]
  ]
  ask customers [if any? other turtles-here [die]]
  ask aliens [die]
end
"""
end
