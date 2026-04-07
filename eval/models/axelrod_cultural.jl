# ── Axelrod Cultural Dissemination ───────────────────────────────────
# Source: modelingcommons #6836 (Eleonora Barelli, 2021)
# Reference: Axelrod 1997 "The dissemination of culture"
# Modifications:
#   - Added F, q, radius, world-size to globals (originally InputBox/Slider widgets)
#   - Defaults: F=3, q=5, radius=1, world-size=10 (set in setup)
#   - Removed resize-world (incompatible with NetLogo.jl: requires min < 0)
#   - Removed set-patch-size (display-only, not needed)
#   - Removed do-plots calls (plot procedures not needed for harness)
#   - Removed clear-all-plots (not available headlessly)
#   - Rewrote overlap_between using indexed loop (multi-list foreach lambda
#     [[a b] -> ...] is not supported by the NetLogo.jl parser)
#   - Used count patches for number_of_agents instead of world-size^2

struct AxelrodCulturalModel <: AbstractBenchmarkModel end

model_name(::AxelrodCulturalModel) = "AxelrodCultural"
n_ticks(::AxelrodCulturalModel) = 200
tracked_globals(::AxelrodCulturalModel) = ["number_of_cultures", "number_of_active_agents"]
world_dims(::AxelrodCulturalModel) = (-4, 5, -4, 5)

function netlogo_code(::AxelrodCulturalModel)
"""
globals [
  F
  q
  radius
  world-size
  time
  number_of_agents
  cult_max
  number_of_active_agents
  number_of_cultures
  number_of_cultural_regions
  component-size
  giant-component-size
]

turtles-own [
  culture
  explored?
]

to setup
  clear-all
  set F 3
  set q 5
  set radius 1
  set world-size 10
  ask patches [set pcolor 34]
  set number_of_agents count patches
  set giant-component-size 0
  set number_of_cultural_regions 0
  setup-turtles
  reset-ticks
  set time 0
end

to setup-turtles
  set-default-shape turtles "person"
  create-turtles number_of_agents [
    set size 0.9
    while [any? other turtles-here] [ move-to one-of patches ]
  ]
  setup-culture-max
  setup-agent-culture
  count-cultures
end

to setup-culture-max
  set cult_max (q ^ F - 1)
end

to setup-agent-culture
  ask turtles [
    set culture []
    repeat F [
      set culture lput random q culture
    ]
    setup-agent-culture-color
  ]
end

to setup-agent-culture-color
  let i 1
  let suma 0
  repeat F [
    set suma suma + item (i - 1) culture * q ^ (F - i)
    set i i + 1
  ]
  let Cult_base_q suma
  set color (9.9 * Cult_base_q / Cult_max) + 100
end

to go
  clear-links
  ask turtles [setup-agent-culture-color]
  tick
  set time time + 1
  set number_of_active_agents 0
  ask turtles [cultural-interaction]
  count-cultures
  if number_of_active_agents = 0 [stop]
end

to cultural-interaction
  let number_of_possible_neighbors count other turtles in-radius radius with [(0 < overlap_between self myself) and (overlap_between self myself < F)]
  if number_of_possible_neighbors > 0 [
    set number_of_active_agents number_of_active_agents + 1
    let neighbor_turtle one-of other turtles in-radius radius
    let target_turtle self
    culturally_interacting target_turtle neighbor_turtle
  ]
end

to-report overlap_between [target_turtle neighbor_turtle]
  let suma 0
  let tc [culture] of target_turtle
  let nc [culture] of neighbor_turtle
  let i 0
  repeat F [
    if item i tc = item i nc [ set suma suma + 1 ]
    set i i + 1
  ]
  report suma
end

to culturally_interacting [target_turtle neighbor_turtle]
  let overlap overlap_between target_turtle neighbor_turtle
  if (0 < overlap and overlap < F) [
    let prob_interaction (overlap / F)
    if random-float 1.0 < prob_interaction [
      let trait random F
      let trait_selected? false
      while [not trait_selected?] [
        ifelse (item trait [culture] of target_turtle = item trait [culture] of neighbor_turtle)
        [
          set trait ((trait + 1) mod F)
        ]
        [
          set trait_selected? true
        ]
      ]
      let new_cultural_value (item trait [culture] of neighbor_turtle)
      set culture replace-item trait culture new_cultural_value
      setup-agent-culture-color
    ]
  ]
end

to explore
  if explored? [ stop ]
  set explored? true
  set component-size component-size + 1
  ask link-neighbors [ explore ]
end

to creates-links-with-same-cultural-neighbors-in-neighborhood-of-radio-radius
  let neighborhood other turtles in-radius radius
  ask neighborhood [
    if overlap_between self myself = F
    [
      let color_for_the_link color
      create-link-with myself [set color color_for_the_link]
    ]
  ]
end

to count-cultures
  let list_of_cultures []
  ask turtles [
    set list_of_cultures lput culture list_of_cultures
  ]
  set list_of_cultures remove-duplicates list_of_cultures
  set number_of_cultures length list_of_cultures
end

to find-all-components
  set number_of_cultural_regions 0
  ask turtles [ set explored? false]
  loop
  [
    let starting_turtle one-of turtles with [ not explored? ]
    if starting_turtle = nobody [ stop ]
    set component-size 0
    ask starting_turtle [
      explore
      set number_of_cultural_regions number_of_cultural_regions + 1
    ]
    if component-size > giant-component-size [
      set giant-component-size component-size
    ]
  ]
end
"""
end
