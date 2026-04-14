# ── Participatory Disinformation ─────────────────────────────────────
# Source: modelingcommons #6768
# Extensions: nw (network generators) + bitstring (rumor bitstring tracking)
# Rumor spreading on social networks with elite/social influence and bitstring ops.

struct ParticipatoryDisinfoNWBitModel <: AbstractBenchmarkModel end

model_name(::ParticipatoryDisinfoNWBitModel) = "Participatory Disinfo NW+Bitstring"
n_ticks(::ParticipatoryDisinfoNWBitModel) = 200
tracked_globals(::ParticipatoryDisinfoNWBitModel) = ["times-heard-from-elites", "times-heard-from-social", "times-created-rumor", "times-traded-up"]

function netlogo_code(::ParticipatoryDisinfoNWBitModel)
"""
extensions [ nw bitstring ]

globals [
  times-heard-from-elites
  times-heard-from-social
  times-traded-up
  times-created-rumor
  num-people
  frac-influencers
  network-type
  network-density
  min-size
  neighborhood-size
  max-rumors
  elite-influence
  social-influence
  trade-up-influence
  rumor-generation
  initial-green-pct
  variant
  ticks-to-end
  model-rate-1-nth
  heard-rumors-to-generate
  influencers-generate-rumors
  only-one-generates
  only-one-forgets
  dissipation-rate
]

patches-own [
  vote
  total
]

turtles-own [
  rumors-heard?
]

breed [ regulars regular ]
breed [ influencers influencer ]
breed [ elites elite ]

to setup
  clear-all

  set num-people 100
  set frac-influencers 0.1
  set network-type "preferential"
  set network-density 0.1
  set min-size 1
  set neighborhood-size 4
  set max-rumors 10
  set elite-influence 0.6
  set social-influence 0.1
  set trade-up-influence 0.1
  set rumor-generation 0.05
  set initial-green-pct 50
  set variant "irregular"
  set ticks-to-end 3000
  set model-rate-1-nth 1
  set heard-rumors-to-generate true
  set influencers-generate-rumors false
  set only-one-generates true
  set only-one-forgets false
  set dissipation-rate 0.1

  set-default-shape regulars "person"
  set-default-shape influencers "star"
  set-default-shape elites "default"

  setup-network

  ask n-of ( frac-influencers * num-people ) turtles [
    set breed influencers
    set size 2
  ]

  ask turtles [
    if breed != influencers [
      set breed regulars
    ]
  ]

  ask turtles [
    facexy xcor min-pycor
    fd 4
  ]

  create-elites 1 [
    setxy 0 max-pycor - 1
    set size 3
    initialize-elite
  ]

  if variant = "uniform" [ setup-elite-uniform ]
  if variant = "block" [ setup-elite-block ]
  if variant = "irregular" [ setup-elite-irregular ]

  reset-ticks
end

to setup-network
  if network-type = "preferential" [
    nw:generate-preferential-attachment turtles links num-people min-size [
      setxy random-xcor random-ycor
      initialize-agent
    ]
    let factor sqrt count turtles
    repeat 300 [
      layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    ]
  ]

  if network-type = "random" [
    nw:generate-random turtles links num-people network-density [
      setxy random-xcor random-ycor
      initialize-agent
    ]
    repeat 30 [ layout-spring turtles links 0.3 (world-width / 2) 1 ]
  ]

  if network-type = "small-world" [
    nw:generate-watts-strogatz turtles links num-people neighborhood-size 0.1 [
      setxy random-xcor random-ycor
      initialize-agent
    ]
    repeat 300 [
      layout-spring turtles links 0.3 (world-width / 3) 3
    ]
  ]
end

to initialize-agent
  set color white
  set rumors-heard? bitstring:make max-rumors false
end

to initialize-elite
  let set-rumor random (max-rumors)
  set rumors-heard? bitstring:make max-rumors false
  set rumors-heard? bitstring:set rumors-heard? set-rumor true
  set color scale-color red bitstring:count1 rumors-heard? max-rumors 0
end

to reinitialize
  ask turtles [ initialize-agent ]
  ask elites [ initialize-elite ]
  set times-heard-from-elites 0
  set times-heard-from-social 0
  set times-traded-up 0
  set times-created-rumor 0
  reset-ticks
end

to setup-elite-uniform
  ask patches [
    set vote 1
    recolor-patch
  ]
end

to setup-elite-block
  let green-y% (max-pycor - (world-height * initial-green-pct / 100))
  ask patches [
    ifelse pycor > green-y%
      [ set vote 0 ]
      [ set vote 1 ]
    recolor-patch
  ]
end

to setup-elite-irregular
  ask patches [
    ifelse random 100 < initial-green-pct
      [ set vote 0 ]
      [ set vote 1 ]
    recolor-patch
  ]

  let stop-count 100
  let counter 0
  loop [
    let any-votes-changed? false
    ask patches [
      set total (sum [ vote ] of neighbors)
    ]
    ask patches [
      let previous-vote vote
      if total < 3 [ set vote 0 ]
      if total = 3 [ set vote 0 ]
      if total = 4 [ set vote (1 - vote) ]
      if total = 5 [ set vote 1 ]
      if total > 5 [ set vote 1 ]
      if vote != previous-vote [ set any-votes-changed? true ]
      recolor-patch
    ]
    set counter counter + 1
    if not any-votes-changed? or counter = stop-count [ stop ]
  ]
end

to recolor-patch
  ifelse vote = 0
    [ set pcolor 58 ]
    [ set pcolor 28 ]
end

to go
  if ( ticks >= ticks-to-end or not any? turtles with [ bitstring:any0? rumors-heard? ] ) [
    stop
  ]

  if ( ticks mod model-rate-1-nth = 0 ) [
    ask turtles with [ not (breed = elites) ] [
      adopt-from-elites
      adopt-from-network

      if (not only-one-generates or random num-people = who) [
        if (breed != influencers or influencers-generate-rumors) [
          generate-rumors
        ]
      ]

      if (not only-one-forgets or random num-people = who) [
        forget-rumors
      ]
    ]

    trade-up-rumors
  ]

  tick
end

to adopt-from-elites
  let elite-rumors [rumors-heard?] of one-of elites
  let elite-adoption elite-influence

  if variant = "irregular" or variant = "block" [
    let near-adopt-pct (count neighbors with [ pcolor = 28 ] / 8)
    let own-adopt 0
    ifelse pcolor = 28
      [ set own-adopt 1 ]
      [ set own-adopt 0 ]
    set elite-adoption ( elite-influence * 0.5 * (near-adopt-pct + own-adopt) )
  ]

  if (random-float 1.0 < elite-adoption) [
    set rumors-heard? adopt-rumor rumors-heard? elite-rumors
    set times-heard-from-elites times-heard-from-elites + 1
    set color scale-color red bitstring:count1 rumors-heard? max-rumors 0
  ]
end

to adopt-from-network
  let neighbors-adopted link-neighbors with [ any-rumors ]
  let total-neighbors link-neighbors

  let rumor-source one-of neighbors-adopted

  if count total-neighbors > 0 and random-float 1.0 < ( social-influence * count neighbors-adopted / count total-neighbors ) [
    set rumors-heard? adopt-rumor rumors-heard? [rumors-heard?] of rumor-source
    set times-heard-from-social times-heard-from-social + 1
    set color scale-color red bitstring:count1 rumors-heard? max-rumors 0
  ]
end

to generate-rumors
  if (not heard-rumors-to-generate or not bitstring:all0? rumors-heard?) [
    if (random-float 1.0 < rumor-generation) [
      let new-rumors create-rumor rumors-heard?
      if ( not (rumors-heard? bitstring:contains? new-rumors)) [
        set rumors-heard? new-rumors
        set times-created-rumor times-created-rumor + 1
      ]
    ]
  ]
end

to forget-rumors
  if ( random-float 1.0 < dissipation-rate ) [
    set rumors-heard? forget-rumor rumors-heard?
  ]
end

to trade-up-rumors
  if (count influencers > 0 and random-float 1.0 < trade-up-influence) [
    let one-influencer one-of influencers
    let influencer-rumors [rumors-heard?] of one-influencer
    ask elites [
      let new-rumors adopt-rumor rumors-heard? influencer-rumors
      if ( not ( rumors-heard? bitstring:contains? new-rumors)) [
        set rumors-heard? new-rumors
        set color scale-color red bitstring:count1 rumors-heard? max-rumors 0
        set times-traded-up times-traded-up + 1
      ]
    ]
  ]
end

to-report adopt-rumor [my-rumors other-rumors]
  let mask my-rumors bitstring:or other-rumors
  let novel-rumors my-rumors bitstring:xor mask

  ifelse (bitstring:count1 novel-rumors > 0) [
    let pos 0
    while [ not bitstring:first? novel-rumors ] [
      set novel-rumors bitstring:but-first novel-rumors
      set pos pos + 1
    ]
    report bitstring:set my-rumors pos true
  ]
  [
    report my-rumors
  ]
end

to-report create-rumor [my-rumors]
  let pos random max-rumors
  report bitstring:set my-rumors pos true
end

to-report forget-rumor [my-rumors]
  let pos random max-rumors
  report bitstring:set my-rumors pos false
end

to-report any-rumors
  report bitstring:count1 rumors-heard? > 0
end

to-report frac-rumors
  report bitstring:count1 rumors-heard? / max-rumors
end
"""
end
