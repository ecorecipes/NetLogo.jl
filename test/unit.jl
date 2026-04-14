using Test
using Colors: RGB
using FileIO
using HTTP
using JSON
using NetLogo

module TESTEXT
using Main.NetLogo
using Main.Test: @test, @testset
using Main.HTTP
using Main.JSON

function register_extension!(registry)
  Main.NetLogo.register_primitive!(
    registry,
    "TESTEXT:DOUBLE",
    Main.NetLogo.REPORTER,
    Main.NetLogo.reporter_syntax(right=[Main.NetLogo.NumberType], ret=Main.NetLogo.NumberType),
    (ctx, args) -> 2 * Main.NetLogo.numeric(args[1]))

  Main.NetLogo.register_primitive!(
    registry,
    "TESTEXT:STORE",
    Main.NetLogo.COMMAND,
    Main.NetLogo.command_syntax(right=[Main.NetLogo.NumberType]),
    function (ctx, args)
      ctx.runtime.world.observer.globals["EXTENSION-VALUE"] = Main.NetLogo.numeric(args[1])
      nothing
    end)
end

@testset "unit: GUI backends" begin
  model = parse_model("""
  globals [population]

  to setup
    clear-all
    create-turtles ants
    set population count turtles
    set-current-plot "Population"
    clear-plot
    plot population
    output-print title
    reset-ticks
  end

  to go
    ask turtles [ rt 15 fd 1 ]
    tick
    set population count turtles
    set-current-plot "Population"
    plot population
  end
  @#\$#@#\$#@
  GRAPHICS-WINDOW
  0
  0
  220
  220
  -1
  -1
  8.0
  1
  11
  1
  1
  1
  0
  0
  1
  1
  -5
  5
  -5
  5
  1
  1
  1
  ticks
  20.0

  SLIDER
  0
  0
  120
  33
  Ants
  ants
  0
  20
  12
  1
  1
  NIL
  HORIZONTAL

  SWITCH
  0
  40
  120
  73
  auto?
  auto?
  0
  1
  -1000

  CHOOSER
  0
  80
  120
  113
  mode
  mode
  "fast" "slow"
  0

  INPUTBOX
  0
  120
  120
  153
  title
  hello world
  1
  0
  String

  MONITOR
  0
  160
  120
  193
  Population
  count turtles
  2
  1
  11

  BUTTON
  0
  200
  120
  233
  Setup
  setup
  NIL
  1
  T
  OBSERVER
  NIL
  NIL
  NIL
  NIL
  1

  TEXTBOX
  130
  170
  220
  210
  gui ready
  12
  15
  1

  OUTPUT
  130
  0
  220
  80
  12

  PLOT
  130
  90
  330
  250
  Population
  Ticks
  Count
  0.0
  20.0
  0.0
  20.0
  true
  true
  "" ""
  PENS
  "default" 1.0 0 -16777216 true "" "plot population"
  @#\$#@#\$#@
  """)

  session = gui_session(model; seed=11)
  state = gui_state(session)
  slider = only([widget for widget in state["widgets"] if widget["type"] == "slider"])
  monitor = only([widget for widget in state["widgets"] if widget["type"] == "monitor"])
  button = only([widget for widget in state["widgets"] if widget["type"] == "button"])

  @test state["ticks"]["started"] == false
  @test slider["variable"] == "ants"
  @test slider["value"] == 12.0
  @test monitor["displayValue"] == "0.00"
  @test length(state["plots"]) == 1

  set_gui_widget!(session, "ANTS", 8)
  set_gui_widget!(session, "auto?", true)
  set_gui_widget!(session, "mode", "slow")
  set_gui_widget!(session, "title", "hello gui")
  press_gui_button!(session, "Setup")

  state = gui_state(session)
  monitor = only([widget for widget in state["widgets"] if widget["type"] == "monitor"])
  plot = only(state["plots"])
  pen = only(plot["pens"])

  @test state["ticks"]["started"] == true
  @test session.runtime.world.observer.globals["ANTS"] == 8.0
  @test session.runtime.world.observer.globals["AUTO?"] == true
  @test session.runtime.world.observer.globals["MODE"] == "slow"
  @test session.runtime.world.observer.globals["TITLE"] == "hello gui"
  @test monitor["displayValue"] == "8.00"
  @test occursin("hello gui", state["outputArea"])
  @test length(pen["points"]) >= 1

  port = 18881
  backend = start_web_gui(session; port=port)
  try
    @test web_gui_url(backend) == "http://127.0.0.1:18881/"

    html_response = HTTP.get(web_gui_url(backend))
    @test html_response.status == 200
    @test occursin("NetLogo.jl GUI", String(html_response.body))

    state_response = HTTP.get(web_gui_url(backend) * "api/state")
    @test state_response.status == 200
    payload = JSON.parse(String(state_response.body))
    @test payload["ticks"]["started"] == true

    view_response = HTTP.get(web_gui_url(backend) * "api/view.png")
    @test view_response.status == 200
    @test occursin("image/png", HTTP.header(view_response, "Content-Type"))

    slider_response = HTTP.post(
      web_gui_url(backend) * "api/widgets/$(slider["id"])",
      ["Content-Type" => "application/json"],
      JSON.json(Dict("value" => 5)))
    slider_payload = JSON.parse(String(slider_response.body))
    slider_widget = only([widget for widget in slider_payload["widgets"] if widget["id"] == slider["id"]])
    @test slider_widget["value"] == 5.0

    button_response = HTTP.post(
      web_gui_url(backend) * "api/buttons/$(button["id"])/press",
      ["Content-Type" => "application/json"],
      "{}")
    button_payload = JSON.parse(String(button_response.body))
    button_monitor = only([widget for widget in button_payload["widgets"] if widget["type"] == "monitor"])
    @test button_monitor["displayValue"] == "5.00"

    notebook = notebook_gui(backend; width=640, height=480, title="Embedded GUI")
    @test notebook isa NotebookGUI
    @test occursin("<iframe", sprint(show, MIME"text/html"(), notebook))
    @test occursin(web_gui_url(backend), sprint(show, MIME"text/html"(), notebook))
    @test pluto_gui(backend; width=320, height=240) isa NotebookGUI
  finally
    stop_web_gui!(backend)
  end
end

end

module BROKENEXT
end

@testset "unit: tokenizer" begin
  tokens = tokenize("""
  globals [steps]
  to setup
    clear-all ; comment
  end
  """)
  @test any(token -> token.lexeme == "globals", tokens)
  @test any(token -> token.kind == NetLogo.NewlineToken, tokens)

  escaped_value = "\"\n\t\r\\"
  escaped_tokens = tokenize("to-report escaped-source-demo\n  report $(repr(escaped_value))\nend\n")
  @test any(token -> token.kind == NetLogo.StringToken && token.value == escaped_value, escaped_tokens)
  power_tokens = tokenize("to-report power-demo\n  report 2 ^ 3\nend\n")
  @test any(token -> token.kind == NetLogo.OperatorToken && token.lexeme == "^", power_tokens)
end

@testset "unit: extensions support" begin
  model = parse_model("""
  extensions [testext]
  globals [extension-result extension-value]

  to setup
    testext:store 9
    set extension-result testext:double 4
  end
  """)

  @test model.extensions == ["testext"]
  runtime = create_runtime(model)
  call!(runtime, "setup")
  @test runtime.world.observer.globals["EXTENSION-VALUE"] == 9.0
  @test runtime.world.observer.globals["EXTENSION-RESULT"] == 8.0

  missing_error = try
    parse_model("""
    extensions [missingext]

    to setup
      show 1
    end
    """)
    nothing
  catch err
    err
  end
  @test missing_error isa Diagnostic
  @test missing_error.message == "Could not load extension missingext"

  broken_error = try
    parse_model("""
    extensions [brokenext]

    to setup
      show 1
    end
    """)
    nothing
  catch err
    err
  end
  @test broken_error isa Diagnostic
  @test broken_error.message == "Extension brokenext must define register_extension! or register_primitives!"
end

@testset "unit: macro DSL and model parsing" begin
  model = netlogo"""
  breed [wolves wolf]
  wolves-own [energy]
  globals [steps]

  to setup
    clear-all
    set steps 0
    create-wolves 2 [
      set energy 5
      setxy who 0
    ]
    reset-ticks
  end

  to-report pack-energy
    report [energy] of wolves
  end
  """

  @test model.globals == ["STEPS"]
  @test haskey(model.procedures, "SETUP")
  @test haskey(model.procedures, "PACK-ENERGY")
  @test length(model.breeds) == 1
  @test model.breeds[1].plural == "WOLVES"
  @test model.breeds[1].owns == ["ENERGY"]
end

@testset "unit: includes support" begin
  base_dir = mktempdir()
  main_path = joinpath(base_dir, "main.nlogo")
  helper_path = joinpath(base_dir, "helper.nls")
  nested_main_path = joinpath(base_dir, "nested-main.nlogo")
  nested_helper_path = joinpath(base_dir, "helpers.nls")
  nested_dir = joinpath(base_dir, "nested")
  nested_math_path = joinpath(nested_dir, "math.nls")
  missing_path = joinpath(base_dir, "missing.nlogo")
  bad_extension_path = joinpath(base_dir, "bad-extension.nlogo")
  circular_main_path = joinpath(base_dir, "circular-main.nlogo")
  circular_a_path = joinpath(base_dir, "a.nls")
  circular_b_path = joinpath(base_dir, "b.nls")

  mkpath(nested_dir)

  write(helper_path, """
  globals [delta]
  turtles-own [bonus]

  to-report included-value [n]
    report n + delta
  end
  """)
  write(main_path, """
  __includes ["helper.nls"]
  globals [steps]

  to setup
    set delta 3
    set steps included-value 2
  end
  """)

  model = load_model(main_path)
  @test model.includes == ["helper.nls"]
  @test model.globals == ["STEPS", "DELTA"]
  @test model.turtles_own == ["BONUS"]
  @test haskey(model.procedures, "SETUP")
  @test haskey(model.procedures, "INCLUDED-VALUE")

  runtime = create_runtime(model; seed=13)
  call!(runtime, "setup")
  @test runtime.world.observer.globals["DELTA"] == 3.0
  @test runtime.world.observer.globals["STEPS"] == 5.0

  write(nested_math_path, """
  to-report nested-bonus
    report 3
  end
  """)
  write(nested_helper_path, """
  __includes ["nested/math.nls"]

  to-report nested-value [n]
    report n + nested-bonus
  end
  """)
  write(nested_main_path, """
  __includes ["helpers.nls"]
  globals [result]

  to setup
    set result nested-value 4
  end
  """)

  nested_model = compile_model(read(nested_main_path, String); source_path=nested_main_path)
  @test haskey(nested_model.procedures, "NESTED-VALUE")
  @test haskey(nested_model.procedures, "NESTED-BONUS")
  nested_runtime = create_runtime(nested_model; seed=17)
  call!(nested_runtime, "setup")
  @test nested_runtime.world.observer.globals["RESULT"] == 7.0

  unresolved_error = try
    compile_model("""__includes ["helper.nls"]""")
    nothing
  catch err
    err
  end
  @test unresolved_error isa NetLogo.Diagnostic
  @test unresolved_error.message == "Can't resolve __includes without a source path"

  write(missing_path, """__includes ["missing.nls"]""")
  missing_error = try
    load_model(missing_path)
    nothing
  catch err
    err
  end
  @test missing_error isa NetLogo.Diagnostic
  @test missing_error.message == "Could not find missing.nls"

  write(bad_extension_path, """__includes ["helper.txt"]""")
  bad_extension_error = try
    load_model(bad_extension_path)
    nothing
  catch err
    err
  end
  @test bad_extension_error isa NetLogo.Diagnostic
  @test bad_extension_error.message == "Included files must end with .nls"

  write(circular_a_path, """__includes ["b.nls"]""")
  write(circular_b_path, """__includes ["a.nls"]""")
  write(circular_main_path, """__includes ["a.nls"]""")
  circular_error = try
    load_model(circular_main_path)
    nothing
  catch err
    err
  end
  @test circular_error isa NetLogo.Diagnostic
  @test occursin("Circular __includes detected", circular_error.message)

  rm(base_dir; recursive=true, force=true)
end

@testset "unit: control flow and collections" begin
  runtime = create_runtime(netlogo"""
  to-report countdown [n]
    let value n
    while [value > 0] [
      set value value - 1
    ]
    report value
  end

  to-report collection-demo
    report (list first ["a" "b"] item 1 [10 20 30] word "wo" "lf")
  end
  """)

  @test call!(runtime, "countdown", 3) == 0.0
  @test call!(runtime, "collection-demo") == Any["a", 20.0, "wolf"]
end

@testset "unit: link breed declarations" begin
  model = netlogo"""
  undirected-link-breed [roads road]
  roads-own [capacity]
  directed-link-breed [streets street]
  streets-own [flow]
  """

  @test length(model.link_breeds) == 2
  @test model.link_breeds[1].plural == "ROADS"
  @test model.link_breeds[1].directed == false
  @test model.link_breeds[1].owns == ["CAPACITY"]
  @test model.link_breeds[2].plural == "STREETS"
  @test model.link_breeds[2].directed == true
  @test model.link_breeds[2].owns == ["FLOW"]
end

@testset "unit: diffusion parsing" begin
  model = netlogo"""
  patches-own [heat]

  to spread
    diffuse heat 0.5
    diffuse4 heat 0.25
  end
  """

  spread = model.procedures["SPREAD"]
  @test length(spread.body.statements) == 2

  diffuse = spread.body.statements[1]::NetLogo.CommandCall
  @test diffuse.name == "DIFFUSE"
  @test diffuse.args[1] isa NetLogo.SymbolArg
  @test diffuse.args[1].name == "HEAT"
  @test diffuse.args[2] isa NetLogo.NumberLiteral
  @test diffuse.args[2].value == 0.5

  diffuse4 = spread.body.statements[2]::NetLogo.CommandCall
  @test diffuse4.name == "DIFFUSE4"
  @test diffuse4.args[1] isa NetLogo.SymbolArg
  @test diffuse4.args[1].name == "HEAT"
  @test diffuse4.args[2] isa NetLogo.NumberLiteral
  @test diffuse4.args[2].value == 0.25
end

@testset "unit: aggregation and selection reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy]

  to setup
    clear-all
    create-wolves 3 [
      set energy item who [5 1 5]
      setxy who 0
    ]
  end

  to-report sum-demo
    report sum [1 "skip" 2 3]
  end

  to-report mean-demo
    report mean [1 "skip" 2 3]
  end

  to-report median-demo
    report median [1 "sports" 2 4 5.0 "dance"]
  end

  to-report min-demo
    report min ["skip" 2 1 3]
  end

  to-report max-demo
    report max ["skip" 2 1 3]
  end

  to-report empty-sum-demo
    report sum []
  end

  to-report empty-mean-demo
    report mean []
  end

  to-report empty-median-demo
    report median ["sports" "music" "dance"]
  end

  to-report empty-min-demo
    report min ["sports" "music" "dance"]
  end

  to-report empty-max-demo
    report max ["sports" "music" "dance"]
  end

  to-report sample-demo
    report n-of 2 [10 20 30]
  end

  to-report capped-demo
    report up-to-n-of 10 [10 20 30]
  end

  to-report top-pack
    report count wolves with-max [energy]
  end

  to-report weakest-who
    report [who] of min-one-of wolves [energy]
  end

  to-report strongest-energy
    report [energy] of max-one-of wolves [energy]
  end
  """; seed=9)

  call!(runtime, "setup")

  @test call!(runtime, "sum-demo") == 6.0
  @test call!(runtime, "mean-demo") == 2.0
  @test call!(runtime, "median-demo") == 3.0
  @test call!(runtime, "min-demo") == 1.0
  @test call!(runtime, "max-demo") == 3.0
  @test call!(runtime, "empty-sum-demo") == 0.0
  mean_error = try
    call!(runtime, "empty-mean-demo")
    nothing
  catch err
    err
  end
  @test mean_error isa NetLogo.LogoRuntimeError
  @test mean_error.message == "Can't find the mean of a list with no numbers: []."

  median_error = try
    call!(runtime, "empty-median-demo")
    nothing
  catch err
    err
  end
  @test median_error isa NetLogo.LogoRuntimeError
  @test median_error.message == "Can't find the median of a list with no numbers: [sports music dance]."

  min_error = try
    call!(runtime, "empty-min-demo")
    nothing
  catch err
    err
  end
  @test min_error isa NetLogo.LogoRuntimeError
  @test min_error.message == "Can't find the minimum of a list with no numbers: [sports music dance]"

  max_error = try
    call!(runtime, "empty-max-demo")
    nothing
  catch err
    err
  end
  @test max_error isa NetLogo.LogoRuntimeError
  @test max_error.message == "Can't find the maximum of a list with no numbers: [sports music dance]"

  sample = call!(runtime, "sample-demo")
  @test length(sample) == 2
  @test issorted(sample)
  @test length(unique(sample)) == 2
  @test all(item -> item in (10.0, 20.0, 30.0), sample)

  @test call!(runtime, "capped-demo") == Any[10.0, 20.0, 30.0]
  @test call!(runtime, "top-pack") == 2.0
  @test call!(runtime, "weakest-who") == 1.0
  @test call!(runtime, "strongest-energy") == 5.0
end

@testset "unit: list sorting and membership reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]

  to setup
    clear-all
    create-wolves 3 [ setxy 0 0 ]
  end

  to-report sort-mixed-demo
    report sort [3 1 3 "foo" 2]
  end

  to-report sort-string-demo
    report sort ["c" "a" "b"]
  end

  to-report member-list-demo
    report member? [1 2] [0 [1 2] 3]
  end

  to-report member-string-demo
    report member? "rin" "string"
  end

  to-report position-list-demo
    report position [1 2] [0 [1 2] 3]
  end

  to-report position-string-demo
    report position "rin" "string"
  end

  to-report remove-list-demo
    report remove 7 [2 7 4 7 "Bob"]
  end

  to-report remove-string-demo
    report remove "a" "bananas"
  end

  to-report remove-item-list-demo
    report remove-item 1 [1 2 3]
  end

  to-report remove-item-string-demo
    report remove-item 1 "123"
  end

  to-report remove-item-error-demo
    report remove-item 3 [1 2 3]
  end

  to-report dedupe-demo
    report remove-duplicates [2 7 4 7 "Bob" 7]
  end

  to-report sorted-agent-position
    report position turtle 2 sort wolves
  end

  to-report member-agent-demo
    report member? turtle 1 wolves
  end
  """; seed=17)

  call!(runtime, "setup")

  @test call!(runtime, "sort-mixed-demo") == Any[1.0, 2.0, 3.0, 3.0]
  @test call!(runtime, "sort-string-demo") == Any["a", "b", "c"]
  @test call!(runtime, "member-list-demo") == true
  @test call!(runtime, "member-string-demo") == true
  @test call!(runtime, "position-list-demo") == 1.0
  @test call!(runtime, "position-string-demo") == 2.0
  @test call!(runtime, "remove-list-demo") == Any[2.0, 4.0, "Bob"]
  @test call!(runtime, "remove-string-demo") == "bnns"
  @test call!(runtime, "remove-item-list-demo") == Any[1.0, 3.0]
  @test call!(runtime, "remove-item-string-demo") == "13"
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "remove-item-error-demo")
  @test call!(runtime, "dedupe-demo") == Any[2.0, 7.0, 4.0, "Bob"]
  @test call!(runtime, "sorted-agent-position") == 2.0
  @test call!(runtime, "member-agent-demo") == true
end

@testset "unit: advanced list and string reporters" begin
  runtime = create_runtime(netlogo"""
  to-report reverse-list-demo
    report reverse [3 2 1]
  end

  to-report reverse-string-demo
    report reverse "string"
  end

  to-report insert-list-demo
    report insert-item 1 [8 9] 3
  end

  to-report insert-list-append-demo
    report insert-item 2 [8 9] "h"
  end

  to-report insert-string-demo
    report insert-item 1 "bit" "abb"
  end

  to-report insert-string-type-error-demo
    report insert-item 2 "me" 2
  end

  to-report collection-error-messages-demo
    let messages []
    let message ""
    carefully [ __ignore insert-item -1 "hello" "Q" ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore insert-item 3 [1 2] 4 ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore insert-item 2 "me" 2 ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore remove-item 3 "123" ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore replace-item 4 [2 7 4 5] 15 ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore item 1 [1] ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore first [] ] [ set message error-message ]
    set messages lput message messages
    carefully [ __ignore last [] ] [ set message error-message ]
    set messages lput message messages
    report messages
  end

  to-report replace-list-demo
    report replace-item 2 [2 7 4 5] 15
  end

  to-report replace-string-demo
    report replace-item 3 "string" "o"
  end

  to-report replace-item-error-demo
    report replace-item 4 [2 7 4 5] 15
  end

  to-report sublist-demo
    report sublist [99 88 77 66] 1 3
  end

  to-report sublist-float-demo
    report sublist [1 2 3] 0.5 1.5
  end

  to-report sublist-error-demo
    report sublist [1 2] 0 3
  end

  to-report substring-demo
    report substring "string" 2 5
  end
  """; seed=19)

  @test call!(runtime, "reverse-list-demo") == Any[1.0, 2.0, 3.0]
  @test call!(runtime, "reverse-string-demo") == "gnirts"
  @test call!(runtime, "insert-list-demo") == Any[8.0, 3.0, 9.0]
  @test call!(runtime, "insert-list-append-demo") == Any[8.0, 9.0, "h"]
  @test call!(runtime, "insert-string-demo") == "babbit"
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "insert-string-type-error-demo")
  @test call!(runtime, "collection-error-messages-demo") == Any[
    "-1 isn't greater than or equal to zero.",
    "Can't find element 3 of the list [1 2], which is only of length 2.",
    "INSERT-ITEM expected input to be a string but got the number 2 instead.",
    "Can't find element 3 of the string 123, which is only of length 3.",
    "Can't find element 4 of the list [2 7 4 5], which is only of length 4.",
    "Can't find element 1 of the list [1], which is only of length 1.",
    "List is empty.",
    "List is empty.",
  ]
  @test call!(runtime, "replace-list-demo") == Any[2.0, 7.0, 15.0, 5.0]
  @test call!(runtime, "replace-string-demo") == "strong"
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "replace-item-error-demo")
  @test call!(runtime, "sublist-demo") == Any[88.0, 77.0]
  @test call!(runtime, "sublist-float-demo") == Any[1.0]
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "sublist-error-demo")
  @test call!(runtime, "substring-demo") == "rin"
end

@testset "unit: further list and string compatibility" begin
  runtime = create_runtime(netlogo"""
  to-report bf-list-demo
    report bf [1 2 3 4]
  end

  to-report butfirst-string-demo
    report butfirst "string"
  end

  to-report bl-list-demo
    report bl [1 2 3 4]
  end

  to-report butlast-string-demo
    report butlast "string"
  end

  to-report bf-singleton-demo
    report bf [1]
  end

  to-report bl-singleton-demo
    report bl [1]
  end

  to-report empty-list-demo
    report empty? []
  end

  to-report empty-string-demo
    report empty? ""
  end

  to-report nonempty-list-demo
    report empty? [1]
  end

  to-report is-string-true-demo
    report is-string? "foo"
  end

  to-report is-string-false-demo
    report is-string? [1 2]
  end

  to-report bf-chain-demo
    report first butfirst [9 8 7]
  end

  to-report bl-chain-demo
    report last butlast [9 8 7]
  end

  to-report bf-empty-error-demo
    report bf []
  end

  to-report bl-empty-error-demo
    report bl ""
  end
  """; seed=61)

  @test call!(runtime, "bf-list-demo") == Any[2.0, 3.0, 4.0]
  @test call!(runtime, "butfirst-string-demo") == "tring"
  @test call!(runtime, "bl-list-demo") == Any[1.0, 2.0, 3.0]
  @test call!(runtime, "butlast-string-demo") == "strin"
  @test call!(runtime, "bf-singleton-demo") == Any[]
  @test call!(runtime, "bl-singleton-demo") == Any[]
  @test call!(runtime, "empty-list-demo") == true
  @test call!(runtime, "empty-string-demo") == true
  @test call!(runtime, "nonempty-list-demo") == false
  @test call!(runtime, "is-string-true-demo") == true
  @test call!(runtime, "is-string-false-demo") == false
  @test call!(runtime, "bf-chain-demo") == 8.0
  @test call!(runtime, "bl-chain-demo") == 8.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bf-empty-error-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bl-empty-error-demo")
end

@testset "unit: spatial and network query reporters" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [streets street]
  streets-own [weight]
  turtles-own [activation incoming]
  globals [other-end-who ahead-x ahead-y]

  to setup
    clear-all
    crt 2 [
      set activation item who [2 3]
      setxy item who [-1 1] 0
      set heading 90
    ]
    ask turtle 0 [
      create-street-to turtle 1 [ set weight 4 ]
    ]
    ask turtle 1 [
      set incoming sum [weight * [activation] of other-end] of my-in-streets
    ]
    ask one-of streets [
      ask turtle 0 [ set other-end-who [who] of other-end ]
    ]
    ask turtle 0 [
      set ahead-x [pxcor] of patch-ahead 1
      set ahead-y [pycor] of patch-ahead 1
    ]
  end

  to-report distance-demo
    report [distance turtle 1] of turtle 0
  end

  to-report distancexy-demo
    report [distancexy 1 0] of turtle 0
  end

  to-report towards-demo
    report [towards turtle 1] of turtle 0
  end

  to-report towardsxy-demo
    report [towardsxy 1 0] of turtle 0
  end

  to-report patch-heading-demo
    report [towards patch 1 1] of patch 0 0
  end

  to-report patch-ahead-x
    report ahead-x
  end

  to-report patch-ahead-y
    report ahead-y
  end

  to-report same-point-demo
    report [towardsxy -1 0] of turtle 0
  end

  to-report link-neighbor-demo
    report [link-neighbor? turtle 1] of turtle 0
  end

  to-report in-link-neighbor-demo
    report [in-link-neighbor? turtle 0] of turtle 1
  end

  to-report out-link-neighbor-demo
    report [out-link-neighbor? turtle 1] of turtle 0
  end

  to-report both-ends-count
    report count [both-ends] of one-of streets
  end

  to-report incoming-demo
    report [incoming] of turtle 1
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=31)

  call!(runtime, "setup")

  @test call!(runtime, "distance-demo") == 2.0
  @test call!(runtime, "distancexy-demo") == 2.0
  @test call!(runtime, "towards-demo") == 90.0
  @test call!(runtime, "towardsxy-demo") == 90.0
  @test call!(runtime, "patch-heading-demo") == 45.0
  @test call!(runtime, "patch-ahead-x") == 0.0
  @test call!(runtime, "patch-ahead-y") == 0.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "same-point-demo")
  @test call!(runtime, "link-neighbor-demo") == true
  @test call!(runtime, "in-link-neighbor-demo") == true
  @test call!(runtime, "out-link-neighbor-demo") == true
  @test call!(runtime, "both-ends-count") == 2.0
  @test runtime.world.observer.globals["OTHER-END-WHO"] == 1.0
  @test call!(runtime, "incoming-demo") == 8.0

  wrap_runtime = create_runtime(netlogo"""
  to-report wrapped-distance-demo
    report [distancexy 0 0] of patch 10 10
  end
  """; min_pxcor=0, max_pxcor=10, min_pycor=0, max_pycor=10, topology=Torus, seed=5)

  @test call!(wrap_runtime, "wrapped-distance-demo") ≈ sqrt(2)
end

@testset "unit: radius and cone query reporters" begin
  torus_runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  globals [wrapped-patch-x patch-target-count patch-radius nearby-pack cone-pack cone-patches]

  to setup
    clear-all
    create-wolves 4 [ setxy 0 0 ]
    ask turtle 0 [ setxy 1 0 set heading 90 ]
    ask turtle 1 [ setxy -1 0 set heading 0 ]
    ask turtle 2 [ setxy 1 1 set heading 0 ]
    ask turtle 3 [ setxy 0 0 set heading 0 ]
    ask turtle 0 [
      set wrapped-patch-x [pxcor] of patch-at 1 0
      set nearby-pack count wolves in-radius 1
      set cone-pack count wolves in-cone 1.1 90
      set cone-patches count patches in-cone 1 180
    ]
    ask patch 1 0 [
      set patch-target-count count turtles-at 1 0
    ]
    ask patch 0 0 [
      set patch-radius count patches in-radius 1
    ]
  end

  to-report negative-radius-demo
    report [count wolves in-radius -1] of turtle 0
  end

  to-report bad-angle-demo
    report [count wolves in-cone 1 361] of turtle 0
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=37)

  box_runtime = create_runtime(netlogo"""
  to-report missing-patch-demo
    report [patch-at 1 0] of patch 1 0
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=5)

  call!(torus_runtime, "setup")

  @test torus_runtime.world.observer.globals["WRAPPED-PATCH-X"] == -1.0
  @test torus_runtime.world.observer.globals["PATCH-TARGET-COUNT"] == 1.0
  @test torus_runtime.world.observer.globals["PATCH-RADIUS"] == 5.0
  @test torus_runtime.world.observer.globals["NEARBY-PACK"] == 4.0
  @test torus_runtime.world.observer.globals["CONE-PACK"] == 2.0
  @test torus_runtime.world.observer.globals["CONE-PATCHES"] == 4.0
  @test call!(box_runtime, "missing-patch-demo") === NetLogo.NOBODY
  @test_throws NetLogo.LogoRuntimeError call!(torus_runtime, "negative-radius-demo")
  @test_throws NetLogo.LogoRuntimeError call!(torus_runtime, "bad-angle-demo")
end

@testset "unit: patch-ahead variant reporters" begin
  runtime = create_runtime(netlogo"""
  to setup
    clear-all
    crt 1 [ setxy 0 0 set heading 0 ]
  end

  to-report right-ahead-demo
    let target [patch-right-and-ahead 90 1] of turtle 0
    report list [pxcor] of target [pycor] of target
  end

  to-report left-ahead-demo
    let target [patch-left-and-ahead 90 1] of turtle 0
    report list [pxcor] of target [pycor] of target
  end

  to-report turtle-heading-distance-demo
    let target [patch-at-heading-and-distance 45 1.5] of turtle 0
    report list [pxcor] of target [pycor] of target
  end

  to-report patch-heading-distance-demo
    let target [patch-at-heading-and-distance 225 1.5] of patch 1 1
    report list [pxcor] of target [pycor] of target
  end

  to-report box-edge-demo
    report [patch-at-heading-and-distance 90 2] of patch 1 1
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=12)

  call!(runtime, "setup")

  @test call!(runtime, "right-ahead-demo") == Any[1.0, 0.0]
  @test call!(runtime, "left-ahead-demo") == Any[-1.0, 0.0]
  @test call!(runtime, "turtle-heading-distance-demo") == Any[1.0, 1.0]
  @test call!(runtime, "patch-heading-distance-demo") == Any[0.0, 0.0]
  @test call!(runtime, "box-edge-demo") === NetLogo.NOBODY

  torus_runtime = create_runtime(netlogo"""
  to-report wrapped-heading-distance-demo
    let target [patch-at-heading-and-distance 90 2] of patch 1 1
    report list [pxcor] of target [pycor] of target
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=12)

  @test call!(torus_runtime, "wrapped-heading-distance-demo") == Any[0.0, 1.0]
end

@testset "unit: movement vector helpers" begin
  runtime = create_runtime(netlogo"""
  to-report dxdy-cardinals
    clear-all
    crt 4 [ set heading who * 90 ]
    report map [ t -> [ (list dx dy) ] of t ] (sort turtles)
  end

  to-report patch-ahead-dxdy
    clear-all
    random-seed 223
    crt 8 [ set heading who * 45 ]
    report not any? turtles with [ patch-ahead 3 != patch-at (dx * 3) (dy * 3) ]
  end

  to-report facexy-demo
    clear-all
    crt 1
    ask turtle 0 [ setxy 4 4 ]
    ask turtle 0 [ facexy 0 0 ]
    report [heading] of turtle 0
  end

  to-report link-heading-error
    clear-all
    cro 2
    ask turtle 0 [ create-link-with turtle 1 ]
    let message ""
    carefully [ set message link-heading-value ] [ set message error-message ]
    report message
  end

  to-report link-heading-value
    report [link-heading] of link 0 1
  end

  to-report link-heading-match
    clear-all
    cro 2
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 0 [ fd 5 ]
    let the-link link 0 1
    let end-one [end1] of the-link
    let end-two [end2] of the-link
    report [link-heading] of the-link = [towards end-two] of end-one
  end
  """; seed=13)

  @test call!(runtime, "dxdy-cardinals") == Any[
    Any[0.0, 1.0],
    Any[1.0, 0.0],
    Any[0.0, -1.0],
    Any[-1.0, 0.0],
  ]
  @test call!(runtime, "patch-ahead-dxdy") == true
  @test call!(runtime, "facexy-demo") == 225.0
  @test call!(runtime, "link-heading-error") == "there is no heading of a link whose endpoints are in the same position"
  @test call!(runtime, "link-heading-match") == true
end

@testset "unit: layout-circle command" begin
  runtime = create_runtime(netlogo"""
  to-report sorted-layout-is-sorted
    clear-all
    crt 100
    layout-circle (sort turtles) max-pxcor
    let ordered (sort-by [[t1 t2] -> [heading] of t1 < [heading] of t2] turtles)
    let sorted (sort turtles)
    report ordered = sorted
  end

  to-report random-layout-is-sorted
    clear-all
    random-seed 8123
    crt 100
    layout-circle turtles max-pxcor
    let ordered (sort-by [[t1 t2] -> [heading] of t1 < [heading] of t2] turtles)
    let sorted (sort turtles)
    report ordered = sorted
  end

  to-report sorted-headings-demo
    clear-all
    random-seed 8123
    crt 7
    layout-circle (sort turtles) max-pxcor
    report map [ t -> [heading] of t ] sort turtles
  end

  to-report sorted-endpoints-demo
    clear-all
    crt 10
    layout-circle (sort turtles) 5
    let p0 (list [precision xcor 12] of turtle 0 [precision ycor 12] of turtle 0)
    let p5 (list [precision xcor 12] of turtle 5 [precision ycor 12] of turtle 5)
    report (list p0 p5)
  end

  to-report centered-after-back-demo
    clear-all
    crt 10
    layout-circle turtles 5
    ask turtles [ bk 5 ]
    report (list remove-duplicates [precision xcor 14] of turtles remove-duplicates [precision ycor 14] of turtles)
  end

  to-report zero-radius-demo
    clear-all
    crt 10
    layout-circle turtles 0
    report (list remove-duplicates [precision xcor 14] of turtles remove-duplicates [precision ycor 14] of turtles)
  end
  """; min_pxcor=-10, max_pxcor=10, min_pycor=-10, max_pycor=10, topology=Torus, seed=8123)

  @test call!(runtime, "sorted-layout-is-sorted") == true
  @test call!(runtime, "random-layout-is-sorted") == false
  @test call!(runtime, "sorted-headings-demo") == Any[0.0, 360.0 / 7.0, 2.0 * 360.0 / 7.0, 3.0 * 360.0 / 7.0, 4.0 * 360.0 / 7.0, 5.0 * 360.0 / 7.0, 6.0 * 360.0 / 7.0]
  @test call!(runtime, "sorted-endpoints-demo") == Any[Any[0.0, 5.0], Any[0.0, -5.0]]
  @test call!(runtime, "centered-after-back-demo") == Any[Any[0.0], Any[0.0]]
  @test call!(runtime, "zero-radius-demo") == Any[Any[0.0], Any[0.0]]
end

@testset "unit: layout-radial command" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]

  to-report star-distance-demo
    clear-all
    resize-world (-16) 16 (-16) 16
    crt 10
    ask turtle 0 [ create-links-with other turtles ]
    layout-radial turtles links (turtle 0)
    report sum [distance turtle 0] of turtles
  end

  to-report layered-rings-demo
    clear-all
    resize-world (-16) 16 (-16) 16
    crt 10
    ask turtle 0 [ create-links-with other turtles ]
    ask turtles with [who > 0] [
      hatch 3 [
        create-link-with myself
      ]
    ]
    layout-radial turtles links (turtle 0)
    let outer turtles with [count link-neighbors = 1]
    let inner turtles with [count link-neighbors = 4]
    report (list (sum [distancexy 0 0] of outer) (sum [distancexy 0 0] of inner))
  end

  to-report filtered-links-demo
    clear-all
    resize-world (-5) 5 (-5) 5
    crt 3
    ask turtle 0 [
      create-undirected-edge-with turtle 1
      create-directed-edge-to turtle 2
    ]
    ask turtle 1 [ create-undirected-edge-with turtle 2 ]
    layout-radial turtles undirected-edges (turtle 0)
    let breed-p0 (list [precision xcor 12] of turtle 0 [precision ycor 12] of turtle 0)
    let breed-p1 (list [precision xcor 12] of turtle 1 [precision ycor 12] of turtle 1)
    let breed-p2 (list [precision xcor 12] of turtle 2 [precision ycor 12] of turtle 2)
    let breed-layout (list breed-p0 breed-p1 breed-p2)
    layout-radial turtles (links with [breed = undirected-edges]) (turtle 0)
    let filtered-p0 (list [precision xcor 12] of turtle 0 [precision ycor 12] of turtle 0)
    let filtered-p1 (list [precision xcor 12] of turtle 1 [precision ycor 12] of turtle 1)
    let filtered-p2 (list [precision xcor 12] of turtle 2 [precision ycor 12] of turtle 2)
    let filtered-layout (list filtered-p0 filtered-p1 filtered-p2)
    report (list breed-layout filtered-layout)
  end

  to-report excluded-turtle-stays-put
    clear-all
    resize-world (-5) 5 (-5) 5
    crt 3
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    ask turtle 2 [ setxy 5 5 ]
    let subset (turtle-set turtle 0 turtle 1)
    layout-radial subset links (turtle 0)
    report (list [precision xcor 12] of turtle 2 [precision ycor 12] of turtle 2)
  end
  """; min_pxcor=-5, max_pxcor=5, min_pycor=-5, max_pycor=5, topology=Torus, seed=100)

  @test call!(runtime, "star-distance-demo") ≈ 120.0

  ring_sums = call!(runtime, "layered-rings-demo")
  @test ring_sums[1] ≈ 392.72727272727275
  @test ring_sums[2] ≈ 65.45454545454545

  filtered_layouts = call!(runtime, "filtered-links-demo")
  expected_layout = Any[Any[0.0, 0.0], Any[0.0, -2.272727272727], Any[0.0, -4.545454545455]]
  @test filtered_layouts[1] == expected_layout
  @test filtered_layouts[2] == expected_layout

  @test call!(runtime, "excluded-turtle-stays-put") == Any[5.0, 5.0]
