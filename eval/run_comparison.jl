#!/usr/bin/env julia
#
# Run stochastic trajectory comparisons between NetLogo.jl (Julia)
# and the reference Java/Scala NetLogo implementation.
#
# Usage:
#   cd NetLogo.jl
#   julia --project=. eval/run_comparison.jl [mode] [model] [n_reps]
#
# Modes:
#   calibrated  (default) 4-batch null-calibrated comparison
#   simple                Single-batch comparison with threshold metrics
#   julia-only            Quick smoke test (Julia only, no Java)
#
# Examples:
#   julia --project=. eval/run_comparison.jl                          # all, calibrated, 50/batch
#   julia --project=. eval/run_comparison.jl calibrated sir 30        # SIR calibrated, 30/batch
#   julia --project=. eval/run_comparison.jl simple all 50            # all, simple, 50 reps
#   julia --project=. eval/run_comparison.jl julia-only               # smoke test
#

using NetLogo
using Printf

include(joinpath(@__DIR__, "NetLogoCompare.jl"))
using .NetLogoCompare

const MODELS = Dict(
    # Original benchmark models
    "sir"           => SIRModel(),
    "diffusion"     => DiffusionModel(),
    "fire"          => FireModel(),
    "schelling"     => SchellingModel(),
    "virus"         => VirusModel(),
    "wolfsheep"     => WolfSheepModel(),
    # Library models
    "segregation"   => SegregationModel(),
    "wealth"        => WealthDistModel(),
    "elfarol"       => ElFarolModel(),
    "birthrates"    => BirthRatesModel(),
    "party"         => PartyModel(),
    "decay"         => DecayModel(),
    "tumor"         => TumorModel(),
    "ising"         => IsingModel(),
    "climate"       => ClimateModel(),
    "teamassembly"  => TeamAssemblyModel(),
    "ants"          => AntsModel(),
    # netlogomas models
    "paretolearn"   => ParetoLearnModel(),
    "coin"          => CoinModel(),
    "antsystem"     => AntSystemModel(),
    "marriage"      => MarriageModel(),
    "mailmen"       => MailmenModel(),
    # model-zoo models
    "contactprocess" => ContactProcessModel(),
    "grassbrushtrees" => GrassBrushTreesModel(),
    "ipd"           => IPDModel(),
    "voter"         => VoterModel(),
    "firepercolation" => FirePercolationModel(),
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
    # GIS ClassModels
    "bombscenario"   => BombScenarioModel(),
    "multidrugresistant" => MultidrugResistantModel(),
    "hikingelevation" => HikingElevationModel(),
    "diffusionofhiv" => DiffusionOfHIVModel(),
    "sleuthlanduse"  => SleuthModel(),
    "riseofradicalism" => RiseOfRadicalismModel(),
    # Extension models (table, matrix, rnd, nw, profiler, csv)
    "croprotation"    => CropRotationModel(),
    "rationalevolvpd" => RationalEvolvingPDModel(),
    "searchpath"      => SearchPathModel(),
    "bullwhipeffect"  => BullwhipEffectModel(),
    "infinitelife"    => InfiniteLifeModel(),
    "resilientteam"   => ResilientTeamModel(),
    "privacyopinion"  => PrivacyOpinionModel(),
    "artificialeconomy" => ArtificialEconomyModel(),
    "voronoivoter"    => VoronoiVoterModel(),
    "cyberopinion"    => CyberspaceOpinionModel(),
    "abtgc"           => ABTgcModel(),
    # Modeling Commons new candidates
    "evolutionofnorms"  => EvolutionOfNormsModel(),
    "lassavirus"        => LassaVirusModel(),
    "axelrodcultural"   => AxelrodCulturalModel(),
    "mousetraps"        => MousetrapsModel(),
    "firebenchmark"     => FireBenchmarkModel(),
    # Modeling Commons classic models
    "dlasimple"         => DLASimpleModel(),
    "boiling"           => BoilingModel(),
    "soliddiffusion"    => SolidDiffusionModel(),
    "flocking"          => FlockingModel(),
    "sand"              => SandModel(),
    "rope"              => RopeModel(),
    "polymer"           => PolymerDynamicsModel(),
    "thermostat"        => ThermostatModel(),
    "crystallization"   => CrystallizationModel(),
    "mimicry"           => MimicryModel(),
    # NW extension eval wrappers (modelingcommons)
    "superdiffuser"     => SuperDiffuserModel(),
    "druguse"           => DrugUseModel(),
    "productsmarket"    => ProductsModel(),
    "socialinfluence"   => SocialInfluenceModel(),
    "participdisinfo"   => ParticipatoryDisinformationModel(),
    "infodiffusion"     => InfoDiffusionModel(),
    "recruitingsupporters" => RecruitingSupportersModel(),
    "gishillclimber"    => GisHillClimberModel(),
    "rhinopoaching"     => RhinoPoachingModel(),
    # Additional NW extension models
    "minoritybelief"    => MinorityBeliefModel(),
    "slowspread"        => SlowSpreadModel(),
    "spreadinggroups"   => SpreadingGroupsModel(),
    "recruiting"        => RecruitingModel(),
    # Modeling Commons additional NW models
    "fakenews"          => FakeNewsModel(),
)

# Models too slow for batch comparison runs (>30s/run)
const SLOW_MODELS = Set(["elfarol", "birthrates", "antsystem", "coin", "contactprocess", "tourism", "langborders",
                          "bombscenario", "multidrugresistant", "hikingelevation", "diffusionofhiv", "sleuthlanduse", "riseofradicalism",
                          "searchpath", "voronoivoter", "artificialeconomy", "infinitelife",
                          "lassavirus", "axelrodcultural",
                          "rationalevolvpd", "cyberopinion", "rhinopoaching",
                          "contagionsi", "contagionsir", "coord2groups", "opinionbc",
                          "civgrowth", "productsmarket", "participdisinfo"])

