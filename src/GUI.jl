using HTTP
using Printf

abstract type AbstractGUIBackend end

"""
    GUISession

Host-side GUI session that wraps a [`RuntimeState`](@ref) with a lock for browser or notebook interaction.
"""
mutable struct GUISession
  runtime::RuntimeState
  lock::ReentrantLock
end

"""
    WebGUIBackend

Running local HTTP GUI backend for a [`GUISession`](@ref).
"""
mutable struct WebGUIBackend <: AbstractGUIBackend
  session::GUISession
  host::String
  port::Int
  server::Any
end

"""
    NotebookGUI

Notebook-friendly wrapper that renders an iframe pointing at a running [`WebGUIBackend`](@ref).
"""
struct NotebookGUI <: AbstractGUIBackend
  backend::WebGUIBackend
  width::Int
  height::Int
  title::String
end

GUISession(runtime::RuntimeState) = GUISession(runtime, ReentrantLock())

"""
    gui_session(runtime::RuntimeState)
    gui_session(model::ModelSpec; extension_host=Main, kwargs...)

Create a GUI session from an existing runtime or from a compiled model.
When passed a model, keywords are forwarded to [`create_runtime`](@ref).
"""
gui_session(runtime::RuntimeState) = GUISession(runtime)
function gui_session(model::ModelSpec; extension_host::Module=Main, kwargs...)
  gui_session(create_runtime(model; extension_host=extension_host, kwargs...))
end

function with_gui_lock(f::Function, session::GUISession)
  lock(session.lock)
  try
    return f()
  finally
    unlock(session.lock)
  end
end

function gui_widget_specs(session::GUISession)
  InterfaceWidgetSpec[
    widget for widget in session.runtime.model.interface_widgets
    if !(widget isa ViewWidgetSpec)
  ]
end

widget_display_text(::InterfaceWidgetSpec) = ""
widget_display_text(widget::SliderWidgetSpec) = widget.display
widget_display_text(widget::SwitchWidgetSpec) = widget.display
widget_display_text(widget::ChooserWidgetSpec) = widget.display
widget_display_text(widget::MonitorWidgetSpec) = widget.display
widget_display_text(widget::ButtonWidgetSpec) = widget.display
widget_display_text(widget::TextBoxWidgetSpec) = widget.display

function widget_label(widget::InterfaceWidgetSpec)
  display = strip(widget_display_text(widget))
  !isempty(display) && return display
  name = widget_global_name(widget)
  name === nothing ? string(nameof(typeof(widget))) : String(name)
end

widget_bounds_json(widget::InterfaceWidgetSpec) = Dict(
  "left" => widget.left,
  "top" => widget.top,
  "right" => widget.right,
  "bottom" => widget.bottom,
  "width" => widget.right - widget.left,
  "height" => widget.bottom - widget.top,
)

function widget_identity_keys(widget::InterfaceWidgetSpec)
  keys = String[]
  name = widget_global_name(widget)
  name === nothing || push!(keys, canonical_name(name))
  display = strip(widget_display_text(widget))
  isempty(display) || push!(keys, canonical_name(display))
  if widget isa ButtonWidgetSpec
    source = strip(widget.source)
    isempty(source) || push!(keys, canonical_name(source))
  elseif widget isa MonitorWidgetSpec
    source = strip(widget.source)
    isempty(source) || push!(keys, canonical_name(source))
  end
  unique(keys)
end

function resolve_gui_widget_index(session::GUISession, selector::Integer)
  index = Int(selector)
  1 <= index <= length(gui_widget_specs(session)) || throw(LogoRuntimeError("No GUI widget with id $(selector)."))
  index
end

function resolve_gui_widget_index(session::GUISession, selector::AbstractString)
  key = canonical_name(selector)
  for (index, widget) in enumerate(gui_widget_specs(session))
    key in widget_identity_keys(widget) && return index
  end
  throw(LogoRuntimeError("No GUI widget matching \"$(selector)\"."))
end

function gui_json_value(value)
  if value === nothing
    return nothing
  elseif value isa Bool || value isa Number || value isa AbstractString
    return value
  elseif value isa AbstractVector
    return Any[gui_json_value(item) for item in value]
  elseif value isa Dict
    return Dict(string(key) => gui_json_value(item) for (key, item) in value)
  end
  logo_string(value)
end

function gui_color_css(value)
  red, green, blue, alpha = extract_rgba_channels(value)
  @sprintf(
    "rgba(%d, %d, %d, %.4f)",
    round(Int, red),
    round(Int, green),
    round(Int, blue),
    clamp(Float64(alpha) / 255.0, 0.0, 1.0),
  )
end

function gui_monitor_text(value, precision::Integer)
  if value isa Real
    number = Float64(value)
    isfinite(number) || return string(number)
    return @sprintf("%.*f", max(0, Int(precision)), number)
  end
  display_logo_string(value)
end

function gui_root_context(runtime::RuntimeState)
  Context(runtime, runtime.world.observer, [Dict{String, Any}()], nothing, false, 1)
end

function gui_button_agent(runtime::RuntimeState, widget::ButtonWidgetSpec)
  kind = uppercase(strip(widget.button_kind))
  if isempty(kind) || kind == "OBSERVER"
    return runtime.world.observer
  end

  subject = current_perspective_subject!(runtime)
  if kind == "TURTLE"
    subject isa Turtle && return subject
    throw(LogoRuntimeError("Button \"$(widget_label(widget))\" requires a turtle perspective subject."))
  elseif kind == "PATCH"
    subject isa Patch && return subject
    throw(LogoRuntimeError("Button \"$(widget_label(widget))\" requires a patch perspective subject."))
  elseif kind == "LINK"
    subject isa Link && return subject
    throw(LogoRuntimeError("Button \"$(widget_label(widget))\" requires a link perspective subject."))
  end
  runtime.world.observer
end

function gui_button_context(runtime::RuntimeState, widget::ButtonWidgetSpec)
  Context(runtime, gui_button_agent(runtime, widget), [Dict{String, Any}()], nothing, false, 1)
end

