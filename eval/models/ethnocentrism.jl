# ── Ethnocentrism ──────────────────────────────────────────────────────
# Source: modelingcommons #1478

struct EthnocentrismModel <: FileBenchmarkModel end

model_name(::EthnocentrismModel) = "Ethnocentrism"
n_ticks(::EthnocentrismModel) = 500
tracked_globals(::EthnocentrismModel) = [
  "cc-percent",
  "cd-percent",
  "dc-percent",
  "dd-percent",
]
world_dims(::EthnocentrismModel) = (0, 50, 0, 50)
topology(::EthnocentrismModel) = (true, true)
setup_command(::EthnocentrismModel) = "setup-empty"

function nlogo_path(::EthnocentrismModel)
  joinpath(modelingcommons_root(), "1478-ethnocentrism", "model", "Ethnocentrism.nlogo")
end
