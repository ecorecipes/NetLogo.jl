# ── Dating model (CSS600 ClassModels) ───────────────────────────────────

struct DatingModel <: AbstractBenchmarkModel end

model_name(::DatingModel) = "Dating"
n_ticks(::DatingModel) = 500
tracked_globals(::DatingModel) = ["n-paired"]
world_dims(::DatingModel) = (-16, 16, -16, 16)

function netlogo_code(::DatingModel)
"""
globals [randomSeed population average-pickiness average-timeline average-commitment-length percentage-pop-considers-single percentage-pop-has-memory action-reach information-reach n-paired]

breed [blue-agents blue-agent]
breed [green-agents green-agent]

turtles-own [
  quality
  pickiness
  timeline
  timeline-count
  has-memory
  this-turn-market-assessment
  market-assessment-list
  all-turns-market-assessment
  consider-who
  looking?
  partner
  relationship-duration
  this-turn-candidate
  this-turn-candidate-score
  number-candidates-info
  number-candidates-action
  current-search-time
  current-partner-quality
  number-partners-ever
  number-considered-ever
  number-considered-before-first-match
]

to setup
  clear-all
  set population 88
  set average-pickiness 0
  set average-timeline 268
  set average-commitment-length 1000
  set percentage-pop-considers-single 0.5
  set percentage-pop-has-memory 0.5
  set action-reach "neighbors8"
  set information-reach "neighbors8"
  set-default-shape turtles "person"
  ask patches [set pcolor white]
  create-blue-agents population / 2 [ setxy random-xcor random-ycor ]
  create-green-agents population / 2 [ setxy random-xcor random-ycor ]
  ask green-agents [ set color green ]
  ask blue-agents [ set color blue ]
  ask turtles [ set quality round random-normal 5 2.5 ]
  ask turtles [ set pickiness round random-normal average-pickiness ( 1.5 ) ]
  ask turtles [ set timeline round random-normal average-timeline ( average-timeline / 3 ) ]
  ask turtles [ set looking? "yes" ]
  ask turtles [
    let draw random-float 1
    ifelse draw < percentage-pop-considers-single [ set consider-who "single" ] [ set consider-who "all" ]
    ifelse draw < percentage-pop-has-memory [ set has-memory "yes" ] [ set has-memory "no" ]
  ]
  ask turtles [ set market-assessment-list list 0 0 ]
  set n-paired count turtles with [looking? = "no"]
  reset-ticks
end

to go
  move-turtles
  update-timeline-count
  pick-candidate
  assess-market
  score-candidate
  consider-match
  report-info
  calculate-duration
  consider-unmatch
  set n-paired count turtles with [looking? = "no"]
  tick
end

to move-turtles
  ask turtles [
    if looking? = "yes" [ right random 360 forward 1 ]
  ]
end

to update-timeline-count
  ask turtles [
    set timeline-count (timeline-count + 1)
  ]
end

to pick-candidate
  ask turtles [

    if action-reach = "this-patch" [
      let number-of-neighbors count ( turtles-here ) with [ color != [ color ] of myself and looking? = "yes" ]
      if number-of-neighbors = 0 [ set this-turn-candidate "none" ]
      if number-of-neighbors != 0 [
        set this-turn-candidate ( [ who ] of one-of turtles-here )
        set number-considered-ever (number-considered-ever + 1)
      ]
    ]

    if action-reach = "neighbors4" [
      let number-of-neighbors count ( turtles-on neighbors4 ) with [ color != [ color ] of myself and looking? = "yes" ]
      if number-of-neighbors = 0 [ set this-turn-candidate "none" ]
      if number-of-neighbors != 0 [
        set this-turn-candidate ( [ who ] of one-of turtles-on neighbors4 )
        set number-considered-ever (number-considered-ever + 1)
      ]
    ]

    if action-reach = "neighbors8" [
      let number-of-neighbors count ( turtles-on neighbors ) with [ color != [ color ] of myself and looking? = "yes" ]
      if number-of-neighbors = 0 [ set this-turn-candidate "none" ]
      if number-of-neighbors != 0 [
        set this-turn-candidate ( [ who ] of one-of turtles-on neighbors )
        set number-considered-ever (number-considered-ever + 1)
      ]
    ]

    if action-reach = "global" [
      let number-of-neighbors count turtles with [ color != [ color ] of myself and looking? = "yes" ]
      if number-of-neighbors = 0 [set this-turn-candidate "none"]
      if number-of-neighbors != 0 [
        set this-turn-candidate ( [ who ] of one-of turtles )
        set number-considered-ever (number-considered-ever + 1)
      ]
    ]
  ]
end

to assess-market
  ask turtles [

    if consider-who = "all" [

      if information-reach = "this-patch" [
        let number-of-neighbors count ( turtles-here ) with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of ( turtles-here ) with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [ set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]

      if information-reach = "neighbors4" [
        let number-of-neighbors count (turtles-on neighbors4) with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of ( turtles-on neighbors4 ) with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment mean market-assessment-list ]
      ]

      if information-reach = "neighbors8" [
        let number-of-neighbors count (turtles-on neighbors) with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of ( turtles-on neighbors ) with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]

      if information-reach = "global" [
        let number-of-neighbors count turtles with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of turtles with [ color != [ color ] of myself and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]
    ]

    if consider-who = "single" [

      if information-reach = "this-patch" [
        let number-of-neighbors count (turtles-here) with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of ( turtles-here ) with [ color != [ color ] of myself and looking? = "yes" ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]

      if information-reach = "neighbors4" [
        let number-of-neighbors count (turtles-on neighbors4) with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of (turtles-on neighbors4) with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]

      if information-reach = "neighbors8" [
        let number-of-neighbors count (turtles-on neighbors) with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of (turtles-on neighbors) with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]

      if information-reach = "global" [
        let number-of-neighbors count turtles with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        let summed-neighbor-quality sum [ quality ] of turtles with [ color != [ color ] of myself and looking? = "yes" and who != [ this-turn-candidate ] of myself ]
        ifelse number-of-neighbors != 0 [set this-turn-market-assessment summed-neighbor-quality / number-of-neighbors ] [set this-turn-market-assessment 0 ]
        if has-memory = "yes" [ set market-assessment-list lput this-turn-market-assessment market-assessment-list ]
        if has-memory = "yes" [ set all-turns-market-assessment round mean market-assessment-list ]
      ]
    ]
  ]
end

to score-candidate
  ask turtles [
    if this-turn-candidate = "none" [set this-turn-candidate-score -100]
    if this-turn-candidate != "none" [
      ifelse [ has-memory ] of self = "no" [
        let score ((([quality] of turtle this-turn-candidate) - (([quality] of self) - ([quality] of turtle this-turn-candidate))) - this-turn-market-assessment)
        set this-turn-candidate-score score
      ]
      [
        let score ((([quality] of turtle this-turn-candidate) - (([quality] of self) - ([quality] of turtle this-turn-candidate))) - all-turns-market-assessment)
        set this-turn-candidate-score score
      ]
    ]
  ]
end

to consider-match
  ask turtles [
    if this-turn-candidate-score > pickiness [
      if timeline-count > timeline [
        if [ looking? ] of turtle this-turn-candidate = "yes" [
          if [ this-turn-candidate ] of turtle this-turn-candidate = [ who ] of self [
            if [ this-turn-candidate-score ] of turtle this-turn-candidate > [ pickiness ] of turtle this-turn-candidate [
              if [ timeline-count ] of turtle this-turn-candidate > [ timeline ] of turtle this-turn-candidate [
                set looking? "no"
                set color black
                set partner ([who] of turtle this-turn-candidate)
                set number-partners-ever (number-partners-ever + 1)
                ask turtle this-turn-candidate [ set looking? "no" ]
                ask turtle this-turn-candidate [ set color black ]
                ask turtle this-turn-candidate [ set partner ([who] of turtle this-turn-candidate) ]
                ask turtle this-turn-candidate [ set number-partners-ever (number-partners-ever + 1) ]
              ]
            ]
          ]
        ]
      ]
    ]
  ]
end

to report-info
  ask turtles [
    ifelse color = black [
      if number-partners-ever = 1 [ set number-considered-before-first-match number-considered-ever ]
      set current-partner-quality [quality] of turtle partner
      set current-search-time 0
    ]
    [
      set current-partner-quality 0
      set current-search-time (current-search-time + 1)
    ]
  ]
end

to calculate-duration
  ask turtles [
    if color = black [
      set relationship-duration (relationship-duration + 1)
    ]
  ]
end

to consider-unmatch
  ask turtles [
    let breakup-draw round random-normal average-commitment-length ( average-commitment-length / 3 )
    if relationship-duration > breakup-draw [
      set relationship-duration 0
      set looking? "yes"
      ifelse breed = blue-agents [ set color blue ] [ set color green ]
      ask turtle partner [ set relationship-duration 0 ]
      ask turtle partner [ set looking? "yes" ]
      ask turtle partner [ ifelse breed = blue-agents [ set color blue ] [ set color green ] ]
      set partner 0
      ask turtle partner [ set partner 0 ]
    ]
  ]
end
"""
end
