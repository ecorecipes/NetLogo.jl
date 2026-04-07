#!/usr/bin/env julia
"""
Benchmark suite for NetLogo.jl vs Java NetLogo.

Measures:
  - Julia wall-clock time (median of multiple seeds, after warmup)
  - Julia memory allocations (via @allocated)
  - Java wall-clock time (median of multiple seeds)
  - Speed ratio (Java/Julia)
  - Per-tick timings

Usage:
  julia --project=. eval/benchmark.jl [model|all] [n_seeds]
  julia --project=. eval/benchmark.jl sir 10
  julia --project=. eval/benchmark.jl all 5
  julia --project=. eval/benchmark.jl profile sir    # Profile a single model
"""

using Printf
using Statistics
using Profile

# ─── Include comparison framework for model definitions ──────────────
include(joinpath(@__DIR__, "NetLogoCompare.jl"))
using .NetLogoCompare

# ─── Model registry (same as run_comparison.jl) ─────────────────────
const MODELS = Dict(
    "sir"           => SIRModel(),
    "wolfsheep"     => WolfSheepModel(),
    "fire"          => FireModel(),
    "ants"          => AntsModel(),
    "schelling"     => SchellingModel(),
    "ising"         => IsingModel(),
    "party"         => PartyModel(),
    "decay"         => DecayModel(),
    "climate"       => ClimateModel(),
    "diffusion"     => DiffusionModel(),
    "virus"         => VirusModel(),
    "wealth"        => WealthDistModel(),
    "teamassembly"  => TeamAssemblyModel(),
    "tumor"         => TumorModel(),
    "segregation"   => SegregationModel(),
    "elfarol"       => ElFarolModel(),
    "birthrates"    => BirthRatesModel(),
    "marriage"      => MarriageModel(),
    "mailmen"       => MailmenModel(),
    "paretolearn"   => ParetoLearnModel(),
    "coin"          => CoinModel(),
    "antsystem"     => AntSystemModel(),
    "contactprocess"=> ContactProcessModel(),
    "grassbrushtrees"=> GrassBrushTreesModel(),
    "ipd"           => IPDModel(),
    "voter"         => VoterModel(),
    "firepercolation"=> FirePercolationModel(),
    # modsoc models
    "particles"      => ParticlesModel(),
    "modsocseg"      => ModsocSegregationModel(),
    "contagionsi"    => ContagionSIModel(),
    "contagionsir"   => ContagionSIRModel(),
    "opinionbc"      => OpinionBCModel(),
    "pdsimple"       => PDSimpleModel(),
    "coordination"   => CoordinationModel(),
    "bayesian"       => BayesianModel(),
    "coord2groups"   => Coordination2GroupsModel(),
    # ClassModels
    "beinggreen"     => BeingGreenModel(),
    "langborders"    => LanguageBordersModel(),
    "tourism"        => TourismModel(),
    "civgrowth"      => CivilizationGrowthModel(),
    "unitcohesion"   => UnitCohesionModel(),
    "dating"         => DatingModel(),
)

# Models too slow for full benchmarking — skip unless explicitly named
const SLOW_MODELS = Set(["elfarol", "birthrates", "antsystem", "coin",
                         "contactprocess", "grassbrushtrees", "ipd", "voter",
                         "firepercolation"])

# Representative fast models for benchmarking
const BENCH_MODELS = ["sir", "schelling", "ants", "fire", "wolfsheep",
                      "ising", "party", "decay", "climate", "virus",
                      "wealth", "teamassembly", "tumor", "segregation",
                      "diffusion", "mailmen", "paretolearn", "marriage"]

# ─── Julia benchmark ────────────────────────────────────────────────

function benchmark_julia_single(model::AbstractBenchmarkModel, seed::Int)
    NetLogo = Base.require(Main, :NetLogo)
    compile_fn = getfield(NetLogo, :compile_model)
    runtime_fn = getfield(NetLogo, :create_runtime)
    call_fn    = getfield(NetLogo, Symbol("call!"))

    code = netlogo_code(model)
    min_px, max_px, min_py, max_py = world_dims(model)
    compiled = Base.invokelatest(compile_fn, code)

    # Warmup (compile paths)
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py)
    Base.invokelatest(call_fn, rt, "setup")
    Base.invokelatest(call_fn, rt, "go")

    # Timed run
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py)

    # Measure setup
    t_setup = @elapsed Base.invokelatest(call_fn, rt, "setup")

    # Measure allocations for the full run
    alloc_bytes = @allocated begin
        for _ in 1:n_ticks(model)
            Base.invokelatest(call_fn, rt, "go")
        end
    end

    # Timed full run (separate measurement)
    rt2 = Base.invokelatest(runtime_fn, compiled; seed=seed,
                     min_pxcor=min_px, max_pxcor=max_px,
                     min_pycor=min_py, max_pycor=max_py)
    Base.invokelatest(call_fn, rt2, "setup")
    t_go = @elapsed begin
        for _ in 1:n_ticks(model)
            Base.invokelatest(call_fn, rt2, "go")
        end
    end

    return (setup_time=t_setup, go_time=t_go, total_time=t_setup+t_go,
            alloc_bytes=alloc_bytes, n_ticks=n_ticks(model))
