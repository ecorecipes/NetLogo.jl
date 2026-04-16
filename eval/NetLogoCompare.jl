"""
    NetLogoCompare

Stochastic trajectory comparison between the Julia NetLogo.jl port
and the reference Java/Scala NetLogo implementation.

# Usage

    include("eval/NetLogoCompare.jl")
    using .NetLogoCompare
    report = compare_model(SIRModel(); n_reps=30)
    print_report(report)
    save_csv(report, "sir_comparison.csv")
"""
module NetLogoCompare

export AbstractBenchmarkModel, ComparisonReport, CalibratedReport,
       compare_model, compare_model_calibrated,
       print_report, print_calibrated_report, save_csv, save_calibrated_csv,
       model_name, netlogo_code, nlogo_source, n_ticks, tracked_globals,
       pre_setup_commands, topology, world_dims, setup_files,
       SIRModel, WolfSheepModel, DiffusionModel, FireModel,
       SchellingModel, VirusModel,
       # Library models
       SegregationModel, WealthDistModel, ElFarolModel, BirthRatesModel,
       PartyModel, DecayModel, TumorModel, IsingModel, ClimateModel,
       TeamAssemblyModel, AntsModel,
       # netlogomas models
       ParetoLearnModel, CoinModel, AntSystemModel, MarriageModel, MailmenModel,
       # model-zoo models
       ContactProcessModel, GrassBrushTreesModel, IPDModel, VoterModel, FirePercolationModel,
       # modsoc models
       ParticlesModel, ModsocSegregationModel, ContagionSIModel, ContagionSIRModel,
       OpinionBCModel, PDSimpleModel, CoordinationModel, BayesianModel, Coordination2GroupsModel,
       # ClassModels
       BeingGreenModel, LanguageBordersModel, TourismModel, CivilizationGrowthModel,
       UnitCohesionModel, DatingModel,
       # GIS ClassModels
       BombScenarioModel, MultidrugResistantModel, HikingElevationModel,
        DiffusionOfHIVModel, SleuthModel, RiseOfRadicalismModel,
        # Extension models (table, matrix, rnd, nw, profiler, csv)
        CropRotationModel, RationalEvolvingPDModel, SearchPathModel,
        BullwhipEffectModel, InfiniteLifeModel, ResilientTeamModel,
         PrivacyOpinionModel, ArtificialEconomyModel, VoronoiVoterModel,
         CyberspaceOpinionModel, ABTgcModel,
          # Modeling Commons new candidates
          EvolutionOfNormsModel, LassaVirusModel, AxelrodCulturalModel,
          EthnocentrismModel, MousetrapsModel, FireBenchmarkModel,
          # Modeling Commons classic models
          DaisyworldModel, DLAModel, DLASimpleModel, BoilingModel, SolidDiffusionModel, FlockingModel,
          SandModel, RopeModel, PolymerDynamicsModel, ThermostatModel,
          CrystallizationModel, MimicryModel,
         # NW extension eval wrappers
         SuperDiffuserModel, DrugUseModel, ProductsModel, SocialInfluenceModel,
         ParticipatoryDisinformationModel, InfoDiffusionModel,
         RecruitingSupportersModel, GisHillClimberModel, GisBurkinaModel, RhinoPoachingModel,
         # Additional NW extension models
         MinorityBeliefModel, SlowSpreadModel, SpreadingGroupsModel, RecruitingModel,
         FakeNewsModel,
         # Additional extension models (nw, table, rnd)
         FlockingNetworkModel, MisinformationSBFCModel, SimpleMarketModel,
         SpatialAttitudeModel, ContagionNWModel, DiffusionNetworkModel,
         # Array/Matrix extension models
         MinimalSISModel, CulturalDiffusionModel, SugarscapeCultureModel,
         CompetitionLearningModel,
         # Table/Array combo + Table models
         BabySittingModel, WisdomCrowdModel, FungalBioremediationModel,
         # nw+bitstring, matrix+rnd, rnd extension models
         ParticipatoryDisinfoModel, BlackBoxModel, SpatialOpinionModel,
         # table:group-agents, nw generators+modularity, nw network dynamics
         ForestDewdneyModel, SocialNetworkDiffusionModel, DrugUseOverdoseModel,
         # nw weak-component-clusters+metrics, table:remove in go loop
         RecruitingMovementModel, SimpleMarketRandomModel,
         # CSV extension models (csv:from-file, csv:to-file, csv:from-row with file-open)
         CsvPopulationModel, CsvNetworkForagingModel

using Statistics
using Printf
using Random

# ── Configuration ──────────────────────────────────────────────────────

const NETLOGO_DIR = Ref{String}("")

function netlogo_dir()
    if isempty(NETLOGO_DIR[])
        candidates = [
            joinpath(@__DIR__, "..", "..", "NetLogo-dist", "NetLogo-6.4.0-64"),
            joinpath(@__DIR__, "..", "NetLogo-dist", "NetLogo-6.4.0-64"),
        ]
        for c in candidates
            if isdir(c)
                NETLOGO_DIR[] = c
                return c
            end
        end
        error("""NetLogo installation not found.
Set NetLogoCompare.NETLOGO_DIR[] = "/path/to/NetLogo-6.4.0-64" """)
    end
    NETLOGO_DIR[]
end

# ── Abstract model protocol ───────────────────────────────────────────

abstract type AbstractBenchmarkModel end
abstract type FileBenchmarkModel <: AbstractBenchmarkModel end

"""Return the full .nlogo file content (code + BehaviorSpace XML)."""
function nlogo_source end

"""Return just the NetLogo code for the Julia runtime."""
function netlogo_code end

"""Return the backing .nlogo path for file-backed models."""
function nlogo_path end

"""Return the list of global variable names to track each tick."""
function tracked_globals end

"""Return the number of ticks to run."""
function n_ticks end

"""Return a human-readable model name."""
function model_name end

"""Return optional extra turtle shape definitions (default: empty)."""
extra_shapes(::AbstractBenchmarkModel) = ""

"""Create auxiliary files (e.g. CSV data) in the given directory before running.
   Called for both Julia and Java runners. Default: no files needed."""
setup_files(::AbstractBenchmarkModel, ::AbstractString) = nothing

"""Return world dimensions as (min_px, max_px, min_py, max_py). Default: -16..16."""
world_dims(::AbstractBenchmarkModel) = (-16, 16, -16, 16)

"""Return world topology as (wrap_x, wrap_y). Default: torus (true, true)."""
topology(::AbstractBenchmarkModel) = (true, true)

function runtime_topology_mode(NetLogo::Module, model::AbstractBenchmarkModel)
    wrap_x, wrap_y = topology(model)
    if wrap_x
        wrap_y ? getfield(NetLogo, :Torus) : getfield(NetLogo, :VerticalCylinder)
    else
        wrap_y ? getfield(NetLogo, :HorizontalCylinder) : getfield(NetLogo, :BoxTopology)
    end
end

"""Return NetLogo commands to run before setup (e.g., widget defaults). Default: empty."""
pre_setup_commands(::AbstractBenchmarkModel) = ""

