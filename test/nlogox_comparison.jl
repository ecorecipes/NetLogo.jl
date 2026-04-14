#!/usr/bin/env julia
# Compare .nlogox (NL7) vs .nlogo (NL6) model loading and execution in NetLogo.jl
# For each matched pair, loads both formats, runs setup + N go steps with same seed,
# and compares: tick count, turtle count, patch variable sums

using NetLogo
using Random

const NL7_DIR = joinpath(dirname(@__DIR__), "..", "NetLogo-dist", "NetLogo 7.0.3", "models", "Sample Models")
const NL6_DIR = joinpath(dirname(@__DIR__), "..", "NetLogo-dist", "NetLogo-6.4.0-64", "models", "Sample Models")

# Extensions we don't support
const UNSUPPORTED_EXTS = Set(["import-a", "resource", "palette", "ls", "vid", "py", "r", "fetch", "send-to", "web"])

# Models to skip (known issues: HubNet, __includes, interactive-only, etc.)
const SKIP_MODELS = Set([
    "Social Science/Economics/Oil Cartel HubNet",
    "Biology/Wolf Sheep Predation - Agent Cognition/Wolf Sheep Predation - Micro-Sims",
    "Biology/Wolf Sheep Predation - Agent Cognition/Wolf Sheep Predation - Micro-Sims Cognitive Model",
    "Social Science/Distribution Center Discrete Event Simulator/Distribution Center Discrete Event Simulator",
    "Biology/CRISPR/CRISPR Bacterium LevelSpace",
    "Biology/CRISPR/CRISPR Ecosystem LevelSpace",
    "Chemistry & Physics/Kicked Rotators",  # ls extension
    "Chemistry & Physics/Gas Chromatography",  # hangs in setup
])

const GO_STEPS = 5
const SEED = 42

struct ModelResult
    ticks::Float64
    turtle_count::Float64
    patch_count::Float64
    success::Bool
    error::String
end

ModelResult() = ModelResult(0.0, 0.0, 0.0, false, "")

function has_unsupported_extension(filepath::String)::Bool
    src = read(filepath, String)
    m = match(r"extensions\s*\[([^\]]*)\]", src)
    m === nothing && return false
    exts = split(strip(m.captures[1]))
    for ext in exts
        ext_name = strip(String(ext))
        if ext_name in UNSUPPORTED_EXTS
            return true
        end
    end
    return false
end

function has_procedure(rt::RuntimeState, name::String)::Bool
    try
        # Try to find the procedure in compiled model
        haskey(rt.model.procedures, name)
    catch
        false
    end
end

function run_model_inner(filepath::String, seed::Int, steps::Int)::ModelResult
    model = load_model(filepath)
    rt = create_runtime(model)
    
    # Set random seed
    try
        runresult(rt, "random-seed $seed")
    catch
        try; rt.rng = Random.MersenneTwister(seed); catch; end
    end
    
    # Run setup
    if haskey(rt.model.procedures, "setup")
        call!(rt, "setup")
    elseif haskey(rt.model.procedures, "SETUP")
        call!(rt, "SETUP")
    else
        return ModelResult(0.0, 0.0, 0.0, false, "no setup procedure")
    end
    
    # Determine go procedure name
    go_name = if haskey(rt.model.procedures, "go")
        "go"
    elseif haskey(rt.model.procedures, "GO")
        "GO"
    else
        return ModelResult(0.0, 0.0, 0.0, false, "no go procedure")
    end
    
    # Run go steps
    for _ in 1:steps
        call!(rt, go_name)
    end
    
    ticks = try Float64(runresult(rt, "ticks")) catch; -1.0 end
    turtle_count = try Float64(runresult(rt, "count turtles")) catch; -1.0 end
    patch_count = try Float64(runresult(rt, "count patches")) catch; -1.0 end
    
    return ModelResult(ticks, turtle_count, patch_count, true, "")
end

const MODEL_TIMEOUT = 30.0  # seconds

function run_model(filepath::String, seed::Int, steps::Int)::ModelResult
    # Use Threads.@spawn for preemptible timeout (requires julia -t2+)
    # Fallback: just run directly with no timeout if single-threaded
    if Threads.nthreads() > 1
        result_ref = Ref{Union{Nothing,ModelResult}}(nothing)
        t = Threads.@spawn begin
            result_ref[] = run_model_inner(filepath, seed, steps)
        end
        deadline = time() + MODEL_TIMEOUT
        while !istaskdone(t) && time() < deadline
            sleep(0.1)
        end
        if istaskdone(t)
            r = result_ref[]
            return r === nothing ? ModelResult(0.0, 0.0, 0.0, false, "unknown error") : r
        else
            return ModelResult(0.0, 0.0, 0.0, false, "TIMEOUT after $(MODEL_TIMEOUT)s")
        end
    else
        try
            return run_model_inner(filepath, seed, steps)
        catch e
            return ModelResult(0.0, 0.0, 0.0, false, sprint(showerror, e))
        end
    end
