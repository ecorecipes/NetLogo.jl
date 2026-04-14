# ── Wisdom of Crowd vs Unpopular Norm ────────────────────────────
# Source: modelingcommons #6686
# Table extension: table:make/put/get for observation and belief tracking
# Agents comply/enforce unpopular norms with volunteering dilemma dynamics.

struct WisdomCrowdModel <: AbstractBenchmarkModel end

model_name(::WisdomCrowdModel) = "Wisdom of Crowd"
n_ticks(::WisdomCrowdModel) = 200
tracked_globals(::WisdomCrowdModel) = ["cnt-offenders", "cnt-inter", "cnt-neutralized", "curr-oi"]
world_dims(::WisdomCrowdModel) = (-16, 16, -16, 16)

function netlogo_code(::WisdomCrowdModel)
"""
extensions [table]

breed [believers believer]
breed [disbelievers disbeliever]

turtles-own [observe belief
  strength compliance complying-for property believe offender-index perform_intervention my-thresholds
  neighbor-list Enforcement enforcement-Need desire intention]

globals [DBComp DBEnf cnt-inter cnt-offenders cnt-neutralized curr-oi
  population tb-perc K threshold radius crime-intensity alpha norm stop-at
  mobility incorporate-guilt models]

to setup
  clear-all
  set population 50
  set tb-perc 15
  set K 0.5
  set threshold 0.5
  set radius 2
  set crime-intensity 3
  set alpha 0.5
  set norm 0.5
  set stop-at 200
  set mobility true
  set incorporate-guilt false
  set models "Gerritsen"

  ask patches [set pcolor white]
  let total_number population * count patches / 100
  let number_of_TB total_number * tb-perc / 100
  let number_of_DB total_number - number_of_TB

  create-believers number_of_TB [
    set color red
    setxy random-pxcor random-pycor
    while [any? other turtles-here] [ let empty_patch one-of patches with [any? turtles-here = false] move-to empty_patch ]
  ]

  ask believers [
    set belief 1
    set compliance 1
    set strength 1
    set heading 0
    set complying-for 0
    set property "offender"
    set observe table:make set believe table:make
    set offender-index 1
    set size 1
    set shape "arrow"
  ]

  create-disbelievers number_of_DB [
    set color green
    setxy random-pxcor random-pycor
    while [any? other turtles-here] [ let empty_patch one-of patches with [any? turtles-here = false] move-to empty_patch ]
  ]

  ask disbelievers [
    set belief -1
    set compliance -1
    set strength random-float 0.3
    set heading 180
    set complying-for 0
    set property "bystanders"
    set observe table:make set believe table:make
    set perform_intervention "no"
    set my-thresholds threshold
    set size 1
    set shape "arrow"
  ]

  ask turtles [table:put observe "no_intervention_by_others" 0 table:put believe "seriousness" crime-intensity / 3]

  set cnt-offenders 0
  set cnt-inter 0
  set cnt-neutralized 0
  set curr-oi 0
  reset-ticks
end

to go
  if ticks = stop-at [stop]

  if models = "Centola" [
    ED
    reportdata
    draw-graphs
  ]

  if models = "Gerritsen" [
    reportdata
    VD
    draw-graphs
  ]

  if models = "Combined" [
    ED
    reportdata
    VD
    draw-graphs
  ]

  if mobility [ask turtles [random-walk]]
end

to ED
  ask turtles [
    let N_Neighbors turtle-set turtles in-radius radius
    let Ni count N_Neighbors
    if Ni = 0 [set Ni 0.001]
    let Bi [belief] of self
    let NCi count N_Neighbors with [Compliance != Bi]
    set enforcement-Need (1 - Bi / Ni) * NCi
    set enforcement-need enforcement-Need / 2
    COMPLY?
    ENFORCE?
  ]
end

to COMPLY?
  let Si [strength] of self
  let Bi [belief] of self
  let N_Neighbors turtle-set turtles in-radius radius
  let Ej count N_Neighbors with [Enforcement = -1 * Bi]
  let Ni count N_Neighbors
  if Ni = 0 [set Ni 0.001]
  ifelse ((-1 * Bi / Ni) * Ej ) > Si [set compliance -1 * Bi] [set compliance Bi]
  if Compliance = 1 [set complying-for complying-for + 1]
  if Compliance = -1 [set complying-for 0]
end

to VD
  let in-range nobody
  let current-intervener nobody
  ask turtles with [property = "offender"] [
    ifelse (offender-index <= 0) [set color black set heading 180]
    [
      set in-range other turtles with [property != "offender" and complying-for < crime-intensity] in-radius radius
      if (count in-range != 0) [
        set current-intervener one-of in-range
        ask current-intervener [set property "intervener" set color blue]
        ask current-intervener [
          set neighbor-list turtles with [ property != "offender"] in-radius radius
        ]
        if (current-intervener != nobody) [applyrules current-intervener who]
      ]
    ]
  ]
end

to ENFORCE?
  let Si [strength] of self
  let Bi [belief] of self
  let Ci [compliance] of self
  let Wi Enforcement-Need
  let N_Neighbors turtle-set turtles in-radius radius
  let Ej count N_Neighbors with [Enforcement = -1 * Bi]
  let Ni count N_Neighbors
  if Ni = 0 [set Ni 0.001]
  ifelse ((-1 * Bi / Ni) * Ej) > (Si + K) AND Bi != Ci [
    set Enforcement -1 * Bi
    set belief 1
    set strength 1
    set compliance 1
    set complying-for 0
    set size 1
    set shape "arrow"
    set heading 0
    set property "offender"
    set offender-index 1
  ] [
    ifelse (Si * Wi) > K AND Bi = Ci [
      set Enforcement Bi
    ] [
      set Enforcement 0
    ]
  ]
end

to applyrules [current-intervener w]
  let off turtle w
  let m 0
  ask current-intervener [set m count neighbor-list with [perform_intervention = "yes" ]]
  ask current-intervener [ifelse (m = 0) [table:put believe "intervention-evaluated-negatively" true] [table:put believe "intervention-evaluated-negatively" false]]
  ask current-intervener [table:put believe "other-observe-me" count neighbor-list]
  ask current-intervener [ifelse (table:get believe "intervention-evaluated-negatively") [table:put believe "audience-inhibation" table:get believe "other-observe-me"] [table:put believe "audience-inhibation" table:get believe "other-observe-me" - m]]
  ask current-intervener [table:put believe "intervention-cost" count neighbor-list - m]
  ask current-intervener [
    ifelse (table:get believe "intervention-cost" < my-thresholds and table:get believe "audience-inhibation" < my-thresholds)
    [ table:put believe "personal_responsibility" true ]
    [ table:put believe "personal_responsibility" false ]
  ]
  let x 0
  ask current-intervener [
    let y count neighbor-list - m
    if y = 0 [set y 0.001]
    set x table:get believe "seriousness" / (y ^ alpha) table:put believe "seriousness" x
  ]
  ask current-intervener [ifelse (table:get believe "seriousness" > norm) [ table:put believe "Emergency" true] [ table:put believe "Emergency" false]]
  ask current-intervener [ ifelse (table:get believe "Emergency") [ set desire "intervention" ] [ set desire "no_need_of_intervention" ]]
  ask current-intervener [ ifelse ( table:get believe "personal_responsibility" and desire = "intervention")
    [ set intention "help" ] [ set intention "not_to_intervene" ] ]
  ask current-intervener [table:put believe "capable" true table:put believe "resources" true]
  ask current-intervener [ if (table:get believe "capable" and table:get believe "resources") [table:put believe "opportunity_for" true ] ]
  let guilt 0
  ask current-intervener [
    ifelse (intention = "help" and table:get believe "opportunity_for" = true)
    [
      set perform_intervention "yes" set color brown
    ]
    [
      ifelse incorporate-guilt [
        set perform_intervention "no" set guilt crime-intensity - (m / count neighbor-list) set my-thresholds my-thresholds + guilt
      ] [
        set perform_intervention "no"
      ]
    ]
  ]
  let what? false
  ask current-intervener [ if (perform_intervention = "yes") [set what? true]]
  if what? [
    ask off [
      set offender-index offender-index - (m / crime-intensity)
      if (offender-index <= 0) [set property "neutralized" set color black set heading 180]
    ]
  ]
end

to random-walk
  rt random 360
  forward 1
end

to reportdata
  set DBComp count disbelievers with [compliance = -1 * belief] / count disbelievers * 100
  set DBEnf count disbelievers with [enforcement = -1 * belief] / count disbelievers * 100
end

to draw-graphs
  set curr-oi 0
  ask turtles with [property = "offender"] [set curr-oi curr-oi + offender-index]
  set curr-oi curr-oi / count turtles
  set cnt-inter count turtles with [property = "intervener"] / count disbelievers * 100
  set cnt-offenders count turtles with [property = "offender"] / count believers * 100
  set cnt-neutralized count turtles with [property = "neutralized"] / count believers * 100
end
"""
end
