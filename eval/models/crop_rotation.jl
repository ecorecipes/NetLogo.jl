# ── Crop Rotation model (CSS645 ClassModels) ─────────────────────────

struct CropRotationModel <: AbstractBenchmarkModel end

model_name(::CropRotationModel) = "Crop Rotation"
n_ticks(::CropRotationModel) = 200
tracked_globals(::CropRotationModel) = ["count patches with [patch-current-crop != fallow]"]
world_dims(::CropRotationModel) = (0, 10, 0, 10)
topology(::CropRotationModel) = (false, false)

function netlogo_code(::CropRotationModel)
"""
extensions [table]

globals [
  init-nitrogen-mean init-nitrogen-sd verbose-output
  crops-list-all
  crops-table-nitrogen-requirements
  crops-table-weeds
  crops-table-disease
  crops-table-harvest-time
  crops-shapes
  crops-table-abbreviations

  crop-yield-totals
  crop-planting-totals
  crop-rule-totals

  rules-list-all

  beet
  buckwheat
  carrot
  cucurbit
  grass
  legume
  lettuce
  lily
  mustard
  nightshade
  rose
  cover
  fallow
]

patches-own [
  patch-id
  patch-nitrogen-level
  patch-crop-history
  patch-current-crop
  patch-available-crops
  patch-crop-harvest-week
  patch-crop-harvest-yield
  patch-previous-crop
  patch-previous-crop-yield
  patch-previous-crop-selection-rule
  patch-crop-weed-loss
  patch-crop-disease-loss
]

to setup
  clear-all
  reset-ticks
  set init-nitrogen-mean 10
  set init-nitrogen-sd 2
  set verbose-output false
  setup-globals
  setup-fields
  setup-turtles

  foreach sort patches [ p1 ->
    ask p1 [
      update-patch-label
      set-crop-shape
      update-crop-size
    ]
  ]
end

to go
  do-next-week
  if (verbose-output) [show "-----"]
  tick
end

to stop-simulation
  foreach sort patches [ p1 ->
    ask p1 [
      if (patch-current-crop != fallow)[
        do-harvest-crop
      ]
    ]
  ]
  let header "Type"
  foreach crops-list-all[ p1 ->
    set header (word header ":" p1)
  ]
  set header (word header ":NM:NSD")
  show header
  print-crop-totals
  set header "Type"
  foreach rules-list-all[ p1 ->
    set header (word header ":" p1)
  ]
  set header (word header ":NM:NSD")
  show header
  print-crop-rule-totals
end

to do-next-week
  foreach sort patches [ p1 ->
    ask p1 [
      if (patch-crop-harvest-week = ticks)[
        ifelse (patch-current-crop = fallow)
        [do-plant-crop]
        [do-harvest-crop]
      ]
      update-patch-label
      set-crop-shape
      update-crop-size
    ]
  ]
end

to do-plant-crop
  let patch-to-plant-crop select-crop-to-plant
  table:put crop-rule-totals patch-previous-crop-selection-rule ( (table:get crop-rule-totals patch-previous-crop-selection-rule) + 1)
  set patch-nitrogen-level patch-nitrogen-level - table:get crops-table-nitrogen-requirements patch-to-plant-crop
  set-patch-color
  set patch-crop-history fput patch-to-plant-crop patch-crop-history
  set patch-current-crop patch-to-plant-crop
  set-patch-crop-harvest-week
  if (verbose-output) [print-planting-message]
  table:put crop-planting-totals patch-to-plant-crop ( (table:get crop-planting-totals patch-to-plant-crop) + 1)
end

to do-harvest-crop
  if (verbose-output) [print-harvest-message]
  set-patch-crop-weed-loss
  set-patch-crop-disease-loss
  set patch-crop-harvest-yield ( (1 - patch-crop-weed-loss) * (1 - patch-crop-disease-loss))
  table:put crop-yield-totals patch-current-crop ( (table:get crop-yield-totals patch-current-crop) + patch-crop-harvest-yield)
  set patch-previous-crop patch-current-crop
  set patch-previous-crop-yield patch-crop-harvest-yield
  set patch-current-crop fallow
  set patch-crop-harvest-week (ticks + 5)
end

to set-patch-crop-harvest-week
  set patch-crop-harvest-week  ticks + table:get crops-table-harvest-time patch-current-crop + (  (random 3) - 1)
end

to set-patch-crop-weed-loss
  let tan-in random-float (table:get crops-table-weeds patch-current-crop)
  set patch-crop-weed-loss get-tanh tan-in
end

to set-patch-crop-disease-loss
  let tan-in random-float (table:get crops-table-disease patch-current-crop)
  set patch-crop-disease-loss get-tanh tan-in
end

to set-all-crops-list
  set crops-list-all (list beet buckwheat carrot cucurbit grass legume lettuce lily mustard nightshade rose cover fallow)
end

to set-crops-table-nitrogen-requirements
  set crops-table-nitrogen-requirements table:make
  table:put crops-table-nitrogen-requirements beet 2
  table:put crops-table-nitrogen-requirements buckwheat 2
  table:put crops-table-nitrogen-requirements carrot 6
  table:put crops-table-nitrogen-requirements cucurbit 6
  table:put crops-table-nitrogen-requirements grass 4
  table:put crops-table-nitrogen-requirements legume 2
  table:put crops-table-nitrogen-requirements lettuce 6
  table:put crops-table-nitrogen-requirements lily 6
  table:put crops-table-nitrogen-requirements mustard 6
  table:put crops-table-nitrogen-requirements nightshade 4
  table:put crops-table-nitrogen-requirements rose 4
  table:put crops-table-nitrogen-requirements cover (0 - 15)
  table:put crops-table-nitrogen-requirements fallow 0
end

to set-crops-table-weeds
  set crops-table-weeds table:make
  table:put crops-table-weeds beet 0.5
  table:put crops-table-weeds buckwheat 0.5
  table:put crops-table-weeds carrot 0.1
  table:put crops-table-weeds cucurbit 0.5
  table:put crops-table-weeds grass 1.5
  table:put crops-table-weeds legume 0.5
  table:put crops-table-weeds lettuce 0.8
  table:put crops-table-weeds lily 0.5
  table:put crops-table-weeds mustard 1.5
  table:put crops-table-weeds nightshade 0.5
  table:put crops-table-weeds rose 0.1
  table:put crops-table-weeds cover 0.1
  table:put crops-table-weeds fallow 0
end

to set-crops-table-disease
  set crops-table-disease table:make
  table:put crops-table-disease beet 0.5
  table:put crops-table-disease buckwheat 0.25
  table:put crops-table-disease carrot 0.5
  table:put crops-table-disease cucurbit 0.5
  table:put crops-table-disease grass 0.8
  table:put crops-table-disease legume 1.0
  table:put crops-table-disease lettuce 0.8
  table:put crops-table-disease lily 1.0
  table:put crops-table-disease mustard 0.25
  table:put crops-table-disease nightshade 0.8
  table:put crops-table-disease rose 0.8
  table:put crops-table-disease cover 0.5
  table:put crops-table-disease fallow 0
end

to set-crops-table-harvest-time
  set crops-table-harvest-time table:make
  table:put crops-table-harvest-time beet 8
  table:put crops-table-harvest-time buckwheat 12
  table:put crops-table-harvest-time carrot 13
  table:put crops-table-harvest-time cucurbit 8
  table:put crops-table-harvest-time grass 12
  table:put crops-table-harvest-time legume 9
  table:put crops-table-harvest-time lettuce 6
  table:put crops-table-harvest-time lily 15
  table:put crops-table-harvest-time mustard 10
  table:put crops-table-harvest-time nightshade 10
  table:put crops-table-harvest-time rose 10
  table:put crops-table-harvest-time cover 6
  table:put crops-table-harvest-time fallow 6
end

to set-crops-table-abbreviations
  set crops-table-abbreviations table:make
  table:put crops-table-abbreviations beet "Be"
  table:put crops-table-abbreviations buckwheat "Bu"
  table:put crops-table-abbreviations carrot "Ca"
  table:put crops-table-abbreviations cucurbit "Cu"
  table:put crops-table-abbreviations grass "Gr"
  table:put crops-table-abbreviations legume "Lg"
  table:put crops-table-abbreviations lettuce "Lt"
  table:put crops-table-abbreviations lily "Li"
  table:put crops-table-abbreviations mustard "Mu"
  table:put crops-table-abbreviations nightshade "Ni"
  table:put crops-table-abbreviations rose "Ro"
  table:put crops-table-abbreviations cover "Co"
  table:put crops-table-abbreviations fallow "Fa"
end

to set-crop-names
  set  beet "beet"
  set  buckwheat "buckwheat"
  set  carrot "carrot"
  set  cucurbit "cucurbit"
  set  grass "grass"
  set  legume "legume"
  set  lettuce "lettuce"
  set  lily "lily"
  set  mustard "mustard"
  set  nightshade "nightshade"
  set  rose "rose"
  set  cover "cover"
  set  fallow "fallow"
end

to set-crop-shapes
  set crops-shapes table:make
  table:put crops-shapes beet "box"
  table:put crops-shapes buckwheat "car"
  table:put crops-shapes carrot "flower"
  table:put crops-shapes cucurbit "leaf"
  table:put crops-shapes grass "person"
  table:put crops-shapes legume "plant"
  table:put crops-shapes lettuce "house"
  table:put crops-shapes lily "sheep"
  table:put crops-shapes mustard "square"
  table:put crops-shapes nightshade "target"
  table:put crops-shapes rose "tree"
  table:put crops-shapes cover "wheel"
  table:put crops-shapes fallow "x"
end

to-report select-crop-to-plant
  let low-yield 0.1
  let random-fallow 0.05
  let low-nitrogen 2
  let medium-nitrogen 4

  if (( (patch-crop-disease-loss > 0.65) or (patch-crop-weed-loss > 0.75) ) and
    patch-previous-crop != cover and patch-previous-crop != fallow) [
    set patch-available-crops remove patch-current-crop patch-available-crops
  ]

  let possible-crops []
  foreach patch-available-crops[ p1 -> set possible-crops fput p1 possible-crops ]

  if empty? possible-crops [
    set patch-previous-crop-selection-rule "Rule_2"
    report fallow
  ]

  if ( (patch-previous-crop-yield < low-yield) and (patch-previous-crop != fallow)) [
    set patch-previous-crop-selection-rule "Rule_3"
    set patch-previous-crop-yield 1
    report fallow
  ]

  if random-float 1 < random-fallow [
    set patch-previous-crop-selection-rule "Rule_4"
    report fallow
  ]

  if patch-nitrogen-level < low-nitrogen [
    set patch-previous-crop-selection-rule "Rule_5a"
    report cover
  ]

  if (patch-nitrogen-level < medium-nitrogen and (random-float 1 < 0.25) ) [
    set patch-previous-crop-selection-rule "Rule_5b"
    report cover
  ]

  foreach possible-crops[ p1 ->
    if ( (table:get crops-table-nitrogen-requirements p1) > patch-nitrogen-level)[
      set possible-crops remove p1 possible-crops
    ]
  ]

  if empty? possible-crops [
    set patch-previous-crop-selection-rule "Rule_6a"
    report fallow
  ]
  if ( (length possible-crops) = 1) [
    set patch-previous-crop-selection-rule "Rule_6b"
    report first possible-crops
  ]

  if (member? patch-previous-crop possible-crops)[
    set possible-crops remove patch-previous-crop possible-crops
  ]

  if empty? possible-crops [
    set patch-previous-crop-selection-rule "Rule_7a"
    report fallow
  ]
  if ( (length possible-crops) = 1) [
    set patch-previous-crop-selection-rule "Rule_7b"
    report first possible-crops
  ]

  foreach possible-crops[ p1 ->
    if ( (count patches with [patch-current-crop = p1] + 1) > (0.25 * count patches) and
      (p1 != cover) and (p1 != grass) )[
      set possible-crops remove p1 possible-crops
    ]
  ]
  if empty? possible-crops [
    set patch-previous-crop-selection-rule "Rule_8a"
    report fallow
  ]
  if ( (length possible-crops) = 1) [
    set patch-previous-crop-selection-rule "Rule_8b"
    report first possible-crops
  ]

  if ( ( (patch-previous-crop = beet) or (patch-previous-crop = lettuce) ) and
    (member? nightshade possible-crops) and
    (random-float 1 < 0.90))[
    set patch-previous-crop-selection-rule "Rule_9"
    report nightshade
  ]

  if ( (patch-previous-crop = lily) and (random-float 1 < 0.90))[
    set patch-previous-crop-selection-rule "Rule_10"
    report fallow
  ]

  if ( (patch-previous-crop = cover) and
    (member? grass possible-crops) and
    (random-float 1 < 0.95))[
    set patch-previous-crop-selection-rule "Rule_11"
    report grass
  ]

  if ( ( (patch-previous-crop = lettuce) or (patch-previous-crop = mustard) ) and
    (member? beet possible-crops) and
    (random-float 1 < 0.95))[
    set patch-previous-crop-selection-rule "Rule_12"
    report beet
  ]

  set patch-previous-crop-selection-rule "Rule_13"
  report one-of patch-available-crops
end

to setup-fields
  let counter 0
  foreach sort patches [ p1 ->
    ask p1 [
      set patch-nitrogen-level round (random-normal init-nitrogen-mean init-nitrogen-sd)
      if (patch-nitrogen-level < 0)[set patch-nitrogen-level 0]
      set patch-crop-history[]
      set patch-current-crop fallow
      set patch-previous-crop fallow
      set patch-available-crops[]
      foreach crops-list-all [ c1 ->
        set patch-available-crops fput c1 patch-available-crops
      ]
      set patch-available-crops remove fallow patch-available-crops
      set patch-previous-crop-yield 1
      set-patch-color
      set patch-id counter
      set counter counter + 1
    ]
  ]
end

to setup-globals
  set-crop-names
  set-all-crops-list
  set-crops-table-nitrogen-requirements
  set-crops-table-weeds
  set-crops-table-disease
  set-crops-table-harvest-time
  set-crops-table-abbreviations
  set-crop-shapes
  set-rules-list-all
  set-crop-yield-totals
  set-crop-planting-totals
  set-crop-rule-totals
end

to setup-turtles
  foreach sort patches [ p1 ->
    ask p1 [
      sprout 1 [
        set heading 0
        set shape (table:get crops-shapes patch-current-crop)
        set color blue
        set size 0.8
      ]
    ]
  ]
end

to set-crop-yield-totals
  set crop-yield-totals table:make
  foreach crops-list-all[ p1 ->
    table:put crop-yield-totals p1 0
  ]
end

to set-crop-planting-totals
  set crop-planting-totals table:make
  foreach crops-list-all[ p1 ->
    table:put crop-planting-totals p1 0
  ]
end

to set-rules-list-all
  set rules-list-all [
    "Rule_2" "Rule_3" "Rule_4" "Rule_5a" "Rule_5b" "Rule_6a"
    "Rule_6b" "Rule_7a" "Rule_7b" "Rule_8a"
    "Rule_8b" "Rule_9" "Rule_10" "Rule_11"
    "Rule_12" "Rule_13" ]
end

to set-crop-rule-totals
  set crop-rule-totals table:make
  foreach rules-list-all[ p1 ->
    table:put crop-rule-totals p1 0
  ]
end

to update-patch-label
  set plabel(word patch-id ": " patch-nitrogen-level "," (table:get crops-table-abbreviations patch-current-crop) "," patch-crop-harvest-week)
end

to print-crop-totals
  print-crop-yield-totals
  print-crop-planting-totals
end

to print-crop-yield-totals
  let y "TOTAL-YIELDS"
  foreach crops-list-all[ p1 ->
    ifelse (length (word table:get crop-yield-totals p1) >= 4)
    [set y (word y ":" (substring (word table:get crop-yield-totals p1) 0 4))]
    [set y (word y ":" table:get crop-yield-totals p1)]
  ]
  set y (word y ":" init-nitrogen-mean ":" init-nitrogen-sd)
  show y
end

to print-crop-planting-totals
  let y "TOTAL-PLANTINGS"
  foreach crops-list-all[ p1 ->
    set y (word y ":" table:get crop-planting-totals p1)
  ]
  set y (word y ":" init-nitrogen-mean ":" init-nitrogen-sd)
  show y
end

to print-crop-rule-totals
  let y "TOTAL-RULES"
  foreach rules-list-all[ p1 ->
    set y (word y ":" table:get crop-rule-totals p1)
  ]
  set y (word y ":" init-nitrogen-mean ":" init-nitrogen-sd)
  show y
end

to print-harvest-message
  ifelse (length (word patch-crop-harvest-yield) >= 4)
  [show (word patch-id " " "HARVEST " patch-current-crop " "  (substring (word patch-crop-harvest-yield) 0 4))]
  [show (word patch-id " " "HARVEST " patch-current-crop " " patch-crop-harvest-yield)]
end

to print-planting-message
  show (word patch-id " " "PLANTING " patch-current-crop " <" patch-previous-crop-selection-rule "> ")
end

to print-current-crop-distribution
  let y "DISTRIBUTION: "
  foreach crops-list-all[ p1 ->
    set y (word y " " p1 ":" count patches with [patch-current-crop = p1])
  ]
end

to set-patch-color
  let max-current-nitrogen max [patch-nitrogen-level] of patches
  let color-temp 67 - (patch-nitrogen-level / (max-current-nitrogen / 4) )
  if (color-temp < 63)[ set color-temp 63]
  if (color-temp > 67)[ set color-temp 67]
  set pcolor color-temp
end

to update-crop-size
  foreach sort turtles-here [ p1 ->
    ask p1 [
      let weeks-to-harvest (table:get crops-table-harvest-time patch-current-crop) - (patch-crop-harvest-week - ticks)
      set size  (weeks-to-harvest / table:get crops-table-harvest-time patch-current-crop) * 0.8
    ]
  ]
end

to set-crop-shape
  foreach sort turtles-here [ p1 ->
    ask p1[
      set shape table:get crops-shapes patch-current-crop
    ]
  ]
end

to print-yield
  show ( word patch-current-crop " " patch-crop-harvest-yield )
end

to-report get-tanh [x]
  report ((exp (2 * x)) - 1) / ((exp (2 * x)) + 1)
end
"""
end
