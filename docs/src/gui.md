# GUI Backends

`NetLogo.jl` remains headless-first internally, but it now ships a host-side GUI layer that reuses parsed interface widgets, the rendered view, plots, monitors, and output buffers.

```@setup gui
using NetLogo
using Sockets

model = netlogo"""
globals [population]

to setup
  clear-all
  create-turtles 5
  set population count turtles
  reset-ticks
end

to go
  ask turtles [ rt 15 fd 1 ]
  tick
end
"""
```

## Inspecting GUI state without starting a server

`gui_session` wraps a runtime in a thread-safe host-side session. `gui_state` returns the serializable state consumed by the browser and notebook frontends:

```@example gui
session = gui_session(model; seed=1)
sort!(collect(keys(gui_state(session))))
```

## Browser workflow

Start from a compiled model or an existing runtime:

```@example gui
server = listen(ip"127.0.0.1", 0)
port = Int(last(getsockname(server)))
close(server)

backend = start_web_gui(model; seed=1, port=port)
url = web_gui_url(backend)
stop_web_gui!(backend)

url
```

The local page exposes:

- sliders, switches, choosers, input boxes, and buttons
- monitor refresh
- live `export-view`-backed image rendering
- plot state as a lightweight SVG frontend
- output-area and command-center buffers

## Notebook and Pluto workflow

`notebook_gui` and `pluto_gui` wrap the same local web backend in an embeddable iframe:

```julia
using NetLogo

model = load_model("path/to/model.nlogo")
gui = pluto_gui(model; seed=1, port=8081, width=1000, height=800)

gui
```

This avoids a hard dependency on Pluto while still giving notebook workflows an interactive interface.

## Direct session control

You can also manage widgets programmatically:

```julia
using NetLogo

model = load_model("path/to/model.nlogo")
session = gui_session(model; seed=1)

set_gui_widget!(session, "density", 65)
press_gui_button!(session, "setup")
state = gui_state(session)
```

`selector` can be a 1-based widget id or a widget/button name.

For code-only models without interface metadata, the GUI state still exposes the view, plots, output buffers, and any synthesized widgets that a higher-level host adds on top.
