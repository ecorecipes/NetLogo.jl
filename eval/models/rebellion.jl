# ── Rebellion model (Epstein civil violence, NetLogo models library) ─

struct RebellionModel <: AbstractBenchmarkModel end

model_name(::RebellionModel) = "Rebellion"
n_ticks(::RebellionModel) = 200
tracked_globals(::RebellionModel) = ["quiet", "active", "jailed"]
world_dims(::RebellionModel) = (0, 39, 0, 39)

function netlogo_code(::RebellionModel)
"""
globals [randomSeed k threshold
         initial-cop-density initial-agent-density
         government-legitimacy max-jail-term vision
         movement? visualization
         quiet active jailed]

breed [agents agent]
breed [cops cop]

agents-own [
  risk-aversion
  perceived-hardship
  active?
  jail-term
]

patches-own [
  neighborhood
]

to setup
  clear-all
  resize-world 0 39 0 39
  set k 2.3
  set threshold 0.1
  set initial-cop-density 4
  set initial-agent-density 70
  set government-legitimacy 0.82
  set max-jail-term 30
  set vision 7
  set movement? true
  set visualization "2D"
  ask patches [
    set pcolor gray - 1
    set neighborhood patches in-radius vision
  ]
  create-cops round (initial-cop-density * 0.01 * count patches) [
    move-to one-of patches with [not any? turtles-here]
    display-cop
  ]
  create-agents round (initial-agent-density * 0.01 * count patches) [
    move-to one-of patches with [not any? turtles-here]
    set heading 0
    set risk-aversion random-float 1.0
    set perceived-hardship random-float 1.0
    set active? false
    set jail-term 0
    display-agent
  ]
  update-globals
  reset-ticks
end

to go
  ask turtles [
    if (breed = agents and jail-term = 0) or breed = cops
      [ move ]
    if breed = agents and jail-term = 0 [ determine-behavior ]
    if breed = cops [ enforce ]
  ]
  ask agents [
    if jail-term > 0 [ set jail-term jail-term - 1 ]
  ]
  ask agents [ display-agent ]
  ask cops [ display-cop ]
  update-globals
  tick
end

to move
  if movement? or (breed = cops) [
    let targets neighborhood with
                [not any? cops-here and all? agents-here [jail-term > 0]]
    if any? targets [ move-to one-of targets ]
  ]
end

to determine-behavior
  set active? (grievance - risk-aversion * estimated-arrest-probability > threshold)
end

to-report grievance
  report perceived-hardship * (1 - government-legitimacy)
end

to-report estimated-arrest-probability
  let C count cops-on neighborhood
  let A 1 + count (agents-on neighborhood) with [active?]
  report 1 - exp (- k * floor (C / A))
end

to enforce
  if any? (agents-on neighborhood) with [active?] [
    let suspect one-of (agents-on neighborhood) with [active?]
    ask suspect [
      set active? false
      set jail-term random max-jail-term
    ]
    move-to suspect
  ]
end

to display-agent
  set shape "circle"
  ifelse active?
    [ set color red ]
    [ ifelse jail-term > 0
        [ set color black + 3 ]
        [ set color scale-color green grievance 1.5 -0.5 ] ]
end

to display-cop
  set color cyan
  set shape "triangle"
end

to update-globals
  set quiet count agents with [not active? and jail-term = 0]
  set active count agents with [active?]
  set jailed count agents with [jail-term > 0]
end
"""
end
