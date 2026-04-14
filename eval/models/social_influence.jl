# ── Social Influence ─────────────────────────────────────────────
# Source: modelingcommons #4376
# NW extension: set-context (for layout, but we skip layout)
# Preferential-attachment network growth model where new nodes
# adopt the color of the node they attach to. Tracks total turtles
# and number of influence events (connections made).

struct SocialInfluenceModel <: AbstractBenchmarkModel end

model_name(::SocialInfluenceModel) = "Social Influence"
n_ticks(::SocialInfluenceModel) = 200
tracked_globals(::SocialInfluenceModel) = ["number-influence"]

function netlogo_code(::SocialInfluenceModel)
"""
extensions [nw]
globals [number-influence layout? plot?]

to setup
  clear-all
  nw:set-context turtles links
  set-default-shape turtles "circle"
  set layout? false
  set plot? false
  set number-influence 0
  make-node nobody
  make-node turtle 0
  reset-ticks
end

to go
  ask links [ set color gray ]
  make-node find-partner
  tick
end

to make-node [old-node]
  crt 1 [
    set color one-of [yellow green]
    if old-node != nobody [
      create-link-with old-node [ set color blue ]
      set color [color] of old-node
    ]
    fd 8
    set number-influence number-influence + 1
  ]
end

to-report find-partner
  report one-of turtles
end
"""
end
