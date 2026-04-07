# Extensions

## Built-in extensions

The package ships with headless implementations for the extensions needed by the compatibility and evaluation suites.

| Extension | Purpose |
| --- | --- |
| `csv` | CSV parsing and serialization helpers |
| `table` | Ordered associative tables with grouping and JSON helpers |
| `nw` | Graph/network algorithms and generators |
| `profiler` | Headless profiler-compatible stubs |
| `sound` | Headless sound primitives and instrument metadata |
| `gis` | Vector/raster GIS loading, transforms, and dataset operations |
| `array` | Mutable indexed arrays |
| `bitmap` | Bitmap creation, file I/O, and base64 conversion |
| `fp` | Functional-programming helpers |
| `matrix` | Matrix operations backed by Julia linear algebra |
| `ls` | LevelSpace-style nested model control |
| `rnd` | Weighted random-selection helpers |
| `store` | JSON-backed persistent key/value stores |
| `time` | Time values, formatting, arithmetic, and scheduling |

Use them from NetLogo source through the usual declaration:

```netlogo
extensions [gis table time]
```

## Extension loading

When a model declares `extensions [...]`, the runtime resolves extension modules by name and invokes either `register_extension!` or `register_primitives!` on the resolved module.

The public low-level registration hook is [`register_primitive!`](@ref), which is what the built-in extension modules use internally to register commands and reporters into a primitive registry.

## External extension modules

External Julia modules can be loaded as extensions if they are visible from the chosen `extension_host` module and define one of the expected registration hooks. This makes it possible to host project-specific extensions beside model code without modifying the `NetLogo.jl` package itself.
