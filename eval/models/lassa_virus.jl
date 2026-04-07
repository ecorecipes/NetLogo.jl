# ── ABM Lassa Virus Transmission ─────────────────────────────────────
# Source: modelingcommons #7141 (Victor Odoh, Teesside University 2022)
# Modifications:
#   - Moved all slider defaults into setup after clear-all (slider globals
#     are not in the globals block and would be 0 after clear-all otherwise)
#   - Slider defaults: Human_Population=500, Multimammate_Rat_Population=25,
#     Initial_Number_Of_Cases=5, pct_Severe_Cases=20,
#     pct_Infectiousness_H2H=20, pct_Infectiousness_R2H=40,
#     Incubation_Period=10, Sick_Days=15, CFR_Mild_Case=1, CFR_Severe_Case=15,
#     Human_Behaviour_Factor=0.8, Infectious_Days_After_Recovery=90

struct LassaVirusModel <: AbstractBenchmarkModel end

model_name(::LassaVirusModel) = "LassaVirus"
n_ticks(::LassaVirusModel) = 500
tracked_globals(::LassaVirusModel) = ["pct_infected", "pct_immune", "current_cases", "total_fatalities"]
world_dims(::LassaVirusModel) = (-16, 16, -16, 16)

function netlogo_code(::LassaVirusModel)
"""
breed [humans human]
breed [rats rat]

humans-own [
  hours
  human_speed
]

globals [
  Human_Population
  Multimammate_Rat_Population
  Initial_Number_Of_Cases
  pct_Severe_Cases
  pct_Infectiousness_H2H
  pct_Infectiousness_R2H
  Incubation_Period
  Sick_Days
  CFR_Mild_Case
  CFR_Severe_Case
  Human_Behaviour_Factor
  Infectious_Days_After_Recovery
  control_speed
  infected_not_infectious
  initial_mild_cases
  initial_severe_cases
  mild_cases_count
  severe_cases_count
  severe_cases
  mild_cases
  total_mild_cases
  total_severe_cases
  fatalities
  total_fatalities
  immune_infectious
  immune_not_infectious
  pct_Mild_Cases
  pct_infected
  pct_uninfected
  pct_immune
  average_pct_CFR
  immune_or_severe_pct_infectiousness
  current_cases
  total_cases
  total_immune
  total_infected
  total_infectious
]

to setup
  clear-all
  set Human_Population 500
  set Multimammate_Rat_Population 25
  set Initial_Number_Of_Cases 5
  set pct_Severe_Cases 20
  set pct_Infectiousness_H2H 20
  set pct_Infectiousness_R2H 40
  set Incubation_Period 10
  set Sick_Days 15
  set CFR_Mild_Case 1
  set CFR_Severe_Case 15
  set Human_Behaviour_Factor 0.8
  set Infectious_Days_After_Recovery 90
  reset-ticks
  set pct_Mild_Cases (100 - pct_Severe_Cases)
  set initial_mild_cases (Initial_Number_Of_Cases * pct_Mild_Cases) / 100
  set initial_severe_cases (Initial_Number_Of_Cases * pct_Severe_Cases) / 100
  set immune_or_severe_pct_infectiousness pct_Infectiousness_H2H * (1 - Human_Behaviour_Factor)
  set control_speed 1
  create-rats Multimammate_Rat_Population [
    setxy random-xcor random-ycor
    set shape "mouse side"
    set color red - 2
    set size 0.8
  ]
  create-humans Human_Population [
    setxy random-xcor random-ycor
    set shape "person"
    set color white
    set size 1
    set human_speed control_speed
  ]
  ask n-of initial_mild_cases Humans
   [set color orange + 2]
  ask n-of initial_severe_cases Humans
   [ set color red ]
end

to go
  ask rats [
    fd control_speed * -1 * ((1 / Human_Behaviour_Factor) * 0.01)
    rt random 100 lt random 100
  ]
  ask humans [
    fd human_speed * ((1 / Human_Behaviour_Factor) * 0.01)
    rt random 45 lt random 45
    set hours hours + 1
  ]
  ask humans [
    ifelse (color = orange + 2) [
      ask other humans-here [
        if random 100 < pct_Infectiousness_H2H [
          if color = white [
            set color yellow
            set infected_not_infectious infected_not_infectious + 1
            set hours 0
          ]
        ]
      ]
    ]
    [
      ask rats [
        ask other humans-here [
          if random-float 100 < pct_Infectiousness_R2H [
            if color = white [
              set color yellow
              set hours 0
            ]
          ]
        ]
      ]
    ]
    if (color = cyan) or (color = red) [
      ask other humans-here [
        if random-float 100 < immune_or_severe_pct_infectiousness [
          if (color = white) [
            set color yellow
            set hours 0
          ]
        ]
      ]
    ]
    if (color = yellow) and (hours > (incubation_Period * 24)) [
      ifelse random-float 100 < pct_Severe_Cases [
        set color red
        set severe_cases severe_cases + 1
        set hours 0
        set human_speed 0
      ]
      [
        set color orange + 2
        set mild_cases mild_cases + 1
        set hours 0
        set human_speed 0.5
      ]
    ]
    if (color = orange + 2) and (hours = (Sick_Days * 24)) [
      ifelse random-float 100 < CFR_Mild_Case [
        set color gray
        set fatalities fatalities + 1
        set hours 0
        set human_speed 0
      ]
      [
        set color cyan
        set hours 0
        set human_speed 0.5
      ]
    ]
    if (color = red) and (hours = (Sick_Days * 24)) [
      ifelse random-float 100 < CFR_Severe_Case [
        set color gray
        set fatalities fatalities + 1
        set hours 0
        set human_speed 0
      ]
      [
        set color cyan
        set hours 0
        set human_speed control_speed
      ]
    ]
    if (color = cyan) and (hours = (Infectious_Days_After_Recovery * 24)) [
      set color lime + 1
      set hours 0
      set human_speed control_speed
    ]
  ]
  set infected_not_infectious count humans with [color = yellow]
  set mild_cases_count count humans with [color = orange + 2]
  set severe_cases_count count humans with [color = red]
  set immune_infectious count humans with [color = cyan]
  set immune_not_infectious count humans with [color = lime + 1]
  set total_immune (immune_infectious + immune_not_infectious)
  set current_cases (mild_cases_count + severe_cases_count)
  set total_mild_cases (mild_cases + initial_mild_cases)
  set total_severe_cases (severe_cases + initial_severe_cases)
  set total_cases (total_mild_cases + total_severe_cases)
  set total_infectious (current_cases + immune_infectious)
  set total_infected (infected_not_infectious + total_infectious + total_fatalities)
  set total_fatalities count humans with [color = gray]
  set average_pct_CFR (fatalities / total_cases) * 100
  set pct_infected (total_infected / Human_Population) * 100
  set pct_uninfected ((count humans with [color = white]) / Human_Population) * 100
  set pct_immune (total_immune / Human_Population) * 100
  if infected_not_infectious + current_cases + count humans with [color = white] = 0 [stop]
  tick
end
"""
end
