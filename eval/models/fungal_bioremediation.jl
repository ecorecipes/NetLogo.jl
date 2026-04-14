# ── Fungal Bioremediation ─────────────────────────────────────────
# Source: modelingcommons #7030
# Table extension: table:make/put/get for species-specific enzyme parameters
# Fungi produce enzymes to degrade environmental contaminants.

struct FungalBioremediationModel <: AbstractBenchmarkModel end

model_name(::FungalBioremediationModel) = "Fungal Bioremediation"
n_ticks(::FungalBioremediationModel) = 200
tracked_globals(::FungalBioremediationModel) = ["num-fungi-fb", "num-enzymes-fb", "num-ecs-fb"]
world_dims(::FungalBioremediationModel) = (-16, 16, -16, 16)

function netlogo_code(::FungalBioremediationModel)
"""
extensions [table]

globals [
  ec-added ms Kr Kc Kd
  complexes-formed dissociated
  fungi-option
  status-1 status-2 status-3
  intracellularly
  fungi-dict
  adjuster-enzymes adjuster-fungi
  temperature pH fungi-species
  num-fungi-fb num-enzymes-fb num-ecs-fb
]

breed [fungi fungus]
breed [ECs EC]
breed [enzymes enzyme]

fungi-own [ age energy NH4 partner ]
patches-own [ glucose O2 lignin ]
enzymes-own [ age partner turn pause-time ]
ECs-own [ partner locked-time taken ]

to setup
  clear-all
  set temperature 33.5
  set pH 5.0
  set fungi-species "Pleurotus Ostreatus"
  setup-globals
  setup-patches
  setup-fungi
  setup-ECs
  set num-fungi-fb count fungi
  set num-enzymes-fb count enzymes
  set num-ecs-fb count ECs
  reset-ticks
end

to go
  if ticks > 400 and not any? ECs [ stop ]
  if ticks > 1000 [ stop ]

  diffuse glucose (0.5 + (0.01 * temperature))
  diffuse O2 (0.5 + (0.01 * temperature))

  set adjuster-enzymes round max (list ((count enzymes) ^ (1 / 4)) 1)
  set adjuster-fungi round max (list ((count enzymes) ^ (1 / 5)) 1)
  move-agents

  break-down-lignin
  eat-glucose
  replenish-O2

  reproduce
  produce-ECs

  age-fungus
  age-enzymes
  check-death
  nutrient-status

  intracellular-degrade
  denature
  change-rate
  degrade-ECs

  set num-fungi-fb count fungi
  set num-enzymes-fb count enzymes
  set num-ecs-fb count ECs
end

to setup-globals
  set ms 0.5
  set fungi-option fungi-species
  set status-1 false
  set status-2 false
  set status-3 false
  set fungi-dict table:make
end

to setup-patches
  ask patches [
    set pcolor blue
    set glucose 4
    set lignin 100
    set O2 25
  ]
end

to setup-fungi
  create-fungi 6 [
    if fungi-species = "Phanerodontia Chrysosporium" [
      set size 2.25
      table:put fungi-dict "fungi-growth-temp" 30
      table:put fungi-dict "fungi-growth-pH" 2
      table:put fungi-dict "enzyme-production-cost" 1
      table:put fungi-dict "enzyme-production-pH" 4
    ]
    if fungi-species = "Trametes Versicolor" [
      set size 2
      table:put fungi-dict "fungi-growth-temp" 24
      table:put fungi-dict "fungi-growth-pH" 1
      table:put fungi-dict "enzyme-production-cost" 1
      table:put fungi-dict "enzyme-production-pH" 3.75
    ]
    if fungi-species = "Pleurotus Ostreatus" [
      set size 2
      table:put fungi-dict "fungi-growth-temp" 33.5
      table:put fungi-dict "fungi-growth-pH" 4
      table:put fungi-dict "enzyme-production-cost" 2.5
      table:put fungi-dict "enzyme-production-pH" 5
    ]
    set color 1
    setxy random -28 + 14 random -28 + 14
    set energy 30
    set NH4 12
    set partner nobody
  ]
end

to setup-ECs
  set ec-added 40
  create-ECs 40 [
    set size 1
    set color 26
    setxy (random -32 + 16) one-of [ -16 16 ]
    set partner nobody
    set hidden? false
    set taken false
  ]
end

to move-agents
  ask enzymes [
    if partner = nobody [
      if ticks mod 3 = 0 [
        set turn (random 120) - 60
      ]
      right turn / 3
      ifelse (xcor > 14.5) [
        if (0 < heading and heading <= 90) [left 20]
        if (90 < heading and heading < 180) [right 20]
      ] [
        ifelse (xcor < -14.5) [
          if (270 <= heading and heading < 360) [right 20]
          if (180 < heading and heading < 270) [left 20]
        ] [
          ifelse (ycor < -14.5) [
            if (270 > heading and heading > 180) [right 20]
            if (180 >= heading and heading > 90) [left 20]
          ] [
            if (ycor > 14.5) [
              if (0 <= heading and heading < 90) [right 20]
              if (270 < heading and heading < 360) [left 20]
            ]
          ]
        ]
      ]
      forward 0.12
    ]
  ]
  ask ECs [
    if partner = nobody [
      ifelse ticks < 150 [
        let ec-heading heading
        if ycor > 6 [set heading 180]
        if ycor < -6 [set heading 0]
        forward 0.05
        set heading ec-heading
      ] [
        let ec-heading heading
        ifelse ycor > 12 [set heading 180] [
          ifelse ycor < -12 [set heading 0] [
            ifelse xcor < -12 [set heading 90] [
              if xcor > 12 [set heading 270]
            ]
          ]
        ]
        forward 0.02
        set heading ec-heading
      ]
      right -45 + random 90
      if (xcor > 14.5) [
        if (0 < heading and heading < 90) [left 20]
        if (90 < heading and heading < 180) [right 20]
      ]
      if (xcor < -14.5) [
        if (270 < heading and heading < 360) [right 20]
        if (180 < heading and heading < 270) [left 20]
      ]
      if (ycor < -14.5) [
        if (270 > heading and heading > 180) [right 20]
        if (180 > heading and heading > 90) [left 20]
      ]
      if (ycor > 14.5) [
        if (0 < heading and heading < 90) [right 20]
        if (270 < heading and heading < 360) [left 20]
      ]
      forward 0.06
    ]
  ]
end

to break-down-lignin
  ask enzymes with [partner = nobody] [
    if lignin >= 2 [
      set lignin (lignin - 2)
      set glucose (glucose + 1)
    ]
  ]
  if (count enzymes) < 80 [
    ask fungi [
      if lignin >= 1 [
        set lignin lignin - 0.5
        set glucose glucose + 0.25
      ]
    ]
  ]
end

to eat-glucose
  ask patches [
    let fungus-count count fungi-here
    if fungus-count > 0 [
      let g glucose / fungus-count
      ask fungi-here [
        set O2 (O2 + (g * 2))
      ]
    ]
  ]
  ask fungi [
    ifelse glucose >= 5 and O2 >= 30 [
      set glucose (glucose - 5)
      set O2 (O2 - 30)
      set energy (energy + (5 * 0.25))
    ] [
      if O2 >= glucose * 3 [
        let m (glucose / count fungi-here)
        set glucose (glucose - m)
        set O2 (O2 - (m * 3))
        set energy (energy + (m * 0.25))
      ]
    ]
  ]
end

to replenish-O2
  if (ticks mod 5 = 0) [
    ask patches [
      if O2 <= 50 [
        set O2 (O2 + 30)
      ]
    ]
  ]
end

to reproduce
  ask fungi [
    ifelse age > 16 and random (2 * (abs (table:get fungi-dict "fungi-growth-pH" - pH)) ^ 2) = 0 and energy > (random 8 + 2 + (abs (table:get fungi-dict "fungi-growth-temp" - temperature) ^ 2) * 2 + (abs (2 - table:get fungi-dict "fungi-growth-pH")) ^ 2) [
      let En (energy / 2)
      set energy En
      let L glucose / 2
      set glucose L
      set NH4 NH4 - 0.5
      hatch-fungi 1 [
        let p max-one-of patches in-radius 3 with [pycor < 15 and pycor > -15 and pxcor < 15 and pxcor > -15] [glucose]
        face p
        set energy En + (5.5 - (2 * abs (table:get fungi-dict "fungi-growth-pH" - pH))) + (table:get fungi-dict "enzyme-production-cost" * 1.5)
        set NH4 3.5 / adjuster-fungi
        set age 0
        forward 1
        set partner nobody
      ]
    ] [
      produce-enzymes
    ]
  ]
end

to produce-enzymes
  if (sum [glucose] of patches in-radius 2) < 120 and (energy < 20 or ticks < 12) and NH4 >= (max (list 1 (abs (table:get fungi-dict "enzyme-production-pH" - pH) * (table:get fungi-dict "enzyme-production-cost"))) * table:get fungi-dict "enzyme-production-cost") and (random (((abs (table:get fungi-dict "enzyme-production-pH" - pH)) ^ 3) * 50) = 0 or ticks < 12) and ((random 100) + count enzymes) < 280 [
    set NH4 NH4 - (max (list 1 (abs (table:get fungi-dict "enzyme-production-pH" - pH) * (table:get fungi-dict "enzyme-production-cost"))) * table:get fungi-dict "enzyme-production-cost")
    hatch-enzymes 1 [
      set size 1
      set color white
      set partner nobody
      set age 0
    ]
  ]
end

to produce-ECs
  if ticks > 32 and ticks < 400 and ticks mod 6 = 0 [
    create-ECs 2 [
      set size 1
      set color 26
      setxy (random 20 - 10) (random 20 - 10)
      set partner nobody
      set hidden? false
      set ec-added ec-added + 1
      set taken false
    ]
  ]
end

to age-fungus
  ask fungi [
    set energy energy - 0.7
    set NH4 NH4 + 0.08 / (adjuster-enzymes * 1.5)
    set age (age + 1)
    set color age * 0.15
    if energy <= 0 [set age age + 0.6]
    if color > 9.9 [ set color 9.9 ]
    if energy < 0 [set energy 0]
  ]
end

to age-enzymes
  ask enzymes [
    set age (age + 1)
  ]
end

to check-death
  ask fungi [
    if age > 200 * (1 / ms) and partner = nobody [die]
  ]
  ask enzymes [
    if age > 275 * (1 / ms) and partner = nobody [die]
  ]
end

to nutrient-status
  if sum [lignin] of patches < (51200) and status-1 = false [
    set status-1 true
  ]
  if sum [lignin] of patches < (76800) and status-2 = false [
    set status-2 true
  ]
  if sum [lignin] of patches < (26600) and status-3 = false [
    set status-3 true
  ]
end

to intracellular-degrade
  ask fungi with [partner = nobody] [
    if any? ECs in-radius 0.5 with [partner = nobody] [
      set partner one-of ECs in-radius 0.5 with [partner = nobody]
      ask partner [
        set partner myself
        set taken true
      ]
    ]
  ]
  ask ECs with [taken = true] [
    set locked-time locked-time + 1
    if locked-time > 34 [
      set intracellularly intracellularly + 1
      ask partner [set partner nobody]
      die
    ]
    set size 1 - (locked-time / 34)
    fd 0.007
  ]
end

to denature
  let aging-amount 0.5 + 0.1 * (table:get fungi-dict "enzyme-production-pH" - pH) ^ 2 + (count enzymes / 500)
  ask enzymes [
    set age age + aging-amount
  ]
end

to change-rate
  set Kc round (1)
  set Kd round (60)
  set Kr round (3 * abs (32 - temperature) + 3)
end

to degrade-ECs
  ask enzymes [form-complex]
  ask enzymes [dissociate-complex]
  ask ECs [react-forward]
end

to form-complex
  ifelse pause-time < 0
  [set pause-time pause-time + 1]
  [if partner = nobody and (any? other ECs-here with [partner = nobody and not taken]) [
    set partner one-of (other ECs-here with [partner = nobody and not taken])
    set complexes-formed complexes-formed + 1
    let h heading
    ask partner [
      set partner myself
      set hidden? true
      move-to partner
      set heading h
    ]
  ]]
end

to react-forward
  if (partner != nobody and not taken) [
    set locked-time locked-time + 1
    if locked-time > 25 and random Kr = 0 [
      ask partner [
        set partner nobody
        set color white
        set age age - 15
      ]
      set partner nobody
      die
    ]
  ]
end

to dissociate-complex
  if partner != nobody and random Kd = 0 [
    set dissociated dissociated + 1
    set pause-time -15
    ask partner [
      set partner nobody
      set hidden? false
      set locked-time 0
    ]
    set partner nobody
    set age age - 15
  ]
end
"""
end
