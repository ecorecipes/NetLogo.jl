module rnd

using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER,
  reporter_syntax,
  ListType, WildcardType, NumberType, NumberBlockType, AgentsetType,
  AgentType, NobodyType,
  LogoRuntimeError, logo_string, Context,
  live_agentset_members, AbstractAgent, AgentSet,
  eval_reporter_block, block_caller,
  invoke_reporter_task, AbstractReporterTaskValue,
  numeric, is_logo_number, NOBODY

using Random: rand

# ── Weight evaluation ────────────────────────────────────────────────────────

function validate_weight(w, display_value)
  if !is_logo_number(w)
    throw(LogoRuntimeError(
      "Got $(logo_string(w)) as a weight but all weights must be numbers."))
  end
  wf = Float64(w)
  if wf < 0.0
    throw(LogoRuntimeError(
      "Got $(logo_string(w)) as a weight but all weights must be >= 0.0."))
  end
  wf
end

function evaluate_agent_weights(ctx::Context, agents::Vector{<:AbstractAgent}, block)
  weights = Vector{Float64}(undef, length(agents))
  for (i, agent) in enumerate(agents)
    w = eval_reporter_block(ctx, block; agent=agent, caller=block_caller(ctx))
    weights[i] = validate_weight(w, w)
  end
  weights
end

function evaluate_list_weights(ctx::Context, items::AbstractVector, task::AbstractReporterTaskValue)
  weights = Vector{Float64}(undef, length(items))
  for (i, item) in enumerate(items)
    w = invoke_reporter_task(ctx, task, Any[item])
    weights[i] = validate_weight(w, w)
  end
  weights
end

# ── Weighted sampling algorithms ─────────────────────────────────────────────

"""Roulette wheel selection: pick one index proportional to weights."""
function roulette_pick_one(rng, weights::Vector{Float64})
  total = sum(weights)
  n = length(weights)
  if total == 0.0
    return rand(rng, 1:n)
  end
  r = rand(rng) * total
  cumulative = 0.0
  for i in 1:n
    cumulative += weights[i]
    if r < cumulative
      return i
    end
  end
  n  # floating-point edge case
end

"""
Pick `count` unique indices without replacement using iterative roulette wheel.
Uses -1.0 sentinel to mark already-picked items.
When all remaining weights are zero, falls back to uniform selection.
"""
function pick_without_replacement(rng, weights::Vector{Float64}, count::Int)
  m = length(weights)
  active = copy(weights)
  selected = Int[]
  sizehint!(selected, count)

  for _ in 1:count
    total = 0.0
    n_available = 0
    for i in 1:m
      if active[i] >= 0.0
        total += active[i]
        n_available += 1
      end
    end

    idx = 0
    if total == 0.0
      # Uniform from remaining unpicked items
      target = rand(rng, 1:n_available)
      k = 0
      for i in 1:m
        if active[i] >= 0.0
          k += 1
          if k == target
            idx = i
            break
          end
        end
      end
    else
      r = rand(rng) * total
      cumulative = 0.0
      for i in 1:m
        active[i] > 0.0 || continue
        cumulative += active[i]
        if r < cumulative
          idx = i
          break
        end
      end
      if idx == 0
        # Floating-point edge case: pick last positive-weight item
        for i in m:-1:1
          if active[i] > 0.0
            idx = i
            break
          end
        end
      end
    end

    push!(selected, idx)
    active[idx] = -1.0
  end

  sort!(selected)
  selected
end

"""Pick `count` indices with replacement using repeated roulette wheel."""
function pick_with_repeats(rng, weights::Vector{Float64}, count::Int)
  total = sum(weights)
  n = length(weights)
  indices = Vector{Int}(undef, count)

  for j in 1:count
    if total == 0.0
      indices[j] = rand(rng, 1:n)
    else
      r = rand(rng) * total
      cumulative = 0.0
      idx = n
      for i in 1:n
        cumulative += weights[i]
        if r < cumulative
          idx = i
          break
        end
      end
      indices[j] = idx
    end
  end

  indices
end

# ── Primitive implementations ────────────────────────────────────────────────

function weighted_one_of_agentset(ctx::Context, agentset::AgentSet, block)
  agents = live_agentset_members(agentset)
  isempty(agents) && return NOBODY
  weights = evaluate_agent_weights(ctx, agents, block)
  idx = roulette_pick_one(ctx.runtime.world.rng, weights)
  agents[idx]
end

function weighted_one_of_list(ctx::Context, items::AbstractVector, task::AbstractReporterTaskValue)
  isempty(items) && throw(LogoRuntimeError(
    "Requesting 1 random items from a candidate list of only 0 items."))
  weights = evaluate_list_weights(ctx, items, task)
  idx = roulette_pick_one(ctx.runtime.world.rng, weights)
  items[idx]
end

function weighted_n_of_agentset(ctx::Context, count_value, agentset::AgentSet, block)
  count = Int(floor(numeric(count_value)))
  count < 0 && throw(LogoRuntimeError(
    "First input to RND:WEIGHTED-N-OF can't be negative."))
  agents = live_agentset_members(agentset)
  available = length(agents)
  count > available && throw(LogoRuntimeError(
    "Requesting $count random items from a candidate list of only $available items."))
  count == 0 && return AgentSet(agentset.kind, AbstractAgent[]; breed=agentset.breed)
  weights = evaluate_agent_weights(ctx, agents, block)
  indices = pick_without_replacement(ctx.runtime.world.rng, weights, count)
  AgentSet(agentset.kind, AbstractAgent[agents[i] for i in indices]; breed=agentset.breed)