"""Return the setup procedure name. Default: setup."""
setup_command(::AbstractBenchmarkModel) = "setup"

"""Return the go procedure name. Default: go."""
go_command(::AbstractBenchmarkModel) = "go"

const SEP = "@#\$#@#\$#@"

project_root() = normpath(joinpath(@__DIR__, "..", ".."))
modelingcommons_root() = joinpath(project_root(), "modelingcommons")

function nlogo_sections(source::AbstractString)
    parts = split(String(source), SEP; keepempty=true)
    length(parts) >= 11 || error("Source does not look like a full .nlogo model")
    parts
end

nlogo_section(source::AbstractString, index::Int) = nlogo_sections(source)[index]

function replace_nlogo_section(source::AbstractString, index::Int, replacement::AbstractString)
    parts = nlogo_sections(source)
    parts[index] = "\n" * String(replacement) * "\n"
    join(parts, SEP)
end

function full_nlogo_source(model::FileBenchmarkModel)
    read(nlogo_path(model), String)
end

function ensure_random_seed_inputbox(source::AbstractString)
    code = nlogo_section(source, 1)
    widgets = strip(nlogo_section(source, 2))
    has_random_seed_global = occursin(r"globals\s*\[.*\brandomSeed\b"si, code)
    has_random_seed_widget = occursin(r"(?m)^randomSeed$", widgets)
    (has_random_seed_global || has_random_seed_widget) && return String(source)

    inputbox = """INPUTBOX
10
460
170
520
randomSeed
0.0
1
0
Number
"""
    replacement = isempty(widgets) ? inputbox : widgets * "\n\n" * inputbox
    replace_nlogo_section(source, 2, replacement)
end

function turtle_shapes_text(model::AbstractBenchmarkModel)
    extra_shapes(model)
end

function turtle_shapes_text(model::FileBenchmarkModel)
    strip(nlogo_section(full_nlogo_source(model), 4))
end

function build_behaviorspace_xml(
    model::AbstractBenchmarkModel;
    fixed_seed::Union{Nothing, Int}=nothing,
    seed_values::Union{Nothing, Vector{Int}}=nothing,
    seed_placeholder::Bool=false)
    metrics = join(["    <metric>$g</metric>" for g in tracked_globals(model)], "\n")
    metric_block = isempty(metrics) ? "" : metrics * "\n"
    pre_cmds = strip(pre_setup_commands(model))
    seed_line = fixed_seed === nothing ? "random-seed randomSeed" : "random-seed $fixed_seed"
    setup_proc = strip(setup_command(model))
    setup_block = isempty(pre_cmds) ? "$seed_line\n$setup_proc" : "$pre_cmds\n$seed_line\n$setup_proc"
    go_proc = strip(go_command(model))
    seed_block = ""
    if seed_values !== nothing
        values = join(["      <value value=\"$seed\"/>" for seed in seed_values], "\n")
        seed_block = """    <enumeratedValueSet variable="randomSeed">
$values
    </enumeratedValueSet>
"""
    elseif seed_placeholder && fixed_seed === nothing
        seed_block = """    <enumeratedValueSet variable="randomSeed">
      __SEEDS_PLACEHOLDER__
    </enumeratedValueSet>
"""
    end
    """<experiments>
  <experiment name="benchmark" repetitions="1" runMetricsEveryStep="true">
    <setup>$(setup_block)</setup>
    <go>$(go_proc)</go>
    <timeLimit steps="$(n_ticks(model))"/>
$(metric_block)$(seed_block)  </experiment>
</experiments>
"""
end

netlogo_code(model::FileBenchmarkModel) = strip(nlogo_section(full_nlogo_source(model), 1))

function nlogo_source(model::FileBenchmarkModel)
    source = full_nlogo_source(model)
    source = replace_nlogo_section(source, 5, "NetLogo 6.4.0")
    source = ensure_random_seed_inputbox(source)
    replace_nlogo_section(source, 8, build_behaviorspace_xml(model; seed_placeholder=true))
end

"""Build a well-formed .nlogo file with BehaviorSpace experiment."""
function nlogo_source(model::AbstractBenchmarkModel)
    code = netlogo_code(model)
    min_px, max_px, min_py, max_py = world_dims(model)
    wrap_x, wrap_y = topology(model)

    # Section 1: Code
    buf = IOBuffer()
    print(buf, code, "\n")

    # Section 2: Interface widgets
    print(buf, SEP, "\n")
    # GRAPHICS-WINDOW format: see NetLogo source WidgetReader.scala
    # Lines: type, left, top, right, bottom, old-max-x(-1), old-max-y(-1),
    #   patch-size, ?, font-size, ?, ?, ?, ?, wrap-x, wrap-y, ?,
    #   min-pxcor, max-pxcor, min-pycor, max-pycor, ?, ?, tick-on, tick-label, framerate
    wx = wrap_x ? 1 : 0
    wy = wrap_y ? 1 : 0
    print(buf, """GRAPHICS-WINDOW
210
10
649
450
-1
-1
13.0
1
10
1
1
1
0
$(wx)
$(wy)
1
$(min_px)
$(max_px)
$(min_py)
$(max_py)
1
1
1
ticks
30.0
""")

    # Only add INPUTBOX for randomSeed if not already in the model's globals declaration
    if !occursin(r"globals\s*\[.*\brandomSeed\b"si, code)
        print(buf, "\nINPUTBOX\n10\n460\n170\n520\nrandomSeed\n0.0\n1\n0\nNumber\n")
    end

    # Section 3: Info tab (empty)
    print(buf, SEP, "\n")
    print(buf, "\n")

    # Section 4: Turtle shapes
    print(buf, SEP, "\n")
    print(buf, """default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

circle
false
0
Circle -7500403 true true 0 0 300

square
false
0
Rectangle -7500403 true true 30 30 270 270

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

mouse side
false
0
Circle -7500403 true true 0 0 300
""")
    if !isempty(extra_shapes(model))
        print(buf, "\n", extra_shapes(model), "\n")
    end

    # Section 5: Version
    print(buf, SEP, "\n")
    print(buf, "NetLogo 6.4.0\n")

    # Section 6: Preview commands (empty)
    print(buf, SEP, "\n")
    print(buf, "\n")

    # Section 7: System dynamics (empty)
    print(buf, SEP, "\n")
    print(buf, "\n")

    # Section 8: BehaviorSpace XML
    print(buf, SEP, "\n")
    print(buf, build_behaviorspace_xml(model; seed_placeholder=true))

    # Section 9: HubNet client (empty)
    print(buf, SEP, "\n")
    print(buf, "\n")

    # Section 10: Link shapes
    print(buf, SEP, "\n")
    print(buf, """default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
""")

    # Section 11: Model settings
    print(buf, SEP, "\n")
    print(buf, "0\n")
    print(buf, SEP, "\n")

    String(take!(buf))
end

# ── Data structures ───────────────────────────────────────────────────

struct TrajectoryData
    seed::Int
    ticks::Vector{Int}
    values::Dict{String, Vector{Float64}}
end