function gui_widget_value(runtime::RuntimeState, widget::InterfaceWidgetSpec)
  name = widget_global_name(widget)
  name === nothing && return nothing
  key = canonical_name(name)
  if haskey(runtime.world.observer.globals, key)
    return runtime.world.observer.globals[key]
  elseif haskey(runtime.model.interface_globals, key)
    return runtime.model.interface_globals[key]
  end
  widget_global_value(widget)
end

function gui_update_widget_value!(runtime::RuntimeState, widget::InterfaceWidgetSpec, value)
  name = widget_global_name(widget)
  name === nothing && throw(LogoRuntimeError("Widget \"$(widget_label(widget))\" does not store a value."))
  key = canonical_name(name)
  runtime.world.observer.globals[key] = value
  runtime.model.interface_globals[key] = value
  value
end

function gui_eval_numeric(runtime::RuntimeState, source::AbstractString, default::Float64)
  stripped = strip(String(source))
  isempty(stripped) && return default
  value = runresult_string(gui_root_context(runtime), stripped)
  Float64(numeric(value))
end

function gui_slider_bounds(runtime::RuntimeState, widget::SliderWidgetSpec)
  minimum = gui_eval_numeric(runtime, widget.minimum, widget.default_value)
  maximum = gui_eval_numeric(runtime, widget.maximum, widget.default_value)
  step = gui_eval_numeric(runtime, widget.step, 1.0)
  step <= 0 && throw(LogoRuntimeError("Slider \"$(widget_label(widget))\" must have a positive step."))
  minimum, maximum, step
end

function gui_input_type(widget::InputBoxWidgetSpec)
  kind = uppercase(strip(widget.value_kind))
  if widget.multiline
    return "textarea"
  elseif kind == "NUMBER"
    return "number"
  end
  "text"
end

function gui_chooser_index(widget::ChooserWidgetSpec, value)
  index = findfirst(choice -> isequal(choice, value), widget.choices)
  index === nothing ? widget.current_choice : index - 1
end

function gui_widget_json(runtime::RuntimeState, widget::SliderWidgetSpec, index::Int)
  value = gui_widget_value(runtime, widget)
  error_message = nothing
  minimum = widget.default_value
  maximum = widget.default_value
  step = 1.0
  try
    minimum, maximum, step = gui_slider_bounds(runtime, widget)
  catch err
    error_message = sprint(showerror, err)
  end

  payload = Dict(
    "id" => index,
    "type" => "slider",
    "label" => widget_label(widget),
    "display" => widget.display,
    "variable" => widget.variable,
    "bounds" => widget_bounds_json(widget),
    "value" => value isa Real ? Float64(value) : gui_json_value(value),
    "displayValue" => display_logo_string(value),
    "minimum" => minimum,
    "maximum" => maximum,
    "step" => step,
    "units" => widget.units,
    "direction" => lowercase(widget.direction),
  )
  error_message === nothing || (payload["error"] = error_message)
  payload
end

function gui_widget_json(runtime::RuntimeState, widget::SwitchWidgetSpec, index::Int)
  value = gui_widget_value(runtime, widget)
  Dict(
    "id" => index,
    "type" => "switch",
    "label" => widget_label(widget),
    "display" => widget.display,
    "variable" => widget.variable,
    "bounds" => widget_bounds_json(widget),
    "value" => logical(value),
  )
end

function gui_widget_json(runtime::RuntimeState, widget::ChooserWidgetSpec, index::Int)
  value = gui_widget_value(runtime, widget)
  Dict(
    "id" => index,
    "type" => "chooser",
    "label" => widget_label(widget),
    "display" => widget.display,
    "variable" => widget.variable,
    "bounds" => widget_bounds_json(widget),
    "selectedIndex" => gui_chooser_index(widget, value),
    "selectedValue" => gui_json_value(value),
    "displayValue" => display_logo_string(value),
    "choices" => Any[
      Dict(
        "index" => choice_index - 1,
        "value" => gui_json_value(choice),
        "display" => display_logo_string(choice),
      ) for (choice_index, choice) in enumerate(widget.choices)
    ],
  )
end

function gui_widget_json(runtime::RuntimeState, widget::InputBoxWidgetSpec, index::Int)
  value = gui_widget_value(runtime, widget)
  Dict(
    "id" => index,
    "type" => "input",
    "label" => widget_label(widget),
    "variable" => widget.variable,
    "bounds" => widget_bounds_json(widget),
    "value" => gui_json_value(value),
    "displayValue" => display_logo_string(value),
    "multiline" => widget.multiline,
    "valueKind" => widget.value_kind,
    "inputType" => gui_input_type(widget),
  )
end

function gui_widget_json(runtime::RuntimeState, widget::MonitorWidgetSpec, index::Int)
  payload = Dict(
    "id" => index,
    "type" => "monitor",
    "label" => widget_label(widget),
    "display" => widget.display,
    "source" => widget.source,
    "precision" => widget.precision,
    "fontSize" => widget.font_size,
    "bounds" => widget_bounds_json(widget),
    "value" => nothing,
    "displayValue" => "",
  )
  try
    value = runresult_string(gui_root_context(runtime), widget.source)
    payload["value"] = gui_json_value(value)
    payload["displayValue"] = gui_monitor_text(value, widget.precision)
  catch err
    payload["error"] = sprint(showerror, err)
  end
  payload
end

function gui_widget_json(runtime::RuntimeState, widget::ButtonWidgetSpec, index::Int)
  Dict(
    "id" => index,
    "type" => "button",
    "label" => widget_label(widget),
    "display" => widget.display,
    "source" => widget.source,
    "forever" => widget.forever,
    "buttonKind" => widget.button_kind,
    "actionKey" => widget.action_key === nothing ? nothing : string(widget.action_key),
    "disableUntilTicksStart" => widget.disable_until_ticks_start,
    "bounds" => widget_bounds_json(widget),
  )
end

function gui_widget_json(runtime::RuntimeState, widget::TextBoxWidgetSpec, index::Int)
  Dict(
    "id" => index,
    "type" => "text",
    "label" => widget.display,
    "display" => widget.display,
    "fontSize" => widget.font_size,
    "color" => gui_color_css(widget.color),
    "transparent" => widget.transparent,
    "bounds" => widget_bounds_json(widget),
  )
