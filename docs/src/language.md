# Language and Runtime

## Design focus

`NetLogo.jl` is intentionally headless-first. It aims for behavioral compatibility with the NetLogo language and runtime while keeping the Julia API idiomatic and scriptable.

The main layers are:

1. **Tokenizer and parser**: convert NetLogo source into a source-spanned model representation.
2. **Compiled model**: store declarations, procedures, widgets, plots, and extension metadata in a [`ModelSpec`](@ref).
3. **Runtime**: create a mutable [`RuntimeState`](@ref) with a world, primitive registry, plot state, output buffers, and RNG state.
4. **Execution context**: evaluate commands and reporters within a [`Context`](@ref) tied to a current agent.

## Supported model inputs

- inline model source via [`compile_model`](@ref) or `netlogo"""..."""`
- `.nlogo` files via [`load_model`](@ref)
- `.nls` include files resolved through `__includes`
- interface metadata and default widget-backed globals
- custom turtle shape text via [`parse_turtle_shapes_text`](@ref) and [`load_turtle_shapes!`](@ref)

## World model

The runtime supports the standard headless agent types:

- [`Observer`](@ref)
- [`Turtle`](@ref)
- [`Patch`](@ref)
- [`Link`](@ref)
- [`AgentSet`](@ref)

Supported topologies are exported through [`TopologyMode`](@ref): [`Torus`](@ref), [`VerticalCylinder`](@ref), [`HorizontalCylinder`](@ref), and [`BoxTopology`](@ref).

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