end

@testset "unit: layout-tutte command" begin
  runtime = create_runtime(netlogo"""
  to-report anchor-distance-demo
    clear-all
    resize-world (-16) 16 (-16) 16
    crt 4
    ask turtles [ create-links-with other turtles ]
    let interior turtles with [who >= 3]
    layout-tutte interior links 5
    let anchors turtles with [who < 3]
    report sort [precision distance turtle 3 11] of anchors
  end
  """; min_pxcor=-5, max_pxcor=5, min_pycor=-5, max_pycor=5, topology=Torus, seed=100)

  @test call!(runtime, "anchor-distance-demo") == Any[5.0, 5.0, 5.0]
end

@testset "unit: layout-spring command" begin
  runtime = create_runtime(netlogo"""
  to-report filtered-turtles-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    crt 3
    ask turtle 0 [ setxy 0 0 set color red ]
    ask turtle 1 [ setxy 2 0 set color red ]
    ask turtle 2 [ setxy 4 0 set color blue ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    layout-spring turtles with [ color = red ] links 0.1 1 0
    let p0 (list [precision xcor 6] of turtle 0 [precision ycor 6] of turtle 0)
    let p1 (list [precision xcor 6] of turtle 1 [precision ycor 6] of turtle 1)
    let p2 (list [precision xcor 6] of turtle 2 [precision ycor 6] of turtle 2)
    report (list p0 p1 p2)
  end

  to-report filtered-links-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    crt 3
    ask turtle 0 [ setxy 0 0 ]
    ask turtle 1 [ setxy 2 0 ]
    ask turtle 2 [ setxy 4 0 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    let chosen ([my-links] of turtle 0)
    layout-spring turtles chosen 0.1 1 0
    let p0 (list [precision xcor 6] of turtle 0 [precision ycor 6] of turtle 0)
    let p1 (list [precision xcor 6] of turtle 1 [precision ycor 6] of turtle 1)
    let p2 (list [precision xcor 6] of turtle 2 [precision ycor 6] of turtle 2)
    report (list p0 p1 p2)
  end

  to-report motion-limit-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    crt 2
    ask turtle 0 [ setxy (-10) 0 ]
    ask turtle 1 [ setxy 10 0 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    layout-spring turtles links 10 0 0
    let p0 (list [precision xcor 6] of turtle 0 [precision ycor 6] of turtle 0)
    let p1 (list [precision xcor 6] of turtle 1 [precision ycor 6] of turtle 1)
    report (list p0 p1)
  end

  to-report no-turtles-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    random-seed 100
    crt 5 [ setxy random-xcor random-ycor ]
    ask turtles [ create-links-with other turtles ]
    let before map [ t -> [ list [precision xcor 12] of t [precision ycor 12] of t ] ] sort turtles
    layout-spring no-turtles links 0.2 5 0.2
    let after map [ t -> [ list [precision xcor 12] of t [precision ycor 12] of t ] ] sort turtles
    report before = after
  end
  """; min_pxcor=-10, max_pxcor=10, min_pycor=-10, max_pycor=10, topology=Torus, seed=100)

  @test call!(runtime, "filtered-turtles-demo") == Any[Any[0.066667, 0.0], Any[2.033333, 0.0], Any[4.0, 0.0]]
  @test call!(runtime, "filtered-links-demo") == Any[Any[0.1, 0.0], Any[1.9, 0.0], Any[4.0, 0.0]]
  @test call!(runtime, "motion-limit-demo") == Any[Any[-9.16, 0.0], Any[9.16, 0.0]]
  @test call!(runtime, "no-turtles-demo") == true
end

@testset "unit: file helper primitives" begin
  base_dir = mktempdir()
  target_dir = joinpath(base_dir, "netlogo", "nested")
  runtime = create_runtime(compile_model("""
  globals [mkdir-path]

  to setup
    set mkdir-path $(repr(target_dir))
    __mkdir mkdir-path
    __mkdir mkdir-path
  end

  to-report nanotime-demo
    report is-number? __nano-time
  end
  """); seed=1)

  try
    call!(runtime, "setup")
    @test isdir(target_dir)
    @test call!(runtime, "nanotime-demo") == true
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: file io primitives" begin
  base_dir = mktempdir()
  primary_path = joinpath(base_dir, "file-io.txt")
  secondary_path = joinpath(base_dir, "file-io-2.txt")
  whitespace_path = joinpath(base_dir, "file-whitespace.txt")
  bad_token_path = joinpath(base_dir, "file-bad-token.txt")
  big_number_path = joinpath(base_dir, "file-big-number.txt")
  utf8_path = joinpath(base_dir, "file-utf8.txt")
  utf8_text = "\u3053\u3093\u306b\u3061\u306f\U0001f422"
  big_number_text = "598745879457894578945789457894578945789"
  runtime = create_runtime(compile_model("""
  globals [primary-path secondary-path whitespace-path bad-token-path big-number-path utf8-path]

  to setup-paths
    set primary-path $(repr(primary_path))
    set secondary-path $(repr(secondary_path))
    set whitespace-path $(repr(whitespace_path))
    set bad-token-path $(repr(bad_token_path))
    set big-number-path $(repr(big_number_path))
    set utf8-path $(repr(utf8_path))
  end

  to-report no-open-read-message
    let result ""
    carefully [ set result file-read ] [ set result error-message ]
    report result
  end

  to-report no-open-write-message
    let result ""
    carefully [ file-write 0 set result "no-error" ] [ set result error-message ]
    report result
  end

  to-report line-reading-demo
    if file-exists? primary-path [ file-delete primary-path ]
    file-open primary-path
    file-print "first line"
    file-show "2nd line"
    file-type "3rd line"
    file-flush
    let mode-error ""
    carefully [ __ignore file-read ] [ set mode-error error-message ]
    let delete-error ""
    carefully [ file-delete primary-path ] [ set delete-error error-message ]
    file-close
    file-open primary-path
    let result (list file-read-line file-read-line file-read-characters 4 file-read-line file-at-end? mode-error delete-error)
    file-close
    report result
  end

  to-report write-read-demo
    if file-exists? primary-path [ file-delete primary-path ]
    file-open primary-path
    file-write 11
    file-write "Once upon a time"
    file-write (list 1 (-2) 5 "this is a string" true)
    file-write "true 5"
    file-close
    file-open primary-path
    let values (list file-read file-read file-read file-read file-at-end?)
    file-close
    report values
  end

  to-report whitespace-at-end-demo
    if file-exists? whitespace-path [ file-delete whitespace-path ]
    file-open whitespace-path
    file-print "1 2\\t3 "
    file-print "4 5 6  \\t   "
    file-close
    file-open whitespace-path
    let values []
    while [not file-at-end?] [ set values lput file-read values ]
    let eof? file-at-end?
    file-close
    report lput eof? values
  end

  to-report bad-token-message-demo
    if file-exists? bad-token-path [ file-delete bad-token-path ]
    file-open bad-token-path
    file-print "1 A 2"
    file-close
    file-open bad-token-path
    let err ""
    carefully [
      __ignore file-read
      __ignore file-read
    ] [ set err error-message ]
    file-close
    report err
  end

  to-report big-number-message-demo
    if file-exists? big-number-path [ file-delete big-number-path ]
    file-open big-number-path
    file-print $(repr(big_number_text))
    file-close
    file-open big-number-path
    let err ""
    carefully [ __ignore file-read ] [ set err error-message ]
    file-close
    report err
  end

  to-report utf8-demo
    if file-exists? utf8-path [ file-delete utf8-path ]
    file-open utf8-path
    file-write $(repr(utf8_text))
    file-close
    file-open utf8-path
    let value file-read
    file-close
    report value
  end

  to-report multi-file-demo
    if file-exists? primary-path [ file-delete primary-path ]
    if file-exists? secondary-path [ file-delete secondary-path ]
    file-open primary-path
    file-type "alpha"
    file-open secondary-path
    file-type "beta"
    file-open primary-path
    file-print " gamma"
    file-close-all
    file-open primary-path
    let first file-read-line
    file-close
    file-open secondary-path
    let second file-read-line
    file-close
    report (list first second)
  end
  """); seed=1)

  try
    call!(runtime, "setup-paths")
    @test call!(runtime, "no-open-read-message") == "No file has been opened."
    @test call!(runtime, "no-open-write-message") == "No file has been opened."
    @test call!(runtime, "line-reading-demo") == Any[
      "first line",
      "observer: \"2nd line\"",
      "3rd ",
      "line",
      true,
      "You can only use WRITING primitives with this file",
      "You need to close the file before deletion",
    ]
    @test call!(runtime, "write-read-demo") == Any[
      11.0,
      "Once upon a time",
      Any[1.0, -2.0, 5.0, "this is a string", true],
      "true 5",
      true,
    ]
    @test call!(runtime, "whitespace-at-end-demo") == Any[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, true]
    @test call!(runtime, "bad-token-message-demo") == "Expected a literal value. (line number 1, character 3)"
    @test call!(runtime, "big-number-message-demo") ==
      "$(big_number_text) is too large to be represented exactly as an integer in NetLogo (line number 1, character 1)"
    @test call!(runtime, "utf8-demo") == utf8_text
    @test call!(runtime, "multi-file-demo") == Any["alpha gamma", "beta"]
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: output, wait, and modes helpers" begin
  runtime = create_runtime(netlogo"""
  globals [modes-basic modes-complex modes-empty modes-mixed wait-value]

  to setup
    clear-all
    set modes-basic modes [1 2 3 3 1 2 3]
    set modes-complex modes [0 0 [1 2 3 4 5] [1 2 [3 4 5]] [1 [2 3] 4 5] [1 2 [3 4 5]] 1 1 2]
    set modes-empty modes []
    crt 2
    set modes-mixed (list length modes (list turtle 0 turtle 1 turtle 0) [who] of first modes (list turtle 0 turtle 1 turtle 0))
    ask turtles [ die ]
    let post-modes modes (list 5 5 5 5 turtle 0 turtle 1 turtle 2 nobody)
    set modes-mixed (list item 0 modes-mixed item 1 modes-mixed post-modes)
    reset-timer
    wait 0.05
    set wait-value timer
  end

  to output-demo
    type "alpha"
    type 7
    print (list 1 2)
    show "beta"
  end

  to write-demo
    write "gamma"
  end

  to turtle-output-demo
    clear-all
    crt 1 [ show "hi" ]
  end
  """; seed=271)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["MODES-BASIC"] == Any[3.0]
  @test runtime.world.observer.globals["MODES-COMPLEX"] == Any[
    0.0,
    Any[1.0, 2.0, Any[3.0, 4.0, 5.0]],
    1.0,
  ]
  @test runtime.world.observer.globals["MODES-EMPTY"] == Any[]
  @test runtime.world.observer.globals["MODES-MIXED"] == Any[1.0, 0.0, Any[5.0, NetLogo.NOBODY]]
  @test runtime.world.observer.globals["WAIT-VALUE"] >= 0.04

  call!(runtime, "output-demo")
  call!(runtime, "write-demo")
  call!(runtime, "turtle-output-demo")
  @test runtime.command_output == "alpha7[1 2]\nobserver: \"beta\"\n \"gamma\"turtle 0: \"hi\"\n"
end

@testset "unit: output area commands" begin
  base_dir = mktempdir()
  output_path = joinpath(base_dir, "output.txt")
  world_path = joinpath(base_dir, "world.bin")
  runtime = create_runtime(netlogo"""
  to output-area-demo
    output-type "alpha"
    output-type 7
    output-print (list 1 2)
    output-show "beta"
    output-write "gamma"
  end

  to turtle-output-area-demo
    clear-all
    crt 1 [ output-show "hi" ]
  end

  to clear-output-demo
    clear-output
  end

  to clear-all-demo
    clear-all
  end

  to export-output-demo [file]
    clear-output
    output-type "alpha"
    output-write "beta"
    output-print "gamma"
    output-show "delta"
    export-output file
  end

  to-report empty-export-output-error
    let result ""
    carefully [ export-output "" set result "no-error" ] [ set result error-message ]
    report result
  end

  to persist-output-demo [file]
    clear-all
    output-print "This is a test of output areas."
    export-world file
    clear-all
    import-world file
  end
  """; seed=273)

  try
    call!(runtime, "output-area-demo")
    @test runtime.output_area == "alpha7[1 2]\nobserver: \"beta\"\n \"gamma\""

    call!(runtime, "clear-output-demo")
    @test runtime.output_area == ""

    call!(runtime, "output-area-demo")
    call!(runtime, "clear-all-demo")
    @test runtime.output_area == ""

    call!(runtime, "turtle-output-area-demo")
    @test runtime.output_area == "turtle 0: \"hi\"\n"

    call!(runtime, "export-output-demo", output_path)
    @test read(output_path, String) == "alpha \"beta\"gamma\nobserver: \"delta\"\n"
    @test call!(runtime, "empty-export-output-error") == "Can't export to empty pathname."

    call!(runtime, "persist-output-demo", world_path)
    @test runtime.output_area == "This is a test of output areas.\n"
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: headless user primitives" begin
  runtime = create_runtime(netlogo"""
  globals [yesno-error oneof-error input-error file-value newfile-value dir-value]

  to setup
    clear-all
    set yesno-error ""
    set oneof-error ""
    set input-error ""
    carefully [ __ignore user-yes-or-no? "blarg" ] [ set yesno-error error-message ]
    carefully [ __ignore user-one-of "blarg" [1 2 3] ] [ set oneof-error error-message ]
    carefully [ __ignore user-input "blarg" ] [ set input-error error-message ]
    set file-value user-file
    set newfile-value user-new-file
    set dir-value user-directory
  end
  """; seed=277)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["YESNO-ERROR"] == "model halted by user"
  @test runtime.world.observer.globals["ONEOF-ERROR"] == "model halted by user"
  @test runtime.world.observer.globals["INPUT-ERROR"] == "model halted by user"
  @test runtime.world.observer.globals["FILE-VALUE"] == false
  @test runtime.world.observer.globals["NEWFILE-VALUE"] == false
  @test runtime.world.observer.globals["DIR-VALUE"] == false
end

@testset "unit: range reporter" begin
  runtime = create_runtime(netlogo"""
  to-report range-basic
    report (list (range 5) (range 2 5) (range 2 5 0.5) (range 5 0 -1) (range 0 5 -1) (range 0.5 2.51 0.5))
  end

  to-report range-map-empty
    report map range
  end

  to-report range-map-one
    report map range [10]
  end

  to-report range-map-two
    report map range [10] [20]
  end

  to-report range-map-three
    report map range [10] [40] [2]
  end

  to-report range-zero-step
    report range 0 5 0
  end

  to-report range-too-many
    report map range [10] [40] [2] [0]
  end
  """; seed=281)

  @test call!(runtime, "range-basic") == Any[
    Any[0.0, 1.0, 2.0, 3.0, 4.0],
    Any[2.0, 3.0, 4.0],
    Any[2.0, 2.5, 3.0, 3.5, 4.0, 4.5],
    Any[5.0, 4.0, 3.0, 2.0, 1.0],
    Any[],
    Any[0.5, 1.0, 1.5, 2.0, 2.5],
  ]
  @test call!(runtime, "range-map-empty") == Any[]
  @test call!(runtime, "range-map-one") == Any[Any[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]]
  @test call!(runtime, "range-map-two") == Any[Any[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]]
  @test call!(runtime, "range-map-three") == Any[Any[10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0, 32.0, 34.0, 36.0, 38.0]]

  zero_step_error = try
    call!(runtime, "range-zero-step")
    nothing
  catch err
    err
  end
  @test zero_step_error isa NetLogo.LogoRuntimeError
  @test zero_step_error.message == "The step-size for range must be non-zero."

  too_many_error = try
    call!(runtime, "range-too-many")
    nothing
  catch err
    err
  end
  @test too_many_error isa NetLogo.LogoRuntimeError
  @test too_many_error.message == "range expects at most three arguments"
end

@testset "unit: read-from-string reporter" begin
  escaped_literal = "\"\\n\\t\\\\\""
  runtime = create_runtime(netlogo"""
  to-report read-demo [text]
    report read-from-string text
  end

  to-report read-error-demo [text]
    let result ""
    carefully [ __ignore read-from-string text ] [ set result error-message ]
    report result
  end
  """; seed=1)

  @test call!(runtime, "read-demo", "5") == 5.0
  @test call!(runtime, "read-demo", "3.2") == 3.2
  @test call!(runtime, "read-demo", "\"foo\"") == "foo"
  @test call!(runtime, "read-demo", "[]") == Any[]
  @test call!(runtime, "read-demo", "[1 3.0]") == Any[1.0, 3.0]
  @test call!(runtime, "read-demo", "[1 \"foo\" 3.0]") == Any[1.0, "foo", 3.0]
  @test call!(runtime, "read-demo", "nobody") === NetLogo.NOBODY
  @test call!(runtime, "read-demo", "e") == MathConstants.e
  @test call!(runtime, "read-demo", "pi") == π
  @test call!(runtime, "read-demo", escaped_literal) == "\n\t\\"
  @test call!(runtime, "read-demo", "(5)") == 5.0
  @test call!(runtime, "read-demo", "98748937489374893743789473894.") == 9.874893748937489e28
  @test length(call!(runtime, "read-demo", "[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]")) == 1
  @test call!(runtime, "read-demo", "3") + call!(runtime, "read-demo", "5") == 8.0
  @test length(call!(runtime, "read-demo", "[1 2 3]")) == 3
  @test call!(runtime, "read-error-demo", "") == "Expected a literal value."
  @test call!(runtime, "read-error-demo", "a") == "Expected a literal value."
  @test call!(runtime, "read-error-demo", "1 2") == "Extra characters after literal."
  @test call!(runtime, "read-error-demo", "[1 2 3") == "No closing bracket for this open bracket."
  @test call!(runtime, "read-error-demo", "[[[[[]]]]]]") == "Extra characters after literal."
  @test call!(runtime, "read-error-demo", "(5") == "Expected a closing parenthesis."
end

@testset "unit: perspective commands" begin
  runtime = create_runtime(netlogo"""
  to setup
    clear-all
    crt 5
  end

  to-report subject-who
    if subject = nobody [ report -1 ]
    report [who] of subject
  end

  to-report subject-history-demo
    reset-perspective
    let values (list subject-who)
    follow turtle 0
    set values lput subject-who values
    follow turtle 3
    set values lput subject-who values
    ask turtle 3 [ die ]
    set values lput subject-who values
    watch turtle 2
    set values lput subject-who values
    ask turtle 2 [ die ]
    set values lput subject-who values
    ride turtle 4
    set values lput subject-who values
    ask turtle 4 [ die ]
    set values lput subject-who values
    ride turtle 0
    set values lput subject-who values
    reset-perspective
    set values lput subject-who values
    report values
  end

  to-report me-history-demo
    reset-perspective
    ask turtle 0 [ ride-me ]
    let values (list subject-who)
    ask turtle 1 [ follow-me ]
    set values lput subject-who values
    ask turtle 2 [ watch-me ]
    set values lput subject-who values
    report values
  end

  to-report follow-link-error-demo
    clear-all
    crt 2
    ask turtle 0 [ create-link-with turtle 1 ]
    let result ""
    carefully [ follow one-of links ] [ set result error-message ]
    report result
  end
  """; seed=1)

  call!(runtime, "setup")
  @test call!(runtime, "subject-history-demo") == Any[-1.0, 0.0, 3.0, -1.0, 2.0, -1.0, 4.0, -1.0, 0.0, -1.0]
  call!(runtime, "setup")
  @test call!(runtime, "me-history-demo") == Any[0.0, 1.0, 2.0]
  @test call!(runtime, "follow-link-error-demo") ==
    "FOLLOW expected input to be a turtle but got the link (link 0 1) instead."
end

@testset "unit: special agentset dynamics" begin
  runtime = create_runtime(netlogo"""
  globals [glob1 glob2 glob3]
  breed [frogs frog]
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]

  to-report turtles-dynamic-demo
    clear-all
    crt 10
    set glob1 turtles
    set glob2 turtles with [true]
    crt 10
    report (list count glob1 count glob2)
  end

  to-report breeds-dynamic-demo
    clear-all
    create-frogs 10
    set glob1 frogs
    set glob2 frogs with [true]
    set glob3 turtles
    create-frogs 10
    crt 10
    report (list count glob1 count glob2 count glob3)
  end

  to-report links-dynamic-demo
    clear-all
    create-frogs 10
    ask turtle 0 [ create-directed-edge-to turtle 1 ]
    ask turtle 1 [ create-undirected-edge-with turtle 2 ]
    set glob1 links
    set glob2 links with [true]
    set glob3 directed-edges
    ask turtle 2 [ create-undirected-edge-with turtle 3 ]
    ask turtle 3 [ create-directed-edge-to turtle 4 ]
    report (list count glob1 count glob2 count glob3)
  end

  to-report patches-dynamic-demo
    clear-all
    set glob1 patches
    resize-world (-1) 1 (-1) 1
    report count glob1
  end
  """; seed=1)

  @test call!(runtime, "turtles-dynamic-demo") == Any[20.0, 10.0]
  @test call!(runtime, "breeds-dynamic-demo") == Any[20.0, 10.0, 30.0]
  @test call!(runtime, "links-dynamic-demo") == Any[4.0, 2.0, 2.0]
  @test call!(runtime, "patches-dynamic-demo") == 9.0
end

@testset "unit: world import and export" begin
  base_dir = mktempdir()
  world_path = joinpath(base_dir, "world.bin")
  runtime = create_runtime(netlogo"""
  globals [glob1 glob2 glob3]
  breed [frogs frog]
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]

  to export-round-trip [file]
    export-world file
    clear-all
    import-world file
  end

  to-report turtles-export-demo [file]
    clear-all
    crt 10
    set glob1 turtles
    set glob2 turtles with [true]
    export-round-trip file
    crt 10
    report (list count glob1 count glob2)
  end

  to-report breeds-export-demo [file]
    clear-all
    create-frogs 10
    set glob1 frogs
    set glob2 frogs with [true]
    set glob3 turtles
    export-round-trip file
    create-frogs 10
    crt 10
    report (list count glob1 count glob2 count glob3)
  end

  to-report links-export-demo [file]
    clear-all
    create-frogs 10
    ask turtle 0 [ create-directed-edge-to turtle 1 ]
    ask turtle 1 [ create-undirected-edge-with turtle 2 ]
    set glob1 links
    set glob2 links with [true]
    set glob3 directed-edges
    export-round-trip file
    ask turtle 2 [ create-undirected-edge-with turtle 3 ]
    ask turtle 3 [ create-directed-edge-to turtle 4 ]
    report (list count glob1 count glob2 count glob3)
  end

  to-report breed-order-demo [file]
    clear-all
    random-seed 6924
    cro 10
    ask turtles [ set breed frogs ]
    ask turtle 0 [ die ]
    export-world file
    let before [who] of one-of frogs
    import-world file
    report (list before [who] of one-of frogs)
  end

  to-report link-order-demo [file]
    clear-all
    random-seed 6924
    cro 10
    ask turtles [ create-directed-edges-to turtles with [ who > [who] of myself ] ]
    ask directed-edge 0 1 [ die ]
    export-world file
    let picked [list [who] of end1 [who] of end2] of one-of links
    import-world file
    report (picked = [list [who] of end1 [who] of end2] of one-of links)
  end

  to-report utf8-export-demo [file]
    clear-all
    set glob1 "AêñüC"
    export-round-trip file
    report glob1
  end

  to-report rgb-export-demo [file]
    clear-all
    crt 2 [ create-links-with other turtles [ set color [255 0 0] set label-color [255 0 0] ] ]
    ask turtles [ set color [0 255 0] set label-color [0 255 0] ]
    ask patch 0 0 [ set pcolor [0 0 255] set plabel-color [0 0 255] ]
    export-round-trip file
    report (list
      [color] of link 0 1
      [label-color] of link 0 1
      [color] of turtle 0
      [label-color] of turtle 0
      [pcolor] of patch 0 0
      [plabel-color] of patch 0 0
      [pcolor] of patch 0 1)
  end
  """; seed=1)

  try
    @test call!(runtime, "turtles-export-demo", world_path) == Any[20.0, 10.0]
    @test call!(runtime, "breeds-export-demo", world_path) == Any[20.0, 10.0, 30.0]
    @test call!(runtime, "links-export-demo", world_path) == Any[4.0, 2.0, 2.0]
    let result = call!(runtime, "breed-order-demo", world_path)
      @test result[1] == result[2]
    end
    @test call!(runtime, "link-order-demo", world_path) == true
    @test call!(runtime, "utf8-export-demo", world_path) == "AêñüC"
    @test call!(runtime, "rgb-export-demo", world_path) == Any[
      Any[255.0, 0.0, 0.0],
      Any[255.0, 0.0, 0.0],
      Any[0.0, 255.0, 0.0],
      Any[0.0, 255.0, 0.0],
      Any[0.0, 0.0, 255.0],
      Any[0.0, 0.0, 255.0],
      0.0,
    ]
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: export-world plot and RNG persistence" begin
  base_dir = mktempdir()
  world_path = joinpath(base_dir, "world.bin")
  runtime = create_runtime(netlogo"""
  globals [ glob1 ]

  to setup-and-plot
    clear-all
    set-current-plot "plot1"
    set-current-plot-pen "pen1"
    plot 10
    plot 20
    plot 30
    set glob1 random 1000
  end

  to export-demo [file]
    setup-and-plot
    output-print "test output"
    export-world file
  end

  to-report import-demo [file]
    clear-all
    import-world file
    set-current-plot "plot1"
    let pen-ok plot-pen-exists? "pen1"
    report (list glob1 pen-ok)
  end

  to-report rng-after-import [file]
    clear-all
    import-world file
    report random 1000
  end
  """; seed=42)

  try
    call!(runtime, "export-demo", world_path)
    saved_glob1 = runtime.world.observer.globals["GLOB1"]

    result = call!(runtime, "import-demo", world_path)
    @test result[1] == saved_glob1
    @test result[2] == true

    # Verify output area was restored
    @test runtime.output_area == "test output\n"

    # Verify plot state was restored
    @test length(runtime.plot_manager.plots) > 0
    plot1 = runtime.plot_manager.plots[1]
    @test plot1.name == "plot1"
    @test length(plot1.pens) > 0
    @test length(plot1.pens[1].points) == 3

    # Verify RNG state is restored deterministically
    r1 = call!(runtime, "rng-after-import", world_path)
    r2 = call!(runtime, "rng-after-import", world_path)
    @test r1 == r2
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: type-check and system primitives" begin
  runtime = create_runtime(netlogo"""
  globals [ glob1 ]
  breed [ frogs frog ]
  breed [ mice mouse ]

  to-report test-is-observer
    report is-observer? self
  end

  to-report test-is-observer-turtle
    let result false
    crt 1 [ set result is-observer? self ]
    report result
  end

  to-report test-date-and-time
    report date-and-time
  end
  """; seed=1)

  @test call!(runtime, "test-is-observer") == true
  @test call!(runtime, "test-is-observer-turtle") == false

  date_str = call!(runtime, "test-date-and-time")
  @test date_str isa String
  @test occursin(r"\d{2}:\d{2}:\d{2}\.\d{3} [AP]M \d{2}-\w{3}-\d{4}", date_str)
end

