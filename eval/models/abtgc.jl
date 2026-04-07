# ── ABTgc model (netlogomas) ─────────────────────────────────────────

struct ABTgcModel <: AbstractBenchmarkModel end

model_name(::ABTgcModel) = "ABTgc"
n_ticks(::ABTgcModel) = 100
tracked_globals(::ABTgcModel) = ["bad-links", "unhandled-messages"]
world_dims(::ABTgcModel) = (-16, 16, -16, 16)
topology(::ABTgcModel) = (false, false)

function netlogo_code(::ABTgcModel)
"""
extensions [table]

globals [
  all-colors
  node-count
  edges-to-nodes
  possible-colors
]

turtles-own [
  message-queue
  value
  naybors
  local-view
  no-goods
]

to setup
  clear-all
  set node-count 14
  set edges-to-nodes 3.19
  set possible-colors 6
  set all-colors filter [x -> x < possible-colors] [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15]
  set-default-shape turtles "circle"
  create-turtles node-count
  ask turtles [setxy random-xcor random-ycor]

  ask turtles [get-random]
  let lonelies sort turtles
  repeat (edges-to-nodes * node-count) [
    ifelse empty? lonelies
    [
      let needing-friends turtles with [((count my-links) < (node-count - 1)) and (not empty? link-options)]
      ifelse (count needing-friends > 0)
      [
        let nf one-of needing-friends
        ask nf [link-up]
      ]
      [
        show "CANNOT FORM ANYMORE LINKS"
      ]
    ]
    [
      let lonely one-of lonelies
      ask lonely [link-up]
      set lonelies filter [x -> not (x = lonely or [link-neighbor? lonely] of x)] lonelies
    ]
  ]
  setup-abt
  reset-ticks
end

to layout
  layout-spring turtles links 1 12 3
end

to setup-abt
  ask turtles [
    get-random
    set message-queue []
    set local-view table:make
    set naybors sort link-neighbors
    set no-goods []
    foreach naybors [ n ->
      let w ([who] of n)
      set no-goods sentence no-goods map [c -> normalize-nogood list (list who c) (list w c)] all-colors
    ]
  ]
  ask turtles [send-out-new-value]
end

to go
  let important-turtles turtles with [not empty? message-queue]
  ifelse (count important-turtles > 0) [
    ask important-turtles [handle-message]
  ][
    ifelse (bad-links = 0)[
      show "SOLUTION FOUND"
    ][
      show "NO MORE MESSAGES"
    ]
    stop
  ]
end


;; ==Turtle Procedures==


;; For setup

to-report link-options
  report sort turtles with [(not link-neighbor? myself) and (not (([value] of myself) = ([value] of self)))]
end

to link-up
  let li link-options
  create-link-with one-of li
end

to get-random
  set value random possible-colors
  be-honest
end

;; For running

to send-out-new-value
  let my-message list "ok" (list who value)
  foreach naybors [ n ->
    ask n [set message-queue (lput my-message message-queue)]
  ]
end

to handle-message
  if not empty? message-queue [
    let message first message-queue
    set message-queue but-first message-queue
    let message-type first message
    let message-value last message
    ifelse message-type = "ok" [
      let someone first message-value
      let val last message-value
      handle-ok someone val
    ][
      ifelse message-type = "nogood" [
        handle-nogood message-value
      ][
        handle-add-neighbor message-value
      ]
    ]
  ]
end

to handle-ok [someone val]
  table:put local-view someone val
  check-local-view
end

to handle-nogood [nogood]
  if(not member? nogood no-goods) [
    set no-goods fput nogood no-goods
    foreach (filter [x -> not member? (turtle first x) naybors] nogood) [ x ->
      let new-naybor turtle (first x)
      set naybors fput new-naybor naybors
      table:put local-view (first x) (last x)
      let message (list "new-neighbor" who)
      ask new-naybor [
        set message-queue lput message message-queue
      ]
    ]
    check-local-view
  ]
end

to-report can-i-be? [val]
  table:put local-view who val
  foreach no-goods [ ng ->
    if (violates? local-view ng) [
      table:remove local-view who
      report false
    ]
  ]
  table:remove local-view who
  report true
end

to-report violates? [assignments constraint]
  foreach constraint [ x ->
    if not (table:has-key? assignments (first x) and (table:get assignments first x) = (last x)) [report false]
  ]
  report true
end

to handle-add-neighbor [someone]
  if (not (member? (turtle someone) naybors)) [
    set naybors fput turtle someone naybors
    let message (list "ok" (list who value))
    ask turtle someone [
      set message-queue lput message message-queue
    ]
  ]
end

to check-local-view
  if not can-i-be? value [
    let try-these filter [x -> not (x = value)] all-colors
    let can-be-something-else false
    while [not empty? try-these] [
      let try-this first try-these
      set try-these but-first try-these

      if can-i-be? try-this [
        set try-these []
        set value try-this
        be-honest
        set can-be-something-else true
        send-out-new-value
      ]
    ]
    if not can-be-something-else [backtrack]
  ]
end

to backtrack
  let no-good normalize-nogood find-new-nogood
  ifelse(not member? no-good no-goods) [
    if ([] = no-good) [
      show "EMPTY NO-GOOD FOUND - NO SOLUTION"
      stop
    ]
    set no-goods fput no-good no-goods
    ask (turtle first first no-good) [
      set message-queue lput (list "nogood" no-good) message-queue
    ]
  ] [ show "SHIT OLD NOGOOD"]
end

to-report find-new-nogood
  report find-new-nogood-hyper
end

to-report find-new-nogood-hyper
  let my-who who
  report remove-duplicates filter [x -> not ((first x) = my-who)] (reduce [[a b] -> sentence a b] no-goods)
end

to-report find-new-nogood-simple
  report table:to-list local-view
end

to be-honest
  set color item value base-colors
end

to-report normalize-nogood [nogood]
  report sort-by [[a b] -> (first a) < (first b)] nogood
end


;; Global Reports

to-report bad-links
  report count links with [is-bad-link]
end

to-report is-bad-link
  let two-vals [value] of both-ends
  report first two-vals = last two-vals
end

to-report unhandled-messages
  report sum [length message-queue] of turtles
end

to-report average-nogoods
  report (sum [length no-goods] of turtles) / (count turtles)
end

to-report average-local-view
  report (sum [(length naybors) / ((count turtles) - 1)] of turtles) / (count turtles)
end

to-report local-view-knowledge
  report (sum [(table:length local-view) / (length naybors)] of turtles) / (count turtles)
end
"""
end