end

function gui_widget_json(runtime::RuntimeState, widget::OutputWidgetSpec, index::Int)
  Dict(
    "id" => index,
    "type" => "output",
    "label" => "Output",
    "fontSize" => widget.font_size,
    "bounds" => widget_bounds_json(widget),
    "content" => runtime.output_area,
  )
end

function gui_plot_mode_name(mode::Integer)
  mode == PLOT_PEN_BAR_MODE && return "bar"
  mode == PLOT_PEN_POINT_MODE && return "point"
  "line"
end

function gui_plot_pen_json(pen::PlotPenState)
  Dict(
    "name" => pen.name,
    "temporary" => pen.temporary,
    "mode" => pen.mode,
    "modeName" => gui_plot_mode_name(pen.mode),
    "color" => gui_color_css(pen.color),
    "interval" => pen.interval,
    "x" => pen.x,
    "isDown" => pen.is_down,
    "hidden" => pen.hidden,
    "inLegend" => pen.in_legend,
    "points" => Any[
      Dict(
        "x" => point.x,
        "y" => point.y,
        "penDown" => point.is_down,
        "color" => gui_color_css(point.color),
      ) for point in pen.points
    ],
  )
end

function gui_plot_json(plot::PlotState)
  Dict(
    "name" => plot.name,
    "xMin" => plot.x_min,
    "xMax" => plot.x_max,
    "yMin" => plot.y_min,
    "yMax" => plot.y_max,
    "autoPlotX" => plot.auto_plot_x,
    "autoPlotY" => plot.auto_plot_y,
    "legendOpen" => plot.legend_open,
    "currentPen" => plot.current_pen === nothing ? nothing : plot.current_pen.name,
    "pens" => Any[gui_plot_pen_json(pen) for pen in plot.pens],
  )
end

function gui_view_state(runtime::RuntimeState)
  world = runtime.world
  widget = runtime.model.view_widget
  wrap_x = world.topology == Torus || world.topology == VerticalCylinder
  wrap_y = world.topology == Torus || world.topology == HorizontalCylinder
  Dict(
    "width" => max(1, drawing_width(world)),
    "height" => max(1, drawing_height(world)),
    "patchSize" => world.patch_size,
    "minPxcor" => world.min_pxcor,
    "maxPxcor" => world.max_pxcor,
    "minPycor" => world.min_pycor,
    "maxPycor" => world.max_pycor,
    "wrapX" => wrap_x,
    "wrapY" => wrap_y,
    "showTickCounter" => widget === nothing ? true : widget.show_tick_counter,
    "tickCounterLabel" => widget === nothing ? "ticks" : widget.tick_counter_label,
    "frameRate" => widget === nothing ? 30.0 : widget.frame_rate,
    "imageUrl" => "/api/view.png",
  )
end

"""
    gui_state(session::GUISession)

Return a JSON-friendly snapshot of the current GUI-visible state: widgets, ticks, plots, output buffers, and view metadata.
"""
function gui_state(session::GUISession)
  with_gui_lock(session) do
    runtime = session.runtime
    Dict(
      "ticks" => Dict(
        "started" => ticks_started(runtime.world),
        "value" => runtime.world.ticks,
      ),
      "view" => gui_view_state(runtime),
      "widgets" => Any[gui_widget_json(runtime, widget, index) for (index, widget) in enumerate(gui_widget_specs(session))],
      "plots" => Any[gui_plot_json(plot) for plot in runtime.plot_manager.plots],
      "outputArea" => runtime.output_area,
      "commandOutput" => runtime.command_output,
      "errors" => copy(runtime.error_messages),
      "perspectiveSubject" => logo_string(current_perspective_subject!(runtime)),
    )
  end
end

parse_gui_number(value::Real) = Float64(value)
function parse_gui_number(value)
  stripped = strip(String(value))
  isempty(stripped) && throw(LogoRuntimeError("Expected a numeric widget value."))
  try
    parse(Float64, stripped)
  catch err
    throw(LogoRuntimeError("Expected a numeric widget value, got \"$(value)\": $(sprint(showerror, err))"))
  end
end

parse_gui_bool(value::Bool) = value
parse_gui_bool(value::Real) = !iszero(value)
function parse_gui_bool(value)
  normalized = lowercase(strip(String(value)))
  normalized in ("true", "1", "yes", "on") && return true
  normalized in ("false", "0", "no", "off") && return false
  throw(LogoRuntimeError("Expected a boolean widget value, got \"$(value)\"."))
end

function snap_slider_value(value::Float64, minimum::Float64, step::Float64)
  step <= 0 && return value
  minimum + round((value - minimum) / step) * step
end

function set_gui_widget!(runtime::RuntimeState, widget::SliderWidgetSpec, value)
  minimum, maximum, step = gui_slider_bounds(runtime, widget)
  number = parse_gui_number(value)
  low = min(minimum, maximum)
  high = max(minimum, maximum)
  snapped = snap_slider_value(number, minimum, step)
  gui_update_widget_value!(runtime, widget, clamp(snapped, low, high))
end

function set_gui_widget!(runtime::RuntimeState, widget::SwitchWidgetSpec, value)
  gui_update_widget_value!(runtime, widget, parse_gui_bool(value))
end

function set_gui_widget!(runtime::RuntimeState, widget::ChooserWidgetSpec, value)
  if value isa Integer
    index = Int(value)
    1 <= index <= length(widget.choices) || throw(LogoRuntimeError("Chooser \"$(widget_label(widget))\" index $(value) is out of range."))
    return gui_update_widget_value!(runtime, widget, widget.choices[index])
  end

  string_value = String(value)
  match = findfirst(widget.choices) do choice
    isequal(choice, value) ||
      display_logo_string(choice) == string_value ||
      logo_string(choice) == string_value
  end
  match === nothing && throw(LogoRuntimeError("Chooser \"$(widget_label(widget))\" has no choice matching \"$(value)\"."))
  gui_update_widget_value!(runtime, widget, widget.choices[match])
end