end

function benchmark_julia(model::AbstractBenchmarkModel, seeds::Vector{Int})
    # First call is warmup (JIT compilation)
    _ = benchmark_julia_single(model, seeds[1])

    results = [benchmark_julia_single(model, s) for s in seeds]
    return results
end

# ─── Java benchmark ─────────────────────────────────────────────────

function benchmark_java_single(model::AbstractBenchmarkModel, seed::Int)
    dir = NetLogoCompare.netlogo_dir()
    headless = joinpath(dir, "netlogo-headless.sh")
    isfile(headless) || error("netlogo-headless.sh not found at $headless")

    source = nlogo_source(model)
    ticks_n = n_ticks(model)

    tmpdir = mktempdir()
    nlogo_path = joinpath(tmpdir, "benchmark.nlogo")
    table_path = joinpath(tmpdir, "output.csv")

    # Replace seed placeholder with single seed
    src = replace(source, "      __SEEDS_PLACEHOLDER__" =>
                  "      <value value=\"$seed\"/>")
    write(nlogo_path, src)

    cmd = `bash $headless --model $nlogo_path --experiment benchmark --table $table_path --threads 1`
    t = @elapsed begin
        run(pipeline(cmd, stderr=devnull))
    end

    rm(tmpdir; recursive=true, force=true)
    return (total_time=t, n_ticks=ticks_n)
end

function benchmark_java(model::AbstractBenchmarkModel, seeds::Vector{Int})
    results = [benchmark_java_single(model, s) for s in seeds]
    return results
end

# ─── Formatting helpers ─────────────────────────────────────────────

function format_bytes(bytes::Integer)
    if bytes < 1024
        return "$(bytes) B"
    elseif bytes < 1024^2
        return @sprintf("%.1f KiB", bytes / 1024)
    elseif bytes < 1024^3
        return @sprintf("%.1f MiB", bytes / 1024^2)
    else
        return @sprintf("%.2f GiB", bytes / 1024^3)
    end
end

function format_time(seconds::Float64)
    if seconds < 0.001
        return @sprintf("%.1f μs", seconds * 1e6)
    elseif seconds < 1.0
        return @sprintf("%.1f ms", seconds * 1e3)
    else
        return @sprintf("%.2f s", seconds)
    end
end

# ─── Profile mode ───────────────────────────────────────────────────

function profile_model(model::AbstractBenchmarkModel; seed::Int=1)
    NetLogo = Base.require(Main, :NetLogo)
    compile_fn = getfield(NetLogo, :compile_model)
    runtime_fn = getfield(NetLogo, :create_runtime)
    call_fn    = getfield(NetLogo, Symbol("call!"))

    code = netlogo_code(model)
    min_px, max_px, min_py, max_py = world_dims(model)
    compiled = Base.invokelatest(compile_fn, code)

    # Warmup
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py)
    Base.invokelatest(call_fn, rt, "setup")
    for _ in 1:min(5, n_ticks(model))
        Base.invokelatest(call_fn, rt, "go")
    end

    # Profile run
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py)
    Base.invokelatest(call_fn, rt, "setup")

    Profile.clear()
    @profile begin
        for _ in 1:min(20, n_ticks(model))
            Base.invokelatest(call_fn, rt, "go")
        end
    end

    println("\n" * "="^60)
    println("  Profile: $(model_name(model)) ($(min(20, n_ticks(model))) ticks)")
    println("="^60)
    Profile.print(noisefloor=2.0, maxdepth=25, mincount=5)

    # Allocation profile
    println("\n" * "="^60)
    println("  Allocation breakdown (1 tick)")
    println("="^60)
    rt2 = Base.invokelatest(runtime_fn, compiled; seed=seed,
                     min_pxcor=min_px, max_pxcor=max_px,
                     min_pycor=min_py, max_pycor=max_py)
    Base.invokelatest(call_fn, rt2, "setup")
    alloc_1 = @allocated Base.invokelatest(call_fn, rt2, "go")
    @printf("  Single tick: %s\n", format_bytes(alloc_1))
    @printf("  Per tick avg over %d ticks: %s\n", n_ticks(model),
            format_bytes(alloc_1))
end

# ─── Main benchmark runner ──────────────────────────────────────────

