# NetLogo.jl

`NetLogo.jl` is a clean-room, headless-first Julia implementation of the NetLogo language and runtime. It focuses on compiling, loading, and executing NetLogo models from Julia while staying behaviorally compatible with the headless language surface.

The package currently covers the 2D headless runtime, `.nlogo` / `.nls` model loading, interface metadata, plotting, import/export, drawing, and the extension surface needed by the evaluation suite. Desktop GUI workflows, HubNet, and 3D semantics remain out of scope.

Repository: <https://github.com/ecorecipes/NetLogo.jl>

## Status

- headless parser, compiler, interpreter, and runtime state
- string-macro DSL via `netlogo"""..."""`
- file-backed model loading with `__includes`
- extension support for `csv`, `table`, `nw`, `profiler`, `sound`, `gis`, `array`, `bitmap`, `fp`, `matrix`, `ls`, `rnd`, `store`, and `time`
- evaluation and comparison tooling in `eval/` for Julia-vs-Java NetLogo runs

## Installation

Until the package is registered, install it from GitHub:

```julia
julia> using Pkg

julia> Pkg.add(url="https://github.com/ecorecipes/NetLogo.jl")
```

`NetLogo.jl` currently targets Julia 1.12.

## Quick start

```julia
using NetLogo

model = netlogo"""
globals [population]

to setup
  clear-all
  create-turtles 5
  set population count turtles
  reset-ticks
end

to go
  ask turtles [ rt 15 fd 1 ]
  tick
end
"""

runtime = create_runtime(model; seed=42)
call!(runtime, "setup")
for _ in 1:10
    call!(runtime, "go")
end

(length(runtime.world.turtles), runtime.world.ticks)
```

To load a model from disk instead of embedding source:

```julia
using NetLogo

model = load_model("path/to/model.nlogo")
runtime = create_runtime(model; seed=1)
call!(runtime, "setup")
```

## Documentation

The full manual is built with Documenter.jl from `docs/` and is configured for GitHub Pages deployment from this repository.

```julia
julia> using Pkg

julia> Pkg.activate("docs")
julia> Pkg.develop(path=pwd())
julia> Pkg.instantiate()
```

Then build the site:

```bash
julia --project=docs docs/make.jl
```

The generated HTML site is written to `docs/build/`.

## Evaluation and benchmarking

The comparison harness in `eval/` can run smoke tests, single-batch comparisons, or calibrated multi-batch comparisons against a local NetLogo 6.4.0 installation.

```bash
julia --project=. eval/run_comparison.jl julia-only
julia --project=. eval/run_comparison.jl calibrated sir 30
```

## Development

Run the package tests from the package root:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Continuous integration and documentation build workflows live under `.github/workflows/`.

## License

`NetLogo.jl` is licensed under the MIT license. See [`LICENSE`](LICENSE).