@testset "unit: custom turtle shape loading" begin
  shapes_path = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "shared", "resources", "main", "system", "defaultTurtleShapes.txt")

  # Test parsing the upstream default shapes file
  shapes = NetLogo.parse_turtle_shapes_text(read(shapes_path, String))
  @test length(shapes) >= 37
  @test haskey(shapes, "default")
  @test haskey(shapes, "turtle")
  @test haskey(shapes, "butterfly")
  @test shapes["default"].rotatable == true
  @test shapes["circle"].rotatable == false
  @test length(shapes["default"].elements) == 1
  @test shapes["default"].elements[1] isa NetLogo.TurtlePolygonElement

  # Test that custom shapes are used in rendering
  runtime = create_runtime(compile_model("""
  to setup
    clear-all
    crt 1 [ set shape "diamondcustom" set size 3 setxy 0 0 set color red ]
  end
  """); seed=1, patch_size=13, min_pxcor=-2, max_pxcor=2, min_pycor=-2, max_pycor=2)

  # Register a custom diamond shape
  NetLogo.load_turtle_shapes!(runtime, """
diamondcustom
true
0
Polygon -7500403 true true 150 0 0 150 150 300 300 150
""")

  call!(runtime, "setup")

  # The custom shape should render as geometry (not just a dot)
  @test haskey(runtime.custom_turtle_shapes, "diamondcustom")
  spec = runtime.custom_turtle_shapes["diamondcustom"]
  @test spec.rotatable == true
  @test length(spec.elements) == 1
  @test spec.elements[1] isa NetLogo.TurtlePolygonElement
  @test spec.elements[1].color === nothing  # agent color

  # Verify it renders (export-view should not error)
  pixels = NetLogo.render_view_pixels(runtime)
  @test size(pixels) == (65, 65)

  # The diamond shape at red color should have red pixels somewhere near center
  center_region = pixels[25:40, 25:40]
  has_red = any(p -> p[1] > 200.0 && p[2] < 50.0 && p[3] < 50.0, center_region)
  @test has_red

  # Test loading all defaults into a runtime
  runtime2 = create_runtime(compile_model(""); seed=1)
  NetLogo.load_turtle_shapes!(runtime2, read(shapes_path, String))
  @test length(runtime2.custom_turtle_shapes) >= 37

  # Test java_color_to_rgba conversion
  @test NetLogo.java_color_to_rgba(-16777216) == (0.0, 0.0, 0.0, 255.0)
  @test NetLogo.java_color_to_rgba(-1) == (255.0, 255.0, 255.0, 255.0)
  @test NetLogo.java_color_to_rgba(-10899396) == (89.0, 176.0, 60.0, 255.0)
  @test NetLogo.java_color_to_rgba(-6459832) == (157.0, 110.0, 72.0, 255.0)
end

@testset "unit: patch color import commands" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  landscape_path = joinpath(fixture_dir, "import-pcolors-test.png")
  vertical_path = joinpath(fixture_dir, "import-pcolors-test-vertical.png")

  exact_runtime = create_runtime(compile_model("""
  to import-numeric
    import-pcolors $(repr(exact_path))
  end

  to import-rgb
    import-pcolors-rgb $(repr(exact_path))
  end
  """); min_pxcor=0, max_pxcor=215, min_pycor=0, max_pycor=215, topology=BoxTopology, seed=307)

  resize_runtime = create_runtime(compile_model("""
  to import-landscape
    resize-world (-1) 1 (-100) 100
    import-pcolors $(repr(landscape_path))
  end

  to import-landscape-topology
    resize-world 0 200 0 2
    import-pcolors $(repr(landscape_path))
  end

  to import-vertical
    resize-world (-100) 100 (-1) 1
    import-pcolors $(repr(vertical_path))
  end
  """); seed=311)

  call!(exact_runtime, "import-numeric")
  @test [
    NetLogo.get_patch(exact_runtime.world, 0, 215).pcolor,
    NetLogo.get_patch(exact_runtime.world, 215, 215).pcolor,
    NetLogo.get_patch(exact_runtime.world, 0, 0).pcolor,
    NetLogo.get_patch(exact_runtime.world, 215, 0).pcolor,
    NetLogo.get_patch(exact_runtime.world, 108, 107).pcolor,
  ] == Any[133.3, 107.3, 70.9, 120.9, 49.1]

  call!(exact_runtime, "import-rgb")
  @test [
    NetLogo.get_patch(exact_runtime.world, 0, 215).pcolor,
    NetLogo.get_patch(exact_runtime.world, 215, 215).pcolor,
    NetLogo.get_patch(exact_runtime.world, 0, 0).pcolor,
    NetLogo.get_patch(exact_runtime.world, 215, 0).pcolor,
    NetLogo.get_patch(exact_runtime.world, 108, 107).pcolor,
  ] == Any[
    Any[138.0, 78.0, 92.0],
    Any[133.0, 158.0, 203.0],
    Any[6.0, 35.0, 27.0],
    Any[37.0, 6.0, 24.0],
    Any[251.0, 251.0, 214.0],
  ]

  call!(resize_runtime, "import-landscape")
  @test any(patch -> patch.pcolor != 0.0, resize_runtime.world.patches)

  call!(resize_runtime, "import-landscape-topology")
  @test any(patch -> patch.pcolor != 0.0, resize_runtime.world.patches)

  call!(resize_runtime, "import-vertical")
  @test any(patch -> patch.pcolor != 0.0, resize_runtime.world.patches)
end

@testset "unit: drawing import commands" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  landscape_path = joinpath(fixture_dir, "import-pcolors-test.png")
  vertical_path = joinpath(fixture_dir, "import-pcolors-test-vertical.png")

  runtime = create_runtime(compile_model("""
  to import-exact
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
  end

  to clear-imported-drawing
    clear-drawing
  end

  to double-patch-size
    set-patch-size 2
  end

  to clear-by-resize
    set-patch-size 1
    resize-world (-1) 1 (-100) 100
  end

  to clear-by-clear-all
    clear-all
  end

  to import-landscape
    resize-world (-1) 1 (-100) 100
    set-patch-size 1
    import-drawing $(repr(landscape_path))
  end

  to import-vertical
    resize-world (-100) 100 (-1) 1
    set-patch-size 1
    import-drawing $(repr(vertical_path))
  end
  """); seed=317)

  call!(runtime, "import-exact")
  @test size(runtime.world.drawing) == (216, 216)
  @test [
    runtime.world.drawing[1, 1],
    runtime.world.drawing[1, 216],
    runtime.world.drawing[216, 1],
    runtime.world.drawing[216, 216],
    runtime.world.drawing[109, 109],
  ] == [
    (138.0, 78.0, 92.0, 255.0),
    (133.0, 158.0, 203.0, 255.0),
    (6.0, 35.0, 27.0, 255.0),
    (37.0, 6.0, 24.0, 255.0),
    (251.0, 251.0, 214.0, 255.0),
  ]

  call!(runtime, "clear-imported-drawing")
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "import-exact")
  call!(runtime, "double-patch-size")
  @test size(runtime.world.drawing) == (432, 432)
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)

  call!(runtime, "clear-by-resize")
  @test size(runtime.world.drawing) == (201, 3)
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "import-landscape")
  @test size(runtime.world.drawing) == (201, 3)
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)

  call!(runtime, "clear-by-clear-all")
  @test size(runtime.world.drawing) == (201, 3)
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "import-vertical")
  @test size(runtime.world.drawing) == (3, 201)
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)
end

@testset "unit: export view command" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  base_dir = mktempdir()
  patch_view_path = joinpath(base_dir, "patch-view.png")
  drawing_view_path = joinpath(base_dir, "drawing-view.png")
  scaled_view_path = joinpath(base_dir, "scaled-view.png")
  agent_view_path = joinpath(base_dir, "agent-view.png")
  labeled_view_path = joinpath(base_dir, "labeled-view.png")
  torus_wrapped_view_path = joinpath(base_dir, "torus-wrapped-view.png")
  vertical_wrapped_view_path = joinpath(base_dir, "vertical-wrapped-view.png")
  horizontal_wrapped_view_path = joinpath(base_dir, "horizontal-wrapped-view.png")
  box_wrapped_view_path = joinpath(base_dir, "box-wrapped-view.png")
  runtime = create_runtime(compile_model("""
  to export-patch-view [file]
    clear-all
    resize-world 0 215 0 215
    set-patch-size 1
    import-pcolors-rgb $(repr(exact_path))
    export-view file
  end

  to export-drawing-view [file]
    clear-all
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
    export-view file
  end

  to export-scaled-view [file]
    clear-all
    resize-world 0 1 0 0
    set-patch-size 3
    ask patch 0 0 [ set pcolor [10 20 30 128] ]
    ask patch 1 0 [ set pcolor [40 50 60] ]
    export-view file
  end

  to export-agent-view [file]
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    ask patches [ set pcolor [1 2 3] ]
    crt 3
    ask turtle 0 [ setxy 0 1 set color [90 100 110 255] ]
    ask turtle 1 [ setxy 2 1 set color [90 100 110 255] ]
    ask turtle 2 [ setxy 1 1 set color [4 7 9 255] ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask link 0 1 [ set color [90 100 110 255] ]
    export-view file
  end

  to export-labeled-view [file]
    clear-all
    resize-world 0 8 0 4
    set-patch-size 5
    set-topology false false
    ask patches [ set pcolor [1 2 3] ]
    ask patch 1 3 [
      set plabel "P"
      set plabel-color [200 10 20 255]
    ]
    random-seed 2
    crt 3
    ask turtle 0 [
      setxy 2 1
      set color [50 60 70 255]
    ]
    ask turtle 1 [
      setxy 6 1
      set color [50 60 70 255]
      create-link-with turtle 0
    ]
    ask link 0 1 [
      set label "L"
      set label-color [10 200 30 255]
    ]
    ask turtle 2 [
      setxy 7 3
      set color [80 90 100 255]
      set label "T"
      set label-color [30 40 210 255]
    ]
    export-view file
  end

  to export-wrapped-labeled-view [file wrap-x wrap-y]
    clear-all
    resize-world 0 2 0 2
    set-patch-size 5
    set-topology wrap-x wrap-y
    ask patches [ set pcolor [1 2 3] ]
    ask patch 0 1 [
      set plabel "PATCH"
      set plabel-color [200 10 20 255]
    ]
    random-seed 2
    crt 4
    ask turtle 0 [
      setxy 2 1
      set size 2
      set color [50 60 70 255]
      set label "X"
      set label-color [30 40 210 255]
    ]
    ask turtle 1 [
      setxy 0 0
      set size 2
      set color [80 90 100 255]
      set label "Y"
      set label-color [220 120 20 255]
    ]
    ask turtle 2 [ setxy 0 2 set color [10 11 12 255] ]
    ask turtle 3 [
      setxy 2 2
      set color [13 14 15 255]
      create-link-with turtle 2
    ]
    ask link 2 3 [
      set label "L"
      set label-color [10 200 30 255]
    ]
    export-view file
  end
  """); seed=321)

  try
    call!(runtime, "export-patch-view", patch_view_path)
    patch_image = NetLogo.FileIO.load(patch_view_path)
    @test size(patch_image) == (216, 216)
    @test [
      NetLogo.image_rgba_channels(patch_image[1, 1]),
      NetLogo.image_rgba_channels(patch_image[1, 216]),
      NetLogo.image_rgba_channels(patch_image[216, 1]),
      NetLogo.image_rgba_channels(patch_image[216, 216]),
      NetLogo.image_rgba_channels(patch_image[109, 109]),
    ] == [
      (138.0, 78.0, 92.0, 255.0),
      (133.0, 158.0, 203.0, 255.0),
      (6.0, 35.0, 27.0, 255.0),
      (37.0, 6.0, 24.0, 255.0),
      (251.0, 251.0, 214.0, 255.0),
    ]

    call!(runtime, "export-drawing-view", drawing_view_path)
    drawing_image = NetLogo.FileIO.load(drawing_view_path)
    @test size(drawing_image) == (216, 216)
    @test [
      NetLogo.image_rgba_channels(drawing_image[1, 1]),
      NetLogo.image_rgba_channels(drawing_image[1, 216]),
      NetLogo.image_rgba_channels(drawing_image[216, 1]),
      NetLogo.image_rgba_channels(drawing_image[216, 216]),
      NetLogo.image_rgba_channels(drawing_image[109, 109]),
    ] == [
      (138.0, 78.0, 92.0, 255.0),
      (133.0, 158.0, 203.0, 255.0),
      (6.0, 35.0, 27.0, 255.0),
      (37.0, 6.0, 24.0, 255.0),
      (251.0, 251.0, 214.0, 255.0),
    ]

    call!(runtime, "export-scaled-view", scaled_view_path)
    scaled_image = NetLogo.FileIO.load(scaled_view_path)
    @test size(scaled_image) == (3, 6)
    @test NetLogo.image_rgba_channels(scaled_image[1, 1]) == (10.0, 20.0, 30.0, 128.0)
    @test NetLogo.image_rgba_channels(scaled_image[3, 3]) == (10.0, 20.0, 30.0, 128.0)
    @test NetLogo.image_rgba_channels(scaled_image[1, 4]) == (40.0, 50.0, 60.0, 255.0)
    @test NetLogo.image_rgba_channels(scaled_image[3, 6]) == (40.0, 50.0, 60.0, 255.0)

    call!(runtime, "export-agent-view", agent_view_path)
    agent_image = NetLogo.FileIO.load(agent_view_path)
    @test size(agent_image) == (3, 3)
    @test NetLogo.image_rgba_channels(agent_image[2, 1]) == (90.0, 100.0, 110.0, 255.0)
    @test NetLogo.image_rgba_channels(agent_image[2, 2]) == (4.0, 7.0, 9.0, 255.0)
    @test NetLogo.image_rgba_channels(agent_image[2, 3]) == (90.0, 100.0, 110.0, 255.0)
    @test NetLogo.image_rgba_channels(agent_image[1, 1]) == (1.0, 2.0, 3.0, 255.0)

    call!(runtime, "export-labeled-view", labeled_view_path)
    labeled_image = NetLogo.FileIO.load(labeled_view_path)
    @test size(labeled_image) == (25, 45)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), labeled_image[6:10, 8:10])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), labeled_image[14:18, 21:23])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), labeled_image[6:10, 38:40])

    call!(runtime, "export-wrapped-labeled-view", torus_wrapped_view_path, true, true)
    torus_wrapped_image = NetLogo.FileIO.load(torus_wrapped_view_path)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), torus_wrapped_image[6:10, 11:15])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), torus_wrapped_image[9:13, 1:3])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (220.0, 120.0, 20.0, 255.0), torus_wrapped_image[1:3, 6:8])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), torus_wrapped_image[14:15, 13:15])

    call!(runtime, "export-wrapped-labeled-view", vertical_wrapped_view_path, true, false)
    vertical_wrapped_image = NetLogo.FileIO.load(vertical_wrapped_view_path)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), vertical_wrapped_image[6:10, 11:15])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), vertical_wrapped_image[9:13, 1:3])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (220.0, 120.0, 20.0, 255.0), vertical_wrapped_image[1:3, 6:8])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), vertical_wrapped_image[14:15, 13:15])

    call!(runtime, "export-wrapped-labeled-view", horizontal_wrapped_view_path, false, true)
    horizontal_wrapped_image = NetLogo.FileIO.load(horizontal_wrapped_view_path)
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), horizontal_wrapped_image[6:10, 11:15])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), horizontal_wrapped_image[9:13, 1:3])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (220.0, 120.0, 20.0, 255.0), horizontal_wrapped_image[1:3, 6:8])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), horizontal_wrapped_image[14:15, 13:15])

    call!(runtime, "export-wrapped-labeled-view", box_wrapped_view_path, false, false)
    box_wrapped_image = NetLogo.FileIO.load(box_wrapped_view_path)
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), box_wrapped_image[6:10, 11:15])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), box_wrapped_image[9:13, 1:3])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (220.0, 120.0, 20.0, 255.0), box_wrapped_image[1:3, 6:8])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), box_wrapped_image[14:15, 13:15])
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: export drawing command" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  base_dir = mktempdir()
  exported_path = joinpath(base_dir, "drawing.png")
  blank_path = joinpath(base_dir, "blank-drawing.png")
  runtime = create_runtime(compile_model("""
  to export-imported-drawing [file]
    clear-all
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
    export-drawing file
  end

  to export-blank-drawing [file]
    clear-all
    resize-world 0 1 0 0
    set-patch-size 2
    export-drawing file
  end
  """); seed=325)

  try
    call!(runtime, "export-imported-drawing", exported_path)
    exported = NetLogo.FileIO.load(exported_path)
    @test size(exported) == (216, 216)
    @test [
      NetLogo.image_rgba_channels(exported[1, 1]),
      NetLogo.image_rgba_channels(exported[1, 216]),
      NetLogo.image_rgba_channels(exported[216, 1]),
      NetLogo.image_rgba_channels(exported[216, 216]),
      NetLogo.image_rgba_channels(exported[109, 109]),
    ] == [
      (138.0, 78.0, 92.0, 255.0),
      (133.0, 158.0, 203.0, 255.0),
      (6.0, 35.0, 27.0, 255.0),
      (37.0, 6.0, 24.0, 255.0),
      (251.0, 251.0, 214.0, 255.0),
    ]

    call!(runtime, "export-blank-drawing", blank_path)
    blank = NetLogo.FileIO.load(blank_path)
    @test size(blank) == (2, 4)
    @test all(pixel -> NetLogo.image_rgba_channels(pixel) == (0.0, 0.0, 0.0, 0.0), blank)
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "unit: pen and stamp drawing commands" begin
  runtime = create_runtime(compile_model("""
  to fd-pen-trails
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 1 0
      set heading 0
      set color [10 20 30 128]
      pd
      fd 1
      penup
      fd 1
      pendown
      set xcor 2
      set heading 90
      pen-erase
      bk 1
    ]
  end

  to move-to-trail
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    crt 2
    ask turtle 0 [ setxy 0 0 set color [40 50 60 255] pen-down ]
    ask turtle 1 [ setxy 0 2 ]
    ask turtle 0 [ move-to turtle 1 ]
  end

  to home-trail
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    crt 1
    ask turtle 0 [ setxy 0 2 set color [70 80 90 255] pen-down home ]
  end

  to stamp-turtle
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 1 1
      set size 1
      set color [4 7 9 1]
      stamp
    ]
  end

  to erase-turtle-stamp
    stamp-turtle
    ask turtle 0 [ stamp-erase ]
  end

  to stamp-link
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    crt 2
    ask turtle 0 [ setxy 0 1 create-link-with turtle 1 ]
    ask turtle 1 [ setxy 2 1 ]
    ask link 0 1 [
      set color [90 100 110 255]
      stamp
    ]
  end

  to erase-link-stamp
    stamp-link
    ask link 0 1 [ stamp-erase ]
  end

  to stamp-labeled-link
    clear-all
    resize-world 0 6 0 4
    set-patch-size 5
    set-topology false false
    crt 2
    ask turtle 0 [ setxy 1 2 ]
    ask turtle 1 [ setxy 5 2 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask link 0 1 [
      set color [90 100 110 255]
      set label "L"
      set label-color [10 200 30 255]
      stamp
    ]
  end

  to stamp-labeled-turtle
    clear-all
    resize-world 0 6 0 4
    set-patch-size 5
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 4 3
      set size 1.2
      set color [80 90 100 255]
      set label "T"
      set label-color [30 40 210 255]
      stamp
    ]
  end
  """); seed=341)

  call!(runtime, "fd-pen-trails")
  @test runtime.world.drawing[3, 2] == (10.0, 20.0, 30.0, 128.0)
  @test runtime.world.drawing[2, 2] == (10.0, 20.0, 30.0, 128.0)
  @test runtime.world.drawing[1, 2] == (0.0, 0.0, 0.0, 0.0)
  @test runtime.world.drawing[1, 3] == (0.0, 0.0, 0.0, 0.0)
  @test [turtle.pen_mode for turtle in runtime.world.turtles if turtle.alive] == ["erase"]

  call!(runtime, "move-to-trail")
  @test [runtime.world.drawing[row, 1] for row in 1:3] == fill((40.0, 50.0, 60.0, 255.0), 3)

  call!(runtime, "home-trail")
  @test [runtime.world.drawing[row, 1] for row in 1:3] == fill((70.0, 80.0, 90.0, 255.0), 3)

  call!(runtime, "stamp-turtle")
  @test runtime.world.drawing[2, 2] == (4.0, 7.0, 9.0, 1.0)

  call!(runtime, "erase-turtle-stamp")
  @test runtime.world.drawing[2, 2] == (0.0, 0.0, 0.0, 0.0)

  call!(runtime, "stamp-link")
  @test [runtime.world.drawing[2, column] for column in 1:3] == fill((90.0, 100.0, 110.0, 255.0), 3)

  call!(runtime, "erase-link-stamp")
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "stamp-labeled-link")
  @test any(pixel -> pixel == (10.0, 200.0, 30.0, 255.0), runtime.world.drawing[9:13, 16:18])

  call!(runtime, "stamp-labeled-turtle")
  @test any(pixel -> pixel == (80.0, 90.0, 100.0, 255.0), runtime.world.drawing)
  @test !any(pixel -> pixel == (30.0, 40.0, 210.0, 255.0), runtime.world.drawing)
end

@testset "unit: shape-aware rendering" begin
  runtime = create_runtime(compile_model("""
  to stamp-default-heading [degrees]
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.4
      set heading degrees
      set shape "default"
      set color [30 40 50 255]
      stamp
    ]
  end

  to stamp-bug-shape
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    set-default-shape turtles "bug"
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set color [80 90 100 255]
      stamp
    ]
  end

  to stamp-car-shape
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set heading 90
      set shape "car"
      set color [150 100 50 255]
      stamp
    ]
  end

  to stamp-airplane-shape [degrees]
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set heading degrees
      set shape "airplane"
      set color [200 60 70 255]
      stamp
    ]
  end

  to stamp-butterfly-shape
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set shape "butterfly"
      set color [210 80 160 255]
      stamp
    ]
  end

  to stamp-flower-shape
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set shape "flower"
      set color [180 70 200 255]
      stamp
    ]
  end

  to stamp-sheep-shape
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set shape "sheep"
      set color [140 120 80 255]
      stamp
    ]
  end

  to stamp-wheel-shape
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set shape "wheel"
      set color [20 140 180 255]
      stamp
    ]
  end

  to stamp-turtle-shape [degrees]
    clear-all
    resize-world 0 4 0 4
    set-patch-size 7
    set-topology false false
    crt 1
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set heading degrees
      set shape "turtle"
      set color [40 160 80 255]
      stamp
    ]
  end

  to stamp-directed-link
    clear-all
    resize-world 0 6 0 2
    set-patch-size 5
    set-topology false false
    crt 2
    ask turtle 0 [ setxy 1 1 ]
    ask turtle 1 [ setxy 5 1 ]
    ask turtle 0 [ create-link-to turtle 1 ]
    ask link 0 1 [
      set color [120 80 60 255]
      set thickness 0.4
      stamp
    ]
  end
  """); seed=351)

  call!(runtime, "stamp-default-heading", 0)
  north_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[11:14, 17:19])
  east_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[17:19, 23:26])
  @test north_focus > east_focus

  call!(runtime, "stamp-default-heading", 90)
  north_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[11:14, 17:19])
  east_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[17:19, 23:26])
  @test east_focus > north_focus

  call!(runtime, "stamp-bug-shape")
  @test any(pixel -> pixel == (80.0, 90.0, 100.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (0.0, 0.0, 0.0, 255.0), runtime.world.drawing)

  call!(runtime, "stamp-car-shape")
  @test any(pixel -> pixel == (150.0, 100.0, 50.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (0.0, 0.0, 0.0, 255.0), runtime.world.drawing)

  call!(runtime, "stamp-airplane-shape", 0)
  airplane_north = copy(runtime.world.drawing)
  @test any(pixel -> pixel == (200.0, 60.0, 70.0, 255.0), airplane_north)

  call!(runtime, "stamp-airplane-shape", 90)
  airplane_east = copy(runtime.world.drawing)
  @test any(pixel -> pixel == (200.0, 60.0, 70.0, 255.0), airplane_east)
  @test airplane_north != airplane_east

  call!(runtime, "stamp-butterfly-shape")
  @test any(pixel -> pixel == (210.0, 80.0, 160.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (0.0, 0.0, 0.0, 255.0), runtime.world.drawing)

  call!(runtime, "stamp-flower-shape")
  @test any(pixel -> pixel == (180.0, 70.0, 200.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (89.0, 176.0, 60.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (0.0, 0.0, 0.0, 255.0), runtime.world.drawing)

  call!(runtime, "stamp-sheep-shape")
  @test any(pixel -> pixel == (140.0, 120.0, 80.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (255.0, 255.0, 255.0, 255.0), runtime.world.drawing)

  call!(runtime, "stamp-wheel-shape")
  @test any(pixel -> pixel == (20.0, 140.0, 180.0, 255.0), runtime.world.drawing)
  @test any(pixel -> pixel == (0.0, 0.0, 0.0, 255.0), runtime.world.drawing)

  call!(runtime, "stamp-turtle-shape", 0)
  north_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[13:14, 17:19])
  east_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[16:19, 23:27])
  @test north_focus > east_focus

  call!(runtime, "stamp-turtle-shape", 90)
  north_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[13:14, 17:19])
  east_focus = count(pixel -> pixel[4] > 0.0, runtime.world.drawing[16:19, 23:27])
  @test east_focus > north_focus

  call!(runtime, "stamp-directed-link")
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing[8, 8:28]) > 10
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing[6:7, 25:29]) ||
    any(pixel -> pixel[4] > 0.0, runtime.world.drawing[9:10, 25:29])
end

@testset "unit: clear command aliases" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")

  runtime = create_runtime(compile_model("""
  to-report clear-all-alias
    crt 2
    ask patches [ set pcolor red ]
    ca
    report list any? turtles all? patches [pcolor = 0]
  end

  to-report clear-turtles-alias
    ca
    crt 3
    ct
    report count turtles
  end

  to-report clear-patches-alias
    ca
    ask patches [ set pcolor red ]
    cp
    report all? patches [pcolor = 0]
  end

  to load-drawing
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
  end

  to clear-drawing-alias
    cd
  end
  """); seed=331)

  @test call!(runtime, "clear-all-alias") == Any[false, true]
  @test call!(runtime, "clear-turtles-alias") == 0.0
  @test call!(runtime, "clear-patches-alias") == true

  call!(runtime, "load-drawing")
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)
  call!(runtime, "clear-drawing-alias")
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0
end

@testset "unit: link shapes and but-first alias" begin
  runtime = create_runtime(netlogo"""
  globals [glob1 glob2]

  to setup
    set glob1 "abc"
    set glob2 "def"
  end

  to-report but-first-demo
    report but-first (word glob1 glob2)
  end

  to-report link-shapes-demo
    report link-shapes
  end
  """; seed=347)

  call!(runtime, "setup")
  @test call!(runtime, "but-first-demo") == "bcdef"
  @test call!(runtime, "link-shapes-demo") == Any["default"]
end

@testset "unit: plot management commands" begin
  runtime = create_runtime(netlogo"""
  to setup-temp-pen
    set-current-plot "plot1"
    create-temporary-plot-pen "foobar"
  end

  to-report pen-exists [name]
    set-current-plot "plot1"
    report plot-pen-exists? name
  end

  to set-pen [name]
    set-current-plot "plot1"
    set-current-plot-pen name
  end

  to-report plot-metadata [name]
    set-current-plot name
    report (list plot-name plot-x-min plot-x-max plot-y-min plot-y-max)
  end

  to clear-temp-plot
    set-current-plot "plot1"
    clear-plot
  end

  to set-ranges
    set-current-plot "plot1"
    set-plot-x-range (-2) 12
    set-plot-y-range 3 9
  end

  to enable-autoplot
    set-current-plot "plot1"
    auto-plot-off
    auto-plot-on
  end

  to-report autoplot-flags
    set-current-plot "plot1"
    report (list autoplot? autoplotx? autoploty?)
  end

  to clear-all-plots-demo
    set-current-plot "plot1"
    create-temporary-plot-pen "foobar"
    set-plot-x-range (-2) 12
    set-plot-y-range 3 9
    clear-all-plots
  end

  to invalid-x-range
    set-current-plot "plot1"
    set-plot-x-range 5 5
  end

  to select-missing-plot
    set-current-plot "bogus"
  end

  to-report autoplot-sequence
    set-current-plot "plot1"
    create-temporary-plot-pen "foobar"
    let states []
    let state (list autoplot? autoplotx? autoploty?)
    set states lput state states
    auto-plot-off
    set state (list autoplot? autoplotx? autoploty?)
    set states lput state states
    auto-plot-x-on
    set state (list autoplot? autoplotx? autoploty?)
    set states lput state states
    auto-plot-y-on
    set state (list autoplot? autoplotx? autoploty?)
    set states lput state states
    auto-plot-x-off
    set state (list autoplot? autoplotx? autoploty?)
    set states lput state states
    auto-plot-y-off
    set state (list autoplot? autoplotx? autoploty?)
    set states lput state states
    report states
  end
  """; seed=353)

  call!(runtime, "setup-temp-pen")
  @test call!(runtime, "pen-exists", "foobar") == true
  @test call!(runtime, "pen-exists", "pen1") == true
  @test call!(runtime, "pen-exists", "dummy") == false
  call!(runtime, "set-pen", "foobar")
  call!(runtime, "set-pen", "pen1")
  call!(runtime, "set-pen", "foobar")
  call!(runtime, "clear-temp-plot")
  @test call!(runtime, "pen-exists", "foobar") == false
  pen_error = try
    call!(runtime, "set-pen", "foobar")
    nothing
  catch err
    err
  end
  @test pen_error isa NetLogo.LogoRuntimeError
  @test pen_error.message == "There is no pen named \"foobar\" in the current plot"
  call!(runtime, "set-pen", "pen1")
  @test call!(runtime, "plot-metadata", "plot1") == Any["plot1", 0.0, 10.0, 0.0, 10.0]
  @test call!(runtime, "plot-metadata", "plot2") == Any["plot2", 0.0, 10.0, 0.0, 10.0]
  call!(runtime, "set-ranges")
  @test call!(runtime, "plot-metadata", "plot1") == Any["plot1", -2.0, 12.0, 3.0, 9.0]
  call!(runtime, "clear-temp-plot")
  @test call!(runtime, "plot-metadata", "plot1") == Any["plot1", 0.0, 10.0, 0.0, 10.0]
  call!(runtime, "enable-autoplot")
  @test call!(runtime, "autoplot-flags") == Any[true, true, true]
  @test call!(runtime, "autoplot-sequence") == Any[
    Any[true, true, true],
    Any[false, false, false],
    Any[false, true, false],
    Any[true, true, true],
    Any[false, false, true],
    Any[false, false, false],
  ]
  call!(runtime, "clear-all-plots-demo")
  @test call!(runtime, "pen-exists", "foobar") == false
  @test call!(runtime, "plot-metadata", "plot1") == Any["plot1", 0.0, 10.0, 0.0, 10.0]
  missing_plot_error = try
    call!(runtime, "select-missing-plot")
    nothing
  catch err
    err
  end
  @test missing_plot_error isa NetLogo.LogoRuntimeError
  @test missing_plot_error.message == "no such plot: \"bogus\""
  invalid_range_error = try
    call!(runtime, "invalid-x-range")
    nothing
  catch err
    err
  end
  @test invalid_range_error isa NetLogo.LogoRuntimeError
  @test invalid_range_error.message == "the minimum must be less than the maximum, but 5.0 is greater than or equal to 5.0"
end

@testset "unit: plot data commands" begin
  runtime = create_runtime(netlogo"""
  to basic-plot-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    plot 5
    plot 7.5
    plotxy 4 9
  end

  to pen-up-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    plot-pen-up
    plotxy 2 3
    plot-pen-down
    plotxy 4 5
  end

  to interval-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    set-plot-pen-interval 1.5
    plot 5
    plot 7.5
    set-plot-pen-interval 2.5
    plot 9
  end

  to bar-mode-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    set-plot-pen-interval 5
    set-plot-pen-mode 1
    plotxy 10.0001 10.0001
  end

  to histogram-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    set-plot-x-range 0 10
    set-plot-y-range 0 5
    histogram [0 1 4 9 0 1 4 6 9 1 6 5]
  end

  to histogram-num-bars-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    set-plot-x-range 0 12
    set-histogram-num-bars 4
  end

  to pen-reset-demo
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    set-plot-pen-interval 2
    set-plot-pen-color [255 0 0]
    set-plot-pen-mode 2
    plot 5
    plot-pen-reset
  end

  to invalid-plot-pen-mode
    set-current-plot "plot1"
    set-current-plot-pen "pen1"
    set-plot-pen-mode 3
  end

  to invalid-histogram
    set-current-plot "plot1"
    set-current-plot-pen "pen1"
    set-plot-pen-interval 0
    histogram [1 2 3]
  end
  """; seed=367)

  call!(runtime, "basic-plot-demo")
  plot1 = runtime.plot_manager.plots[1]
  pen1 = plot1.pens[1]
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 5.0, true),
    (1.0, 7.5, true),
    (4.0, 9.0, true),
  ]
  @test pen1.x == 4.0
  @test (plot1.x_min, plot1.x_max, plot1.y_min, plot1.y_max) == (0.0, 10.0, 0.0, 10.0)

  call!(runtime, "pen-up-demo")
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (2.0, 3.0, false),
    (4.0, 5.0, true),
  ]

  call!(runtime, "interval-demo")
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 5.0, true),
    (1.5, 7.5, true),
    (4.0, 9.0, true),
  ]
  @test pen1.interval == 2.5
  @test pen1.x == 4.0

  call!(runtime, "bar-mode-demo")
  @test pen1.mode == 1
  @test plot1.x_max == 16.0
  @test plot1.y_max == 12.0

  call!(runtime, "histogram-demo")
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 2.0, true),
    (1.0, 3.0, true),
    (4.0, 2.0, true),
    (5.0, 1.0, true),
    (6.0, 2.0, true),
    (9.0, 2.0, true),
  ]
  @test plot1.y_max == 5.0

  call!(runtime, "histogram-num-bars-demo")
  @test pen1.interval == 3.0

  call!(runtime, "pen-reset-demo")
  @test isempty(pen1.points)
  @test pen1.x == 0.0
  @test pen1.is_down == true
  @test pen1.interval == 1.0
  @test pen1.mode == 0
  @test pen1.color == 0.0

  invalid_mode_error = try
    call!(runtime, "invalid-plot-pen-mode")
    nothing
  catch err
    err
  end
  @test invalid_mode_error isa NetLogo.LogoRuntimeError
  @test invalid_mode_error.message == "3 is not a valid plot pen mode (valid modes are 0, 1, and 2)"

  invalid_histogram_error = try
    call!(runtime, "invalid-histogram")
    nothing
  catch err
    err
  end
  @test invalid_histogram_error isa NetLogo.LogoRuntimeError
  @test invalid_histogram_error.message == "You cannot histogram with a plot-pen-interval of 0."
