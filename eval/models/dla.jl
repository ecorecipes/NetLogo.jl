# ── DLA ────────────────────────────────────────────────────────────────
# Source: modelingcommons #1358

struct DLAModel <: FileBenchmarkModel end

model_name(::DLAModel) = "DLA"
n_ticks(::DLAModel) = 300
tracked_globals(::DLAModel) = [
  "radius",
  "count turtles",
  "count patches with [pcolor = green]",
]
world_dims(::DLAModel) = (-85, 85, -85, 85)
topology(::DLAModel) = (false, false)

function nlogo_path(::DLAModel)
  joinpath(modelingcommons_root(), "1358-dla", "model", "DLA.nlogo")
end
