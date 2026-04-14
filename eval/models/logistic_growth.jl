# ── Logistic Growth model (System Dynamics) ──────────────────────────

struct LogisticGrowthModel <: AbstractBenchmarkModel end

model_name(::LogisticGrowthModel) = "Logistic Growth"
n_ticks(::LogisticGrowthModel) = 200
tracked_globals(::LogisticGrowthModel) = ["stock"]
world_dims(::LogisticGrowthModel) = (-17, 17, -17, 17)

function netlogo_code(::LogisticGrowthModel)
"""
globals [randomSeed stock dt-val]

to setup
  clear-all
  resize-world (- 17) 17 (- 17) 17
  set stock 0.1
  set dt-val 0.01
  reset-ticks
end

to go
  let inflow stock * (1 - stock)
  set stock stock + dt-val * inflow
  tick
end
"""
end
