# ── Simple Genetic Algorithm model ───────────────────────────────────

struct SimpleGeneticAlgorithmModel <: AbstractBenchmarkModel end

model_name(::SimpleGeneticAlgorithmModel) = "Simple Genetic Algorithm"
n_ticks(::SimpleGeneticAlgorithmModel) = 200
tracked_globals(::SimpleGeneticAlgorithmModel) = ["best-fitness", "mean-fitness", "diversity"]
world_dims(::SimpleGeneticAlgorithmModel) = (0, 99, 0, 3)

function netlogo_code(::SimpleGeneticAlgorithmModel)
"""
globals [randomSeed population-size crossover-rate mutation-rate
         winner best-fitness mean-fitness diversity]

turtles-own [
  bits
  fitness
]

to setup
  clear-all
  resize-world 0 99 0 3
  set population-size 100
  set crossover-rate 70
  set mutation-rate 0.5
  create-turtles population-size [
    set bits n-values world-width [one-of [0 1]]
    calculate-fitness
    hide-turtle
  ]
  update-display
  set best-fitness [fitness] of winner
  set mean-fitness mean [fitness] of turtles
  set diversity calc-diversity
  reset-ticks
end

to go
  if [fitness] of winner = world-width [ stop ]
  create-next-generation
  update-display
  set best-fitness [fitness] of winner
  set mean-fitness mean [fitness] of turtles
  set diversity calc-diversity
  tick
end

to update-display
  set winner max-one-of turtles [fitness]
end

to calculate-fitness
  set fitness length (remove 0 bits)
end

to create-next-generation
  let old-generation turtles with [true]
  let crossover-count (floor (population-size * crossover-rate / 100 / 2))
  repeat crossover-count [
    let parent1 max-one-of (n-of 3 old-generation) [fitness]
    let parent2 max-one-of (n-of 3 old-generation) [fitness]
    let child-bits crossover ([bits] of parent1) ([bits] of parent2)
    ask parent1 [ hatch 1 [ set bits item 0 child-bits ] ]
    ask parent2 [ hatch 1 [ set bits item 1 child-bits ] ]
  ]
  repeat (population-size - crossover-count * 2) [
    ask max-one-of (n-of 3 old-generation) [fitness]
      [ hatch 1 ]
  ]
  ask old-generation [ die ]
  ask turtles [
    mutate
    calculate-fitness
  ]
end

to-report crossover [bits1 bits2]
  let split-point 1 + random (length bits1 - 1)
  report list (sentence (sublist bits1 0 split-point)
                        (sublist bits2 split-point length bits2))
              (sentence (sublist bits2 0 split-point)
                        (sublist bits1 split-point length bits1))
end

to mutate
  set bits map [b -> ifelse-value (random-float 100.0 < mutation-rate) [1 - b] [b]] bits
end

to-report calc-diversity
  let distances []
  ask turtles [
    let bits1 bits
    ask turtles with [self > myself] [
      set distances fput (hamming-distance bits bits1) distances
    ]
  ]
  let max-possible-distance-sum floor (count turtles * count turtles / 4)
  report (sum distances) / max-possible-distance-sum
end

to-report hamming-distance [bits1 bits2]
  report (length remove true (map [[b1 b2] -> b1 = b2] bits1 bits2)) / world-width
end
"""
end
