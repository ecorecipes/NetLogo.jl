# ── Sleuthmodel v22 (Politics of LandUse / GIS) ─────────────────────

struct SleuthModel <: AbstractBenchmarkModel end

model_name(::SleuthModel) = "Sleuth LandUse"
n_ticks(::SleuthModel) = 50
tracked_globals(::SleuthModel) = ["urbantotal", "purbantotal", "concentration"]
world_dims(::SleuthModel) = (-376, 376, -376, 376)
topology(::SleuthModel) = (true, true)

const SLEUTH_DIR = "/Users/username/Projects/netlogo/ClassModels/OtherClasses/Politics_of_LandUse"

function netlogo_code(::SleuthModel)
    urban_path = joinpath(SLEUTH_DIR, "urbandclr3.asc")
    county_path = joinpath(SLEUTH_DIR, "countyls.asc")
    excluded_path = joinpath(SLEUTH_DIR, "excludedlr.asc")
    road_path = joinpath(SLEUTH_DIR, "rasterroad.asc")
"""
extensions [ gis ]

globals [
  randomSeed
  capxcor capycor
  newspreadcount newspreadx newspready
  urbancenter rgvalue roadgrowthx roadgrowthy
  maxsearchindex roadaheadx roadaheady roadaheaddist
  roadgrowthtaken moveuproad roadmoves
  newspreadcountroad
  urbantotal ruraltotal purbantotal
  concentration taxglobal
  Lobby Dispersion newspread spread rounds roadgravity
  urban1 nurban1 purban1 tax1
  urban2 nurban2 purban2 tax2
  urban10 nurban10 purban10 tax10
  urban12 nurban12 purban12 tax12
  urban14 nurban14 purban14 tax14
  urban18 nurban18 purban18 tax18
  urban20 nurban20 purban20 tax20
  urban24 nurban24 purban24 tax24
  urban26 nurban26 purban26 tax26
  urban28 nurban28 purban28 tax28
  urban29 nurban29 purban29 tax29
  urban32 nurban32 purban32 tax32
  urban35 nurban35 purban35 tax35
  urban36 nurban36 purban36 tax36
  urban37 nurban37 purban37 tax37
  urban40 nurban40 purban40 tax40
  urban41 nurban41 purban41 tax41
  urban42 nurban42 purban42 tax42
  urban43 nurban43 purban43 tax43
  urban44 nurban44 purban44 tax44
  urban46 nurban46 purban46 tax46
  urban49 nurban49 purban49 tax49
  urban56 nurban56 purban56 tax56
]

turtles-own [roadahead]
patches-own [urban urbancount ruralcount county capital excluded available capdist isolated newcenter newcentergrowth tax DC potential road hasroad distancetoroad roadadjgrowth roadgrowthcenter]

to setup
  __clear-all-and-reset-ticks
  set Lobby 1.0
  set Dispersion 52
  set newspread 55
  set spread 26
  set rounds 50
  set roadgravity 19
  let tmp-ds gis:load-dataset "$(urban_path)"
  gis:set-world-envelope gis:envelope-of tmp-ds
  gis:apply-raster tmp-ds "urban"
  gis:apply-raster gis:load-dataset "$(county_path)" "county"
  gis:apply-raster gis:load-dataset "$(excluded_path)" "excluded"
  gis:apply-raster gis:load-dataset "$(road_path)" "road"
  calculate-capdist
  setroad
  draw-map
  determine-availability
  set-tax
  calculateglobals
end

to go
  if ticks >= rounds [ stop ]
  spontaneous
  edge
  tick
  draw-map
  determine-availability
  set-tax
  calculateglobals
end

to setroad
  ask patches [
    set hasroad 0
    if road = 1 [
      set hasroad 1]]
end

to calculate-capdist
  set capxcor mean [pxcor] of patches with [county = 43]
  set capycor mean [pycor] of patches with [county = 43]
  ask patches [
    set capdist ((pxcor - capxcor) ^ 2 + (pycor - capycor) ^ 2) ^ 0.5]
end

to determine-availability
  ask patches [
    if county > 0 and county < 57 [
      set DC 1]
    if county > 0 and county < 57 and urban = 1 [
      set available 1]
    if excluded = 1 [
      set available 0]
    if urban = 2 [
      set available 0]
  ]
end

to draw-map
  ask patches [
    if urban = 1 [ set pcolor green ]
    if urban = 2 [ set pcolor red ]
  ]
end

to set-tax
  ask patches with [DC = 1] [
    set urbancount 0
    set potential 1
    if urban = 2 [ set urbancount 1]]
  ask patches [
    set ruralcount 0
    set potential 1
    if urban = 1 and available = 1 [ set ruralcount 1]]

  set urban1 sum [urbancount] of patches with [county = 1]
  set nurban1 sum [ruralcount] of patches with [county = 1]
  set purban1 (urban1 / (urban1 + nurban1))
  ask patches with [county = 1] [ set tax ( (purban1) * Lobby * 100)]
  set tax1 ((purban1) * Lobby * 100)

  set urban2 sum [urbancount] of patches with [county = 2]
  set nurban2 sum [ruralcount] of patches with [county = 2]
  set purban2 (urban2 / (urban2 + nurban2))
  ask patches with [county = 2] [ set tax ( (purban2) * Lobby * 100)]
  set tax2 ((purban2) * Lobby * 100)

  set urban10 sum [urbancount] of patches with [county = 10]
  set nurban10 sum [ruralcount] of patches with [county = 10]
  set purban10 (urban10 / (urban10 + nurban10))
  ask patches with [county = 10] [ set tax ( (purban10) * Lobby * 100)]
  set tax10 ((purban10) * Lobby * 100)

  set urban12 sum [urbancount] of patches with [county = 12]
  set nurban12 sum [ruralcount] of patches with [county = 12]
  set purban12 (urban12 / (urban12 + nurban12))
  ask patches with [county = 12] [ set tax ( (purban12) * Lobby * 100)]
  set tax12 ((purban12) * Lobby * 100)

  set urban14 sum [urbancount] of patches with [county = 14]
  set nurban14 sum [ruralcount] of patches with [county = 14]
  set purban14 (urban14 / (urban14 + nurban14))
  ask patches with [county = 14] [ set tax ( (purban14) * Lobby * 100)]
  set tax14 ((purban14) * Lobby * 100)

  set urban18 sum [urbancount] of patches with [county = 18]
  set nurban18 sum [ruralcount] of patches with [county = 18]
  set purban18 (urban18 / (urban18 + nurban18))
  ask patches with [county = 18] [ set tax ( (purban18) * Lobby * 100)]
  set tax18 ((purban18) * Lobby * 100)

  set urban20 sum [urbancount] of patches with [county = 20]
  set nurban20 sum [ruralcount] of patches with [county = 20]
  set purban20 (urban20 / (urban20 + nurban20))
  ask patches with [county = 20] [ set tax ( (purban20) * Lobby * 100)]
  set tax20 ((purban20) * Lobby * 100)

  set urban24 sum [urbancount] of patches with [county = 24]
  set nurban24 sum [ruralcount] of patches with [county = 24]
  set purban24 (urban24 / (urban24 + nurban24))
  ask patches with [county = 24] [ set tax ( (purban24) * Lobby * 100)]
  set tax24 ((purban24) * Lobby * 100)

  set urban26 sum [urbancount] of patches with [county = 26]
  set nurban26 sum [ruralcount] of patches with [county = 26]
  set purban26 (urban26 / (urban26 + nurban26))
  ask patches with [county = 26] [ set tax ( (purban26) * Lobby * 100)]
  set tax26 ((purban26) * Lobby * 100)

  set urban28 sum [urbancount] of patches with [county = 28]
  set nurban28 sum [ruralcount] of patches with [county = 28]
  set purban28 (urban28 / (urban28 + nurban28))
  ask patches with [county = 28] [ set tax ( (purban28) * Lobby * 100)]
  set tax28 ((purban28) * Lobby * 100)

  set urban29 sum [urbancount] of patches with [county = 29]
  set nurban29 sum [ruralcount] of patches with [county = 29]
  set purban29 (urban29 / (urban29 + nurban29))
  ask patches with [county = 29] [ set tax ( (purban29) * Lobby * 100)]
  set tax29 ((purban29) * Lobby * 100)

  set urban32 sum [urbancount] of patches with [county = 32]
  set nurban32 sum [ruralcount] of patches with [county = 32]
  set purban32 (urban32 / (urban32 + nurban32))
  ask patches with [county = 32] [ set tax ( (purban32) * Lobby * 100)]
  set tax32 ((purban32) * Lobby * 100)

  set urban35 sum [urbancount] of patches with [county = 35]
  set nurban35 sum [ruralcount] of patches with [county = 35]
  set purban35 (urban35 / (urban35 + nurban35))
  ask patches with [county = 35] [ set tax ( (purban35) * Lobby * 100)]
  set tax35 ((purban35) * Lobby * 100)

  set urban36 sum [urbancount] of patches with [county = 36]
  set nurban36 sum [ruralcount] of patches with [county = 36]
  set purban36 (urban36 / (urban36 + nurban36))
  ask patches with [county = 36] [ set tax ( (purban36) * Lobby * 100)]
  set tax36 ((purban36) * Lobby * 100)

  set urban37 sum [urbancount] of patches with [county = 37]
  set nurban37 sum [ruralcount] of patches with [county = 37]
  set purban37 (urban37 / (urban37 + nurban37))
  ask patches with [county = 37] [ set tax ( (purban37) * Lobby * 100)]
  set tax37 ((purban37) * Lobby * 100)

  set urban40 sum [urbancount] of patches with [county = 40]
  set nurban40 sum [ruralcount] of patches with [county = 40]
  set purban40 (urban40 / (urban40 + nurban40))
  ask patches with [county = 40] [ set tax ( (purban40) * Lobby * 100)]
  set tax40 ((purban40) * Lobby * 100)

  set urban41 sum [urbancount] of patches with [county = 41]
  set nurban41 sum [ruralcount] of patches with [county = 41]
  set purban41 (urban41 / (urban41 + nurban41))
  ask patches with [county = 41] [ set tax ( (purban41) * Lobby * 100)]
  set tax41 ((purban41) * Lobby * 100)

  set urban42 sum [urbancount] of patches with [county = 42]
  set nurban42 sum [ruralcount] of patches with [county = 42]
  set purban42 (urban42 / (urban42 + nurban42))
  ask patches with [county = 42] [ set tax ( (purban42) * Lobby * 100)]
  set tax42 ((purban42) * Lobby * 100)

  set urban43 sum [urbancount] of patches with [county = 43]
  set nurban43 sum [ruralcount] of patches with [county = 43]
  set purban43 (urban43 / (urban43 + nurban43))
  ask patches with [county = 43] [ set tax ( (purban43) * Lobby * 100)]
  set tax43 ((purban43) * Lobby * 100)

  set urban44 sum [urbancount] of patches with [county = 44]
  set nurban44 sum [ruralcount] of patches with [county = 44]
  set purban44 (urban44 / (urban44 + nurban44))
  ask patches with [county = 44] [ set tax ( (purban44) * Lobby * 100)]
  set tax44 ((purban44) * Lobby * 100)

  set urban46 sum [urbancount] of patches with [county = 46]
  set nurban46 sum [ruralcount] of patches with [county = 46]
  set purban46 (urban46 / (urban46 + nurban46))
  ask patches with [county = 46] [ set tax ( (purban46) * Lobby * 100)]
  set tax46 ((purban46) * Lobby * 100)

  set urban49 sum [urbancount] of patches with [county = 49]
  set nurban49 sum [ruralcount] of patches with [county = 49]
  set purban49 (urban49 / (urban49 + nurban49))
  ask patches with [county = 49] [ set tax ( (purban49) * Lobby * 100)]
  set tax49 ((purban49) * Lobby * 100)

  set urban56 sum [urbancount] of patches with [county = 56]
  set nurban56 sum [ruralcount] of patches with [county = 56]
  set purban56 (urban56 / (urban56 + nurban56))
  ask patches with [county = 56] [ set tax ( (purban56) * Lobby * 100)]
  set tax56 ((purban56) * Lobby * 100)
end

to spontaneous
  set urbancenter 0
  set newspreadx random-pxcor
  set newspready random-pycor
  ask patches [ set newcenter 0]
  ask patches with [available = 1] [
    if urbancenter = 0 [
      set newspreadcount 0
      if pxcor = newspreadx and pycor = newspready [
        set urbancenter 1
        if random 100 < ((Dispersion * 5.3) * ((100 - tax) / 100)) [
          set newcenter 1
          set urban 2
          set available 0
        ]
      ]
      if newcenter = 1 [
        ask neighbors with [available = 1] [
          if random 100 < (newspread * ((100 - tax) / 100)) and newspreadcount < 2 [
            set urban 2
            set available 0
            set newspreadcount (newspreadcount + 1)
            set newcenter 1
          ]
        ]
      ]
    ]
  ]
end

to edge
  ask patches with [available = 1] [
    if sum [urbancount] of neighbors >= 3 [
      set isolated 0
      if random 100 < (spread * ((100 - tax) / 100)) [
        set urban 2
        set available 0
        set newcenter 1
      ]
    ]
  ]
end

to calculateglobals
  set urbantotal sum [urbancount] of patches with [DC = 1]
  set ruraltotal sum [ruralcount] of patches with [DC = 1]
  set purbantotal (urbantotal / (urbantotal + ruraltotal))
  set concentration ( (urban1 / urbantotal) ^ 2 + (urban2 / urbantotal) ^ 2 + (urban10 / urbantotal) ^ 2 + (urban12 / urbantotal) ^ 2 + (urban14 / urbantotal) ^ 2 + (urban18 / urbantotal) ^ 2 + (urban20 / urbantotal) ^ 2 + (urban24 / urbantotal) ^ 2 + (urban26 / urbantotal) ^ 2 + (urban28 / urbantotal) ^ 2 + (urban29 / urbantotal) ^ 2 + (urban32 / urbantotal) + (urban35 / urbantotal) ^ 2 + (urban36 / urbantotal) ^ 2 + (urban37 / urbantotal) ^ 2 + (urban40 / urbantotal) ^ 2 + (urban41 / urbantotal) ^ 2 + (urban42 / urbantotal) ^ 2 + (urban43 / urbantotal) ^ 2 + (urban44 / urbantotal) ^ 2 + (urban46 / urbantotal) ^ 2 + (urban49 / urbantotal) ^ 2 + (urban56 / urbantotal) ^ 2)
  set taxglobal mean [tax] of patches with [potential = 1]
end
"""
end
