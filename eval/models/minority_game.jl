# ── Minority Game model (NetLogo models library) ─────────────────────

struct MinorityGameModel <: AbstractBenchmarkModel end

model_name(::MinorityGameModel) = "Minority Game"
n_ticks(::MinorityGameModel) = 200
tracked_globals(::MinorityGameModel) = ["avg-score", "stdev-score", "num-picking-zero"]
world_dims(::MinorityGameModel) = (-17, 17, -17, 17)

function netlogo_code(::MinorityGameModel)
"""
globals [
  randomSeed
  number
  memory
  strategies-per-agent
  history
  minority
  avg-score
  stdev-score
  num-picking-zero
]

turtles-own [
  score
  choice
  strategies
  current-strategy
  strategies-scores
]

to setup
  clear-all
  resize-world (- 17) 17 (- 17) 17
  set number 501
  set memory 6
  set strategies-per-agent 5
  initialize-system
  initialize-turtles
  update-system
  reset-ticks
end

to initialize-system
  set history random (2 ^ memory)
  set avg-score 0
  set stdev-score 0
end

to initialize-turtles
  crt number
    [ setxy 0 (world-height * who / number)
      set heading 90
      assign-strategies
      set current-strategy random strategies-per-agent
      set choice item history (item current-strategy strategies)
      set color green
      set score 0
      set strategies-scores n-values strategies-per-agent [0] ]
end

to assign-strategies
  set strategies []
  while [ length remove-duplicates strategies < strategies-per-agent ]
    [ set strategies n-values strategies-per-agent [create-strategy] ]
end

to-report create-strategy
  report n-values (2 ^ memory) [random 2]
end

to go
  ask turtles [ update-scores-and-strategy ]
  set history decimal (lput minority but-first full-history)
  ask turtles [ update-choice-and-color ]
  tick
  update-system
  move-turtles
end

to move-turtles
  if avg-score > 0 [
    ask turtles [ fd score / avg-score ]
  ]
end

to update-system
  set num-picking-zero count turtles with [choice = 0]
  ifelse (num-picking-zero <= (number - 1) / 2)
    [ set minority 0 ]
    [ set minority 1 ]
  set avg-score mean [score] of turtles
  set stdev-score standard-deviation [score] of turtles
end

to update-scores-and-strategy
  increment-scores
  let max-score max strategies-scores
  let max-strategies []
  let counter 0
  foreach strategies-scores
    [ if (? = max-score)
        [ set max-strategies lput counter max-strategies ]
      set counter counter + 1 ]
  set current-strategy one-of max-strategies
  if (choice = minority)
    [ set score score + 1 ]
end

to increment-scores
  set strategies-scores
      (map [ifelse-value (item history ?1 = minority)
              [?2 + 1] [?2]]
           strategies strategies-scores)
end

to update-choice-and-color
  set choice (item history (item current-strategy strategies))
  ifelse (choice = 0)
    [ set color red ]
    [ set color blue ]
end

to-report full-history
  report sentence n-values (memory - length binary history) [0] (binary history)
end

to-report binary [decimal-num]
  let binary-num []
  loop
    [ set binary-num fput (decimal-num mod 2) binary-num
      set decimal-num int (decimal-num / 2)
      if (decimal-num = 0)
        [ report binary-num ] ]
end

to-report decimal [binary-num]
  report reduce [(2 * ?1) + ?2] binary-num
end
"""
end
