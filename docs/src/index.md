# NetLogo.jl

`NetLogo.jl` is a clean-room Julia implementation of the NetLogo language and headless runtime. The package is designed for scripted execution, model loading, regression testing, and Julia-native integration rather than the desktop application workflow.

## Quick start

```@setup home
using NetLogo

model = netlogo"""
globals [population]

to setup
  clear-all
  create-turtles 5 [ setxy who 0 ]
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

```@example home
for _ in 1:3
    call!(runtime, "go")
end

(length(runtime.world.turtles), runtime.world.ticks)
```

## What the package covers

- parsing and compiling NetLogo source into a Julia runtime model
- loading `.nlogo` models and resolving `__includes`
- headless execution for observers, turtles, patches, and links
- import/export, plotting, drawing, and file I/O needed by headless models
- host-side GUI sessions for browsers and notebooks
- extension loading and built-in extension implementations
- evaluation tooling for Julia-vs-Java NetLogo comparability

## What remains out of scope

- the full NetLogo desktop application workflow
- HubNet
- 3D world semantics

## Core NetLogo concepts

- **Observer**: the global execution context that owns globals, orchestrates setup/go style procedures, and can ask other agents to act.
- **Turtles**: movable agents with position, heading, breed membership, and agent-owned variables.
- **Patches**: fixed cells in the 2D world grid.
- **Links**: directed or undirected connections between turtles.
- **AgentSets**: the dynamic collections that NetLogo procedures work over when they say `ask turtles`, `patches with [...]`, `link-neighbors`, and related forms.

## Typical workflow

1. Build or load a model with [`compile_model`](@ref) or [`load_model`](@ref).
2. Create an executable runtime with [`create_runtime`](@ref).
3. Run procedures by name with [`call!`](@ref).
4. Use [`run_commands!`](@ref) or [`runresult`](@ref) for runtime string evaluation when you need NetLogo command/reporter snippets from Julia.
5. Inspect the resulting [`RuntimeState`](@ref) and world state from Julia.

## Documentation map

- **Getting Started**: install the package locally and run a first model.
- **GUI Backends**: serve interface widgets and plots through a local browser UI or notebook embed.
- **Language and Runtime**: understand the parser, compiled model, runtime, and compatibility scope.
- **Extensions**: see the bundled extension surface and the extension-loading mechanism.
- **Evaluation and Benchmarking**: run the comparison harness against Java NetLogo.
- **Development**: test, build docs, and understand the included GitHub workflows.
- **API Reference**: exported API entry points and public data structures.