end

function weighted_n_of_list(ctx::Context, count_value, items::AbstractVector, task::AbstractReporterTaskValue)
  count = Int(floor(numeric(count_value)))
  count < 0 && throw(LogoRuntimeError(
    "First input to RND:WEIGHTED-N-OF-LIST can't be negative."))
  available = length(items)
  count > available && throw(LogoRuntimeError(
    "Requesting $count random items from a candidate list of only $available items."))
  count == 0 && return Any[]
  weights = evaluate_list_weights(ctx, items, task)
  indices = pick_without_replacement(ctx.runtime.world.rng, weights, count)
  Any[items[i] for i in indices]
end

function weighted_n_of_repeats_agentset(ctx::Context, count_value, agentset::AgentSet, block)
  count = Int(floor(numeric(count_value)))
  count < 0 && throw(LogoRuntimeError(
    "First input to RND:WEIGHTED-N-OF-WITH-REPEATS can't be negative."))
  agents = live_agentset_members(agentset)
  available = length(agents)
  (count > 0 && available == 0) && throw(LogoRuntimeError(
    "Requesting $count random items from a candidate list of only 0 items."))
  count == 0 && return Any[]
  weights = evaluate_agent_weights(ctx, agents, block)
  indices = pick_with_repeats(ctx.runtime.world.rng, weights, count)
  Any[agents[i] for i in indices]
end

function weighted_n_of_repeats_list(ctx::Context, count_value, items::AbstractVector, task::AbstractReporterTaskValue)
  count = Int(floor(numeric(count_value)))
  count < 0 && throw(LogoRuntimeError(
    "First input to RND:WEIGHTED-N-OF-LIST-WITH-REPEATS can't be negative."))
  available = length(items)
  (count > 0 && available == 0) && throw(LogoRuntimeError(
    "Requesting $count random items from a candidate list of only 0 items."))
  count == 0 && return Any[]
  weights = evaluate_list_weights(ctx, items, task)
  indices = pick_with_repeats(ctx.runtime.world.rng, weights, count)
  Any[items[i] for i in indices]
end

# ── Extension registration ───────────────────────────────────────────────────

function register_extension!(registry::PrimitiveRegistry)

  # rnd:weighted-one-of <agentset> [ reporter ]
  register_primitive!(registry, "RND:WEIGHTED-ONE-OF", REPORTER,
    reporter_syntax(right=[AgentsetType, NumberBlockType],
      ret=AgentType | NobodyType,
      arg_modes=[:eval, :reporter_block]),
    (ctx, args) -> weighted_one_of_agentset(ctx, args[1], args[2]))

  # rnd:weighted-one-of-list <list> [ [x] -> reporter ]
  register_primitive!(registry, "RND:WEIGHTED-ONE-OF-LIST", REPORTER,
    reporter_syntax(right=[ListType, WildcardType],
      ret=WildcardType,
      arg_modes=[:eval, :reporter_task]),
    (ctx, args) -> weighted_one_of_list(ctx, args[1], args[2]))

  # rnd:weighted-n-of <n> <agentset> [ reporter ]
  register_primitive!(registry, "RND:WEIGHTED-N-OF", REPORTER,
    reporter_syntax(right=[NumberType, AgentsetType, NumberBlockType],
      ret=AgentsetType,
      arg_modes=[:eval, :eval, :reporter_block]),
    (ctx, args) -> weighted_n_of_agentset(ctx, args[1], args[2], args[3]))

  # rnd:weighted-n-of-list <n> <list> [ [x] -> reporter ]
  register_primitive!(registry, "RND:WEIGHTED-N-OF-LIST", REPORTER,
    reporter_syntax(right=[NumberType, ListType, WildcardType],
      ret=ListType,
      arg_modes=[:eval, :eval, :reporter_task]),
    (ctx, args) -> weighted_n_of_list(ctx, args[1], args[2], args[3]))

  # rnd:weighted-n-of-with-repeats <n> <agentset> [ reporter ]
  register_primitive!(registry, "RND:WEIGHTED-N-OF-WITH-REPEATS", REPORTER,
    reporter_syntax(right=[NumberType, AgentsetType, NumberBlockType],
      ret=ListType,
      arg_modes=[:eval, :eval, :reporter_block]),
    (ctx, args) -> weighted_n_of_repeats_agentset(ctx, args[1], args[2], args[3]))

  # rnd:weighted-n-of-list-with-repeats <n> <list> [ [x] -> reporter ]
  register_primitive!(registry, "RND:WEIGHTED-N-OF-LIST-WITH-REPEATS", REPORTER,
    reporter_syntax(right=[NumberType, ListType, WildcardType],
      ret=ListType,
      arg_modes=[:eval, :eval, :reporter_task]),
    (ctx, args) -> weighted_n_of_repeats_list(ctx, args[1], args[2], args[3]))

end

end # module rnd
