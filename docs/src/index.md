# NetLogo.jl

`NetLogo.jl` is a clean-room Julia implementation of the NetLogo language and headless runtime. The package is designed for scripted execution, model loading, regression testing, and Julia-native integration rather than the desktop application workflow.

## What the package covers

- parsing and compiling NetLogo source into a Julia runtime model
- loading `.nlogo` models and resolving `__includes`
- headless execution for observers, turtles, patches, and links
- import/export, plotting, drawing, and file I/O needed by headless models
- extension loading and built-in extension implementations
- evaluation tooling for Julia-vs-Java NetLogo comparability

## What remains out of scope

- the NetLogo desktop GUI
- HubNet
- 3D world semantics

## Typical workflow

1. Build or load a model with [`compile_model`](@ref) or [`load_model`](@ref).
2. Create an executable runtime with [`create_runtime`](@ref).
3. Run procedures by name with [`call!`](@ref).
4. Inspect the resulting [`RuntimeState`](@ref) and world state from Julia.

## Documentation map

- **Getting Started**: install the package locally and run a first model.
- **Language and Runtime**: understand the parser, compiled model, runtime, and compatibility scope.
- **Extensions**: see the bundled extension surface and the extension-loading mechanism.
- **Evaluation and Benchmarking**: run the comparison harness against Java NetLogo.
- **Development**: test, build docs, and understand the included GitHub workflows.
- **API Reference**: exported API entry points and public data structures.
