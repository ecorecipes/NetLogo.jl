# Language and Runtime

## Design focus

`NetLogo.jl` is intentionally headless-first. It aims for behavioral compatibility with the NetLogo language and runtime while keeping the Julia API idiomatic and scriptable.

The main layers are:

1. **Tokenizer and parser**: convert NetLogo source into a source-spanned model representation.
2. **Compiled model**: store declarations, procedures, widgets, plots, and extension metadata in a [`ModelSpec`](@ref).
3. **Runtime**: create a mutable [`RuntimeState`](@ref) with a world, primitive registry, plot state, output buffers, and RNG state.
4. **Execution context**: evaluate commands and reporters within a [`Context`](@ref) tied to a current agent.

```@setup language
using NetLogo

model = netlogo"""
globals [population]

to setup
  clear-all
  create-turtles 4 [ setxy who 0 ]
  set population count turtles
  reset-ticks
end

to move-red
  ask turtles [ set color red fd 1 ]
  tick
end
"""

runtime = create_runtime(model; seed=11)
call!(runtime, "setup")
```

## Supported model inputs

- inline model source via [`compile_model`](@ref) or `netlogo"""..."""`
- `.nlogo` files via [`load_model`](@ref)
- `.nls` include files resolved through `__includes`
- interface metadata and default widget-backed globals
- custom turtle shape text via [`parse_turtle_shapes_text`](@ref) and [`load_turtle_shapes!`](@ref)

## World model

The runtime supports the standard headless agent types defined by NetLogo semantics:

- [`Observer`](@ref)
- [`Turtle`](@ref)
- [`Patch`](@ref)
- [`Link`](@ref)
- [`AgentSet`](@ref)

Supported topologies are exported through [`TopologyMode`](@ref): [`Torus`](@ref), [`VerticalCylinder`](@ref), [`HorizontalCylinder`](@ref), and [`BoxTopology`](@ref).

## Calling procedures and reporter expressions

Use [`call!`](@ref) for named procedures:

```@example language
call!(runtime, "move-red")
runtime.world.ticks
```

Use [`runresult`](@ref) when you want a NetLogo reporter expression from Julia:

```@example language
runresult(runtime, "list population count turtles with [color = red]")
```

Use [`run_commands!`](@ref) for ad hoc command strings:

```@example language
run_commands!(runtime, "ask turtles [ set label who ]")
runresult(runtime, "count turtles with [label != \"\"]")
```

## Compatibility scope

The current package surface includes:

- the 2D headless language and runtime
- file-backed model composition
- plotting and drawing in headless mode
- world import/export
- model-facing extension loading
- comparison and benchmarking infrastructure

Still intentionally out of scope:

- the desktop GUI itself
- HubNet
- 3D state such as `zcor`, pitch, roll, and tilt

## Error handling

Execution failures surface as [`LogoRuntimeError`](@ref). Parser and static-analysis failures surface as [`Diagnostic`](@ref) values with source spans when the relevant location is known.

Because the runtime keeps source spans on parsed procedures and expressions, parser and runtime errors can usually be traced back to the relevant source fragment even when the model was loaded from a file with includes.