end

@testset "unit: plot export commands" begin
  base_dir = mktempdir()
  single_path = joinpath(base_dir, "plot.csv")
  all_path = joinpath(base_dir, "plots.csv")
  runtime = create_runtime(netlogo"""
  to export-single-plot [file]
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    plot 5
    plot 8
    plot 17
    export-plot "plot1" file
  end

  to export-all-plots-demo [file]
    clear-all-plots
    set-current-plot "plot1"
    set-current-plot-pen "pen1"
    plot 5
    set-current-plot "plot2"
    set-current-plot-pen "pen2"
    plotxy 3 4
    export-all-plots file
  end

  to export-missing-plot [file]
    export-plot "bogus" file
  end
  """; seed=379)

  plot1 = runtime.plot_manager.plots[1]
  plot1.pens = [plot1.pens[1]]
  plot1.current_pen = plot1.pens[1]

  call!(runtime, "export-single-plot", single_path)
  single_content = replace(read(single_path, String), "\r\n" => "\n")
  @test startswith(single_content, "\"export-plot data ($(NetLogo.NETLOGO_VERSION_STRING))\"\n\"\"\n")
  @test occursin(r"^\"\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}:\d{3} \+0000\"$"m, single_content)
  @test endswith(single_content,
    "\"MODEL SETTINGS\"\n\n\n\n" *
    "\"plot1\"\n" *
    "\"x min\",\"x max\",\"y min\",\"y max\",\"autoplot?\",\"current pen\",\"legend open?\",\"number of pens\"\n" *
    "\"0.0\",\"10.0\",\"0.0\",\"18.0\",\"true\",\"pen1\",\"false\",\"1\"\n" *
    "\n" *
    "\"pen name\",\"pen down?\",\"mode\",\"interval\",\"color\",\"x\"\n" *
    "\"pen1\",\"true\",\"0\",\"1.0\",\"0.0\",\"2.0\"\n" *
    "\n" *
    "\"pen1\"\n" *
    "\"x\",\"y\",\"color\",\"pen down?\"\n" *
    "\"0.0\",\"5.0\",\"0.0\",\"true\"\n" *
    "\"1.0\",\"8.0\",\"0.0\",\"true\"\n" *
    "\"2.0\",\"17.0\",\"0.0\",\"true\"\n")

  call!(runtime, "export-all-plots-demo", all_path)
  all_content = replace(read(all_path, String), "\r\n" => "\n")
  @test startswith(all_content, "\"export-plots data ($(NetLogo.NETLOGO_VERSION_STRING))\"\n\"\"\n")
  @test occursin("\"plot1\"\n", all_content)
  @test occursin("\"plot2\"\n", all_content)
  @test first(findfirst("\"plot1\"", all_content)) < first(findfirst("\"plot2\"", all_content))

  missing_plot_error = try
    call!(runtime, "export-missing-plot", single_path)
    nothing
  catch err
    err
  end
  @test missing_plot_error isa NetLogo.LogoRuntimeError
  @test missing_plot_error.message == "no such plot: \"bogus\""
end

@testset "unit: plot callback commands" begin
  runtime = create_runtime(netlogo"""
  breed [dogs dog]
  globals [x]

  to clear-state
    clear-all
    clear-all-plots
  end

  to run-setup-plots
    setup-plots
  end

  to run-update-plots
    update-plots
  end

  to run-reset-ticks
    reset-ticks
  end

  to go
    create-dogs 1
    tick
  end

  to go-stop
    tick
    create-dogs 4
  end

  to go-explicit-stop
    update-plots
    create-dogs 4
  end

  to tick-only
    tick
  end

  to add-turtle
    create-turtles 1
  end

  to set-seed [n]
    random-seed n
  end

  to select-plot2-pen2
    set-current-plot "plot2"
    set-current-plot-pen "pen2"
  end

  to-report dog-count
    report count dogs
  end

  to-report rng-sample
    report n-values 10 [random 10]
  end
  """; seed=389)

  function clear_plot_codes!(runtime)
    for plot in runtime.plot_manager.plots
      plot.setup_code = ""
      plot.update_code = ""
      for pen in plot.pens
        pen.setup_code = ""
        pen.update_code = ""
      end
    end
    nothing
  end

  plot1 = runtime.plot_manager.plots[1]
  plot2 = runtime.plot_manager.plots[2]
  pen1 = plot1.pens[1]
  pen2 = plot1.pens[2]
  plot2_pen2 = plot2.pens[2]

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.setup_code = "create-dogs 5"
  pen1.setup_code = "create-dogs 3"
  call!(runtime, "run-setup-plots")
  @test call!(runtime, "dog-count") == 8.0
  @test isempty(pen1.points)

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  pen1.update_code = "plot count dogs * 2"
  call!(runtime, "run-reset-ticks")
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [(0.0, 0.0, true)]
  call!(runtime, "go")
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 0.0, true),
    (1.0, 2.0, true),
  ]
  call!(runtime, "run-update-plots")
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 0.0, true),
    (1.0, 2.0, true),
    (2.0, 2.0, true),
  ]

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  call!(runtime, "run-reset-ticks")
  call!(runtime, "go")
  @test isempty(pen1.points)

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  pen1.update_code = "plot 1"
  call!(runtime, "select-plot2-pen2")
  call!(runtime, "run-update-plots")
  @test runtime.plot_manager.current_plot === plot2
  @test plot2.current_pen === plot2_pen2

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.update_code = "create-dogs 1 stop"
  pen1.update_code = "create-dogs 42"
  call!(runtime, "run-reset-ticks")
  @test call!(runtime, "dog-count") == 1.0
  @test isempty(pen1.points)
  call!(runtime, "go-stop")
  @test call!(runtime, "dog-count") == 6.0
  @test isempty(pen1.points)

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.update_code = "create-dogs 1 stop"
  pen1.update_code = "create-dogs 42"
  call!(runtime, "run-reset-ticks")
  call!(runtime, "go-explicit-stop")
  @test call!(runtime, "dog-count") == 6.0

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  call!(runtime, "add-turtle")
  plot1.update_code = "ask turtles [stop]"
  pen1.update_code = "create-dogs 8"
  call!(runtime, "run-update-plots")
  @test call!(runtime, "dog-count") == 8.0

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  pen1.update_code = "create-dogs 8 stop"
  pen2.update_code = "create-dogs 8 stop"
  call!(runtime, "run-update-plots")
  @test call!(runtime, "dog-count") == 16.0

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.update_code = "set x n-values 10 [random 10]"
  pen1.update_code = "set x n-values 10 [random 10]"
  call!(runtime, "run-reset-ticks")
  call!(runtime, "set-seed", 10)
  rng_before = call!(runtime, "rng-sample")
  call!(runtime, "set-seed", 10)
  call!(runtime, "tick-only")
  @test call!(runtime, "rng-sample") == rng_before
end

@testset "unit: plot metadata loading" begin
  model = parse_model("""
  breed [dogs dog]
  globals [dog-count]

  to run-reset-ticks
    reset-ticks
    set dog-count count dogs
  end
  @#\$#@#\$#@
  PLOT
  10
  360
  239
  524
  Demo Plot
  Time
  Dogs
  1.0
  7.0
  2.0
  9.0
  true
  true
  "create-dogs 2" "create-dogs 1"
  PENS
  "dogs / 4" 5.0 1 -13345367 false "create-dogs 3" "plot count dogs"
  @#\$#@#\$#@
  """)

  @test model.has_interface_section == true
  @test length(model.plots) == 1
  plot = model.plots[1]
  @test plot.name == "Demo Plot"
  @test plot.x_axis == "Time"
  @test plot.y_axis == "Dogs"
  @test plot.default_x_min == 1.0
  @test plot.default_x_max == 7.0
  @test plot.default_y_min == 2.0
  @test plot.default_y_max == 9.0
  @test plot.auto_plot_x == true
  @test plot.auto_plot_y == true
  @test plot.legend_open == true
  @test plot.setup_code == "create-dogs 2"
  @test plot.update_code == "create-dogs 1"
  @test length(plot.pens) == 1
  pen = plot.pens[1]
  @test pen.name == "dogs / 4"
  @test pen.default_interval == 5.0
  @test pen.default_mode == 1
  @test pen.default_color == -13345367
  @test pen.in_legend == false
  @test pen.setup_code == "create-dogs 3"
  @test pen.update_code == "plot count dogs"

  runtime = create_runtime(model; seed=11)
  @test length(runtime.plot_manager.plots) == 1
  runtime_plot = runtime.plot_manager.plots[1]
  @test runtime_plot.name == "Demo Plot"
  @test runtime_plot.legend_open == true
  @test runtime_plot.current_pen === runtime_plot.pens[1]
  @test runtime_plot.pens[1].name == "dogs / 4"
  @test runtime_plot.pens[1].default_color == -13345367
  @test runtime_plot.pens[1].default_interval == 5.0
  @test runtime_plot.pens[1].default_mode == 1
  @test runtime_plot.pens[1].in_legend == false

  invalid_plot_error = try
    parse_model("""
    to go
    end
    @#\$#@#\$#@
    PLOT
    10
    360
    239
    524
    Broken Plot
    Time
    Dogs
    0.0
    10.0
    0.0
    10.0
    true
    false
    "" "if ["
    PENS
    "pen1" 1.0 0 -7500403 true "" ""
    @#\$#@#\$#@
    """)
    nothing
  catch err
    err
  end
  @test invalid_plot_error isa Diagnostic
  @test occursin("plot update code", invalid_plot_error.message)
end

@testset "unit: interface widget code validation" begin
  invalid_button_error = try
    parse_model("""
    to setup
    end
    @#\$#@#\$#@
    BUTTON
    0
    0
    100
    30
    Run
    [
    NIL
    1
    T
    OBSERVER
    NIL
    NIL
    NIL
    NIL
    1
    @#\$#@#\$#@
    """)
    nothing
  catch err
    err
  end
  @test invalid_button_error isa Diagnostic
  @test occursin("button code", invalid_button_error.message)

  invalid_monitor_error = try
    parse_model("""
    to-report foo
      report 1
    end
    @#\$#@#\$#@
    MONITOR
    0
    0
    100
    30
    Broken
    [
    2
    1
    11
    @#\$#@#\$#@
    """)
    nothing
  catch err
    err
  end
  @test invalid_monitor_error isa Diagnostic
  @test occursin("monitor source", invalid_monitor_error.message)
end

@testset "unit: interface widget metadata" begin
  model = parse_model("""
  to setup
    if plot? [ show ants ]
    show title
  end
  @#\$#@#\$#@
  GRAPHICS-WINDOW
  0
  0
  200
  220
  -1
  -1
  6.0
  1
  11
  1
  1
  1
  0
  0
  1
  1
  -5
  5
  -7
  7
  1
  1
  1
  ticks
  20.0

  SLIDER
  0
  0
  100
  33
  Ants
  ants
  0
  500
  300
  1
  1
  NIL
  HORIZONTAL

  SWITCH
  0
  40
  100
  73
  plot?
  plot?
  0
  1
  -1000

  CHOOSER
  0
  80
  100
  113
  mode
  mode
  "fast" "slow"
  1

  INPUTBOX
  0
  120
  100
  153
  title
  hello world
  1
  0
  String

  MONITOR
  0
  160
  100
  193
  Ant Count
  count turtles
  2
  1
  11

  BUTTON
  0
  200
  100
  233
  Run
  setup
  T
  1
  T
  OBSERVER
  NIL
  R
  NIL
  NIL
  0

  TEXTBOX
  0
  240
  120
  280
  hello world
  14
  15
  1

  OUTPUT
  0
  290
  120
  330
  12
  @#\$#@#\$#@
  """)

  @test model.has_interface_section == true
  @test model.view_widget !== nothing
  @test model.view_widget.min_pxcor == -5
  @test model.view_widget.max_pxcor == 5
  @test model.view_widget.min_pycor == -7
  @test model.view_widget.max_pycor == 7
  @test model.view_widget.patch_size == 6.0
  @test model.view_widget.wrap_x == false
  @test model.view_widget.wrap_y == true
  @test model.view_widget.tick_counter_label == "ticks"
  @test model.interface_globals["ANTS"] == 300.0
  @test model.interface_globals["PLOT?"] == true
  @test model.interface_globals["MODE"] == "slow"
  @test model.interface_globals["TITLE"] == "hello world"
  @test "ANTS" in model.globals
  @test "PLOT?" in model.globals
  @test "MODE" in model.globals
  @test "TITLE" in model.globals
  @test count(widget -> widget isa NetLogo.SliderWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.SwitchWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.ChooserWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.InputBoxWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.MonitorWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.ButtonWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.TextBoxWidgetSpec, model.interface_widgets) == 1
  @test count(widget -> widget isa NetLogo.OutputWidgetSpec, model.interface_widgets) == 1

  slider = only([widget for widget in model.interface_widgets if widget isa NetLogo.SliderWidgetSpec])
  @test slider.left == 0
  @test slider.top == 0
  @test slider.right == 100
  @test slider.bottom == 33
  @test slider.direction == "HORIZONTAL"

  button = only([widget for widget in model.interface_widgets if widget isa NetLogo.ButtonWidgetSpec])
  @test button.left == 0
  @test button.top == 200
  @test button.right == 100
  @test button.bottom == 233
  @test button.display == "Run"
  @test button.source == "setup"
  @test button.forever == true
  @test button.button_kind == "OBSERVER"
  @test button.action_key == 'R'
  @test button.disable_until_ticks_start == true

  text_box = only([widget for widget in model.interface_widgets if widget isa NetLogo.TextBoxWidgetSpec])
  @test text_box.display == "hello world"
  @test text_box.font_size == 14
  @test text_box.color == 15.0
  @test text_box.transparent == true

  output = only([widget for widget in model.interface_widgets if widget isa NetLogo.OutputWidgetSpec])
  @test output.left == 0
  @test output.top == 290
  @test output.right == 120
  @test output.bottom == 330
  @test output.font_size == 12

  runtime = create_runtime(model; seed=17)
  @test runtime.world.min_pxcor == -5
  @test runtime.world.max_pxcor == 5
  @test runtime.world.min_pycor == -7
  @test runtime.world.max_pycor == 7
  @test runtime.world.topology == HorizontalCylinder
  @test runtime.world.patch_size == 6.0
  @test runtime.world.observer.globals["ANTS"] == 300.0
  @test runtime.world.observer.globals["PLOT?"] == true
  @test runtime.world.observer.globals["MODE"] == "slow"
  @test runtime.world.observer.globals["TITLE"] == "hello world"

  NetLogo.clear_all!(runtime.world)
  @test runtime.world.observer.globals["ANTS"] == 300.0
  @test runtime.world.observer.globals["PLOT?"] == true
  @test runtime.world.observer.globals["MODE"] == "slow"
  @test runtime.world.observer.globals["TITLE"] == "hello world"

  override_runtime = create_runtime(model; min_pxcor=-1, max_pxcor=1, min_pycor=-2, max_pycor=2, topology=BoxTopology, patch_size=2, seed=17)
  @test override_runtime.world.min_pxcor == -1
  @test override_runtime.world.max_pxcor == 1
  @test override_runtime.world.min_pycor == -2
  @test override_runtime.world.max_pycor == 2
  @test override_runtime.world.topology == BoxTopology
  @test override_runtime.world.patch_size == 2.0

  import_pcolors_path = normpath(joinpath(@__DIR__, "..", "..", "NetLogo", "test", "import-pcolors", "import-pcolors-test1.nlogo"))
  old_model = compile_model(read(import_pcolors_path, String))
  old_runtime = create_runtime(old_model; seed=3)
  @test old_runtime.world.min_pxcor == 0
  @test old_runtime.world.max_pxcor == 17
  @test old_runtime.world.min_pycor == 0
  @test old_runtime.world.max_pycor == 17
  @test old_runtime.world.patch_size == 12.0
  @test old_runtime.world.topology == Torus
  @test count(widget -> widget isa NetLogo.ButtonWidgetSpec, old_model.interface_widgets) == 5
  @test count(widget -> widget isa NetLogo.TextBoxWidgetSpec, old_model.interface_widgets) == 3
  first_button = first([widget for widget in old_model.interface_widgets if widget isa NetLogo.ButtonWidgetSpec])
  @test occursin("setup", first_button.source)
  @test first_button.button_kind == "OBSERVER"
end

@testset "unit: shapes reporter" begin
  runtime = create_runtime(netlogo"""
  to-report shapes-demo
    report shapes
  end
  """; seed=1)

  @test call!(runtime, "shapes-demo") == Any[
    "default", "airplane", "arrow", "box", "bug", "butterfly", "car", "circle", "circle 2",
    "cow", "cylinder", "dot", "face happy", "face neutral", "face sad", "fish", "flag", "flower",
    "house", "leaf", "line", "line half", "pentagon", "person", "plant", "sheep", "square",
    "square 2", "star", "target", "tree", "triangle", "triangle 2", "truck", "turtle", "wheel",
    "wolf", "x"
  ]
end

@testset "unit: set-default-shape command" begin
  runtime = create_runtime(netlogo"""
  breed [frogs frog]
  undirected-link-breed [roads road]

  to setup
    clear-all
    set-default-shape turtles "bug"
    create-turtles 2
    set-default-shape frogs "car"
    create-frogs 1
    ask turtle 1 [ set breed frogs ]
    set-default-shape roads "default"
    ask turtle 0 [ create-road-with turtle 2 ]
  end

  to bad-patch-shape
    set-default-shape patches "default"
  end

  to bad-breed-shape
    set-default-shape turtles with [who = 0] "bug"
  end

  to bad-turtle-shape
    set-default-shape turtles "not-a-shape"
  end
  """; seed=1)

  call!(runtime, "setup")
  @test runtime.world.turtles[1].breed == "TURTLES"
  @test runtime.world.turtles[1].shape == "bug"
  @test runtime.world.turtles[2].breed == "FROGS"
  @test runtime.world.turtles[2].shape == "car"
  @test runtime.world.turtles[3].breed == "FROGS"
  @test runtime.world.turtles[3].shape == "car"
  @test runtime.world.links[1].shape == "default"

  patch_error = try
    call!(runtime, "bad-patch-shape")
    nothing
  catch err
    err
  end
  @test patch_error isa NetLogo.LogoRuntimeError
  @test occursin("patches do not have a shape", patch_error.message)

  breed_error = try
    call!(runtime, "bad-breed-shape")
    nothing
  catch err
    err
  end
  @test breed_error isa NetLogo.LogoRuntimeError
  @test occursin("entire breed", breed_error.message)

  turtle_shape_error = try
    call!(runtime, "bad-turtle-shape")
    nothing
  catch err
    err
  end
  @test turtle_shape_error isa NetLogo.LogoRuntimeError
  @test occursin("defined turtle shape", turtle_shape_error.message)
end

@testset "unit: metadata reporters" begin
  runtime = create_runtime(netlogo"""
  to-report version-prefix
    report substring netlogo-version 0 3
  end

  to-report version-equality
    report netlogo-version = netlogo-version
  end

  to-report home-directory-demo
    report home-directory
  end

  to-report behaviorspace-run-number-demo
    report behaviorspace-run-number
  end

  to-report behaviorspace-experiment-name-demo
    report behaviorspace-experiment-name
  end
  """; seed=1)

  @test call!(runtime, "version-prefix") == "7.0"
  @test call!(runtime, "version-equality") == true
  @test call!(runtime, "home-directory-demo") == homedir()
  @test call!(runtime, "behaviorspace-run-number-demo") == 0.0
  @test call!(runtime, "behaviorspace-experiment-name-demo") == ""
end

@testset "unit: point query reporters" begin
  torus_runtime = create_runtime(netlogo"""
  breed [frogs frog]
  breed [mice mouse]
  globals [patch-hit wrapped-hit frog-count mouse-count pack-count patch-count neighbor-frogs]

  to setup
    clear-all
    create-frogs 3 [ setxy 0 0 ]
    create-mice 5 [ setxy 0 0 ]
    ask turtle 0 [ setxy 0 0 ]
    ask turtle 1 [ setxy 0 0 ]
    ask turtle 2 [ setxy -1 1 ]
    ask turtle 3 [ setxy 0 0 ]
    ask turtle 4 [ setxy 0 0 ]
    ask turtle 5 [ setxy 0 0 ]
    ask turtle 6 [ setxy 0 0 ]
    ask turtle 7 [ setxy -1 1 ]
    set patch-hit count patches at-points [[0 0] [0 0] [0.2 0.1]]
    set wrapped-hit count patches at-points [[2 1]]
    set frog-count count frogs at-points [[0 0] [-1 1]]
    set mouse-count count mice-on patch 0 0
    set pack-count count turtles-on one-of frogs-on patch 0 0
    set patch-count count patches-on turtles
    set neighbor-frogs count frogs-on [neighbors] of patch 0 0
  end

  to-report invalid-point-dimension-demo
    report count patches at-points [[0 0 0]]
  end

  to-report invalid-point-value-demo
    report count turtles at-points [[0 "a"]]
  end

  to-report bad-turtles-on-demo
    report count turtles-on links
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=71)

  box_runtime = create_runtime(netlogo"""
  breed [frogs frog]

  to setup
    clear-all
    create-frogs 1 [ setxy 0 0 ]
  end

  to-report out-of-bounds-points-demo
    report count patches at-points [[2 0]]
  end

  to-report nobody-source-demo
    report count frogs-on patch 2 0
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=73)

  call!(torus_runtime, "setup")
  call!(box_runtime, "setup")

  @test torus_runtime.world.observer.globals["PATCH-HIT"] == 1.0
  @test torus_runtime.world.observer.globals["WRAPPED-HIT"] == 1.0
  @test torus_runtime.world.observer.globals["FROG-COUNT"] == 3.0
  @test torus_runtime.world.observer.globals["MOUSE-COUNT"] == 4.0
  @test torus_runtime.world.observer.globals["PACK-COUNT"] == 6.0
  @test torus_runtime.world.observer.globals["PATCH-COUNT"] == 2.0
  @test torus_runtime.world.observer.globals["NEIGHBOR-FROGS"] == 1.0
  @test call!(box_runtime, "out-of-bounds-points-demo") == 0.0
  @test_throws NetLogo.LogoRuntimeError call!(torus_runtime, "invalid-point-dimension-demo")
  @test_throws NetLogo.LogoRuntimeError call!(torus_runtime, "invalid-point-value-demo")
  @test_throws NetLogo.LogoRuntimeError call!(torus_runtime, "bad-turtles-on-demo")
  @test_throws NetLogo.LogoRuntimeError call!(box_runtime, "nobody-source-demo")
end

@testset "unit: breed-specific at reporters" begin
  runtime = create_runtime(netlogo"""
  breed [apples apple]
  breed [grapes grape]
  breed [bananas banana]
  breed [failtowns failtown]

  to setup
    clear-all
    create-failtowns 20 [ setxy 3 3 ]
    ask n-of 7 failtowns [ set breed apples ]
    ask n-of 9 failtowns [ set breed grapes ]
    ask n-of 4 failtowns [ set breed bananas ]
    ask (turtle-set (n-of 4 apples) (n-of 2 grapes) (n-of 3 bananas)) [ home ]
    crt 1
  end

  to-report breed-at-counts
    let target turtle 20
    report (list
      [count apples-at 0 0] of target
      [count grapes-at 0 0] of target
      [count bananas-at 0 0] of target
      [count failtowns-at 0 0] of target
      [count turtles-at 0 0] of target
      [count apples-at 3 3] of target
      [count grapes-at 3 3] of target
      [count bananas-at 3 3] of target
      [count failtowns-at 3 3] of target
      [count turtles-at 3 3] of target)
  end
  """; min_pxcor=-4, max_pxcor=4, min_pycor=-4, max_pycor=4, topology=BoxTopology, seed=241)

  call!(runtime, "setup")

  @test call!(runtime, "breed-at-counts") == Any[4.0, 2.0, 3.0, 0.0, 10.0, 3.0, 7.0, 1.0, 0.0, 11.0]
end

@testset "unit: breed-specific here reporters" begin
  runtime = create_runtime(netlogo"""
  breed [frogs frog]
  breed [mice mouse]
  globals [home-patch]

  to setup
    clear-all
    set home-patch patch 0 0
    create-frogs 10 [ setxy 0 0 ]
    create-mice 10 [ setxy 0 0 ]
  end

  to-report mouse-here-counts
    let target turtle 10
    report (list
      [count mice-here] of target
      [count other mice-here] of target
      [count frogs-here] of target
      [count other frogs-here] of target)
  end

  to-report patch-here-counts
    report (list
      [count frogs-here] of home-patch
      [count other frogs-here] of home-patch
      [length sort other frogs-here] of home-patch)
  end
  """; seed=243)

  call!(runtime, "setup")

  @test call!(runtime, "mouse-here-counts") == Any[10.0, 9.0, 10.0, 10.0]
  @test call!(runtime, "patch-here-counts") == Any[10.0, 10.0, 10.0]
end

@testset "unit: higher-order tasks and list reporters" begin
  runtime = create_runtime(netlogo"""
  globals [sink]
  breed [wolves wolf]
  wolves-own [energy]

  to setup
    clear-all
    set sink []
    create-wolves 3 [
      set energy item who [3 1 2]
      setxy 0 0
    ]
  end

  to-report square [x]
    report x * x
  end

  to-report runresult-demo
    report (runresult [ x -> x + 1 ] 4)
  end

  to-report runresult-constant-demo
    report runresult [ 3 ]
  end

  to-report closure-demo
    let x 10
    let addx [ y -> y + x ]
    set x 20
    report (runresult addx 5)
  end

  to-report nested-lambda-demo
    report (runresult (runresult [ x -> [ y -> x + y ] ] 4) 6)
  end

  to-report map-lambda-demo
    report map [ x -> x + 2 ] [1 2 3]
  end

  to-report map-procedure-demo
    report map square [1 2 3]
  end

  to-report map-variadic-demo
    report (map [[x y] -> x + y] [1 2 3] [10 20 30])
  end

  to-report filter-demo
    report filter [ x -> x < 3 ] [1 3 2]
  end

  to-report reduce-demo
    report reduce + [1 2 3 4]
  end

  to-report n-values-demo
    report n-values 4 [ x -> x * x ]
  end

  to-report sort-by-demo
    report sort-by [[x y] -> x < y] [3 1 4 2]
  end

  to-report sort-by-unary-demo
    report sort-by [ x -> x > 2 ] [3 1 4 2]
  end

  to-report sort-by-agentset-demo
    report map [ t -> [who] of t ] (sort-by [[a b] -> [who] of a < [who] of b] wolves)
  end

  to run-demo
    set sink []
    let append-item [ x -> set sink lput x sink ]
    run append-item 7
  end

  to foreach-demo
    set sink []
    foreach [1 2 3] [ x -> set sink lput x sink ]
  end

  to foreach-run-demo
    set sink []
    let commands (list [ x -> set sink lput x sink ] [ x -> set sink lput (x + 10) sink ])
    foreach commands [1 2] run
  end

  to-report sink-values
    report sink
  end

  to-report map-mismatch-demo
    report (map [[x y] -> x + y] [1 2] [10])
  end

  to-report runresult-arity-demo
    report runresult [ x -> x ]
  end
  """; seed=83)

  call!(runtime, "setup")

  @test call!(runtime, "runresult-demo") == 5.0
  @test call!(runtime, "runresult-constant-demo") == 3.0
  @test call!(runtime, "closure-demo") == 25.0
  @test call!(runtime, "nested-lambda-demo") == 10.0
  @test call!(runtime, "map-lambda-demo") == Any[3.0, 4.0, 5.0]
  @test call!(runtime, "map-procedure-demo") == Any[1.0, 4.0, 9.0]
  @test call!(runtime, "map-variadic-demo") == Any[11.0, 22.0, 33.0]
  @test call!(runtime, "filter-demo") == Any[1.0, 2.0]
  @test call!(runtime, "reduce-demo") == 10.0
  @test call!(runtime, "n-values-demo") == Any[0.0, 1.0, 4.0, 9.0]
  @test call!(runtime, "sort-by-demo") == Any[1.0, 2.0, 3.0, 4.0]
  @test call!(runtime, "sort-by-unary-demo") == Any[3.0, 4.0, 1.0, 2.0]
  @test call!(runtime, "sort-by-agentset-demo") == Any[0.0, 1.0, 2.0]

  call!(runtime, "run-demo")
  @test call!(runtime, "sink-values") == Any[7.0]

  call!(runtime, "foreach-demo")
  @test call!(runtime, "sink-values") == Any[1.0, 2.0, 3.0]

  call!(runtime, "foreach-run-demo")
  @test call!(runtime, "sink-values") == Any[1.0, 12.0]

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "map-mismatch-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "runresult-arity-demo")
end

@testset "unit: sort-on, ifelse-value, and numeric helpers" begin
  runtime = create_runtime(netlogo"""
  to setup
    clear-all
    crt 4 [
      setxy 0 0
    ]
    ask turtle 0 [ set label 3 ]
    ask turtle 1 [ set label 1 ]
    ask turtle 2 [ set label 4 ]
    ask turtle 3 [ set label "fox" ]
  end

  to-report ifelse-basic-demo
    report ifelse-value 2 = 2 [10] [20]
  end

  to-report ifelse-variadic-demo
    report (ifelse-value false [0] 1 = 1 [2] [4])
  end

  to-report ifelse-missing-else-demo
    report (ifelse-value false [0] false [1])
  end

  to-report abs-demo
    report map abs (list (-7) (-3.7) 0 0.4 1)
  end

  to-report mod-demo
    report 62 mod 5
  end

  to-report sort-on-who-demo
    report map [t -> [who] of t] sort-on [who] turtles
  end

  to-report sort-on-desc-demo
    report map [t -> [who] of t] sort-on [(- who)] turtles
  end

  to-report sort-on-string-demo
    report map [t -> [who] of t] sort-on [(word (5 - who))] turtles
  end

  to-report sort-on-mixed-demo
    report sort-on [label] turtles
  end
  """; seed=97)

  call!(runtime, "setup")

  @test call!(runtime, "ifelse-basic-demo") == 10.0
  @test call!(runtime, "ifelse-variadic-demo") == 2.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "ifelse-missing-else-demo")
  @test call!(runtime, "abs-demo") == Any[7.0, 3.7, 0.0, 0.4, 1.0]
  @test call!(runtime, "mod-demo") == 2.0
  @test call!(runtime, "sort-on-who-demo") == Any[0.0, 1.0, 2.0, 3.0]
  @test call!(runtime, "sort-on-desc-demo") == Any[3.0, 2.0, 1.0, 0.0]
  @test call!(runtime, "sort-on-string-demo") == Any[3.0, 2.0, 1.0, 0.0]
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "sort-on-mixed-demo")
end

