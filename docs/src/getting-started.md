# Getting Started

## Installation

`NetLogo.jl` is not registered yet, so install it directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/ecorecipes/NetLogo.jl")
```

The package targets Julia 1.12.

## A minimal embedded model

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

length(runtime.world.turtles), runtime.world.ticks
```

Use `netlogo"""..."""` when the model source lives naturally beside Julia code, tests, or benchmarks.

## Loading a `.nlogo` model

```julia
using NetLogo

model = load_model("path/to/model.nlogo")
runtime = create_runtime(model; seed=1)
call!(runtime, "setup")
```

`load_model` sets the source path used for relative `__includes` resolution, so included `.nls` files are handled the same way as embedded model code.

## Inspecting runtime state

The runtime exposes the compiled model, the live world state, output buffers, and plotting state:

- `runtime.model` holds the compiled model metadata.
- `runtime.world` holds turtles, patches, links, globals, RNG state, ticks, and drawing state.
- `runtime.command_output` and `runtime.output_area` track headless text output.
- `runtime.plot_manager` holds headless plot state.

These structures are useful for tests, model comparisons, and Julia-side instrumentation.
