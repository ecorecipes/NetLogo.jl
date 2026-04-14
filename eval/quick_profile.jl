#!/usr/bin/env julia
# Quick profiling script for slow models.
using NetLogo, Printf, Profile

include(joinpath(@__DIR__, "NetLogoCompare.jl"))
using .NetLogoCompare

const MODELS = Dict(
    "elfarol"        => ElFarolModel(),
    "coin"           => CoinModel(),
    "grassbrushtrees"=> GrassBrushTreesModel(),
    "lassavirus"     => LassaVirusModel(),
    "antsystem"      => AntSystemModel(),
    "voter"          => VoterModel(),
    "contactprocess" => ContactProcessModel(),
    "birthrates"     => BirthRatesModel(),
    "firepercolation"=> FirePercolationModel(),
    "langborders"    => LanguageBordersModel(),
    "tourism"        => TourismModel(),
    "ipd"            => IPDModel(),
    "axelrodcultural"=> AxelrodCulturalModel(),
    # Modeling Commons classics
    "dlasimple"      => DLASimpleModel(),
    "boiling"        => BoilingModel(),
    "soliddiffusion" => SolidDiffusionModel(),
    "flocking"       => FlockingModel(),
    "sand"           => SandModel(),
    "rope"           => RopeModel(),
    "polymer"        => PolymerDynamicsModel(),
    "thermostat"     => ThermostatModel(),
    "crystallization"=> CrystallizationModel(),
    "mimicry"        => MimicryModel(),
)

function bench(model; seed=1)
    code = netlogo_code(model); px = world_dims(model)
    topo = NetLogoCompare.runtime_topology_mode(NetLogo, model)
    compiled = compile_model(code); nticks = n_ticks(model)
    rt = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt, "setup"); for _ in 1:min(5, nticks); call!(rt, "go"); end
    rt = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt, "setup")
    t = @elapsed for _ in 1:nticks; call!(rt, "go"); end
    rt2 = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt2, "setup")
    alloc = @allocated for _ in 1:nticks; call!(rt2, "go"); end
    @printf("%-20s %5d ticks  %8.2fs  %8.1f MiB\n", model_name(model), nticks, t, alloc/1024^2)
end

function prof(model; seed=1, ticks=20)
    code = netlogo_code(model); px = world_dims(model)
    topo = NetLogoCompare.runtime_topology_mode(NetLogo, model)
    compiled = compile_model(code); nticks = min(ticks, n_ticks(model))
    rt = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt, "setup"); for _ in 1:min(5, nticks); call!(rt, "go"); end
    rt = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt, "setup")
    Profile.clear()
    @profile for _ in 1:nticks; call!(rt, "go"); end
    println("\n" * "="^70)
    @printf("  Profile: %s (%d ticks)\n", model_name(model), nticks)
    println("="^70)
    Profile.print(noisefloor=2.0, maxdepth=25, mincount=10)
    rt2 = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt2, "setup")
    alloc = @allocated call!(rt2, "go")
    @printf("\n  Single-tick alloc: %.1f KiB (%.1f MiB)\n", alloc/1024, alloc/1024^2)
end

function alloc_prof(model; seed=1, ticks=10, rate=0.001)
    code = netlogo_code(model); px = world_dims(model)
    topo = NetLogoCompare.runtime_topology_mode(NetLogo, model)
    compiled = compile_model(code); nticks = min(ticks, n_ticks(model))
    rt = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt, "setup"); for _ in 1:min(5, nticks); call!(rt, "go"); end
    rt = create_runtime(compiled; seed=seed, min_pxcor=px[1], max_pxcor=px[2], min_pycor=px[3], max_pycor=px[4], topology=topo)
    call!(rt, "setup")
    Profile.Allocs.clear()
    Profile.Allocs.@profile sample_rate=rate begin
        for _ in 1:nticks; call!(rt, "go"); end
    end
    results = Profile.Allocs.fetch()
    type_counts = Dict{String,Tuple{Int,Int}}()
    for a in results.allocs
        t = string(a.type)
        cnt, sz = get(type_counts, t, (0, 0))
        type_counts[t] = (cnt + 1, sz + a.size)
    end
    sorted = sort(collect(type_counts), by=x->x[2][2], rev=true)
    @printf("\nTop allocating types (%s, %d ticks):\n", model_name(model), nticks)
    for (t, (cnt, sz)) in sorted[1:min(15, length(sorted))]
        @printf("  %8.1f KiB  %6d samples  %s\n", sz/1024, cnt, t)
    end
end

if !isempty(ARGS)
    name = ARGS[1]
    if name == "bench"
        names = length(ARGS) >= 2 ? split(ARGS[2], ",") : ["elfarol", "coin", "grassbrushtrees", "lassavirus", "antsystem", "voter", "contactprocess"]
        for n in names; bench(MODELS[String(n)]); end
    elseif name == "allocprof"
        model_name_arg = length(ARGS) >= 2 ? ARGS[2] : "elfarol"
        alloc_prof(MODELS[model_name_arg])
    elseif haskey(MODELS, name)
        prof(MODELS[name])
    else
        error("Unknown: $name")
    end
end
