# ── Team Assembly model (NetLogo models library) ─────────────────────

struct TeamAssemblyModel <: AbstractBenchmarkModel end

model_name(::TeamAssemblyModel) = "Team Assembly"
n_ticks(::TeamAssemblyModel) = 50
tracked_globals(::TeamAssemblyModel) = ["giant-component-size"]
world_dims(::TeamAssemblyModel) = (-50, 50, -50, 50)

function netlogo_code(::TeamAssemblyModel)
"""
globals [randomSeed max-downtime p q team-size
         newcomer component-size giant-component-size components]

turtles-own [incumbent? in-team? downtime explored?]

links-own [new-collaboration?]

to setup
  clear-all
  resize-world (- 50) 50 (- 50) 50
  set max-downtime 40
  set p 40
  set q 65
  set team-size 4
  set-default-shape turtles "circle"
  repeat team-size [ make-newcomer ]
  ask turtles [
    set in-team? true
    set incumbent? true
  ]
  tie-collaborators
  ask turtles [
    set heading (360 / team-size) * who
    fd 1.75
    set in-team? false
  ]
  find-all-components
  reset-ticks
end

to make-newcomer
  create-turtles 1 [
    set color blue + 1
    set size 1.8
    set incumbent? false
    set in-team? false
    set newcomer self
    set downtime 0
    set explored? false
  ]
end

to go
  ask turtles [set incumbent? true set color gray - 1.5 set size 0.9]
  ask links [set new-collaboration? false]
  pick-team-members
  tie-collaborators
  ask turtles [
    if downtime > max-downtime [ die ]
    set in-team? false
    set downtime downtime + 1
  ]
  find-all-components
  tick
end

to pick-team-members
  let new-team-member nobody
  repeat team-size [
    ifelse random-float 100.0 >= p [
      make-newcomer
      set new-team-member newcomer
    ] [
      ifelse random-float 100.0 < q and any? (turtles with [in-team? and (any? link-neighbors with [not in-team?])]) [
        set new-team-member one-of turtles with [not in-team? and (any? link-neighbors with [in-team?])]
      ] [
        set new-team-member one-of turtles with [not in-team?]
      ]
    ]
    ask new-team-member [
      set in-team? true
      set downtime 0
      set size 1.8
      set color ifelse-value incumbent? [yellow + 2] [blue + 1]
    ]
  ]
end

to tie-collaborators
  ask turtles with [in-team?] [
    create-links-with other turtles with [in-team?] [
      set new-collaboration? true
      set thickness 0.3
    ]
  ]
end

to find-all-components
  set components []
  set giant-component-size 0
  ask turtles [ set explored? false ]
  loop [
    let start one-of turtles with [ not explored? ]
    if start = nobody [ stop ]
    set component-size 0
    ask start [ explore ]
    if component-size > giant-component-size [
      set giant-component-size component-size
    ]
    set components lput component-size components
  ]
end

to explore
  if explored? [ stop ]
  set explored? true
  set component-size component-size + 1
  ask link-neighbors [ explore ]
end
"""
end
