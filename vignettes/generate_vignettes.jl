#!/usr/bin/env julia

include(joinpath(@__DIR__, "_support.jl"))
using .NetLogoVignetteSupport

function julia_identifier(name::AbstractString)
  replace(String(name), r"[^A-Za-z0-9_]" => "_")
end

function bundle_identifier(name::AbstractString)
  uppercase(julia_identifier(name)) * "_VIGNETTE_BUNDLE"
end

function notebook_template(model_key::Symbol)
  key = String(model_key)
  title = model_title(model_key)
  seed_var = julia_identifier(key) * "_seed"
  bundle_var = bundle_identifier(key)
  """
### A Pluto.jl notebook ###
# v0.20.4

using Markdown
using NetLogo

# ╔═╡ 55f4dbe7-02af-476d-9c20-a1f490cf38d5
begin
  if !isdefined(Main, :NetLogoVignetteSupport)
    include(joinpath(@__DIR__, "..", "_support.jl"))
  end
  using .NetLogoVignetteSupport
end

# ╔═╡ 8853fa0b-4f2a-48d4-9d9e-b5e1e5924dda
md\"\"\"
# $(title) vignette

This Pluto notebook wraps `eval/models/$(key).jl` in the synthesized NetLogo-style interface used for the vignette rollout.

- **setup** initializes the model
- **go once** advances one tick
- **go** behaves like a NetLogo forever button and stops when the underlying model stops
- monitors and the plot are populated from the benchmark model's tracked globals
- model-specific sliders appear when the support layer defines them
\"\"\"

# ╔═╡ d70f6ba9-4d0c-46d0-b6d4-77851a59b385
$(seed_var) = 1

# ╔═╡ 5e793407-fd26-4942-9e48-3fb75f835986
begin
  if !isdefined(Main, :$(bundle_var))
    const $(bundle_var) = Ref{Any}(nothing)
  end
  previous = Main.$(bundle_var)[]
  previous === nothing || NetLogoVignetteSupport.close_bundle!(previous)
  bundle = NetLogoVignetteSupport.benchmark_backend(Symbol(\"$(key)\"); seed=$(seed_var), width=1280, height=980)
  Main.$(bundle_var)[] = bundle
  bundle
end

# ╔═╡ 4d274d98-b66e-4d37-899b-40fe4ec90f69
md\"\"\"
**Embedded GUI URL:** \$(NetLogo.web_gui_url(bundle.backend))

If you rerun the seed cell above, the notebook tears down the previous local GUI server and starts a fresh $(title) session.
\"\"\"

# ╔═╡ c4edfc0e-f5d2-46d0-b3d8-c55d1cf07d4e
bundle.notebook

# ╔═╡ Cell order:
# ╠═55f4dbe7-02af-476d-9c20-a1f490cf38d5
# ╠═8853fa0b-4f2a-48d4-9d9e-b5e1e5924dda
# ╠═d70f6ba9-4d0c-46d0-b6d4-77851a59b385
# ╠═5e793407-fd26-4942-9e48-3fb75f835986
# ╠═4d274d98-b66e-4d37-899b-40fe4ec90f69
# ╠═c4edfc0e-f5d2-46d0-b3d8-c55d1cf07d4e
"""
end

function main()
  generated = 0
  for key in benchmark_model_keys()
    dir = joinpath(@__DIR__, String(key))
    mkpath(dir)
    write(joinpath(dir, "$(key).jl"), notebook_template(key))
    generated += 1
  end
  println("generated\t", generated)
end

main()
