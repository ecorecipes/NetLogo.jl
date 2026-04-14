# ── Virus on a Network model (NetLogo models library) ───────────────

struct VirusOnNetworkModel <: AbstractBenchmarkModel end

model_name(::VirusOnNetworkModel) = "Virus on a Network"
n_ticks(::VirusOnNetworkModel) = 200
tracked_globals(::VirusOnNetworkModel) = ["num-susceptible", "num-infected", "num-resistant"]
world_dims(::VirusOnNetworkModel) = (-20, 20, -20, 20)

function netlogo_code(::VirusOnNetworkModel)
"""
globals [randomSeed number-of-nodes average-node-degree initial-outbreak-size
         virus-spread-chance virus-check-frequency recovery-chance gain-resistance-chance
         num-susceptible num-infected num-resistant]

turtles-own [infected? resistant? virus-check-timer]

to setup
  clear-all
  set number-of-nodes 150
  set average-node-degree 6
  set initial-outbreak-size 3
  set virus-spread-chance 2.5
  set virus-check-frequency 1
  set recovery-chance 5
  set gain-resistance-chance 5
  setup-nodes
  setup-spatially-clustered-network
  ask n-of initial-outbreak-size turtles [ become-infected ]
  ask links [ set color white ]
  update-globals
  reset-ticks
end

to setup-nodes
  set-default-shape turtles "circle"
  crt number-of-nodes [
    setxy (random-xcor * 0.95) (random-ycor * 0.95)
    become-susceptible
    set virus-check-timer random virus-check-frequency
  ]
end

to setup-spatially-clustered-network
  let num-links (average-node-degree * number-of-nodes) / 2
  while [count links < num-links] [
    ask one-of turtles [
      let choice (min-one-of (other turtles with [not link-neighbor? myself]) [distance myself])
      if choice != nobody [ create-link-with choice ]
    ]
  ]
  repeat 10 [
    layout-spring turtles links 0.3 (world-width / (sqrt number-of-nodes)) 1
  ]
end

to go
  if all? turtles [not infected?] [ stop ]
  ask turtles [
    set virus-check-timer virus-check-timer + 1
    if virus-check-timer >= virus-check-frequency
      [ set virus-check-timer 0 ]
  ]
  spread-virus
  do-virus-checks
  update-globals
  tick
end

to become-infected
  set infected? true
  set resistant? false
  set color red
end

to become-susceptible
  set infected? false
  set resistant? false
  set color green
end

to become-resistant
  set infected? false
  set resistant? true
  set color gray
  ask my-links [ set color gray - 2 ]
end

to spread-virus
  ask turtles with [infected?] [
    ask link-neighbors with [not resistant?] [
      if random-float 100 < virus-spread-chance [ become-infected ]
    ]
  ]
end

to do-virus-checks
  ask turtles with [infected? and virus-check-timer = 0] [
    if random 100 < recovery-chance [
      ifelse random 100 < gain-resistance-chance
        [ become-resistant ]
        [ become-susceptible ]
    ]
  ]
end

to update-globals
  set num-susceptible count turtles with [not infected? and not resistant?]
  set num-infected count turtles with [infected?]
  set num-resistant count turtles with [resistant?]
end
"""
end
