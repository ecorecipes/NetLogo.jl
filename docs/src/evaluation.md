# Evaluation and Benchmarking

The `eval/` directory contains the comparison harness used to test `NetLogo.jl` against the reference Java NetLogo runtime.

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

## Java NetLogo dependency

The comparison harness expects a local NetLogo 6.4.0 installation. By default it looks under the sibling `NetLogo-dist/NetLogo-6.4.0-64` directory. If your installation lives elsewhere, set:

```julia
NetLogoCompare.NETLOGO_DIR[] = "/path/to/NetLogo-6.4.0-64"
```

before running the comparison functions directly from Julia.

## Results

Comparison CSVs are written to `eval/results/`. The harness tracks per-model trajectory statistics and also reports speed comparisons between the Julia runtime and the reference Java implementation.
