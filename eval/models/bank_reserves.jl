# ── Bank Reserves model (NetLogo models library) ────────────────────

struct BankReservesModel <: AbstractBenchmarkModel end

model_name(::BankReservesModel) = "Bank Reserves"
n_ticks(::BankReservesModel) = 200
tracked_globals(::BankReservesModel) = ["rich", "poor", "middle-class", "money-total"]
world_dims(::BankReservesModel) = (-8, 8, -8, 8)

function netlogo_code(::BankReservesModel)
"""
globals [randomSeed people reserves
         bank-loans bank-reserves bank-deposits bank-to-loan
         x-max y-max
         rich poor middle-class rich-threshold money-total]

turtles-own [
  savings
  loans
  wallet
  temp-loan
  wealth
  customer
]

to setup
  clear-all
  resize-world (- 8) 8 (- 8) 8
  set people 57
  set reserves 52.0
  set rich-threshold 10
  initialize-variables
  ask patches [set pcolor black]
  set-default-shape turtles "person"
  crt people [setup-turtles]
  setup-bank
  set x-max 300
  set y-max 2 * money-total
  update-globals
  reset-ticks
end

to setup-turtles
  set color blue
  setxy random-xcor random-ycor
  set wallet (random rich-threshold) + 1
  set savings 0
  set loans 0
  set wealth 0
  set customer -1
end

to setup-bank
  set bank-loans 0
  set bank-reserves 0
  set bank-deposits 0
  set bank-to-loan 0
end

to initialize-variables
  set rich 0
  set middle-class 0
  set poor 0
  set rich-threshold 10
end

to get-shape
  if (savings > 10) [set color green]
  if (loans > 10) [set color red]
  set wealth (savings - loans)
end

to go
  set rich (count turtles with [savings > rich-threshold])
  set poor (count turtles with [loans > 10])
  set middle-class (count turtles - (rich + poor))
  ask turtles [
    ifelse ticks mod 3 = 0 [
      do-business
    ] [
      ifelse ticks mod 3 = 1 [
        balance-books
        get-shape
      ] [
        bank-balance-sheet
      ]
    ]
  ]
  update-globals
  tick
end

to update-globals
  set money-total sum [wallet + savings] of turtles
end

to do-business
  rt random-float 360
  fd 1
  if ((savings > 0) or (wallet > 0) or (bank-to-loan > 0)) [
    set customer one-of other turtles-here
    if customer != nobody [
      if (random 2) = 0 [
        ifelse (random 2) = 0 [
          ask customer [set wallet wallet + 5]
          set wallet (wallet - 5)
        ] [
          ask customer [set wallet wallet + 2]
          set wallet (wallet - 2)
        ]
      ]
    ]
  ]
end

to balance-books
  ifelse (wallet < 0) [
    ifelse (savings >= (- wallet)) [
      withdraw-from-savings (- wallet)
    ] [
      if (savings > 0) [
        withdraw-from-savings savings
      ]
      set temp-loan bank-to-loan
      ifelse (temp-loan >= (- wallet)) [
        take-out-loan (- wallet)
      ] [
        take-out-loan temp-loan
      ]
    ]
  ] [
    deposit-to-savings wallet
  ]
  if (loans > 0 and savings > 0) [
    ifelse (savings >= loans) [
      withdraw-from-savings loans
      repay-a-loan loans
    ] [
      withdraw-from-savings savings
      repay-a-loan wallet
    ]
  ]
end

to bank-balance-sheet
  set bank-deposits sum [savings] of turtles
  set bank-loans sum [loans] of turtles
  set bank-reserves (reserves / 100) * bank-deposits
  set bank-to-loan bank-deposits - (bank-reserves + bank-loans)
end

to deposit-to-savings [amount]
  set wallet wallet - amount
  set savings savings + amount
end

to withdraw-from-savings [amount]
  set wallet (wallet + amount)
  set savings (savings - amount)
end

to repay-a-loan [amount]
  set loans (loans - amount)
  set wallet (wallet - amount)
  set bank-to-loan (bank-to-loan + amount)
end

to take-out-loan [amount]
  set loans (loans + amount)
  set wallet (wallet + amount)
  set bank-to-loan (bank-to-loan - amount)
end
"""
end