end

function find_matching_models()
    pairs = Tuple{String,String,String}[]  # (name, nlogo_path, nlogox_path)
    
    for (root, dirs, files) in walkdir(NL7_DIR)
        for f in files
            endswith(f, ".nlogox") || continue
            nlogox_path = joinpath(root, f)
            relpath_from_nl7 = relpath(nlogox_path, NL7_DIR)
            basename_no_ext = relpath_from_nl7[1:end-7]  # strip .nlogox
            nlogo_path = joinpath(NL6_DIR, basename_no_ext * ".nlogo")
            
            if isfile(nlogo_path)
                push!(pairs, (basename_no_ext, nlogo_path, nlogox_path))
            end
        end
    end
    
    sort!(pairs, by=x->x[1])
    return pairs
end

function main()
    pairs = find_matching_models()
    println("Found $(length(pairs)) matching model pairs")
    println("=" ^ 120)
    
    results = Dict{String, Tuple{ModelResult, ModelResult}}()
    
    pass = 0
    fail_load = 0
    fail_mismatch = 0
    both_fail = 0
    skip_count = 0
    errors_nlogo = String[]
    errors_nlogox = String[]
    mismatches = String[]
    
    for (i, (name, nlogo_path, nlogox_path)) in enumerate(pairs)
        # Skip known problematic models
        if name in SKIP_MODELS
            skip_count += 1
            continue
        end
        
        # Skip models with unsupported extensions
        if has_unsupported_extension(nlogox_path)
            skip_count += 1
            continue
        end
        
        print("[$i/$(length(pairs))] $name ... ")
        
        # Run .nlogo version
        r_nlogo = run_model(nlogo_path, SEED, GO_STEPS)
        
        # Run .nlogox version
        r_nlogox = run_model(nlogox_path, SEED, GO_STEPS)
        
        results[name] = (r_nlogo, r_nlogox)
        
        if !r_nlogo.success && !r_nlogox.success
            println("BOTH FAIL")
            both_fail += 1
        elseif !r_nlogo.success
            println("NLOGO FAIL: $(first(r_nlogo.error, 80))")
            push!(errors_nlogo, "$name: $(first(r_nlogo.error, 100))")
            fail_load += 1
        elseif !r_nlogox.success
            println("NLOGOX FAIL: $(first(r_nlogox.error, 80))")
            push!(errors_nlogox, "$name: $(first(r_nlogox.error, 100))")
            fail_load += 1
        else
            # Both succeeded - compare results
            ticks_match = r_nlogo.ticks == r_nlogox.ticks
            turtles_match = r_nlogo.turtle_count == r_nlogox.turtle_count
            patches_match = r_nlogo.patch_count == r_nlogox.patch_count
            
            if ticks_match && turtles_match && patches_match
                println("PASS (ticks=$(r_nlogo.ticks), turtles=$(r_nlogo.turtle_count), patches=$(r_nlogo.patch_count))")
                pass += 1
            else
                diffs = String[]
                if !ticks_match
                    push!(diffs, "ticks: $(r_nlogo.ticks) vs $(r_nlogox.ticks)")
                end
                if !turtles_match
                    push!(diffs, "turtles: $(r_nlogo.turtle_count) vs $(r_nlogox.turtle_count)")
                end
                if !patches_match
                    push!(diffs, "patches: $(r_nlogo.patch_count) vs $(r_nlogox.patch_count)")
                end
                println("MISMATCH: ", join(diffs, ", "))
                push!(mismatches, "$name: " * join(diffs, ", "))
                fail_mismatch += 1
            end
        end
        
        GC.gc(false)  # Light GC to manage memory
    end
    
    # Summary
    total = length(pairs) - skip_count
    println("\n" * "=" ^ 120)
    println("SUMMARY")
    println("=" ^ 120)
    println("Total pairs:    $(length(pairs))")
    println("Skipped:        $skip_count")
    println("Tested:         $total")
    println("PASS (match):   $pass")
    println("BOTH FAIL:      $both_fail (not nlogox-specific)")
    println("One-side FAIL:  $fail_load")
    println("MISMATCH:       $fail_mismatch")
    successful = pass + fail_mismatch  # both loaded successfully
    println("Both loaded:    $successful / $total")
    println("Match rate:     $(round(100.0 * pass / max(successful, 1), digits=1))% (of models that loaded)")
    
    if !isempty(mismatches)
        println("\n--- MISMATCHES (nlogo vs nlogox) ---")
        for m in mismatches
            println("  $m")
        end
    end
    
    if !isempty(errors_nlogox)
        println("\n--- NLOGOX-ONLY ERRORS (first 20) ---")
        for e in first(errors_nlogox, 20)
            println("  $e")
        end
    end
    
    if !isempty(errors_nlogo)
        println("\n--- NLOGO-ONLY ERRORS (first 20) ---")
        for e in first(errors_nlogo, 20)
            println("  $e")
        end
    end
end

main()
