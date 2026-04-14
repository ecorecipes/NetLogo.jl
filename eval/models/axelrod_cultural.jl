# ── Axelrod Cultural Dissemination ───────────────────────────────────
# Source: modelingcommons #6836 (Eleonora Barelli, 2021)
# Reference: Axelrod 1997 "The dissemination of culture"
# Modifications:
#   - Added F, q, radius, world-size to globals (originally InputBox/Slider widgets)
#   - Defaults: F=3, q=5, radius=1, world-size=10 (set in setup)
#   - Removed resize-world and fixed the harness world to the source model's
#     0..9 by 0..9 box topology
#   - Removed set-patch-size (display-only, not needed)
#   - Removed do-plots calls (plot procedures not needed for harness)
#   - Removed clear-all-plots (not available headlessly)
#   - Removed display-only color refreshes from the headless eval wrapper
#   - Replaced the turtle-based state with an equivalent patch-based wrapper
#     because this eval configuration has exactly one stationary agent per patch
#   - Used count patches for number_of_agents instead of world-size^2

struct AxelrodCulturalModel <: AbstractBenchmarkModel end

model_name(::AxelrodCulturalModel) = "AxelrodCultural"
n_ticks(::AxelrodCulturalModel) = 200
tracked_globals(::AxelrodCulturalModel) = ["number_of_cultures", "number_of_active_agents"]
world_dims(::AxelrodCulturalModel) = (0, 9, 0, 9)
topology(::AxelrodCulturalModel) = (false, false)

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
]

patches-own [
  trait0
  trait1
  trait2
  culture-id
]

to setup
  clear-all
  set F 3
  set q 5
  set radius 1
  set world-size 10
  ask patches [
    set pcolor 34
    set trait0 random q
    set trait1 random q
    set trait2 random q
    set culture-id ((trait0 * q * q) + (trait1 * q) + trait2)
  ]
  set number_of_agents count patches
  setup-culture-max
  count-cultures
  reset-ticks
  set time 0
end

to setup-culture-max
  set cult_max (q ^ F - 1)
end

to go
  tick
  set time time + 1
  set number_of_active_agents 0
  ask patches [
    let chosen_overlap 0
    let active_count 0
    let chosen_neighbor_trait0 0
    let chosen_neighbor_trait1 0
    let chosen_neighbor_trait2 0

    let north patch-at 0 1
    if north != nobody [
      let north_trait0 [trait0] of north
      let north_trait1 [trait1] of north
      let north_trait2 [trait2] of north
      let overlap 0
      if trait0 = north_trait0 [ set overlap overlap + 1 ]
      if trait1 = north_trait1 [ set overlap overlap + 1 ]
      if trait2 = north_trait2 [ set overlap overlap + 1 ]
      if (0 < overlap) and (overlap < F) [
        set active_count active_count + 1
        if random active_count = 0 [
          set chosen_overlap overlap
          set chosen_neighbor_trait0 north_trait0
          set chosen_neighbor_trait1 north_trait1
          set chosen_neighbor_trait2 north_trait2
        ]
      ]
    ]

    let east patch-at 1 0
    if east != nobody [
      let east_trait0 [trait0] of east
      let east_trait1 [trait1] of east
      let east_trait2 [trait2] of east
      let overlap 0
      if trait0 = east_trait0 [ set overlap overlap + 1 ]
      if trait1 = east_trait1 [ set overlap overlap + 1 ]
      if trait2 = east_trait2 [ set overlap overlap + 1 ]
      if (0 < overlap) and (overlap < F) [
        set active_count active_count + 1
        if random active_count = 0 [
          set chosen_overlap overlap
          set chosen_neighbor_trait0 east_trait0
          set chosen_neighbor_trait1 east_trait1
          set chosen_neighbor_trait2 east_trait2
        ]
      ]
    ]

    let south patch-at 0 -1
    if south != nobody [
      let south_trait0 [trait0] of south
      let south_trait1 [trait1] of south
      let south_trait2 [trait2] of south
      let overlap 0
      if trait0 = south_trait0 [ set overlap overlap + 1 ]
      if trait1 = south_trait1 [ set overlap overlap + 1 ]
      if trait2 = south_trait2 [ set overlap overlap + 1 ]
      if (0 < overlap) and (overlap < F) [
        set active_count active_count + 1
        if random active_count = 0 [
          set chosen_overlap overlap
          set chosen_neighbor_trait0 south_trait0
          set chosen_neighbor_trait1 south_trait1
          set chosen_neighbor_trait2 south_trait2
        ]
      ]
    ]

    let west patch-at -1 0
    if west != nobody [
      let west_trait0 [trait0] of west
      let west_trait1 [trait1] of west
      let west_trait2 [trait2] of west
      let overlap 0
      if trait0 = west_trait0 [ set overlap overlap + 1 ]
      if trait1 = west_trait1 [ set overlap overlap + 1 ]
      if trait2 = west_trait2 [ set overlap overlap + 1 ]
      if (0 < overlap) and (overlap < F) [
        set active_count active_count + 1
        if random active_count = 0 [
          set chosen_overlap overlap
          set chosen_neighbor_trait0 west_trait0
          set chosen_neighbor_trait1 west_trait1
          set chosen_neighbor_trait2 west_trait2
        ]
      ]
    ]

    if active_count > 0 [
      set number_of_active_agents number_of_active_agents + 1
      if random-float 1.0 < (chosen_overlap / F) [
        let chosen_trait -1
        let differing_count 0
        if trait0 != chosen_neighbor_trait0 [
          set differing_count differing_count + 1
          if random differing_count = 0 [ set chosen_trait 0 ]
        ]
        if trait1 != chosen_neighbor_trait1 [
          set differing_count differing_count + 1
          if random differing_count = 0 [ set chosen_trait 1 ]
        ]
        if trait2 != chosen_neighbor_trait2 [
          set differing_count differing_count + 1
          if random differing_count = 0 [ set chosen_trait 2 ]
        ]
        if chosen_trait = 0 [ set trait0 chosen_neighbor_trait0 ]
        if chosen_trait = 1 [ set trait1 chosen_neighbor_trait1 ]
        if chosen_trait = 2 [ set trait2 chosen_neighbor_trait2 ]
        if chosen_trait >= 0 [
          set culture-id ((trait0 * q * q) + (trait1 * q) + trait2)
        ]
      ]
    ]
  ]
  count-cultures
  if number_of_active_agents = 0 [stop]
end

to count-cultures
  let list_of_cultures remove-duplicates [culture-id] of patches
  set number_of_cultures length list_of_cultures
end
"""
end