function julia_only_smoke_test()
    println("═══════════════════════════════════════════════════")
    println("  Julia-only smoke test (no Java comparison)")
    println("═══════════════════════════════════════════════════\n")

    for name in sort(collect(keys(MODELS)))
        model = MODELS[name]
        print("  $(model_name(model))... ")
        try
            trajs = NetLogoCompare.run_julia_trajectories(model, [42])
            traj = trajs[1]
            n_ticks_actual = length(traj.ticks) - 1
            finals = Dict(g => last(v) for (g, v) in traj.values)
            println("✓ ($n_ticks_actual ticks, $(join(["$g=$(round(v, digits=1))" for (g,v) in finals], ", ")))")
        catch e
            println("✗ $e")
        end
    end
    println()
end

function resolve_models(name_arg::String)
    if name_arg == "all"
        [v for (k,v) in MODELS if k ∉ SLOW_MODELS]
    else
        haskey(MODELS, name_arg) || error("Unknown model: $name_arg. Available: $(join(keys(MODELS), ", "))")
        [MODELS[name_arg]]
    end
end

function run_calibrated(model_arg::String, n::Int)
    outdir = joinpath(@__DIR__, "results")
    mkpath(outdir)

    models = resolve_models(model_arg)
    reports = CalibratedReport[]

    for model in models
        try
            report = compare_model_calibrated(model; n_per_batch=n)
            print_calibrated_report(report)
            csv_path = joinpath(outdir, "$(replace(lowercase(NetLogoCompare.model_name(model)), " " => "_"))_calibrated.csv")
            save_calibrated_csv(report, csv_path)
            push!(reports, report)
        catch e
            println("\n  ❌ Error running $(NetLogoCompare.model_name(model)): $e")
            println("     $(sprint(showerror, e))")
        end
        println()
    end

    if length(reports) > 1
        println("\n════════════════════════════════════════════════════════════════════")
        println("  CALIBRATED SUMMARY")
        println("════════════════════════════════════════════════════════════════════")
        @printf("  %-25s  %-6s  %-20s  %-20s  %-20s\n",
                "Model", "Pass?", "NMAE (JJ / VV / JV)", "KS (JJ / VV / JV)", "MMDp (JJ / VV / JV)")
        println("  " * "─"^90)
        for r in reports
            all_pass = all(v -> v.pass, r.variables)
            status = all_pass ? "✅" : "❌"
            # Show worst-case variable
            worst = argmax(v -> v.jl_vs_jv.nmae, r.variables)
            w = worst
            @printf("  %-25s  %s     %.4f/%.4f/%.4f  %.2f/%.2f/%.2f  %.3f/%.3f/%.3f\n",
                    r.model_name, status,
                    w.jl_vs_jl.nmae, w.jv_vs_jv.nmae, w.jl_vs_jv.nmae,
                    w.jl_vs_jl.ks, w.jv_vs_jv.ks, w.jl_vs_jv.ks,
                    w.jl_vs_jl.mmd_p, w.jv_vs_jv.mmd_p, w.jl_vs_jv.mmd_p)
        end
    end
end

function run_simple(model_arg::String, n::Int)
    outdir = joinpath(@__DIR__, "results")
    mkpath(outdir)

    models = resolve_models(model_arg)
    reports = ComparisonReport[]

    for model in models
        try
            report = compare_model(model; n_reps=n)
            print_report(report)
            csv_path = joinpath(outdir, "$(replace(lowercase(NetLogoCompare.model_name(model)), " " => "_")).csv")
            save_csv(report, csv_path)
            push!(reports, report)
        catch e
            println("\n  ❌ Error running $(NetLogoCompare.model_name(model)): $e")
            println("     $(sprint(showerror, e))")
        end
        println()
    end

    if length(reports) > 1
        println("\n════════════════════════════════════════════════════════════════════")
        println("  SUMMARY")
        println("════════════════════════════════════════════════════════════════════")
        for r in reports
            verdicts = NetLogoCompare.verdict.(r.comparisons)
            overall = all(v -> v in (:exact, :pass), verdicts) ? "✅" :
                      all(v -> v != :divergent, verdicts) ? "⚠️" : "❌"
            max_nmae = maximum(c.nmae_mean_traj for c in r.comparisons)
            min_r = minimum(c.corr_mean_traj for c in r.comparisons)
            max_ks = maximum(c.ks_statistic for c in r.comparisons)
            speedup = r.java_time_s > 0 ? r.java_time_s / r.julia_time_s : NaN
            @printf("  %s %-25s  NMAE=%.4f  r(μ)=%.4f  KS=%.4f  (%.1f×)\n",
                    overall, r.model_name, max_nmae, min_r, max_ks, speedup)
        end
    end
end

function main()
    mode = length(ARGS) >= 1 ? lowercase(ARGS[1]) : "calibrated"
    
    if mode == "julia-only"
        julia_only_smoke_test()
        return
    end

    if mode in ("calibrated", "simple")
        model_arg = length(ARGS) >= 2 ? lowercase(ARGS[2]) : "all"
        n = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 50
    else
        # Legacy: first arg is model name
        model_arg = mode
        mode = "calibrated"
        n = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 50
    end

    if mode == "calibrated"
        run_calibrated(model_arg, n)
    else
        run_simple(model_arg, n)
    end
end

main()