@testset "unit: set builders and math reporters" begin
  runtime = create_runtime(netlogo"""
  breed [frogs frog]
  breed [mice mouse]

  to setup
    clear-all
    create-frogs 2 [ setxy who 0 ]
    create-mice 1 [ setxy 2 0 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
  end

  to-report same-breed-turtle-set
    report turtle-set frogs turtle 0
  end

  to-report mixed-turtle-set
    report turtle-set frogs mice
  end

  to-report nested-turtle-whos
    report sort [who] of (turtle-set (list (list turtle 1) (list frogs)))
  end

  to-report patch-pxcor-demo
    report sort [pxcor] of (patch-set patch 1 0 (list (list patch 0 0)))
  end

  to-report link-set-count
    report count (link-set links nobody (sort links))
  end

  to-report empty-agent-flags
    report (list (no-turtles = (turtles with [who > 20])) (no-patches = (patches with [pxcor > 99])) (no-links = (links with [color = 99])) (no-turtles = no-patches) (is-agentset? no-links) (is-turtle-set? no-turtles) (is-patch-set? no-patches) (is-link-set? no-links))
  end

  to-report math-demo
    report (list (floor 4.5) (ceiling (-4.5)) (round (-1.5)) (round 1.5) (int (-3.5)) (sqrt 37.21) (exp 0) (ln (exp (-1))) (log 64 2))
  end

  to-report trig-demo
    report (list (sin 0) (sin 90) (cos 0) (cos 180) (tan 45) (asin 1) (asin (-1)) (acos 0) (atan 1 (-1)) (atan (-1) 1) (sin 90 + 1))
  end

  to-report tan-zero-demo
    let total 0
    if tan (-540) = 0 [ set total total + 1 ]
    if tan (-360) = 0 [ set total total + 1 ]
    if tan (-180) = 0 [ set total total + 1 ]
    if tan 0 = 0 [ set total total + 1 ]
    if tan 180 = 0 [ set total total + 1 ]
    if tan 360 = 0 [ set total total + 1 ]
    if tan 540 = 0 [ set total total + 1 ]
    report total
  end

  to-report division-and-heading-demo
    report (list (3 / 1.5) (62 mod 5) (remainder 62 5) (remainder (-8) 3) (subtract-headings 355 10) (subtract-headings 10 355) (subtract-headings 0 180) (subtract-headings (-3660) 10))
  end

  to-report power-demo
    report (list (9 ^ 2) (9 ^ 0.5) (2 ^ 3 ^ 4) (2 ^ -1) (2 ^ -3) (2 ^ 0) (2 * 3 ^ 2) (2 ^ 3 * 4))
  end

  to-report bad-turtle-set
    report turtle-set patch 0 0
  end

  to-report bad-link-set
    report link-set turtles
  end

  to-report sqrt-error-demo
    report sqrt (-1)
  end

  to-report log-base-error-demo
    report log 9 0
  end

  to-report log-value-error-demo
    report log 0 10
  end

  to-report exp-overflow-demo
    report exp 10000
  end

  to-report divide-zero-demo
    report 3 / 0
  end

  to-report mod-zero-demo
    report 10 mod 0
  end

  to-report remainder-zero-demo
    report remainder 10 0
  end

  to-report atan-zero-demo
    report atan 0 0
  end

  to-report asin-error-demo
    report asin 1.00001
  end

  to-report acos-error-demo
    report acos (-1.00001)
  end

  to-report tan-overflow-demo
    report tan 90
  end

  to-report power-nonnumber-demo
    report -1 ^ 0.5
  end

  to-report power-overflow-demo
    report (exp 1) ^ 1024
  end
  """; seed=107)

  call!(runtime, "setup")

  frogset = call!(runtime, "same-breed-turtle-set")
  @test frogset isa AgentSet
  @test frogset.breed == "FROGS"
  @test [t.id for t in frogset.members] == [0, 1]

  mixedset = call!(runtime, "mixed-turtle-set")
  @test mixedset isa AgentSet
  @test mixedset.breed == "TURTLES"
  @test sort([t.id for t in mixedset.members]) == [0, 1, 2]

  @test call!(runtime, "nested-turtle-whos") == Any[0.0, 1.0]
  @test call!(runtime, "patch-pxcor-demo") == Any[0.0, 1.0]
  @test call!(runtime, "link-set-count") == 2.0
  @test call!(runtime, "empty-agent-flags") == Any[true, true, true, false, true, true, true, true]

  math_values = call!(runtime, "math-demo")
  @test math_values[1:5] == Any[4.0, -4.0, -1.0, 2.0, -3.0]
  @test math_values[6] ≈ 6.1
  @test math_values[7] == 1.0
  @test math_values[8] ≈ -1.0
  @test math_values[9] == 6.0

  trig_values = call!(runtime, "trig-demo")
  @test trig_values[1] == 0.0
  @test trig_values[2] == 1.0
  @test trig_values[3] == 1.0
  @test trig_values[4] == -1.0
  @test trig_values[5] ≈ 0.9999999999999999
  @test trig_values[6:10] == Any[90.0, -90.0, 90.0, 135.0, 315.0]
  @test trig_values[11] == 2.0

  @test call!(runtime, "tan-zero-demo") == 7.0
  @test call!(runtime, "division-and-heading-demo") == Any[2.0, 2.0, 2.0, -2.0, -15.0, 15.0, 180.0, -70.0]
  @test call!(runtime, "power-demo") == Any[81.0, 3.0, 4096.0, 0.5, 0.125, 1.0, 18.0, 32.0]

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-turtle-set")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-link-set")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "sqrt-error-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "log-base-error-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "log-value-error-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "exp-overflow-demo")

  divide_error = try
    call!(runtime, "divide-zero-demo")
    nothing
  catch err
    err
  end
  @test divide_error isa NetLogo.LogoRuntimeError
  @test divide_error.message == "Division by zero."

  mod_error = try
    call!(runtime, "mod-zero-demo")
    nothing
  catch err
    err
  end
  @test mod_error isa NetLogo.LogoRuntimeError
  @test mod_error.message == "Division by zero."

  remainder_error = try
    call!(runtime, "remainder-zero-demo")
    nothing
  catch err
    err
  end
  @test remainder_error isa NetLogo.LogoRuntimeError
  @test remainder_error.message == "Division by zero."

  atan_error = try
    call!(runtime, "atan-zero-demo")
    nothing
  catch err
    err
  end
  @test atan_error isa NetLogo.LogoRuntimeError
  @test atan_error.message == "atan is undefined when both inputs are zero."

  asin_error = try
    call!(runtime, "asin-error-demo")
    nothing
  catch err
    err
  end
  @test asin_error isa NetLogo.LogoRuntimeError
  @test asin_error.message == "math operation produced a non-number"

  acos_error = try
    call!(runtime, "acos-error-demo")
    nothing
  catch err
    err
  end
  @test acos_error isa NetLogo.LogoRuntimeError
  @test acos_error.message == "math operation produced a non-number"

  tan_error = try
    call!(runtime, "tan-overflow-demo")
    nothing
  catch err
    err
  end
  @test tan_error isa NetLogo.LogoRuntimeError
  @test tan_error.message == "math operation produced a number too large for NetLogo"

  power_nonnumber_error = try
    call!(runtime, "power-nonnumber-demo")
    nothing
  catch err
    err
  end
  @test power_nonnumber_error isa NetLogo.LogoRuntimeError
  @test power_nonnumber_error.message == "math operation produced a non-number"

  power_overflow_error = try
    call!(runtime, "power-overflow-demo")
    nothing
  catch err
    err
  end
  @test power_overflow_error isa NetLogo.LogoRuntimeError
  @test power_overflow_error.message == "math operation produced a number too large for NetLogo"
end

@testset "unit: carefully and local randomness" begin
  runtime = create_runtime(netlogo"""
  globals [recovered outer-draw local-draw next-draw]

  to setup
    clear-all
    random-seed 17
    set recovered ""
    set outer-draw 0
    set local-draw 0
    set next-draw 0
  end

  to careful-demo
    carefully [ error "boom" ] [ set recovered error-message ]
  end

  to nested-careful-demo
    carefully [ error "outer" ] [ carefully [ set recovered (word error-message "-handled") ] [] ]
  end

  to safe-careful-demo
    carefully [ set recovered "safe" ] [ set recovered "bad" ]
  end

  to local-random-demo
    set outer-draw random 100
    with-local-randomness [ set local-draw random 100 ]
    set next-draw random 100
  end

  to-report random-state-restored-demo
    let before __random-state
    with-local-randomness [ set local-draw random 1 ]
    report before = __random-state
  end

  to-report random-state-advances-demo
    let before __random-state
    __ignore random 1
    report before = __random-state
  end

  to-report local-random-report-demo
    let value 0
    with-local-randomness [ set value random 100 ]
    report value
  end

  to-report one-of-local-random-demo
    let chosen nobody
    with-local-randomness [ set chosen one-of patches ]
    report chosen = one-of patches
  end

  to-report min-one-of-local-random-demo
    let before __random-state
    with-local-randomness [ __ignore min-one-of patches [ pxcor ] ]
    report before = __random-state
  end

  to-report nested-local-random-demo
    let before __random-state
    with-local-randomness [ with-local-randomness [ set local-draw random 10 ] set next-draw random 10 ]
    report before = __random-state
  end

  to-report seed-local-random-demo
    random-seed 10
    let first random 10
    let local-first 0
    let local-next 0
    with-local-randomness [
      random-seed 10
      set local-first random 10
      set local-next random 20
    ]
    report (list (first = local-first) ((random 20) = local-next))
  end

  to local-random-stop-inner
    with-local-randomness [ set local-draw random 100 stop ]
  end

  to-report local-random-stop-demo
    let before __random-state
    local-random-stop-inner
    report before = __random-state
  end

  to-report local-random-carefully-demo
    let before __random-state
    carefully [ with-local-randomness [ set local-draw random 100 error "boom" ] ] []
    report before = __random-state
  end

  to-report ask-local-random-demo
    clear-all
    crt 10
    let before __random-state
    with-local-randomness [ ask turtles [ set color random 140 ] ]
    report before = __random-state
  end

  to-report error-message-outside
    report error-message
  end
  """; seed=17)

  call!(runtime, "setup")
  call!(runtime, "careful-demo")
  @test runtime.world.observer.globals["RECOVERED"] == "boom"

  call!(runtime, "nested-careful-demo")
  @test runtime.world.observer.globals["RECOVERED"] == "outer-handled"

  call!(runtime, "safe-careful-demo")
  @test runtime.world.observer.globals["RECOVERED"] == "safe"

  call!(runtime, "setup")
  call!(runtime, "local-random-demo")
  @test runtime.world.observer.globals["LOCAL-DRAW"] == runtime.world.observer.globals["NEXT-DRAW"]
  @test runtime.world.observer.globals["OUTER-DRAW"] != runtime.world.observer.globals["LOCAL-DRAW"]

  call!(runtime, "setup")
  @test call!(runtime, "random-state-restored-demo") == true
  @test call!(runtime, "random-state-advances-demo") == false
  @test call!(runtime, "one-of-local-random-demo") == true
  @test call!(runtime, "min-one-of-local-random-demo") == true
  @test call!(runtime, "nested-local-random-demo") == true
  @test call!(runtime, "seed-local-random-demo") == Any[true, true]
  @test call!(runtime, "local-random-stop-demo") == true
  @test call!(runtime, "local-random-carefully-demo") == true
  @test call!(runtime, "ask-local-random-demo") == true
  @test call!(runtime, "local-random-report-demo") == call!(runtime, "local-random-report-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "error-message-outside")
end

@testset "unit: ask-concurrent" begin
  runtime = create_runtime(netlogo"""
  to setup-repeat
    clear-all
    cro 4
  end

  to setup-let
    clear-all
    crt 4
  end

  to repeat-demo
    ask-concurrent turtles [ repeat 4 [ fd 1 ] ]
  end

  to let-demo
    ask-concurrent turtles [ let x who fd 1 set xcor x ]
  end

  to-report repeat-positions
    report (list [list xcor ycor] of turtle 0
                 [list xcor ycor] of turtle 1
                 [list xcor ycor] of turtle 2
                 [list xcor ycor] of turtle 3)
  end

  to-report let-demo-valid?
    report not any? turtles with [who != xcor]
  end

  to-report single-agent-error-demo
    clear-all
    crt 1
    let captured ""
    carefully [ ask-concurrent turtle 0 [ set pcolor red ] ] [ set captured error-message ]
    report captured
  end

  to-report local-random-ask-concurrent-demo
    clear-all
    crt 10
    let before __random-state
    with-local-randomness [ ask-concurrent turtles [ set color random 140 ] ]
    report before = __random-state
  end
  """; seed=17)

  call!(runtime, "setup-repeat")
  call!(runtime, "repeat-demo")
  @test call!(runtime, "repeat-positions") == Any[Any[0.0, 4.0], Any[4.0, 0.0], Any[0.0, -4.0], Any[-4.0, 0.0]]

  call!(runtime, "setup-let")
  call!(runtime, "let-demo")
  @test call!(runtime, "let-demo-valid?") == true

  @test call!(runtime, "single-agent-error-demo") == "ASK-CONCURRENT expected input to be an agentset but got the turtle (turtle 0) instead."
  @test call!(runtime, "local-random-ask-concurrent-demo") == true
end

@testset "unit: agent lifecycle and movement" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]
  breed [frogs frog]
  mice-own [mice-energy]
  frogs-own [frog-energy]
  globals [dead-ref dead-links cached-pack survived dead-message]

  to setup
    clear-all
    create-mice 1 [ set mice-energy 10 setxy 0 0 set heading 0 ]
    create-turtles 1 [ setxy 3 4 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    set dead-ref nobody
    set dead-links 0
    set cached-pack turtles
    set survived 0
    set dead-message ""
  end

  to do-face
    ask turtle 0 [ face turtle 1 ]
  end

  to do-move-to
    ask turtle 0 [ move-to patch 2 3 ]
  end

  to do-home
    ask turtle 0 [ setxy 4 5 set heading 90 home ]
  end

  to do-hatch
    ask turtle 0 [ set shape "circle" hatch 1 ]
  end

  to do-hatch-breed
    ask turtle 0 [ set shape "circle" hatch-frogs 1 ]
  end

  to do-sprout
    ask patch -1 2 [ sprout-frogs 2 [ set frog-energy 5 ] ]
  end

  to do-die
    ask turtle 0 [ set dead-ref self die ]
    set dead-links count links
    set survived count cached-pack
  end

  to do-link-die
    ask one-of links [ die ]
  end

  to read-dead-color
    carefully [ set dead-message [color] of dead-ref ] [ set dead-message error-message ]
  end

  to-report dead-string
    report word dead-ref
  end

  to-report bad-move-target
    ask turtle 0 [ move-to one-of turtles with [false] ]
    report 0
  end

  to-report bad-face-target
    let foo turtles
    ask turtle 0 [ face foo ]
    report 0
  end
  """; seed=211)

  call!(runtime, "setup")
  call!(runtime, "do-face")
  @test runtime.world.turtles[1].heading ≈ 36.86989764584402

  call!(runtime, "setup")
  call!(runtime, "do-move-to")
  @test runtime.world.turtles[1].xcor == 2.0
  @test runtime.world.turtles[1].ycor == 3.0

  call!(runtime, "setup")
  call!(runtime, "do-home")
  @test runtime.world.turtles[1].xcor == 0.0
  @test runtime.world.turtles[1].ycor == 0.0
  @test runtime.world.turtles[1].heading == 0.0

  call!(runtime, "setup")
  call!(runtime, "do-hatch")
  @test count(t -> t.alive, runtime.world.turtles) == 3
  @test runtime.world.turtles[3].breed == "MICE"
  @test runtime.world.turtles[3].shape == "circle"
  @test runtime.world.turtles[3].xcor == 0.0
  @test runtime.world.turtles[3].ycor == 0.0
  @test runtime.world.turtles[3].heading == 0.0
  @test runtime.world.turtles[3].own["MICE-ENERGY"] == 10.0

  call!(runtime, "setup")
  call!(runtime, "do-hatch-breed")
  @test count(t -> t.alive, runtime.world.turtles) == 3
  @test runtime.world.turtles[3].breed == "FROGS"
  @test runtime.world.turtles[3].shape == "default"
  @test runtime.world.turtles[3].own["FROG-ENERGY"] == 0.0

  call!(runtime, "setup")
  call!(runtime, "do-sprout")
  @test count(t -> t.alive && t.breed == "FROGS", runtime.world.turtles) == 2
  @test all(t -> t.xcor == -1.0 && t.ycor == 2.0 && t.own["FROG-ENERGY"] == 5.0,
    filter(t -> t.alive && t.breed == "FROGS", runtime.world.turtles))

  call!(runtime, "setup")
  call!(runtime, "do-die")
  call!(runtime, "read-dead-color")
  @test runtime.world.observer.globals["DEAD-LINKS"] == 0.0
  @test runtime.world.observer.globals["SURVIVED"] == 1.0
  @test runtime.world.observer.globals["DEAD-MESSAGE"] == "That mouse is dead."
  @test call!(runtime, "dead-string") == "nobody"

  call!(runtime, "setup")
  call!(runtime, "do-link-die")
  @test count(l -> l.alive, runtime.world.links) == 0

  call!(runtime, "setup")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-move-target")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-face-target")
end

@testset "unit: can-move predicate" begin
  function can_move_runtime(topology)
    runtime = create_runtime(netlogo"""
    to setup
      clear-all
      crt 1 [ set heading 0 fd 5.1 ]
    end

    to-report can-move-triplet [first-distance second-distance third-distance]
      report [(list can-move? first-distance can-move? second-distance can-move? third-distance)] of turtle 0
    end
    """; min_pxcor=-5, max_pxcor=5, min_pycor=-5, max_pycor=5, topology=topology, seed=227)
    call!(runtime, "setup")
    runtime
  end

  torus_runtime = can_move_runtime(Torus)
  box_runtime = can_move_runtime(BoxTopology)

  @test call!(torus_runtime, "can-move-triplet", 1, 0.5, 0) == Any[true, true, true]
  @test call!(box_runtime, "can-move-triplet", 1, 0.5, 0.2) == Any[false, false, true]
  @test call!(box_runtime, "can-move-triplet", 0.4, 0.2, 0) == Any[false, true, true]
end

@testset "unit: blocked forward movement" begin
  runtime = create_runtime(netlogo"""
  to setup
    clear-all
    resize-world 0 2 0 2
    set-topology false false
    crt 1 [ setxy 1 1 set heading 90 ]
  end

  to-report partial-forward [distance]
    setup
    ask turtle 0 [ fd distance ]
    report [list xcor ycor] of turtle 0
  end

  to-report blocked-forward-at-edge [distance]
    setup
    ask turtle 0 [ setxy 2 1 fd distance ]
    report [list xcor ycor] of turtle 0
  end
  """; seed=228)

  @test call!(runtime, "partial-forward", 2) == Any[2.0, 1.0]
  @test call!(runtime, "blocked-forward-at-edge", 1) == Any[2.0, 1.0]
end

@testset "unit: uphill and downhill commands" begin
  runtime = create_runtime(netlogo"""
  globals [glob1]
  patches-own [pvar]

  to-report gradient-headings
    clear-all
    crt 1
    set glob1 1
    ask turtle 0 [
      foreach sort neighbors [ x -> ask x [ set pvar glob1 set glob1 glob1 + 1 ] ]
      set pvar 100
      home
      downhill pvar
    ]
    let a [heading] of turtle 0
    ask turtle 0 [ home downhill4 pvar ]
    let b [heading] of turtle 0
    ask turtle 0 [ home set pvar -100 uphill pvar ]
    let c [heading] of turtle 0
    ask turtle 0 [ home uphill4 pvar ]
    let d [heading] of turtle 0
    report (list a b c d)
  end

  to-report uphill-headings
    clear-all
    random-seed 287
    ask patches [ if patch 0 0 != self [ set pcolor 1 ] ]
    crt 100
    ask turtles [ uphill pcolor ]
    report sort remove-duplicates [heading] of turtles
  end

  to-report uphill4-headings
    clear-all
    random-seed 287
    let home-patch patch 0 0
    ask patches [ if home-patch != self [ set pcolor 1 ] ]
    crt 100
    ask turtles [ uphill4 pcolor ]
    report sort remove-duplicates [heading] of turtles
  end

  to-report downhill-headings
    clear-all
    random-seed 287
    crt 100
    ask turtle 0 [ set pcolor 1 ]
    ask turtles [ downhill pcolor ]
    report sort remove-duplicates [heading] of turtles
  end

  to-report downhill4-headings
    clear-all
    random-seed 287
    crt 100
    ask turtle 0 [ set pcolor 1 ]
    ask turtles [ downhill4 pcolor ]
    report sort remove-duplicates [heading] of turtles
  end

  to-report uphill-home?
    clear-all
    random-seed 287
    let home-patch patch 0 0
    ask patches [ if home-patch != self [ set pcolor 1 ] ]
    crt 100
    ask turtles [ uphill pcolor rt 180 fd 1 move-to patch-here ]
    report not any? turtles with [ patch-here != home-patch ]
  end

  to-report downhill-home?
    clear-all
    random-seed 287
    crt 100
    ask turtle 0 [ set pcolor 1 ]
    let home-patch patch 0 0
    ask turtles [ downhill pcolor rt 180 fd 1 move-to patch-here ]
    report not any? turtles with [ patch-here != home-patch ]
  end
  """; seed=231)

  @test call!(runtime, "gradient-headings") == Any[315.0, 0.0, 135.0, 180.0]
  @test call!(runtime, "uphill-headings") == Any[0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
  @test call!(runtime, "uphill4-headings") == Any[0.0, 90.0, 180.0, 270.0]
  @test call!(runtime, "downhill-headings") == Any[0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
  @test call!(runtime, "downhill4-headings") == Any[0.0, 90.0, 180.0, 270.0]
  @test call!(runtime, "uphill-home?") == true
  @test call!(runtime, "downhill-home?") == true
end

@testset "unit: tie and link-length compatibility" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [l1s l1]
  directed-link-breed [l2s l2]

  to-report tie-modes
    clear-all
    cro 2 [ fd 1 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    let a [tie-mode] of link 0 1
    ask link 0 1 [ tie ]
    let b [tie-mode] of link 0 1
    ask link 0 1 [ untie ]
    let c [tie-mode] of link 0 1
    report (list a b c)
  end

  to-report directed-fixed-follow
    clear-all
    cro 2 [ fd 1 ]
    ask turtle 1 [ create-link-to turtle 0 [ tie ] ]
    ask turtle 1 [ rt 180 ]
    let a (list [ycor] of turtle 1 [ycor] of turtle 0 [heading] of turtle 0 [heading] of turtle 1)
    ask turtle 1 [ fd 1 ]
    let b (list [ycor] of turtle 1 [ycor] of turtle 0 [heading] of turtle 0 [heading] of turtle 1)
    report (list a b)
  end

  to-report free-follow
    clear-all
    cro 2 [ fd 1 ]
    ask turtle 0 [ create-link-with turtle 1 [ set tie-mode "free" ] ]
    ask turtle 1 [ rt 180 ]
    ask turtle 1 [ fd 2 ]
    ask turtle 0 [ rt 180 ]
    ask turtle 0 [ fd 2 ]
    report (list [ycor] of turtle 0 [ycor] of turtle 1 [heading] of turtle 0 [heading] of turtle 1)
  end

  to-report rigid-rotation-cycle
    clear-all
    cro 2 [ fd 1 ]
    ask turtle 1 [ create-link-to turtle 0 [ tie ] ]
    ask turtle 1 [ rt 90 ]
    let a (list [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1 [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0)
    ask turtle 1 [ rt 90 ]
    let b (list [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1 [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0)
    ask turtle 1 [ rt 90 ]
    let c (list [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1 [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0)
    ask turtle 1 [ rt 90 ]
    let d (list [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1 [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0)
    report (list a b c d)
  end

  to-report multiple-fixed-links
    clear-all
    crt 1 [ setxy 0 1 ]
    crt 1 [ setxy 0 0 ]
    ask turtle 1 [ create-l1-to turtle 0 [ set tie-mode "fixed" ] ]
    ask turtle 1 [ create-l2-to turtle 0 [ set tie-mode "fixed" ] ]
    ask turtle 1 [ right 90 ]
    report (list [xcor] of turtle 0 [ycor] of turtle 0)
  end

  to-report link-lengths
    clear-all
    crt 2
    ask turtle 0 [ setxy 0 0 ]
    ask turtle 1 [ setxy 3 4 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    let a [link-length] of link 0 1
    ask turtle 0 [ move-to turtle 1 ]
    let b [link-length] of link 0 1
    report (list a b)
  end

  to-report invalid-tie-mode-message
    clear-all
    crt 2
    ask turtle 0 [ create-link-with turtle 1 ]
    carefully [
      ask link 0 1 [ set tie-mode "banana" ]
    ] [
      report error-message
    ]
    report ""
  end
  """; seed=241)

  @test call!(runtime, "tie-modes") == Any["none", "fixed", "none"]
  @test call!(runtime, "directed-fixed-follow") == Any[
    Any[-1.0, -3.0, 180.0, 0.0],
    Any[0.0, -2.0, 180.0, 0.0],
  ]
  @test call!(runtime, "free-follow") == Any[-3.0, -5.0, 180.0, 0.0]
  @test call!(runtime, "rigid-rotation-cycle") == Any[
    Any[0.0, -1.0, 270.0, 2.0, -1.0, 90.0],
    Any[0.0, -1.0, 0.0, 0.0, -3.0, 180.0],
    Any[0.0, -1.0, 90.0, -2.0, -1.0, 270.0],
    Any[0.0, -1.0, 180.0, 0.0, 1.0, 0.0],
  ]
  @test call!(runtime, "multiple-fixed-links") == Any[1.0, 0.0]
  @test call!(runtime, "link-lengths") == Any[5.0, 0.0]
  @test call!(runtime, "invalid-tie-mode-message") == "tie-mode must be one of \"none\", \"fixed\", or \"free\""
end

@testset "unit: ordered creation and random initialization" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]

  to-report ordered-turtle-headings
    clear-all
    create-ordered-turtles 4
    report map [ t -> [heading] of t ] sort turtles
  end

  to-report ordered-turtle-colors
    clear-all
    cro 4
    report map [ t -> [color] of t ] sort turtles
  end

  to-report ordered-wolf-headings
    clear-all
    create-ordered-wolves 4
    report map [ t -> [heading] of t ] sort wolves
  end

  to-report ordered-wolf-colors
    clear-all
    create-ordered-wolves 4
    report map [ t -> [color] of t ] sort wolves
  end

  to-report cro-randomized-last
    clear-all
    random-seed 1717
    let last -1
    cro 10 [ set last who ]
    report last
  end

  to-report crt-randomized-last
    clear-all
    random-seed 1717
    let last -1
    crt 10 [ set last who ]
    report last
  end

  to-report hatch-randomized-last
    clear-all
    random-seed 1717
    crt 1
    let last -1
    ask turtle 0 [ hatch 10 [ set last who ] ]
    report last
  end

  to-report sprout-randomized-last
    clear-all
    random-seed 1717
    let last -1
    ask patch 0 0 [ sprout 10 [ set last who ] ]
    report last
  end

  to-report link-init-with
    clear-all
    random-seed 73219
    crt 10
    let last []
    ask turtle 0 [ create-links-with other turtles-here [ set last (list [who] of end1 [who] of end2) ] ]
    report last
  end

  to-report link-init-to
    clear-all
    random-seed 73219
    crt 10
    let last []
    ask turtle 0 [ create-links-to other turtles-here [ set last (list [who] of end1 [who] of end2) ] ]
    report last
  end

  to-report link-init-from
    clear-all
    random-seed 73219
    crt 10
    let last []
    ask turtle 0 [ create-links-from other turtles-here [ set last (list [who] of end1 [who] of end2) ] ]
    report last
  end
  """; seed=233)

  @test call!(runtime, "ordered-turtle-headings") == Any[0.0, 90.0, 180.0, 270.0]
  @test call!(runtime, "ordered-turtle-colors") == Any[5.0, 15.0, 25.0, 35.0]
  @test call!(runtime, "ordered-wolf-headings") == Any[0.0, 90.0, 180.0, 270.0]
  @test call!(runtime, "ordered-wolf-colors") == Any[5.0, 15.0, 25.0, 35.0]
  @test call!(runtime, "cro-randomized-last") == 3.0
  @test call!(runtime, "crt-randomized-last") == 8.0
  @test call!(runtime, "hatch-randomized-last") == 9.0
  @test call!(runtime, "sprout-randomized-last") == 8.0
  @test call!(runtime, "link-init-with") == Any[0.0, 3.0]
  @test call!(runtime, "link-init-to") == Any[0.0, 3.0]
  @test call!(runtime, "link-init-from") == Any[3.0, 0.0]
end

@testset "unit: color reporters and assignments" begin
  runtime = create_runtime(netlogo"""
  globals [saved-patch saved-link]

  to setup
    clear-all
    crt 2 [ setxy who 0 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    set saved-patch patch 0 0
    set saved-link link 0 1
  end

  to-report wrapped-colors
    report (list wrap-color 150 wrap-color (-10) wrap-color 0)
  end

  to-report shade-flags
    let a shade-of? blue red
    let b shade-of? blue (blue + 1)
    let c shade-of? gray white
    let d shade-of? -130 10
    report (list a b c d)
  end

  to-report scaled-colors
    let a scale-color red 5 0 10
    let b scale-color red 0 0 10
    let c scale-color red 10 0 10
    let d scale-color blue 16 10 20
    let e scale-color blue 16 20 10
    let f scale-color grey 0 1 1
    let g scale-color grey 1 1 1
    let h scale-color grey 2 1 1
    report (list a b c d e f g h)
  end

  to-report rgb-round-trip [col]
    let vals extract-rgb col
    let approx approximate-rgb (item 0 vals) (item 1 vals) (item 2 vals)
    report approx
  end

  to-report hsb-round-trip [col]
    let vals extract-hsb col
    let approx approximate-hsb (item 0 vals) (item 1 vals) (item 2 vals)
    report approx
  end

  to-report rgb-round-trips-ok
    let colors n-values 1400 [ x -> x / 10 ]
    report colors = map [ c -> rgb-round-trip c ] colors
  end

  to-report hsb-round-trips-ok
    let colors n-values 1400 [ x -> x / 10 ]
    report colors = map [ c -> hsb-round-trip c ] colors
  end

  to-report unique-rgb-count
    report length remove-duplicates map extract-rgb n-values 1400 [ x -> x / 10 ]
  end

  to-report clamped-color-lists
    let a rgb -1 -83 -9
    let b rgb 260 257 372
    let c hsb 360 50 100
    let d hsb 255 45 34
    report (list a b c d)
  end

  to-report exact-color-helpers
    let a extract-rgb red
    let b extract-rgb [215 50 41 100]
    let c extract-hsb blue
    let d hsb 218.974 69.231 66.275
    let e approximate-rgb 0 0 0
    let f approximate-hsb 0 0 0
    let g approximate-rgb 83 72 54
    let h base-colors
    report (list a b c d e f g h)
  end

  to do-valid-assignments
    ask turtle 0 [
      set color [0 255 0]
      set label-color [255 0 0 0]
    ]
    ask saved-patch [
      set pcolor [10 10 10 0]
      set plabel-color [255 0 0]
    ]
    ask saved-link [
      set color red
      set label-color [0 0 255 0]
    ]
  end

  to-report assigned-colors
    let a [color] of turtle 0
    let b [label-color] of turtle 0
    let c [pcolor] of saved-patch
    let d [plabel-color] of saved-patch
    let e [color] of saved-link
    let f [label-color] of saved-link
    report (list a b c d e f)
  end

  to bad-color-shape
    ask turtle 0 [ set color [0 0 0 0 0] ]
  end

  to bad-color-range
    ask saved-patch [ set pcolor [500 0 0] ]
  end

  to-report bad-extract-rgb
    report extract-rgb [10 10 10 10 10]
  end

  to-report color-after-errors
    report (list [color] of turtle 0 [pcolor] of saved-patch)
  end
  """; seed=241)

  call!(runtime, "setup")

  @test call!(runtime, "wrapped-colors") == Any[10.0, 130.0, 0.0]
  @test call!(runtime, "shade-flags") == Any[false, true, true, true]

  scaled = call!(runtime, "scaled-colors")
  @test scaled[1] == 15.0
  @test scaled[2] == 10.0
  @test scaled[3] == 19.9999
  @test scaled[4] == 106.0
  @test scaled[5] == 104.0
  @test scaled[6] == 0.0
  @test scaled[7] == 0.0
  @test scaled[8] == 9.9999

  @test call!(runtime, "rgb-round-trips-ok") == true
  @test call!(runtime, "hsb-round-trips-ok") == true
  @test call!(runtime, "unique-rgb-count") == 1400.0

  @test call!(runtime, "clamped-color-lists") == Any[
    Any[0.0, 0.0, 0.0],
    Any[255.0, 255.0, 255.0],
    Any[255.0, 128.0, 128.0],
    Any[57.0, 48.0, 87.0],
  ]

  helpers = call!(runtime, "exact-color-helpers")
  @test helpers[1] == Any[215.0, 50.0, 41.0]
  @test helpers[2] == Any[215.0, 50.0, 41.0]
  @test helpers[3][1] ≈ 218.974358974359
  @test helpers[3][2] ≈ 69.23076923076923
  @test helpers[3][3] ≈ 66.27450980392156
  @test helpers[4] == Any[52.0, 93.0, 169.0]
  @test helpers[5] == 0.0
  @test helpers[6] == 0.0
  @test helpers[7] == 32.9
  @test helpers[8] == Any[5.0, 15.0, 25.0, 35.0, 45.0, 55.0, 65.0, 75.0, 85.0, 95.0, 105.0, 115.0, 125.0, 135.0]

  call!(runtime, "do-valid-assignments")
  @test call!(runtime, "assigned-colors") == Any[
    Any[0.0, 255.0, 0.0],
    Any[255.0, 0.0, 0.0, 0.0],
    Any[10.0, 10.0, 10.0, 0.0],
    Any[255.0, 0.0, 0.0],
    15.0,
    Any[0.0, 0.0, 255.0, 0.0],
  ]

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-color-shape")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-color-range")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-extract-rgb")
  @test call!(runtime, "color-after-errors") == Any[
    Any[0.0, 255.0, 0.0],
    Any[10.0, 10.0, 10.0, 0.0],
  ]
end

@testset "unit: breed mutation and predicates" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]
  breed [frogs frog]
  undirected-link-breed [roads road]
  mice-own [mice-energy]
  frogs-own [frog-energy]
  globals [saved agent-flag turtle-flag patch-flag link-flag frog-flag road-flag]

  to setup
    clear-all
    create-mice 2 [ set mice-energy 10 + who ]
    ask mouse 0 [ create-road-with mouse 1 ]
    set saved turtle 0
    set agent-flag false
    set turtle-flag false
    set patch-flag false
    set link-flag false
    set frog-flag false
    set road-flag false
  end

  to switch-breed
    ask turtle 0 [ set shape "car" set breed frogs ]
  end

  to set-frog-energy
    ask frog 0 [ set frog-energy 7 ]
  end

  to classify
    set agent-flag is-agent? saved
    set turtle-flag is-turtle? saved
    set patch-flag is-patch? patch 0 0
    set link-flag is-link? one-of roads
    set frog-flag is-frog? saved
    set road-flag is-road? one-of roads
  end

  to kill-saved
    ask saved [ die ]
  end

  to-report frog-zero
    report frog 0
  end

  to-report mouse-zero
    report mouse 0
  end

  to-report missing-frog
    report word frog -1
  end

  to-report bad-frog-decimal
    report frog 0.1
  end

  to-report bad-turtle-decimal
    report turtle 0.1
  end

  to-report saved-frog?
    report is-frog? saved
  end
  """; seed=307)

  call!(runtime, "setup")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "frog-zero")
  @test call!(runtime, "missing-frog") == "nobody"
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-frog-decimal")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-turtle-decimal")

  call!(runtime, "switch-breed")
  @test runtime.world.turtles[1].breed == "FROGS"
  @test runtime.world.turtles[1].shape == "default"
  @test !haskey(runtime.world.turtles[1].own, "MICE-ENERGY")
  @test runtime.world.turtles[1].own["FROG-ENERGY"] == 0.0

  call!(runtime, "set-frog-energy")
  @test runtime.world.turtles[1].own["FROG-ENERGY"] == 7.0
  @test call!(runtime, "frog-zero") === runtime.world.turtles[1]
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "mouse-zero")

  call!(runtime, "classify")
  @test runtime.world.observer.globals["AGENT-FLAG"] == true
  @test runtime.world.observer.globals["TURTLE-FLAG"] == true
  @test runtime.world.observer.globals["PATCH-FLAG"] == true
  @test runtime.world.observer.globals["LINK-FLAG"] == true
  @test runtime.world.observer.globals["FROG-FLAG"] == true
  @test runtime.world.observer.globals["ROAD-FLAG"] == true

  call!(runtime, "kill-saved")
  @test call!(runtime, "saved-frog?") == false