function set_gui_widget!(runtime::RuntimeState, widget::InputBoxWidgetSpec, value)
  kind = uppercase(strip(widget.value_kind))
  parsed =
    if kind == "NUMBER"
      parse_gui_number(value)
    elseif kind == "STRING"
      String(value)
    elseif value isa AbstractString
      read_literal_from_string(value)
    else
      value
    end
  gui_update_widget_value!(runtime, widget, parsed)
end

function set_gui_widget!(runtime::RuntimeState, widget::InterfaceWidgetSpec, value)
  throw(LogoRuntimeError("Widget \"$(widget_label(widget))\" cannot be assigned a value from the GUI."))
end

"""
    set_gui_widget!(session::GUISession, selector, value)

Update a GUI control in-place. `selector` can be a 1-based widget id or a widget/global name.
"""
function set_gui_widget!(session::GUISession, selector, value)
  with_gui_lock(session) do
    index = resolve_gui_widget_index(session, selector)
    set_gui_widget!(session.runtime, gui_widget_specs(session)[index], value)
  end
end

function gui_simple_button_procedure(runtime::RuntimeState, widget::ButtonWidgetSpec)
  source = strip(widget.source)
  isempty(source) && return nothing
  occursin('\n', source) && return nothing
  occursin('[', source) && return nothing
  tokens = split(source)
  length(tokens) == 1 || return nothing
  procedure = get(runtime.model.procedures, canonical_name(tokens[1]), nothing)
  procedure isa ProcedureSpec || return nothing
  procedure.is_reporter && return nothing
  isempty(procedure.inputs) || return nothing
  source
end

"""
    press_gui_button!(session::GUISession, selector)

Execute a GUI button by 1-based widget id or button label.
"""
function press_gui_button!(session::GUISession, selector)
  with_gui_lock(session) do
    index = resolve_gui_widget_index(session, selector)
    widget = gui_widget_specs(session)[index]
    widget isa ButtonWidgetSpec || throw(LogoRuntimeError("Widget \"$(selector)\" is not a button."))
    simple_proc = gui_simple_button_procedure(session.runtime, widget)
    simple_proc !== nothing && return call!(session.runtime, simple_proc)
    isempty(strip(widget.source)) && return false
    try
      run_string!(gui_button_context(session.runtime, widget), widget.source)
      false
    catch signal
      signal isa StopSignal || rethrow()
      true
    end
  end
end

function gui_render_view_png(runtime::RuntimeState)
  path = tempname() * ".png"
  try
    export_view!(runtime, path)
    read(path)
  finally
    isfile(path) && rm(path; force=true)
  end
end

function gui_json_response(status::Integer, payload)
  HTTP.Response(
    status,
    ["Content-Type" => "application/json; charset=utf-8", "Cache-Control" => "no-store"],
    JSON.json(payload),
  )
end

function gui_error_response(status::Integer, err)
  gui_json_response(status, Dict("error" => sprint(showerror, err)))
end

function gui_request_payload(request::HTTP.Request)
  isempty(request.body) && return Dict{String, Any}()
  payload = JSON.parse(String(request.body))
  payload isa AbstractDict || throw(LogoRuntimeError("Expected a JSON object request body."))
  Dict{String, Any}(String(key) => value for (key, value) in pairs(payload))
end

function gui_http_handler(session::GUISession)
  function (request::HTTP.Request)
    try
      target = HTTP.URIs.URI(String(request.target))
      path = isempty(target.path) ? "/" : target.path
      segments = [segment for segment in split(path, '/') if !isempty(segment)]
      method = String(request.method)

      if method == "GET" && (path == "/" || path == "/index.html")
        return HTTP.Response(
          200,
          ["Content-Type" => "text/html; charset=utf-8", "Cache-Control" => "no-store"],
          gui_application_html(),
        )
      elseif method == "GET" && path == "/api/state"
        return gui_json_response(200, gui_state(session))
      elseif method == "GET" && path == "/api/view.png"
        image = with_gui_lock(session) do
          gui_render_view_png(session.runtime)
        end
        return HTTP.Response(200, ["Content-Type" => "image/png", "Cache-Control" => "no-store"], image)
      elseif method == "POST" && length(segments) == 3 && segments[1] == "api" && segments[2] == "widgets"
        widget_id = parse(Int, segments[3])
        payload = gui_request_payload(request)
        value =
          if haskey(payload, "choiceIndex")
            Int(payload["choiceIndex"]) + 1
          elseif haskey(payload, "value")
            payload["value"]
          else
            payload
          end
        set_gui_widget!(session, widget_id, value)
        return gui_json_response(200, gui_state(session))
      elseif method == "POST" && length(segments) == 4 && segments[1] == "api" && segments[2] == "buttons" && segments[4] == "press"
        button_id = parse(Int, segments[3])
        stopped = press_gui_button!(session, button_id)
        payload = gui_state(session)
        payload["buttonStopped"] = stopped
        return gui_json_response(200, payload)
      end

      HTTP.Response(404, ["Content-Type" => "text/plain; charset=utf-8"], "Not found")
    catch err
      status = err isa LogoRuntimeError || err isa ArgumentError ? 400 : 500
      gui_error_response(status, err)
    end
  end
end

"""
    start_web_gui(session::GUISession; host="127.0.0.1", port=8080)
    start_web_gui(runtime::RuntimeState; host="127.0.0.1", port=8080)
    start_web_gui(model::ModelSpec; host="127.0.0.1", port=8080, extension_host=Main, kwargs...)

Start a lightweight local web UI for a NetLogo runtime or model.
"""
function start_web_gui(session::GUISession; host::AbstractString="127.0.0.1", port::Integer=8080)
  port > 0 || throw(ArgumentError("GUI port must be positive."))
  server = HTTP.serve!(gui_http_handler(session), String(host), Int(port); verbose=false)
  WebGUIBackend(session, String(host), Int(port), server)
end

function start_web_gui(runtime::RuntimeState; host::AbstractString="127.0.0.1", port::Integer=8080)
  start_web_gui(gui_session(runtime); host=host, port=port)
end

