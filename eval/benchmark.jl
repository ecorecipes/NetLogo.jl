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
  julia --project=. eval/benchmark.jl components 50 20  # Team Assembly CC vignette
"""

using Graphs
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
    # Modeling Commons eval candidates
    "mousetraps"     => MousetrapsModel(),
    "firebenchmark"  => FireBenchmarkModel(),
    "lassavirus"     => LassaVirusModel(),
    "axelrodcultural" => AxelrodCulturalModel(),
    "ethnocentrism"  => EthnocentrismModel(),
    "daisyworld"     => DaisyworldModel(),
    "dla"            => DLAModel(),
)

# Models too slow for full benchmarking — skip unless explicitly named
const SLOW_MODELS = Set(["elfarol", "birthrates", "antsystem", "coin",
                         "contactprocess", "grassbrushtrees", "ipd", "voter",
                         "firepercolation", "mousetraps", "firebenchmark",
                         "lassavirus", "axelrodcultural"])

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
    topology_mode = NetLogoCompare.runtime_topology_mode(NetLogo, model)
    compiled = Base.invokelatest(compile_fn, code)

    # Warmup (compile paths)
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py,
                    topology=topology_mode)
    Base.invokelatest(call_fn, rt, "setup")
    Base.invokelatest(call_fn, rt, "go")

    # Timed run
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py,
                    topology=topology_mode)

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
                     min_pycor=min_py, max_pycor=max_py,
                     topology=topology_mode)
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

# ─── Team Assembly connected-component vignette ───────────────────────

function teamassembly_runtime(compiled, runtime_fn, call_fn, topology_mode; seed::Int=1, ticks::Int=50)
    model = TeamAssemblyModel()
    min_px, max_px, min_py, max_py = world_dims(model)
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py,
                    topology=topology_mode)
    Base.invokelatest(call_fn, rt, "setup")
    for _ in 1:ticks
        Base.invokelatest(call_fn, rt, "go")
    end
    rt
end

function live_team_turtles(world)
    turtles = eltype(world.turtles)[]
    sizehint!(turtles, length(world.turtles))
    for turtle in world.turtles
        turtle.alive && push!(turtles, turtle)
    end
    turtles
end

function team_component_sizes_bespoke(world)
    turtles = live_team_turtles(world)
    isempty(turtles) && return Int[]
    id_to_index = Dict{Int, Int}(turtle.id => i for (i, turtle) in enumerate(turtles))
    seen = falses(length(turtles))
    queue = Int[]
    sizes = Int[]
    sizehint!(sizes, length(turtles))

    for start in eachindex(turtles)
        seen[start] && continue
        empty!(queue)
        push!(queue, start)
        seen[start] = true
        size = 0
        head = 1
        while head <= length(queue)
            current_index = queue[head]
            head += 1
            size += 1
            turtle = turtles[current_index]
            for link in get(world.turtle_links, turtle.id, eltype(world.links)[])
                link.alive || continue
                neighbor_id = link.end1 == turtle.id ? link.end2 : link.end1
                neighbor_index = get(id_to_index, neighbor_id, 0)
                neighbor_index == 0 && continue
                seen[neighbor_index] && continue
                seen[neighbor_index] = true
                push!(queue, neighbor_index)
            end
        end
        push!(sizes, size)
    end

    sort!(sizes)
end

function team_component_sizes_graphs(world)
    turtles = live_team_turtles(world)
    n = length(turtles)
    n == 0 && return Int[]
    id_to_index = Dict{Int, Int}(turtle.id => i for (i, turtle) in enumerate(turtles))
    g = Graphs.SimpleGraph(n)
    for link in world.links
        link.alive || continue
        src = get(id_to_index, link.end1, 0)
        dst = get(id_to_index, link.end2, 0)
        (src == 0 || dst == 0 || src == dst) && continue
        Graphs.add_edge!(g, src, dst)
    end
    sort!([length(component) for component in Graphs.connected_components(g)])
end

function team_component_sizes_interpreter!(rt, call_fn)
    Base.invokelatest(call_fn, rt, "find-all-components")
    raw_sizes = rt.world.observer.globals["COMPONENTS"]
    sort!(Int[round(Int, Float64(size)) for size in raw_sizes])
end

function component_vignette(; ticks::Int=50, reps::Int=20, seed::Int=1)
    NetLogo = Base.require(Main, :NetLogo)
    compile_fn = getfield(NetLogo, :compile_model)
    runtime_fn = getfield(NetLogo, :create_runtime)
    call_fn = getfield(NetLogo, Symbol("call!"))
    topology_mode = NetLogoCompare.runtime_topology_mode(NetLogo, TeamAssemblyModel())
    compiled = Base.invokelatest(compile_fn, netlogo_code(TeamAssemblyModel()))
    rt = teamassembly_runtime(compiled, runtime_fn, call_fn, topology_mode; seed=seed, ticks=ticks)

    interpreter_sizes = team_component_sizes_interpreter!(rt, call_fn)
    bespoke_sizes = team_component_sizes_bespoke(rt.world)
    graphs_sizes = team_component_sizes_graphs(rt.world)

    interpreter_sizes == bespoke_sizes || error("Interpreter and bespoke component sizes diverged: $interpreter_sizes vs $bespoke_sizes")
    bespoke_sizes == graphs_sizes || error("Bespoke and Graphs.jl component sizes diverged: $bespoke_sizes vs $graphs_sizes")

    interp_t = @elapsed for _ in 1:reps
        team_component_sizes_interpreter!(rt, call_fn)
    end
    bespoke_t = @elapsed for _ in 1:reps
        team_component_sizes_bespoke(rt.world)
    end
    graphs_t = @elapsed for _ in 1:reps
        team_component_sizes_graphs(rt.world)
    end

    println("╔════════════════════════════════════════════════════════════════════╗")
    println("║  Team Assembly Connected-Components Vignette                      ║")
    @printf("║  Tick snapshot: %-3d  │  Repetitions: %-3d  │  Seed: %-3d                 ║\n", ticks, reps, seed)
    println("╚════════════════════════════════════════════════════════════════════╝\n")
    println("Component sizes: ", interpreter_sizes)
    println("Giant component: ", isempty(interpreter_sizes) ? 0 : last(interpreter_sizes))
    println()
    @printf("%-18s %12s %12s\n", "Implementation", "Total", "Per run")
    println("─"^44)
    @printf("%-18s %12s %12s\n", "Interpreter", format_time(interp_t), format_time(interp_t / reps))
    @printf("%-18s %12s %12s\n", "Bespoke BFS", format_time(bespoke_t), format_time(bespoke_t / reps))
    @printf("%-18s %12s %12s\n", "Graphs.jl", format_time(graphs_t), format_time(graphs_t / reps))
end

# ─── Profile mode ───────────────────────────────────────────────────

function profile_model(model::AbstractBenchmarkModel; seed::Int=1)
    NetLogo = Base.require(Main, :NetLogo)
    compile_fn = getfield(NetLogo, :compile_model)
    runtime_fn = getfield(NetLogo, :create_runtime)
    call_fn    = getfield(NetLogo, Symbol("call!"))

    code = netlogo_code(model)
    min_px, max_px, min_py, max_py = world_dims(model)
    topology_mode = NetLogoCompare.runtime_topology_mode(NetLogo, model)
    compiled = Base.invokelatest(compile_fn, code)

    # Warmup
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py,
                    topology=topology_mode)
    Base.invokelatest(call_fn, rt, "setup")
    for _ in 1:min(5, n_ticks(model))
        Base.invokelatest(call_fn, rt, "go")
    end

    # Profile run
    rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                    min_pxcor=min_px, max_pxcor=max_px,
                    min_pycor=min_py, max_pycor=max_py,
                    topology=topology_mode)
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
                     min_pycor=min_py, max_pycor=max_py,
                     topology=topology_mode)
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
    elseif length(args) >= 1 && args[1] == "components"
        ticks = length(args) >= 2 ? parse(Int, args[2]) : 50
        reps = length(args) >= 3 ? parse(Int, args[3]) : 20
        seed = length(args) >= 4 ? parse(Int, args[4]) : 1
        component_vignette(; ticks=ticks, reps=reps, seed=seed)
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
