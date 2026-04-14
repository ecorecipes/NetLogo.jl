# Social Network Diffusion Model
# nw extension: tests nw:generate-preferential-attachment, nw:modularity,
#   nw:louvain-communities, nw:betweenness-centrality, nw:eigenvector-centrality
# Belief diffusion on a directed network with weighted influence
# Source: modelingcommons #7017

struct SocialNetworkDiffusionModel <: AbstractBenchmarkModel end

model_name(::SocialNetworkDiffusionModel) = "Social Network Diffusion"
n_ticks(::SocialNetworkDiffusionModel) = 20
tracked_globals(::SocialNetworkDiffusionModel) = ["num-red", "num-grey", "avg-utility"]
world_dims(::SocialNetworkDiffusionModel) = (-16, 16, -16, 16)
topology(::SocialNetworkDiffusionModel) = (false, false)

function netlogo_code(::SocialNetworkDiffusionModel)
    return """
extensions [nw]
breed [group person]
directed-link-breed [influences influence]
links-own [weight alternative]
group-own [p utility preferences oldsum]
globals [changing num-red num-grey avg-utility threshold members]

to setup
  clear-all
  set threshold 0.5
  set members 30
  set changing true
  nw:generate-preferential-attachment group influences members 1 [
    set color grey
    setxy random-xcor random-ycor
    set shape "person"
    set size 2
    set oldsum 0
    set utility 0
    set preferences []
  ]
  ;; assign random weights to links
  ask influences [set weight (round (1000 * random-float 1) / 1000)]
  ;; assign initial beliefs: 1 = red believer, -1 = grey non-believer
  ask group [
    set p random 2
    ifelse p = 1 [set color red] [set p -1 set color grey]
  ]
  update-stats
  reset-ticks
end

to go
  if not changing [stop]
  if ticks > 20 [stop]
  set changing false
  ask influences [
    if [color] of end1 = red [set color red]
  ]
  ask group [
    let summer 0
    ask my-in-links [
      let netweight (weight * ([p] of end1))
      set summer (summer + netweight)
    ]
    set oldsum precision oldsum 3
    set summer precision summer 3
    if oldsum != summer [set changing true]
    set oldsum summer
    let oldcolor color
    ifelse summer > threshold [
      set p 1
      set color red
    ] [
      if summer < threshold * -1 [
        set p -1
        set color grey
      ]
    ]
  ]
  ;; compute individual utility
  ask influences [set alternative weight * [p] of end1]
  ask group [
    ifelse any? my-in-links [
      set preferences [alternative] of my-in-links
      set utility max preferences
    ] [
      set utility p
    ]
  ]
  update-stats
  tick
end

to update-stats
  set num-red count group with [color = red]
  set num-grey count group with [color = grey]
  ifelse any? group [
    set avg-utility mean [utility] of group
  ] [
    set avg-utility 0
  ]
end
"""
end
