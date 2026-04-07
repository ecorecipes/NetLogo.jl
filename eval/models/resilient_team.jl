# ── Resilient Team model (CSS600 ClassModels) ────────────────────────

struct ResilientTeamModel <: AbstractBenchmarkModel end

model_name(::ResilientTeamModel) = "Resilient Team"
n_ticks(::ResilientTeamModel) = 200
tracked_globals(::ResilientTeamModel) = ["mean [stress] of turtles", "mean [resilience] of turtles"]
world_dims(::ResilientTeamModel) = (-16, 16, -16, 16)
topology(::ResilientTeamModel) = (false, false)

function netlogo_code(::ResilientTeamModel)
"""
extensions [rnd]

globals [
  numberagents
  a
  b
  G_belief
  G_belongsafe
  G_contribute
  G_engagement
  G_gratitude
  G_resilience
  G_stress
  EG_stress_new
  zipfdist
]

turtles-own [
  belief
  belongsafe
  contribute
  hope
  resilience
  strength
  stress
  trusted
  blame_rate
  gratitude_rate
  hope_rate
  listen_rate
  spend_rate
  recovery_rate
  seekhelp_rate
  trust_rate
]

directed-link-breed [relations relation]
relations-own [
  N_blame
  N_feedback
  N_gratitude
  N_interact_rate
  N_recrimination
  N_seekhelp
  N_spend
  N_stress
  N_trust
  D_belief
  D_blame
  D_gratitude
  D_hope
  D_listen
  D_seekhelp
  D_spend
]

patches-own [
  EI_stress
  EG_stress
]

to setup
  clear-all
  set numberagents 5
  setup-patches
  setup-turtles
  setup-links
  initialize-globals
  reset-ticks
end

to setup-patches
  ask patches [set pcolor black]
  ask patches [initialize_env]
end

to setup-turtles
  create-turtles numberagents
  layout-circle sort turtles 10
  ask turtles [set color white]
  ask turtles [set shape "face happy"]
  ask turtles [initialize_agents]
end

to setup-links
  ask turtles [create-relations-to other turtles]
  ask relations [set thickness 0.1]
  ask relations [set color (blue + 2)]
  ask relations [initialize_relations]
end

to restore-defaults
  set numberagents 5
end

to initialize-globals
  set a 1
  set b 7
  set zipfdist [[1 0.818] [2 0.143] [3 0.020] [4 0.010] [5 0.005] [6 0.003] [7 0.001]]
end

to initialize_agents
  set belief 4
  set belongsafe 4
  set contribute 4
  set hope 4
  set resilience 4
  set strength 4
  set stress 4
  set trusted 4
  set blame_rate 0.5
  set gratitude_rate 0.5
  set hope_rate 0.5
  set listen_rate 0.5
  set recovery_rate 0.5
  set seekhelp_rate 0.5
  set spend_rate 0.5
  set trust_rate 0.5
end

to initialize_env
  set EI_stress 1
  set EG_stress 1
end

to initialize_relations
  set D_belief 1
  set D_blame 1
  set D_gratitude 1
  set D_hope 1
  set D_listen 1
  set D_seekhelp 1
  set D_spend 1
  set N_blame 1
  set N_feedback 1
  set N_gratitude 1
  set N_seekhelp 1
  set N_spend 1
  set N_stress 1
  set N_trust 1
  set N_recrimination 1
  set N_interact_rate 0.5
end

to go
  if ticks >= 500 [stop]
  gotick
end

to gotick
  print "===================================="
  type "VALUES @ tick " type (ticks) print ":"
  update_env
  agent_perceive
  agent_decisions
  agent_change
  agent_act
  tick
end

to update_env
  ask patches [set EI_stress (first rnd:weighted-one-of-list zipfdist [[p] -> last p])]
  set EG_stress_new (first rnd:weighted-one-of-list zipfdist [[p] -> last p])
  ask patches [set EG_stress EG_stress_new]
  ask patches [set pcolor ((((EI_stress + EG_stress) - 2) / (14 - 2)) * (15 - 19.9) + 19.9)]
  type "EG_stress: " type ([precision EG_stress 2] of turtles)
  type ". EI_stress: " type ([precision EI_stress 2] of turtles)
  type ". pcolor = " type ([EI_stress + EG_stress] of patches)
  print "."
end

to agent_perceive
  ask turtles [set stress stress + (((([EI_stress] of patch-here + [EG_stress] of patch-here) - 2) / (14 - 2)) * (b - a) + a)]
  ask turtles [set stress (stress / (((resilience - 1) / (7 - 1)) * (2 - 1) + 1))]
  ask turtles [IF (stress > 7) [set stress 7]]
  ask turtles [IF (stress < 1) [set stress 1]]
  ask turtles [set color resilience
    set size stress]
  type "stress: " type ([precision stress 2] of turtles) print "."
end

to agent_decisions
  ask turtles
  [ask my-in-relations
    [set D_listen (((([listen_rate] of myself * (([resilience] of myself + [belongsafe] of myself - [stress] of myself ) / 2)) - 0) / (13 - 0)) * (b - a) + a)]
  ]
  ask relations
  [IFELSE (([belief] of end2 > 1) and ([belongsafe] of end2 >= N_trust) and ([stress] of end2 > 1))
    [set D_seekhelp (((([seekhelp_rate] of end2 * ((N_trust + [belongsafe] of end2 + [stress] of end2))) - 0) / (21 - 0)) * (b - a) + a)]
    [set D_seekhelp 1]
  ]
  ask relations [IFELSE (([stress] of end1 > 2) and ([trusted] of end1 >= [trusted] of end2))
    [set D_blame (((([blame_rate] of end1 * ((8 - [belongsafe] of end1) + ([stress] of end1) + (8 - N_trust ))) - 0) / (21 - 0)) * (b - a) + a)]
    [set D_blame 1]
  ]
  ask relations [set D_spend ((([spend_rate] of end1 * (N_seekhelp + [resilience] of end1 + [belongsafe] of end1) - 0) / (21 - 0)) * (b - a) + a)]
  type "spend_rate: " type ([precision spend_rate 2] of turtles) print "."
  type "strength: " type ([precision strength 2] of turtles) print "."
  type "resilience: " type ([precision resilience 2] of turtles) print "."
  type "D_listen: " type ([precision D_listen 2] of relations) print "."
  type "D_seekhelp: " type ([precision D_seekhelp 2] of relations) print "."
  type "D_blame: " type ([precision D_blame 2] of relations) print "."
  type "D_spend: " type ([precision D_spend 2] of relations) print "."
  type "blame_rate: " type ([precision blame_rate 2] of turtles) print "."
  type "N_trust: " type ([precision N_trust 2] of relations) print "."
end

to agent_change
  ask turtles [set trusted (mean [N_trust] of my-in-relations)]
  ask turtles [set belongsafe (((((mean [D_seekhelp] of my-in-relations) + ((8 - (mean [D_blame] of my-in-relations)) * 3)) - 4) / (28 - 4)) * (b - a) + a)]
  type "trusted: " type ([precision trusted 2] of turtles) print "."
  type "belongsafe: " type ([precision belongsafe 2] of turtles) print "."
  type "resilience: " type ([precision resilience 2] of turtles) print "."
end

to agent_act
  ask relations [set N_seekhelp 1]
  ask turtles [ask (max-one-of my-out-relations [D_seekhelp]) [set N_seekhelp 7] ]
  type "N_seekhelp: " type ([precision N_seekhelp 2] of relations) print "."
  type "N_blame: " type ([precision N_blame 2] of relations) print "."
  type "N_spend: " type ([precision N_spend 2] of relations) print "."
  type "N_feedback: " type ([precision N_feedback 2] of relations) print "."
end
"""
end