end

@testset "unit: link lookup and directed predicates" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [roads road]
  globals [default-link directed-flag undirected-flag road-flag]

  to setup
    clear-all
    create-turtles 4
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-road-with turtle 2 ]
    ask turtle 2 [ create-directed-edge-to turtle 3 ]
    set default-link link 0 1
    set directed-flag is-directed-link? directed-edge 2 3
    set undirected-flag is-undirected-link? road 2 1
    set road-flag is-road? road 1 2
  end

  to-report missing-default
    report (word link 2 3)
  end

  to-report missing-directed
    report (word directed-edge 0 1)
  end

  to-report matching-road
    report road 2 1
  end

  to-report default-link?
    report is-link? link 0 1
  end
  """; seed=401)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["DEFAULT-LINK"] === runtime.world.links[1]
  @test runtime.world.observer.globals["DIRECTED-FLAG"] == true
  @test runtime.world.observer.globals["UNDIRECTED-FLAG"] == true
  @test runtime.world.observer.globals["ROAD-FLAG"] == true
  @test call!(runtime, "default-link?") == true
  @test call!(runtime, "missing-default") == "nobody"
  @test call!(runtime, "missing-directed") == "nobody"
  @test call!(runtime, "matching-road") === runtime.world.links[2]
end

@testset "unit: world topology and reset commands" begin
  runtime = create_runtime(netlogo"""
  globals [glob1 stale-patch]
  patches-own [mark]

  to seed-world
    clear-all
    set glob1 5
    ask patches [ set mark 3 set pcolor 139 set plabel "test" ]
    create-turtles 1 [ setxy 1 0 ]
    set stale-patch patch 1 1
  end

  to clear-observer-state
    clear-globals
    clear-patches
  end

  to set-torus
    set-topology true true
  end

  to set-box
    set-topology false false
  end

  to resize-small
    resize-world 0 0 0 0
  end

  to resize-decimal
    resize-world 0.5 10.5 (-0.5) 10.5
  end

  to repopulate
    create-turtles 2
  end

  to hard-clear
    reset-ticks
    tick
    __clear-all-and-reset-ticks
  end

  to-report wrapped-pcoords
    report [list pxcor pycor] of patch 2 0
  end

  to-report box-missing?
    report patch 2 0 = nobody
  end

  to-report torus-distance
    report [distancexy -1 0] of turtle 0
  end

  to-report box-distance
    report [distancexy -1 0] of turtle 0
  end

  to-report stale-patch-word
    report word stale-patch
  end

  to-report world-dimensions
    report (list world-width world-height min-pxcor max-pxcor min-pycor max-pycor)
  end

  to-report bad-resize
    resize-world 1 0 0 0
    report 0
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=509)

  call!(runtime, "seed-world")
  call!(runtime, "clear-observer-state")
  @test runtime.world.observer.globals["GLOB1"] == 0.0
  @test count(t -> t.alive, runtime.world.turtles) == 1
  @test all(patch -> patch.own["MARK"] == 0.0 && patch.pcolor == 0.0 && patch.plabel !== "test", runtime.world.patches)

  call!(runtime, "seed-world")
  call!(runtime, "set-torus")
  @test runtime.world.topology == Torus
  @test call!(runtime, "wrapped-pcoords") == Any[-1.0, 0.0]
  @test call!(runtime, "torus-distance") == 1.0

  call!(runtime, "set-box")
  @test runtime.world.topology == BoxTopology
  @test call!(runtime, "box-missing?") == true
  @test call!(runtime, "box-distance") == 2.0

  call!(runtime, "seed-world")
  call!(runtime, "resize-small")
  @test runtime.world.min_pxcor == 0
  @test runtime.world.max_pxcor == 0
  @test runtime.world.min_pycor == 0
  @test runtime.world.max_pycor == 0
  @test call!(runtime, "world-dimensions") == Any[1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
  @test count(t -> t.alive, runtime.world.turtles) == 0
  @test call!(runtime, "stale-patch-word") == "nobody"

  call!(runtime, "repopulate")
  @test [turtle.id for turtle in runtime.world.turtles] == [0, 1]

  call!(runtime, "resize-decimal")
  @test runtime.world.min_pxcor == 0
  @test runtime.world.max_pxcor == 10
  @test runtime.world.min_pycor == 0
  @test runtime.world.max_pycor == 10
  @test call!(runtime, "world-dimensions") == Any[11.0, 11.0, 0.0, 10.0, 0.0, 10.0]

  call!(runtime, "seed-world")
  call!(runtime, "hard-clear")
  @test runtime.world.ticks == 0.0
  @test runtime.world.observer.globals["GLOB1"] == 0.0
  @test count(t -> t.alive, runtime.world.turtles) == 0

  call!(runtime, "seed-world")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-resize")
end

@testset "unit: patch-size commands" begin
  runtime = create_runtime(netlogo"""
  globals [initial-size squared-size decimal-size]

  to setup
    clear-all
    set initial-size patch-size
  end

  to square-size-demo
    set-patch-size patch-size * patch-size
    set squared-size patch-size
  end

  to decimal-size-demo
    set-patch-size 5.2
    set decimal-size patch-size
  end

  to invalid-zero-demo
    set-patch-size 5
    set-patch-size 0
  end

  to invalid-negative-demo
    set-patch-size 5
    set-patch-size (-5)
  end
  """; seed=533)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["INITIAL-SIZE"] == 12.0

  call!(runtime, "square-size-demo")
  @test runtime.world.observer.globals["SQUARED-SIZE"] == 144.0
  @test runtime.world.patch_size == 144.0

  call!(runtime, "decimal-size-demo")
  @test runtime.world.observer.globals["DECIMAL-SIZE"] == 5.2
  @test runtime.world.patch_size == 5.2

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "invalid-zero-demo")
  @test runtime.world.patch_size == 5.0

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "invalid-negative-demo")
  @test runtime.world.patch_size == 5.0
end

@testset "unit: rng coordinate and normal reporters" begin
  runtime = create_runtime(netlogo"""
  globals [coord-extrema]

  to sample-coords
    random-seed 38923
    set coord-extrema (list
      min [random-pxcor] of patches
      max [random-pxcor] of patches
      min [round random-xcor] of patches
      max [round random-xcor] of patches
      min [random-pycor] of patches
      max [random-pycor] of patches
      min [round random-ycor] of patches
      max [round random-ycor] of patches)
  end

  to-report normal-triplet
    random-seed 17
    report n-values 3 [random-normal 10 1]
  end

  to-report normal-samples
    random-seed 17
    report n-values 4000 [random-normal 10 1]
  end

  to-report bad-normal
    report random-normal 10 -1
  end

  to-report bad-seed
    random-seed 2147483648
    report 0
  end
  """; min_pxcor=-2, max_pxcor=2, min_pycor=-3, max_pycor=3, seed=613)

  call!(runtime, "sample-coords")
  @test runtime.world.observer.globals["COORD-EXTREMA"] == Any[-2.0, 2.0, -2.0, 2.0, -3.0, 3.0, -3.0, 3.0]

  triplet1 = call!(runtime, "normal-triplet")
  triplet2 = call!(runtime, "normal-triplet")
  @test triplet1 == triplet2

  samples = call!(runtime, "normal-samples")
  mean_value = sum(samples) / length(samples)
  variance = sum((value - mean_value)^2 for value in samples) / length(samples)
  @test abs(mean_value - 10.0) < 0.1
  @test abs(sqrt(variance) - 1.0) < 0.1

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-normal")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-seed")
end

@testset "unit: no-wrap spatial reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  globals [
    wrapped-gap nowrap-gap wrapped-xy-gap nowrap-xy-gap
    wrapped-heading nowrap-heading wrapped-xy-heading nowrap-xy-heading
    wrapped-face nowrap-face wrapped-facexy nowrap-facexy
    wrapped-pack nowrap-pack wrapped-cone nowrap-cone
    wrapped-territory nowrap-territory
  ]

  to setup
    clear-all
    create-wolves 4 [ setxy 0 0 ]
    ask turtle 0 [ setxy 1 0 set heading 90 ]
    ask turtle 1 [ setxy -1 0 ]
    ask turtle 2 [ setxy 0 0 ]
    ask turtle 3 [ setxy 1 1 ]
    ask turtle 0 [
      set wrapped-gap distance turtle 1
      set nowrap-gap distance-nowrap turtle 1
      set wrapped-xy-gap distancexy -1 0
      set nowrap-xy-gap distancexy-nowrap -1 0
      set wrapped-heading towards turtle 1
      set nowrap-heading towards-nowrap turtle 1
      set wrapped-xy-heading towardsxy -1 0
      set nowrap-xy-heading towardsxy-nowrap -1 0
      set heading 0
      face turtle 1
      set wrapped-face heading
      set heading 0
      face-nowrap turtle 1
      set nowrap-face heading
      set heading 0
      facexy -1 0
      set wrapped-facexy heading
      set heading 0
      facexy-nowrap -1 0
      set nowrap-facexy heading
      set heading 90
      set wrapped-pack count wolves in-radius 1
      set nowrap-pack count wolves in-radius-nowrap 1
      set wrapped-cone count wolves in-cone 2.1 90
      set nowrap-cone count wolves in-cone-nowrap 2.1 90
    ]
    ask patch 1 0 [
      set wrapped-territory count patches in-radius 1
      set nowrap-territory count patches in-radius-nowrap 1
    ]
  end

  to-report bad-nowrap-radius
    report [count wolves in-radius-nowrap -1] of turtle 0
  end

  to-report bad-nowrap-angle
    report [count wolves in-cone-nowrap 2 361] of turtle 0
  end

  to-report same-point-nowrap
    report [towards-nowrap turtle 0] of turtle 0
  end

  to bad-face-nowrap
    clear-all
    cro 2 [ fd 1 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask link 0 1 [ face-nowrap turtle 0 ]
  end

  to bad-facexy-nowrap
    clear-all
    cro 2 [ fd 1 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask link 0 1 [ facexy-nowrap 0 1 ]
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=53)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["WRAPPED-GAP"] == 1.0
  @test runtime.world.observer.globals["NOWRAP-GAP"] == 2.0
  @test runtime.world.observer.globals["WRAPPED-XY-GAP"] == 1.0
  @test runtime.world.observer.globals["NOWRAP-XY-GAP"] == 2.0
  @test runtime.world.observer.globals["WRAPPED-HEADING"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-HEADING"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-XY-HEADING"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-XY-HEADING"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-FACE"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-FACE"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-FACEXY"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-FACEXY"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-PACK"] == 4.0
  @test runtime.world.observer.globals["NOWRAP-PACK"] == 3.0
  @test runtime.world.observer.globals["WRAPPED-CONE"] == 2.0
  @test runtime.world.observer.globals["NOWRAP-CONE"] == 1.0
  @test runtime.world.observer.globals["WRAPPED-TERRITORY"] == 5.0
  @test runtime.world.observer.globals["NOWRAP-TERRITORY"] == 4.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-nowrap-radius")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-nowrap-angle")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "same-point-nowrap")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-face-nowrap")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-facexy-nowrap")
end

@testset "unit: selector expansion reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy tag]

  to setup
    clear-all
    create-wolves 4 [
      set energy item who [1 2 4 5]
      set tag item who ["a" "b" "c" "d"]
      setxy 0 0
    ]
  end

  to-report weakest-count
    report count min-n-of 2 wolves [energy]
  end

  to-report strongest-whos
    report sort [who] of max-n-of 2 wolves [energy]
  end

  to-report nonnumeric-count
    report count min-n-of 1 wolves [tag]
  end

  to-report oversize-demo
    report count max-n-of 5 wolves [energy]
  end
  """; seed=41)

  call!(runtime, "setup")

  @test call!(runtime, "weakest-count") == 2.0
  @test call!(runtime, "strongest-whos") == Any[2.0, 3.0]
  @test call!(runtime, "nonnumeric-count") == 0.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "oversize-demo")
end

@testset "unit: statistical reporters" begin
  runtime = create_runtime(netlogo"""
  to-report variance-demo
    report variance [2 7 4 3 5]
  end

  to-report standard-deviation-demo
    report standard-deviation [1 2 3 4 5 6]
  end

  to-report ignored-items-demo
    report variance [2 "skip" 4]
  end

  to-report empty-variance-demo
    report variance []
  end

  to-report singleton-standard-deviation-demo
    report standard-deviation [5]
  end

  to-report precision-demo
    report (list (precision 1.23456789 3) (precision 3834 (-3)) (precision 2175 (-2)) (precision 2144 (-2)))
  end
  """; seed=107)

  @test call!(runtime, "variance-demo") == 3.7
  @test call!(runtime, "standard-deviation-demo") ≈ 1.8708286933869707
  @test call!(runtime, "ignored-items-demo") == 2.0
  empty_variance_error = try
    call!(runtime, "empty-variance-demo")
    nothing
  catch err
    err
  end
  @test empty_variance_error isa NetLogo.LogoRuntimeError
  @test empty_variance_error.message == "Can't find the variance of a list without at least two numbers: []."

  singleton_standard_deviation_error = try
    call!(runtime, "singleton-standard-deviation-demo")
    nothing
  catch err
    err
  end
  @test singleton_standard_deviation_error isa NetLogo.LogoRuntimeError
  @test singleton_standard_deviation_error.message == "Can't find the standard deviation of a list without at least two numbers: [5]"
  @test call!(runtime, "precision-demo") == Any[1.235, 4000.0, 2200.0, 2100.0]
end

@testset "unit: link identity reporters" begin
  generic_runtime = create_runtime(netlogo"""
  to setup
    clear-all
    crt 2 [ setxy who 0 ]
    ask turtle 0 [
      create-link-with turtle 1
      create-link-to turtle 1
    ]
  end

  to-report link-choice-count
    report length remove-duplicates [ n-values 50 [ link-with turtle 1 ] ] of turtle 0
  end

  to-report source-out-count
    report count [my-out-links] of turtle 0
  end

  to-report source-in-count
    report count [my-in-links] of turtle 0
  end

  to-report dest-out-count
    report count [my-out-links] of turtle 1
  end

  to-report dest-in-count
    report count [my-in-links] of turtle 1
  end

  to-report source-out-neighbor?
    report [out-link-neighbor? turtle 1] of turtle 0
  end

  to-report source-in-neighbor?
    report [in-link-neighbor? turtle 1] of turtle 0
  end
  """; seed=131)

  directed_runtime = create_runtime(netlogo"""
  to setup
    clear-all
    crt 2 [ setxy who 0 ]
    ask turtle 0 [ create-link-to turtle 1 ]
  end

  to-report directed-generic?
    report is-directed-link? [out-link-to turtle 1] of turtle 0
  end
  """; seed=137)

  breed_runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]
  globals [directed-out-breed-val directed-in-breed-val undirected-with-breed-val]

  to setup
    clear-all
    crt 2 [ setxy who 0 ]
    ask turtle 0 [
      create-directed-edge-to turtle 1
      create-undirected-edge-with turtle 1
    ]
    ask turtle 0 [
      set directed-out-breed-val [breed] of out-directed-edge-to turtle 1
      set undirected-with-breed-val [breed] of undirected-edge-with turtle 1
    ]
    ask turtle 1 [
      set directed-in-breed-val [breed] of in-directed-edge-from turtle 0
    ]
  end

  to-report breed-link-choice-count
    report length remove-duplicates [ n-values 50 [ link-with turtle 1 ] ] of turtle 0
  end
  """; seed=139)

  call!(generic_runtime, "setup")
  call!(directed_runtime, "setup")
  call!(breed_runtime, "setup")

  @test call!(generic_runtime, "link-choice-count") == 2.0
  @test call!(generic_runtime, "source-out-count") == 2.0
  @test call!(generic_runtime, "source-in-count") == 1.0
  @test call!(generic_runtime, "dest-out-count") == 1.0
  @test call!(generic_runtime, "dest-in-count") == 2.0
  @test call!(generic_runtime, "source-out-neighbor?") == true
  @test call!(generic_runtime, "source-in-neighbor?") == true
  @test call!(directed_runtime, "directed-generic?") == true
  @test breed_runtime.world.observer.globals["DIRECTED-OUT-BREED-VAL"] isa NetLogo.AgentSet
  @test breed_runtime.world.observer.globals["DIRECTED-OUT-BREED-VAL"].breed == "DIRECTED-EDGES"
  @test breed_runtime.world.observer.globals["DIRECTED-IN-BREED-VAL"] isa NetLogo.AgentSet
  @test breed_runtime.world.observer.globals["DIRECTED-IN-BREED-VAL"].breed == "DIRECTED-EDGES"
  @test breed_runtime.world.observer.globals["UNDIRECTED-WITH-BREED-VAL"] isa NetLogo.AgentSet
  @test breed_runtime.world.observer.globals["UNDIRECTED-WITH-BREED-VAL"].breed == "UNDIRECTED-EDGES"
  @test call!(breed_runtime, "breed-link-choice-count") == 2.0
end

@testset "unit: clear-links command" begin
  runtime = create_runtime(netlogo"""
  to seed-many-links
    clear-all
    crt 4
    ask turtle 0 [ create-links-with other turtles ]
  end

  to clear-demo
    clear-links
  end

  to-report source-neighbor-count
    report count [link-neighbors] of turtle 0
  end

  to-report source-my-link-count
    report count [my-links] of turtle 0
  end

  to seed-radius-links
    clear-all
    ask patch 0 0 [ sprout 3 ]
    ask turtle 0 [ create-link-with turtle 2 ]
  end

  to relink-after-clear
    clear-links
    ask turtle 0 [ create-link-to turtle 1 ]
  end

  to-report generic-radius-counts
    let ordered sort turtles
    report map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (link-neighbor? myself)]] of target))] ordered
  end

  to-report out-radius-counts
    let ordered sort turtles
    report map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (out-link-neighbor? myself)]] of target))] ordered
  end

  to-report in-radius-counts
    let ordered sort turtles
    report map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (in-link-neighbor? myself)]] of target))] ordered
  end
  """; seed=211)

  call!(runtime, "seed-many-links")
  @test length(runtime.world.links) == 3

  call!(runtime, "clear-demo")
  @test isempty(runtime.world.links)
  @test call!(runtime, "source-neighbor-count") == 0.0
  @test call!(runtime, "source-my-link-count") == 0.0

  call!(runtime, "seed-radius-links")
  @test call!(runtime, "generic-radius-counts") == Any[Any[0.0, 2.0], Any[1.0, 3.0], Any[2.0, 2.0]]

  call!(runtime, "relink-after-clear")
  @test length(runtime.world.links) == 1
  @test call!(runtime, "generic-radius-counts") == Any[Any[0.0, 2.0], Any[1.0, 2.0], Any[2.0, 3.0]]
  @test call!(runtime, "out-radius-counts") == Any[Any[0.0, 3.0], Any[1.0, 2.0], Any[2.0, 3.0]]
  @test call!(runtime, "in-radius-counts") == Any[Any[0.0, 2.0], Any[1.0, 3.0], Any[2.0, 3.0]]
end

@testset "unit: RNG distribution reporters" begin
  runtime = create_runtime(netlogo"""
  globals [exp-mean gamma-mean gamma-variance poisson-mean]

  to setup
    clear-all
    random-seed 2025
    let exp-draws n-values 20000 [random-exponential 2]
    set exp-mean mean exp-draws
    random-seed 2722
    let gamma-draws n-values 50000 [random-gamma 50 5]
    set gamma-mean mean gamma-draws
    set gamma-variance variance gamma-draws
    random-seed 3031
    let poisson-draws n-values 20000 [random-poisson 3.4]
    set poisson-mean mean poisson-draws
  end

  to-report poisson-sample-demo
    random-seed 4041
    report n-values 25 [random-poisson 3.4]
  end

  to-report gamma-error-demo
    report random-gamma 0 1
  end

  to-report poisson-error-demo
    report random-poisson (-1)
  end
  """; seed=157)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["EXP-MEAN"] ≈ 2.0 atol=0.08
  @test runtime.world.observer.globals["GAMMA-MEAN"] ≈ 10.0 atol=0.08
  @test runtime.world.observer.globals["GAMMA-VARIANCE"] ≈ 2.0 atol=0.05
  @test runtime.world.observer.globals["POISSON-MEAN"] ≈ 3.4 atol=0.08
  poisson_samples = call!(runtime, "poisson-sample-demo")
  @test all(value -> value >= 0 && value == floor(value), poisson_samples)
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "gamma-error-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "poisson-error-demo")
end

@testset "unit: shuffle and sampling helpers" begin
  runtime = create_runtime(netlogo"""
  globals [counter]

  to setup
    clear-all
    set counter 0
  end

  to-report foo
    set counter counter + 1
    report (list counter counter counter)
  end

  to-report shuffle-demo
    random-seed 2782
    report shuffle [1 2 3 4 5]
  end

  to-report shuffle-empty-demo
    report shuffle []
  end

  to-report shuffle-preserves-original-demo
    let xs [1 2 3 4 5]
    let ys shuffle xs
    report (list xs ys)
  end

  to-report one-of-evaluates-once-demo
    report (list (one-of foo) (one-of foo))
  end

  to-report one-of-empty-demo
    report one-of []
  end

  to-report n-of-negative-demo
    report n-of -1 [1 2 3]
  end

  to-report n-of-oversize-demo
    report n-of 1 []
  end

  to-report n-of-rounded-lengths-demo
    random-seed 27892
    let a n-of 2.2 [1 2 3]
    random-seed 27892
    let b n-of 2.5 [1 2 3]
    random-seed 27892
    let c n-of 2.7 [1 2 3]
    report (list (length a) (length b) (length c))
  end
  """; seed=167)

  call!(runtime, "setup")

  shuffled1 = call!(runtime, "shuffle-demo")
  shuffled2 = call!(runtime, "shuffle-demo")
  @test shuffled1 == shuffled2
  @test sort(shuffled1) == Any[1.0, 2.0, 3.0, 4.0, 5.0]
  @test call!(runtime, "shuffle-empty-demo") == Any[]
  preserved = call!(runtime, "shuffle-preserves-original-demo")
  @test preserved[1] == Any[1.0, 2.0, 3.0, 4.0, 5.0]
  @test sort(preserved[2]) == Any[1.0, 2.0, 3.0, 4.0, 5.0]
  @test call!(runtime, "one-of-evaluates-once-demo") == Any[1.0, 2.0]
  @test call!(runtime, "n-of-rounded-lengths-demo") == Any[2.0, 2.0, 2.0]
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "one-of-empty-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "n-of-negative-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "n-of-oversize-demo")
end

@testset "unit: tick and timer controls" begin
  runtime = create_runtime(netlogo"""
  to start-ticks
    reset-ticks
  end

  to stop-ticks
    clear-ticks
  end

  to do-tick
    tick
  end

  to advance-ticks [amount]
    tick-advance amount
  end

  to reset-the-timer
    reset-timer
  end

  to-report current-ticks-demo
    report ticks
  end

  to-report current-timer-demo
    report timer
  end
  """; seed=179)

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "current-ticks-demo")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "do-tick")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "advance-ticks", 0.1)

  call!(runtime, "start-ticks")
  @test call!(runtime, "current-ticks-demo") == 0.0
  call!(runtime, "do-tick")
  @test call!(runtime, "current-ticks-demo") == 1.0
  call!(runtime, "advance-ticks", 0.1)
  @test call!(runtime, "current-ticks-demo") == 1.1
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "advance-ticks", -0.1)
  call!(runtime, "stop-ticks")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "current-ticks-demo")

  @test call!(runtime, "current-timer-demo") >= 0.0
  call!(runtime, "reset-the-timer")
  sleep(0.05)
  @test call!(runtime, "current-timer-demo") >= 0.02
end

@testset "unit: dead agent control semantics" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]
  globals [dead-ref dead-message dist-message towards-message nested-flag hatch-flag]

  to setup
    clear-all
    set dead-ref nobody
    set dead-message ""
    set dist-message ""
    set towards-message ""
    create-mice 1 [ set dead-ref self die ]
    create-turtles 1 [ setxy 1 0 ]
  end

  to read-dead-color
    carefully [ set dead-message [color] of dead-ref ] [ set dead-message error-message ]
  end

  to read-dead-distance
    ask turtle 1 [ carefully [ __ignore distance dead-ref ] [ set dist-message error-message ] ]
  end

  to read-dead-towards
    ask turtle 1 [ carefully [ __ignore towards dead-ref ] [ set towards-message error-message ] ]
  end

  to inspect-dead
    inspect dead-ref
  end

  to ask-dead
    ask dead-ref [ set color red ]
  end

  to nested-death
    clear-all
    set nested-flag 0
    create-turtles 2
    ask turtle 0 [ ask turtle 1 [ ask turtle 0 [ die ] ] set nested-flag 5 ]
  end

  to hatch-parent-death
    clear-all
    set hatch-flag 0
    create-turtles 1
    ask turtle 0 [ hatch 1 [ ask myself [ die ] ] set hatch-flag 5 ]
  end

  to-report fail-via-ask
    ask turtle 0 [ die ]
    report 5
  end

  to-report fail-direct
    die
    report 5
  end

  to call-fail-via-ask
    clear-all
    create-turtles 1
    ask turtle 0 [ set dead-message fail-via-ask ]
  end

  to call-fail-direct
    clear-all
    create-turtles 1
    ask turtle 0 [ set dead-message fail-direct ]
  end
  """; seed=183)

  call!(runtime, "setup")
  call!(runtime, "read-dead-color")
  call!(runtime, "read-dead-distance")
  call!(runtime, "read-dead-towards")
  @test runtime.world.observer.globals["DEAD-MESSAGE"] == "That mouse is dead."
  @test runtime.world.observer.globals["DIST-MESSAGE"] == "That mouse is dead."
  @test runtime.world.observer.globals["TOWARDS-MESSAGE"] == "That mouse is dead."

  inspect_error = try
    call!(runtime, "inspect-dead")
    nothing
  catch err
    err
  end
  @test inspect_error isa NetLogo.LogoRuntimeError
  @test inspect_error.message == "That mouse is dead."

  ask_error = try
    call!(runtime, "ask-dead")
    nothing
  catch err
    err
  end
  @test ask_error isa NetLogo.LogoRuntimeError
  @test ask_error.message == "That mouse is dead."

  call!(runtime, "nested-death")
  @test runtime.world.observer.globals["NESTED-FLAG"] == 0

  call!(runtime, "hatch-parent-death")
  @test runtime.world.observer.globals["HATCH-FLAG"] == 0

  fail_via_ask_error = try
    call!(runtime, "call-fail-via-ask")
    nothing
  catch err
    err
  end
  @test fail_via_ask_error isa NetLogo.LogoRuntimeError
  @test fail_via_ask_error.message == "the FAIL-VIA-ASK procedure failed to report a result"

  fail_direct_error = try
    call!(runtime, "call-fail-direct")
    nothing
  catch err
    err
  end
  @test fail_direct_error isa NetLogo.LogoRuntimeError
  @test fail_direct_error.message == "the FAIL-DIRECT procedure failed to report a result"
end

@testset "unit: comparison operators" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]
  undirected-link-breed [undirected-edges2 undirected-edge2]
  directed-link-breed [directed-edges2 directed-edge2]
  globals [patch-ref]

  to setup
    clear-all
    create-turtles 3 [ setxy who 0 ]
    ask turtle 0 [ create-directed-edges-to other turtles ]
    ask turtle 1 [ create-directed-edges-to other turtles ]
    ask turtle 0 [ create-undirected-edges-with other turtles ]
    ask turtle 0 [ create-directed-edges2-to other turtles ]
    ask turtle 0 [ create-undirected-edges2-with other turtles ]
    set patch-ref [patch-here] of turtle 0
  end

  to-report string-order
    report (list ("cow" < "moo") ("moo" < "cow") ("moo" >= "cow") ("cow" <= "cow"))
  end

  to-report turtle-order
    report (list (turtle 0 < turtle 1) (turtle 0 <= turtle 1) (turtle 0 > turtle 1) (turtle 0 >= turtle 0))
  end

  to-report patch-order
    report (list (patch 0 0 > patch 0 1) (patch 0 0 < patch 1 0) (patch 0 0 <= patch 0 0))
  end

  to-report link-flag-1
    let left-link directed-edge 1 0
    let right-link directed-edge 0 1
    report left-link > right-link
  end

  to-report link-flag-2
    let left-link undirected-edge 0 1
    let right-link directed-edge 0 1
    report left-link > right-link
  end

  to-report link-flag-3
    let left-link directed-edge2 0 1
    let right-link undirected-edge2 0 1
    report left-link > right-link
  end

  to-report link-flag-4
    let left-link undirected-edge2 0 1
    let right-link undirected-edge 0 1
    report left-link > right-link
  end

  to-report link-flag-5
    let left-link directed-edge2 0 1
    let right-link directed-edge 0 1
    report left-link > right-link
  end

  to-report link-order
    report (list link-flag-1 link-flag-2 link-flag-3 link-flag-4 link-flag-5)
  end

  to-report mixed-compare
    report patch-ref < turtle 0
  end

  to-report mixed-link-compare
    report patch-ref <= undirected-edge 0 1
  end

  to-report link-kind [link-agent]
    if is-directed-edge? link-agent [ report "DE1" ]
    if is-undirected-edge? link-agent [ report "UE1" ]
    if is-undirected-edge2? link-agent [ report "UE2" ]
    report "DE2"
  end

  to-report sorted-link-kinds
    report map link-kind (sort links)
  end
  """; seed=211)

  call!(runtime, "setup")

  @test call!(runtime, "string-order") == Any[true, false, true, true]
  @test call!(runtime, "turtle-order") == Any[true, true, false, true]
  @test call!(runtime, "patch-order") == Any[true, true, true]
  @test call!(runtime, "link-order") == Any[true, true, true, true, true]
  @test call!(runtime, "sorted-link-kinds") == Any["DE1", "DE1", "DE1", "DE1", "UE1", "UE1", "UE2", "UE2", "DE2", "DE2"]

  mixed_error = try
    call!(runtime, "mixed-compare")
    nothing
  catch err
    err
  end
  @test mixed_error isa NetLogo.LogoRuntimeError
  @test mixed_error.message == "The < operator can only be used on two numbers, two strings, or two agents of the same type, but not on a patch and a turtle."

  mixed_link_error = try
    call!(runtime, "mixed-link-compare")
    nothing
  catch err
    err
  end
  @test mixed_link_error isa NetLogo.LogoRuntimeError
  @test mixed_link_error.message == "The <= operator can only be used on two numbers, two strings, or two agents of the same type, but not on a patch and a link."
end