struct VariableComparison
    name::String
    julia_mean::Vector{Float64}        # mean trajectory across reps
    julia_std::Vector{Float64}
    java_mean::Vector{Float64}
    java_std::Vector{Float64}
    # ── Mean trajectory metrics ──
    mae_mean_traj::Float64             # MAE between mean trajectories
    nmae_mean_traj::Float64            # normalized MAE (÷ range of java mean)
    corr_mean_traj::Float64            # Pearson r of mean trajectories
    # ── Final-tick distributional metrics ──
    ks_statistic::Float64              # KS stat on final-tick samples
    ecdf_corr::Float64                 # Pearson r of empirical CDFs
    qq_corr::Float64                   # Pearson r of QQ (rank-paired) values
    # ── Trajectory-level MMD ──
    mmd_stat::Float64                  # unbiased MMD² on full trajectories
    mmd_pvalue::Float64                # permutation test p-value
    # ── Summary stat comparison ──
    julia_final_mean::Float64
    java_final_mean::Float64
    julia_final_std::Float64
    java_final_std::Float64
    julia_final_median::Float64
    java_final_median::Float64
end

struct ComparisonReport
    model_name::String
    n_reps::Int
    n_ticks::Int
    seeds::Vector{Int}
    julia_trajectories::Vector{TrajectoryData}
    java_trajectories::Vector{TrajectoryData}
    comparisons::Vector{VariableComparison}
    julia_time_s::Float64
    java_time_s::Float64
end

# ── Julia runner ──────────────────────────────────────────────────────

function _read_tracked_global(rt, g::String, runresult_fn)
    ug = uppercase(g)
    v = get(rt.world.observer.globals, ug, nothing)
    if v !== nothing
        return Float64(v)
    end
    # Not a stored global — evaluate as a reporter expression
    try
        result = Base.invokelatest(runresult_fn, rt, g)
        return Float64(result)
    catch
        return 0.0
    end
end

function run_julia_trajectories(model::AbstractBenchmarkModel, seeds::Vector{Int})
    NetLogo = Base.require(Main, :NetLogo)
    compile_fn = getfield(NetLogo, :compile_model)
    runtime_fn = getfield(NetLogo, :create_runtime)
    call_fn    = getfield(NetLogo, Symbol("call!"))
    run_commands_fn = getfield(NetLogo, Symbol("run_commands!"))

    source = model isa FileBenchmarkModel ? full_nlogo_source(model) : netlogo_code(model)
    source_path = model isa FileBenchmarkModel ? nlogo_path(model) : nothing
    globals = tracked_globals(model)
    ticks_n = n_ticks(model)
    min_px, max_px, min_py, max_py = world_dims(model)
    topology_mode = runtime_topology_mode(NetLogo, model)
    pre_setup = strip(pre_setup_commands(model))
    setup_proc = setup_command(model)
    go_proc = go_command(model)

    compiled = if source_path === nothing
        Base.invokelatest(compile_fn, source)
    else
        Base.invokelatest(compile_fn, source; source_path=source_path)
    end
    trajectories = TrajectoryData[]

    # Check if any tracked globals are reporter expressions (not stored globals)
    # We need runresult for those
    runresult_fn = nothing
    try
        runresult_fn = getfield(NetLogo, :runresult)
    catch
    end

    # Create a temp working directory for models that use file I/O
    tmpdir = mktempdir()
    setup_files(model, tmpdir)
    saved_cwd = pwd()

    try
    cd(tmpdir)

    for seed in seeds
        rt = Base.invokelatest(runtime_fn, compiled; seed=seed,
                        min_pxcor=min_px, max_pxcor=max_px,
                        min_pycor=min_py, max_pycor=max_py,
                        topology=topology_mode)
        isempty(pre_setup) || Base.invokelatest(run_commands_fn, rt, pre_setup)
        Base.invokelatest(run_commands_fn, rt, "random-seed $seed")
        Base.invokelatest(call_fn, rt, setup_proc)

        tick_nums = Int[0]
        vals = Dict{String, Vector{Float64}}(
            g => Float64[_read_tracked_global(rt, g, runresult_fn)]
            for g in globals)

        for t in 1:ticks_n
            stopped = Base.invokelatest(call_fn, rt, go_proc)
            push!(tick_nums, t)
            for g in globals
                push!(vals[g], _read_tracked_global(rt, g, runresult_fn))
            end
            if stopped === true
                # Model called stop — fill remaining ticks with final values
                for t2 in (t+1):ticks_n
                    push!(tick_nums, t2)
                    for g in globals
                        push!(vals[g], last(vals[g]))
                    end
                end
                break
            end
        end

        push!(trajectories, TrajectoryData(seed, tick_nums, vals))
    end

    finally
        cd(saved_cwd)
        rm(tmpdir; recursive=true, force=true)
    end

    trajectories
end

# ── Java runner via BehaviorSpace ─────────────────────────────────────

function run_java_trajectories(model::AbstractBenchmarkModel, seeds::Vector{Int})
    dir = netlogo_dir()
    headless = joinpath(dir, "netlogo-headless.sh")
    isfile(headless) || error("netlogo-headless.sh not found at $headless")

    tmpdir = mktempdir()
    nlogo_path = joinpath(tmpdir, "benchmark.nlogo")
    table_path = joinpath(tmpdir, "output.csv")

    # Create any auxiliary files the model needs (e.g., CSV data files)
    setup_files(model, tmpdir)

    # Write the .nlogo file with seeds embedded as BehaviorSpace <value> tags
    src = nlogo_source(model)
    seed_values = join(["      <value value=\"$s\"/>" for s in seeds], "\n")
    src = replace(src, "      __SEEDS_PLACEHOLDER__" => seed_values)
    write(nlogo_path, src)

    cmd = `bash $headless --model $nlogo_path --experiment benchmark --table $table_path --threads 1`
    try
        run(pipeline(cmd, stderr=devnull))
    catch e
        # Try to read any output for diagnostics
        if isfile(table_path)
            @warn "Java runner had errors but produced output — attempting to parse"
        else
            rm(tmpdir; recursive=true, force=true)
            rethrow(e)
        end
    end

    trajs = parse_behaviorsearch_csv(table_path, tracked_globals(model))
    rm(tmpdir; recursive=true, force=true)
    trajs
end

function parse_behaviorsearch_csv(path::String, globals::Vector{String})
    lines = readlines(path)

    # Find the CSV header (starts with "[run number]")
    header_idx = 0
    for (i, line) in enumerate(lines)
        if occursin("[run number]", line)
            header_idx = i
            break
        end
    end
    header_idx == 0 && error("Could not find CSV header in BehaviorSpace output")

    header = csv_split(lines[header_idx])
    run_col  = findfirst(h -> occursin("run number", h), header)
    step_col = findfirst(h -> occursin("[step]", h), header)
    seed_col = findfirst(h -> occursin("randomSeed", h), header)

    global_cols = Dict{String, Int}()
    for g in globals
        idx = findfirst(h -> lowercase(strip(h, '"')) == lowercase(g), header)
        idx !== nothing && (global_cols[g] = idx)
    end

    # Group data by run number
    runs = Dict{Int, Tuple{Int, Vector{Int}, Dict{String, Vector{Float64}}}}()

    for i in (header_idx+1):length(lines)
        line = strip(lines[i])
        isempty(line) && continue
        fields = csv_split(line)

        run_num = tryparse(Int, fields[run_col])
        step    = tryparse(Int, fields[step_col])
        seed_v  = seed_col !== nothing ? tryparse(Int, fields[seed_col]) : 0
        (run_num === nothing || step === nothing) && continue

        if !haskey(runs, run_num)
            runs[run_num] = (something(seed_v, 0), Int[],
                             Dict{String, Vector{Float64}}(g => Float64[] for g in globals))
        end

        _, ticks, values = runs[run_num]
        push!(ticks, step)
        for g in globals
            col = get(global_cols, g, 0)
            v = (col > 0 && col <= length(fields)) ? tryparse(Float64, fields[col]) : nothing
            push!(values[g], something(v, NaN))
        end
    end

    [TrajectoryData(seed, ticks, vals)
     for (_, (seed, ticks, vals)) in sort(collect(runs), by=first)]