function start_web_gui(
  model::ModelSpec;
  host::AbstractString="127.0.0.1",
  port::Integer=8080,
  extension_host::Module=Main,
  kwargs...)
  start_web_gui(gui_session(model; extension_host=extension_host, kwargs...); host=host, port=port)
end

"""
    stop_web_gui!(backend::WebGUIBackend)

Stop a running local web GUI server.
"""
function stop_web_gui!(backend::WebGUIBackend)
  backend.server === nothing && return nothing
  close(backend.server)
  backend.server = nothing
  nothing
end

"""
    web_gui_url(backend::WebGUIBackend)

Return the local URL for a running web GUI backend.
"""
function web_gui_url(backend::WebGUIBackend)
  host = backend.host == "0.0.0.0" ? "127.0.0.1" : backend.host
  "http://$(host):$(backend.port)/"
end

"""
    notebook_gui(backend::WebGUIBackend; width=1100, height=900, title="NetLogo.jl GUI")
    notebook_gui(session::GUISession; host="127.0.0.1", port=8080, width=1100, height=900, title="NetLogo.jl GUI")
    notebook_gui(runtime::RuntimeState; host="127.0.0.1", port=8080, width=1100, height=900)
    notebook_gui(model::ModelSpec; host="127.0.0.1", port=8080, width=1100, height=900, extension_host=Main, kwargs...)

Create a notebook/Pluto-friendly iframe wrapper around the local web GUI.
"""
function notebook_gui(
  backend::WebGUIBackend;
  width::Integer=1100,
  height::Integer=900,
  title::AbstractString="NetLogo.jl GUI")
  NotebookGUI(backend, Int(width), Int(height), String(title))
end

function notebook_gui(
  session::GUISession;
  host::AbstractString="127.0.0.1",
  port::Integer=8080,
  width::Integer=1100,
  height::Integer=900,
  title::AbstractString="NetLogo.jl GUI")
  notebook_gui(start_web_gui(session; host=host, port=port); width=width, height=height, title=title)
end

function notebook_gui(
  runtime::RuntimeState;
  host::AbstractString="127.0.0.1",
  port::Integer=8080,
  width::Integer=1100,
  height::Integer=900,
  title::AbstractString="NetLogo.jl GUI")
  notebook_gui(gui_session(runtime); host=host, port=port, width=width, height=height, title=title)
end

function notebook_gui(
  model::ModelSpec;
  host::AbstractString="127.0.0.1",
  port::Integer=8080,
  width::Integer=1100,
  height::Integer=900,
  title::AbstractString="NetLogo.jl GUI",
  extension_host::Module=Main,
  kwargs...)
  notebook_gui(
    gui_session(model; extension_host=extension_host, kwargs...);
    host=host,
    port=port,
    width=width,
    height=height,
    title=title,
  )
end

"""
    pluto_gui(args...; kwargs...)

Alias for [`notebook_gui`](@ref) for Pluto-oriented workflows.
"""
pluto_gui(args...; kwargs...) = notebook_gui(args...; kwargs...)

function html_escape(value::AbstractString)
  escaped = replace(String(value), "&" => "&amp;")
  escaped = replace(escaped, "<" => "&lt;")
  escaped = replace(escaped, ">" => "&gt;")
  escaped = replace(escaped, "\"" => "&quot;")
  replace(escaped, "'" => "&#39;")
end

function Base.show(io::IO, backend::WebGUIBackend)
  print(io, "WebGUIBackend(", web_gui_url(backend), ")")
end

function Base.show(io::IO, gui::NotebookGUI)
  print(io, "NotebookGUI(", web_gui_url(gui.backend), ")")
end

function Base.show(io::IO, ::MIME"text/html", gui::NotebookGUI)
  url = html_escape(web_gui_url(gui.backend))
  title = html_escape(gui.title)
  print(
    io,
    "<div class=\"netlogo-gui-embed\">",
    "<p><strong>", title, "</strong> ",
    "<a href=\"", url, "\" target=\"_blank\" rel=\"noopener noreferrer\">open in new tab</a></p>",
    "<iframe src=\"", url, "\" width=\"", gui.width, "\" height=\"", gui.height,
    "\" style=\"border: 1px solid #d0d7de; border-radius: 8px; background: white; width: 100%; max-width: 100%;\"></iframe>",
    "</div>",
  )
end

