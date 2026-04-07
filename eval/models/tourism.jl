# ── Tourism Destination model (CSS645 ClassModels) ──────────────────────

struct TourismModel <: AbstractBenchmarkModel end

model_name(::TourismModel) = "Tourism"
n_ticks(::TourismModel) = 50
tracked_globals(::TourismModel) = ["attendance", "reputation"]
world_dims(::TourismModel) = (-80, 80, -30, 30)

function netlogo_code(::TourismModel)
"""
globals [
  randomSeed
  destination-patches
  home-patches
  attendance
  reputation
  attraction
  maintaining-rate
  initial-number
  capacity
  innovative?
  promotive?
  extension?
]

turtles-own [
  evaluation
  revisit-interval
  social?
]

to setup
  clear-all
  set maintaining-rate 80
  set initial-number 30
  set capacity 410
  set innovative? false
  set promotive? false
  set extension? false
  setup-environment
  setup-visitors
  reset-ticks
end

to setup-environment
  set destination-patches patches with [pxcor > 30]
  ask destination-patches [set pcolor green]
  set home-patches patches with [pxcor <= 30]
  set reputation 0
  set attraction 300
end

to setup-visitors
  set-default-shape turtles "person"
  crt initial-number [
    set color white
    set size 2
    move-to-empty-one-of home-patches
    set revisit-interval random 9 + 1
  ]
  ask turtles [
    ifelse (random-float 100 < 50)
      [set social? true]
      [set social? false]
  ]
end

to go
  if count turtles = 0 [stop]
  tick
  ask turtles [
    set revisit-interval revisit-interval - 1
    ifelse revisit-interval = 0
      [ move-to-empty-one-of destination-patches
        evaluate
        set attendance attendance + 1
        ifelse (innovative?)
        [ ifelse (ticks <= 30)
          [set attraction attraction - 1 + maintaining-rate / 100 + 0.2]
          [set attraction attraction - 1 + maintaining-rate / 100 + 0.2 + 0.1]
        ]
        [set attraction attraction - 1 + maintaining-rate / 100 + 0.2]
        if promotive? = true
        [hatch 1
         [set color white
          set size 2
          ifelse (random-float 100 < 50)
           [set social? true]
           [set social? false]
          move-to-empty-one-of home-patches
          set revisit-interval random 9 + 1]
        ]
      ]
      [ move-to-empty-one-of home-patches ]
    set attendance count turtles-on destination-patches

    let evaluation-list []
    set evaluation-list fput evaluation evaluation-list
    let l length evaluation-list
    if l = random 9 + 1 [die]
  ]
  if extension?
   [if ticks = 70
     [set capacity capacity + 100]]
  if count turtles = 0 [stop]
end

to evaluate
  ifelse (social? = true)
    [if attraction >= 250 and attendance <= 0.5 * capacity
      [set evaluation 3
       set reputation reputation + 2
       set revisit-interval random 4
       hatch 2
         [set color white
          set size 2
          set social? true
          move-to-empty-one-of home-patches
          set revisit-interval random 9 + 1]
       ]
     if attraction >= 250 and attendance > 0.5 * capacity and attendance < capacity
      [set evaluation 2
       set reputation reputation + 1
       set revisit-interval random 8
       hatch 1
         [set color white
          set size 2
          set social? true
          move-to-empty-one-of home-patches
          set revisit-interval random 9 + 1]
        ]
     if attraction <= 250 and attraction > 50 and attendance <= 0.5 * capacity
      [set evaluation 1
       set revisit-interval random 30]
     if attraction <= 250 and attraction > 50 and attendance > 0.5 * capacity and attendance < capacity
      [set evaluation 1
       set revisit-interval random 30
        ]
     if attendance >= capacity
      [ set evaluation 0
       set reputation reputation - 2
       die
       if any? turtles with [ social? = true ] [ask one-of turtles with [ social? = true ] [die]]
      ]
     if attraction <= 50
      [ set evaluation 0
       set reputation reputation - 2
       die
       if any? turtles with [ social? = true ] [ask one-of turtles with [ social? = true ] [die]]
      ]
    ]

    [if attraction >= 250 and attendance <= 0.5 * capacity
      [set evaluation 3
       set reputation reputation + 2
       set revisit-interval random 4
       hatch 2
         [set color white
          set size 2
          set social? false
          move-to-empty-one-of home-patches
          set revisit-interval random 9 + 1]
       ]
     if attraction >= 250 and attendance > 0.5 * capacity and attendance < 0.8 * capacity
      [set evaluation 1
       set revisit-interval random 30]
     if attendance >= 0.8 * capacity
      [ set evaluation 0
       set reputation reputation - 2
       die
       if any? turtles with [social? = false] [ask one-of turtles with [social? = false] [die]]
      ]
     if attraction <= 250 and attraction > 0 and attendance <= 0.5 * capacity
      [set evaluation 2
       set reputation reputation + 1
       set revisit-interval random 8
       hatch 1
         [set color white
          set size 2
          set social? false
          move-to-empty-one-of home-patches
          set revisit-interval random 9 + 1]
        ]
     if attraction <= 250 and attendance > 0.5 * capacity and attraction > 0 and attendance < 0.8 * capacity
      [set evaluation 1
       set revisit-interval random 30
      ]
     if attraction <= 0
      [set evaluation 0
       set reputation reputation - 2
       die
       if any? turtles with [social? = false] [ask one-of turtles with [social? = false] [die]]
      ]
     ]
end

to move-to-empty-one-of [locations]
  move-to one-of locations
  let tries 0
  while [any? other turtles-here and tries < 100] [
    move-to one-of locations
    set tries tries + 1
  ]
end
"""
end