end

function csv_split(line::AbstractString)
    fields = String[]
    buf = IOBuffer()
    in_q = false
    for c in line
        if in_q
            c == '"' ? (in_q = false) : write(buf, c)
        else
            if c == '"'; in_q = true
            elseif c == ','; push!(fields, String(take!(buf)))
            else write(buf, c)
            end
        end
    end
    push!(fields, String(take!(buf)))
    fields
end

# ── Statistics ────────────────────────────────────────────────────────

"""Two-sample Kolmogorov-Smirnov statistic."""
function ks_statistic(a::Vector{Float64}, b::Vector{Float64})
    sa = sort(filter(!isnan, a))
    sb = sort(filter(!isnan, b))
    na, nb = length(sa), length(sb)
    (na == 0 || nb == 0) && return NaN
    all_v = sort(unique(vcat(sa, sb)))
    maximum(abs(searchsortedlast(sa, v)/na - searchsortedlast(sb, v)/nb) for v in all_v)
end

"""Pearson correlation; returns NaN for constant/empty inputs."""
function pearson_r(x::Vector{Float64}, y::Vector{Float64})
    fx = filter(!isnan, x)
    fy = filter(!isnan, y)
    n = min(length(fx), length(fy))
    n < 2 && return NaN
    a, b = fx[1:n], fy[1:n]
    (std(a) < 1e-15 || std(b) < 1e-15) && return (std(a) < 1e-15 && std(b) < 1e-15) ? 1.0 : NaN
    cor(a, b)
end

"""
Correlation of empirical CDFs evaluated at the sorted union of both samples.
Returns Pearson r between the two ECDF step functions.
"""
function ecdf_correlation(a::Vector{Float64}, b::Vector{Float64})
    sa = sort(filter(!isnan, a))
    sb = sort(filter(!isnan, b))
    na, nb = length(sa), length(sb)
    (na < 2 || nb < 2) && return NaN
    pts = sort(unique(vcat(sa, sb)))
    length(pts) < 2 && return NaN
    ecdf_a = Float64[searchsortedlast(sa, v) / na for v in pts]
    ecdf_b = Float64[searchsortedlast(sb, v) / nb for v in pts]
    pearson_r(ecdf_a, ecdf_b)
end

"""
QQ correlation: sort both samples, pair by rank, compute Pearson r.
For equal-sized samples this is the standard QQ correlation.
For unequal sizes, linearly interpolate the smaller to match the larger.
"""
function qq_correlation(a::Vector{Float64}, b::Vector{Float64})
    sa = sort(filter(!isnan, a))
    sb = sort(filter(!isnan, b))
    na, nb = length(sa), length(sb)
    (na < 3 || nb < 3) && return NaN
    # Interpolate both to common quantile grid
    n_pts = max(na, nb)
    probs = range(0.0, 1.0, length=n_pts)
    qa = quantile_at.(Ref(sa), probs)
    qb = quantile_at.(Ref(sb), probs)
    pearson_r(qa, qb)
end

"""Linear interpolation quantile (like R's type=7)."""
function quantile_at(sorted::Vector{Float64}, p::Float64)
    n = length(sorted)
    n == 0 && return NaN
    n == 1 && return sorted[1]
    h = (n - 1) * p + 1.0
    lo = clamp(floor(Int, h), 1, n)
    hi = clamp(lo + 1, 1, n)
    sorted[lo] + (h - lo) * (sorted[hi] - sorted[lo])
end

# ── Maximum Mean Discrepancy (MMD) on trajectories ───────────────────

"""
    mmd_rbf(X, Y; n_perms=500) -> (mmd², p_value)

Compute the unbiased MMD² between two sets of trajectories using a Gaussian
RBF kernel with the median heuristic for bandwidth selection.

Each row of X (m×T) and Y (n×T) is a single trajectory of length T ticks.
Returns the unbiased MMD² statistic and a permutation-test p-value.
"""
function mmd_rbf(X::Matrix{Float64}, Y::Matrix{Float64}; n_perms::Int=500)
    m, T = size(X)
    n = size(Y, 1)
    (m < 2 || n < 2) && return (NaN, NaN)

    # Pre-compute pairwise squared L2 distances for bandwidth selection
    combined = vcat(X, Y)                        # (m+n) × T
    N = m + n
    D2 = _pairwise_sq_dists(combined)            # N×N

    # Median heuristic: σ² = median of nonzero pairwise distances
    upper = Float64[]
    for i in 1:N, j in (i+1):N
        D2[i,j] > 0.0 && push!(upper, D2[i,j])
    end
    isempty(upper) && return (0.0, 1.0)
    sigma2 = median(upper)
    sigma2 < 1e-30 && return (0.0, 1.0)

    # Compute kernel matrix K (Gaussian RBF)
    K = exp.(-D2 ./ (2.0 * sigma2))

    # Unbiased MMD² from kernel matrix with index sets A=1:m, B=m+1:N
    observed = _mmd2_from_kernel(K, 1:m, (m+1):N)

    # Permutation test
    perm_count = 0
    idxs = collect(1:N)
    for _ in 1:n_perms
        shuffle!(idxs)
        perm_val = _mmd2_from_kernel(K, @view(idxs[1:m]), @view(idxs[m+1:N]))
        perm_val >= observed && (perm_count += 1)
    end
    p_value = (perm_count + 1) / (n_perms + 1)   # +1 for continuity correction

    (observed, p_value)
end

"""Pairwise squared Euclidean distances between rows of X."""
function _pairwise_sq_dists(X::Matrix{Float64})
    N = size(X, 1)
    norms = sum(X .^ 2, dims=2)  # N×1
    # ||xᵢ - xⱼ||² = ||xᵢ||² + ||xⱼ||² - 2 xᵢ·xⱼ
    D2 = norms .+ norms' .- 2.0 .* (X * X')
    # Clamp numerical noise
    D2 .= max.(D2, 0.0)
    D2
end

