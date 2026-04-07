# ── Rational Evolving PD model (CSS600 ClassModels) ──────────────────

struct RationalEvolvingPDModel <: AbstractBenchmarkModel end

model_name(::RationalEvolvingPDModel) = "Rational Evolving PD"
n_ticks(::RationalEvolvingPDModel) = 100
tracked_globals(::RationalEvolvingPDModel) = ["count patches with [alive?]", "count neurons"]
world_dims(::RationalEvolvingPDModel) = (0, 50, 0, 50)

function netlogo_code(::RationalEvolvingPDModel)
"""
extensions [table]

globals[
  num-of-initial-people
  energy-cost-per-neuron
  people-birth-energy
  energy-cost-per-person
  people-birth-threshold
  relative-genetic-variation
  max-brain-size
  resource-competition
  best-competition
  forgetfulness
  tell-story?
  emo-DD emo-DC emo-CD emo-CC
  people-death-threshold
  neuron-death-threshold
  neuron-recombination-threshold
  energy-matrix
  protagonist
]

breed [neurons neuron]

patches-own [
  alive?
  energy
  current-event
  my-move
  partner
  match-event
  decision-buffer
  counter
  played?
  score
  adjusted-score
  reward-punishment-multiplier
  emotion-matrix
]

neurons-own [
  imprint-utility
  events-pattern
  parent-neurons
  signal?
  buffer
]

to setup
  clear-all
  set num-of-initial-people 2000
  set energy-cost-per-neuron 0
  set people-birth-energy 12
  set energy-cost-per-person 0.6
  set people-birth-threshold 36
  set relative-genetic-variation 50
  set max-brain-size 4
  set resource-competition 0
  set best-competition 2
  set forgetfulness 0.25
  set tell-story? false
  set emo-DD 1
  set emo-DC 5
  set emo-CD 0
  set emo-CC 3
  set-default-shape neurons "circle"
  set people-death-threshold 0
  set neuron-death-threshold 0.001
  set energy-matrix [[1 5] [0 3]]
  ask patches [
    set alive? false
  ]
  ask n-of num-of-initial-people patches [
    initialize-people
    initialize-random-variables
    mutate-random-variables
    initialize-neurons
  ]
  ifelse tell-story? [
    new-protagonist
  ][
    set protagonist nobody
  ]
  reset-ticks
end

to go
  if not any? patches with [alive?] [stop]
  ask patches with [alive?] [
    set played? false
    find-partner
  ]
  ask patches with [alive? and partner != nobody] [
    play-round
  ]
  ask patches with [alive?] [
    receive-expend-energy
    reproduce
  ]
  death-race
  tick
end

to new-protagonist
  set protagonist one-of patches with [alive? = true]
  tell protagonist "Once upon a time..."
  tell protagonist (word "I was born with this emotion-matrix, " [emotion-matrix] of protagonist ",")
  tell protagonist (word "and this reward-punishment-multiplier, " [reward-punishment-multiplier] of protagonist ",")
  tell protagonist (word "and this forgetfulness multiplier, " [forgetfulness] of protagonist)
end

to find-partner
  if partner != nobody and counter = 0[
    tell self (word "I finished my game with " partner)
    ask partner [reset-living-player]
    reset-living-player
  ]
  if partner = nobody [
    set partner one-of neighbors with [partner = nobody and alive? = true]
    if partner != nobody [
      tell self (word "I started a new game with " partner)
      ask partner[set partner myself]
    ]
  ]
end

to play-round
  if not played? [
    make-decision
    ask partner [make-decision]
    set current-event list (my-move) ([my-move] of partner)
    tell self (word "I felt " (get-element current-event emotion-matrix) " when " current-event " happened")
    color-neurons
    set counter counter - 1
  ]
end

to make-decision
  fire-neurons
  let defect (table:get decision-buffer [0 0]) + (table:get decision-buffer [0 1])
  let cooperate (table:get decision-buffer [1 0]) + (table:get decision-buffer [1 1])
  let intensity cooperate - defect
  tell self (word "I imagined feeling this way, " intensity ", before I made a decision")
  ifelse intensity > 0 [
    set my-move 1
    tell self "I chose to cooperate"
  ][
    set my-move 0
    tell self "I chose to defect"
  ]
  set played? true
  table:put decision-buffer [0 0] 0
  table:put decision-buffer [0 1] 0
  table:put decision-buffer [1 0] 0
  table:put decision-buffer [1 1] 0
end

to fire-neurons
  if not empty? current-event [
    let fired-gate table:get match-event current-event
    cascade fired-gate
  ]

  ask neurons-here [
    let key item 0 events-pattern
    tell myself (word self " with " key " matching event starts with buffer " (table:get decision-buffer key))
    let imprint item 0 imprint-utility
    let emotion get-element key emotion-matrix
    let new-output (imprint * emotion)
    let old-value table:get decision-buffer key
    table:put decision-buffer key (old-value + new-output)
    tell myself (word self " fired to the " key " buffer, which is now " (table:get decision-buffer key))

    let match-update 0
    if signal? [
      set match-update (abs emotion) / (imprint + 1)
      set signal? false
    ]

    let forget-update imprint * forgetfulness

    let new-imprint imprint + match-update - forget-update
    ifelse new-imprint < neuron-death-threshold and length imprint-utility = 1 [
      set imprint-utility (list (neuron-death-threshold))
    ][
      set imprint-utility (replace-item 0 imprint-utility new-imprint)
    ]
    tell myself (word self " with " events-pattern " event pattern has " imprint-utility " imprint-utility")
  ]
end

to cascade [ fired-neuron ]
  ask fired-neuron [
    set signal? true
    if parent-neurons != nobody [
      foreach parent-neurons [ p1 ->
        cascade p1
      ]
    ]
  ]
end

to initialize-random-variables
  set emotion-matrix (list (list emo-DD emo-DC) (list emo-CD emo-CC))
  set reward-punishment-multiplier 0.1
end

to initialize-people
  set alive? true
  set energy people-birth-energy
  set score -1
  reset-living-player
end

to initialize-neurons
  sprout-neurons 4 [
    set color magenta
    set imprint-utility [1]
    set parent-neurons nobody
    set signal? false
    set buffer []
  ]

  let gates sort neurons-here

  ask item 0 gates [set events-pattern [[0 0]] ]
  ask item 1 gates [set events-pattern [[0 1]] ]
  ask item 2 gates [set events-pattern [[1 0]] ]
  ask item 3 gates [set events-pattern [[1 1]] ]

  set match-event table:make
  table:put match-event [0 0] item 0 gates
  table:put match-event [0 1] item 1 gates
  table:put match-event [1 0] item 2 gates
  table:put match-event [1 1] item 3 gates

  set decision-buffer table:make
  table:put decision-buffer [0 0] 0
  table:put decision-buffer [0 1] 0
  table:put decision-buffer [1 0] 0
  table:put decision-buffer [1 1] 0
end

to receive-expend-energy
  if not empty? current-event [
    set score get-element current-event energy-matrix
    set adjusted-score score * ( 1 - resource-competition / 100 * (count neighbors with [alive?]) / 8 )
    set energy energy + adjusted-score
    tell self (word "I got " score " units of energy, and now have " energy " units of energy")
  ]

  let loss energy-cost-per-person + energy-cost-per-neuron * (count neurons-here)
  set energy energy - loss
  tell self (word "I lost " loss " units of energy, and now have " energy " units of energy")

  if energy < people-death-threshold [
    kill-self
  ]
end

to death-race
  let race-order sort-by [[a b] -> [energy] of a < [energy] of b] patches with [alive?]
  let n count patches with [alive?]
  let threshold n * best-competition / 100
  let diers sublist race-order 0 threshold
  foreach diers [ p1 -> ask p1 [kill-self] ]
end

to kill-self
   if partner != nobody [
      ask partner [
        reset-living-player
      ]
    ]
    set alive? false
    set partner  nobody
    set match-event []
    set current-event []
    set decision-buffer []
    set emotion-matrix []
    ask neurons-here [die]
    tell self "I died"
end

to reset-living-player
  set partner nobody
  set counter 20
  set current-event []
  set my-move []
  ask neurons-here [set buffer []]
end

to reproduce
  if energy > people-birth-threshold and energy > people-birth-energy [
    let embryo one-of neighbors with [alive? = false]
    if embryo != nobody [
      set energy energy - people-birth-energy
      tell self (word "I gave birth. Lost " people-birth-energy " units of energy, and now have  " energy " units of energy")
      ask embryo [
        initialize-people
        set emotion-matrix [emotion-matrix] of myself
        set reward-punishment-multiplier [reward-punishment-multiplier] of myself
        set forgetfulness [forgetfulness] of myself
        mutate-random-variables
        initialize-neurons
        tell self (word "I was reborn with this emotion-matrix, " emotion-matrix ",")
        tell self (word "this reward-punishment-multiplier, " reward-punishment-multiplier ",")
        tell self (word "and this forgetfulness multiplier, " forgetfulness)
      ]
      tell embryo (word "My parent had this emotion-matrix, " emotion-matrix ",")
      tell embryo (word "this reward-punishment-multiplier, "  reward-punishment-multiplier ",")
      tell embryo (word "and this forgetfulness multiplier, " forgetfulness)
    ]
  ]
end

to mutate-random-variables
  let r0c0 get-element [0 0] emotion-matrix
  let r0c1 get-element [0 1] emotion-matrix
  let r1c0 get-element [1 0] emotion-matrix
  let r1c1 get-element [1 1] emotion-matrix
  let ave mean (list r0c0 r0c1 r1c0 r1c1)
  set r0c0 r0c0 + random-normal 0 (ave * relative-genetic-variation / 100)
  set r0c1 r0c1 + random-normal 0 (ave * relative-genetic-variation / 100)
  set r1c0 r1c0 + random-normal 0 (ave * relative-genetic-variation / 100)
  set r1c1 r1c1 + random-normal 0 (ave * relative-genetic-variation / 100)
  set emotion-matrix list (list r0c0 r0c1) (list r1c0 r1c1)
end

to color-neurons
  ask neurons-here [
    set score get-element current-event energy-matrix
    if score = 5 [
      set color violet
    ]
    if score = 3 [
      set color blue
    ]
    if score = 1 [
      set color sky
    ]
    if score = 0 [
      set color cyan
    ]
  ]
end

to tell [me str]
  if tell-story? = true [
    if me = protagonist [
      type protagonist type " says " type str type " on tick " print ticks
    ]
  ]
end

to-report get-element [event mat]
  let r item 0 event
  let c item 1 event
  report item c (item r mat)
end
"""
end
