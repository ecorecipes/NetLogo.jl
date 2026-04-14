# ── Rumor Mill ─────────────────────────────────────────────────────
# Source: modelingcommons #1476 (Uri Wilensky, 1997)
# Rumor spreading through a population via spatial proximity.
# Patches spread rumors to random neighbors each tick.

struct RumorMillModel <: AbstractBenchmarkModel end

model_name(::RumorMillModel) = "Rumor Mill"
n_ticks(::RumorMillModel) = 300
tracked_globals(::RumorMillModel) = ["clique"]
world_dims(::RumorMillModel) = (-50, 50, -50, 50)
topology(::RumorMillModel) = (true, true)

function setup_commands(::RumorMillModel)
    return "random-seed \$SEED setup true"
end

go_command(::RumorMillModel) = "go"

function netlogo_code(::RumorMillModel)
    return """
globals [
  color-mode
  clique
  previous-clique
]

patches-own [
  times-heard
  first-heard
  just-heard?
]

to setup [seed-one?]
  clear-all
  set color-mode 0
  set clique 0
  ask patches [
    set first-heard -1
    set times-heard 0
    set just-heard? false
    recolor
  ]
  ifelse seed-one?
    [ seed-one ]
    [ seed-random ]
  reset-ticks
end

to seed-one
  ask patch 0 0 [ hear-rumor 0 ]
end

to seed-random
  ask patches with [times-heard = 0] [
    if (random-float 100.0) < init-clique [ hear-rumor 0 ]
  ]
end

to go
  if all? patches [times-heard > 0] [ stop ]
  ask patches [
    if times-heard > 0 [ spread-rumor ]
  ]
  update
  tick
end

to spread-rumor
  let neighbor nobody
  ifelse eight-mode?
    [ set neighbor one-of neighbors ]
    [ set neighbor one-of neighbors4 ]
  ask neighbor [ set just-heard? true ]
end

to hear-rumor [when]
  if first-heard = -1 [
    set first-heard when
    set just-heard? true
  ]
  set times-heard times-heard + 1
  recolor
end

to update
  ask patches with [just-heard?] [
    set just-heard? false
    hear-rumor ticks
  ]
  set previous-clique clique
  set clique count patches with [times-heard > 0]
end

to recolor
  ifelse color-mode = 0
    [ recolor-normal ]
    [ ifelse color-mode = 1
      [ recolor-by-when-heard ]
      [ recolor-by-times-heard ] ]
end

to recolor-normal
  ifelse first-heard >= 0
    [ set pcolor red ]
    [ set pcolor blue ]
end

to recolor-by-when-heard
  ifelse first-heard = -1
    [ set pcolor black ]
    [ set pcolor scale-color yellow first-heard world-width 0 ]
end

to recolor-by-times-heard
  set pcolor scale-color green times-heard 0 world-width
end
"""
end