"""Unbiased MMD² given a pre-computed kernel matrix and index sets."""
function _mmd2_from_kernel(K::Matrix{Float64}, A, B)
    m = length(A)
    n = length(B)
    # Σ k(xᵢ,xⱼ) for i≠j in A
    sum_AA = 0.0
    for i in A, j in A
        i != j && (sum_AA += K[i, j])
    end
    # Σ k(yᵢ,yⱼ) for i≠j in B
    sum_BB = 0.0
    for i in B, j in B
        i != j && (sum_BB += K[i, j])
    end
    # Σ k(xᵢ,yⱼ) for all cross-pairs
    sum_AB = 0.0
    for i in A, j in B
        sum_AB += K[i, j]
    end
    sum_AA / (m * (m - 1)) + sum_BB / (n * (n - 1)) - 2.0 * sum_AB / (m * n)
end

"""In-place Fisher-Yates shuffle."""
function shuffle!(v::Vector{Int})
    for i in length(v):-1:2
        j = rand(1:i)
        v[i], v[j] = v[j], v[i]
    end
    v
end

"""
    trajectory_mmd(jl_trajs, jv_trajs, global_name, nticks; n_perms=500)

Extract the trajectory for `global_name` from each replicate, form
m×T and n×T matrices, and compute MMD² with permutation p-value.
Trajectories shorter than nticks are padded with their final value
(appropriate for models that `stop` early — values are constant after stop).
"""
function trajectory_mmd(jl::Vector{TrajectoryData}, jv::Vector{TrajectoryData},
                        g::String, nticks::Int; n_perms::Int=500)
    T = nticks + 1   # include tick 0
    function extract_matrix(trajs)
        rows = Vector{Float64}[]
        for traj in trajs
            series = padded_trajectory_series(traj, g, nticks)
            series === nothing && continue
            push!(rows, series)
        end
        isempty(rows) && return Matrix{Float64}(undef, 0, 0)
        reduce(vcat, [r' for r in rows])  # m × T
    end
    X = extract_matrix(jl)
    Y = extract_matrix(jv)
    (size(X, 1) < 2 || size(Y, 1) < 2) && return (NaN, NaN)
    mmd_rbf(X, Y; n_perms=n_perms)
end

function padded_trajectory_series(traj::TrajectoryData, g::String, nticks::Int)
    values = get(traj.values, g, Float64[])
    isempty(values) && return nothing
    limit = nticks + 1
    series = Vector{Float64}(undef, limit)
    final_value = Float64(values[min(length(values), length(traj.ticks))])
    fill!(series, final_value)
    for (i, tick) in enumerate(traj.ticks)
        i > length(values) && break
        0 <= tick <= nticks || continue
        series[tick + 1] = Float64(values[i])
    end
    series
end

function compute_comparisons(jl::Vector{TrajectoryData}, jv::Vector{TrajectoryData},
                             globals::Vector{String}, nticks::Int)
    comparisons = VariableComparison[]
    for g in globals
        jl_by_tick = [Float64[] for _ in 0:nticks]
        jv_by_tick = [Float64[] for _ in 0:nticks]

        for traj in jl
            series = padded_trajectory_series(traj, g, nticks)
            series === nothing && continue
            for t in 0:nticks
                push!(jl_by_tick[t+1], series[t+1])
            end
        end
        for traj in jv
            series = padded_trajectory_series(traj, g, nticks)
            series === nothing && continue
            for t in 0:nticks
                push!(jv_by_tick[t+1], series[t+1])
            end
        end

        safe_mean(x) = (f = filter(!isnan, x); isempty(f) ? NaN : mean(f))
        safe_std(x)  = (f = filter(!isnan, x); length(f) < 2 ? 0.0 : std(f))
        safe_median(x) = (f = filter(!isnan, x); isempty(f) ? NaN : median(f))

        jl_m = safe_mean.(jl_by_tick)
        jl_s = safe_std.(jl_by_tick)
        jv_m = safe_mean.(jv_by_tick)
        jv_s = safe_std.(jv_by_tick)

        # MAE of mean trajectories
        diffs = abs.(jl_m .- jv_m)
        fd = filter(!isnan, diffs)
        mae = isempty(fd) ? NaN : mean(fd)

        # Normalized MAE (÷ range of Java mean trajectory, with floor)
        jv_clean = filter(!isnan, jv_m)
        val_range = isempty(jv_clean) ? 1.0 : max(maximum(jv_clean) - minimum(jv_clean), 1.0)
        nmae = mae / val_range

        # Pearson r of mean trajectories
        r_traj = pearson_r(jl_m, jv_m)

        # Final-tick samples
        final_jl = Float64[last(get(t.values, g, [NaN])) for t in jl]
        final_jv = Float64[last(get(t.values, g, [NaN])) for t in jv]

        # MMD on full trajectories
        mmd2, mmd_p = trajectory_mmd(jl, jv, g, nticks; n_perms=500)

        push!(comparisons, VariableComparison(
            g, jl_m, jl_s, jv_m, jv_s,
            mae, nmae, r_traj,
            ks_statistic(final_jl, final_jv),
            ecdf_correlation(final_jl, final_jv),
            qq_correlation(final_jl, final_jv),
            mmd2, mmd_p,
            safe_mean(final_jl), safe_mean(final_jv),
            safe_std(final_jl), safe_std(final_jv),
            safe_median(final_jl), safe_median(final_jv)))
    end
    comparisons
end

# ── Main entry point ──────────────────────────────────────────────────

function compare_model(model::AbstractBenchmarkModel;
                       n_reps::Int=20,
                       seeds::Union{Nothing, Vector{Int}}=nothing)
    actual_seeds = seeds !== nothing ? seeds : collect(1:n_reps)
    n = length(actual_seeds)
    nticks = n_ticks(model)

    println("╔══════════════════════════════════════════════════╗")
    println("║  Comparing: $(model_name(model))")
    println("║  Replications: $n  │  Ticks: $nticks")
    println("╚══════════════════════════════════════════════════╝")

    println("\n▶ Running Julia implementation...")
    t_jl = @elapsed jl = run_julia_trajectories(model, actual_seeds)
    @printf("  ✓ Julia: %.2f s (%.3f s/rep)\n", t_jl, t_jl/n)

    println("\n▶ Running Java implementation...")
    t_jv = @elapsed jv = run_java_trajectories(model, actual_seeds)
    @printf("  ✓ Java:  %.2f s (%.3f s/rep)\n", t_jv, t_jv/n)

    println("\n▶ Computing statistical comparisons...")
    comps = compute_comparisons(jl, jv, tracked_globals(model), nticks)

    ComparisonReport(model_name(model), n, nticks, actual_seeds, jl, jv, comps, t_jl, t_jv)
end

# ── Reporting ─────────────────────────────────────────────────────────

function verdict(c::VariableComparison)
    final_exact =
        (isnan(c.ks_statistic) || c.ks_statistic < 1e-8) &&
        (isnan(c.ecdf_corr) || c.ecdf_corr > 0.999999) &&
        (isnan(c.qq_corr) || c.qq_corr > 0.999999) &&
        (isnan(c.mmd_pvalue) || c.mmd_pvalue > 0.05)
    # Deterministic/exact match: trajectory and final distribution agree
    if c.nmae_mean_traj < 1e-8 && c.mae_mean_traj < 1e-8 && final_exact
        return :exact
    end
    # Strong match: high trajectory correlation + low NMAE + MMD non-significant
    traj_ok   = c.corr_mean_traj > 0.99
    nmae_ok   = c.nmae_mean_traj < 0.10
    ecdf_ok   = c.ecdf_corr > 0.90 || isnan(c.ecdf_corr)
    ks_ok     = c.ks_statistic < 0.20
    mmd_ok    = c.mmd_pvalue > 0.05 || isnan(c.mmd_pvalue)
    if traj_ok && nmae_ok && (ecdf_ok || ks_ok) && mmd_ok
        return :pass
    end
    # Acceptable: decent trajectory correlation + moderate NMAE + MMD marginal
    if c.corr_mean_traj > 0.95 && c.nmae_mean_traj < 0.20
        return :marginal
    end
    return :divergent
end

verdict_symbol(v::Symbol) = v == :exact ? "══" : v == :pass ? "✓ " : v == :marginal ? "~ " : "✗ "

function print_report(r::ComparisonReport)
    println()
    println("┌──────────────────────────────────────────────────────────────────────────────┐")
    @printf("│  %s — %d reps × %d ticks\n", r.model_name, r.n_reps, r.n_ticks)
    @printf("│  Julia: %.2fs  │  Java: %.2fs  │  Speedup: %.1f×\n",
            r.julia_time_s, r.java_time_s,
            r.java_time_s > 0 ? r.java_time_s / r.julia_time_s : NaN)
    println("├──────────────────────────────────────────────────────────────────────────────┤")
    println("│  MEAN TRAJECTORY COMPARISON                                                 │")
    println("├──────────────────────┬──────────┬──────────┬──────────┬──────────┬───────────┤")
    println("│  Variable            │   MAE    │   NMAE   │   r(μ)   │   KS     │  Verdict  │")
    println("├──────────────────────┼──────────┼──────────┼──────────┼──────────┼───────────┤")
    for c in r.comparisons
        v = verdict(c)
        @printf("│  %-20s│ %8.3f │ %8.5f │ %8.5f │ %8.4f │    %s     │\n",
                c.name[1:min(20,end)], c.mae_mean_traj, c.nmae_mean_traj,
                c.corr_mean_traj, c.ks_statistic, verdict_symbol(v))
    end
    println("├──────────────────────┴──────────┴──────────┴──────────┴──────────┴───────────┤")
    println("│  TRAJECTORY MMD (RBF kernel, median heuristic, 500 permutations)             │")
    println("├──────────────────────┬──────────────┬──────────────┬─────────────────────────┤")
    println("│  Variable            │     MMD²     │   p-value    │  Interpretation         │")
    println("├──────────────────────┼──────────────┼──────────────┼─────────────────────────┤")
    for c in r.comparisons
        interp = isnan(c.mmd_pvalue) ? "insufficient data" :
                 c.mmd_pvalue > 0.10 ? "✓ not significant" :
                 c.mmd_pvalue > 0.05 ? "~ borderline"      :
                 c.mmd_pvalue > 0.01 ? "⚠ significant"     : "✗ highly significant"
        mmd_str = isnan(c.mmd_stat) ? "    N/A " : @sprintf("%12.6f", c.mmd_stat)
        p_str   = isnan(c.mmd_pvalue) ? "    N/A " : @sprintf("%12.4f", c.mmd_pvalue)
        @printf("│  %-20s│ %s │ %s │  %-23s │\n",
                c.name[1:min(20,end)], mmd_str, p_str, interp)
    end
    println("├──────────────────────┴──────────────┴──────────────┴─────────────────────────┤")
    println("│  DISTRIBUTIONAL COMPARISON (final tick)                                      │")
    println("├──────────────────────┬───────────────────────┬───────────────────────┬────────┤")
    println("│  Variable            │  Julia (μ ± σ) [med]  │  Java (μ ± σ) [med]   │ECDF r  │")
    println("├──────────────────────┼───────────────────────┼───────────────────────┼────────┤")
    for c in r.comparisons
        jl_str = @sprintf("%.1f±%.1f [%.1f]", c.julia_final_mean, c.julia_final_std, c.julia_final_median)
        jv_str = @sprintf("%.1f±%.1f [%.1f]", c.java_final_mean, c.java_final_std, c.java_final_median)
        @printf("│  %-20s│ %-21s │ %-21s │ %6.4f │\n",
                c.name[1:min(20,end)], jl_str, jv_str, c.ecdf_corr)
    end
    println("└──────────────────────┴───────────────────────┴───────────────────────┴────────┘")

    verdicts = verdict.(r.comparisons)
    if all(v -> v in (:exact, :pass), verdicts)
        println("\n  ✅ PASS — All variables show compatible stochastic behavior")
    elseif all(v -> v != :divergent, verdicts)
        marginal = [c.name for (c, v) in zip(r.comparisons, verdicts) if v == :marginal]
        println("\n  ⚠️  MARGINAL: $(join(marginal, ", ")) — may need more replicates")
    else
        bad = [c.name for (c, v) in zip(r.comparisons, verdicts) if v == :divergent]
        println("\n  ❌ DIVERGENCE in: $(join(bad, ", "))")
    end
end

function save_csv(r::ComparisonReport, path::String)
    globals = [c.name for c in r.comparisons]
    # Raw trajectory data
    open(path, "w") do io
        println(io, "implementation,seed,tick,", join(globals, ","))
        for traj in r.julia_trajectories
            for (i, t) in enumerate(traj.ticks)
                vals = [i <= length(get(traj.values, g, Float64[])) ?
                        get(traj.values, g, Float64[])[i] : NaN for g in globals]
                println(io, "julia,", traj.seed, ",", t, ",", join(vals, ","))
            end
        end
        for traj in r.java_trajectories
            for (i, t) in enumerate(traj.ticks)
                vals = [i <= length(get(traj.values, g, Float64[])) ?
                        get(traj.values, g, Float64[])[i] : NaN for g in globals]
                println(io, "java,", traj.seed, ",", t, ",", join(vals, ","))
            end
        end
    end
    # Summary metrics
    summary_path = replace(path, ".csv" => "_summary.csv")
    open(summary_path, "w") do io
        println(io, "variable,mae,nmae,corr_mean_traj,ks_stat,ecdf_corr,qq_corr,",
                "mmd_stat,mmd_pvalue,",
                "jl_final_mean,jv_final_mean,jl_final_std,jv_final_std,",
                "jl_final_median,jv_final_median,verdict")
        for c in r.comparisons
            v = verdict(c)
            @printf(io, "%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%s\n",
                    c.name, c.mae_mean_traj, c.nmae_mean_traj, c.corr_mean_traj,
                    c.ks_statistic, c.ecdf_corr, c.qq_corr,
                    c.mmd_stat, c.mmd_pvalue,
                    c.julia_final_mean, c.java_final_mean,
                    c.julia_final_std, c.java_final_std,
                    c.julia_final_median, c.java_final_median, v)
        end
    end
    println("  📁 Trajectories: $path")
    println("  📁 Summary:      $summary_path")
end

# ── Calibrated comparison (4-batch design) ───────────────────────────
#
# Run 2 batches per implementation (Julia-A, Julia-B, Java-A, Java-B).
# Compare:  Julia-A vs Julia-B  (within-Julia null)
#           Java-A  vs Java-B   (within-Java null)
#           Julia-A vs Java-A   (cross-implementation test)
# If cross-impl metrics fall within the range of within-impl metrics,
# the implementations are statistically equivalent — no subjective thresholds.

"""Compact metrics for one pairwise batch comparison."""
struct BatchMetrics
    mae::Float64
    nmae::Float64
    corr_mean::Float64
    ks::Float64
    ecdf_r::Float64
    mmd_stat::Float64
    mmd_p::Float64
end

struct VariableCalibrated
    name::String
    jl_vs_jl::BatchMetrics     # within-Julia (null)
    jv_vs_jv::BatchMetrics     # within-Java  (null)
    jl_vs_jv::BatchMetrics     # cross-implementation (test)
    pass::Bool                 # true if cross ≤ max(within) for key metrics
end

struct CalibratedReport
    model_name::String
    n_per_batch::Int
    n_ticks::Int
    variables::Vector{VariableCalibrated}
    julia_time_s::Float64
    java_time_s::Float64
end

"""Compute BatchMetrics between two trajectory sets for one variable."""
function batch_metrics(trajs_a::Vector{TrajectoryData}, trajs_b::Vector{TrajectoryData},
                       g::String, nticks::Int)
    safe_mean(x) = (f = filter(!isnan, x); isempty(f) ? NaN : mean(f))

    function mean_traj(trajs)
        by_tick = [Float64[] for _ in 0:nticks]
        for traj in trajs
            series = padded_trajectory_series(traj, g, nticks)
            series === nothing && continue
            for t in 0:nticks
                push!(by_tick[t+1], series[t+1])
            end
        end
        safe_mean.(by_tick)
    end

    ma = mean_traj(trajs_a)
    mb = mean_traj(trajs_b)

    diffs = abs.(ma .- mb)
    fd = filter(!isnan, diffs)
    mae = isempty(fd) ? NaN : mean(fd)

    combined = filter(!isnan, vcat(ma, mb))
    val_range = isempty(combined) ? 1.0 : max(maximum(combined) - minimum(combined), 1.0)
    nmae = mae / val_range

    r_mean = pearson_r(ma, mb)

    final_a = Float64[last(get(t.values, g, [NaN])) for t in trajs_a]
    final_b = Float64[last(get(t.values, g, [NaN])) for t in trajs_b]

    ks = ks_statistic(final_a, final_b)
    ecdf_r = ecdf_correlation(final_a, final_b)
    mmd2, mmd_p = trajectory_mmd(trajs_a, trajs_b, g, nticks; n_perms=500)

    BatchMetrics(mae, nmae, r_mean, ks, ecdf_r, mmd2, mmd_p)
end

function compare_model_calibrated(model::AbstractBenchmarkModel;
                                  n_per_batch::Int=50)
    nticks = n_ticks(model)
    seeds_a = collect(1:n_per_batch)
    seeds_b = collect(n_per_batch+1 : 2*n_per_batch)

    println("╔══════════════════════════════════════════════════════════╗")
    println("║  Calibrated comparison: $(model_name(model))")
    println("║  4 batches × $n_per_batch reps  │  Ticks: $nticks")
    println("╚══════════════════════════════════════════════════════════╝")

    println("\n▶ Running Julia batch A (seeds 1-$n_per_batch)...")
    t_jl = @elapsed begin
        jl_a = run_julia_trajectories(model, seeds_a)
        print("    ...batch B (seeds $(n_per_batch+1)-$(2*n_per_batch))...")
        jl_b = run_julia_trajectories(model, seeds_b)
    end
    @printf("\n  ✓ Julia: %.2f s (%.3f s/rep)\n", t_jl, t_jl/(2*n_per_batch))

    println("\n▶ Running Java batch A (seeds 1-$n_per_batch)...")
    t_jv = @elapsed begin
        jv_a = run_java_trajectories(model, seeds_a)
        print("    ...batch B (seeds $(n_per_batch+1)-$(2*n_per_batch))...")
        jv_b = run_java_trajectories(model, seeds_b)
    end
    @printf("\n  ✓ Java:  %.2f s (%.3f s/rep)\n", t_jv, t_jv/(2*n_per_batch))

    println("\n▶ Computing 3-way batch comparisons...")
    globals = tracked_globals(model)
    variables = VariableCalibrated[]

    for g in globals
        jl_jl = batch_metrics(jl_a, jl_b, g, nticks)
        jv_jv = batch_metrics(jv_a, jv_b, g, nticks)
        jl_jv = batch_metrics(jl_a, jv_a, g, nticks)

        # Pass if cross-implementation metrics are no worse than the
        # larger of the two within-implementation baselines.
        # For MAE/NMAE/KS: cross should be ≤ max(within) * tolerance
        # For correlations: cross should be ≥ min(within) * tolerance
        # For MMD p-value: cross should not be much lower than within
        tol = 1.5   # allow 50% slack over the within-impl baseline
        null_mae  = max(jl_jl.nmae, jv_jv.nmae)
        null_ks   = max(jl_jl.ks, jv_jv.ks)
        null_mmd_p = min(jl_jl.mmd_p, jv_jv.mmd_p)

        mae_ok = isnan(null_mae) || jl_jv.nmae <= null_mae * tol + 0.01
        ks_ok  = isnan(null_ks)  || jl_jv.ks   <= null_ks  * tol + 0.02
        # MMD: cross p-value shouldn't be dramatically lower than within
        mmd_ok = isnan(jl_jv.mmd_p) || jl_jv.mmd_p >= null_mmd_p * 0.5 - 0.05

        ok = mae_ok && ks_ok && mmd_ok
        push!(variables, VariableCalibrated(g, jl_jl, jv_jv, jl_jv, ok))
    end

    CalibratedReport(model_name(model), n_per_batch, nticks, variables, t_jl, t_jv)
end

function print_calibrated_report(r::CalibratedReport)
    println()
    println("┌──────────────────────────────────────────────────────────────────────────────────────────────────┐")
    @printf("│  %s — Calibrated 4-batch comparison (%d per batch × %d ticks)\n",
            r.model_name, r.n_per_batch, r.n_ticks)
    @printf("│  Julia: %.1fs  │  Java: %.1fs\n", r.julia_time_s, r.java_time_s)
    println("├──────────────────────────────────────────────────────────────────────────────────────────────────┤")
    println("│                       │        Julia A↔B (null)  │        Java A↔B (null)   │   Julia↔Java (test)│")
    println("│  Variable       Metric│   value                  │   value                  │   value        pass│")
    println("├──────────────────────────────────────────────────────────────────────────────────────────────────┤")
    for v in r.variables
        jj = v.jl_vs_jl; vv = v.jv_vs_jv; jv = v.jl_vs_jv
        n = v.name[1:min(16,end)]
        @printf("│  %-16s NMAE │   %8.5f                │   %8.5f                │   %8.5f     │\n", n, jj.nmae, vv.nmae, jv.nmae)
        @printf("│  %-16s r(μ) │   %8.5f                │   %8.5f                │   %8.5f     │\n", "", jj.corr_mean, vv.corr_mean, jv.corr_mean)
        @printf("│  %-16s KS   │   %8.4f                │   %8.4f                │   %8.4f     │\n", "", jj.ks, vv.ks, jv.ks)
        mmd_p_jj = isnan(jj.mmd_p) ? "   N/A" : @sprintf("%8.4f", jj.mmd_p)
        mmd_p_vv = isnan(vv.mmd_p) ? "   N/A" : @sprintf("%8.4f", vv.mmd_p)
        mmd_p_jv = isnan(jv.mmd_p) ? "   N/A" : @sprintf("%8.4f", jv.mmd_p)
        mark = v.pass ? "  ✓" : "  ✗"
        @printf("│  %-16s MMDp │   %s                │   %s                │   %s   %s │\n", "", mmd_p_jj, mmd_p_vv, mmd_p_jv, mark)
        println("│                       │                          │                          │                    │")
    end
    println("└──────────────────────────────────────────────────────────────────────────────────────────────────┘")

    all_ok = all(v -> v.pass, r.variables)
    if all_ok
        println("\n  ✅ PASS — Cross-implementation differences within null baseline for all variables")
    else
        bad = [v.name for v in r.variables if !v.pass]
        println("\n  ❌ FAIL — Cross-impl exceeds null baseline for: $(join(bad, ", "))")
    end
end

function save_calibrated_csv(r::CalibratedReport, path::String)
    open(path, "w") do io
        println(io, "variable,comparison,mae,nmae,corr_mean,ks,ecdf_r,mmd_stat,mmd_p,pass")
        for v in r.variables
            for (label, m) in [("julia_vs_julia", v.jl_vs_jl),
                               ("java_vs_java",   v.jv_vs_jv),
                               ("julia_vs_java",  v.jl_vs_jv)]
                @printf(io, "%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%s\n",
                        v.name, label, m.mae, m.nmae, m.corr_mean,
                        m.ks, m.ecdf_r, m.mmd_stat, m.mmd_p,
                        label == "julia_vs_java" ? string(v.pass) : "")
            end
        end
    end
    println("  📁 Saved: $path")
end

# ── Built-in benchmark models ─────────────────────────────────────────

include("models/sir.jl")
include("models/diffusion.jl")
include("models/fire.jl")
include("models/schelling.jl")
include("models/virus.jl")
include("models/wolfsheep.jl")

# ── Library benchmark models ──────────────────────────────────────────

include("models/segregation.jl")
include("models/wealth_distribution.jl")
include("models/el_farol.jl")
include("models/simple_birth_rates.jl")
include("models/party.jl")
include("models/decay.jl")
include("models/tumor.jl")
include("models/ising.jl")
include("models/climate_change.jl")
include("models/team_assembly.jl")
include("models/ants.jl")

# netlogomas models
include("models/paretolearn.jl")
include("models/coin.jl")
include("models/antsystem.jl")
include("models/marriage.jl")
include("models/mailmen.jl")

# model-zoo models
include("models/contactprocess.jl")
include("models/grassbrushtrees.jl")
include("models/ipd.jl")
include("models/voter.jl")
include("models/firepercolation.jl")

# modsoc models
include("models/particles.jl")
include("models/modsoc_segregation.jl")
include("models/contagion_si.jl")
include("models/contagion_sir.jl")
include("models/opinion_bc.jl")
include("models/pd_simple.jl")
include("models/coordination.jl")
include("models/bayesian.jl")
include("models/coordination_2groups.jl")

# ClassModels
include("models/being_green.jl")
include("models/language_borders.jl")
include("models/tourism.jl")
include("models/civilization_growth.jl")
include("models/unit_cohesion.jl")
include("models/dating.jl")

# GIS ClassModels
include("models/bomb_scenario.jl")
include("models/multidrug_resistant.jl")
include("models/hiking_elevation.jl")
include("models/diffusion_of_hiv.jl")
include("models/sleuth_landuse.jl")
include("models/rise_of_radicalism.jl")

# Extension models (table, matrix, rnd, nw, profiler, csv)
include("models/crop_rotation.jl")
include("models/rational_evolving_pd.jl")
include("models/search_path.jl")
include("models/bullwhip_effect.jl")
include("models/infinite_life.jl")
include("models/resilient_team.jl")
include("models/privacy_opinion.jl")
include("models/artificial_economy.jl")
include("models/voronoi_voter.jl")
include("models/cyberspace_opinion.jl")
include("models/abtgc.jl")

# Modeling Commons new candidates
include("models/evolution_of_norms.jl")
include("models/lassa_virus.jl")
include("models/axelrod_cultural.jl")
include("models/ethnocentrism.jl")
include("models/mousetraps.jl")
include("models/fire_benchmark.jl")
include("models/daisyworld.jl")
include("models/dla.jl")
include("models/dla_simple.jl")
include("models/boiling.jl")
include("models/solid_diffusion.jl")
include("models/flocking.jl")
include("models/sand.jl")
include("models/rope.jl")
include("models/polymer_dynamics.jl")
include("models/thermostat.jl")
include("models/crystallization.jl")
include("models/mimicry.jl")

# Extension-exercising models
include("models/minority_belief.jl")
include("models/recruiting.jl")
include("models/slow_spread.jl")
include("models/spreading_groups.jl")

# NW extension eval wrappers (modelingcommons)
include("models/superdiffuser.jl")
include("models/drug_use.jl")
include("models/products_market.jl")
include("models/social_influence.jl")
include("models/participatory_disinformation.jl")
include("models/info_diffusion.jl")
include("models/recruiting_supporters.jl")
include("models/gis_hillclimber.jl")
include("models/gis_burkina.jl")
include("models/rhino_poaching.jl")
include("models/fake_news.jl")

# Additional extension models (nw, table, rnd)
include("models/flocking_network.jl")
include("models/misinformation_sbfc.jl")
include("models/simple_market.jl")
include("models/spatial_attitude.jl")
include("models/contagion_nw.jl")
include("models/diffusion_network.jl")

# Array/Matrix extension models
include("models/minimal_sis.jl")
include("models/cultural_diffusion.jl")
include("models/sugarscape_culture.jl")
include("models/competition_learning.jl")

# Table/Array combo + Table models
include("models/babysitting_coop.jl")
include("models/wisdom_crowd.jl")
include("models/fungal_bioremediation.jl")

# nw + bitstring extension model
include("models/participatory_disinfo.jl")

# matrix + rnd extension model
include("models/blackbox.jl")

# rnd extension model
include("models/spatial_opinion.jl")
include("models/forest_dewdney.jl")
include("models/social_network_diffusion.jl")
include("models/drug_use_overdose.jl")
include("models/recruiting_movement.jl")
include("models/simple_market_random.jl")
include("models/csv_population.jl")
include("models/csv_network_foraging.jl")
include("models/spreading_bots.jl")
include("models/disinfo_nw_bitstring.jl")
include("models/cqin.jl")
include("models/simple_market_table.jl")
include("models/sugarscape_sexual.jl")
include("models/pref_attach_homophily.jl")
include("models/leonardi_tech_adoption.jl")

end # module
