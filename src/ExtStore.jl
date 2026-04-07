module store

using JSON
using ..NetLogo: PrimitiveRegistry, register_primitive!, REPORTER, COMMAND,
  reporter_syntax, command_syntax,
  StringType, ListType, WildcardType, NumberType, BooleanType,
  LogoRuntimeError

const STORE_DIR = joinpath(homedir(), ".netlogo", "stores")
const _STATE_KEY = "__STORE_STATE"

mutable struct StoreState
  current_name::String
  data::Dict{String, String}  # current store's key-value pairs
end

# ── Persistence helpers ───────────────────────────────────────────────────────

function _store_path(name::String)::String
  joinpath(STORE_DIR, name * ".json")
end

function _load_store(name::String)::Dict{String, String}
  mkpath(STORE_DIR)
  path = _store_path(name)
  isfile(path) || return Dict{String, String}()
  raw =
    try
      JSON.parsefile(path)
    catch err
      throw(LogoRuntimeError("store: could not load store '$name': $(sprint(showerror, err))"))
    end
  raw isa AbstractDict || throw(LogoRuntimeError("store: invalid data in store '$name'"))
  data = Dict{String, String}()
  for (key, value) in pairs(raw)
    key isa AbstractString || throw(LogoRuntimeError("store: invalid key in store '$name'"))
    value isa AbstractString || throw(LogoRuntimeError("store: invalid value for key '$key' in store '$name'"))
    data[String(key)] = String(value)
  end
  data
end

function _save_store(name::String, data::Dict{String, String})
  mkpath(STORE_DIR)
  open(_store_path(name), "w") do io
    JSON.print(io, data, 2)
  end
end

function _list_all_stores()::Vector{String}
  mkpath(STORE_DIR)
  names = String[]
  for f in readdir(STORE_DIR)
    endswith(f, ".json") || continue
    push!(names, f[1:end-5])
  end
  # Always include "default" even if file doesn't exist yet
  "default" in names || pushfirst!(names, "default")
  sort!(names)
end

# ── State accessor ────────────────────────────────────────────────────────────

function _get_state(globals::Dict{String, Any})::StoreState
  get!(globals, _STATE_KEY) do
    StoreState("default", _load_store("default"))
  end
end

# ── Registration ──────────────────────────────────────────────────────────────

function register_extension!(registry::PrimitiveRegistry)

  # store:put key value
  register_primitive!(registry, "STORE:PUT", COMMAND,
    command_syntax(right=[StringType, StringType]),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      key = args[1]::String
      value = args[2]::String
      st.data[key] = value
      _save_store(st.current_name, st.data)
      nothing
    end)

  # store:get key → value
  register_primitive!(registry, "STORE:GET", REPORTER,
    reporter_syntax(right=[StringType], ret=StringType),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      key = args[1]::String
      haskey(st.data, key) || throw(LogoRuntimeError("Could not find a value for key: '$(key)'."))
      st.data[key]
    end)

  # store:has-key key → boolean
  register_primitive!(registry, "STORE:HAS-KEY", REPORTER,
    reporter_syntax(right=[StringType], ret=BooleanType),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      haskey(st.data, args[1]::String)
    end)

  # store:remove key
  register_primitive!(registry, "STORE:REMOVE", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      delete!(st.data, args[1]::String)
      _save_store(st.current_name, st.data)
      nothing
    end)

  # store:clear
  register_primitive!(registry, "STORE:CLEAR", COMMAND,
    command_syntax(),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      empty!(st.data)
      _save_store(st.current_name, st.data)
      nothing
    end)

  # store:get-keys → list
  register_primitive!(registry, "STORE:GET-KEYS", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      Any[collect(keys(st.data))...]
    end)

  # store:switch-store name
  register_primitive!(registry, "STORE:SWITCH-STORE", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      name = args[1]::String
      # Save current store before switching
      _save_store(st.current_name, st.data)
      # Handle "Default Store" or empty → "default"
      target = (name == "" || name == "Default Store") ? "default" : name
      st.current_name = target
      st.data = _load_store(target)
      nothing
    end)

  # store:list-stores → list
  register_primitive!(registry, "STORE:LIST-STORES", REPORTER,
    reporter_syntax(ret=ListType),
    (ctx, args) -> begin
      # Ensure current store is saved so it appears in listing
      st = _get_state(ctx.runtime.world.observer.globals)
      _save_store(st.current_name, st.data)
      Any[_list_all_stores()...]
    end)

  # store:delete-store name
  register_primitive!(registry, "STORE:DELETE-STORE", COMMAND,
    command_syntax(right=[StringType]),
    (ctx, args) -> begin
      st = _get_state(ctx.runtime.world.observer.globals)
      name = args[1]::String
      (name == "" || name == "Default Store" || name == "default") &&
        throw(LogoRuntimeError("Cannot delete the default store, but you can clear it if you want."))
      name == st.current_name &&
        throw(LogoRuntimeError("Cannot delete the current store, switch to another store first."))
      path = _store_path(name)
      isfile(path) && rm(path)
      nothing
    end)
end

end # module store
