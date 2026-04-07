# API Reference

## Compilation and model loading

```@docs
NetLogo.tokenize
NetLogo.parse_model
NetLogo.compile_model
NetLogo.load_model
NetLogo.@netlogo_str
```

## Runtime execution

```@docs
NetLogo.create_runtime
NetLogo.call!
NetLogo.parse_turtle_shapes_text
NetLogo.load_turtle_shapes!
```

## Extension registration

```@docs
NetLogo.register_primitive!
```

## Source and parser types

```@docs
NetLogo.SourceSpan
NetLogo.Diagnostic
NetLogo.TokenKind
NetLogo.Token
NetLogo.BlockNode
NetLogo.ProcedureSpec
NetLogo.ModelSpec
NetLogo.CompiledModel
```

## Runtime and agent types

```@docs
NetLogo.RuntimeState
NetLogo.Context
NetLogo.LogoRuntimeError
NetLogo.Observer
NetLogo.Turtle
NetLogo.Patch
NetLogo.Link
NetLogo.AgentSet
```

## Enumerations

```@docs
NetLogo.AgentKind
NetLogo.TopologyMode
NetLogo.Torus
NetLogo.VerticalCylinder
NetLogo.HorizontalCylinder
NetLogo.BoxTopology
```

## Public types

### Source and parser structures

| Name | Purpose |
| --- | --- |
| [`SourceSpan`](@ref) | Source location range used in errors and diagnostics |
| [`Diagnostic`](@ref) | Parser or static-analysis failure with source context |
| [`TokenKind`](@ref) | Token category enumeration |
| [`Token`](@ref) | Lexical token with span and parsed value |
| [`BlockNode`](@ref) | Parsed command block node |
| [`ProcedureSpec`](@ref) | Parsed procedure definition |
| [`ModelSpec`](@ref) | Full parsed model |
| [`CompiledModel`](@ref) | Alias for `ModelSpec` |

### Runtime and agent structures

| Name | Purpose |
| --- | --- |
| [`RuntimeState`](@ref) | Live executable runtime |
| [`Context`](@ref) | Current execution context |
| [`LogoRuntimeError`](@ref) | Runtime error type |
| [`Observer`](@ref) | Observer agent record |
| [`Turtle`](@ref) | Turtle agent record |
| [`Patch`](@ref) | Patch agent record |
| [`Link`](@ref) | Link agent record |
| [`AgentSet`](@ref) | Typed agent collection |

### Enumerations

| Name | Purpose |
| --- | --- |
| [`AgentKind`](@ref) | Agent kind tags used by agentsets and runtime helpers |
| [`TopologyMode`](@ref) | World topology enumeration |
| [`Torus`](@ref) | Wrap on both axes |
| [`VerticalCylinder`](@ref) | Wrap on x only |
| [`HorizontalCylinder`](@ref) | Wrap on y only |
| [`BoxTopology`](@ref) | No wrapping |
