# ── PrivacyOpinion model (CSS600 ClassModels / nw extension) ──────────

struct PrivacyOpinionModel <: AbstractBenchmarkModel end

model_name(::PrivacyOpinionModel) = "Privacy Opinion"
n_ticks(::PrivacyOpinionModel) = 200
tracked_globals(::PrivacyOpinionModel) = ["adoptersTotal", "adopterPercent"]
world_dims(::PrivacyOpinionModel) = (-16, 16, -16, 16)
topology(::PrivacyOpinionModel) = (false, false)

function netlogo_code(::PrivacyOpinionModel)
"""
;; Define attributes of each employee agent
turtles-own [
  adopted?                    ;; Binary that signifies that the employee has adopted the wellness plan
  currentPrivacyAttitude     ;; Range 0 to 1 -> 0 = Never give up data; 1 = Always give up data
  updatedPrivacyAttitude     ;; Temporary value used when thresholds are updated
  willingnessToChange         ;; Range 0 to 1 ->  1 = Always change privacy attitude; 0 = Never change privacy attitude
]

;; Define global variables
globals [
  adoptersTotal   ;; Total number of employees that adopt the plan
  nodeCount       ;; Total number of employees in the population (nodes in the graph)
  adopterPercent  ;; Percentage of employees that have adopted

  HRtickCounter   ;; Counts ticks between HR material releases
  HRtickInterval  ;; Current interval length to release HR material
  HRpulseIndicator  ;; Used to show when HR released material to employees

  PVtickCounter   ;; Counts ticks between privacy violations
  PVtickInterval  ;; Current interval between privacy violations
  PLRandomValue    ;; Global Privacy Random Value Holder

  adoptionThreshold
  HRminimumTickInterval
  boundedConfidenceThreshold
  HRboundedConfidenceThreshold
  privacyMinimumTickInterval
  PVboundedConfidenceThreshold
  enableHRinformationDistribution?
  enablePrivacyViolations?
]

extensions [ nw ]
undirected-link-breed [ employeelinks employeelink ]

to setup
  clear-all

  ;; Hardcode slider/switch defaults
  set adoptionThreshold 0.75
  set HRminimumTickInterval 20
  set boundedConfidenceThreshold 0.35
  set HRboundedConfidenceThreshold 0.5
  set privacyMinimumTickInterval 5
  set PVboundedConfidenceThreshold 1.0
  set enableHRinformationDistribution? true
  set enablePrivacyViolations? true

  ;; Generate a small-world network with ~50 nodes
  nw:generate-small-world turtles employeelinks 5 10 2.0 false [
    set color gray
    set adopted? false
  ]
  set nodeCount count turtles

  init-employee-attributes
  layout
  resize-nodes
  check-adopters
  initialize-HR
  initialize-PV

  reset-ticks
end

to initialize-HR
  set HRtickCounter 0
  set HRtickInterval HRminimumTickInterval
  set HRpulseIndicator 0
end

to initialize-PV
  set PVtickCounter 0
  set PVtickInterval privacyMinimumTickInterval
end

to layout
  repeat 20 [
    do-layout
  ]
end

to do-layout
  layout-spring (turtles with [any? link-neighbors]) links 0.4 15 1
end

to init-employee-attributes
  let n 0
  set adoptersTotal 0

  while [n < nodeCount] [
    ask turtle n [
      set currentPrivacyAttitude (random 100) * 0.01
      set updatedPrivacyAttitude 0
      set willingnessToChange (random 100) * 0.01

      if currentPrivacyAttitude >= adoptionThreshold [
        set adopted? True
        set color green
        set adoptersTotal (adoptersTotal + 1)
      ]
    ]
    set n n + 1
  ]
end

to resize-nodes
    ask turtles [ set size sqrt (currentPrivacyAttitude * 5) ]
end

to check-adopters
  set adoptersTotal 0

  ask turtles [
      ifelse currentPrivacyAttitude >= adoptionThreshold [
        set adopted? True
        set color green
        set adoptersTotal (adoptersTotal + 1) ]
      [set adopted? False
        set color gray ]
   ]

  set adopterPercent (adoptersTotal / nodeCount) * 100
end

to block-update-privacy
  ask turtles [
       set currentPrivacyAttitude updatedPrivacyAttitude
       ]
end

to propagate-privacy-thresholds
  ask turtles [
    let neighbors-who-meet-confidence-threshold link-neighbors with [ abs(currentPrivacyAttitude - ([currentPrivacyAttitude] of myself)) <= boundedConfidenceThreshold  ]

    let Attitude-delta 0

    ask neighbors-who-meet-confidence-threshold [
      set Attitude-delta (Attitude-delta + (currentPrivacyAttitude - [currentPrivacyAttitude] of myself))
    ]

    set Attitude-delta Attitude-delta / (1 + count neighbors-who-meet-confidence-threshold)

    ifelse (count neighbors-who-meet-confidence-threshold) > 0
      [ set updatedPrivacyAttitude ((currentPrivacyAttitude) + (willingnessToChange * Attitude-delta)) ]
      [ set updatedPrivacyAttitude currentPrivacyAttitude ]
    ]
end

to distribute-HR-material
  if HRtickCounter >= HRtickInterval [
    set HRpulseIndicator (HRpulseIndicator + 1) mod 2
    set HRtickCounter 0
    set adoptersTotal 0

    ask turtles [
      if abs(1 - currentPrivacyAttitude) < HRboundedConfidenceThreshold [
         set updatedPrivacyAttitude (currentPrivacyAttitude + (1.0 - currentPrivacyAttitude) * willingnessToChange)
         set currentPrivacyAttitude updatedPrivacyAttitude
         set size sqrt (currentPrivacyAttitude * 10)
      ]

      ifelse currentPrivacyAttitude >= adoptionThreshold [
        set adopted? True
        set color green
        set adoptersTotal (adoptersTotal + 1) ]
      [set adopted? False
        set color gray ]
    ]

  ]
end

to cause-privacy-violation
  if PVtickCounter >= PVtickInterval [
    set PVtickCounter 0
    set adoptersTotal 0

    let PLexponent -1.5
    let lowerBound 0.01
    let upperBound 1.0
    let uniformRandomValue random-float 1
    set PLRandomValue (lowerBound ^ PLexponent + (upperBound ^ PLexponent - lowerBound ^ PLexponent) * uniformRandomValue) ^ (1 / PLexponent)

    ask turtles [
      if abs(PLRandomValue - currentPrivacyAttitude) < PVboundedConfidenceThreshold [
         set updatedPrivacyAttitude (currentPrivacyAttitude - (PLRandomValue * willingnessToChange))
         if updatedPrivacyAttitude < 0 [set updatedPrivacyAttitude 0]
         set currentPrivacyAttitude updatedPrivacyAttitude
         set size sqrt (currentPrivacyAttitude * 10)
      ]

      ifelse currentPrivacyAttitude >= adoptionThreshold [
        set adopted? True
        set color green
        set adoptersTotal (adoptersTotal + 1) ]
      [set adopted? False
        set color gray ]
    ]
  ]
end

to go
  propagate-privacy-thresholds
  block-update-privacy
  check-adopters
  resize-nodes

  set HRtickCounter HRtickCounter + 1
  if enableHRinformationDistribution? [
    distribute-HR-material ]

  set PVtickCounter PVtickCounter + 1
  if enablePrivacyViolations? [
    cause-privacy-violation ]

  tick
end
"""
end
