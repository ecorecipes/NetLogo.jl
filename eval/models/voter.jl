# ── Voter Model (Consensus Dynamics) ────────────────────────────────
# Adapted from model-zoo 3.8-voter-model
# Patches copy random neighbor's color, converges to consensus

struct VoterModel <: AbstractBenchmarkModel end

model_name(::VoterModel) = "Voter Model"
n_ticks(::VoterModel) = 200
tracked_globals(::VoterModel) = ["n-colors"]
world_dims(::VoterModel) = (0, 49, 0, 49)

function netlogo_code(::VoterModel)
"""
globals [randomSeed N pcolors n-colors]

to setup
  clear-all
  set N count patches
  set pcolors sublist (list grey white red yellow green orange blue pink) 0 2
  ask patches [
    set pcolor one-of pcolors
  ]
  set n-colors length remove-duplicates [pcolor] of patches
  reset-ticks
end

to go
  if length remove-duplicates [pcolor] of patches = 1 [ stop ]
  repeat count patches [
    ask one-of patches [
      set pcolor [pcolor] of one-of neighbors4
    ]
  ]
  set n-colors length remove-duplicates [pcolor] of patches
  tick
end
"""
end
