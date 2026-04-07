# ── Language Borders model (CSS600 ClassModels) ─────────────────────────

struct LanguageBordersModel <: AbstractBenchmarkModel end

model_name(::LanguageBordersModel) = "Language Borders"
n_ticks(::LanguageBordersModel) = 100
tracked_globals(::LanguageBordersModel) = ["avg-language"]
world_dims(::LanguageBordersModel) = (-20, 20, 0, 40)
topology(::LanguageBordersModel) = (false, false)

function netlogo_code(::LanguageBordersModel)
"""
globals [randomSeed Initial-Percent-Green Rounding-Precision Rounding? Ability-for-Languages? normal? poisson? normal-mean poisson-mean avg-language]

patches-own [
  Language
  Neighbor-av
  ability
  temp-ability
]

to setup
  clear-all
  set Initial-Percent-Green 0.5
  set Rounding-Precision 4
  set Rounding? false
  set Ability-for-Languages? true
  set normal? true
  set poisson? false
  set normal-mean 2
  set poisson-mean 4
  ask patches [
    ifelse pycor > (Initial-Percent-Green * 40)
    [ set pcolor blue ]
    [ set pcolor green ]
    ifelse pcolor = blue
    [ set Language 105 ]
    [ set Language 55 ]
    if Ability-for-Languages?
    [ distribute-ability ]
  ]
  set avg-language mean [language] of patches
  reset-ticks
end

to go
  ask patches [
    Check-Neighbors
    Update-Color
  ]
  set avg-language mean [language] of patches
  tick
end

to distribute-ability
  if normal? [ set temp-ability ( random-normal normal-mean 1 ) ]
  if poisson? [ set temp-ability ( random-poisson poisson-mean ) ]
  if temp-ability < 0 [ set temp-ability 0 ]
  set ability ( ( round temp-ability ) )
end

to Check-Neighbors
  set neighbor-av neighbor-average
  ifelse Rounding?
    [ set Language precision my-average Rounding-Precision ]
    [ check-AFL ]
end

to check-AFL
  ifelse Ability-for-Languages?
  [ set Language precision my-average ability ]
  [ set Language my-average ]
end

to-report neighbor-average
  report ( sum [ Language ] of neighbors ) / ( count neighbors )
end

to-report my-average
  report ( neighbor-av + Language ) / 2
end

to Update-Color
  set pcolor precision Language 0
  ifelse ( pcolor = 100 or pcolor = 90 or pcolor = 80 or pcolor = 70 or pcolor = 60 )
    [ set pcolor ( pcolor + 2.5 ) ]
    [ set pcolor ( pcolor + 0 ) ]
  ifelse ( pcolor = 101 or pcolor = 91 or pcolor = 81 or pcolor = 71 or pcolor = 61 )
    [ set pcolor ( pcolor + 2 ) ]
    [ set pcolor ( pcolor + 0 ) ]
  ifelse ( pcolor = 102 or pcolor = 92 or pcolor = 82 or pcolor = 72 or pcolor = 62 )
    [ set pcolor ( pcolor + 1.5 ) ]
    [ set pcolor ( pcolor + 0 ) ]
  ifelse ( pcolor = 99 or pcolor = 89 or pcolor = 79 or pcolor = 69 or pcolor = 59 )
    [ set pcolor ( pcolor - 1.5 ) ]
    [ set pcolor ( pcolor + 0 ) ]
  ifelse ( pcolor = 98 or pcolor = 88 or pcolor = 78 or pcolor = 68 or pcolor = 58 )
    [ set pcolor ( pcolor - 1 ) ]
    [ set pcolor ( pcolor + 0 ) ]
end
"""
end
