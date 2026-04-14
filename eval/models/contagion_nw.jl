# ── Contagion on Network (Preferential Attachment) ────────────────
# Source: modelingcommons #4383
# NW extension: set-context for preferential attachment growth
# Network grows via preferential attachment until target link count,
# then contagion spreads through linked and unlinked neighbors.

struct ContagionNWModel <: AbstractBenchmarkModel end

model_name(::ContagionNWModel) = "Contagion NW"
n_ticks(::ContagionNWModel) = 200
tracked_globals(::ContagionNWModel) = ["num-infected-nw", "num-links-nw"]
world_dims(::ContagionNWModel) = (-45, 45, -45, 45)
topology(::ContagionNWModel) = (false, false)

function netlogo_code(::ContagionNWModel)
"""
extensions [nw]

globals [
  N
  number-of-links
  probability-linked-affected
  probability-other-affected
  num-infected-nw
  num-links-nw
]

to setup
  clear-all
  set number-of-links 100
  set probability-linked-affected 50
  set probability-other-affected 1
  set-default-shape turtles "circle"
  nw:set-context turtles links
  set N 0
  make-node nobody
  make-node turtle 0
  reset-ticks
end

to go
  while [N < number-of-links] [
    ask links [ set color gray ]
    make-node find-partner
  ]
  ask one-of turtles [ set color green ]
  if any? turtles with [color = red] [
    ask turtles with [color = green] [
      ask link-neighbors [
        if random 100 <= probability-linked-affected [ set color green ]
        ask other turtles [
          if random 100 < probability-other-affected [ set color green ]
        ]
      ]
    ]
  ]
  set num-infected-nw count turtles with [color = green]
  set num-links-nw count links
end

to make-node [old-node]
  crt 1 [
    set color red
    if old-node != nobody [
      create-link-with old-node [ set color green ]
      move-to old-node
      fd 8
      set N N + 1
    ]
  ]
end

to-report find-partner
  report [one-of both-ends] of one-of links
end
"""
end