@testset "unit: general type predicates" begin
  runtime = create_runtime(netlogo"""
  globals [cmd-task rep-task nested-total]

  to setup
    clear-all
    set nested-total 0
    set cmd-task [ -> set nested-total 5 ]
    set rep-task [ x -> x + 1 ]
  end

  to-report scalar-flag-1
    report is-boolean? true
  end

  to-report scalar-flag-2
    report is-boolean? false
  end

  to-report scalar-flag-3
    report is-boolean? 3
  end

  to-report scalar-flag-4
    report is-number? 3
  end

  to-report scalar-flag-5
    report is-number? true
  end

  to-report scalar-flag-6
    report is-number? "foo"
  end

  to-report scalar-flag-7
    report is-list? []
  end

  to-report scalar-flag-8
    report is-list? [1 2]
  end

  to-report scalar-flag-9
    report is-list? "foo"
  end

  to-report scalar-predicates
    report (list scalar-flag-1 scalar-flag-2 scalar-flag-3 scalar-flag-4 scalar-flag-5 scalar-flag-6 scalar-flag-7 scalar-flag-8 scalar-flag-9)
  end

  to-report task-flag-1
    report is-anonymous-command? cmd-task
  end

  to-report task-flag-2
    report is-anonymous-command? [ -> 5 ]
  end

  to-report task-flag-3
    report is-anonymous-reporter? rep-task
  end

  to-report task-flag-4
    report is-anonymous-reporter? [ -> 5 ]
  end

  to-report task-flag-5
    report is-command-task? cmd-task
  end

  to-report task-flag-6
    report is-reporter-task? rep-task
  end

  to-report task-flag-7
    report is-anonymous-reporter? cmd-task
  end

  to-report task-flag-8
    report is-anonymous-command? rep-task
  end

  to-report task-predicates
    report (list task-flag-1 task-flag-2 task-flag-3 task-flag-4 task-flag-5 task-flag-6 task-flag-7 task-flag-8)
  end

  to-report list-shape-demo
    report map is-list? [1 [2] "skip" false]
  end
  """; seed=227)

  call!(runtime, "setup")

  @test call!(runtime, "scalar-predicates") == Any[true, true, false, true, false, false, true, true, false]
  @test call!(runtime, "task-predicates") == Any[true, false, true, true, true, true, false, false]
  @test call!(runtime, "list-shape-demo") == Any[false, true, false, false]
end

@testset "unit: boolean reporters" begin
  runtime = create_runtime(netlogo"""
  to-report boom
    error "boom!"
  end

  to-report and-table
    report (list (true and true) (true and false) (false and true) (false and false))
  end

  to-report or-table
    report (list (true or true) (true or false) (false or true) (false or false))
  end

  to-report xor-table
    report (list (true xor true) (true xor false) (false xor true) (false xor false))
  end

  to-report not-table
    report (list (not true) (not false))
  end

  to-report false-and-boom
    report false and boom
  end

  to-report true-or-boom
    report true or boom
  end

  to-report true-xor-boom
    report true xor boom
  end

  to-report boolean-precedence
    report true or false and false
  end
  """; seed=243)

  @test call!(runtime, "and-table") == Any[true, false, false, false]
  @test call!(runtime, "or-table") == Any[true, true, true, false]
  @test call!(runtime, "xor-table") == Any[false, true, true, false]
  @test call!(runtime, "not-table") == Any[false, true]
  @test call!(runtime, "false-and-boom") == false
  @test call!(runtime, "true-or-boom") == true
  xor_error = try
    call!(runtime, "true-xor-boom")
    nothing
  catch err
    err
  end
  @test xor_error isa NetLogo.LogoRuntimeError
  @test xor_error.message == "boom!"
  @test call!(runtime, "boolean-precedence") == false
end

@testset "unit: agent identity and introspection" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]

  to setup
    clear-all
    crt 2 [ setxy who 0 ]
    create-mice 2 [ setxy 0 0 ]
  end

  to-report self-demo
    report count turtles with [self = turtle who]
  end

  to-report carefully-myself
    let result -1
    carefully [ set result myself ] [ ]
    report result
  end

  to-report observer-of-myself-demo
    report [carefully-myself] of turtle 0
  end

  to-report nested-carefully-myself
    let result -1
    ask turtle 1 [ carefully [ set result myself ] [ ] ]
    report [who] of result
  end

  to-report nested-carefully-myself-demo
    report [nested-carefully-myself] of turtle 0
  end

  to-report inner-myself-who
    report [who] of myself
  end

  to-report inner-of-myself
    report [inner-myself-who] of turtle 1
  end

  to-report nested-of-myself-demo
    report [inner-of-myself] of turtle 0
  end

  to-report selfish-self
    carefully [ ask other turtles [ error "Derp" ] ] [ ]
    report who
  end

  to-report selfish-self-demo
    report [selfish-self] of turtle 0
  end

  to-report who-are-not-counts
    let picked one-of mice
    let remaining mice who-are-not picked
    let non-mice count (turtles who-are-not mice)
    let no-mice count (mice who-are-not turtles)
    let outer-patches count (patches who-are-not patches with [pxcor = 0])
    let remaining-count count remaining
    let contains-picked member? picked remaining
    report (list non-mice no-mice outer-patches remaining-count contains-picked)
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=231)

  call!(runtime, "setup")

  @test call!(runtime, "self-demo") == 4.0
  @test call!(runtime, "observer-of-myself-demo") == -1.0
  @test call!(runtime, "nested-carefully-myself-demo") == 0.0
  @test call!(runtime, "nested-of-myself-demo") == 0.0
  @test call!(runtime, "selfish-self-demo") == 0.0
  @test call!(runtime, "who-are-not-counts") == Any[2.0, 0.0, 6.0, 1.0, false]
end

@testset "unit: all reporter" begin
  runtime = create_runtime(netlogo"""
  to setup
    clear-all
    ask patches [ set plabel true ]
    crt 1 [ setxy 0 0 ]
  end

  to-report empty-all
    report all? no-turtles [false]
  end

  to-report turtles-all-false
    report all? turtles [false]
  end

  to-report patch-self-match
    report all? patches [patch-at 0 0 = self]
  end

  to-report patch-origin-match
    report all? patches [patch 0 0 = self]
  end

  to-report patch-labels-all
    report all? patches [plabel]
  end

  to-report patch-labels-error
    ask patch -4 3 [ set plabel 5 ]
    report all? patches [plabel]
  end

  to-report patch-labels-short-circuit
    ask patches [ set plabel false ]
    ask patch -4 3 [ set plabel 5 ]
    report all? patches [false]
  end
  """; min_pxcor=-4, max_pxcor=4, min_pycor=-4, max_pycor=4, topology=BoxTopology, seed=239)

  call!(runtime, "setup")

  @test call!(runtime, "empty-all") == true
  @test call!(runtime, "turtles-all-false") == false
  @test call!(runtime, "patch-self-match") == true
  @test call!(runtime, "patch-origin-match") == false
  @test call!(runtime, "patch-labels-all") == true
  patch_label_error = try
    call!(runtime, "patch-labels-error")
    nothing
  catch err
    err
  end
  @test patch_label_error isa NetLogo.LogoRuntimeError
  @test patch_label_error.message == "ALL? expected a true/false value from (patch -4 3), but got 5 instead."
  @test call!(runtime, "patch-labels-short-circuit") == false
end

@testset "unit: reference reporter" begin
  runtime = create_runtime(netlogo"""
  globals [foo bar]
  turtles-own [foos]
  patches-own [foos]

  to setup
    clear-all
    crt 1 [ setxy 0 0 ]
  end

  to-report patch-references
    report [ (list __reference pxcor __reference pycor __reference pcolor __reference foos) ] of patch 0 0
  end

  to-report turtle-references
    report [ (list __reference xcor __reference ycor __reference foos) ] of turtle 0
  end

  to-report observer-references
    report (list __reference foo __reference bar)
  end

  to-report bad-reference-syntax
    report __check-syntax "show __reference not-a-var"
  end
  """; seed=232)

  call!(runtime, "setup")

  @test call!(runtime, "patch-references") == Any[
    Any["PATCH", 0.0, "PXCOR"],
    Any["PATCH", 1.0, "PYCOR"],
    Any["PATCH", 2.0, "PCOLOR"],
    Any["PATCH", 5.0, "FOOS"],
  ]
  @test call!(runtime, "turtle-references") == Any[
    Any["TURTLE", 3.0, "XCOR"],
    Any["TURTLE", 4.0, "YCOR"],
    Any["TURTLE", 13.0, "FOOS"],
  ]
  @test call!(runtime, "observer-references") == Any[
    Any["OBSERVER", 0.0, "FOO"],
    Any["OBSERVER", 1.0, "BAR"],
  ]
  @test call!(runtime, "bad-reference-syntax") == "Nothing named NOT-A-VAR has been defined."
end

@testset "unit: task stringification" begin
  runtime = create_runtime(netlogo"""
  globals [cmd-task rep-task]

  to setup
    clear-all
    set cmd-task [ -> set cmd-task 5 ]
    set rep-task [ x -> x + 1 ]
  end

  to-report command-string
    report word cmd-task
  end

  to-report reporter-string
    report word rep-task
  end
  """; seed=233)

  call!(runtime, "setup")

  @test call!(runtime, "command-string") == "(anonymous command: [ -> set cmd-task 5 ])"
  @test call!(runtime, "reporter-string") == "(anonymous reporter: [ x -> x + 1 ])"
end

@testset "unit: apply-result and codeblock helpers" begin
  runtime = create_runtime(netlogo"""
  to-report apply-power
    report __apply-result [ [x y] -> x ^ y ] [3 2]
  end

  to-report apply-empty
    report __apply-result [ 5 ] []
  end

  to-report apply-word
    report __apply-result word ["str1" "str2" "str3"]
  end

  to-report apply-command
    clear-all
    __apply [ [num col] -> crt num [ set color col ] ] [10 5]
    report list count turtles [color] of turtle 0
  end

  to-report apply-command-empty
    clear-all
    __apply [ crt 1 ] []
    report count turtles
  end

  to-report symbol-values
    report (list (__symbol what-is-this) (__symbol xcor) (__symbol turtles) (__symbol turtle))
  end

  to-report block-values
    report (list (__block [ crt some-stuff ]) (__block [ crt [ setxy foo bar ] ]) (__block [ [foo] -> foo ]))
  end

  to-report apply-arity-one
    report __apply-result [ [num col] -> num * col ] [10]
  end

  to-report apply-arity-two
    report __apply-result [ [num] -> num ] []
  end

  to apply-command-arity-one
    __apply [ [num col] -> crt num [ set color col ] ] [10]
  end

  to apply-command-arity-two
    __apply [ [num] -> crt num ] []
  end
  """; seed=257)

  @test call!(runtime, "apply-power") == 9.0
  @test call!(runtime, "apply-empty") == 5.0
  @test call!(runtime, "apply-word") == "str1str2str3"
  @test call!(runtime, "apply-command") == Any[10.0, 5.0]
  @test call!(runtime, "apply-command-empty") == 1.0
  @test call!(runtime, "symbol-values") == Any["what-is-this", "xcor", "turtles", "turtle"]
  @test call!(runtime, "block-values") == Any["crt some-stuff", "crt [ setxy foo bar ]", "[ foo ] -> foo"]

  arity_one_error = try
    call!(runtime, "apply-arity-one")
    nothing
  catch err
    err
  end
  @test arity_one_error isa NetLogo.LogoRuntimeError
  @test arity_one_error.message == "anonymous procedure expected 2 inputs, but only got 1"

  arity_two_error = try
    call!(runtime, "apply-arity-two")
    nothing
  catch err
    err
  end
  @test arity_two_error isa NetLogo.LogoRuntimeError
  @test arity_two_error.message == "anonymous procedure expected 1 input, but only got 0"

  command_arity_one_error = try
    call!(runtime, "apply-command-arity-one")
    nothing
  catch err
    err
  end
  @test command_arity_one_error isa NetLogo.LogoRuntimeError
  @test command_arity_one_error.message == "anonymous procedure expected 2 inputs, but only got 1"

  command_arity_two_error = try
    call!(runtime, "apply-command-arity-two")
    nothing
  catch err
    err
  end
  @test command_arity_two_error isa NetLogo.LogoRuntimeError
  @test command_arity_two_error.message == "anonymous procedure expected 1 input, but only got 0"
end

@testset "unit: task kind mismatch handling" begin
  runtime = create_runtime(netlogo"""
  globals [runresult-error run-error foreach-error]

  to setup
    clear-all
    set runresult-error ""
    set run-error ""
    set foreach-error ""
    carefully [ __ignore runresult [ -> __ignore 5 ] ] [ set runresult-error error-message ]
    carefully [ run [ -> 5 ] ] [ set run-error error-message ]
    carefully [ foreach [1 2 3] [ x -> x + 1 ] ] [ set foreach-error error-message ]
  end

  to-report task-kind-errors
    report (list runresult-error run-error foreach-error)
  end
  """; seed=241)

  call!(runtime, "setup")

  @test call!(runtime, "task-kind-errors") == Any[
    "RUNRESULT expected this input to be a string or anonymous reporter, but got an anonymous command instead",
    "RUN expected this input to be a string or anonymous command, but got an anonymous reporter instead",
    "FOREACH expected this input to be an anonymous command, but got an anonymous reporter instead",
  ]
end

@testset "unit: string run runtime" begin
  runtime = create_runtime(netlogo"""
  globals [check counter message]
  turtles-own [turtle-var]

  to setup
    clear-all
    set check 0
    set counter 0
    set message ""
    crt 1 [ set turtle-var 600000 ]
  end

  to run-basic
    run "set check count turtles"
  end

  to-report runresult-basic
    report (list (runresult "3") (runresult "1 + 2") (runresult "1; + 2"))
  end

  to-report make-run-string
    set counter counter + 1
    report (word "set check " counter)
  end

  to-report run-once
    set counter 0
    run (make-run-string)
    report (list check counter)
  end

  to-report make-bare-run-source
    set counter counter + 1
    report "set check counter"
  end

  to run-from-bare-reporter
    set check 0
    set counter 0
    run make-bare-run-source
  end

  to-report bare-run-state
    report (list check counter)
  end

  to-report make-bare-runresult-source
    set counter counter + 1
    report "count turtles + counter"
  end

  to-report runresult-from-bare-reporter
    set counter 0
    report (list (runresult make-bare-runresult-source) counter)
  end

  to-report local-isolation
    let s 0
    run "set s -1"
    report s
  end

  to-report read-procedure-locals [proc-arg]
    let proc-let 20
    report runresult "proc-arg + proc-let"
  end

  to scope-error-demo [proc-arg]
    let proc-let 20
    ask turtle 0 [
      let ask-let 300
      carefully [ run "set check ask-let + turtle-var" ] [ set message error-message ]
      run "set check proc-arg + proc-let + turtle-var"
    ]
  end

  to-report scope-message
    report message
  end

  to-report scope-value
    report check
  end

  to-report duplicate-let-demo
    set message ""
    carefully [ run "let a 2 run \\\"let a 3\\\"" ] [ set message error-message ]
    report message
  end

  to stop-demo
    set check 0
    run "stop set check 10"
    set check 5
  end

  to-report extra-arg-errors
    let run-error ""
    let runresult-error ""
    carefully [ run "__ignore 5" 1 ] [ set run-error error-message ]
    carefully [ __ignore (runresult "5" 1) ] [ set runresult-error error-message ]
    report (list run-error runresult-error)
  end
  """; seed=263)

  call!(runtime, "setup")

  call!(runtime, "run-basic")
  @test runtime.world.observer.globals["CHECK"] == 1.0
  @test call!(runtime, "runresult-basic") == Any[3.0, 3.0, 1.0]
  @test call!(runtime, "run-once") == Any[1.0, 1.0]
  call!(runtime, "run-from-bare-reporter")
  @test call!(runtime, "bare-run-state") == Any[1.0, 1.0]
  @test call!(runtime, "runresult-from-bare-reporter") == Any[2.0, 1.0]
  @test call!(runtime, "local-isolation") == 0.0
  @test call!(runtime, "read-procedure-locals", 1) == 21.0

  call!(runtime, "scope-error-demo", 1)
  @test call!(runtime, "scope-value") == 600021.0
  @test occursin("ASK-LET", call!(runtime, "scope-message"))

  @test call!(runtime, "duplicate-let-demo") == "There is already a local variable here called A"

  call!(runtime, "stop-demo")
  @test runtime.world.observer.globals["CHECK"] == 0.0

  @test call!(runtime, "extra-arg-errors") == Any[
    "run doesn't accept further inputs if the first is a string",
    "runresult doesn't accept further inputs if the first is a string",
  ]
end

@testset "unit: command task non-local exits" begin
  runtime = create_runtime(netlogo"""
  globals [check]

  to setup
    clear-all
    set check 0
  end

  to-report stop-task?
    report is-anonymous-command? [ -> stop ]
  end

  to-report report-task?
    report is-anonymous-command? [ -> report 5 ]
  end

  to stop-via-task
    set check 1
    run [ -> stop ]
    set check 2
  end

  to-report report-via-task
    run [ -> report 5 ]
  end

  to-report foreach-early-exit
    foreach ["apples" "oranges"] [0 0] [ [x y] -> if x = "oranges" [ report x ] ]
  end

  to-report stop-error-demo
    run [ -> stop ]
    report 5
  end

  to report-error-demo
    run [ -> report 5 ]
  end
  """; seed=279)

  call!(runtime, "setup")

  @test call!(runtime, "stop-task?") == true
  @test call!(runtime, "report-task?") == true

  call!(runtime, "stop-via-task")
  @test runtime.world.observer.globals["CHECK"] == 1.0
  @test call!(runtime, "report-via-task") == 5.0
  @test call!(runtime, "foreach-early-exit") == "oranges"

  stop_error = try
    call!(runtime, "stop-error-demo")
    nothing
  catch err
    err
  end
  @test stop_error isa NetLogo.LogoRuntimeError
  @test stop_error.message == "STOP is not allowed inside TO-REPORT."

  report_error = try
    call!(runtime, "report-error-demo")
    nothing
  catch err
    err
  end
  @test report_error isa NetLogo.LogoRuntimeError
  @test report_error.message == "REPORT can only be used inside TO-REPORT."
end

@testset "unit: ask stop handling" begin
  runtime = create_runtime(netlogo"""
  turtles-own [hits]
  globals [direct-stop-hits run-stop-hits]

  to setup
    clear-all
    create-turtles 3 [ set hits 0 ]
  end

  to direct-stop-ask
    ask turtles [
      set hits hits + 1
      stop
      set hits hits + 10
    ]
    set direct-stop-hits sort [hits] of turtles
  end

  to run-stop-ask
    ask turtles [
      set hits 0
      set hits hits + 1
      run [ -> stop ]
      set hits hits + 10
    ]
    set run-stop-hits sort [hits] of turtles
  end
  """; seed=281)

  call!(runtime, "setup")
  call!(runtime, "direct-stop-ask")
  @test runtime.world.observer.globals["DIRECT-STOP-HITS"] == Any[1.0, 1.0, 1.0]

  call!(runtime, "run-stop-ask")
  @test runtime.world.observer.globals["RUN-STOP-HITS"] == Any[1.0, 1.0, 1.0]
end

@testset "unit: foreach concise command references" begin
  runtime = create_runtime(netlogo"""
  globals [glob1]

  to foo
    set glob1 glob1 + 1
  end

  to-report foreach-procedure-demo
    clear-all
    set glob1 0
    foreach [1 1 1] foo
    report glob1
  end

  to-report foreach-create-demo
    clear-all
    foreach [1 2 3] crt
    report count turtles
  end

  to-report foreach-create-extra-input-demo
    clear-all
    foreach [1 2 3] [9 9 9] crt
    report count turtles
  end

  to-report foreach-forward-demo
    clear-all
    crt 1
    ask turtle 0 [
      set heading 0
      foreach [0.5 0.5 0.5] fd
    ]
    report [ycor] of turtle 0
  end

  to-report foreach-die-demo
    clear-all
    crt 1
    ask turtle 0 [
      foreach [1] die
    ]
    report count turtles
  end
  """; seed=281)

  @test call!(runtime, "foreach-procedure-demo") == 3.0
  @test call!(runtime, "foreach-create-demo") == 6.0
  @test call!(runtime, "foreach-create-extra-input-demo") == 6.0
  @test call!(runtime, "foreach-forward-demo") == 1.5
  @test call!(runtime, "foreach-die-demo") == 0.0
end

@testset "unit: loop and check-syntax" begin
  runtime = create_runtime(netlogo"""
  globals [glob1]

  to setup
    clear-all
    set glob1 0
  end

  to loop-demo
    loop [
      if glob1 = 4 [ stop ]
      set glob1 glob1 + 1
    ]
  end

  to-report loop-count
    report glob1
  end

  to-report syntax-basic
    report (list __check-syntax "set glob1 1" __check-syntax "set glob1 missing-name")
  end

  to-report syntax-scope [x]
    let y 2
    report (list __check-syntax "set glob1 x + y" __check-syntax "set glob1 x + z")
  end
  """; seed=271)

  call!(runtime, "setup")
  call!(runtime, "loop-demo")

  @test call!(runtime, "loop-count") == 4.0
  @test call!(runtime, "syntax-basic") == Any["", "Nothing named MISSING-NAME has been defined."]
  @test call!(runtime, "syntax-scope", 1) == Any["", "Nothing named Z has been defined."]
end

@testset "unit: every command" begin
  runtime = create_runtime(netlogo"""
  globals [glob1]

  to-report will-it-run?
    every 20 [ report true ]
    report false
  end

  to go
    set glob1 (fput who glob1)
  end

  to every-agent-demo
    set glob1 (list)
    clear-all
    crt 5
    ask turtles [ repeat 10 [ every 10 [ go ] ] ]
  end

  to-report every-always-runs-first
    loop [
      every 10 [ report true ]
      report false
    ]
  end

  to-report every-waits-for-time
    let i 0
    loop [
      every 20 [ if i > 0 [ report true ] ]
      if i > 0 [ report false ]
      set i i + 1
    ]
  end
  """; seed=563)

  @test call!(runtime, "will-it-run?") == true
  @test call!(runtime, "will-it-run?") == true

  call!(runtime, "every-agent-demo")
  @test sum(runtime.world.observer.globals["GLOB1"]) == 10.0

  @test call!(runtime, "every-always-runs-first") == true
  @test call!(runtime, "every-waits-for-time") == false
end

# ── csv extension ──────────────────────────────────────────────────────
@testset "unit: csv extension" begin
  runtime = create_runtime(compile_model("""
  extensions [csv]

  to-report test-from-row
    report csv:from-row "1,hello,true,3.14"
  end

  to-report test-from-string
    report csv:from-string "a,b,c\\n1,2,3"
  end

  to-report test-to-row
    report csv:to-row [1 "hello" true]
  end

  to-report test-to-string
    report csv:to-string [[1 2 3] [4 5 6]]
  end

  to-report test-delimiter
    report csv:from-row-with-delimiter "a;b;c" ";"
  end

  to-report test-to-row-delimiter
    report csv:to-row-with-delimiter [1 2 3] "|"
  end

  to-report test-empty-row
    report csv:from-row ""
  end

  to-report test-to-from-roundtrip
    let row [1 "hello" true 3.14]
    let encoded csv:to-row row
    report csv:from-row encoded
  end
  """); seed=1)

  @test call!(runtime, "test-from-row") == Any[1.0, "hello", true, 3.14]
  @test call!(runtime, "test-from-string") == Any[Any["a", "b", "c"], Any[1.0, 2.0, 3.0]]
  @test call!(runtime, "test-to-row") == "1,hello,true"
  @test call!(runtime, "test-to-string") == "1,2,3\n4,5,6"
  @test call!(runtime, "test-delimiter") == Any["a", "b", "c"]
  @test call!(runtime, "test-to-row-delimiter") == "1|2|3"
  @test call!(runtime, "test-empty-row") == Any[""]
  @test call!(runtime, "test-to-from-roundtrip") == Any[1.0, "hello", true, 3.14]
end

# ── table extension ────────────────────────────────────────────────────
@testset "unit: table extension" begin
  runtime = create_runtime(compile_model("""
  extensions [table]
  globals [t]

  to-report test-make-put-get
    set t table:make
    table:put t "a" 1
    table:put t "b" 2
    table:put t "c" 3
    let len table:length t
    let v table:get t "b"
    let hk1 table:has-key? t "a"
    let hk2 table:has-key? t "z"
    report (list len v hk1 hk2)
  end

  to-report test-keys-values
    set t table:make
    table:put t "x" 10
    table:put t "y" 20
    report (list table:keys t table:values t)
  end

  to-report test-from-list
    set t table:from-list [[1 "one"] [2 "two"] [3 "three"]]
    report table:get t 2
  end

  to-report test-to-list
    set t table:make
    table:put t "a" 1
    table:put t "b" 2
    report table:to-list t
  end

  to-report test-remove
    set t table:make
    table:put t "a" 1
    table:put t "b" 2
    table:remove t "a"
    report table:length t
  end

  to-report test-clear
    set t table:make
    table:put t "a" 1
    table:put t "b" 2
    table:clear t
    report table:length t
  end

  to-report test-counts
    let c table:counts [1 2 1 3 2 1]
    report (list table:get c 1 table:get c 2 table:get c 3)
  end

  to-report test-get-or-default
    set t table:make
    table:put t "a" 1
    let v1 table:get-or-default t "a" 99
    let v2 table:get-or-default t "z" 99
    report (list v1 v2)
  end

  to-report test-overwrite
    set t table:make
    table:put t "k" 1
    table:put t "k" 2
    report (list table:get t "k" table:length t)
  end

  to-report test-numeric-keys
    set t table:from-list [[1 "one"] [2 "two"]]
    report table:get t 1
  end
  """); seed=1)

  @test call!(runtime, "test-make-put-get") == Any[3.0, 2.0, true, false]
  @test call!(runtime, "test-keys-values") == Any[Any["x", "y"], Any[10.0, 20.0]]
  @test call!(runtime, "test-from-list") == "two"
  @test call!(runtime, "test-to-list") == Any[Any["a", 1.0], Any["b", 2.0]]
  @test call!(runtime, "test-remove") == 1.0
  @test call!(runtime, "test-clear") == 0.0
  @test call!(runtime, "test-counts") == Any[3.0, 2.0, 1.0]
  @test call!(runtime, "test-get-or-default") == Any[1.0, 99.0]
  @test call!(runtime, "test-overwrite") == Any[2.0, 1.0]
  @test call!(runtime, "test-numeric-keys") == "one"
end

# ── nw extension ───────────────────────────────────────────────────────
@testset "unit: nw extension" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [result]
  undirected-link-breed [friendships friendship]

  to setup
    create-turtles 5
    ask turtle 0 [ create-friendship-with turtle 1 ]
    ask turtle 1 [ create-friendship-with turtle 2 ]
    ask turtle 2 [ create-friendship-with turtle 3 ]
    ask turtle 3 [ create-friendship-with turtle 4 ]
    nw:set-context turtles friendships
  end

  to-report test-distance
    let d 0
    ask turtle 0 [ set d nw:distance-to turtle 4 ]
    report d
  end

  to-report test-path-length
    let p []
    ask turtle 0 [ set p nw:path-to turtle 4 ]
    report length p
  end

  to-report test-mean-path
    report nw:mean-path-length
  end

  to-report test-clustering-chain
    let c 0
    ask turtle 1 [ set c nw:clustering-coefficient ]
    report c
  end

  to-report test-clustering-triangle
    ask turtle 0 [ create-friendship-with turtle 2 ]
    let c 0
    ask turtle 1 [ set c nw:clustering-coefficient ]
    report c
  end

  to-report test-closeness
    let c 0
    ask turtle 0 [ set c nw:closeness-centrality ]
    report c
  end

  to-report test-radius
    let r []
    ask turtle 2 [ set r sort [who] of nw:turtles-in-radius 1 ]
    report r
  end

  to-report test-disconnected
    let d false
    ask turtle 0 [ set d nw:distance-to turtle 4 ]
    report d
  end
  """); seed=1)

  call!(runtime, "setup")
  @test call!(runtime, "test-distance") == 4.0
  @test call!(runtime, "test-path-length") == 5.0
  @test call!(runtime, "test-mean-path") == 2.0
  @test call!(runtime, "test-clustering-chain") == 0.0

  # closeness of node 0 in chain 0-1-2-3-4: 4/(1+2+3+4) = 0.4
  @test call!(runtime, "test-closeness") == 0.4

  @test call!(runtime, "test-radius") == Any[1.0, 2.0, 3.0]

  # adding triangle edge changes clustering
  @test call!(runtime, "test-clustering-triangle") == 1.0
end

# ── nw extension generators ───────────────────────────────────────────
@testset "unit: nw generators" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  undirected-link-breed [edges edge]

  to-report test-star
    nw:generate-star turtles edges 5 [ set color red ]
    report (list count turtles count edges)
  end

  to-report test-ring
    nw:generate-ring turtles edges 6 [ ]
    report (list count turtles count edges)
  end

  to-report test-lattice
    nw:generate-lattice-2d turtles edges 3 4 false [ ]
    report count turtles
  end

  to-report test-pref-attach
    nw:generate-preferential-attachment turtles edges 8 1 [ ]
    report count turtles
  end
  """); seed=42)

  @test call!(runtime, "test-star") == Any[5.0, 4.0]
  r = call!(runtime, "test-ring")
  @test r[1] == 11.0
  @test r[2] == 10.0
  @test call!(runtime, "test-lattice") == 23.0  # 11 + 12
  @test call!(runtime, "test-pref-attach") == 31.0  # 23 + 8
end

# ── nw extension: new primitives (page-rank, eigenvector, louvain, cliques, etc.) ──
@testset "unit: nw page-rank and eigenvector centrality" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]

  to setup
    create-turtles 5
    ; Star: turtle 0 is hub, connected to 1,2,3,4
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 0 [ create-link-with turtle 2 ]
    ask turtle 0 [ create-link-with turtle 3 ]
    ask turtle 0 [ create-link-with turtle 4 ]
    nw:set-context turtles links
  end

  to-report test-pr-hub
    let pr 0
    ask turtle 0 [ set pr nw:page-rank ]
    report pr
  end

  to-report test-pr-leaf
    let pr 0
    ask turtle 1 [ set pr nw:page-rank ]
    report pr
  end

  to-report test-ec-hub
    let ec 0
    ask turtle 0 [ set ec nw:eigenvector-centrality ]
    report ec
  end

  to-report test-ec-leaf
    let ec 0
    ask turtle 1 [ set ec nw:eigenvector-centrality ]
    report ec
  end
  """); seed=1)

  call!(runtime, "setup")
  pr_hub = call!(runtime, "test-pr-hub")
  pr_leaf = call!(runtime, "test-pr-leaf")
  @test pr_hub > pr_leaf  # hub should have higher PageRank
  @test pr_hub > 0.2      # hub PR should be significant
  @test pr_leaf > 0.0     # leaf PR should be positive

  ec_hub = call!(runtime, "test-ec-hub")
  ec_leaf = call!(runtime, "test-ec-leaf")
  @test ec_hub > ec_leaf  # hub should have higher eigenvector centrality
  @test ec_hub > 0.0
end

@testset "unit: nw louvain communities" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [n-comms comm-sizes]

  to setup
    create-turtles 8
    ; Cluster A: 0-1-2-3 fully connected
    ask turtle 0 [ create-link-with turtle 1 create-link-with turtle 2 create-link-with turtle 3 ]
    ask turtle 1 [ create-link-with turtle 2 create-link-with turtle 3 ]
    ask turtle 2 [ create-link-with turtle 3 ]
    ; Bridge
    ask turtle 3 [ create-link-with turtle 4 ]
    ; Cluster B: 4-5-6-7 fully connected
    ask turtle 4 [ create-link-with turtle 5 create-link-with turtle 6 create-link-with turtle 7 ]
    ask turtle 5 [ create-link-with turtle 6 create-link-with turtle 7 ]
    ask turtle 6 [ create-link-with turtle 7 ]
    nw:set-context turtles links
    let comms nw:louvain-communities
    set n-comms length comms
    set comm-sizes sort map [c -> count c] comms
  end
  """); seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["N-COMMS"] == 2.0
  @test runtime.world.observer.globals["COMM-SIZES"] == Any[4.0, 4.0]
end

@testset "unit: nw maximal cliques" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [n-cliques sizes biggest-sizes]

  to setup
    create-turtles 4
    ; Triangle 0-1-2 plus edge 2-3
    ask turtle 0 [ create-link-with turtle 1 create-link-with turtle 2 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    ask turtle 2 [ create-link-with turtle 3 ]
    nw:set-context turtles links
    let cliques nw:maximal-cliques
    set n-cliques length cliques
    set sizes sort map [c -> count c] cliques
    let biggest nw:biggest-maximal-cliques
    set biggest-sizes sort map [c -> count c] biggest
  end
  """); seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["N-CLIQUES"] == 2.0  # triangle + edge
  @test runtime.world.observer.globals["SIZES"] == Any[2.0, 3.0]
  @test runtime.world.observer.globals["BIGGEST-SIZES"] == Any[3.0]
end

@testset "unit: nw bicomponent clusters" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [n-bicomps]

  to setup
    create-turtles 5
    ; Triangle 0-1-2 connected via bridge 2-3 to edge 3-4
    ask turtle 0 [ create-link-with turtle 1 create-link-with turtle 2 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    ask turtle 2 [ create-link-with turtle 3 ]
    ask turtle 3 [ create-link-with turtle 4 ]
    nw:set-context turtles links
    let bicomps nw:bicomponent-clusters
    set n-bicomps length bicomps
  end
  """); seed=1)

  call!(runtime, "setup")
  # Triangle is one bicomponent, bridge+edge are two more
  @test runtime.world.observer.globals["N-BICOMPS"] >= 2.0
