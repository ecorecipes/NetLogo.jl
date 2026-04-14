# ── Baby-Sitting Co-op ────────────────────────────────────────────
# Source: modelingcommons #4235
# Array + Table extensions: table:make/get/put/has-key?, array:from-list/set/to-list
# Economic model of baby-sitting co-op with scrip-based exchange.

struct BabySittingModel <: AbstractBenchmarkModel end

model_name(::BabySittingModel) = "Baby Sitting Coop"
n_ticks(::BabySittingModel) = 300
tracked_globals(::BabySittingModel) = ["total-scrip", "going-out-count", "sitting-count"]
world_dims(::BabySittingModel) = (-16, 16, -16, 16)

function netlogo_code(::BabySittingModel)
"""
extensions [ array table ]

turtles-own [
  scrip
  scrip-needed
  want-sitter?
  want-to-go-out?
  enough-scrip?
  going-out?
  want-to-sit?
  sitting?
]

globals [
  aggregated-hours-out cycle-pos frustrated-want-sitter frustrated-want-to-sit going-out-count
  max-gini max-scrip my-ticks no-sitter-count no-sitting-jobs-count not-enough-scrip-count quiet-evening-count
  sitting-count sitting-as-1st-choice-count sitting-as-2nd-choice-count stop-run? total-hours-out
  total-scrip want-sitter-count want-to-go-out-count want-to-sit-count
  co-op-size initial-scrip mean-hours-out want-to-go-out-probability want-to-sit-probability
  monthly-dues desired-times-out-reserve willing-to-sit-prob years cycle-amplitude
  multiple-sitees? clear-sitter-market? auto-adjust hours-out-distribution
]

to setup
  clear-all
  set co-op-size 100
  set initial-scrip 25
  set mean-hours-out 4
  set want-to-go-out-probability 0.5
  set want-to-sit-probability 0.5
  set monthly-dues 0.6
  set desired-times-out-reserve 0
  set willing-to-sit-prob 0
  set years 10
  set cycle-amplitude 0
  set multiple-sitees? true
  set clear-sitter-market? false
  set auto-adjust false
  set hours-out-distribution "uniform"
  create-co-op
  set aggregated-hours-out table:make
  set total-hours-out 0
  set max-scrip 0
  set frustrated-want-sitter no-turtles
  set frustrated-want-to-sit no-turtles
  set stop-run? false
  reset-ticks
end

to go
  reset-turtles
  set my-ticks ticks
  set cycle-pos (sin ( my-ticks mod 360 )) * cycle-amplitude
  plan-evening
  match-sitees-and-sitters
  if clear-sitter-market? [ clear-sitter-market ]
  check-consistency
  set total-scrip sum [scrip] of turtles
  let max-scrip-now max [scrip] of turtles
  set max-scrip ceiling maxi max-scrip max-scrip-now
  let gini ifelse-value (total-scrip = 0) [0] [(max-scrip-now / total-scrip) - (1 / co-op-size)]
  set max-gini maxi max-gini gini
  if auto-adjust [ set-monthly-dues ]
  if ticks mod 12 = 0 [ ask turtles [ set scrip scrip - monthly-dues ] ]
  if ticks >= 365 * years or stop-run? [stop]
end

to check-consistency
  set frustrated-want-sitter turtles with [ want-sitter? and not going-out? and not sitting? ]
  set frustrated-want-to-sit turtles with [ want-to-sit? and not sitting? ]
  if count frustrated-want-sitter > 0 and count frustrated-want-to-sit > 0 [
    set stop-run? true
  ]
  set want-sitter-count count turtles with [want-sitter?]
  set want-to-sit-count count turtles with [want-to-sit?]
  set quiet-evening-count count turtles with [not want-sitter? and not want-to-sit?]
  if want-sitter-count + want-to-sit-count + quiet-evening-count != co-op-size [
    set stop-run? true
  ]
  set want-to-go-out-count count turtles with [want-to-go-out?]
  set not-enough-scrip-count count turtles with [want-to-go-out? and not enough-scrip?]
  if want-sitter-count + not-enough-scrip-count != want-to-go-out-count [
    set stop-run? true
  ]
  set going-out-count count turtles with [ going-out? ]
  set no-sitter-count count frustrated-want-sitter
  set sitting-as-2nd-choice-count count turtles with [ want-sitter? and sitting? ]
  if going-out-count + no-sitter-count + sitting-as-2nd-choice-count != want-sitter-count [
    set stop-run? true
  ]
  set sitting-as-1st-choice-count count turtles with [ want-to-sit? and sitting? ]
  set no-sitting-jobs-count count frustrated-want-to-sit
  if sitting-as-1st-choice-count + no-sitting-jobs-count != want-to-sit-count [
    set stop-run? true
  ]
  set sitting-count count turtles with [ sitting? ]
  if not multiple-sitees? and going-out-count != sitting-count [
    set stop-run? true
  ]
end

to clear-sitter-market
  let uncleared-turtles turtles with [ want-sitter? and not going-out? ]
  let sitters-set uncleared-turtles with [ random-probability < willing-to-sit-prob ]
  let sittees [ self ] of uncleared-turtles with [ not member? self sitters-set ]
  let sitters [ self ] of sitters-set
  ifelse length sitters > length sittees [
    set sitters n-of length sittees sitters
  ] [
    set sittees n-of length sitters sittees
  ]
  let i 0
  while [i < length sittees] [
    pay-sitter item i sittees item i sitters "clear-sitters1"
    set i i + 1
  ]
  let extra-sitters [ self ] of sitters-set with [ not sitting? ]
  set sittees n-of ((length extra-sitters) / 2) extra-sitters
  let remaining-sitters []
  foreach extra-sitters [[x] -> if not member? x sittees [set remaining-sitters lput x remaining-sitters]]
  set sitters n-of length sittees remaining-sitters
  set i 0
  while [i < length sittees] [
    pay-sitter item i sittees item i sitters "clear-sitters2"
    set i i + 1
  ]
end

to create-co-op
  create-turtles co-op-size [
    set scrip initial-scrip
    set hidden? true
  ]
  reset-turtles
end

to-report get-event-length
  if random-probability > get-want-to-go-out-probability [ report 0 ]
  if hours-out-distribution = "uniform" [ report (random (mean-hours-out + mean-hours-out / 2)) + 1 ]
  if hours-out-distribution = "poisson" [ report (random-poisson (mean-hours-out - 1)) + 1 ]
  if hours-out-distribution = "none"    [ report mean-hours-out ]
end

to-report get-want-to-go-out-probability
  report seasonally-adjusted-prob (mini percent-of-desired-times-out-reserve want-to-go-out-probability) cycle-pos
end

to-report get-want-to-sit-probability
  report seasonally-adjusted-prob (maxi (1 - percent-of-desired-times-out-reserve) want-to-sit-probability) ((-1) * cycle-pos)
end

to increment-table [ tab instance ]
  let current-value ifelse-value table:has-key? tab instance [table:get tab instance] [0]
  table:put tab instance current-value + 1
end

to match-sitees-and-sitters
  let want-sitters [self] of turtles with [ want-sitter? ]
  let available-sitters [self] of turtles with [ want-to-sit? ]
  if length want-sitters < length available-sitters [ set available-sitters n-of length want-sitters available-sitters ]
  if length want-sitters > length available-sitters [
    ifelse multiple-sitees? and length available-sitters > 0 [
      set available-sitters repeat-to available-sitters length want-sitters
    ] [
      set want-sitters n-of length available-sitters want-sitters
    ]
  ]
  let i 0
  while [i < length want-sitters] [
    pay-sitter item i want-sitters item i available-sitters "match-sitees-and-sitters"
    set i i + 1
  ]
end

to-report maxi [a b]
  report max list a b
end

to-report mini [a b]
  report min list a b
end

to pay-sitter [sittee sitter source]
  if [going-out?] of sittee [ set stop-run? true ]
  if [sitting?]   of sittee [ set stop-run? true ]
  if [going-out?] of sitter [ set stop-run? true ]
  if not multiple-sitees? and [sitting?] of sitter [ set stop-run? true ]
  let payment [scrip-needed] of sittee
  ask sittee [
    set scrip scrip - payment
    set going-out? true
  ]
  ask sitter [
    set scrip scrip + payment
    set sitting? true
    set total-hours-out total-hours-out + payment
  ]
end

to-report repeat-to [xs n]
  ifelse length xs < n [ report repeat-to (sentence xs xs) n ] [ report n-of n xs ]
end

to-report percent-of-desired-times-out-reserve
  report ifelse-value (desired-times-out-reserve = 0) [ 1 ]
  [ percent-of-limit scrip mean-hours-out * desired-times-out-reserve ]
end

to-report percent-of-limit [amount limit]
  report mini 1 maxi 0 ( amount / limit )
end

to plan-evening
  ask turtles [
    let hours-out-wanted get-event-length
    if hours-out-wanted > 0 [ increment-table aggregated-hours-out hours-out-wanted ]
    set scrip-needed hours-out-wanted
    if scrip-needed > 0 [
      set want-to-go-out? true
      if scrip >= scrip-needed [ set want-sitter? true set enough-scrip? true ]
    ]
    set want-to-sit? not want-sitter? and random-probability < get-want-to-sit-probability
  ]
end

to-report random-probability
  report (random 100) / 100
end

to reset-turtles
  ask turtles [
    set going-out? false
    set enough-scrip? false
    set sitting? false
    set want-sitter? false
    set want-to-go-out? false
    set want-to-sit? false
  ]
end

to-report seasonally-adjusted-prob [p cycle-p]
  let diff ifelse-value (cycle-p > 0) [1 - p] [
    ifelse-value (cycle-p = 0) [0] [p]]
  report p + diff * cycle-p
end

to set-monthly-dues
  if no-sitting-jobs-count > 10 [set monthly-dues -0.3]
  if no-sitting-jobs-count < 5 [set monthly-dues 0.6]
end

to-report table-as-pct-list [tab]
  let keys table:keys tab
  if length keys = 0 [ report [ ] ]
  let min-key min keys
  let arr array:from-list n-values (1 + max keys - min-key) [0]
  foreach keys [[k] -> array:set arr (k - min-key) table:get tab k]
  let list-arr array:to-list arr
  let sum-of-elements sum list-arr
  report map [[x] -> round ( 100 * x / sum-of-elements ) ] list-arr
end
"""
end
