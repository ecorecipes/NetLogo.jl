# Development

## Test the package

Run the full package tests from the package root:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Build the documentation

From the package root:

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

The generated site is written to `docs/build/`.

## GitHub workflows

The package includes:

- `CI.yml` for package tests
- `Documentation.yml` for docs builds and GitHub Pages deployment
- `TagBot.yml` for Julia package release tags after registration

The documentation workflow is configured for `https://github.com/ecorecipes/NetLogo.jl` and deploys with Documenter.jl.
