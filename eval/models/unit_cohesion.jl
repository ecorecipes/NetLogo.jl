# ── Unit Cohesion model (CSS600 ClassModels) ────────────────────────────

struct UnitCohesionModel <: AbstractBenchmarkModel end

model_name(::UnitCohesionModel) = "Unit Cohesion"
n_ticks(::UnitCohesionModel) = 500
tracked_globals(::UnitCohesionModel) = ["n-vacancies"]
world_dims(::UnitCohesionModel) = (0, 39, 0, 24)
topology(::UnitCohesionModel) = (false, false)

function netlogo_code(::UnitCohesionModel)
"""
globals [randomSeed lifespan cohorts replacement-team-size n-vacancies]

turtles-own [
  age
]

to setup
  clear-all
  set replacement-team-size 8
  set-default-shape turtles "person"
  setup-random-start
  set n-vacancies vacancies
  reset-ticks
end

to setup-random-start
  ask patches [
    set pcolor 37
    sprout 1 [
      set age random 156
      set color age
      set lifespan 156
    ]
  ]
end

to-report vacancies
  report (1000 - count turtles)
end

to go
  ask turtles [
    get-older
  ]
  if vacancies > replacement-team-size [
    ask patches [
      if not any? turtles-here [
        sprout 1 [
          set color ticks
          set age 6
          set lifespan 162
        ]
      ]
    ]
  ]
  set n-vacancies vacancies
  tick
end

to get-older
  set age age + 1
  if age > lifespan [
    die
  ]
end
"""
end
