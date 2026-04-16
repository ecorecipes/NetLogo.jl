# Evaluation and Benchmarking

The `eval/` directory contains the comparison harness used to test `NetLogo.jl` against the reference Java NetLogo runtime.

The harness includes wrappers for several model families:

- original NetLogo library-style benchmark models,
- class and extension stress models,
- compatibility models derived from public Modeling Commons descriptions and behavior,
- and a growing set of file-backed comparison cases.

## Entry point

Run the harness from the package root:

```bash
julia --project=. eval/run_comparison.jl [mode] [model] [n_reps]
```

Supported modes:

- `julia-only`: quick smoke test of the Julia models without invoking Java NetLogo
- `simple`: single-batch comparison with summary thresholds
- `calibrated`: multi-batch null-calibrated comparison

Examples:

```bash
julia --project=. eval/run_comparison.jl julia-only
julia --project=. eval/run_comparison.jl simple all 50
julia --project=. eval/run_comparison.jl calibrated sir 30
```

## Using the comparison module directly from Julia

```@setup evaluation
using NetLogo

include(joinpath(dirname(dirname(pathof(NetLogo))), "eval", "NetLogoCompare.jl"))
using .NetLogoCompare
```

```@example evaluation
model = SIRModel()
traj = only(NetLogoCompare.run_julia_trajectories(model, [1]))

(length(traj.ticks), sort!(collect(keys(traj.values))))
```

## Java NetLogo dependency

The comparison harness expects a local NetLogo 6.4.0 installation. By default it looks under the sibling `NetLogo-dist/NetLogo-6.4.0-64` directory. If your installation lives elsewhere, set:

```julia
NetLogoCompare.NETLOGO_DIR[] = "/path/to/NetLogo-6.4.0-64"
```

before running the comparison functions directly from Julia.

## Results

Comparison CSVs are written to `eval/results/`. The harness tracks per-model trajectory statistics and also reports speed comparisons between the Julia runtime and the reference Java implementation.

For local iteration, `julia-only` mode is usually the fastest way to smoke-test a benchmark wrapper before involving Java NetLogo.