function run_benchmarks(model_names::Vector{String}, n_seeds::Int)
    seeds = collect(1:n_seeds)

    println("╔══════════════════════════════════════════════════════════════════════════════════╗")
    println("║  NetLogo.jl Benchmark Suite                                                     ║")
    @printf("║  Models: %d  │  Seeds: %d  │  Warmup: 1 seed                                    ║\n",
            length(model_names), n_seeds)
    println("╚══════════════════════════════════════════════════════════════════════════════════╝\n")

    # Header
    @printf("%-22s %6s %10s %10s %12s %10s %8s\n",
            "Model", "Ticks", "Julia (s)", "Java (s)", "Ratio", "Alloc", "μs/tick")
    println("─"^82)

    results = []

    for name in model_names
        model = MODELS[name]
        print("  $(model_name(model))...")
        flush(stdout)

        # Julia benchmark
        jl_results = benchmark_julia(model, seeds)
        jl_median_time = median([r.total_time for r in jl_results])
        jl_median_go = median([r.go_time for r in jl_results])
        jl_median_alloc = median([r.alloc_bytes for r in jl_results])
        nticks = n_ticks(model)

        # Java benchmark
        jv_results = try
            benchmark_java(model, seeds)
        catch e
            println(" (Java failed: $e)")
            nothing
        end

        jv_median_time = jv_results !== nothing ?
            median([r.total_time for r in jv_results]) : NaN

        ratio = jv_median_time > 0 ? jl_median_time / jv_median_time : NaN
        us_per_tick = jl_median_go / nticks * 1e6

        @printf("\r%-22s %6d %10s %10s %11.1fx %10s %8.0f\n",
                model_name(model), nticks,
                format_time(jl_median_time),
                isnan(jv_median_time) ? "N/A" : format_time(jv_median_time),
                ratio,
                format_bytes(round(Int, jl_median_alloc)),
                us_per_tick)

        push!(results, (
            name=model_name(model),
            ticks=nticks,
            jl_time=jl_median_time,
            jl_go_time=jl_median_go,
            jv_time=jv_median_time,
            ratio=ratio,
            alloc_bytes=round(Int, jl_median_alloc),
            us_per_tick=us_per_tick,
            jl_results=jl_results,
            jv_results=jv_results
        ))
    end

    println("─"^82)

    # Summary statistics
    valid = filter(r -> !isnan(r.ratio), results)
    if !isempty(valid)
        ratios = [r.ratio for r in valid]
        total_alloc = sum(r.alloc_bytes for r in valid)
        @printf("\nSummary (%d models):\n", length(valid))
        @printf("  Median speed ratio (Julia/Java): %.1fx\n", median(ratios))
        @printf("  Mean speed ratio:                %.1fx\n", mean(ratios))
        @printf("  Min ratio:  %.1fx (%s)\n", minimum(ratios),
                valid[argmin(ratios)].name)
        @printf("  Max ratio:  %.1fx (%s)\n", maximum(ratios),
                valid[argmax(ratios)].name)
        @printf("  Total allocations:               %s\n", format_bytes(total_alloc))
    end

    # Save CSV
    csv_path = joinpath(@__DIR__, "results", "benchmark_results.csv")
    mkpath(dirname(csv_path))
    open(csv_path, "w") do io
        println(io, "model,ticks,julia_time_s,julia_go_time_s,java_time_s,ratio,alloc_bytes,us_per_tick")
        for r in results
            @printf(io, "%s,%d,%.4f,%.4f,%.4f,%.2f,%d,%.1f\n",
                    r.name, r.ticks, r.jl_time, r.jl_go_time,
                    isnan(r.jv_time) ? 0.0 : r.jv_time,
                    isnan(r.ratio) ? 0.0 : r.ratio,
                    r.alloc_bytes, r.us_per_tick)
        end
    end
    @printf("\n📁 Saved: %s\n", csv_path)

    return results
end

# ─── CLI entry point ────────────────────────────────────────────────

function main()
    args = ARGS

    if length(args) >= 1 && args[1] == "profile"
        model_name_arg = length(args) >= 2 ? args[2] : "sir"
        haskey(MODELS, model_name_arg) || error("Unknown model: $model_name_arg")
        profile_model(MODELS[model_name_arg])
        return
    end

    model_arg = length(args) >= 1 ? args[1] : "all"
    n_seeds = length(args) >= 2 ? parse(Int, args[2]) : 5

    if model_arg == "all"
        model_names = BENCH_MODELS
    elseif model_arg == "fast"
        model_names = ["sir", "schelling", "fire", "ising", "decay"]
    elseif haskey(MODELS, model_arg)
        model_names = [model_arg]
    else
        error("Unknown model: $model_arg. Use 'all', 'fast', or a model name.")
    end

    run_benchmarks(model_names, n_seeds)
end

main()