function gui_application_html()
  """
  <!doctype html>
  <html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>NetLogo.jl GUI</title>
    <style>
      :root {
        color-scheme: light;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      body {
        margin: 0;
        background: #f6f8fa;
        color: #1f2328;
      }
      .page {
        padding: 1.25rem;
      }
      .header {
        display: flex;
        flex-wrap: wrap;
        justify-content: space-between;
        align-items: baseline;
        gap: 0.75rem;
        margin-bottom: 1rem;
      }
      .header h1 {
        margin: 0;
        font-size: 1.5rem;
      }
      .layout {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
        gap: 1rem;
      }
      .panel {
        background: white;
        border: 1px solid #d0d7de;
        border-radius: 10px;
        padding: 1rem;
        box-shadow: 0 1px 2px rgba(31, 35, 40, 0.05);
      }
      .panel.wide {
        grid-column: span 2;
      }
      .panel h2 {
        margin-top: 0;
        font-size: 1rem;
      }
      .controls,
      .monitors,
      .plots,
      .notes,
      .errors {
        display: grid;
        gap: 0.75rem;
      }
      .control,
      .monitor,
      .plot-card,
      .note,
      .error-card {
        border: 1px solid #d8dee4;
        border-radius: 8px;
        padding: 0.75rem;
        background: #ffffff;
      }
      .control label,
      .control .control-title,
      .monitor .monitor-title,
      .plot-title {
        font-weight: 600;
      }
      .control small,
      .monitor small,
      .plot-meta {
        color: #59636e;
      }
      .control input[type="range"] {
        width: 100%;
      }
      .control select,
      .control input[type="text"],
      .control input[type="number"],
      .control textarea,
      .control button {
        width: 100%;
        box-sizing: border-box;
        margin-top: 0.35rem;
        padding: 0.45rem 0.55rem;
        border-radius: 6px;
        border: 1px solid #d0d7de;
        font: inherit;
      }
      .control button {
        background: #0969da;
        color: white;
        border-color: #0969da;
        cursor: pointer;
      }
      .control button:disabled {
        cursor: not-allowed;
        background: #94a3b8;
        border-color: #94a3b8;
      }
      .monitor-value {
        font-size: 1.35rem;
        margin-top: 0.35rem;
      }
      .plot-card svg {
        width: 100%;
        height: 240px;
        display: block;
        background: #f6f8fa;
        border-radius: 6px;
      }
      .plot-legend {
        display: flex;
        flex-wrap: wrap;
        gap: 0.5rem 1rem;
        margin-top: 0.5rem;
        font-size: 0.9rem;
      }
      .plot-legend-item {
        display: inline-flex;
        align-items: center;
        gap: 0.35rem;
      }
      .plot-swatch {
        width: 0.9rem;
        height: 0.9rem;
        border-radius: 999px;
        display: inline-block;
      }
      #view-image {
        max-width: 100%;
        border: 1px solid #d8dee4;
        border-radius: 8px;
        image-rendering: pixelated;
        background: white;
      }
      .output {
        margin: 0;
        min-height: 8rem;
        max-height: 18rem;
        overflow: auto;
        padding: 0.75rem;
        border-radius: 8px;
        border: 1px solid #d8dee4;
        background: #0d1117;
        color: #e6edf3;
        white-space: pre-wrap;
      }
      .note {
        white-space: pre-wrap;
      }
      .error-card {
        background: #fff8f8;
        border-color: #ffb3b3;
      }
      @media (max-width: 960px) {
        .panel.wide {
          grid-column: span 1;
        }
      }
    </style>
  </head>
  <body>
    <div class="page">
      <div class="header">
        <h1>NetLogo.jl GUI</h1>
        <div id="status">Connecting…</div>
      </div>
      <div class="layout">
        <section class="panel">
          <h2>Controls</h2>
          <div id="controls" class="controls"></div>
        </section>
        <section class="panel">
          <h2>Monitors</h2>
          <div id="monitors" class="monitors"></div>
        </section>
        <section class="panel wide">
          <h2>View</h2>
          <img id="view-image" alt="NetLogo view">
        </section>
        <section class="panel wide">
          <h2>Plots</h2>
          <div id="plots" class="plots"></div>
        </section>
        <section class="panel">
          <h2>Text Boxes</h2>
          <div id="text-boxes" class="notes"></div>
        </section>
        <section class="panel">
          <h2>Output</h2>
          <pre id="output-area" class="output"></pre>
        </section>
        <section class="panel">
          <h2>Command Output</h2>
          <pre id="command-output" class="output"></pre>
        </section>
        <section class="panel wide">
          <h2>Errors</h2>
          <div id="errors" class="errors"></div>
        </section>
      </div>
    </div>
    <script>
      'use strict';

      const SVG_NS = 'http://www.w3.org/2000/svg';
      const foreverTimers = {};
      let state = null;
      let transientError = null;

      function clearChildren(node) {
        while (node.firstChild) {
          node.removeChild(node.firstChild);
        }
      }

      function asText(value) {
        if (value === null || value === undefined) {
          return '';
        }
        return String(value);
      }

      async function apiJson(path, options) {
        const response = await fetch(path, Object.assign({
          headers: {
            'Content-Type': 'application/json'
          }
        }, options || {}));
        const contentType = response.headers.get('content-type') || '';
        const payload = contentType.includes('application/json') ? await response.json() : null;
        if (!response.ok) {
          throw new Error(payload && payload.error ? payload.error : response.statusText);
        }
        return payload;
      }

      async function refreshState() {
        try {
          state = await apiJson('/api/state');
          transientError = null;
        } catch (error) {
          transientError = error.message;
        }
        render();
      }

      async function updateWidget(id, payload) {
        state = await apiJson('/api/widgets/' + id, {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        transientError = null;
        render();
      }

      async function pressButton(id) {
        state = await apiJson('/api/buttons/' + id + '/press', {
          method: 'POST',
          body: '{}'
        });
        transientError = null;
        render();
      }

      function stopForever(id) {
        if (foreverTimers[id]) {
          clearInterval(foreverTimers[id]);
          delete foreverTimers[id];
        }
      }

      function foreverDelayMs() {
        if (!state || !state.view) {
          return 250;
        }
        const frameRate = Number(state.view.frameRate);
        if (!Number.isFinite(frameRate) || frameRate <= 0) {
          return 250;
        }
        return Math.max(50, Math.round(1000 / frameRate));
      }

      async function runForever(widgetId) {
        try {
          await pressButton(widgetId);
          if (state && state.buttonStopped) {
            stopForever(widgetId);
            renderControls();
          }
        } catch (error) {
          transientError = error.message;
          stopForever(widgetId);
          renderErrors();
        }
      }

      function toggleForever(widget) {
        if (foreverTimers[widget.id]) {
          stopForever(widget.id);
          renderControls();
          return;
        }
        foreverTimers[widget.id] = setInterval(function () {
          void runForever(widget.id);
        }, foreverDelayMs());
        void runForever(widget.id);
        renderControls();
      }

      function makeSectionCard(className) {
        const card = document.createElement('div');
        card.className = className;
        return card;
      }

      function setStatus() {
        const node = document.getElementById('status');
        if (!state) {
          node.textContent = transientError ? 'Disconnected' : 'Connecting…';
          return;
        }
        const ticks = state.ticks && state.ticks.started
          ? state.ticks.value
          : 'not started';
        node.textContent = 'ticks: ' + ticks + ' · subject: ' + asText(state.perspectiveSubject);
      }

      function renderControls() {
        const root = document.getElementById('controls');
        clearChildren(root);
        if (!state) {
          return;
        }

        const controls = state.widgets.filter(function (widget) {
          return widget.type === 'slider' ||
            widget.type === 'switch' ||
            widget.type === 'chooser' ||
            widget.type === 'input' ||
            widget.type === 'button';
        });

        if (controls.length === 0) {
          const empty = makeSectionCard('control');
          empty.textContent = 'No interactive controls in this model.';
          root.appendChild(empty);
          return;
        }

        controls.forEach(function (widget) {
          const card = makeSectionCard('control');
          const title = document.createElement('div');
          title.className = 'control-title';
          title.textContent = widget.label;
          card.appendChild(title);

          if (widget.variable) {
            const variable = document.createElement('small');
            variable.textContent = widget.variable;
            card.appendChild(variable);
          }

          if (widget.type === 'slider') {
            const input = document.createElement('input');
            input.type = 'range';
            input.min = asText(widget.minimum);
            input.max = asText(widget.maximum);
            input.step = asText(widget.step);
            input.value = asText(widget.value);
            const readout = document.createElement('small');
            readout.textContent = asText(widget.displayValue) + (widget.units ? ' ' + widget.units : '');
            input.addEventListener('input', function () {
              readout.textContent = asText(input.value) + (widget.units ? ' ' + widget.units : '');
            });
            input.addEventListener('change', function () {
              void updateWidget(widget.id, { value: Number(input.value) });
            });
            card.appendChild(input);
            card.appendChild(readout);
          } else if (widget.type === 'switch') {
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.checked = Boolean(widget.value);
            checkbox.addEventListener('change', function () {
              void updateWidget(widget.id, { value: checkbox.checked });
            });
            card.appendChild(checkbox);
          } else if (widget.type === 'chooser') {
            const select = document.createElement('select');
            widget.choices.forEach(function (choice) {
              const option = document.createElement('option');
              option.value = asText(choice.index);
              option.textContent = asText(choice.display);
              select.appendChild(option);
            });
            select.selectedIndex = Number(widget.selectedIndex);
            select.addEventListener('change', function () {
              void updateWidget(widget.id, { choiceIndex: Number(select.value) });
            });
            card.appendChild(select);
          } else if (widget.type === 'input') {
            const editor = widget.inputType === 'textarea'
              ? document.createElement('textarea')
              : document.createElement('input');
            if (editor.tagName === 'INPUT') {
              editor.type = widget.inputType;
            }
            editor.value = asText(widget.value);
            const commit = function () {
              const value = editor.type === 'number' && editor.value !== ''
                ? Number(editor.value)
                : editor.value;
              void updateWidget(widget.id, { value: value });
            };
            editor.addEventListener('change', commit);
            editor.addEventListener('blur', commit);
            card.appendChild(editor);
          } else if (widget.type === 'button') {
            const button = document.createElement('button');
            const running = Boolean(foreverTimers[widget.id]);
            button.textContent = running ? widget.label + ' (running)' : widget.label;
            button.title = widget.source || widget.label;
            if (widget.disableUntilTicksStart && state.ticks && !state.ticks.started) {
              stopForever(widget.id);
              button.disabled = true;
            }
            button.addEventListener('click', function () {
              if (widget.forever) {
                toggleForever(widget);
              } else {
                void pressButton(widget.id);
              }
            });
            card.appendChild(button);
            if (widget.buttonKind) {
              const meta = document.createElement('small');
              meta.textContent = widget.buttonKind.toLowerCase();
              card.appendChild(meta);
            }
          }

          if (widget.error) {
            const error = document.createElement('small');
            error.textContent = widget.error;
            error.style.color = '#cf222e';
            card.appendChild(error);
          }

          root.appendChild(card);
        });
      }

      function renderMonitors() {
        const root = document.getElementById('monitors');
        clearChildren(root);
        if (!state) {
          return;
        }

        const monitors = state.widgets.filter(function (widget) {
          return widget.type === 'monitor';
        });

        if (monitors.length === 0) {
          const empty = makeSectionCard('monitor');
          empty.textContent = 'No monitors in this model.';
          root.appendChild(empty);
          return;
        }

        monitors.forEach(function (widget) {
          const card = makeSectionCard('monitor');
          const title = document.createElement('div');
          title.className = 'monitor-title';
          title.textContent = widget.label;
          card.appendChild(title);
          const value = document.createElement('div');
          value.className = 'monitor-value';
          value.textContent = widget.error ? widget.error : asText(widget.displayValue);
          if (widget.error) {
            value.style.color = '#cf222e';
          }
          card.appendChild(value);
          root.appendChild(card);
        });
      }

      function renderView() {
        const image = document.getElementById('view-image');
        if (!state || !state.view) {
          image.removeAttribute('src');
          return;
        }
        image.width = Number(state.view.width);
        image.height = Number(state.view.height);
        image.src = '/api/view.png?nonce=' + Date.now();
      }

      function makeSvgElement(name) {
        return document.createElementNS(SVG_NS, name);
      }

      function svgPoint(plot, width, height, point) {
        const xSpan = plot.xMax === plot.xMin ? 1 : (plot.xMax - plot.xMin);
        const ySpan = plot.yMax === plot.yMin ? 1 : (plot.yMax - plot.yMin);
        return {
          x: 30 + ((point.x - plot.xMin) / xSpan) * (width - 40),
          y: (height - 20) - ((point.y - plot.yMin) / ySpan) * (height - 30)
        };
      }

      function drawLinePen(svg, plot, pen, width, height) {
        let segment = [];
        pen.points.forEach(function (point, index) {
          const mapped = svgPoint(plot, width, height, point);
          if (index === 0) {
            segment = [mapped];
            return;
          }
          if (point.penDown) {
            segment.push(mapped);
          } else {
            if (segment.length > 1) {
              const polyline = makeSvgElement('polyline');
              polyline.setAttribute('fill', 'none');
              polyline.setAttribute('stroke', pen.color);
              polyline.setAttribute('stroke-width', '2');
              polyline.setAttribute('points', segment.map(function (item) {
                return item.x + ',' + item.y;
              }).join(' '));
              svg.appendChild(polyline);
            }
            segment = [mapped];
          }
        });
        if (segment.length > 1) {
          const polyline = makeSvgElement('polyline');
          polyline.setAttribute('fill', 'none');
          polyline.setAttribute('stroke', pen.color);
          polyline.setAttribute('stroke-width', '2');
          polyline.setAttribute('points', segment.map(function (item) {
            return item.x + ',' + item.y;
          }).join(' '));
          svg.appendChild(polyline);
        }
      }

      function drawPointPen(svg, plot, pen, width, height) {
        pen.points.forEach(function (point) {
          const mapped = svgPoint(plot, width, height, point);
          const circle = makeSvgElement('circle');
          circle.setAttribute('cx', mapped.x);
          circle.setAttribute('cy', mapped.y);
          circle.setAttribute('r', '3');
          circle.setAttribute('fill', point.color || pen.color);
          svg.appendChild(circle);
        });
      }

      function drawBarPen(svg, plot, pen, width, height) {
        pen.points.forEach(function (point) {
          const mapped = svgPoint(plot, width, height, point);
          const base = svgPoint(plot, width, height, { x: point.x, y: plot.yMin });
          const rect = makeSvgElement('rect');
          const barWidth = Math.max(3, Math.abs((width - 40) * (Number(pen.interval || 1) / Math.max(plot.xMax - plot.xMin, 1))));
          rect.setAttribute('x', mapped.x - (barWidth / 2));
          rect.setAttribute('y', Math.min(mapped.y, base.y));
          rect.setAttribute('width', barWidth);
          rect.setAttribute('height', Math.max(1, Math.abs(base.y - mapped.y)));
          rect.setAttribute('fill', point.color || pen.color);
          rect.setAttribute('opacity', '0.75');
          svg.appendChild(rect);
        });
      }

      function renderPlots() {
        const root = document.getElementById('plots');
        clearChildren(root);
        if (!state) {
          return;
        }

        if (!state.plots || state.plots.length === 0) {
          const empty = makeSectionCard('plot-card');
          empty.textContent = 'No plots in this model.';
          root.appendChild(empty);
          return;
        }

        state.plots.forEach(function (plot) {
          const card = makeSectionCard('plot-card');
          const title = document.createElement('div');
          title.className = 'plot-title';
          title.textContent = plot.name;
          card.appendChild(title);

          const meta = document.createElement('div');
          meta.className = 'plot-meta';
          meta.textContent = 'x: [' + plot.xMin + ', ' + plot.xMax + ']  y: [' + plot.yMin + ', ' + plot.yMax + ']';
          card.appendChild(meta);

          const svg = makeSvgElement('svg');
          const width = 420;
          const height = 240;
          svg.setAttribute('viewBox', '0 0 ' + width + ' ' + height);
          const background = makeSvgElement('rect');
          background.setAttribute('x', '30');
          background.setAttribute('y', '10');
          background.setAttribute('width', String(width - 40));
          background.setAttribute('height', String(height - 30));
          background.setAttribute('fill', '#ffffff');
          background.setAttribute('stroke', '#d8dee4');
          svg.appendChild(background);

          plot.pens.filter(function (pen) {
            return !pen.hidden;
          }).forEach(function (pen) {
            if (!pen.points || pen.points.length === 0) {
              return;
            }
            if (pen.modeName === 'bar') {
              drawBarPen(svg, plot, pen, width, height);
            } else if (pen.modeName === 'point') {
              drawPointPen(svg, plot, pen, width, height);
            } else {
              drawLinePen(svg, plot, pen, width, height);
            }
          });

          card.appendChild(svg);

          const legend = document.createElement('div');
          legend.className = 'plot-legend';
          plot.pens.filter(function (pen) {
            return !pen.hidden && pen.inLegend;
          }).forEach(function (pen) {
            const item = document.createElement('div');
            item.className = 'plot-legend-item';
            const swatch = document.createElement('span');
            swatch.className = 'plot-swatch';
            swatch.style.background = pen.color;
            item.appendChild(swatch);
            const label = document.createElement('span');
            label.textContent = pen.name;
            item.appendChild(label);
            legend.appendChild(item);
          });
          if (legend.childNodes.length > 0) {
            card.appendChild(legend);
          }

          root.appendChild(card);
        });
      }

      function renderTextBoxes() {
        const root = document.getElementById('text-boxes');
        clearChildren(root);
        if (!state) {
          return;
        }

        const textBoxes = state.widgets.filter(function (widget) {
          return widget.type === 'text';
        });

        if (textBoxes.length === 0) {
          const empty = makeSectionCard('note');
          empty.textContent = 'No text boxes in this model.';
          root.appendChild(empty);
          return;
        }

        textBoxes.forEach(function (widget) {
          const note = makeSectionCard('note');
          note.textContent = widget.display;
          note.style.color = widget.color || '#1f2328';
          note.style.fontSize = widget.fontSize + 'px';
          if (!widget.transparent) {
            note.style.background = '#f6f8fa';
          }
          root.appendChild(note);
        });
      }

      function renderOutputs() {
        document.getElementById('output-area').textContent =
          state ? asText(state.outputArea) : '';
        document.getElementById('command-output').textContent =
          state ? asText(state.commandOutput) : '';
      }

      function renderErrors() {
        const root = document.getElementById('errors');
        clearChildren(root);
        const messages = [];
        if (transientError) {
          messages.push(transientError);
        }
        if (state && Array.isArray(state.errors)) {
          state.errors.forEach(function (message) {
            messages.push(asText(message));
          });
        }
        if (state && Array.isArray(state.widgets)) {
          state.widgets.forEach(function (widget) {
            if (widget.error) {
              messages.push(widget.label + ': ' + widget.error);
            }
          });
        }

        if (messages.length === 0) {
          const empty = makeSectionCard('error-card');
          empty.textContent = 'No GUI-visible errors.';
          root.appendChild(empty);
          return;
        }

        messages.forEach(function (message) {
          const card = makeSectionCard('error-card');
          card.textContent = message;
          root.appendChild(card);
        });
      }

      function render() {
        setStatus();
        renderControls();
        renderMonitors();
        renderView();
        renderPlots();
        renderTextBoxes();
        renderOutputs();
        renderErrors();
      }

      document.addEventListener('DOMContentLoaded', function () {
        void refreshState();
        setInterval(function () {
          void refreshState();
        }, 1000);
      });
    </script>
  </body>
  </html>
  """
end
