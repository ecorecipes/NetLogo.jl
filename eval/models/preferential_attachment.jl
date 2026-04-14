# ── Preferential Attachment model (NetLogo models library) ──────────

struct PreferentialAttachmentModel <: AbstractBenchmarkModel end

model_name(::PreferentialAttachmentModel) = "Preferential Attachment"
n_ticks(::PreferentialAttachmentModel) = 498
tracked_globals(::PreferentialAttachmentModel) = ["num-nodes", "num-edges", "max-degree"]
world_dims(::PreferentialAttachmentModel) = (-45, 45, -45, 45)

function netlogo_code(::PreferentialAttachmentModel)
"""
globals [randomSeed max-nodes num-nodes num-edges max-degree]

to setup
  clear-all
  set max-nodes 500
  set-default-shape turtles "circle"
  make-node nobody
  make-node turtle 0
  update-globals
  reset-ticks
end

to go
  if count turtles >= max-nodes [ stop ]
  ask links [ set color gray ]
  make-node find-partner
  update-globals
  tick
end

to make-node [old-node]
  crt 1 [
    set color red
    if old-node != nobody [
      create-link-with old-node [ set color green ]
      move-to old-node
      fd 8
    ]
  ]
end

to-report find-partner
  let total random-float sum [count link-neighbors] of turtles
  let partner nobody
  ask turtles [
    let nc count link-neighbors
    if partner = nobody [
      ifelse nc > total
        [ set partner self ]
        [ set total total - nc ]
    ]
  ]
  report partner
end

to update-globals
  set num-nodes count turtles
  set num-edges count links
  ifelse any? turtles
    [ set max-degree max [count link-neighbors] of turtles ]
    [ set max-degree 0 ]
end
"""
end
