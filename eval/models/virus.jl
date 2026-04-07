# ── Virus on a Network model ──────────────────────────────────────────

struct VirusModel <: AbstractBenchmarkModel end

model_name(::VirusModel) = "Virus on Network"
n_ticks(::VirusModel) = 150
tracked_globals(::VirusModel) = ["num-susceptible", "num-infected", "num-resistant"]

function netlogo_code(::VirusModel)
"""
globals [num-susceptible num-infected num-resistant]
turtles-own [infected? resistant? virus-timer]

to setup
  clear-all
  create-turtles 150 [
    setxy random-xcor random-ycor
    set infected? false
    set resistant? false
    set virus-timer 0
    set color green
    set shape "circle"
    set size 0.5
  ]
  ask turtles [
    create-links-with other turtles in-radius 3
  ]
  ask n-of 3 turtles [
    become-infected
  ]
  update-counts
  reset-ticks
end

to go
  if num-infected = 0 [ stop ]
  ask turtles with [infected?] [
    ask link-neighbors with [not resistant? and not infected?] [
      if random-float 1.0 < 0.10 [
        become-infected
      ]
    ]
    set virus-timer virus-timer + 1
    if virus-timer > 10 [
      ifelse random-float 1.0 < 0.25 [
        become-resistant
      ] [
        become-susceptible
      ]
    ]
  ]
  ask turtles with [resistant?] [
    if random-float 1.0 < 0.01 [
      become-susceptible
    ]
  ]
  update-counts
  tick
end

to become-infected
  set infected? true
  set resistant? false
  set virus-timer 0
  set color red
end

to become-resistant
  set infected? false
  set resistant? true
  set virus-timer 0
  set color gray
end

to become-susceptible
  set infected? false
  set resistant? false
  set virus-timer 0
  set color green
end

to update-counts
  set num-susceptible count turtles with [not infected? and not resistant?]
  set num-infected count turtles with [infected?]
  set num-resistant count turtles with [resistant?]
end
"""
end
