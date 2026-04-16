# Getting Started

## Installation

`NetLogo.jl` is not registered yet, so install it directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/ecorecipes/NetLogo.jl")
```

The package targets Julia 1.12.

## A minimal embedded model

```@setup getting-started
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
```

```@example getting-started
for _ in 1:10
    call!(runtime, "go")
end

length(runtime.world.turtles), runtime.world.ticks
```

Use `netlogo"""..."""` when the model source lives naturally beside Julia code, tests, or benchmarks.

## Loading a model from disk

The example below writes a tiny standalone source file so the page stays self-contained. In normal use, `load_model` usually points at an existing `.nlogo` file from disk.

```@setup getting-started-file
using NetLogo

source = """
globals [population]

to setup
  clear-all
  create-turtles 5 [ setxy who 0 ]
  set population count turtles
  reset-ticks
end
"""

path = joinpath(mktempdir(), "demo.nls")
write(path, source)

file_runtime = create_runtime(load_model(path); seed=7)
call!(file_runtime, "setup")
```

```@example getting-started-file
runresult(file_runtime, "population")
```

`load_model` sets the source path used for relative `__includes` resolution, so included `.nls` files are handled the same way as embedded model code.

## Runtime string evaluation

`call!` is ideal for named procedures already compiled into the model. When you want to execute ad hoc NetLogo code from Julia, use [`run_commands!`](@ref) and [`runresult`](@ref):

```@example getting-started-file
run_commands!(file_runtime, "ask turtles [ set color blue ]")
runresult(file_runtime, "count turtles with [color = blue]")
```

## Optional browser and notebook GUI

If a model has interface widgets, you can expose them through a local browser UI:

```julia
using NetLogo

model = load_model("path/to/model.nlogo")
backend = start_web_gui(model; seed=1, port=8081)

web_gui_url(backend)
```

For Pluto or other notebook frontends, wrap the same session as an embeddable iframe:

```julia
using NetLogo

model = load_model("path/to/model.nlogo")
gui = pluto_gui(model; seed=1, port=8081, width=1000, height=800)

gui
```

## Inspecting runtime state

The runtime exposes the compiled model, the live world state, output buffers, and plotting state:

- `runtime.model` holds the compiled model metadata.
- `runtime.world` holds turtles, patches, links, globals, RNG state, ticks, and drawing state.
- `runtime.command_output` and `runtime.output_area` track headless text output.
- `runtime.plot_manager` holds headless plot state.

These structures are useful for tests, model comparisons, and Julia-side instrumentation.
