# ── Artificial Economy model (CSS600 ClassModels) ────────────────────

struct ArtificialEconomyModel <: AbstractBenchmarkModel end

model_name(::ArtificialEconomyModel) = "Artificial Economy"
n_ticks(::ArtificialEconomyModel) = 200
tracked_globals(::ArtificialEconomyModel) = ["count farmers", "count professionals"]
world_dims(::ArtificialEconomyModel) = (0, 39, 0, 39)
topology(::ArtificialEconomyModel) = (false, false)

function netlogo_code(::ArtificialEconomyModel)
"""
globals [farm-patches city-patches trade-patches
  fuel-grow-rate productivity-cityworld depreciation productivity-farmerworld
  produce-supply-level widget-supply-level markup population]
patches-own [yield prod]
turtles-own [produce widget money age ptrade wtrade ptrade-t-1 ptrade-t-2 ptrade-t-3
  ptrade-t-4 ptrade-t-5 ptrade-t-6 ptrade-t-7   wtrade-t-1 wtrade-t-2 wtrade-t-3
  wtrade-t-4 wtrade-t-5 wtrade-t-6  wtrade-t-7 deposit pexchange wexchange mexchange
  savings capital pdebt fdebt securities productivity pprice wprice
  farmer-interest-rate professional-interest-rate withdraw
  reserve-ratio produce-purchaseprice produce-saleprice widget-purchaseprice
  widget-saleprice fbusiness pbusiness wealth savings_propensity bankrupt]
breed [farmers farmer]
breed [professionals professional]
breed [stores store]
breed [farmerBanks farmerBank]
breed [professionalBanks professionalBank]

to step
  go
end

to go
  set-interest-rate
  repay
  disaster
  ifelse random 100 < 50 [
    move-farmers
    move-professionals]
  [
    move-professionals
    move-farmers]
  renew-fuel
  store-deposit
  bankruptcy
  compound-interest
  borrow-emergency-funds
  update-macro-stats
  trades-last-period
  tick
end

to setup
  clear-all
  set fuel-grow-rate 5
  set productivity-cityworld 5
  set depreciation 0.1
  set productivity-farmerworld 5
  set produce-supply-level 20
  set widget-supply-level 20
  set markup 1
  set population 100
  setup-landscape
  setup-population
  setup-infrastructure
  setup-prices
  setup-interest-rates
  update-macro-stats
  reset-ticks
end

to setup-landscape
  set farm-patches patches with [pxcor < 20]
  ask farm-patches [ set pcolor green ]
  ask farm-patches [ set yield 1 ]
  set city-patches patches with [pxcor > 20 ]
  ask city-patches [set pcolor red]
  ask city-patches [set yield 1]
  set trade-patches patches with [pxcor = 20 ]
  ask trade-patches [set pcolor blue]
end

to setup-population
  create-farmers population [
    set shape "person farmer"
    set productivity 1
    move-to-empty-one-of farm-patches
    set color white
    set size 1
    set age 1
    set money random-normal 50 20
    set savings_propensity random-normal 5 2
    if savings_propensity < 1 [
      set savings_propensity 1]
    set bankrupt 0
  ]
  create-professionals population [
    set shape "person business"
    set productivity 1
    move-to-empty-one-of city-patches
    set color white
    set size 1
    set age 1
    set money random-normal 50 20
    set savings_propensity random-normal 5 2
    if savings_propensity < 1 [
      set savings_propensity 1]
    set bankrupt 0
  ]
end

to move-to-empty-one-of [locations]
  move-to one-of locations
  while [any? other turtles-here] [
    move-to one-of locations
  ]
end

to setup-infrastructure
  create-stores 1
  [
    set shape "store"
    setxy 20 20
    set color white
    set size 1
    set produce 0
    set money 500 * (count professionals + count farmers)
  ]
  create-farmerBanks 1
  [
    set shape "bank"
    setxy 10 10
    set color yellow
    set size 1
  ]
  create-professionalBanks 1
  [
    set shape "bank"
    setxy 30 10
    set color white
    set size 1
  ]
end

to set-productivity
  ask farmers [
    set productivity 1 + (widget) ^ (1 / 2)
  ]
  ask professionals
  [ set productivity 1 + (produce) ^ (1 / 2)]
end

to setup-prices
  ask stores[
    set pprice 100
    set wprice 100
  ]
end

to setup-interest-rates
  ask farmerBanks [
    set farmer-interest-rate 0.002]
  ask professionalBanks [
    set professional-interest-rate 0.002]
end

to move-farmers
  ask farmers [
    set age age + 1
    set-productivity
    ifelse produce < random-normal 50 15 [
      find-new-farmerLocation]
    [next-stepf]
    set widget widget * (1 - depreciation)
  ]
end

to find-new-farmerLocation
   let nearest-farm-patch one-of (neighbors with [pcolor = green])
   ifelse is-patch? nearest-farm-patch[
   face nearest-farm-patch
   fd 1
   ask patch-here [
     if pcolor = green [
     set pcolor black]  ]
   set produce produce + (yield * productivity)
   ]
   [
     let nearest-black-patch one-of (neighbors with [pcolor = black])
     ifelse is-patch? nearest-black-patch [
       face nearest-black-patch
       fd 1
   ]
     [
       let target one-of farmerBanks
       if distance target > 0 [face target]
       fd 1]
   ]
 end

to next-stepf
  getMoney-farmer
  ifelse money  + savings + produce * [pprice] of one-of stores + widget * [wprice] of one-of stores - fdebt > (1 + markup) * [wprice] of one-of stores
  [getWidget-farmer]
  [find-new-farmerLocation]
 if random 10 < 1 [deposit-farmer-savings]
end

to move-professionals
  ask professionals [
    set age age + 1
    set-productivity
    ifelse widget < random-normal 50 15
    [find-new-professionalLocation]
    [next-stepp]
    set produce produce * (1 - depreciation)
  ]
end

 to find-new-professionalLocation
   let nearest-city-patch one-of (neighbors with [pcolor = red])
   ifelse is-patch? nearest-city-patch [
   fd 1
   ask patch-here [
     if pcolor = red [
     set pcolor yellow]]
   set widget widget + (yield * productivity)
   ]
   [
     let nearest-yellow-patch one-of (neighbors with [pcolor = yellow])
     ifelse is-patch? nearest-yellow-patch [
       face nearest-yellow-patch
       fd 1]
     [let target one-of professionalBanks
       if distance target > 0 [face target]
       fd 1]
   ]
 end

to next-stepp
    getMoney-professional
   ifelse money + savings + produce * [pprice] of one-of stores + widget * [wprice] of one-of stores - pdebt > (1 + markup * [pprice]  of one-of stores)
   [ getProduce-professional]
   [find-new-professionalLocation]
    if random 10 < 1 [deposit-professional-savings]
end

to getMoney-farmer
  ask stores [
    set-prices
    if money < pprice * [produce] of myself[
      set fbusiness true
      store-withdraw]
    if money < pprice * [produce] of myself [
      set fbusiness true
      borrow-store]]
  if produce >= 1 and ([money] of one-of stores ) >=  [pprice] of one-of stores[
    while [produce >= 1 and ([money] of one-of stores ) >= [pprice] of one-of stores]
      [
        set money money + [pprice] of one-of stores
        set produce produce - 1
        ask one-of stores [
          set produce produce + 1
          set money money - pprice
          set produce-purchaseprice pprice
                      ]
      ]
    ]
end

to getWidget-Farmer
  set-prices
  if money + savings > ( 1 + markup) *  [wprice] of one-of stores and money < ( 1 + markup) * [wprice] of one-of stores and [widget] of one-of stores >= 1 [
    withdraw-farmer-savings]
  if money < [wprice] of one-of stores [
    borrow-farmer]
  if money >= ( 1 + markup) * [wprice] of one-of stores and ([widget] of one-of stores) >= 1 [
    while [money >= ( 1 + markup) * savings_propensity * [wprice] of one-of stores and ([widget] of one-of stores) >= 1] [
        set widget widget + 1
        set money money - ( 1 + markup) * [wprice] of one-of stores
        ask one-of stores [
          set money money + ( 1 + markup) * wprice
          set widget widget - 1
          set wtrade wtrade + 1
          set widget-saleprice ( 1 + markup) * [wprice] of one-of stores
                 ]
      ]
    ]
end

to getMoney-professional
  set-prices
  if [money] of one-of stores < wprice * widget [
   ask stores [
     set pbusiness true
     store-withdraw]]
  if [money] of one-of stores < wprice * widget[
    ask stores [
      set pbusiness true
      borrow-store]]
 if widget >= 1 and ([money] of one-of stores) >= wprice [
    while [widget >= 1 and ([money] of one-of stores) >= wprice]
      [
        set money money + wprice
        set widget widget - 1
        ask one-of stores [
          set money money - wprice
          set widget widget + 1
          set widget-purchaseprice  wprice]
      ]
    ]
end

to getProduce-professional
  set-prices
  if money < (1 + markup) * [pprice] of one-of stores and money + savings > (1 + markup) * [pprice] of one-of stores [
    withdraw-professional-savings]
  if money < (1 + markup) * [pprice] of one-of stores [
    borrow-professional]
  if money >= ( 1 + markup) * [pprice] of one-of stores and ([produce] of one-of stores) >= 1 [
    while [money >= ( 1 + markup) * savings_propensity * [pprice] of one-of stores and ([produce] of one-of stores) >= 1]
      [
        set money money - ( 1 + markup) * [pprice] of one-of stores
        set produce produce + 1
        ask one-of stores [
          set money money + ( 1 + markup) * pprice
          set produce produce - 1
          set ptrade ptrade + 1
          set produce-saleprice ( 1 + markup) * pprice
          ]
      ]
    ]
end

to set-prices
  ask stores [
    if wealth > 0 [
   if widget > 0 and widget < 1 * widget-supply-level * (count farmers) [
     set wprice wprice * 1.0001]
   if widget < 2 * widget-supply-level * (count farmers)[
     set wprice wprice * 1.00005]
   if widget < 3 * widget-supply-level * (count farmers) [
     set wprice wprice * 1.00005]]

    if widget > 7 * widget-supply-level * (count farmers) [
      set wprice wprice * 0.9999]
    if widget > 8 * widget-supply-level * (count farmers) [
      set wprice wprice * 0.9999]
    if widget > 9 * widget-supply-level * (count farmers) [
      set wprice wprice * 0.9995]

    if wprice < 0.1 [
      set wprice wprice * 1.000000000001]

    if wealth > 0 [
    if produce > 0 and produce < 1  * produce-supply-level * (count professionals)[
      set pprice pprice * 1.0001]
    if produce < 2 * produce-supply-level * (count professionals)[
      set pprice pprice * 1.00005]
    if produce < 3 * produce-supply-level * (count professionals)[
      set pprice pprice * 1.00005]  ]
    if produce > 7 * produce-supply-level * (count professionals)[
      set pprice pprice * 0.9999]
    if produce > 8 * produce-supply-level * (count professionals)[
      set pprice pprice * 0.9999]
    if produce > 9 * produce-supply-level * (count professionals)[
      set pprice pprice * 0.9995]

    if pprice < 0.1 [set pprice pprice * 1.000000000001]

    if money + savings - pdebt - fdebt < 0 [
      set pprice pprice * 0.9995
      set wprice wprice * 0.9995]
  ]

  ask farmers[
    set pprice [pprice] of one-of stores
    set wprice [wprice] of one-of stores]
  ask professionals[
    set pprice [pprice] of one-of stores
    set wprice [wprice] of one-of stores]
  ask farmerBanks [
    set pprice [pprice] of one-of stores
    set wprice [wprice] of one-of stores]
  ask professionalBanks [
    set pprice [pprice] of one-of stores
    set wprice [wprice] of one-of stores]
end

to trades-last-period
  ask stores [
    if ticks > 20 [
    if wtrade = wtrade-t-7[
      set wprice wprice * 0.95]
    if wtrade = wtrade-t-6[
      set wprice wprice * 0.98]
    if wtrade = wtrade-t-5[
      set wprice wprice * 0.98]
    if ptrade = ptrade-t-7[
      set pprice pprice * 0.95]
    if ptrade = ptrade-t-6[
      set pprice pprice * 0.98]
    if ptrade = ptrade-t-5[
      set pprice pprice * 0.98]
    if random 20 < 1 [set wprice wprice * 1.05]
    if random 20 < 1 [set pprice pprice * 1.05]
   set ptrade-t-7 ptrade-t-6
   set wtrade-t-7 wtrade-t-6
   set ptrade-t-6 ptrade-t-5
   set wtrade-t-6 wtrade-t-5
   set ptrade-t-5 ptrade-t-4
   set wtrade-t-5 wtrade-t-4
   set ptrade-t-4 ptrade-t-3
   set wtrade-t-4 wtrade-t-3
   set ptrade-t-3 ptrade-t-2
   set wtrade-t-3 wtrade-t-2
   set ptrade-t-2 ptrade-t-1
   set wtrade-t-2 wtrade-t-1
   set ptrade-t-1 ptrade
   set wtrade-t-1 wtrade
    ]
  ]
end

to borrow-emergency-funds
  ask farmerBanks
  [
    if [money] of one-of professionalBanks / ([securities] of one-of professionalBanks  + 0.000000001) > 0.01  [
      set pdebt pdebt + 100
      set money money + 100
      ask one-of professionalBanks [
        set money money - 100
        set securities securities + 100]
    ]
    if money > 0.1 * pdebt [
      set deposit pdebt * 0.1
      set money money - deposit
      set pdebt pdebt - deposit
    ask one-of professionalBanks
      [
        set money money + [deposit] of myself
        set securities securities - [deposit] of myself
      ]
    ]
  ]

  ask professionalBanks [
   if [money] of one-of farmerBanks / ([securities] of  one-of farmerBanks + 0.000000001) > 0.01 [
    set fdebt fdebt + 100
    set money money + 100
   ask one-of farmerBanks [
     set money money - 100
     set securities securities + 100]
   ]
   if money > 0.1 * pdebt [
   set deposit fdebt * 0.1
   set money money - deposit
   set fdebt fdebt - deposit
   ask one-of farmerBanks [
     set money money + [deposit] of myself
     set securities securities - [deposit] of myself]
   ]
    ]
end

to farmer-professional-switch
  ask farmers[
    if random 10 < 1 and (count farmers) / (count professionals) > 0.1 and [pprice] of one-of stores > 0[
      let price-ratio ( [wprice] of one-of stores / [pprice] of one-of stores)
      if ( price-ratio ) > 2 [
        set deposit 50 * price-ratio
        if money > deposit [
          set money money - deposit
          ask one-of stores [
            set money money + [deposit] of myself ]
          hatch-professionals 1 [
            set money money
            set produce produce
            set fdebt fdebt
            set widget widget
             ]
          die
      ]
    ]
  ]
  ]
  ask professionals[
    if random 10 < 1 and (count professionals) / (count farmers) > 0.1 and [wprice] of one-of stores > 0 [
      let price-ratio ( [pprice] of one-of stores / [wprice] of one-of stores)
      if (price-ratio) > 2 [
        set deposit 50 * price-ratio
        if money > deposit [
          set money money - deposit
          ask one-of stores[
            set money money + [deposit] of myself]
          hatch-farmers 1[
            set money money
            set produce produce
            set widget widget
            set pdebt pdebt   ]
          die
      ]
    ]
  ]
  ]
end

to borrow-store
    ifelse random 100 < 50 [
      if fbusiness = true [
         while [money < 1.1 * pprice * [produce] of myself  and  [money] of one-of farmerBanks / ([securities] of one-of farmerBanks + 0.00000000001) > 0.1
           and fdebt + pdebt < 0.9 * (produce * pprice + widget * wprice + money + savings)][
       ask one-of farmerBanks [
        set securities securities + [pprice] of one-of stores
         set money money - [pprice] of one-of stores]
       set fdebt fdebt + pprice
       set money money + pprice]]]
   [ if pbusiness = true [
      while [money < 1.1 * wprice * [widget] of one-of stores  and [money] of one-of professionalBanks / ([securities] of one-of professionalBanks + 0.0000000000001) > 0.1 and
         fdebt + pdebt < 0.9 * (produce * pprice + widget * wprice + money + savings)][
      ask one-of professionalBanks [
        set securities securities + [wprice] of one-of stores
        set money money - [wprice] of one-of stores]
      set pdebt pdebt + wprice
      set money money + wprice
    ]]]
end

to borrow-farmer
  while[  money <  (1 + markup) * wprice * [widget] of one-of stores and [money] of one-of farmerBanks > (1 + markup) * wprice and
     fdebt < 0.99 * pprice * (produce + wprice * widget + money + savings)] [
    set fdebt fdebt + (1 + markup) * wprice
    set money money + (1 + markup) * wprice
    ask one-of farmerBanks [
      set securities securities + (1 + markup) *  wprice
      set money money - (1 + markup) * wprice]
  ]
end

to borrow-professional
  while [money < (1 + markup) *  pprice * [produce] of one-of stores  and [money] of one-of professionalbanks > (1 + markup) *  pprice and
  pdebt < 0.99 * (pprice * produce + wprice * widget + money + savings - pdebt)][
    set pdebt pdebt + (1 + markup) * pprice
    set money money + (1 + markup) * pprice
    ask one-of professionalBanks [
      set securities securities + (1 + markup) * pprice
      set money money - (1 + markup) * pprice]
  ]
  set-interest-rate
end

to repay
ask stores [
  if money >  (pprice) and fdebt > 0 and money > 0.1 * fdebt[
    set deposit fdebt * 0.1
    set fdebt fdebt - deposit
    set money money - deposit
    ask one-of farmerBanks [
      set securities securities - [deposit] of myself
      set money money + [deposit] of myself]
]
  if fdebt > 0 and savings > 0.1 * fdebt[
    set deposit fdebt * 0.1
    set fdebt fdebt - deposit
    set savings savings - deposit
    ask one-of farmerBanks[
      set securities securities -[deposit] of myself]
    ]
if pdebt > 0 and money > 0.1 * pdebt[
    set deposit pdebt * 0.1
    set pdebt pdebt - deposit
    set money money - deposit
    ask one-of professionalBanks [
      set securities securities - [deposit] of myself
      set money money + [deposit] of myself
    ]
]
if pdebt > 0 and savings > 0.1 * pdebt [
  set deposit pdebt * 0.1
  set pdebt pdebt - deposit
  set savings savings - deposit
  ask one-of professionalBanks[
    set securities securities - [deposit] of myself]
]
  ]
ask farmers [
  set mexchange fdebt * 0.05
if money > wprice and money > mexchange [
  set fdebt fdebt - mexchange
  set money money - mexchange
  ask one-of farmerBanks [
    set securities securities - [mexchange] of myself
    set money money + [mexchange] of myself
  ]
]
if savings > [wprice] of one-of stores and savings > mexchange[
  set fdebt fdebt - mexchange
  set savings savings - mexchange
  ask one-of farmerbanks[
    set securities securities - mexchange]
]
]
ask professionals[
  set mexchange pdebt * 0.05
  if money > pprice and money > mexchange [
    set pdebt pdebt - mexchange
    set money money - mexchange
    ask one-of professionalBanks [
      set securities securities - [mexchange] of myself
      set money money + [mexchange] of myself
    ]
  ]
  if savings > [pprice] of one-of stores and savings > mexchange[
    set pdebt pdebt - mexchange
    set savings savings - mexchange
    ask one-of farmerbanks[
      set securities securities - mexchange]
  ]
]
end

to bankruptcy
ask farmers [
  if money + savings - fdebt + produce * [pprice] of one-of stores + widget * [wprice] of one-of stores < 0 [
    ask one-of farmerBanks [
      set money money + [money] of myself
      set securities securities - [fdebt] of myself
    ]
    set money 0
    set savings 0
    set fdebt 0
    set produce 0
    set widget 0
    set bankrupt bankrupt + 1]
  ]
ask professionals [
  if money + savings - pdebt + produce * [pprice] of one-of stores + widget * [wprice] of one-of stores < 0 * wealth [
    ask one-of professionalBanks [
      set money money + [money] of myself
      set securities securities - [pdebt] of myself]
    ask professionals [
      set savings savings + ([savings] of myself / ((count professionals) - 1 ))
      set produce produce + ([produce] of myself / ((count professionals) - 1 ))
      set widget widget + ([widget] of myself / ((count professionals) - 1 )) ]
    set money 0
    set savings 0
    set pdebt 0
    set produce 0
    set widget 0
    set bankrupt bankrupt + 1
  ]
]
end

to set-interest-rate
  ask farmerBanks [
    if farmer-interest-rate > 0.00002 and ([securities] of one-of farmerBanks) > 0 [
      if money  < 0.5 * sum [money] of farmers [
        set farmer-interest-rate farmer-interest-rate * 1.0000005]
      if money < 0.4 * sum [money] of farmers [
        set farmer-interest-rate farmer-interest-rate * 1.000001]
      if money < 0.2 * sum [money] of farmers [
        set farmer-interest-rate farmer-interest-rate * 1.000002]
      if money > 0.6 * sum [money] of farmers [
        set farmer-interest-rate farmer-interest-rate * 0.999995]
      if money > 0.65 * sum [money] of farmers [
        set farmer-interest-rate farmer-interest-rate * 0.999999]
      if money > 0.7 * sum [money] of farmers [
        set farmer-interest-rate farmer-interest-rate * 0.999998]
    ]
    if farmer-interest-rate = 0 [ set farmer-interest-rate 0.00001]
    if farmer-interest-rate > 0.01 [ set farmer-interest-rate 0.01]
  ]
  ask professionalBanks [
      if money  < 0.05 * sum [money] of professionals [
        set professional-interest-rate professional-interest-rate * 1.000005]
      if money < 0.1 * sum [money] of professionals [
        set professional-interest-rate professional-interest-rate * 1.000001]
      if money < 0.2 * sum [money] of professionals [
        set professional-interest-rate professional-interest-rate * 1.000002]
      if money > 0.5 * sum [money] of farmers [
        set professional-interest-rate professional-interest-rate * 0.999995]
      if money > 0.6 * sum [money] of farmers [
        set professional-interest-rate professional-interest-rate * 0.999999]
      if money > 0.7 * sum [money] of farmers [
        set professional-interest-rate professional-interest-rate * 0.999998]
    if professional-interest-rate < 0.0002 [ set professional-interest-rate professional-interest-rate * 0.00001]
    if professional-interest-rate = 0 [ set professional-interest-rate 0.00001]
    if professional-interest-rate > 0.01 [ set professional-interest-rate 0.01]
  ]
end

to compound-interest
  ask stores [
    set savings savings * (1 + professional-interest-rate )
    set pdebt pdebt * (1 + professional-interest-rate)
    set fdebt fdebt * (1 + farmer-interest-rate)
    set securities securities * (1 + professional-interest-rate) ]

  ask farmerBanks [
    set savings savings * (1 + professional-interest-rate)
    set pdebt pdebt * ( 1 + professional-interest-rate)
    set securities securities * (1 + farmer-interest-rate)]

  ask professionalBanks[
    set savings savings * (1 + farmer-interest-rate)
    set fdebt fdebt * (1 + (farmer-interest-rate))
    set securities securities * (1 + professional-interest-rate)]

  ask farmers [
      set savings savings * (1 + farmer-interest-rate)
      set fdebt fdebt * (1  + farmer-interest-rate)
    ]

    ask professionals [
        set pdebt pdebt * (1 + professional-interest-rate)
        set savings savings * (1 + professional-interest-rate)
    ]
end

to store-deposit
  ask stores [
    ifelse random 100 < 50 and money > 5 * pprice [
      set deposit 0.05 * (money - 5 * pprice)
      set money money - deposit
      set savings savings + deposit
     ask one-of farmerBanks [
        set money money + [deposit] of myself
      ]]
    [if money > 5 * wprice [
      set deposit 0.05 * (money - 5 * wprice)
      set money money - deposit
      set savings savings + deposit
      ask one-of professionalBanks [
        set money money + [deposit] of myself
      ]]]]
end

to store-withdraw
    if fbusiness = true [
    while [money < pprice * [produce] of myself  and savings >= pprice and [money] of one-of farmerBanks > pprice] [
      set withdraw pprice
      set money money + withdraw
      set savings savings - withdraw
      ask one-of farmerBanks [
        set money money - [withdraw] of myself
      ]]]

    if pbusiness = true[
     while [money < wprice * [widget] of myself and savings >= wprice and [money] of one-of professionalBanks > wprice ][
      set withdraw wprice
      set money money + withdraw
      set savings savings - withdraw
     ask one-of professionalBanks [
        set money money - [withdraw] of myself
      ]]]
      set-interest-rate
end

to withdraw-farmer-savings
  while [ money < ( 1 + markup) * [wprice] of one-of stores * [widget] of one-of stores and savings > ( 1 + markup) * [wprice] of one-of stores and
    [money] of one-of farmerBanks > ( 1 + markup) * [wprice] of one-of stores] [
      set withdraw ( 1 + markup) * [wprice] of one-of stores
      set money money + withdraw
      set savings savings - withdraw
      ask one-of farmerBanks[
        set money money - (1 + markup) * [wprice] of one-of stores
      ]
      ]
end

to deposit-farmer-savings
  if money > [wprice] of one-of stores [
    set deposit (money - [wprice] of one-of stores) * 0.1
    set money money - deposit
    set savings savings + deposit
    ask one-of farmerBanks[
      set money money + [deposit] of myself]
  ]
  set-interest-rate
end

to withdraw-professional-savings
  while[ money < ( 1 + markup) * [pprice] of one-of stores * [produce] of one-of stores and savings > ( 1 + markup) * [pprice] of one-of stores and
    [money] of one-of professionalBanks > ( 1 + markup) * [pprice] of one-of stores] [
      set withdraw ( 1 + markup) *  [pprice] of one-of stores
      set money money + withdraw
      set savings savings - withdraw
      ask one-of professionalBanks[
        set money money -  ( 1 + markup) * [pprice] of one-of stores
      ]
      ]
end

to deposit-professional-savings
  if money > [pprice] of one-of stores [
    set deposit (money - [pprice] of one-of stores) * 0.1
    set money money - deposit
    set savings savings + deposit
    ask one-of professionalBanks[
      set money money + [deposit] of myself]
  ]
  set-interest-rate
end

to renew-fuel
  ask farm-patches [
    if pcolor = black [
      if random-float 100 < fuel-grow-rate
        [ set pcolor green ]
    ]
  ]
  ask city-patches [
    if pcolor = yellow [
      if random-float 100 < fuel-grow-rate
        [ set pcolor red ]
    ]
  ]
end

to disaster
  if random 100.0 < 0.5 [
    ask patches [
      if pcolor = green [
        set pcolor black]
    ]
  ]
  if random 100.0 < 0.5 [
    ask  patches [
      if pcolor = red [
        set pcolor yellow]
    ]
  ]
end

to update-macro-stats
  ask turtles [
    if sum [pdebt] of turtles + sum [fdebt] of turtles > 0 [
      set reserve-ratio (sum [money] of turtles) / ( sum [pdebt] of turtles + sum [fdebt] of turtles  + sum [money] of turtles)]
  ]
end

to-report average-productivity1
  ifelse count farmers > 0
    [ report mean [ productivity ] of farmers ]
    [ report 0 ]
end

to-report average-productivity2
  ifelse count professionals > 0
    [ report mean [ productivity ] of professionals ]
    [ report 0 ]
end
"""
end