end

@testset "unit: nw watts-strogatz generator" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [n-nodes n-edges]

  to setup
    nw:generate-watts-strogatz turtles links 20 2 0.0 false [ ]
    set n-nodes count turtles
    set n-edges count links
  end
  """); seed=42)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["N-NODES"] == 20.0
  @test runtime.world.observer.globals["N-EDGES"] == 40.0  # 20 nodes * 2 neighbors each side
end

@testset "unit: nw weak-component-clusters" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [n-comps comp-sizes]

  to setup
    create-turtles 6
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    ask turtle 3 [ create-link-with turtle 4 ]
    ; 0-1-2 = component, 3-4 = component, 5 = isolated
    nw:set-context turtles links
    let comps nw:weak-component-clusters
    set n-comps length comps
    set comp-sizes sort map [c -> count c] comps
  end
  """); seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["N-COMPS"] == 3.0
  @test runtime.world.observer.globals["COMP-SIZES"] == Any[1.0, 2.0, 3.0]
end

@testset "unit: nw set-snapshot" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [n-before n-after]

  to setup
    create-turtles 3
    ask turtle 0 [ create-link-with turtle 1 ]
    nw:set-context turtles links
    nw:set-snapshot
    set n-before count turtles
    ; Add more turtles after snapshot
    create-turtles 2
    ask turtle 2 [ create-link-with turtle 3 ]
    ; Context is now frozen to original 3 turtles
    let ctx nw:get-context
    set n-after count item 0 ctx
  end
  """); seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["N-BEFORE"] == 3.0
  @test runtime.world.observer.globals["N-AFTER"] == 3.0  # frozen at snapshot time
end

@testset "unit: agent-owned values preserve agent identity" begin
  runtime = create_runtime(compile_model("""
  breed [wolves wolf]
  turtles-own [mate]

  to setup
    clear-all
    create-turtles 1 [
      set mate self
    ]
    ask turtle 0 [
      hatch 1
      set breed wolves
    ]
  end
  """); seed=1)

  call!(runtime, "setup")
  parent = runtime.world.turtles[1]
  child = runtime.world.turtles[2]
  @test parent.own["MATE"] === parent
  @test child.own["MATE"] === parent
end

@testset "unit: array extension index handling" begin
  runtime = create_runtime(compile_model("""
  extensions [array]
  globals [a]

  to setup
    set a array:from-list [10 20 30]
  end

  to-report fractional-index
    report array:item a 1.9
  end

  to-report negative-fractional-index
    report array:item a -0.2
  end
  """); seed=1)

  call!(runtime, "setup")
  @test call!(runtime, "fractional-index") == 20.0
  @test_throws LogoRuntimeError call!(runtime, "negative-fractional-index")
end

@testset "unit: table json extension" begin
  mktempdir() do dir
    json_path = joinpath(dir, "table.json")
    json_text = "{\"alpha\":[1,2],\"beta\":true}"
    write(json_path, json_text)
    escaped_path = replace(json_path, "\\" => "\\\\")
    escaped_json = replace(json_text, "\"" => "\\\"")

    runtime = create_runtime(compile_model("""
    extensions [table]
    globals [t]

    to setup
      set t table:from-json "$escaped_json"
    end

    to-report beta-value
      report table:get t "beta"
    end

    to-report alpha-second-from-file
      let from-file table:from-json-file "$escaped_path"
      report last table:get from-file "alpha"
    end

    to-report serialized
      report table:to-json t
    end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "beta-value") == true
    @test call!(runtime, "alpha-second-from-file") == 2.0
    @test occursin("\"beta\":true", call!(runtime, "serialized"))
  end
end

@testset "unit: store persistence handling" begin
  mkpath(NetLogo.store.STORE_DIR)
  store_name = "unit-store-" * string(time_ns())
  store_path = joinpath(NetLogo.store.STORE_DIR, store_name * ".json")
  corrupt_name = store_name * "-corrupt"
  corrupt_path = joinpath(NetLogo.store.STORE_DIR, corrupt_name * ".json")

  try
    NetLogo.store._save_store(store_name, Dict("key" => "value"))
    @test NetLogo.store._load_store(store_name) == Dict("key" => "value")

    write(corrupt_path, "{bad json")
    @test_throws LogoRuntimeError NetLogo.store._load_store(corrupt_name)
  finally
    rm(store_path; force=true)
    rm(corrupt_path; force=true)
  end
end

@testset "unit: bitmap extension import export and base64" begin
  mktempdir() do dir
    input_path = joinpath(dir, "input.png")
    output_path = joinpath(dir, "output.png")
    image = Matrix{RGB{Float32}}(undef, 2, 2)
    image[1, 1] = RGB{Float32}(1, 0, 0)
    image[1, 2] = RGB{Float32}(0, 1, 0)
    image[2, 1] = RGB{Float32}(0, 0, 1)
    image[2, 2] = RGB{Float32}(1, 1, 0)
    FileIO.save(input_path, image)

    escaped_input = replace(input_path, "\\" => "\\\\")
    escaped_output = replace(output_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [bitmap]
    globals [bmp payload]

    to setup
      set bmp bitmap:import "$escaped_input"
      set payload bitmap:to-base64 bmp
    end

    to-report dimensions
      report (list bitmap:width bmp bitmap:height bmp)
    end

    to-report roundtrip-width
      let decoded bitmap:from-base64 payload
      report bitmap:width decoded
    end

    to export-bitmap
      bitmap:export bmp "$escaped_output"
    end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "dimensions") == Any[2.0, 2.0]
    @test call!(runtime, "roundtrip-width") == 2.0
    call!(runtime, "export-bitmap")
    @test isfile(output_path)
    exported = FileIO.load(output_path)
    @test size(exported, 1) == 2
    @test size(exported, 2) == 2
  end
end

@testset "unit: gis dataset export and patch datasets" begin
  mktempdir() do dir
    input_path = joinpath(dir, "grid.asc")
    output_path = joinpath(dir, "grid-out.asc")
    write(input_path, join([
      "ncols 2",
      "nrows 2",
      "xllcorner 0",
      "yllcorner 0",
      "cellsize 1",
      "NODATA_value -9999",
      "1 2",
      "3 4",
    ], "\n"))

    escaped_input = replace(input_path, "\\" => "\\\\")
    escaped_output = replace(output_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    globals [r p]

    to setup
      set r gis:load-dataset "$escaped_input"
      gis:store-dataset r "$escaped_output"
      gis:set-world-envelope [0 2 0 2]
      set p gis:patch-dataset patches
    end

    to-report patch-count
      report length (gis:feature-list-of p)
    end
    """); seed=1)

    call!(runtime, "setup")
    @test isfile(output_path)
    exported = NetLogo.gis._load_dataset(output_path)
    @test exported isa NetLogo.gis.GisRasterDataset
    @test exported.width == 2
    @test exported.height == 2
    expected = (runtime.world.max_pxcor - runtime.world.min_pxcor + 1) *
               (runtime.world.max_pycor - runtime.world.min_pycor + 1)
    @test call!(runtime, "patch-count") == Float64(expected)
  end
end

# ---------------------------------------------------------------------------
# Parser: negative number literal tests
# ---------------------------------------------------------------------------

@testset "unit: negative number literals" begin
  # Basic negative numbers as command arguments
  runtime = create_runtime(compile_model("""
  globals [a b c d e]
  to setup
    resize-world -2 2 -2 2
    set a -5
    set b 3 - 2
    set c 10 + -3
    set d -1 + -2
    set e -0.5
  end
  to-report get-a report a end
  to-report get-b report b end
  to-report get-c report c end
  to-report get-d report d end
  to-report get-e report e end
  to-report w report world-width end
  """); seed=1)

  call!(runtime, "setup")
  @test call!(runtime, "get-a") == -5.0
  @test call!(runtime, "get-b") == 1.0    # 3 - 2 = 1 (infix subtraction with spaces)
  @test call!(runtime, "get-c") == 7.0    # 10 + (-3) = 7
  @test call!(runtime, "get-d") == -3.0   # (-1) + (-2) = -3
  @test call!(runtime, "get-e") == -0.5
  @test call!(runtime, "w") == 5.0        # resize-world -2 2 -2 2 => width 5

  # Negative numbers as movement arguments
  runtime2 = create_runtime(compile_model("""
  to setup
    crt 1 [ setxy 0 0 set heading 0 ]
  end
  to-report move-and-report
    ask turtle 0 [ fd -3 ]
    report [ycor] of turtle 0
  end
  """); seed=1)
  call!(runtime2, "setup")
  @test call!(runtime2, "move-and-report") == -3.0
end

# ---------------------------------------------------------------------------
# Comprehensive bitmap extension tests
# ---------------------------------------------------------------------------

@testset "unit: bitmap create, scale, grayscale, average-color" begin
  runtime = create_runtime(compile_model("""
  extensions [bitmap]
  globals [bmp gray avg sc diff]

  to setup
    ;; create a 3x2 bitmap via from-view on a tiny world
    resize-world 0 2 0 1
    ask patches [ set pcolor red ]
    ask patch 1 0 [ set pcolor blue ]
    ask patch 2 1 [ set pcolor green ]
    set bmp bitmap:from-view
  end

  to-report bmp-width  report bitmap:width bmp  end
  to-report bmp-height report bitmap:height bmp end

  to make-gray
    set gray bitmap:to-grayscale bmp
  end
  to-report gray-width  report bitmap:width gray  end
  to-report gray-height report bitmap:height gray end

  to make-scaled
    set sc bitmap:scaled bmp 6 4
  end
  to-report sc-width  report bitmap:width sc  end
  to-report sc-height report bitmap:height sc end

  to make-avg
    set avg bitmap:average-color bmp
  end
  to-report avg-color report avg end

  to make-diff
    set diff bitmap:difference-rgb bmp bmp
  end
  to-report diff-avg report bitmap:average-color diff end
  """); seed=1)

  call!(runtime, "setup")
  # from-view renders at patch-size scale (default 12px per patch)
  # 3 patches wide × 12 = 36, 2 patches tall × 12 = 24
  @test call!(runtime, "bmp-width") == 36.0
  @test call!(runtime, "bmp-height") == 24.0

  call!(runtime, "make-gray")
  @test call!(runtime, "gray-width") == 36.0
  @test call!(runtime, "gray-height") == 24.0

  call!(runtime, "make-scaled")
  @test call!(runtime, "sc-width") == 6.0
  @test call!(runtime, "sc-height") == 4.0

  call!(runtime, "make-avg")
  avg = call!(runtime, "avg-color")
  @test length(avg) == 3
  @test all(v -> v isa Float64, avg)

  # difference of bitmap with itself should be all zeros
  call!(runtime, "make-diff")
  diff_avg = call!(runtime, "diff-avg")
  @test diff_avg == Any[0.0, 0.0, 0.0]
end

@testset "unit: bitmap channel extraction" begin
  runtime = create_runtime(compile_model("""
  extensions [bitmap]
  globals [bmp red-ch green-ch blue-ch]

  to setup
    resize-world 0 1 0 0
    ask patch 0 0 [ set pcolor [255 0 0] ]
    ask patch 1 0 [ set pcolor [0 128 255] ]
    set bmp bitmap:from-view
    set red-ch bitmap:channel bmp 0
    set green-ch bitmap:channel bmp 1
    set blue-ch bitmap:channel bmp 2
  end

  to-report get-red report red-ch end
  to-report get-green report green-ch end
  to-report get-blue report blue-ch end
  """); seed=1)

  call!(runtime, "setup")
  red_ch = call!(runtime, "get-red")
  # channel returns a list of rows; bitmap is rendered at patch-size (12px per patch)
  # so 2 patches × 12 = 24 columns, 1 patch × 12 = 12 rows
  @test length(red_ch) == 12
  @test length(red_ch[1]) == 24
  # Left half (patch 0,0 = red) should have R=255
  @test red_ch[1][1] == 255.0
  # Right half (patch 1,0 = [0,128,255]) should have R=0
  @test red_ch[1][end] == 0.0

  green_ch = call!(runtime, "get-green")
  @test green_ch[1][1] == 0.0    # red pixel G=0
  @test green_ch[1][end] == 128.0 # [0,128,255] G=128

  blue_ch = call!(runtime, "get-blue")
  @test blue_ch[1][1] == 0.0      # red pixel B=0
  @test blue_ch[1][end] == 255.0   # [0,128,255] B=255
end

@testset "unit: bitmap copy-to-pcolors scaled and unscaled" begin
  runtime = create_runtime(compile_model("""
  extensions [bitmap]
  globals [bmp]

  to setup
    resize-world 0 1 0 0
    ask patch 0 0 [ set pcolor [200 100 50] ]
    ask patch 1 0 [ set pcolor [10 20 30] ]
    set bmp bitmap:from-view

    ;; now resize to 4x2 and apply bitmap
    resize-world 0 3 0 1
  end

  to apply-scaled
    bitmap:copy-to-pcolors bmp true
  end

  to apply-unscaled
    ;; reset colors first
    ask patches [ set pcolor black ]
    bitmap:copy-to-pcolors bmp false
  end

  to-report pc [x y]
    report [pcolor] of patch x y
  end
  """); seed=1)

  call!(runtime, "setup")
  # scaled: stretches bitmap to 4x2 world
  call!(runtime, "apply-scaled")
  c00 = call!(runtime, "pc", Any[0.0, 0.0])
  @test c00 isa AbstractVector  # should be RGB list
  @test length(c00) == 3  # R, G, B

  # unscaled: bitmap is larger than world (24x12 vs 4x2), centered
  call!(runtime, "apply-unscaled")
  c31 = call!(runtime, "pc", Any[3.0, 1.0])
  @test c31 isa AbstractVector || c31 isa Number  # should be set to something
end

@testset "unit: bitmap import/export round-trip with file" begin
  mktempdir() do dir
    png_path = joinpath(dir, "test.png")
    # Create a small test PNG via Julia
    image = Matrix{RGB{Float32}}(undef, 3, 4)
    for r in 1:3, c in 1:4
      image[r, c] = RGB{Float32}(Float32(r)/3f0, Float32(c)/4f0, 0.5f0)
    end
    FileIO.save(png_path, image)

    escaped = replace(png_path, "\\" => "\\\\")
    out_path = joinpath(dir, "out.png")
    escaped_out = replace(out_path, "\\" => "\\\\")

    runtime = create_runtime(compile_model("""
    extensions [bitmap]
    globals [bmp]

    to setup
      set bmp bitmap:import "$escaped"
    end

    to-report dims
      report (list bitmap:width bmp bitmap:height bmp)
    end

    to do-export
      bitmap:export bmp "$escaped_out"
    end

    to-report avg
      report bitmap:average-color bmp
    end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "dims") == Any[4.0, 3.0]

    avg = call!(runtime, "avg")
    @test length(avg) == 3
    @test all(v -> v > 0, avg)  # non-zero averages

    call!(runtime, "do-export")
    @test isfile(out_path)

    # Re-import and check dimensions match
    re = FileIO.load(out_path)
    @test size(re) == (3, 4)
  end
end

@testset "unit: bitmap base64 round-trip" begin
  mktempdir() do dir
    png_path = joinpath(dir, "test.png")
    image = Matrix{RGB{Float32}}(undef, 2, 2)
    image[1, 1] = RGB{Float32}(1, 0, 0)
    image[1, 2] = RGB{Float32}(0, 1, 0)
    image[2, 1] = RGB{Float32}(0, 0, 1)
    image[2, 2] = RGB{Float32}(1, 1, 1)
    FileIO.save(png_path, image)

    escaped = replace(png_path, "\\" => "\\\\")

    runtime = create_runtime(compile_model("""
    extensions [bitmap]
    globals [bmp b64 decoded]

    to setup
      set bmp bitmap:import "$escaped"
      set b64 bitmap:to-base64 bmp
      set decoded bitmap:from-base64 b64
    end

    to-report orig-dims
      report (list bitmap:width bmp bitmap:height bmp)
    end

    to-report decoded-dims
      report (list bitmap:width decoded bitmap:height decoded)
    end

    to-report orig-avg  report bitmap:average-color bmp end
    to-report decoded-avg report bitmap:average-color decoded end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "orig-dims") == Any[2.0, 2.0]
    @test call!(runtime, "decoded-dims") == Any[2.0, 2.0]
    # Averages should be the same (lossless PNG round-trip)
    orig_avg = call!(runtime, "orig-avg")
    decoded_avg = call!(runtime, "decoded-avg")
    for i in 1:3
      @test abs(orig_avg[i] - decoded_avg[i]) < 2.0  # allow minor PNG compression drift
    end
  end
end

# ---------------------------------------------------------------------------
# Comprehensive GIS extension tests
# ---------------------------------------------------------------------------

@testset "unit: gis raster create, read, write, dimensions" begin
  runtime = create_runtime(compile_model("""
  extensions [gis]
  globals [r]

  to setup
    set r gis:create-raster 5 4 (list 0 5 0 4)
  end

  to-report raster-w report gis:width-of r end
  to-report raster-h report gis:height-of r end

  to fill-raster
    let row 0
    repeat 4 [
      let col 0
      repeat 5 [
        gis:set-raster-value r col row (row * 5 + col)
        set col col + 1
      ]
      set row row + 1
    ]
  end

  to-report val [c rv]
    report gis:raster-value r c rv
  end

  to-report min-val report gis:minimum-of r end
  to-report max-val report gis:maximum-of r end
  """); seed=1)

  call!(runtime, "setup")
  @test call!(runtime, "raster-w") == 5.0
  @test call!(runtime, "raster-h") == 4.0

  call!(runtime, "fill-raster")
  @test call!(runtime, "val", Any[0.0, 0.0]) == 0.0  # top-left
  @test call!(runtime, "val", Any[4.0, 3.0]) == 19.0  # bottom-right
  @test call!(runtime, "val", Any[2.0, 1.0]) == 7.0   # row 1 col 2

  @test call!(runtime, "min-val") == 0.0
  @test call!(runtime, "max-val") == 19.0
end

@testset "unit: gis raster apply-raster to patches" begin
  mktempdir() do dir
    asc_path = joinpath(dir, "elev.asc")
    write(asc_path, join([
      "ncols 3",
      "nrows 3",
      "xllcorner 0",
      "yllcorner 0",
      "cellsize 1",
      "NODATA_value -9999",
      "10 20 30",
      "40 50 60",
      "70 80 90",
    ], "\n"))

    escaped = replace(asc_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    patches-own [elevation]
    globals [r]

    to setup
      resize-world -1 1 -1 1
      set r gis:load-dataset "$escaped"
      gis:set-world-envelope (gis:envelope-of r)
      gis:apply-raster r "elevation"
    end

    to-report elev-center report [elevation] of patch 0 0 end
    to-report elev-corner report [elevation] of patch -1 -1 end
    to-report elev-top-right report [elevation] of patch 1 1 end
    """); seed=1)

    call!(runtime, "setup")
    # Verify patches got non-zero elevation values from the raster
    center = call!(runtime, "elev-center")
    @test center isa Float64
    @test center > 0.0
    corner = call!(runtime, "elev-corner")
    @test corner isa Float64
    @test corner > 0.0
    top_right = call!(runtime, "elev-top-right")
    @test top_right isa Float64
    @test top_right > 0.0
  end
end

@testset "unit: gis raster convolve" begin
  mktempdir() do dir
    asc_path = joinpath(dir, "data.asc")
    write(asc_path, join([
      "ncols 5",
      "nrows 5",
      "xllcorner 0",
      "yllcorner 0",
      "cellsize 1",
      "NODATA_value -9999",
      "0 0 0 0 0",
      "0 0 0 0 0",
      "0 0 100 0 0",
      "0 0 0 0 0",
      "0 0 0 0 0",
    ], "\n"))

    escaped = replace(asc_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    globals [r smoothed kernel]

    to setup
      set r gis:load-dataset "$escaped"
      ;; 3x3 averaging kernel - must use (list ...) since [...] is a block
      set kernel (list 1 1 1 1 1 1 1 1 1)
      set smoothed gis:convolve r 3 3 kernel
    end

    to-report smooth-w report gis:width-of smoothed end
    to-report smooth-h report gis:height-of smoothed end
    to-report center-val report gis:raster-value smoothed 2 2 end
    to-report far-val report gis:raster-value smoothed 0 0 end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "smooth-w") == 5.0
    @test call!(runtime, "smooth-h") == 5.0
    # center pixel (2,2) was 100, after raw 3x3 convolution with all-1s kernel:
    # only the center pixel contributes: 1*100 = 100
    center = call!(runtime, "center-val")
    @test abs(center - 100.0) < 0.01
    # pixel (0,0) is far from center, should be 0
    @test call!(runtime, "far-val") == 0.0
  end
end

@testset "unit: gis set-world-envelope and raster-sample" begin
  mktempdir() do dir
    asc_path = joinpath(dir, "grid.asc")
    write(asc_path, join([
      "ncols 4",
      "nrows 4",
      "xllcorner 0",
      "yllcorner 0",
      "cellsize 10",
      "NODATA_value -9999",
      "1 2 3 4",
      "5 6 7 8",
      "9 10 11 12",
      "13 14 15 16",
    ], "\n"))

    escaped = replace(asc_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    globals [r]

    to setup
      resize-world -1 2 -1 2
      set r gis:load-dataset "$escaped"
      gis:set-world-envelope (gis:envelope-of r)
    end

    to-report env report gis:envelope-of r end
    to-report world-env report gis:world-envelope end
    to-report sample-at [x y]
      report gis:raster-sample r x y
    end
    """); seed=1)

    call!(runtime, "setup")
    env = call!(runtime, "env")
    @test length(env) == 4

    wenv = call!(runtime, "world-env")
    @test length(wenv) == 4

    # sample at center of raster
    center_sample = call!(runtime, "sample-at", Any[20.0, 20.0])
    @test center_sample isa Float64
  end
end

@testset "unit: gis raster store-dataset round-trip" begin
  mktempdir() do dir
    input_path = joinpath(dir, "in.asc")
    output_path = joinpath(dir, "out.asc")
    write(input_path, join([
      "ncols 3",
      "nrows 2",
      "xllcorner 10",
      "yllcorner 20",
      "cellsize 5",
      "NODATA_value -9999",
      "1.5 2.5 3.5",
      "4.5 5.5 6.5",
    ], "\n"))

    escaped_in = replace(input_path, "\\" => "\\\\")
    escaped_out = replace(output_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    globals [r r2]

    to setup
      set r gis:load-dataset "$escaped_in"
      gis:store-dataset r "$escaped_out"
      set r2 gis:load-dataset "$escaped_out"
    end

    to-report orig-dims report (list gis:width-of r gis:height-of r) end
    to-report copy-dims report (list gis:width-of r2 gis:height-of r2) end
    to-report orig-val [c rv] report gis:raster-value r c rv end
    to-report copy-val [c rv] report gis:raster-value r2 c rv end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "orig-dims") == Any[3.0, 2.0]
    @test call!(runtime, "copy-dims") == Any[3.0, 2.0]
    @test call!(runtime, "orig-val", Any[0.0, 0.0]) == call!(runtime, "copy-val", Any[0.0, 0.0])
    @test call!(runtime, "orig-val", Any[2.0, 1.0]) == call!(runtime, "copy-val", Any[2.0, 1.0])
  end
end

@testset "unit: gis resample raster" begin
  mktempdir() do dir
    asc_path = joinpath(dir, "small.asc")
    write(asc_path, join([
      "ncols 2",
      "nrows 2",
      "xllcorner 0",
      "yllcorner 0",
      "cellsize 1",
      "NODATA_value -9999",
      "10 20",
      "30 40",
    ], "\n"))

    escaped = replace(asc_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    globals [r big]

    to setup
      set r gis:load-dataset "$escaped"
      set big gis:resample r (list 4 4)
    end

    to-report orig-dims report (list gis:width-of r gis:height-of r) end
    to-report big-dims report (list gis:width-of big gis:height-of big) end
    """); seed=1)

    call!(runtime, "setup")
    @test call!(runtime, "orig-dims") == Any[2.0, 2.0]
    @test call!(runtime, "big-dims") == Any[4.0, 4.0]
  end
end

@testset "unit: gis world-envelope and set-transformation" begin
  runtime = create_runtime(compile_model("""
  extensions [gis]
  globals [r]

  to setup
    resize-world -5 5 -5 5
    set r gis:create-raster 10 10 (list 0 100 0 100)
    gis:set-world-envelope (list 0 100 0 100)
  end

  to-report world-env report gis:world-envelope end
  to-report raster-env report gis:envelope-of r end
  """); seed=1)

  call!(runtime, "setup")
  wenv = call!(runtime, "world-env")
  @test length(wenv) == 4
  renv = call!(runtime, "raster-env")
  @test length(renv) == 4
end

@testset "unit: gis drawing commands" begin
  mktempdir() do dir
    asc_path = joinpath(dir, "grid.asc")
    write(asc_path, join([
      "ncols 3",
      "nrows 3",
      "xllcorner 0",
      "yllcorner 0",
      "cellsize 1",
      "NODATA_value -9999",
      "1 2 3",
      "4 5 6",
      "7 8 9",
    ], "\n"))

    escaped = replace(asc_path, "\\" => "\\\\")
    runtime = create_runtime(compile_model("""
    extensions [gis]
    globals [r]

    to setup
      resize-world -1 1 -1 1
      set r gis:load-dataset "$escaped"
      gis:set-world-envelope (gis:envelope-of r)
    end

    to draw-raster
      gis:set-drawing-color 15
      gis:paint r 0
    end

    to-report drawing-c report gis:drawing-color end
    """); seed=1)

    call!(runtime, "setup")
    call!(runtime, "draw-raster")
    dc = call!(runtime, "drawing-c")
    @test dc == 15.0  # should be the color number we set
  end
end

# ── Bitstring Extension ──────────────────────────────────────────────────────

@testset "bitstring: make and basic accessors" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    globals [bs0 bs1]
    to setup
      set bs0 bitstring:make 6 false
      set bs1 bitstring:make 6 true
    end
    to-report len0 report bitstring:length bs0 end
    to-report len1 report bitstring:length bs1 end
    to-report c0 report bitstring:count0 bs0 end
    to-report c1 report bitstring:count1 bs1 end
    to-report all0 report bitstring:all0? bs0 end
    to-report all1 report bitstring:all1? bs1 end
    to-report any0 report bitstring:any0? bs1 end
    to-report any1 report bitstring:any1? bs0 end
    to-report first0 report bitstring:first? bs0 end
    to-report first1 report bitstring:first? bs1 end
    to-report last0 report bitstring:last? bs0 end
    to-report last1 report bitstring:last? bs1 end
    to-report get2 report bitstring:get? bs1 2 end
  """))
  call!(runtime, "setup")
  @test call!(runtime, "len0") == 6.0
  @test call!(runtime, "len1") == 6.0
  @test call!(runtime, "c0") == 6.0
  @test call!(runtime, "c1") == 6.0
  @test call!(runtime, "all0") == true
  @test call!(runtime, "all1") == true
  @test call!(runtime, "any0") == false
  @test call!(runtime, "any1") == false
  @test call!(runtime, "first0") == false
  @test call!(runtime, "first1") == true
  @test call!(runtime, "last0") == false
  @test call!(runtime, "last1") == true
  @test call!(runtime, "get2") == true
end

@testset "bitstring: set, from-list, from-string" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    globals [bs]
    to setup
      set bs bitstring:make 4 false
    end
    to-report do-set
      let b bitstring:set bs 1 true
      report bitstring:count1 b
    end
    to-report do-from-list
      let b bitstring:from-list [true false true false true]
      report bitstring:count1 b
    end
    to-report do-from-string
      let b bitstring:from-string "1010"
      report bitstring:count1 b
    end
    to-report list-round-trip
      let b bitstring:from-list [true false true]
      report bitstring:to-list b
    end
  """))
  call!(runtime, "setup")
  @test call!(runtime, "do-set") == 1.0
  @test call!(runtime, "do-from-list") == 3.0
  @test call!(runtime, "do-from-string") == 2.0
  @test call!(runtime, "list-round-trip") == Any[true, false, true]
end

@testset "bitstring: bitwise operators" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    to-report do-and
      let a bitstring:from-string "1100"
      let b bitstring:from-string "1010"
      report bitstring:count1 (a bitstring:and b)
    end
    to-report do-or
      let a bitstring:from-string "1100"
      let b bitstring:from-string "1010"
      report bitstring:count1 (a bitstring:or b)
    end
    to-report do-xor
      let a bitstring:from-string "1100"
      let b bitstring:from-string "1010"
      report bitstring:count1 (a bitstring:xor b)
    end
    to-report do-not
      let a bitstring:from-string "1100"
      report bitstring:count1 bitstring:not a
    end
    to-report do-parity
      let a bitstring:from-string "1100"
      let b bitstring:from-string "1010"
      report bitstring:count1 (a bitstring:parity b)
    end
    to-report do-right-shift
      let a bitstring:from-string "1000"
      let b bitstring:right-shift a
      report bitstring:get? b 1
    end
  """))
  @test call!(runtime, "do-and") == 1.0    # 1000
  @test call!(runtime, "do-or") == 3.0     # 1110
  @test call!(runtime, "do-xor") == 2.0    # 0110
  @test call!(runtime, "do-not") == 2.0    # 0011
  @test call!(runtime, "do-parity") == 2.0 # 1001
  @test call!(runtime, "do-right-shift") == true
end

@testset "bitstring: sub, but-first, but-last, cat" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    to-report do-sub
      let a bitstring:from-string "10110"
      let b bitstring:sub a 1 4
      report bitstring:length b
    end
    to-report do-but-first
      let a bitstring:from-string "100"
      let b bitstring:but-first a
      report bitstring:count1 b
    end
    to-report do-but-last
      let a bitstring:from-string "001"
      let b bitstring:but-last a
      report bitstring:count1 b
    end
    to-report do-cat
      let a bitstring:from-string "11"
      let b bitstring:from-string "00"
      let c bitstring:cat a b
      report bitstring:length c
    end
    to-report cat-count
      let a bitstring:from-string "11"
      let b bitstring:from-string "00"
      let c bitstring:cat a b
      report bitstring:count1 c
    end
  """))
  @test call!(runtime, "do-sub") == 3.0
  @test call!(runtime, "do-but-first") == 0.0
  @test call!(runtime, "do-but-last") == 0.0
  @test call!(runtime, "do-cat") == 4.0
  @test call!(runtime, "cat-count") == 2.0
end

@testset "bitstring: contains and match" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    to-report do-contains-yes
      let a bitstring:from-string "110100"
      let b bitstring:from-string "101"
      report a bitstring:contains? b
    end
    to-report do-contains-no
      let a bitstring:from-string "110100"
      let b bitstring:from-string "111"
      report a bitstring:contains? b
    end
    to-report do-match
      let a bitstring:from-string "1100"
      let b bitstring:from-string "1010"
      report a bitstring:match b
    end
  """))
  @test call!(runtime, "do-contains-yes") == true
  @test call!(runtime, "do-contains-no") == false
  @test call!(runtime, "do-match") == 2.0
end

@testset "bitstring: genetic operators" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    to-report do-toggle
      let a bitstring:from-string "0000"
      let b bitstring:toggle a 2
      report bitstring:get? b 2
    end
    to-report do-crossover
      let a bitstring:make 6 false
      let b bitstring:make 6 true
      let result bitstring:crossover a b 3
      let c1 item 0 result
      let c2 item 1 result
      report (list bitstring:count1 c1 bitstring:count1 c2)
    end
    to-report do-fput
      let a bitstring:from-string "000"
      let b bitstring:fput a true
      report (list bitstring:length b bitstring:first? b)
    end
    to-report do-lput
      let a bitstring:from-string "000"
      let b bitstring:lput a true
      report (list bitstring:length b bitstring:last? b)
    end
  """))
  @test call!(runtime, "do-toggle") == true
  @test call!(runtime, "do-crossover") == Any[3.0, 3.0]
  @test call!(runtime, "do-fput") == Any[4.0, true]
  @test call!(runtime, "do-lput") == Any[4.0, true]
end

@testset "bitstring: random and gray code" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    to-report do-random
      let a bitstring:random 100 0.5
      report bitstring:length a
    end
    to-report gray-round-trip
      let a bitstring:from-string "10110"
      let g bitstring:gray-code a
      let b bitstring:inverse-gray-code g
      report a bitstring:match b
    end
  """); seed=42)
  @test call!(runtime, "do-random") == 100.0
  @test call!(runtime, "gray-round-trip") == 5.0  # perfect round-trip
end

@testset "bitstring: string representation" begin
  runtime = create_runtime(compile_model("""
    extensions [bitstring]
    to-report bs-word
      let a bitstring:from-string "101"
      report word "" a
    end
  """))
  @test call!(runtime, "bs-word") == "{{bitstring: 101}}"
end
