# ── Daisyworld ─────────────────────────────────────────────────────────
# Source: modelingcommons #1420

struct DaisyworldModel <: FileBenchmarkModel end

model_name(::DaisyworldModel) = "Daisyworld"
n_ticks(::DaisyworldModel) = 400
tracked_globals(::DaisyworldModel) = [
  "global-temperature",
  "count turtles with [color = black]",
  "count turtles with [color = white]",
]
world_dims(::DaisyworldModel) = (-14, 14, -14, 14)
topology(::DaisyworldModel) = (true, true)

function nlogo_path(::DaisyworldModel)
  joinpath(modelingcommons_root(), "1420-daisyworld", "model", "Daisyworld.nlogo")
end
