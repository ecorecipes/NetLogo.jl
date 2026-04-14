# ── Voting model ─────────────────────────────────────────────────────

struct VotingModel <: AbstractBenchmarkModel end

model_name(::VotingModel) = "Voting"
n_ticks(::VotingModel) = 200
tracked_globals(::VotingModel) = ["blue-count", "green-count"]
world_dims(::VotingModel) = (-75, 75, -75, 75)

function netlogo_code(::VotingModel)
"""
globals [randomSeed change-vote-if-tied? award-close-calls-to-loser?
         blue-count green-count]

patches-own [
  vote
  total
]

to setup
  clear-all
  resize-world (- 75) 75 (- 75) 75
  set change-vote-if-tied? false
  set award-close-calls-to-loser? false
  ask patches [
    set vote random 2
    recolor-patch
  ]
  update-globals
  reset-ticks
end

to go
  ask patches [
    set total (sum [vote] of neighbors)
  ]
  ask patches [
    if total > 5 [ set vote 1 ]
    if total < 3 [ set vote 0 ]
    if total = 4 [
      if change-vote-if-tied? [ set vote (1 - vote) ]
    ]
    if total = 5 [
      ifelse award-close-calls-to-loser?
        [ set vote 0 ]
        [ set vote 1 ]
    ]
    if total = 3 [
      ifelse award-close-calls-to-loser?
        [ set vote 1 ]
        [ set vote 0 ]
    ]
    recolor-patch
  ]
  update-globals
  tick
end

to recolor-patch
  ifelse vote = 0
    [ set pcolor lime ]
    [ set pcolor blue ]
end

to update-globals
  set blue-count count patches with [pcolor = blue]
  set green-count count patches with [pcolor = lime]
end
"""
end
