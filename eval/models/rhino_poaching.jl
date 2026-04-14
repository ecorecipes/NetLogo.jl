# ── Rhino Poaching ───────────────────────────────────────────────────
# Source: modelingcommons #5016
# Rhinos, poachers, and rangers interact in a protected area.
# Poachers hunt rhinos; rangers patrol to catch poachers.

struct RhinoPoachingModel <: AbstractBenchmarkModel end

model_name(::RhinoPoachingModel) = "Rhino Poaching"
n_ticks(::RhinoPoachingModel) = 2000
tracked_globals(::RhinoPoachingModel) = ["n-rhinos", "n-poachers", "total-killed"]
world_dims(::RhinoPoachingModel) = (0, 100, 0, 100)
topology(::RhinoPoachingModel) = (false, false)

function netlogo_code(::RhinoPoachingModel)
"""
extensions [rnd]

globals [
  max-roughness
  sprout-delay-time
  rhino-activity-decay
  human-signs-decay
  carcass-decay
  rhino-weight
  poacher-weight
  ranger-weight
  num-rhinos
  rough-areas
  num-poachers
  sandy-areas
  num-rangers
  forage-amount
  num-camps
  poacher-time
  poacher-vision
  ranger-vision
  patrol-length
  visualization
  camp-placement
  patrol-type
  herd
  coordinated
  intervals
  resources-weight
  roughness-weight
  rhino-avoid-weight
  ranger-avoid-weight
  hunt-rhino-weight
  success-weight
  catch-poacher-weight
  search-rhino-weight
  goal-weight
  n-rhinos
  n-poachers
  total-killed
]

breed [ camps camp ]
breed [ poachers poacher ]
breed [ rhinos rhino ]
breed [ rangers ranger ]

rangers-own [
  patrol-memory
  patrol-time
  risky-areas
  safe-areas
  off-duty-time
  rhino-sightings
  ranger-goal
  state
  direction
  ticks-wait
]

poachers-own [
  time
  laylow
  success-sites
  good-sites
  failure-sites
  rhinos-killed
  poacher-memory
  poacher-goal
  state
  ticks-wait
]

rhinos-own [
  rhino-memory
  rhino-goal
  ticks-wait
  herd-size
]

patches-own [
  inside?
  resources
  roughness
  countdown
  recent-rhino-activity
  rhino-territory
  poacher-signs
  patch-attractiveness
  ranger-signs
]

to setup
  clear-all
  set num-rhinos 70
  set rough-areas 2
  set num-poachers 4
  set sandy-areas 5
  set num-rangers 4
  set forage-amount 1
  set num-camps 1
  set poacher-time 50
  set poacher-vision 1.5
  set ranger-vision 1.5
  set patrol-length 50
  set visualization "resources_colors"
  set camp-placement "random"
  set patrol-type "fence-patrol"
  set herd true
  set coordinated false
  set intervals false
  set resources-weight 3
  set roughness-weight 2
  set rhino-avoid-weight 2
  set ranger-avoid-weight 3
  set hunt-rhino-weight 2
  set success-weight 2
  set catch-poacher-weight 3
  set search-rhino-weight 2
  set goal-weight 2
  set total-killed 0
  setup-park
  setup-humans
  reset-ticks
end

to setup-park
  set sprout-delay-time 100
  set max-roughness 5
  set rhino-activity-decay 500
  set rhino-weight (rhino-avoid-weight + roughness-weight + resources-weight)
  create-park
  create-rough-areas
  release-rhinos
  setup-home-range
end

to-report population-size
  report sum [herd-size] of rhinos
end

to setup-humans
  set carcass-decay 10000
  set human-signs-decay 200
  set poacher-weight (ranger-avoid-weight * 2) + hunt-rhino-weight + roughness-weight + resources-weight
  set ranger-weight 1 + search-rhino-weight + roughness-weight + catch-poacher-weight
  build-camps
  distribute-camps
  release-rangers
  release-poachers
end

to create-park
  ask patches with [count neighbors = 8] [
    set rhino-territory nobody
    set roughness 1
    set inside? TRUE
    set resources random-float 1.1
    set countdown random (sprout-delay-time + random 100)
  ]
  diffuse resources 0.4
  ask patches with [count neighbors < 8] [
    set roughness 1
    set resources 0
    set inside? FALSE
    set countdown 0
    set pcolor black
  ]
  let percentage-sand ((count patches with [inside? = TRUE]) / 100) * sandy-areas
  ask n-of percentage-sand patches with [inside? = TRUE] [
    set resources 0
  ]
  ask patches [color-resources]
end

to setup-rhino
  if ticks = 1000 [ stop ]
  ask rhinos [
    rhino-goal-check
    update-rhino-memory
    rhino-foraging-and-home-range
  ]
  ask patches [
    update-resources
    update-home-range
    update-visualization
    update-activity-signs
  ]
  tick
end

to go
  if (not any? rhinos) [ stop ]
  if (not any? poachers) [ stop ]
  if ticks = 10000 [ stop ]

  ask rhinos [
    rhino-goal-check
    update-rhino-memory
    rhino-foraging-and-home-range
  ]

  ask poachers [
    poacher-laylow
    poacher-goal-check
  ]

  ask rangers [
    ranger-end-patrol
    ranger-goal-check
  ]

  ask patches [
    update-resources
    update-home-range
    update-visualization
    update-activity-signs
  ]

  set n-rhinos count rhinos
  set n-poachers count poachers
  tick
end

to update-visualization
  if visualization = "resources_colors" [
    color-resources
  ]
  if visualization = "rhino_home-ranges" [
    color-home-range
  ]
  if (visualization = "rough_areas") [
    color-rough-areas
  ]
end

to color-home-range
  ifelse inside? [
    if rhino-territory != nobody [
      set pcolor [color] of rhino-territory + 2]
    if rhino-territory = nobody and resources > 0 [
      set pcolor (scale-color green resources 1.5 0)]
    if rhino-territory = nobody and resources = 0 [
      set pcolor brown * 1.02]
  ]
  [set pcolor black]
end

to update-resources
  set countdown (countdown - 1)
  if inside? and countdown = 0 [
    set resources (resources * 1.01)
    set countdown sprout-delay-time + random 100
    if resources > 1 [set resources 1]
  ]
  if not inside? [
    set resources 0]
  if resources < 0 [
    set resources 0
  ]
  if (visualization = "resources_colours") [
    color-resources]
end

to color-resources
  ifelse inside? [
    ifelse resources > 0 [
      set pcolor (scale-color green resources 1.5 0)]
    [set pcolor brown * 1.02]
  ]
  [set pcolor black]
end

to create-rough-areas
  ask n-of rough-areas patches with [inside? = TRUE] [
    set roughness max-roughness
    ask patches in-radius (max-roughness - 1) [
      set roughness round (max-roughness - distance myself + roughness)
      if roughness < 1 [
        set roughness 1]
      if roughness > max-roughness [
        set roughness max-roughness]
    ]
  ]
  if visualization = "rough_areas" [
    ask patches [
      color-rough-areas]
  ]
end

to color-rough-areas
  if roughness > 1 [
    set pcolor (scale-color red roughness 1 10)
  ]
  if roughness = 1 and resources > 0 [
    set pcolor (scale-color green resources 1.5 0)
  ]
  if roughness = 1 and resources = 0 and inside? = TRUE [
    set pcolor brown * 1.02
  ]
  if roughness = 1 and resources = 0 and inside? = FALSE [
    set pcolor black
  ]
end

to release-rhinos
  set-default-shape rhinos "default"
  ask n-of num-rhinos patches with [inside? = TRUE and not any? turtles in-radius 5] [
    sprout-rhinos 1 [
      set size 2]
  ]
  spread-rhinos
  ask rhinos [
    set rhino-memory (list patch-here)
    set rhino-goal patch-here
    ifelse herd = true [set herd-size 5] [set herd-size 1]
  ]
end

to setup-home-range
  ask rhinos [
    ask patches in-radius 1.5 with [inside? = TRUE] [
      set rhino-territory myself
      if visualization = "rhino_home-ranges" [
        set pcolor [color] of myself + 2]
    ]
    if random-float 1 < 0.5 [
      ask patch-here [
        set recent-rhino-activity rhino-activity-decay + random 500]
    ]
  ]
end

to spread-rhinos
  let spreading-rhinos rhinos with [any? other turtles in-radius 10]
  if any? spreading-rhinos [
    ask one-of spreading-rhinos [
      let available-patches patches with [inside? = TRUE and not any? other turtles in-radius 10]
      ifelse any? available-patches [
        move-to one-of available-patches
        spread-rhinos
      ]
      [move-to one-of patches with [inside? = TRUE and not any? other turtles-here]]
    ]
  ]
end

to release-poachers
  set-default-shape poachers "person"
  ask n-of num-poachers patches with [inside? = FALSE] [
    sprout-poachers 1 [
      set color blue
      set size 2
      set time 0
      set laylow (poacher-time * 2) + random 100
      set good-sites no-patches
      set success-sites no-patches
      set failure-sites no-patches
      set poacher-memory no-patches
      set poacher-goal patch-here
      set state "journey-to-crime"
    ]
  ]
end

to build-camps
  set-default-shape camps "default"
  if camp-placement = "random" [
    ask n-of num-camps patches with [inside? = TRUE and roughness = 1] [
      sprout-camps 1]
  ]
  if camp-placement = "fixed" [
    let camp-coordinates (patch-set patch 0 0 patch (min-pxcor + 1 + random 10) (min-pycor + 1 + random 10) patch (min-pxcor + 1 + random 10) (max-pycor - 1 - random 10) patch (max-pxcor - 1 - random 10) (max-pycor - 1 - random 10) patch (max-pxcor - 1 - random 10) (min-pycor + 1 + random 10))
    ask n-of num-camps camp-coordinates [
      sprout-camps 1]
  ]
end

to distribute-camps
  let camps-too-close camps with [any? other camps in-radius 10]
  if any? camps-too-close [
    ask one-of camps-too-close [
      let available-patches patches with [inside? = TRUE and not any? other camps in-radius 10]
      ifelse any? available-patches [
        move-to one-of available-patches
        distribute-camps
      ]
      [move-to one-of patches with [inside? = TRUE and not any? other turtles-here]]
    ]
  ]
  ask camps [
    ask patches in-radius 4.5 [
      set resources 0
      color-resources]
    set size 2
    set color red]
end

to click-camps
  if mouse-down? [
    ask patch mouse-xcor mouse-ycor [
      sprout-camps 1]
    stop]
end

to release-rangers
  set-default-shape rangers "person"
  repeat num-rangers [
    ask one-of camps [
      hatch-rangers 1 [
        set color red
        set size 2
        set patrol-memory no-patches
        set patrol-time 0
        set risky-areas no-patches
        set safe-areas no-patches
        set rhino-sightings no-patches
        ifelse coordinated = false [set off-duty-time (patrol-length * 2) + random 100] [set off-duty-time patrol-length * 2]
        set ranger-goal patch-here
        set state "patrolling"
        ifelse random 2 = 0 [
          set direction 1]
        [set direction -1]
        face one-of neighbors4
      ]
    ]
  ]
end

to-report ticks-to-stay-on-patch [p]
  report roughness - 1
end

to rhino-goal-check
  ifelse ticks-wait > 0 [
    set ticks-wait ticks-wait - 1]
  [ifelse rhino-goal = patch-here [
    rhino-decision-making]
  [ifelse member? rhino-goal neighbors [
    move-to rhino-goal]
  [rhino-movement]
  ]
  if (roughness > 1) [set ticks-wait ticks-to-stay-on-patch patch-here]
  ]
end

to rhino-movement
  let surroundings neighbors with [inside? = TRUE]
  let max-goal-dist distance rhino-goal

  ask surroundings [
    let goal-dist (max-goal-dist - distance [rhino-goal] of myself) * goal-weight
    let estimated-roughness ((max-roughness - roughness) / max-roughness) * roughness-weight
    let estimated-resources resources * resources-weight
    set patch-attractiveness (goal-dist + estimated-resources + estimated-roughness + rhino-dist) / (rhino-weight + goal-weight)
    if patch-attractiveness < 0 [
      set patch-attractiveness 0]
  ]
  ask surroundings with [rhino-territory != myself and rhino-territory != nobody] [
    set patch-attractiveness patch-attractiveness / 2]

  move-to rnd:weighted-one-of surroundings [patch-attractiveness]
end

to rhino-decision-making
  let surroundings patches in-radius 2.5 with [inside? = TRUE and not member? self [rhino-memory] of myself]

  ask surroundings [
    let estimated-roughness ((max-roughness - roughness) / max-roughness) * roughness-weight
    let estimated-resources resources * resources-weight
    set patch-attractiveness (estimated-resources + estimated-roughness + rhino-dist) / rhino-weight
  ]
  ask surroundings with [rhino-territory != myself and rhino-territory != nobody] [
    set patch-attractiveness patch-attractiveness / 10]

  set rhino-goal rnd:weighted-one-of surroundings [patch-attractiveness]
  ifelse member? rhino-goal neighbors [
    move-to rhino-goal]
  [rhino-movement]
end

to-report rhino-dist
  ifelse any? other rhinos [
    let max-rhino-dist distance min-one-of other rhinos [distance myself]
    ifelse max-rhino-dist = 0 [
      report 0]
    [report (distance min-one-of other rhinos [distance myself] / max-rhino-dist) * rhino-avoid-weight]
  ]
  [report 0]
end

to update-rhino-memory
  set rhino-memory lput patch-here rhino-memory
  set rhino-memory remove-duplicates rhino-memory
  if length rhino-memory > 3 [
    set rhino-memory but-first rhino-memory]
end

to rhino-foraging-and-home-range
  ask patch-here [
    set resources (resources * ((100 - forage-amount) / 100))
    set countdown sprout-delay-time
    set rhino-territory myself
    if visualization = "rhino_home-ranges" [
      set pcolor [color] of myself + 2]
    if random-float 1 < 0.5 [
      set recent-rhino-activity rhino-activity-decay + random 500]
  ]
end

to update-home-range
  if visualization = "rhino_home-ranges" [
    set pcolor [pcolor] of one-of neighbors with [inside? = TRUE]
  ]
end

to poacher-goal-check
  pen-down
  ifelse ticks-wait > 0 [
    set ticks-wait ticks-wait - 1]
  [
    ifelse state = "journey-to-crime" [poacher-journey-to-crime]
    [poacher-journey-after-crime]
    if time >= poacher-time [
      set state "journey-after-crime"]
    if roughness > 1 [
      set ticks-wait ticks-to-stay-on-patch patch-here]
  ]
  ask patch-here [
    if random-float 1 < 0.5 [
      set poacher-signs human-signs-decay]
  ]
  set time time + 1
end

to poacher-journey-after-crime
  let closest-exit min-one-of patches with [inside? = FALSE] [distance myself]
  set poacher-goal closest-exit
  ifelse distance poacher-goal <= 1 [
    move-to poacher-goal]
  [face poacher-goal
    forward 1]
end

to poacher-journey-to-crime
  let target one-of rhinos in-radius poacher-vision
  ifelse target != nobody [
    poacher-kills-rhino]
  [ifelse poacher-goal = patch-here [
    poacher-decision-making]
  [ifelse member? poacher-goal neighbors [
    move-to poacher-goal]
  [poacher-movement]
  ]
  ]
  set poacher-memory (patch-set poacher-memory patch-here)

  if recent-rhino-activity > 0 and ranger-signs = 0 [
    set good-sites (patch-set good-sites patch-here)
    if (member? patch-here [good-sites] of self) and (member? patch-here [failure-sites] of self) [
      set failure-sites failure-sites with [[patch-here] of myself != self]]
  ]

  if ranger-signs > 0 [
    set failure-sites (patch-set failure-sites patch-here)
    if (member? patch-here [failure-sites] of self) and (member? patch-here [good-sites] of self) [
      set good-sites good-sites with [[patch-here] of myself != self]]
  ]
end

to poacher-movement
  let nearby-rangers (turtle-set rangers camps)
  if any? nearby-rangers in-radius poacher-vision [
    set failure-sites (patch-set failure-sites patches in-radius poacher-vision)]

  let max-goal-dist distance poacher-goal

  ask neighbors with [inside? = TRUE] [
    let goal-dist (max-goal-dist - distance [poacher-goal] of myself) * goal-weight
    let rhino-signs (recent-rhino-activity / (rhino-activity-decay * 2)) * hunt-rhino-weight
    let nearby-ranger-signs ((human-signs-decay - ranger-signs) / human-signs-decay) * ranger-avoid-weight
    let estimated-roughness ((max-roughness - roughness) / max-roughness) * roughness-weight
    let estimated-resources resources * resources-weight
    set patch-attractiveness (goal-dist + estimated-resources + estimated-roughness + ranger-dist + rhino-signs + nearby-ranger-signs) / (poacher-weight + goal-weight)
    if patch-attractiveness < 0 [
      set patch-attractiveness 0]
  ]
  let surroundings neighbors with [inside? = TRUE and not member? self [poacher-memory] of myself]
  ifelse any? surroundings [
    move-to rnd:weighted-one-of surroundings [patch-attractiveness]]
  [move-to rnd:weighted-one-of neighbors with [inside? = TRUE] [patch-attractiveness]]
end

to poacher-decision-making
  let nearby-rangers (turtle-set rangers camps)
  if any? nearby-rangers in-radius poacher-vision [
    set failure-sites (patch-set failure-sites poacher-memory)
    set state "journey-after-crime"]

  let surroundings patches in-radius poacher-vision with [inside? = TRUE]
  ask surroundings [
    let rhino-signs (recent-rhino-activity / (rhino-activity-decay * 2)) * hunt-rhino-weight
    let nearby-ranger-signs ((human-signs-decay - ranger-signs) / human-signs-decay) * ranger-avoid-weight
    let estimated-roughness ((max-roughness - roughness) / max-roughness) * roughness-weight
    let estimated-resources resources * resources-weight
    set patch-attractiveness (ranger-dist + rhino-signs + nearby-ranger-signs + estimated-resources + estimated-roughness) / poacher-weight
    if patch-attractiveness < 0 [
      set patch-attractiveness 0]
  ]
  ask surroundings with [member? self [poacher-memory] of myself] [
    set patch-attractiveness patch-attractiveness / 10
  ]
  set poacher-goal rnd:weighted-one-of surroundings [patch-attractiveness]
  ifelse member? poacher-goal neighbors [
    move-to poacher-goal]
  [poacher-movement]
end

to-report ranger-dist
  let nearby-rangers (turtle-set rangers camps)
  ifelse any? nearby-rangers [
    let max-ranger-dist distance min-one-of nearby-rangers [distance myself]
    ifelse max-ranger-dist != 0 [
      report (distance min-one-of nearby-rangers [distance myself] / max-ranger-dist) * ranger-avoid-weight]
    [report 0]
  ]
  [report 0]
end

to-report other-patrol-dist
  let nearby-rangers (turtle-set other rangers camps)
  ifelse any? nearby-rangers [
    let max-ranger-dist distance min-one-of nearby-rangers [distance myself]
    ifelse max-ranger-dist != 0 [
      report (distance min-one-of nearby-rangers [distance myself] / max-ranger-dist) * ranger-avoid-weight]
    [report 0]
  ]
  [report 0]
end

to poacher-kills-rhino
  let target one-of rhinos in-radius 1.5
  move-to target
  set rhinos-killed rhinos-killed + 1
  set total-killed total-killed + 1
  ask target [
    if herd-size >= 1 [set herd-size herd-size - 1]
    if herd-size = 0 [die]
  ]
  set poacher-goal patch-here
  set success-sites (patch-set success-sites patch-here)
  set poacher-memory no-patches
  set state "journey-after-crime"
  ask patch-here [
    set poacher-signs poacher-signs + carcass-decay
  ]
end

to poacher-laylow
  pen-up
  if poacher-goal = patch-here and state = "journey-after-crime" [
    set laylow laylow - 1]
  if (laylow = 0) [
    poacher-plan-new-trip
  ]
end

to poacher-plan-new-trip
  let good-options (patch-set success-sites good-sites)
  ifelse good-options = nobody or count good-options = 0 [
    move-to one-of patches with [inside? = FALSE and not member? self [failure-sites] of myself]
  ]
  [let new-trip-weight success-weight + hunt-rhino-weight + ranger-avoid-weight
    ask good-options [
      let recent-rhino-kill (poacher-signs / carcass-decay) * success-weight
      let detected-rhino-signs (recent-rhino-activity / (rhino-activity-decay * 2)) * hunt-rhino-weight
      let detected-ranger-signs ((human-signs-decay - ranger-signs) / human-signs-decay) * ranger-avoid-weight
      set patch-attractiveness (recent-rhino-kill + detected-rhino-signs + detected-ranger-signs) / new-trip-weight
      if patch-attractiveness < 0 [
        set patch-attractiveness 0]
    ]
    let best-option max-one-of good-options [patch-attractiveness]
    ifelse random-float 1 < [patch-attractiveness] of best-option [
      move-to rnd:weighted-one-of good-options [patch-attractiveness] move-to one-of patches in-radius 1.5
      move-to min-one-of patches with [inside? = FALSE] [distance myself]]
    [move-to one-of patches with [inside? = FALSE]]
  ]
  set state "journey-to-crime"
  set laylow (poacher-time * 2) + random 100
  set time 0
  set poacher-memory no-patches
  set poacher-goal patch-here
end

to ranger-goal-check
  pen-down
  ifelse ticks-wait > 0 [
    set ticks-wait ticks-wait - 1]
  [
    let target one-of poachers in-radius ranger-vision with [inside? = TRUE]
    ifelse target != nobody [
      rangers-catch-poachers]
    [if state = "patrolling" [
      ifelse patrol-type = "standard-patrol" [
        ranger-patrol]
      [ranger-fence-patrol]
    ]
    if state = "follow-up" [
      ranger-follow-up]
    if state = "back-to-camp" [
      ranger-to-camp]
    if patrol-time >= patrol-length [
      set state "back-to-camp"
    ]
    if roughness > 1 [
      set ticks-wait ticks-to-stay-on-patch patch-here]
    ]
  ]

  ask patch-here [
    if random-float 1 < 0.5 [
      set ranger-signs human-signs-decay]
  ]
  if any? poachers in-radius ranger-vision with [inside? = TRUE] [
    rangers-catch-poachers]

  set patrol-time patrol-time + 1
  set patrol-memory (patch-set patrol-memory patch-here)

  if poacher-signs > 0 [
    set risky-areas (patch-set risky-areas patch-here)
    if (member? patch-here [risky-areas] of self) and (member? patch-here [safe-areas] of self) [
      set safe-areas safe-areas with [[patch-here] of myself != self]]
  ]
  let new-rhino-sighting any? rhinos-on neighbors
  if new-rhino-sighting = TRUE [
    set rhino-sightings (patch-set rhino-sightings neighbors)
  ]
  if poacher-signs = 0 [
    set safe-areas (patch-set safe-areas patch-here)
    if (member? patch-here [safe-areas] of self) and (member? patch-here [risky-areas] of self) [
      set risky-areas risky-areas with [[patch-here] of myself != self]]
  ]
end

to ranger-to-camp
  let closest-border min-one-of patches with [inside? = FALSE] [distance myself]
  let closest-camp min-one-of camps [distance myself]
  ifelse distance closest-border < distance closest-camp [set ranger-goal closest-border]
  [set ranger-goal closest-camp]
  ifelse distance ranger-goal <= 1 [
    move-to ranger-goal]
  [face ranger-goal
    forward 1]
end

to ranger-patrol
  ifelse ranger-goal = patch-here [
    ranger-decision-making]
  [ifelse member? ranger-goal neighbors [
    move-to ranger-goal]
  [ranger-movement]
  ]
end

to rangers-catch-poachers
  let suspect one-of poachers in-radius ranger-vision with [inside? = TRUE]
  move-to suspect
  ask suspect [die]
  set risky-areas (patch-set risky-areas patch-here)
  set ranger-goal patch-here
  set state "back-to-camp"
  ask patch-here [
    set ranger-signs ranger-signs + 500]
  pen-up
  move-to min-one-of camps [distance myself]
end

to ranger-movement
  if any? poachers in-radius ranger-vision with [inside? = TRUE] [
    set risky-areas (patch-set risky-areas patrol-memory)]
  let max-goal-dist distance ranger-goal

  ask neighbors with [inside? = TRUE] [
    let goal-dist (max-goal-dist - distance [ranger-goal] of myself) * goal-weight
    let rhino-signs (recent-rhino-activity / (rhino-activity-decay * 2)) * search-rhino-weight
    let nearby-poacher-signs catch-poacher-weight - ((human-signs-decay - poacher-signs) / human-signs-decay) * catch-poacher-weight
    let estimated-roughness ((max-roughness - roughness) / max-roughness) * roughness-weight
    set patch-attractiveness (goal-dist + estimated-roughness + other-patrol-dist + rhino-signs + nearby-poacher-signs) / (ranger-weight + goal-weight)
    if patch-attractiveness < 0 [
      set patch-attractiveness 0]
  ]
  let surroundings neighbors with [not member? self [patrol-memory] of myself]
  ifelse any? surroundings [
    move-to rnd:weighted-one-of surroundings [patch-attractiveness]]
  [move-to rnd:weighted-one-of neighbors [patch-attractiveness]]
end

to ranger-decision-making
  if any? poachers in-radius ranger-vision [
    set risky-areas (patch-set risky-areas patrol-memory)]
  let surroundings patches in-radius ranger-vision with [not any? camps-here and inside? = TRUE]
  ask surroundings [
    let rhino-signs (recent-rhino-activity / (rhino-activity-decay * 2)) * search-rhino-weight
    let nearby-poacher-signs catch-poacher-weight - ((human-signs-decay - poacher-signs) / human-signs-decay) * catch-poacher-weight
    let estimated-roughness ((max-roughness - roughness) / max-roughness) * roughness-weight
    set patch-attractiveness (other-patrol-dist + rhino-signs + nearby-poacher-signs + estimated-roughness) / ranger-weight
    if patch-attractiveness < 0 [
      set patch-attractiveness 0]
  ]
  ask surroundings with [member? self [patrol-memory] of myself] [
    set patch-attractiveness patch-attractiveness / 10
  ]
  set ranger-goal rnd:weighted-one-of surroundings [patch-attractiveness]
  ifelse member? ranger-goal neighbors [
    move-to ranger-goal]
  [ranger-movement]
end

to-report fence? [angle]
  report black = [pcolor] of patch-right-and-ahead angle 1
end

to ranger-fence-patrol
  if not fence? (90 * direction) and fence? (135 * direction) [rt 90 * direction]
  while [fence? 0] [lt 90 * direction]
  fd 1
  if poacher-signs > 0 [
    ranger-follow-up
    set patrol-time 0
    set state "follow-up"]
end

to ranger-follow-up
  let poacher-spoor neighbors with [poacher-signs >= 1 and inside? = TRUE]
  ifelse any? poacher-spoor with [not member? self [patrol-memory] of myself] [
    move-to max-one-of poacher-spoor [poacher-signs]]
  [ranger-movement]
end

to ranger-end-patrol
  pen-up
  if state = "back-to-camp" and ranger-goal = patch-here or ranger-goal = one-of camps in-radius 1 [
    set off-duty-time off-duty-time - 1]
  if off-duty-time = 0 [
    ranger-new-patrol]
end

to ranger-new-patrol
  let options rhino-sightings with [not member? self [safe-areas] of myself]
  let good-options (patch-set options risky-areas)
  ifelse good-options = nobody or count good-options = 0 [
    move-to one-of patches with [not member? self [safe-areas] of myself]
    ranger-start-location
  ]
  [let new-patrol-weight search-rhino-weight + catch-poacher-weight
    ask good-options [
      let detected-rhino-signs (recent-rhino-activity / (rhino-activity-decay * 2)) * search-rhino-weight
      let detected-poacher-signs ((human-signs-decay - poacher-signs) / human-signs-decay) * catch-poacher-weight
      set patch-attractiveness (detected-rhino-signs + detected-poacher-signs) / new-patrol-weight
      if patch-attractiveness < 0 [
        set patch-attractiveness 0]
    ]
    let best-option max-one-of good-options [patch-attractiveness]
    ifelse random-float 1 < [patch-attractiveness] of best-option [
      move-to rnd:weighted-one-of good-options [patch-attractiveness] move-to one-of patches in-radius 1.5
      ranger-start-location]
    [move-to one-of patches with [not member? self [safe-areas] of myself]
      ranger-start-location]
  ]
end

to ranger-start-location
  let closest-border min-one-of patches with [inside? = FALSE] [distance myself]
  let closest-camp min-one-of camps [distance myself]
  ifelse patrol-type = "fence-patrol" [
    move-to closest-border
    move-to one-of neighbors with [inside? = TRUE]]
  [ifelse distance closest-border < distance closest-camp [
    move-to closest-border]
  [move-to closest-camp]
  ]
  set patrol-time 0
  set patrol-memory no-patches
  ifelse coordinated = false [set off-duty-time (patrol-length * 2) + random 100] [set off-duty-time patrol-length * 2]
  set ranger-goal patch-here
  set state "patrolling"
  ifelse random 2 = 0 [
    set direction 1]
  [set direction -1]
  face one-of neighbors4
end

to update-activity-signs
  if recent-rhino-activity > 0 [set recent-rhino-activity recent-rhino-activity - 1]
  if ranger-signs > 0 [set ranger-signs ranger-signs - 1]
  if poacher-signs > 0 [set poacher-signs poacher-signs - 1]
end
"""
end
