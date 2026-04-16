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
md"""
# Participatory Disinfo NW+Bitstring vignette

This Pluto notebook wraps `eval/models/disinfo_nw_bitstring.jl` in the synthesized NetLogo-style interface used for the vignette rollout.

- **setup** initializes the model
- **go once** advances one tick
- **go** behaves like a NetLogo forever button and stops when the underlying model stops
- monitors and the plot are populated from the benchmark model's tracked globals
- model-specific sliders appear when the support layer defines them
"""

# ╔═╡ d70f6ba9-4d0c-46d0-b6d4-77851a59b385
disinfo_nw_bitstring_seed = 1

# ╔═╡ 5e793407-fd26-4942-9e48-3fb75f835986
begin
  if !isdefined(Main, :DISINFO_NW_BITSTRING_VIGNETTE_BUNDLE)
    const DISINFO_NW_BITSTRING_VIGNETTE_BUNDLE = Ref{Any}(nothing)
  end
  previous = Main.DISINFO_NW_BITSTRING_VIGNETTE_BUNDLE[]
  previous === nothing || NetLogoVignetteSupport.close_bundle!(previous)
  bundle = NetLogoVignetteSupport.benchmark_backend(Symbol("disinfo_nw_bitstring"); seed=disinfo_nw_bitstring_seed, width=1280, height=980)
  Main.DISINFO_NW_BITSTRING_VIGNETTE_BUNDLE[] = bundle
  bundle
end

# ╔═╡ 4d274d98-b66e-4d37-899b-40fe4ec90f69
md"""
**Embedded GUI URL:** $(NetLogo.web_gui_url(bundle.backend))

If you rerun the seed cell above, the notebook tears down the previous local GUI server and starts a fresh Participatory Disinfo NW+Bitstring session.
"""

# ╔═╡ c4edfc0e-f5d2-46d0-b3d8-c55d1cf07d4e
bundle.notebook

# ╔═╡ Cell order:
# ╠═55f4dbe7-02af-476d-9c20-a1f490cf38d5
# ╠═8853fa0b-4f2a-48d4-9d9e-b5e1e5924dda
# ╠═d70f6ba9-4d0c-46d0-b6d4-77851a59b385
# ╠═5e793407-fd26-4942-9e48-3fb75f835986
# ╠═4d274d98-b66e-4d37-899b-40fe4ec90f69
# ╠═c4edfc0e-f5d2-46d0-b3d8-c55d1cf07d4e
