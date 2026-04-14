using Test
using NetLogo

# Define a tiny test extension for the "extensions support" testset below
module Testext
  using NetLogo: PrimitiveRegistry, register_primitive!, COMMAND, REPORTER,
                 command_syntax, reporter_syntax, NumberType

  function register_primitives!(registry::PrimitiveRegistry)
      register_primitive!(registry, "TESTEXT:STORE", COMMAND,
          command_syntax(right=[NumberType]),
          (ctx, args) -> begin
              ctx.runtime.world.observer.globals["EXTENSION-VALUE"] = args[1]
              nothing
          end)
      register_primitive!(registry, "TESTEXT:DOUBLE", REPORTER,
          reporter_syntax(right=[NumberType], ret=NumberType),
          (ctx, args) -> Float64(args[1]) * 2.0)
  end
end

@testset "integration: basic runtime execution" begin
  runtime = create_runtime(netlogo"""
  globals [steps]

  to setup
    clear-all
    set steps 0
    crt 3 [
      setxy 0 0
      set heading 0
    ]
    reset-ticks
  end

  to go
    ask turtles [
      rt 90
      fd 1
    ]
    set steps steps + 1
    tick
  end
  """; seed=7)

  call!(runtime, "setup")
  @test length(runtime.world.turtles) == 3
  @test runtime.world.observer.globals["STEPS"] == 0.0
  @test runtime.world.ticks == 0.0
  @test all(t -> t.xcor == 0.0 && t.ycor == 0.0, runtime.world.turtles)

  call!(runtime, "go")
  @test runtime.world.observer.globals["STEPS"] == 1.0
  @test runtime.world.ticks == 1.0
  @test all(t -> t.xcor == 1.0 && t.ycor == 0.0, runtime.world.turtles)
  @test runtime.world.turtles[1].heading == 90.0
end

@testset "integration: includes support" begin
  base_dir = mktempdir()
  main_path = joinpath(base_dir, "main.nlogo")
  helpers_path = joinpath(base_dir, "helpers.nls")
  nested_dir = joinpath(base_dir, "nested")
  math_path = joinpath(nested_dir, "math.nls")

  mkpath(nested_dir)

  write(math_path, """
  to-report bonus
    report 3
  end
  """)
  write(helpers_path, """
  __includes ["nested/math.nls"]
  globals [delta]
  turtles-own [energy]

  to-report included-total [n]
    report n + bonus + delta
  end

  to seed-energy
    crt 1
    ask turtle 0 [ set energy bonus ]
  end
  """)
  write(main_path, """
  __includes ["helpers.nls"]
  globals [result]

  to setup
    clear-all
    set delta 2
    set result included-total 4
    seed-energy
  end
  """)

  try
    runtime = create_runtime(load_model(main_path); seed=19)
    call!(runtime, "setup")
    @test runtime.world.observer.globals["DELTA"] == 2.0
    @test runtime.world.observer.globals["RESULT"] == 9.0
    @test length(runtime.world.turtles) == 1
    @test runtime.world.turtles[1].own["ENERGY"] == 3.0
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: extensions support" begin
  runtime = create_runtime(netlogo"""
  extensions [testext]
  globals [extension-value result]

  to setup
    clear-all
    testext:store 11
    set result testext:double 6
  end
  """; seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["EXTENSION-VALUE"] == 11.0
  @test runtime.world.observer.globals["RESULT"] == 12.0
end

@testset "integration: breeds, reporter blocks, and spatial queries" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy]
  patches-own [occupied]
  globals [energy-snapshot]

  to setup
    clear-all
    ask patches [
      set occupied false
    ]
    create-wolves 3 [
      set energy who + 1
      set heading 0
      setxy who 0
    ]
    ask patches with [any? turtles-here] [
      set occupied true
    ]
    set energy-snapshot [energy] of wolves
    reset-ticks
  end

  to go
    repeat 2 [
      ask wolves with [energy > 1] [
        fd 1
        set energy energy + 1
      ]
      tick
    ]
  end

  to-report occupied-patch-count
    report count patches with [occupied]
  end

  to-report origin-occupants
    report count [turtles-here] of patch 0 0
  end
  """; seed=11)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["ENERGY-SNAPSHOT"] == Any[1.0, 2.0, 3.0]
  @test call!(runtime, "occupied-patch-count") == 3.0
  @test call!(runtime, "origin-occupants") == 1.0
  @test all(t -> t.breed == "WOLVES", runtime.world.turtles)
  @test [t.own["ENERGY"] for t in runtime.world.turtles] == [1.0, 2.0, 3.0]

  call!(runtime, "go")

  @test runtime.world.ticks == 2.0
  @test [t.own["ENERGY"] for t in runtime.world.turtles] == [1.0, 4.0, 5.0]
  @test [t.ycor for t in runtime.world.turtles] == [0.0, 2.0, 2.0]
end

@testset "integration: links and link breeds" begin
  runtime = create_runtime(netlogo"""
  undirected-link-breed [roads road]
  roads-own [capacity]
  directed-link-breed [streets street]
  streets-own [flow]
  globals [road-capacities street-flows]

  to setup
    clear-all
    crt 3 [ setxy who 0 ]
    ask turtle 0 [
      create-link-with turtle 1
      create-roads-with other turtles [
        set capacity 5
      ]
    ]
    ask turtle 1 [
      create-street-to turtle 2 [
        set flow 7
      ]
    ]
    set road-capacities [capacity] of roads
    set street-flows [flow] of streets
    reset-ticks
  end

  to-report road-count
    report count roads
  end

  to-report all-link-count
    report count links
  end

  to-report my-link-count
    report count [my-links] of turtle 1
  end

  to-report my-road-count
    report count [my-roads] of turtle 0
  end

  to-report road-neighbor-count
    report count [road-neighbors] of turtle 0
  end

  to-report street-out-neighbor-count
    report count [out-street-neighbors] of turtle 1
  end

  to-report my-street-count
    report count [my-streets] of turtle 1
  end
  """; seed=19)

  call!(runtime, "setup")

  @test call!(runtime, "road-count") == 2.0
  @test call!(runtime, "all-link-count") == 4.0
  @test call!(runtime, "my-link-count") == 3.0
  @test call!(runtime, "my-road-count") == 2.0
  @test call!(runtime, "road-neighbor-count") == 2.0
  @test call!(runtime, "street-out-neighbor-count") == 1.0
  @test call!(runtime, "my-street-count") == 1.0
  @test runtime.world.observer.globals["ROAD-CAPACITIES"] == Any[5.0, 5.0]
  @test runtime.world.observer.globals["STREET-FLOWS"] == Any[7.0]
end

@testset "integration: neighborhoods and diffusion" begin
  runtime = create_runtime(netlogo"""
  patches-own [heat]
  globals [neighbor-count neighbor4-count origin-heat east-heat northeast-heat]

  to setup
    clear-all
    ask patches [ set heat 0 ]
    ask patch 0 0 [ set heat 8 ]
    set neighbor-count count [neighbors] of patch 0 0
    set neighbor4-count count [neighbors4] of patch 0 0
    diffuse heat 0.5
    set origin-heat [heat] of patch 0 0
    set east-heat [heat] of patch 1 0
    set northeast-heat [heat] of patch 1 1
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=3)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["NEIGHBOR-COUNT"] == 8.0
  @test runtime.world.observer.globals["NEIGHBOR4-COUNT"] == 4.0
  @test runtime.world.observer.globals["ORIGIN-HEAT"] == 4.0
  @test runtime.world.observer.globals["EAST-HEAT"] == 0.5
  @test runtime.world.observer.globals["NORTHEAST-HEAT"] == 0.5
end

@testset "integration: aggregation and selection reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy]
  patches-own [heat]
  globals [
    energy-total energy-mean weakest-who strongest-energy hottest-heat
    top-pack-count bottom-pack-count sample-count oversample-count
  ]

  to setup
    clear-all
    ask patches [
      set heat ((pxcor + 2) * 10) + (pycor + 2)
    ]
    create-wolves 4 [
      set energy item who [3 7 7 2]
      setxy 0 0
    ]
    set energy-total sum [energy] of wolves
    set energy-mean mean [energy] of wolves
    set weakest-who [who] of min-one-of wolves [energy]
    set strongest-energy [energy] of max-one-of wolves [energy]
    set hottest-heat [heat] of max-one-of patches [heat]
    set top-pack-count count wolves with-max [energy]
    set bottom-pack-count count wolves with-min [energy]
    set sample-count count n-of 2 wolves
    set oversample-count count up-to-n-of 10 wolves
  end

  to-report hottest-patch-x
    report [pxcor] of max-one-of patches [heat]
  end

  to-report weakest-energy
    report [energy] of min-one-of wolves [energy]
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=13)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["ENERGY-TOTAL"] == 19.0
  @test runtime.world.observer.globals["ENERGY-MEAN"] == 4.75
  @test runtime.world.observer.globals["WEAKEST-WHO"] == 3.0
  @test runtime.world.observer.globals["STRONGEST-ENERGY"] == 7.0
  @test runtime.world.observer.globals["HOTTEST-HEAT"] == 33.0
  @test runtime.world.observer.globals["TOP-PACK-COUNT"] == 2.0
  @test runtime.world.observer.globals["BOTTOM-PACK-COUNT"] == 1.0
  @test runtime.world.observer.globals["SAMPLE-COUNT"] == 2.0
  @test runtime.world.observer.globals["OVERSAMPLE-COUNT"] == 4.0
  @test call!(runtime, "hottest-patch-x") == 1.0
  @test call!(runtime, "weakest-energy") == 2.0
end

@testset "integration: list sorting and membership reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy]
  globals [
    sorted-energies unique-energies has-middle-wolf has-sorted-middle-wolf
    wolf-two-index trimmed-name pruned-energies first-patch-x first-patch-y
    first-wolf-who
  ]

  to setup
    clear-all
    create-wolves 3 [
      set energy item who [5 2 5]
      setxy 0 0
    ]
    set sorted-energies sort [energy] of wolves
    set unique-energies remove-duplicates [energy] of wolves
    set has-middle-wolf member? turtle 1 wolves
    set has-sorted-middle-wolf member? turtle 1 sort wolves
    set wolf-two-index position turtle 2 sort wolves
    set trimmed-name remove "a" "bananas"
    let sorted-energy-list sort [energy] of wolves
    set pruned-energies remove-item 1 sorted-energy-list
    set first-patch-x [pxcor] of item 0 sort patches
    set first-patch-y [pycor] of item 0 sort patches
    set first-wolf-who [who] of item 0 sort wolves
  end

  to-report has-string-fragment
    report member? "rin" "string"
  end

  to-report sorted-energy-position
    report position 5 sorted-energies
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=23)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SORTED-ENERGIES"] == Any[2.0, 5.0, 5.0]
  @test runtime.world.observer.globals["UNIQUE-ENERGIES"] == Any[5.0, 2.0]
  @test runtime.world.observer.globals["HAS-MIDDLE-WOLF"] == true
  @test runtime.world.observer.globals["HAS-SORTED-MIDDLE-WOLF"] == true
  @test runtime.world.observer.globals["WOLF-TWO-INDEX"] == 2.0
  @test runtime.world.observer.globals["TRIMMED-NAME"] == "bnns"
  @test runtime.world.observer.globals["PRUNED-ENERGIES"] == Any[2.0, 5.0]
  @test runtime.world.observer.globals["FIRST-PATCH-X"] == -1.0
  @test runtime.world.observer.globals["FIRST-PATCH-Y"] == 1.0
  @test runtime.world.observer.globals["FIRST-WOLF-WHO"] == 0.0
  @test call!(runtime, "has-string-fragment") == true
  @test call!(runtime, "sorted-energy-position") == 1.0
end

@testset "integration: advanced list and string reporters" begin
  escaped_source = "\"\n\t\r\\"
  runtime = create_runtime(compile_model("""
  breed [wolves wolf]
  wolves-own [energy]
  globals [
    ranked-energies middle-energies inserted-energies revised-energies
    repaired-name reversed-name label-fragment escaped-source error-messages
  ]

  to setup
    clear-all
    create-wolves 4 [
      set energy item who [3 1 4 2]
      setxy 0 0
    ]
    set ranked-energies reverse sort [energy] of wolves
    set middle-energies sublist ranked-energies 1 3
    set inserted-energies insert-item 1 middle-energies 9
    set revised-energies replace-item 2 inserted-energies [energy] of turtle 0
    set repaired-name insert-item 1 "wlf" "o"
    set reversed-name reverse repaired-name
    set label-fragment substring repaired-name 0 4
    set escaped-source $(repr(escaped_source))
    set error-messages collection-error-messages-demo
  end

  to-report top-two-total
    let top-two sublist ranked-energies 0 2
    report sum top-two
  end

  to-report revised-tail
    report item 2 revised-energies
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
  """); seed=29)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["RANKED-ENERGIES"] == Any[4.0, 3.0, 2.0, 1.0]
  @test runtime.world.observer.globals["MIDDLE-ENERGIES"] == Any[3.0, 2.0]
  @test runtime.world.observer.globals["INSERTED-ENERGIES"] == Any[3.0, 9.0, 2.0]
  @test runtime.world.observer.globals["REVISED-ENERGIES"] == Any[3.0, 9.0, 3.0]
  @test runtime.world.observer.globals["REPAIRED-NAME"] == "wolf"
  @test runtime.world.observer.globals["REVERSED-NAME"] == "flow"
  @test runtime.world.observer.globals["LABEL-FRAGMENT"] == "wolf"
  @test runtime.world.observer.globals["ESCAPED-SOURCE"] == escaped_source
  @test runtime.world.observer.globals["ERROR-MESSAGES"] == Any[
    "-1 isn't greater than or equal to zero.",
    "Can't find element 3 of the list [1 2], which is only of length 2.",
    "INSERT-ITEM expected input to be a string but got the number 2 instead.",
    "Can't find element 3 of the string 123, which is only of length 3.",
    "Can't find element 4 of the list [2 7 4 5], which is only of length 4.",
    "Can't find element 1 of the list [1], which is only of length 1.",
    "List is empty.",
    "List is empty.",
  ]
  @test call!(runtime, "top-two-total") == 7.0
  @test call!(runtime, "revised-tail") == 3.0
end

@testset "integration: further list and string compatibility" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy]
  globals [
    trimmed-name clipped-name pack-middle pack-shell
    empty-tail? label-is-string?
  ]

  to setup
    clear-all
    create-wolves 3 [
      set energy item who [9 8 7]
      setxy 0 0
    ]
    let sorted-energies sort [energy] of wolves
    set pack-middle first butfirst sorted-energies
    set pack-shell last butlast sorted-energies
    set trimmed-name butfirst "alpha"
    set clipped-name butlast "alpha"
    set empty-tail? empty? butlast "a"
    set label-is-string? is-string? word "pack-" count wolves
  end

  to-report middle-tail-empty?
    report empty? butfirst [1]
  end

  to-report shortened-name
    report bf clipped-name
  end
  """; seed=67)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["TRIMMED-NAME"] == "lpha"
  @test runtime.world.observer.globals["CLIPPED-NAME"] == "alph"
  @test runtime.world.observer.globals["PACK-MIDDLE"] == 8.0
  @test runtime.world.observer.globals["PACK-SHELL"] == 8.0
  @test runtime.world.observer.globals["EMPTY-TAIL?"] == true
  @test runtime.world.observer.globals["LABEL-IS-STRING?"] == true
  @test call!(runtime, "middle-tail-empty?") == true
  @test call!(runtime, "shortened-name") == "lph"
end

@testset "integration: spatial and network query reporters" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [synapses synapse]
  synapses-own [weight]
  turtles-own [activation input-sum]
  globals [separation heading-to-target ahead-px ahead-py connected inbound outbound ends-count]

  to setup
    clear-all
    crt 3 [
      set activation item who [2 4 8]
      setxy item who [-1 1 0] item who [0 0 1]
    ]
    ask turtle 0 [
      create-synapse-to turtle 1 [ set weight 0.5 ]
    ]
    ask turtle 2 [
      create-synapse-to turtle 1 [ set weight 1.5 ]
    ]
    set separation [distance turtle 1] of turtle 0
    set heading-to-target [towards turtle 1] of turtle 0
    ask turtle 0 [
      set heading towards turtle 1
      set ahead-px [pxcor] of patch-ahead 1
      set ahead-py [pycor] of patch-ahead 1
    ]
    ask turtle 1 [
      set input-sum sum [weight * [activation] of other-end] of my-in-synapses
    ]
    set connected [link-neighbor? turtle 1] of turtle 0
    set inbound [in-link-neighbor? turtle 0] of turtle 1
    set outbound [out-link-neighbor? turtle 1] of turtle 0
    set ends-count count [both-ends] of one-of synapses
  end

  to-report input-total
    report [input-sum] of turtle 1
  end

  to-report target-heading-from-origin
    report [towardsxy 0 0] of patch 1 1
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=29)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SEPARATION"] == 2.0
  @test runtime.world.observer.globals["HEADING-TO-TARGET"] == 90.0
  @test runtime.world.observer.globals["AHEAD-PX"] == 0.0
  @test runtime.world.observer.globals["AHEAD-PY"] == 0.0
  @test runtime.world.observer.globals["CONNECTED"] == true
  @test runtime.world.observer.globals["INBOUND"] == true
  @test runtime.world.observer.globals["OUTBOUND"] == true
  @test runtime.world.observer.globals["ENDS-COUNT"] == 2.0
  @test call!(runtime, "input-total") == 13.0
  @test call!(runtime, "target-heading-from-origin") == 225.0
end

@testset "integration: patch-ahead variants" begin
  runtime = create_runtime(netlogo"""
  globals [right-match left-match patch-target box-missing torus-target]

  to setup
    clear-all
    crt 1 [ setxy 0 0 set heading 0 ]
    ask turtle 0 [
      let right-target patch-right-and-ahead 90 1
      rt 90
      fd 1
      set right-match right-target = patch-here
      home
      set heading 0
      let left-target patch-left-and-ahead 90 1
      lt 90
      fd 1
      set left-match left-target = patch-here
    ]
    let patch-target-patch [patch-at-heading-and-distance 45 1.5] of patch 0 0
    set patch-target (list [pxcor] of patch-target-patch [pycor] of patch-target-patch)
    let missing-patch [patch-at-heading-and-distance 90 2] of patch 1 1
    set box-missing missing-patch = nobody
    set-topology true true
    let torus-target-patch [patch-at-heading-and-distance 90 2] of patch 1 1
    set torus-target (list [pxcor] of torus-target-patch [pycor] of torus-target-patch)
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=14)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["RIGHT-MATCH"] == true
  @test runtime.world.observer.globals["LEFT-MATCH"] == true
  @test runtime.world.observer.globals["PATCH-TARGET"] == Any[1.0, 1.0]
  @test runtime.world.observer.globals["BOX-MISSING"] == true
  @test runtime.world.observer.globals["TORUS-TARGET"] == Any[0.0, 1.0]
end

@testset "integration: movement vector helpers" begin
  runtime = create_runtime(netlogo"""
  globals [cardinal-vectors patch-ahead-match facexy-heading link-heading-error link-heading-match]

  to cardinal-vectors-demo
    clear-all
    crt 4 [ set heading who * 90 ]
    set cardinal-vectors map [ t -> [ (list dx dy) ] of t ] (sort turtles)
  end

  to patch-ahead-demo
    clear-all
    random-seed 223
    crt 8 [ set heading who * 45 ]
    set patch-ahead-match not any? turtles with [ patch-ahead 3 != patch-at (dx * 3) (dy * 3) ]
  end

  to facexy-demo
    clear-all
    crt 1
    ask turtle 0 [ setxy 4 4 ]
    ask turtle 0 [ facexy 0 0 ]
    set facexy-heading [heading] of turtle 0
  end

  to link-heading-demo
    clear-all
    cro 2
    ask turtle 0 [ create-link-with turtle 1 ]
    set link-heading-error ""
    carefully [ set link-heading-error link-heading-value ] [ set link-heading-error error-message ]
    ask turtle 0 [ fd 5 ]
    let the-link link 0 1
    let end-one [end1] of the-link
    let end-two [end2] of the-link
    set link-heading-match [link-heading] of the-link = [towards end-two] of end-one
  end

  to-report link-heading-value
    report [link-heading] of link 0 1
  end
  """; seed=15)

  call!(runtime, "cardinal-vectors-demo")
  @test runtime.world.observer.globals["CARDINAL-VECTORS"] == Any[
    Any[0.0, 1.0],
    Any[1.0, 0.0],
    Any[0.0, -1.0],
    Any[-1.0, 0.0],
  ]

  call!(runtime, "patch-ahead-demo")
  @test runtime.world.observer.globals["PATCH-AHEAD-MATCH"] == true

  call!(runtime, "facexy-demo")
  @test runtime.world.observer.globals["FACEXY-HEADING"] == 225.0

  call!(runtime, "link-heading-demo")
  @test runtime.world.observer.globals["LINK-HEADING-ERROR"] == "there is no heading of a link whose endpoints are in the same position"
  @test runtime.world.observer.globals["LINK-HEADING-MATCH"] == true
end

@testset "integration: layout-circle command" begin
  runtime = create_runtime(netlogo"""
  globals [single-position sorted-endpoints random-ordered centered-back zero-collapse]

  to single-demo
    clear-all
    crt 1
    layout-circle turtles max-pxcor
    set single-position (list [precision xcor 12] of turtle 0 [precision ycor 12] of turtle 0)
  end

  to sorted-demo
    clear-all
    crt 10
    layout-circle (sort turtles) 5
    let p0 (list [precision xcor 12] of turtle 0 [precision ycor 12] of turtle 0)
    let p5 (list [precision xcor 12] of turtle 5 [precision ycor 12] of turtle 5)
    set sorted-endpoints (list p0 p5)
  end

  to random-demo
    clear-all
    random-seed 8123
    crt 10
    layout-circle turtles 5
    let ordered (sort-by [[t1 t2] -> [heading] of t1 < [heading] of t2] turtles)
    let sorted (sort turtles)
    set random-ordered ordered = sorted
    ask turtles [ bk 5 ]
    set centered-back (list remove-duplicates [precision xcor 14] of turtles remove-duplicates [precision ycor 14] of turtles)
    layout-circle turtles 0
    set zero-collapse (list remove-duplicates [precision xcor 14] of turtles remove-duplicates [precision ycor 14] of turtles)
  end
  """; min_pxcor=-10, max_pxcor=10, min_pycor=-10, max_pycor=10, topology=Torus, seed=8123)

  call!(runtime, "single-demo")
  @test runtime.world.observer.globals["SINGLE-POSITION"] == Any[0.0, 10.0]

  call!(runtime, "sorted-demo")
  @test runtime.world.observer.globals["SORTED-ENDPOINTS"] == Any[Any[0.0, 5.0], Any[0.0, -5.0]]

  call!(runtime, "random-demo")
  @test runtime.world.observer.globals["RANDOM-ORDERED"] == false
  @test runtime.world.observer.globals["CENTERED-BACK"] == Any[Any[0.0], Any[0.0]]
  @test runtime.world.observer.globals["ZERO-COLLAPSE"] == Any[Any[0.0], Any[0.0]]
end

@testset "integration: layout-radial command" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]
  globals [star-distance outer-ring-sum inner-ring-sum breed-layout filtered-layout excluded-position]

  to star-demo
    clear-all
    resize-world (-16) 16 (-16) 16
    crt 10
    ask turtle 0 [ create-links-with other turtles ]
    layout-radial turtles links (turtle 0)
    set star-distance sum [distance turtle 0] of turtles
  end

  to layered-demo
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
    set outer-ring-sum sum [distancexy 0 0] of outer
    set inner-ring-sum sum [distancexy 0 0] of inner
  end

  to filtered-demo
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
    set breed-layout (list breed-p0 breed-p1 breed-p2)
    layout-radial turtles (links with [breed = undirected-edges]) (turtle 0)
    let filtered-p0 (list [precision xcor 12] of turtle 0 [precision ycor 12] of turtle 0)
    let filtered-p1 (list [precision xcor 12] of turtle 1 [precision ycor 12] of turtle 1)
    let filtered-p2 (list [precision xcor 12] of turtle 2 [precision ycor 12] of turtle 2)
    set filtered-layout (list filtered-p0 filtered-p1 filtered-p2)
  end

  to excluded-demo
    clear-all
    resize-world (-5) 5 (-5) 5
    crt 3
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    ask turtle 2 [ setxy 5 5 ]
    let subset (turtle-set turtle 0 turtle 1)
    layout-radial subset links (turtle 0)
    set excluded-position (list [precision xcor 12] of turtle 2 [precision ycor 12] of turtle 2)
  end
  """; min_pxcor=-5, max_pxcor=5, min_pycor=-5, max_pycor=5, topology=Torus, seed=100)

  call!(runtime, "star-demo")
  @test runtime.world.observer.globals["STAR-DISTANCE"] ≈ 120.0

  call!(runtime, "layered-demo")
  @test runtime.world.observer.globals["OUTER-RING-SUM"] ≈ 392.72727272727275
  @test runtime.world.observer.globals["INNER-RING-SUM"] ≈ 65.45454545454545

  call!(runtime, "filtered-demo")
  expected_layout = Any[Any[0.0, 0.0], Any[0.0, -2.272727272727], Any[0.0, -4.545454545455]]
  @test runtime.world.observer.globals["BREED-LAYOUT"] == expected_layout
  @test runtime.world.observer.globals["FILTERED-LAYOUT"] == expected_layout

  call!(runtime, "excluded-demo")
  @test runtime.world.observer.globals["EXCLUDED-POSITION"] == Any[5.0, 5.0]
end

@testset "integration: layout-tutte command" begin
  runtime = create_runtime(netlogo"""
  globals [anchor-distances]

  to setup
    clear-all
    resize-world (-16) 16 (-16) 16
    crt 4
    ask turtles [ create-links-with other turtles ]
    let interior turtles with [who >= 3]
    layout-tutte interior links 5
    let anchors turtles with [who < 3]
    set anchor-distances sort [precision distance turtle 3 11] of anchors
  end
  """; min_pxcor=-5, max_pxcor=5, min_pycor=-5, max_pycor=5, topology=Torus, seed=100)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["ANCHOR-DISTANCES"] == Any[5.0, 5.0, 5.0]
end

@testset "integration: layout-spring command" begin
  runtime = create_runtime(netlogo"""
  globals [filtered-turtles filtered-links motion-limit unchanged]

  to filtered-turtles-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    crt 3
    ask turtle 0 [ setxy 0 0 set color red ]
    ask turtle 1 [ setxy 2 0 set color red ]
    ask turtle 2 [ setxy 4 0 set color blue ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    let p0 nobody
    let p1 nobody
    let p2 nobody
    layout-spring turtles with [ color = red ] links 0.1 1 0
    set p0 (list [precision xcor 6] of turtle 0 [precision ycor 6] of turtle 0)
    set p1 (list [precision xcor 6] of turtle 1 [precision ycor 6] of turtle 1)
    set p2 (list [precision xcor 6] of turtle 2 [precision ycor 6] of turtle 2)
    set filtered-turtles (list p0 p1 p2)
  end

  to filtered-links-demo
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
    set filtered-links (list p0 p1 p2)
  end

  to motion-limit-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    crt 2
    ask turtle 0 [ setxy (-10) 0 ]
    ask turtle 1 [ setxy 10 0 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    layout-spring turtles links 10 0 0
    let p0 (list [precision xcor 6] of turtle 0 [precision ycor 6] of turtle 0)
    let p1 (list [precision xcor 6] of turtle 1 [precision ycor 6] of turtle 1)
    set motion-limit (list p0 p1)
  end

  to no-turtles-demo
    clear-all
    resize-world (-10) 10 (-10) 10
    random-seed 100
    crt 5 [ setxy random-xcor random-ycor ]
    ask turtles [ create-links-with other turtles ]
    let before map [ t -> [ list [precision xcor 12] of t [precision ycor 12] of t ] ] sort turtles
    layout-spring no-turtles links 0.2 5 0.2
    let after map [ t -> [ list [precision xcor 12] of t [precision ycor 12] of t ] ] sort turtles
    set unchanged before = after
  end
  """; min_pxcor=-10, max_pxcor=10, min_pycor=-10, max_pycor=10, topology=Torus, seed=100)

  call!(runtime, "filtered-turtles-demo")
  @test runtime.world.observer.globals["FILTERED-TURTLES"] == Any[Any[0.066667, 0.0], Any[2.033333, 0.0], Any[4.0, 0.0]]

  call!(runtime, "filtered-links-demo")
  @test runtime.world.observer.globals["FILTERED-LINKS"] == Any[Any[0.1, 0.0], Any[1.9, 0.0], Any[4.0, 0.0]]

  call!(runtime, "motion-limit-demo")
  @test runtime.world.observer.globals["MOTION-LIMIT"] == Any[Any[-9.16, 0.0], Any[9.16, 0.0]]

  call!(runtime, "no-turtles-demo")
  @test runtime.world.observer.globals["UNCHANGED"] == true
end

@testset "integration: file helper primitives" begin
  base_dir = mktempdir()
  target_dir = joinpath(base_dir, "integration", "mkdir-target")
  runtime = create_runtime(compile_model("""
  globals [mkdir-path nanotime-is-number]

  to setup
    set mkdir-path $(repr(target_dir))
    __mkdir mkdir-path
    set nanotime-is-number is-number? __nano-time
  end
  """); seed=1)

  try
    call!(runtime, "setup")
    @test runtime.world.observer.globals["NANOTIME-IS-NUMBER"] == true
    @test runtime.world.observer.globals["MKDIR-PATH"] == target_dir
    @test isdir(target_dir)
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: file io primitives" begin
  base_dir = mktempdir()
  primary_path = joinpath(base_dir, "integration-file-io.txt")
  secondary_path = joinpath(base_dir, "integration-file-io-2.txt")
  whitespace_path = joinpath(base_dir, "integration-file-whitespace.txt")
  bad_token_path = joinpath(base_dir, "integration-file-bad-token.txt")
  big_number_path = joinpath(base_dir, "integration-file-big-number.txt")
  utf8_path = joinpath(base_dir, "integration-file-utf8.txt")
  utf8_text = "\u3053\u3093\u306b\u3061\u306f\U0001f422"
  big_number_text = "598745879457894578945789457894578945789"
  runtime = create_runtime(compile_model("""
  globals [
    primary-path secondary-path whitespace-path bad-token-path big-number-path utf8-path
    line-results write-results whitespace-results bad-token-message big-number-message utf8-value multi-results
  ]

  to setup
    set primary-path $(repr(primary_path))
    set secondary-path $(repr(secondary_path))
    set whitespace-path $(repr(whitespace_path))
    set bad-token-path $(repr(bad_token_path))
    set big-number-path $(repr(big_number_path))
    set utf8-path $(repr(utf8_path))
    set line-results line-reading-demo
    set write-results write-read-demo
    set whitespace-results whitespace-at-end-demo
    set bad-token-message bad-token-message-demo
    set big-number-message big-number-message-demo
    set utf8-value utf8-demo
    set multi-results multi-file-demo
  end

  to-report line-reading-demo
    if file-exists? primary-path [ file-delete primary-path ]
    file-open primary-path
    file-print "first line"
    file-show "2nd line"
    file-type "3rd line"
    let mode-error ""
    carefully [ __ignore file-read ] [ set mode-error error-message ]
    file-close
    file-open primary-path
    let result (list file-read-line file-read-line file-read-characters 4 file-read-line file-at-end? mode-error)
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
    call!(runtime, "setup")
    @test runtime.world.observer.globals["LINE-RESULTS"] == Any[
      "first line",
      "observer: \"2nd line\"",
      "3rd ",
      "line",
      true,
      "You can only use WRITING primitives with this file",
    ]
    @test runtime.world.observer.globals["WRITE-RESULTS"] == Any[
      11.0,
      "Once upon a time",
      Any[1.0, -2.0, 5.0, "this is a string", true],
      "true 5",
      true,
    ]
    @test runtime.world.observer.globals["WHITESPACE-RESULTS"] == Any[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, true]
    @test runtime.world.observer.globals["BAD-TOKEN-MESSAGE"] == "Expected a literal value. (line number 1, character 3)"
    @test runtime.world.observer.globals["BIG-NUMBER-MESSAGE"] ==
      "$(big_number_text) is too large to be represented exactly as an integer in NetLogo (line number 1, character 1)"
    @test runtime.world.observer.globals["UTF8-VALUE"] == utf8_text
    @test runtime.world.observer.globals["MULTI-RESULTS"] == Any["alpha gamma", "beta"]
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: output, wait, and modes helpers" begin
  runtime = create_runtime(compile_model("""
  globals [modes-basic modes-complex modes-empty modes-mixed wait-value]

  to setup
    clear-all
    set modes-basic modes [1 2 3 3 1 2 3]
    set modes-complex modes [0 0 [1 2 3 4 5] [1 2 [3 4 5]] [1 [2 3] 4 5] [1 2 [3 4 5]] 1 1 2]
    set modes-empty modes []
    crt 2
    set modes-mixed (list length modes (list turtle 0 turtle 1 turtle 0) [who] of first modes (list turtle 0 turtle 1 turtle 0))
    type "alpha"
    type 7
    print (list 1 2)
    show "beta"
    write "gamma"
    ask turtle 0 [ show "hi" ]
    ask turtles [ die ]
    let post-modes modes (list 5 5 5 5 turtle 0 turtle 1 turtle 2 nobody)
    set modes-mixed (list item 0 modes-mixed item 1 modes-mixed post-modes)
    reset-timer
    wait 0.05
    set wait-value timer
  end
  """); seed=1)

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
  @test runtime.command_output == "alpha7[1 2]\nobserver: \"beta\"\n \"gamma\"turtle 0: \"hi\"\n"
end

@testset "integration: output area commands" begin
  base_dir = mktempdir()
  output_path = joinpath(base_dir, "output.txt")
  world_path = joinpath(base_dir, "world.bin")
  runtime = create_runtime(compile_model("""
  to setup-output-area
    clear-all
    output-type "alpha"
    output-type 7
    output-print (list 1 2)
    output-show "beta"
    output-write "gamma"
  end

  to export-output-demo [file]
    clear-output
    output-type "alpha"
    output-write "beta"
    output-print "gamma"
    output-show "delta"
    export-output file
  end

  to setup-turtle-output-area
    clear-all
    crt 1 [ output-show "hi" ]
  end

  to persist-output-demo [file]
    clear-all
    output-print "This is a test of output areas."
    export-world file
    clear-all
    import-world file
  end
  """); seed=275)

  try
    call!(runtime, "setup-output-area")
    @test runtime.output_area == "alpha7[1 2]\nobserver: \"beta\"\n \"gamma\""

    call!(runtime, "setup-turtle-output-area")
    @test runtime.output_area == "turtle 0: \"hi\"\n"

    call!(runtime, "export-output-demo", output_path)
    @test read(output_path, String) == "alpha \"beta\"gamma\nobserver: \"delta\"\n"

    call!(runtime, "persist-output-demo", world_path)
    @test runtime.output_area == "This is a test of output areas.\n"
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: headless user primitives" begin
  runtime = create_runtime(compile_model("""
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
  """); seed=1)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["YESNO-ERROR"] == "model halted by user"
  @test runtime.world.observer.globals["ONEOF-ERROR"] == "model halted by user"
  @test runtime.world.observer.globals["INPUT-ERROR"] == "model halted by user"
  @test runtime.world.observer.globals["FILE-VALUE"] == false
  @test runtime.world.observer.globals["NEWFILE-VALUE"] == false
  @test runtime.world.observer.globals["DIR-VALUE"] == false
end

@testset "integration: range reporter" begin
  runtime = create_runtime(compile_model("""
  globals [range-basic range-map-empty range-map-one range-map-two range-map-three range-zero-step range-too-many]

  to setup
    set range-basic (list (range 5) (range 2 5) (range 2 5 0.5) (range 5 0 -1) (range 0 5 -1) (range 0.5 2.51 0.5))
    set range-map-empty (map range)
    set range-map-one (map range [10])
    set range-map-two (map range [10] [20])
    set range-map-three (map range [10] [40] [2])
    set range-zero-step ""
    set range-too-many ""
    carefully [ set range-zero-step (range 0 5 0) ] [ set range-zero-step error-message ]
    carefully [ set range-too-many (map range [10] [40] [2] [0]) ] [ set range-too-many error-message ]
  end
  """); seed=1)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["RANGE-BASIC"] == Any[
    Any[0.0, 1.0, 2.0, 3.0, 4.0],
    Any[2.0, 3.0, 4.0],
    Any[2.0, 2.5, 3.0, 3.5, 4.0, 4.5],
    Any[5.0, 4.0, 3.0, 2.0, 1.0],
    Any[],
    Any[0.5, 1.0, 1.5, 2.0, 2.5],
  ]
  @test runtime.world.observer.globals["RANGE-MAP-EMPTY"] == Any[]
  @test runtime.world.observer.globals["RANGE-MAP-ONE"] == Any[Any[0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0]]
  @test runtime.world.observer.globals["RANGE-MAP-TWO"] == Any[Any[10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0]]
  @test runtime.world.observer.globals["RANGE-MAP-THREE"] == Any[Any[10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 28.0, 30.0, 32.0, 34.0, 36.0, 38.0]]
  @test runtime.world.observer.globals["RANGE-ZERO-STEP"] == "The step-size for range must be non-zero."
  @test runtime.world.observer.globals["RANGE-TOO-MANY"] == "range expects at most three arguments"
end

@testset "integration: read-from-string reporter" begin
  escaped_literal = "\"\\n\\t\\\\\""
  runtime = create_runtime(compile_model("""
  globals [parsed-number parsed-list parsed-nobody parsed-pi parsed-paren parsed-escaped empty-error extra-error bracket-error paren-error]

  to setup
    set parsed-number read-demo "5"
    set parsed-list read-demo "[1 3.0]"
    set parsed-nobody read-demo "nobody"
    set parsed-pi read-demo "pi"
    set parsed-paren read-demo "(5)"
    set parsed-escaped read-demo $(repr(escaped_literal))
    set empty-error read-error-demo ""
    set extra-error read-error-demo "1 2"
    set bracket-error read-error-demo "[1 2 3"
    set paren-error read-error-demo "(5"
  end

  to-report read-demo [text]
    report read-from-string text
  end

  to-report read-error-demo [text]
    let result ""
    carefully [ __ignore read-from-string text ] [ set result error-message ]
    report result
  end
  """); seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["PARSED-NUMBER"] == 5.0
  @test runtime.world.observer.globals["PARSED-LIST"] == Any[1.0, 3.0]
  @test runtime.world.observer.globals["PARSED-NOBODY"] === NetLogo.NOBODY
  @test runtime.world.observer.globals["PARSED-PI"] == π
  @test runtime.world.observer.globals["PARSED-PAREN"] == 5.0
  @test runtime.world.observer.globals["PARSED-ESCAPED"] == "\n\t\\"
  @test runtime.world.observer.globals["EMPTY-ERROR"] == "Expected a literal value."
  @test runtime.world.observer.globals["EXTRA-ERROR"] == "Extra characters after literal."
  @test runtime.world.observer.globals["BRACKET-ERROR"] == "No closing bracket for this open bracket."
  @test runtime.world.observer.globals["PAREN-ERROR"] == "Expected a closing parenthesis."
end

@testset "integration: perspective commands" begin
  runtime = create_runtime(netlogo"""
  globals [subject-history me-history link-error]

  to setup
    clear-all
    crt 5
    set subject-history subject-history-demo
    clear-turtles
    reset-perspective
    crt 5
    set me-history me-history-demo
    clear-turtles
    reset-perspective
    set link-error follow-link-error-demo
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
    clear-turtles
    crt 2
    ask turtle 0 [ create-link-with turtle 1 ]
    let result ""
    carefully [ follow one-of links ] [ set result error-message ]
    report result
  end
  """; seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["SUBJECT-HISTORY"] == Any[-1.0, 0.0, 3.0, -1.0, 2.0, -1.0, 4.0, -1.0, 0.0, -1.0]
  @test runtime.world.observer.globals["ME-HISTORY"] == Any[0.0, 1.0, 2.0]
  @test runtime.world.observer.globals["LINK-ERROR"] ==
    "FOLLOW expected input to be a turtle but got the link (link 0 1) instead."
end

@testset "integration: special agentset dynamics" begin
  runtime = create_runtime(netlogo"""
  breed [frogs frog]
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]

  to-report turtles-dynamic-demo
    clear-all
    let glob1 turtles
    crt 10
    let glob2 turtles with [true]
    crt 10
    report (list count glob1 count glob2)
  end

  to-report breeds-dynamic-demo
    clear-all
    create-frogs 10
    let glob1 frogs
    let glob2 frogs with [true]
    let glob3 turtles
    create-frogs 10
    crt 10
    report (list count glob1 count glob2 count glob3)
  end

  to-report links-dynamic-demo
    clear-all
    create-frogs 10
    ask turtle 0 [ create-directed-edge-to turtle 1 ]
    ask turtle 1 [ create-undirected-edge-with turtle 2 ]
    let glob1 links
    let glob2 links with [true]
    let glob3 directed-edges
    ask turtle 2 [ create-undirected-edge-with turtle 3 ]
    ask turtle 3 [ create-directed-edge-to turtle 4 ]
    report (list count glob1 count glob2 count glob3)
  end

  to-report patches-dynamic-demo
    clear-all
    let glob1 patches
    resize-world (-1) 1 (-1) 1
    report count glob1
  end
  """; seed=1)

  @test call!(runtime, "turtles-dynamic-demo") == Any[20.0, 10.0]
  @test call!(runtime, "breeds-dynamic-demo") == Any[20.0, 10.0, 30.0]
  @test call!(runtime, "links-dynamic-demo") == Any[4.0, 2.0, 2.0]
  @test call!(runtime, "patches-dynamic-demo") == 9.0
end

@testset "integration: world import and export" begin
  base_dir = mktempdir()
  world_path = joinpath(base_dir, "world.bin")
  runtime = create_runtime(netlogo"""
  globals [counts order-ok utf8-value rgb-values glob1 glob2 glob3]
  breed [frogs frog]
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]

  to export-round-trip [file]
    export-world file
    clear-all
    import-world file
  end

  to setup-breeds [file]
    set counts breeds-export-demo file
  end

  to setup-links [file]
    set counts links-export-demo file
  end

  to setup-breed-order [file]
    set counts breed-order-demo file
  end

  to setup-link-order [file]
    set order-ok link-order-demo file
  end

  to setup-utf8 [file]
    set utf8-value utf8-export-demo file
  end

  to setup-rgb [file]
    set rgb-values rgb-export-demo file
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
    set utf8-value "AêñüC"
    export-round-trip file
    report utf8-value
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
    call!(runtime, "setup-breeds", world_path)
    @test runtime.world.observer.globals["COUNTS"] == Any[20.0, 10.0, 30.0]
    call!(runtime, "setup-links", world_path)
    @test runtime.world.observer.globals["COUNTS"] == Any[4.0, 2.0, 2.0]
    call!(runtime, "setup-breed-order", world_path)
    let result = runtime.world.observer.globals["COUNTS"]
      @test result[1] == result[2]
    end
    call!(runtime, "setup-link-order", world_path)
    @test runtime.world.observer.globals["ORDER-OK"] == true
    call!(runtime, "setup-utf8", world_path)
    @test runtime.world.observer.globals["UTF8-VALUE"] == "AêñüC"
    call!(runtime, "setup-rgb", world_path)
    @test runtime.world.observer.globals["RGB-VALUES"] == Any[
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

@testset "integration: export-world plot and RNG round-trip" begin
  base_dir = mktempdir()
  world_path = joinpath(base_dir, "world.bin")
  runtime = create_runtime(netlogo"""
  globals [ saved-random plot-pen-count rng-match ]

  to setup-and-export [file]
    clear-all
    set-current-plot "plot1"
    set-current-plot-pen "pen1"
    plot 10
    plot 20
    plot 30
    set saved-random random 1000
    output-print "preserved text"
    export-world file
  end

  to import-and-verify [file]
    clear-all
    import-world file
    let rng-val random 1000
    ; import again from same snapshot and check RNG determinism
    import-world file
    set rng-match (rng-val = random 1000)
    set plot-pen-count 0
    set-current-plot "plot1"
    if plot-pen-exists? "pen1" [ set plot-pen-count 1 ]
  end
  """; seed=99)

  try
    call!(runtime, "setup-and-export", world_path)
    saved_random = runtime.world.observer.globals["SAVED-RANDOM"]

    call!(runtime, "import-and-verify", world_path)
    @test runtime.world.observer.globals["SAVED-RANDOM"] == saved_random
    @test runtime.world.observer.globals["PLOT-PEN-COUNT"] == 1.0
    @test runtime.output_area == "preserved text\n"
    @test runtime.world.observer.globals["RNG-MATCH"] == true
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: patch color import commands" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  landscape_path = joinpath(fixture_dir, "import-pcolors-test.png")
  vertical_path = joinpath(fixture_dir, "import-pcolors-test-vertical.png")

  runtime = create_runtime(compile_model("""
  globals [numeric-values rgb-values landscape-colored topology-colored vertical-colored]

  to setup-exact-numeric
    resize-world 0 215 0 215
    import-pcolors $(repr(exact_path))
    set numeric-values (list
      [pcolor] of patch 0 215
      [pcolor] of patch 215 215
      [pcolor] of patch 0 0
      [pcolor] of patch 215 0
      [pcolor] of patch 108 107)
  end

  to setup-exact-rgb
    resize-world 0 215 0 215
    import-pcolors-rgb $(repr(exact_path))
    set rgb-values (list
      [pcolor] of patch 0 215
      [pcolor] of patch 215 215
      [pcolor] of patch 0 0
      [pcolor] of patch 215 0
      [pcolor] of patch 108 107)
  end

  to setup-landscape
    resize-world (-1) 1 (-100) 100
    import-pcolors $(repr(landscape_path))
    set landscape-colored count patches with [pcolor != 0]
  end

  to setup-landscape-topology
    resize-world 0 200 0 2
    import-pcolors $(repr(landscape_path))
    set topology-colored count patches with [pcolor != 0]
  end

  to setup-vertical
    resize-world (-100) 100 (-1) 1
    import-pcolors $(repr(vertical_path))
    set vertical-colored count patches with [pcolor != 0]
  end
  """); seed=313)

  call!(runtime, "setup-exact-numeric")
  @test runtime.world.observer.globals["NUMERIC-VALUES"] == Any[133.3, 107.3, 70.9, 120.9, 49.1]

  call!(runtime, "setup-exact-rgb")
  @test runtime.world.observer.globals["RGB-VALUES"] == Any[
    Any[138.0, 78.0, 92.0],
    Any[133.0, 158.0, 203.0],
    Any[6.0, 35.0, 27.0],
    Any[37.0, 6.0, 24.0],
    Any[251.0, 251.0, 214.0],
  ]

  call!(runtime, "setup-landscape")
  @test runtime.world.observer.globals["LANDSCAPE-COLORED"] > 0

  call!(runtime, "setup-landscape-topology")
  @test runtime.world.observer.globals["TOPOLOGY-COLORED"] > 0

  call!(runtime, "setup-vertical")
  @test runtime.world.observer.globals["VERTICAL-COLORED"] > 0
end

@testset "integration: drawing import commands" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  landscape_path = joinpath(fixture_dir, "import-pcolors-test.png")
  vertical_path = joinpath(fixture_dir, "import-pcolors-test-vertical.png")

  runtime = create_runtime(compile_model("""
  to setup-exact
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
  end

  to clear-exact
    clear-drawing
  end

  to rescale-exact
    set-patch-size 2
  end

  to clear-by-resize
    set-patch-size 1
    resize-world (-1) 1 (-100) 100
  end

  to setup-landscape
    resize-world (-1) 1 (-100) 100
    set-patch-size 1
    import-drawing $(repr(landscape_path))
  end

  to clear-by-clear-all
    clear-all
  end

  to setup-vertical
    resize-world (-100) 100 (-1) 1
    set-patch-size 1
    import-drawing $(repr(vertical_path))
  end
  """); seed=319)

  call!(runtime, "setup-exact")
  @test size(runtime.world.drawing) == (216, 216)
  @test runtime.world.drawing[109, 109] == (251.0, 251.0, 214.0, 255.0)

  call!(runtime, "clear-exact")
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "setup-exact")
  call!(runtime, "rescale-exact")
  @test size(runtime.world.drawing) == (432, 432)
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)

  call!(runtime, "clear-by-resize")
  @test size(runtime.world.drawing) == (201, 3)
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "setup-landscape")
  @test size(runtime.world.drawing) == (201, 3)
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)

  call!(runtime, "clear-by-clear-all")
  @test size(runtime.world.drawing) == (201, 3)
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0

  call!(runtime, "setup-vertical")
  @test size(runtime.world.drawing) == (3, 201)
  @test any(pixel -> pixel[4] > 0.0, runtime.world.drawing)
end

@testset "integration: export view command" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  base_dir = mktempdir()
  view_path = joinpath(base_dir, "view.png")
  agent_view_path = joinpath(base_dir, "agent-view.png")
  labeled_view_path = joinpath(base_dir, "labeled-view.png")
  torus_wrapped_view_path = joinpath(base_dir, "torus-wrapped-view.png")
  box_wrapped_view_path = joinpath(base_dir, "box-wrapped-view.png")
  runtime = create_runtime(compile_model("""
  globals [view-size]

  to setup-and-export [file]
    clear-all
    resize-world 0 215 0 215
    set-patch-size 1
    import-pcolors-rgb $(repr(exact_path))
    import-drawing $(repr(exact_path))
    export-view file
    set view-size (list world-width world-height)
  end

  to export-live-agents [file]
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
  """); seed=323)

  try
    call!(runtime, "setup-and-export", view_path)
    exported = NetLogo.FileIO.load(view_path)
    @test runtime.world.observer.globals["VIEW-SIZE"] == Any[216.0, 216.0]
    @test size(exported) == (216, 216)
    @test NetLogo.image_rgba_channels(exported[1, 1]) == (138.0, 78.0, 92.0, 255.0)
    @test NetLogo.image_rgba_channels(exported[109, 109]) == (251.0, 251.0, 214.0, 255.0)
    @test NetLogo.image_rgba_channels(exported[216, 216]) == (37.0, 6.0, 24.0, 255.0)

    call!(runtime, "export-live-agents", agent_view_path)
    agent_export = NetLogo.FileIO.load(agent_view_path)
    @test size(agent_export) == (3, 3)
    @test NetLogo.image_rgba_channels(agent_export[2, 1]) == (90.0, 100.0, 110.0, 255.0)
    @test NetLogo.image_rgba_channels(agent_export[2, 2]) == (4.0, 7.0, 9.0, 255.0)
    @test NetLogo.image_rgba_channels(agent_export[2, 3]) == (90.0, 100.0, 110.0, 255.0)
    @test NetLogo.image_rgba_channels(agent_export[1, 1]) == (1.0, 2.0, 3.0, 255.0)

    call!(runtime, "export-labeled-view", labeled_view_path)
    labeled_export = NetLogo.FileIO.load(labeled_view_path)
    @test size(labeled_export) == (25, 45)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), labeled_export[6:10, 8:10])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), labeled_export[14:18, 21:23])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), labeled_export[6:10, 38:40])

    call!(runtime, "export-wrapped-labeled-view", torus_wrapped_view_path, true, true)
    torus_wrapped_export = NetLogo.FileIO.load(torus_wrapped_view_path)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), torus_wrapped_export[6:10, 11:15])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), torus_wrapped_export[9:13, 1:3])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (220.0, 120.0, 20.0, 255.0), torus_wrapped_export[1:3, 6:8])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), torus_wrapped_export[14:15, 13:15])

    call!(runtime, "export-wrapped-labeled-view", box_wrapped_view_path, false, false)
    box_wrapped_export = NetLogo.FileIO.load(box_wrapped_view_path)
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (200.0, 10.0, 20.0, 255.0), box_wrapped_export[6:10, 11:15])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (30.0, 40.0, 210.0, 255.0), box_wrapped_export[9:13, 1:3])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (220.0, 120.0, 20.0, 255.0), box_wrapped_export[1:3, 6:8])
    @test !any(pixel -> NetLogo.image_rgba_channels(pixel) == (10.0, 200.0, 30.0, 255.0), box_wrapped_export[14:15, 13:15])
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: export drawing command" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")
  base_dir = mktempdir()
  drawing_path = joinpath(base_dir, "drawing.png")
  runtime = create_runtime(compile_model("""
  to export-and-reimport [file]
    clear-all
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
    export-drawing file
    clear-drawing
    import-drawing file
  end
  """); seed=327)

  try
    call!(runtime, "export-and-reimport", drawing_path)
    exported = NetLogo.FileIO.load(drawing_path)
    @test size(exported) == (216, 216)
    @test runtime.world.drawing[109, 109] == (251.0, 251.0, 214.0, 255.0)
    @test NetLogo.image_rgba_channels(exported[109, 109]) == (251.0, 251.0, 214.0, 255.0)
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: pen and stamp drawing commands" begin
  base_dir = mktempdir()
  drawing_path = joinpath(base_dir, "pen-stamp.png")
  runtime = create_runtime(compile_model("""
  to draw-and-export [file]
    clear-all
    resize-world 0 2 0 2
    set-patch-size 1
    set-topology false false
    crt 2
    ask turtle 1 [ setxy 2 1 set color [90 100 110 255] ]
    ask turtle 0 [
      setxy 1 0
      set heading 0
      set color [10 20 30 128]
      pd
      fd 1
      penup
      fd 1
      set color [4 7 9 1]
      stamp
      setxy 0 1
      create-link-with turtle 1
    ]
    ask link 0 1 [
      set color [90 100 110 255]
      stamp
    ]
    export-drawing file
  end
  """); seed=345)

  try
    call!(runtime, "draw-and-export", drawing_path)
    exported = NetLogo.FileIO.load(drawing_path)
    @test size(exported) == (3, 3)
    @test runtime.world.drawing[3, 2] == (10.0, 20.0, 30.0, 128.0)
    @test runtime.world.drawing[1, 2] == (4.0, 7.0, 9.0, 1.0)
    @test runtime.world.drawing[2, 1] == (90.0, 100.0, 110.0, 255.0)
    @test runtime.world.drawing[2, 3] == (90.0, 100.0, 110.0, 255.0)
    @test NetLogo.image_rgba_channels(exported[3, 2]) == (10.0, 20.0, 30.0, 128.0)
    @test NetLogo.image_rgba_channels(exported[1, 2]) == (4.0, 7.0, 9.0, 1.0)
    @test NetLogo.image_rgba_channels(exported[2, 1]) == (90.0, 100.0, 110.0, 255.0)
    @test NetLogo.image_rgba_channels(exported[2, 3]) == (90.0, 100.0, 110.0, 255.0)
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: shape-aware export view" begin
  base_dir = mktempdir()
  shape_view_path = joinpath(base_dir, "shape-view.png")
  runtime = create_runtime(compile_model("""
  to export-shaped-view [file]
    clear-all
    resize-world 0 10 0 4
    set-patch-size 5
    set-topology false false
    ask patches [ set pcolor [1 2 3] ]
    set-default-shape turtles "bug"
    crt 5
    ask turtle 0 [
      setxy 2 2
      set size 1.5
      set color [80 90 100 255]
    ]
    ask turtle 1 [
      setxy 5 2
      set heading 180
      set shape "default"
      set color [30 40 50 255]
    ]
    ask turtle 2 [
      setxy 7 2
      set size 1.5
      set shape "wheel"
      set color [20 140 180 255]
    ]
    ask turtle 3 [
      setxy 0 0
      set size 1.5
      set shape "flower"
      set color [180 70 200 255]
    ]
    ask turtle 4 [
      setxy 9 0
      set size 1.5
      set shape "sheep"
      set color [140 120 80 255]
    ]
    ask turtle 0 [
      create-link-to turtle 1 [
        set color [120 80 60 255]
        set thickness 0.4
      ]
    ]
    export-view file
  end
  """); seed=353)

  try
    call!(runtime, "export-shaped-view", shape_view_path)
    exported = NetLogo.FileIO.load(shape_view_path)
    @test size(exported) == (25, 55)
    @test NetLogo.image_rgba_channels(exported[1, 1]) == (1.0, 2.0, 3.0, 255.0)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (80.0, 90.0, 100.0, 255.0), exported)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (0.0, 0.0, 0.0, 255.0), exported)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (120.0, 80.0, 60.0, 255.0), exported[11:12, 24:29]) ||
      any(pixel -> NetLogo.image_rgba_channels(pixel) == (120.0, 80.0, 60.0, 255.0), exported[14:15, 24:29])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (20.0, 140.0, 180.0, 255.0), exported[9:17, 35:41])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (0.0, 0.0, 0.0, 255.0), exported[9:17, 35:41])
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (89.0, 176.0, 60.0, 255.0), exported)
    @test any(pixel -> NetLogo.image_rgba_channels(pixel) == (255.0, 255.0, 255.0, 255.0), exported)
  finally
    rm(base_dir; recursive=true, force=true)
  end
end

@testset "integration: clear command aliases" begin
  fixture_dir = joinpath(dirname(dirname(@__DIR__)), "NetLogo", "test", "import-pcolors")
  exact_path = joinpath(fixture_dir, "import-pcolors-test1.png")

  runtime = create_runtime(compile_model("""
  globals [ca-summary ct-count cp-clean]

  to setup
    crt 2
    ask patches [ set pcolor red ]
    ca
    set ca-summary (list any? turtles all? patches [pcolor = 0])
    crt 3
    ct
    set ct-count count turtles
    ask patches [ set pcolor red ]
    cp
    set cp-clean all? patches [pcolor = 0]
    resize-world 0 215 0 215
    set-patch-size 1
    import-drawing $(repr(exact_path))
    cd
  end
  """); seed=337)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["CA-SUMMARY"] == Any[false, true]
  @test runtime.world.observer.globals["CT-COUNT"] == 0.0
  @test runtime.world.observer.globals["CP-CLEAN"] == true
  @test count(pixel -> pixel[4] > 0.0, runtime.world.drawing) == 0
end

@testset "integration: link shapes and but-first alias" begin
  runtime = create_runtime(netlogo"""
  globals [glob1 glob2 word-tail link-shape-names]

  to setup
    set glob1 "abc"
    set glob2 "def"
    set word-tail but-first (word glob1 glob2)
    set link-shape-names link-shapes
  end
  """; seed=349)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["WORD-TAIL"] == "bcdef"
  @test runtime.world.observer.globals["LINK-SHAPE-NAMES"] == Any["default"]
end

@testset "integration: plot management commands" begin
  runtime = create_runtime(netlogo"""
  globals [
    foobar-exists pen1-exists dummy-exists foobar-after-clear pen-error autoplot-states
    plot1-default plot1-ranged plot1-cleared plot2-default autoplot-on-flags
    foobar-after-clear-all plot1-after-clear-all missing-plot-error range-error
  ]

  to setup
    set-current-plot "plot1"
    set plot1-default (list plot-name plot-x-min plot-x-max plot-y-min plot-y-max)
    set-current-plot "plot2"
    set plot2-default (list plot-name plot-x-min plot-x-max plot-y-min plot-y-max)
    set-current-plot "plot1"
    create-temporary-plot-pen "foobar"
    set foobar-exists plot-pen-exists? "foobar"
    set pen1-exists plot-pen-exists? "pen1"
    set dummy-exists plot-pen-exists? "dummy"
    set-current-plot-pen "foobar"
    set-current-plot-pen "pen1"
    set-current-plot-pen "foobar"
    clear-plot
    set foobar-after-clear plot-pen-exists? "foobar"
    set plot1-cleared (list plot-name plot-x-min plot-x-max plot-y-min plot-y-max)
    set pen-error ""
    carefully [ set-current-plot-pen "foobar" ] [ set pen-error error-message ]
    set-current-plot-pen "pen1"
    set-plot-x-range (-2) 12
    set-plot-y-range 3 9
    set plot1-ranged (list plot-name plot-x-min plot-x-max plot-y-min plot-y-max)
    clear-plot
    create-temporary-plot-pen "foobar"
    auto-plot-off
    auto-plot-on
    set autoplot-on-flags (list autoplot? autoplotx? autoploty?)
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
    set autoplot-states states
    clear-all-plots
    set foobar-after-clear-all plot-pen-exists? "foobar"
    set plot1-after-clear-all (list plot-name plot-x-min plot-x-max plot-y-min plot-y-max)
    set missing-plot-error ""
    carefully [ set-current-plot "bogus" ] [ set missing-plot-error error-message ]
    set range-error ""
    carefully [ set-plot-x-range 5 5 ] [ set range-error error-message ]
  end
  """; seed=359)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["FOOBAR-EXISTS"] == true
  @test runtime.world.observer.globals["PEN1-EXISTS"] == true
  @test runtime.world.observer.globals["DUMMY-EXISTS"] == false
  @test runtime.world.observer.globals["FOOBAR-AFTER-CLEAR"] == false
  @test runtime.world.observer.globals["PEN-ERROR"] == "There is no pen named \"foobar\" in the current plot"
  @test runtime.world.observer.globals["PLOT1-DEFAULT"] == Any["plot1", 0.0, 10.0, 0.0, 10.0]
  @test runtime.world.observer.globals["PLOT2-DEFAULT"] == Any["plot2", 0.0, 10.0, 0.0, 10.0]
  @test runtime.world.observer.globals["PLOT1-CLEARED"] == Any["plot1", 0.0, 10.0, 0.0, 10.0]
  @test runtime.world.observer.globals["PLOT1-RANGED"] == Any["plot1", -2.0, 12.0, 3.0, 9.0]
  @test runtime.world.observer.globals["AUTOPLOT-ON-FLAGS"] == Any[true, true, true]
  @test runtime.world.observer.globals["AUTOPLOT-STATES"] == Any[
    Any[true, true, true],
    Any[false, false, false],
    Any[false, true, false],
    Any[true, true, true],
    Any[false, false, true],
    Any[false, false, false],
  ]
  @test runtime.world.observer.globals["FOOBAR-AFTER-CLEAR-ALL"] == false
  @test runtime.world.observer.globals["PLOT1-AFTER-CLEAR-ALL"] == Any["plot1", 0.0, 10.0, 0.0, 10.0]
  @test runtime.world.observer.globals["MISSING-PLOT-ERROR"] == "no such plot: \"bogus\""
  @test runtime.world.observer.globals["RANGE-ERROR"] == "the minimum must be less than the maximum, but 5.0 is greater than or equal to 5.0"
end

@testset "integration: plot data commands" begin
  runtime = create_runtime(netlogo"""
  globals [invalid-mode-error invalid-histogram-error]

  to setup
    set-current-plot "plot1"
    set-current-plot-pen "pen1"
    plot 5
    plot 7.5
    plotxy 4 9
    plot-pen-up
    plotxy 5 11
    plot-pen-down
    plot-pen-reset
    set-plot-x-range 0 10
    set-plot-y-range 0 5
    histogram [0 1 4 9 0 1 4 6 9 1 6 5]
    set-histogram-num-bars 5
    set invalid-mode-error ""
    carefully [ set-plot-pen-mode 3 ] [ set invalid-mode-error error-message ]
    set invalid-histogram-error ""
    carefully [
      set-plot-pen-interval 0
      histogram [1 2 3]
    ] [ set invalid-histogram-error error-message ]
  end
  """; seed=373)

  call!(runtime, "setup")
  plot1 = runtime.plot_manager.plots[1]
  pen1 = plot1.pens[1]
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 2.0, true),
    (1.0, 3.0, true),
    (4.0, 2.0, true),
    (5.0, 1.0, true),
    (6.0, 2.0, true),
    (9.0, 2.0, true),
  ]
  @test plot1.y_max == 5.0
  @test runtime.world.observer.globals["INVALID-MODE-ERROR"] == "3 is not a valid plot pen mode (valid modes are 0, 1, and 2)"
  @test runtime.world.observer.globals["INVALID-HISTOGRAM-ERROR"] == "You cannot histogram with a plot-pen-interval of 0."
end

@testset "integration: plot callback commands" begin
  runtime = create_runtime(netlogo"""
  breed [dogs dog]
  globals [dog-count after-go rng-before rng-after]

  to clear-state
    clear-all
    clear-all-plots
  end

  to run-setup-plots
    setup-plots
    set dog-count count dogs
  end

  to run-update-plots
    update-plots
    set dog-count count dogs
  end

  to run-reset-ticks
    reset-ticks
    set dog-count count dogs
  end

  to go
    create-dogs 1
    tick
    set after-go count dogs
  end

  to go-stop
    tick
    create-dogs 4
    set after-go count dogs
  end

  to tick-only
    tick
  end

  to set-seed [n]
    random-seed n
  end

  to snapshot-rng-before
    set rng-before n-values 10 [random 10]
  end

  to snapshot-rng-after
    set rng-after n-values 10 [random 10]
  end
  """; seed=397)

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
  pen1 = plot1.pens[1]

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.setup_code = "create-dogs 5"
  pen1.setup_code = "create-dogs 3"
  call!(runtime, "run-setup-plots")
  @test runtime.world.observer.globals["DOG-COUNT"] == 8.0

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  pen1.update_code = "plot count dogs * 2"
  call!(runtime, "run-reset-ticks")
  call!(runtime, "go")
  @test runtime.world.observer.globals["AFTER-GO"] == 1.0
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 0.0, true),
    (1.0, 2.0, true),
  ]

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.update_code = "create-dogs 1 stop"
  pen1.update_code = "create-dogs 42"
  call!(runtime, "run-reset-ticks")
  call!(runtime, "go-stop")
  @test runtime.world.observer.globals["AFTER-GO"] == 6.0
  @test isempty(pen1.points)

  clear_plot_codes!(runtime)
  call!(runtime, "clear-state")
  plot1.update_code = "set dog-count count dogs set rng-before n-values 10 [random 10]"
  pen1.update_code = "set rng-after n-values 10 [random 10]"
  call!(runtime, "run-reset-ticks")
  call!(runtime, "set-seed", 10)
  call!(runtime, "snapshot-rng-before")
  call!(runtime, "set-seed", 10)
  call!(runtime, "tick-only")
  call!(runtime, "snapshot-rng-after")
  @test runtime.world.observer.globals["RNG-BEFORE"] == runtime.world.observer.globals["RNG-AFTER"]
end

@testset "integration: model-backed plot metadata" begin
  runtime = create_runtime(compile_model("""
  breed [dogs dog]
  globals [dog-count after-go]

  to clear-state
    clear-all
    clear-all-plots
  end

  to run-reset-ticks
    reset-ticks
    set dog-count count dogs
  end

  to go
    create-dogs 1
    tick
    set after-go count dogs
  end
  @#\$#@#\$#@
  PLOT
  10
  360
  239
  524
  Dogs Over Time
  Time
  Dogs
  0.0
  10.0
  0.0
  10.0
  true
  true
  "create-dogs 5" ""
  PENS
  "dogs" 1.0 0 -13345367 true "create-dogs 3" "plot count dogs * 2"
  @#\$#@#\$#@
  """); seed=401)

  @test length(runtime.plot_manager.plots) == 1
  plot1 = runtime.plot_manager.plots[1]
  pen1 = plot1.pens[1]
  @test plot1.name == "Dogs Over Time"
  @test plot1.legend_open == true
  @test pen1.name == "dogs"
  @test pen1.default_color == -13345367

  call!(runtime, "clear-state")
  call!(runtime, "run-reset-ticks")
  @test runtime.world.observer.globals["DOG-COUNT"] == 8.0
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 16.0, true),
  ]

  call!(runtime, "go")
  @test runtime.world.observer.globals["AFTER-GO"] == 9.0
  @test [(point.x, point.y, point.is_down) for point in pen1.points] == [
    (0.0, 16.0, true),
    (1.0, 18.0, true),
  ]
end

@testset "integration: file-backed interface widgets" begin
  ants_path = normpath(joinpath(@__DIR__, "..", "..", "NetLogo", "test", "fileformat", "Ants Benchmark.nlogo"))
  model = compile_model(read(ants_path, String))
  runtime = create_runtime(model; seed=337)

  @test runtime.world.min_pxcor == -50
  @test runtime.world.max_pxcor == 50
  @test runtime.world.min_pycor == -50
  @test runtime.world.max_pycor == 50
  @test runtime.world.topology == BoxTopology
  @test runtime.world.patch_size == 5.0
  @test runtime.world.observer.globals["ANTS"] == 300.0
  @test runtime.world.observer.globals["DIFFUSION-RATE"] == 53.0
  @test runtime.world.observer.globals["EVAPORATION-RATE"] == 10.0
  @test runtime.world.observer.globals["PLOT?"] == true
  @test length(runtime.plot_manager.plots) == 1
  @test runtime.plot_manager.plots[1].name == "Food in each pile"
  buttons = [widget for widget in model.interface_widgets if widget isa NetLogo.ButtonWidgetSpec]
  @test length(buttons) == 3
  @test buttons[1].display == "Setup"
  @test buttons[1].source == "setup"
  @test buttons[1].forever == false
  @test buttons[2].display == "Go"
  @test buttons[2].source == "go"
  @test buttons[2].forever == true
  @test buttons[3].source == "benchmark"

  call!(runtime, "setup")
  @test length(runtime.world.turtles) == 300
  @test all(turtle -> turtle.shape == "bug", runtime.world.turtles)
  @test runtime.world.ticks == 0.0

  call!(runtime, "go")
  @test runtime.world.ticks == 1.0
end

@testset "integration: plot export commands" begin
  base_dir = mktempdir()
  single_path = joinpath(base_dir, "plot.csv")
  all_path = joinpath(base_dir, "plots.csv")
  runtime = create_runtime(netlogo"""
  globals [missing-plot-error]

  to setup [single-file all-file]
    set-current-plot "plot1"
    clear-plot
    set-current-plot-pen "pen1"
    plot 5
    plot 8
    plot 17
    export-plot "plot1" single-file

    set-current-plot "plot2"
    clear-plot
    set-current-plot-pen "pen2"
    plotxy 3 4
    export-all-plots all-file

    set missing-plot-error ""
    carefully [ export-plot "bogus" single-file ] [ set missing-plot-error error-message ]
  end
  """; seed=383)

  call!(runtime, "setup", single_path, all_path)

  single_content = replace(read(single_path, String), "\r\n" => "\n")
  all_content = replace(read(all_path, String), "\r\n" => "\n")
  @test startswith(single_content, "\"export-plot data ($(NetLogo.NETLOGO_VERSION_STRING))\"\n\"\"\n")
  @test occursin("\"plot1\"\n", single_content)
  @test occursin("\"pen1\",\"true\",\"0\",\"1.0\",\"0.0\",\"2.0\"", single_content)
  @test occursin("\"0.0\",\"5.0\",\"0.0\",\"true\"", single_content)

  @test startswith(all_content, "\"export-plots data ($(NetLogo.NETLOGO_VERSION_STRING))\"\n\"\"\n")
  @test occursin("\"plot1\"\n", all_content)
  @test occursin("\"plot2\"\n", all_content)
  @test first(findfirst("\"plot1\"", all_content)) < first(findfirst("\"plot2\"", all_content))

  @test runtime.world.observer.globals["MISSING-PLOT-ERROR"] == "no such plot: \"bogus\""
end

@testset "integration: shapes reporter" begin
  runtime = create_runtime(netlogo"""
  globals [shape-names]

  to setup
    set shape-names shapes
  end
  """; seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["SHAPE-NAMES"] == Any[
    "default", "airplane", "arrow", "box", "bug", "butterfly", "car", "circle", "circle 2",
    "cow", "cylinder", "dot", "face happy", "face neutral", "face sad", "fish", "flag", "flower",
    "house", "leaf", "line", "line half", "pentagon", "person", "plant", "sheep", "square",
    "square 2", "star", "target", "tree", "triangle", "triangle 2", "truck", "turtle", "wheel",
    "wolf", "x"
  ]
end

@testset "integration: metadata reporters" begin
  runtime = create_runtime(netlogo"""
  globals [version-prefix version-equality home-directory-string behaviorspace-run-number-value behaviorspace-experiment-name-value]

  to setup
    set version-prefix substring netlogo-version 0 3
    set version-equality netlogo-version = netlogo-version
    set home-directory-string is-string? home-directory
    set behaviorspace-run-number-value behaviorspace-run-number
    set behaviorspace-experiment-name-value behaviorspace-experiment-name
  end
  """; seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["VERSION-PREFIX"] == "7.0"
  @test runtime.world.observer.globals["VERSION-EQUALITY"] == true
  @test runtime.world.observer.globals["HOME-DIRECTORY-STRING"] == true
  @test runtime.world.observer.globals["BEHAVIORSPACE-RUN-NUMBER-VALUE"] == 0.0
  @test runtime.world.observer.globals["BEHAVIORSPACE-EXPERIMENT-NAME-VALUE"] == ""
end

@testset "integration: radius and cone query reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [pack-count cone-count scent-count target-count]
  globals [wrapped-px alpha-pack alpha-cone alpha-scent alpha-target patch-territory]

  to setup
    clear-all
    create-wolves 4 [
      setxy 0 0
      set pack-count 0
      set cone-count 0
      set scent-count 0
      set target-count 0
    ]
    ask turtle 0 [ setxy 1 0 set heading 90 ]
    ask turtle 1 [ setxy -1 0 set heading 0 ]
    ask turtle 2 [ setxy 1 1 set heading 0 ]
    ask turtle 3 [ setxy 0 0 set heading 0 ]
    ask turtle 0 [
      set pack-count count wolves in-radius 1
      set cone-count count wolves in-cone 1.1 90
      set scent-count count patches in-cone 1 180
      set target-count count turtles-at 1 0
      set wrapped-px [pxcor] of patch-at 1 0
    ]
    ask patch 0 0 [
      set patch-territory count patches in-radius 1
    ]
    set alpha-pack [pack-count] of turtle 0
    set alpha-cone [cone-count] of turtle 0
    set alpha-scent [scent-count] of turtle 0
    set alpha-target [target-count] of turtle 0
  end

  to-report wrapped-target-x
    report wrapped-px
  end

  to-report cone-pack-again
    report [count wolves in-cone 1.1 90] of turtle 0
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=41)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["WRAPPED-PX"] == -1.0
  @test runtime.world.observer.globals["ALPHA-PACK"] == 4.0
  @test runtime.world.observer.globals["ALPHA-CONE"] == 2.0
  @test runtime.world.observer.globals["ALPHA-SCENT"] == 4.0
  @test runtime.world.observer.globals["ALPHA-TARGET"] == 1.0
  @test runtime.world.observer.globals["PATCH-TERRITORY"] == 5.0
  @test call!(runtime, "wrapped-target-x") == -1.0
  @test call!(runtime, "cone-pack-again") == 2.0
end

@testset "integration: point query reporters" begin
  runtime = create_runtime(netlogo"""
  breed [frogs frog]
  breed [mice mouse]
  frogs-own [local-pack wrap-pack]
  globals [target-patches occupied-patches source-frogs]

  to setup
    clear-all
    create-frogs 3 [
      setxy 0 0
      set local-pack 0
      set wrap-pack 0
    ]
    create-mice 5 [ setxy 0 0 ]
    ask turtle 0 [ setxy 0 0 ]
    ask turtle 1 [ setxy 0 0 ]
    ask turtle 2 [ setxy -1 1 ]
    ask turtle 3 [ setxy 0 0 ]
    ask turtle 4 [ setxy 0 0 ]
    ask turtle 5 [ setxy 0 0 ]
    ask turtle 6 [ setxy 0 0 ]
    ask turtle 7 [ setxy -1 1 ]
    set target-patches count patches-on turtles
    set occupied-patches count patches at-points [[0 0] [-1 1] [0.2 0.2]]
    set source-frogs count frogs-on patches-on mice
    ask turtle 0 [
      set local-pack count turtles-on patch-here
      set wrap-pack count turtles at-points [[2 1] [2 1]]
    ]
  end

  to-report neighborhood-frogs
    report count frogs-on [neighbors] of patch 0 0
  end

  to-report patch-sources
    report count patches-on one-of frogs-on patch 0 0
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=79)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["TARGET-PATCHES"] == 2.0
  @test runtime.world.observer.globals["OCCUPIED-PATCHES"] == 2.0
  @test runtime.world.observer.globals["SOURCE-FROGS"] == 3.0
  @test runtime.world.turtles[1].own["LOCAL-PACK"] == 6.0
  @test runtime.world.turtles[1].own["WRAP-PACK"] == 2.0
  @test call!(runtime, "neighborhood-frogs") == 1.0
  @test call!(runtime, "patch-sources") == 1.0
end

@testset "integration: breed-specific at reporters" begin
  runtime = create_runtime(netlogo"""
  globals [breed-at-counts]
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
    let target turtle 20
    set breed-at-counts (list
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
  """; min_pxcor=-4, max_pxcor=4, min_pycor=-4, max_pycor=4, topology=BoxTopology, seed=242)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["BREED-AT-COUNTS"] == Any[4.0, 2.0, 3.0, 0.0, 10.0, 3.0, 7.0, 1.0, 0.0, 11.0]
end

@testset "integration: breed-specific here reporters" begin
  runtime = create_runtime(netlogo"""
  globals [home-patch mouse-here-counts patch-here-counts]
  breed [frogs frog]
  breed [mice mouse]

  to setup
    clear-all
    set home-patch patch 0 0
    create-frogs 10 [ setxy 0 0 ]
    create-mice 10 [ setxy 0 0 ]
    let target turtle 10
    set mouse-here-counts (list
      [count mice-here] of target
      [count other mice-here] of target
      [count frogs-here] of target
      [count other frogs-here] of target)
    set patch-here-counts (list
      [count frogs-here] of home-patch
      [count other frogs-here] of home-patch
      [length sort other frogs-here] of home-patch)
  end
  """; seed=244)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["MOUSE-HERE-COUNTS"] == Any[10.0, 9.0, 10.0, 10.0]
  @test runtime.world.observer.globals["PATCH-HERE-COUNTS"] == Any[10.0, 10.0, 10.0]
end

@testset "integration: higher-order tasks and list reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy score]
  globals [ranked-whos energy-trace weighted-energy strong-energies]

  to-report square [x]
    report x * x
  end

  to setup
    clear-all
    create-wolves 4 [
      set energy item who [5 2 4 1]
      set score 0
      setxy who 0
    ]
    let ranked sort-by [[a b] -> [energy] of a > [energy] of b] wolves
    let ranked-energies map [ t -> [energy] of t ] ranked
    set ranked-whos map [ t -> [who] of t ] ranked
    set energy-trace map square ranked-energies
    set weighted-energy reduce + (map [[t w] -> [energy] of t * w] ranked [1 2 3 4])
    set strong-energies filter [ x -> x > 2 ] ranked-energies
    foreach ranked (n-values count ranked [ i -> i + 1 ]) [
      [t bonus] -> ask t [ set score bonus ]
    ]
  end

  to go
    let pack sort turtles
    let boosts map [ t -> [score] of t ] pack
    foreach pack boosts [
      [t bonus] -> ask t [ set energy energy + bonus ]
    ]
  end

  to-report boosted-energies
    report map [ t -> [energy] of t ] sort turtles
  end
  """; seed=89)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["RANKED-WHOS"] == Any[0.0, 2.0, 1.0, 3.0]
  @test runtime.world.observer.globals["ENERGY-TRACE"] == Any[25.0, 16.0, 4.0, 1.0]
  @test runtime.world.observer.globals["WEIGHTED-ENERGY"] == 23.0
  @test runtime.world.observer.globals["STRONG-ENERGIES"] == Any[5.0, 4.0]
  @test [t.own["SCORE"] for t in sort(runtime.world.turtles, by=t -> t.id)] == [1.0, 3.0, 2.0, 4.0]

  call!(runtime, "go")

  @test call!(runtime, "boosted-energies") == Any[6.0, 5.0, 6.0, 5.0]
end

@testset "integration: sort-on, ifelse-value, and numeric helpers" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [energy band]
  globals [ordered-whos parity-flags total-gap]

  to setup
    clear-all
    create-wolves 4 [
      set energy item who [5 2 4 1]
      set band ""
      setxy who 0
    ]
    let ordered sort-on [energy] wolves
    let ordered-energies map [ t -> [energy] of t ] ordered
    set ordered-whos map [ t -> [who] of t ] ordered
    set parity-flags n-values count ordered [ i -> ifelse-value (i mod 2 = 0) ["even"] ["odd"] ]
    ask turtle 0 [
      set band ifelse-value energy > 4 ["alpha"] ["beta"]
    ]
    set total-gap reduce + map [ x -> abs (x - 3) ] ordered-energies
  end

  to go
    ask turtles [
      set energy energy + ifelse-value (who mod 2 = 0) [1] [2]
    ]
  end

  to-report boosted-energies
    report map [ t -> [energy] of t ] sort turtles
  end
  """; seed=101)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["ORDERED-WHOS"] == Any[3.0, 1.0, 2.0, 0.0]
  @test runtime.world.observer.globals["PARITY-FLAGS"] == Any["even", "odd", "even", "odd"]
  @test runtime.world.observer.globals["TOTAL-GAP"] == 6.0
  @test runtime.world.turtles[1].own["BAND"] == "alpha"

  call!(runtime, "go")

  @test call!(runtime, "boosted-energies") == Any[6.0, 4.0, 5.0, 3.0]
end

@testset "integration: set builders and math reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  breed [mice mouse]
  globals [pack-whos corridor-count marked-patches empty-flags math-trace]

  to setup
    clear-all
    create-wolves 2 [ setxy who 0 ]
    create-mice 1 [ setxy 2 0 ]
    ask turtle 0 [ create-link-with turtle 1 ]
    ask turtle 1 [ create-link-with turtle 2 ]
    set pack-whos sort [who] of (turtle-set wolves mice nobody)
    set corridor-count count (link-set links nobody (sort links))
    ask (patch-set patch 0 0 (list patch 1 0 (list patch 2 0)) nobody) [
      set pcolor 9
    ]
    set marked-patches count patches with [pcolor = 9]
    set empty-flags (list (no-turtles = (turtles with [who > 20])) (is-link-set? no-links) (is-patch-set? no-patches))
    set math-trace (list (floor 4.5) (ceiling (-4.5)) (round (-1.5)) (round 1.5) (int (-3.5)) (sqrt 25) (exp 0) (log 64 2))
  end

  to go
    ask (turtle-set wolves mice nobody) [
      set heading 15 * log 64 2
    ]
  end

  to-report heading-trace
    report map [ t -> [heading] of t ] sort (turtle-set wolves mice nobody)
  end
  """; seed=109)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["PACK-WHOS"] == Any[0.0, 1.0, 2.0]
  @test runtime.world.observer.globals["CORRIDOR-COUNT"] == 2.0
  @test runtime.world.observer.globals["MARKED-PATCHES"] == 3.0
  @test runtime.world.observer.globals["EMPTY-FLAGS"] == Any[true, true, true]
  @test runtime.world.observer.globals["MATH-TRACE"] == Any[4.0, -4.0, -1.0, 2.0, -3.0, 5.0, 1.0, 6.0]

  call!(runtime, "go")

  @test call!(runtime, "heading-trace") == Any[90.0, 90.0, 90.0]
end

@testset "integration: carefully and local randomness" begin
  runtime = create_runtime(netlogo"""
  globals [caught-message local-draw next-draw]

  to setup
    clear-all
    random-seed 31
    set caught-message ""
    set local-draw 0
    set next-draw 0
    carefully [ error "integration boom" ] [ set caught-message error-message ]
  end

  to go
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

  to-report sampled-local
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
  """; seed=31)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["CAUGHT-MESSAGE"] == "integration boom"

  call!(runtime, "go")

  @test runtime.world.observer.globals["LOCAL-DRAW"] == runtime.world.observer.globals["NEXT-DRAW"]
  @test call!(runtime, "random-state-restored-demo") == true
  @test call!(runtime, "random-state-advances-demo") == false
  @test call!(runtime, "one-of-local-random-demo") == true
  @test call!(runtime, "min-one-of-local-random-demo") == true
  @test call!(runtime, "nested-local-random-demo") == true
  @test call!(runtime, "seed-local-random-demo") == Any[true, true]
  @test call!(runtime, "local-random-stop-demo") == true
  @test call!(runtime, "local-random-carefully-demo") == true
  @test call!(runtime, "ask-local-random-demo") == true
  @test call!(runtime, "sampled-local") == call!(runtime, "sampled-local")
end

@testset "integration: ask-concurrent" begin
  runtime = create_runtime(netlogo"""
  globals [repeat-positions let-valid? single-agent-error local-random-ok?]

  to setup
    clear-all
    set repeat-positions []
    set let-valid? false
    set single-agent-error ""
    set local-random-ok? false
  end

  to run-repeat-demo
    cro 4
    ask-concurrent turtles [ repeat 4 [ fd 1 ] ]
    set repeat-positions (list [list xcor ycor] of turtle 0
                               [list xcor ycor] of turtle 1
                               [list xcor ycor] of turtle 2
                               [list xcor ycor] of turtle 3)
  end

  to run-let-demo
    clear-all
    crt 4
    ask-concurrent turtles [ let x who fd 1 set xcor x ]
    set let-valid? not any? turtles with [who != xcor]
  end

  to run-single-agent-error-demo
    clear-all
    crt 1
    carefully [ ask-concurrent turtle 0 [ set pcolor red ] ] [ set single-agent-error error-message ]
  end

  to run-local-random-demo
    clear-all
    crt 10
    let before __random-state
    with-local-randomness [ ask-concurrent turtles [ set color random 140 ] ]
    set local-random-ok? (before = __random-state)
  end
  """; seed=31)

  call!(runtime, "setup")
  call!(runtime, "run-repeat-demo")
  @test runtime.world.observer.globals["REPEAT-POSITIONS"] == Any[Any[0.0, 4.0], Any[4.0, 0.0], Any[0.0, -4.0], Any[-4.0, 0.0]]

  call!(runtime, "run-let-demo")
  @test runtime.world.observer.globals["LET-VALID?"] == true

  call!(runtime, "run-single-agent-error-demo")
  @test runtime.world.observer.globals["SINGLE-AGENT-ERROR"] == "ASK-CONCURRENT expected input to be an agentset but got the turtle (turtle 0) instead."

  call!(runtime, "run-local-random-demo")
  @test runtime.world.observer.globals["LOCAL-RANDOM-OK?"] == true
end

@testset "integration: agent lifecycle and movement" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]
  breed [frogs frog]
  mice-own [mice-energy]
  frogs-own [frog-energy]
  globals [offspring-whos aimed-heading hatch-energy moved-frog sprout-count cached-before cached-after dead-ref]

  to setup
    clear-all
    create-mice 1 [ set mice-energy 10 setxy 0 0 ]
    create-turtles 1 [ setxy 3 4 ]
    ask turtle 0 [
      create-link-with turtle 1
      face turtle 1
      hatch 1 [ set label "child" ]
      hatch-frogs 1 [ set frog-energy 7 move-to patch 2 2 ]
    ]
    ask patch -2 1 [ sprout-frogs 1 [ set frog-energy 3 ] ]
    set cached-before turtles
    set offspring-whos sort [who] of turtles
    set aimed-heading [heading] of turtle 0
    set hatch-energy [mice-energy] of turtle 2
    set moved-frog [(list xcor ycor frog-energy shape)] of turtle 3
    set sprout-count count frogs with [xcor = -2 and ycor = 1]
    set dead-ref nobody
  end

  to go
    ask turtle 0 [ set dead-ref self die ]
    set cached-after count cached-before
  end

  to-report dead-ref-string
    report word dead-ref
  end

  to-report frog-whos
    report sort [who] of frogs
  end
  """; seed=223)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["OFFSPRING-WHOS"] == Any[0.0, 1.0, 2.0, 3.0, 4.0]
  @test runtime.world.observer.globals["AIMED-HEADING"] ≈ 36.86989764584402
  @test runtime.world.observer.globals["HATCH-ENERGY"] == 10.0
  @test runtime.world.observer.globals["MOVED-FROG"] == Any[2.0, 2.0, 7.0, "default"]
  @test runtime.world.observer.globals["SPROUT-COUNT"] == 1.0
  @test call!(runtime, "frog-whos") == Any[3.0, 4.0]

  call!(runtime, "go")

  @test runtime.world.observer.globals["CACHED-AFTER"] == 4.0
  @test count(l -> l.alive, runtime.world.links) == 0
  @test call!(runtime, "dead-ref-string") == "nobody"
end

@testset "integration: can-move predicate" begin
  runtime = create_runtime(netlogo"""
  to setup-topology [wrap-x? wrap-y?]
    clear-all
    set-topology wrap-x? wrap-y?
    crt 1 [ set heading 0 fd 5.1 ]
  end

  to-report probe-under [wrap-x? wrap-y? third-distance]
    setup-topology wrap-x? wrap-y?
    report [(list can-move? 1 can-move? 0.5 can-move? third-distance)] of turtle 0
  end
  """; min_pxcor=-5, max_pxcor=5, min_pycor=-5, max_pycor=5, topology=Torus, seed=229)

  @test call!(runtime, "probe-under", true, true, 0) == Any[true, true, true]
  @test call!(runtime, "probe-under", false, true, 0.2) == Any[true, true, true]
  @test call!(runtime, "probe-under", true, false, 0.2) == Any[false, false, true]
  @test call!(runtime, "probe-under", false, false, 0.2) == Any[false, false, true]
  @test call!(runtime, "probe-under", false, false, 0.4) == Any[false, false, false]
end

@testset "integration: blocked forward movement" begin
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
  """; seed=230)

  @test call!(runtime, "partial-forward", 2) == Any[2.0, 1.0]
  @test call!(runtime, "blocked-forward-at-edge", 1) == Any[2.0, 1.0]
end

@testset "integration: uphill and downhill compatibility" begin
  runtime = create_runtime(netlogo"""
  globals [gradient-headings uphill-summary downhill-summary]
  patches-own [pvar]

  to-report gradient-headings-helper
    clear-all
    crt 1
    let counter 1
    ask turtle 0 [
      foreach sort neighbors [ x -> ask x [ set pvar counter set counter counter + 1 ] ]
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

  to-report uphill-summary-helper
    clear-all
    random-seed 287
    let home-patch patch 0 0
    ask patches [ if home-patch != self [ set pcolor 1 ] ]
    crt 100
    ask turtles [ uphill pcolor ]
    let headings sort remove-duplicates [heading] of turtles
    ask turtles [ rt 180 fd 1 move-to patch-here ]
    let returned-home not any? turtles with [ patch-here != home-patch ]
    report (list headings returned-home)
  end

  to-report downhill-summary-helper
    clear-all
    random-seed 287
    crt 100
    ask turtle 0 [ set pcolor 1 ]
    let home-patch patch 0 0
    ask turtles [ downhill4 pcolor ]
    let headings sort remove-duplicates [heading] of turtles
    ask turtles [ rt 180 fd 1 move-to patch-here ]
    let returned-home not any? turtles with [ patch-here != home-patch ]
    report (list headings returned-home)
  end

  to setup
    let gradient-value gradient-headings-helper
    let uphill-value uphill-summary-helper
    let downhill-value downhill-summary-helper
    set gradient-headings gradient-value
    set uphill-summary uphill-value
    set downhill-summary downhill-value
  end
  """; seed=237)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["GRADIENT-HEADINGS"] == Any[315.0, 0.0, 135.0, 180.0]
  @test runtime.world.observer.globals["UPHILL-SUMMARY"] == Any[Any[0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0], true]
  @test runtime.world.observer.globals["DOWNHILL-SUMMARY"] == Any[Any[0.0, 90.0, 180.0, 270.0], true]
end

@testset "integration: tie compatibility" begin
  runtime = create_runtime(netlogo"""
  globals [wrap-summary chain-summary zero-summary]

  to setup-wrap
    clear-all
    resize-world (-5) 5 (-5) 5
    crt 2
    ask turtle 0 [ setxy 1 0 set heading 90 ]
    ask turtle 1 [ setxy 0 0 set heading 0 create-link-with turtle 0 [ tie ] ]
    ask turtle 0 [ fd 1 ]
    let a (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0 [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    ask turtle 0 [ set heading 0 ]
    let b (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0 [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    ask turtle 0 [ fd 5 ]
    let c (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0 [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    ask turtle 0 [ fd 1 ]
    let d (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0 [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    ask turtle 0 [ rt 90 ]
    let e (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0 [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    ask turtle 0 [ rt 90 ]
    let f (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0 [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    set wrap-summary (list a b c d e f)
  end

  to setup-chain
    clear-all
    crt 3
    ask turtles [ set heading 0 ]
    ask turtle 0 [ setxy 0 0 ]
    ask turtle 1 [ setxy 0 2 ]
    ask turtle 2 [ setxy 0 4 ]
    ask turtle 0 [ create-link-with turtle 1 [ tie ] ]
    ask turtle 1 [ create-link-with turtle 2 [ tie ] ]
    ask turtle 1 [ rt 90 ]
    let t0 (list [xcor] of turtle 0 [ycor] of turtle 0 [heading] of turtle 0)
    let t1 (list [xcor] of turtle 1 [ycor] of turtle 1 [heading] of turtle 1)
    let t2 (list [xcor] of turtle 2 [ycor] of turtle 2 [heading] of turtle 2)
    set chain-summary (list t0 t1 t2)
  end

  to setup-zero
    clear-all
    crt 1
    ask turtle 0 [ hatch 1 [ create-link-from turtle 0 [ tie ] ] ]
    ask turtle 0 [ fd 1 ]
    let x0 [xcor] of turtle 0
    let x1 [xcor] of turtle 1
    let y0 [ycor] of turtle 0
    let y1 [ycor] of turtle 1
    let len [link-length] of link 0 1
    let same-x x0 = x1
    let same-y y0 = y1
    set zero-summary (list same-x same-y len)
  end
  """; seed=243)

  call!(runtime, "setup-wrap")
  @test runtime.world.observer.globals["WRAP-SUMMARY"] == Any[
    Any[2.0, 0.0, 90.0, 1.0, 0.0, 0.0],
    Any[2.0, 0.0, 0.0, 2.0, -1.0, 270.0],
    Any[2.0, 5.0, 0.0, 2.0, 4.0, 270.0],
    Any[2.0, -5.0, 0.0, 2.0, 5.0, 270.0],
    Any[2.0, -5.0, 90.0, 1.0, -5.0, 0.0],
    Any[2.0, -5.0, 180.0, 2.0, -4.0, 90.0],
  ]

  call!(runtime, "setup-chain")
  @test runtime.world.observer.globals["CHAIN-SUMMARY"] == Any[
    Any[-2.0, 2.0, 90.0],
    Any[0.0, 2.0, 90.0],
    Any[2.0, 2.0, 90.0],
  ]

  call!(runtime, "setup-zero")
  @test runtime.world.observer.globals["ZERO-SUMMARY"] == Any[true, true, 0.0]
end

@testset "integration: ordered creation compatibility" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  globals [ordered-headings ordered-colors breed-headings breed-colors random-summary link-summary]

  to-report ordered-turtle-headings-helper
    clear-all
    create-ordered-turtles 4
    report map [ t -> [heading] of t ] sort turtles
  end

  to-report ordered-turtle-colors-helper
    clear-all
    cro 4
    report map [ t -> [color] of t ] sort turtles
  end

  to-report ordered-wolf-headings-helper
    clear-all
    create-ordered-wolves 4
    report map [ t -> [heading] of t ] sort wolves
  end

  to-report ordered-wolf-colors-helper
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

  to setup
    let ordered-headings-value ordered-turtle-headings-helper
    let ordered-colors-value ordered-turtle-colors-helper
    let breed-headings-value ordered-wolf-headings-helper
    let breed-colors-value ordered-wolf-colors-helper
    let cro-last cro-randomized-last
    let hatch-last hatch-randomized-last
    let sprout-last sprout-randomized-last
    let with-last link-init-with
    let to-last link-init-to
    let from-last link-init-from
    set ordered-headings ordered-headings-value
    set ordered-colors ordered-colors-value
    set breed-headings breed-headings-value
    set breed-colors breed-colors-value
    set random-summary (list cro-last hatch-last sprout-last)
    set link-summary (list with-last to-last from-last)
  end
  """; seed=239)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["ORDERED-HEADINGS"] == Any[0.0, 90.0, 180.0, 270.0]
  @test runtime.world.observer.globals["ORDERED-COLORS"] == Any[5.0, 15.0, 25.0, 35.0]
  @test runtime.world.observer.globals["BREED-HEADINGS"] == Any[0.0, 90.0, 180.0, 270.0]
  @test runtime.world.observer.globals["BREED-COLORS"] == Any[5.0, 15.0, 25.0, 35.0]
  @test runtime.world.observer.globals["RANDOM-SUMMARY"] == Any[3.0, 9.0, 8.0]
  @test runtime.world.observer.globals["LINK-SUMMARY"] == Any[Any[0.0, 3.0], Any[0.0, 3.0], Any[3.0, 0.0]]
end

@testset "integration: color compatibility" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  globals [palette-summary roundtrip-flags extracted-blue base-demo]

  to-report rgb-round-trip? [col]
    let vals extract-rgb col
    let approx approximate-rgb (item 0 vals) (item 1 vals) (item 2 vals)
    report approx = col
  end

  to-report hsb-round-trip? [col]
    let vals extract-hsb col
    let approx approximate-hsb (item 0 vals) (item 1 vals) (item 2 vals)
    report approx = col
  end

  to setup
    clear-all
    create-wolves 1 [
      set color rgb 0 255 0
      set label-color hsb 218.974 69.231 66.275
    ]
    create-turtles 1 [
      set color blue + 1
      create-link-with wolf 0 [
        set color [255 0 0]
        set label-color [255 0 0 100]
      ]
    ]
    ask patch 0 0 [
      set pcolor scale-color red 5 0 10
      set plabel-color rgb 0 0 255
    ]
    set extracted-blue extract-hsb blue
    set base-demo base-colors
    let rgb-flag rgb-round-trip? red
    let hsb-flag hsb-round-trip? blue
    let shade-flag shade-of? gray white
    set roundtrip-flags (list rgb-flag hsb-flag shade-flag)
    let wolf-color [color] of wolf 0
    let wolf-label [label-color] of wolf 0
    let turtle-color [color] of turtle 1
    let patch-color [pcolor] of patch 0 0
    let patch-label [plabel-color] of patch 0 0
    let link-color [color] of link 0 1
    let link-label [label-color] of link 0 1
    set palette-summary (list wolf-color wolf-label turtle-color patch-color patch-label link-color link-label)
  end

  to-report patch-reset-color
    ask patch 0 0 [ set pcolor [0 0 0] ]
    clear-all
    report [pcolor] of patch 0 0
  end
  """; seed=251)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["ROUNDTRIP-FLAGS"] == Any[true, true, true]
  @test runtime.world.observer.globals["BASE-DEMO"] == Any[5.0, 15.0, 25.0, 35.0, 45.0, 55.0, 65.0, 75.0, 85.0, 95.0, 105.0, 115.0, 125.0, 135.0]
  @test runtime.world.observer.globals["EXTRACTED-BLUE"][1] ≈ 218.974358974359
  @test runtime.world.observer.globals["EXTRACTED-BLUE"][2] ≈ 69.23076923076923
  @test runtime.world.observer.globals["EXTRACTED-BLUE"][3] ≈ 66.27450980392156
  @test runtime.world.observer.globals["PALETTE-SUMMARY"] == Any[
    Any[0.0, 255.0, 0.0],
    Any[52.0, 93.0, 169.0],
    106.0,
    15.0,
    Any[0.0, 0.0, 255.0],
    Any[255.0, 0.0, 0.0],
    Any[255.0, 0.0, 0.0, 100.0],
  ]
  @test call!(runtime, "patch-reset-color") == 0.0
end

@testset "integration: breed mutation and predicates" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]
  breed [frogs frog]
  undirected-link-breed [roads road]
  mice-own [mice-energy]
  frogs-own [frog-energy]
  globals [before-frog after-frog breed-name road-flag same-agent saved]

  to setup
    clear-all
    create-mice 2 [
      set mice-energy 5 + who
      setxy who 0
    ]
    ask mouse 0 [ create-road-with mouse 1 ]
    set before-frog is-frog? turtle 0
    ask mouse 0 [ set shape "car" set breed frogs set frog-energy 12 ]
    set after-frog is-frog? turtle 0
    set breed-name [breed] of turtle 0
    set road-flag is-road? one-of roads
    set same-agent frog 0 = turtle 0
    set saved frog 0
  end

  to go
    ask saved [ die ]
  end

  to-report frog-energy-at-zero
    report [frog-energy] of frog 0
  end

  to-report live-saved?
    report is-agent? saved
  end

  to-report mouse-zero-status
    report word mouse 0
  end
  """; seed=313)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["BEFORE-FROG"] == false
  @test runtime.world.observer.globals["AFTER-FROG"] == true
  @test runtime.world.observer.globals["ROAD-FLAG"] == true
  @test runtime.world.observer.globals["SAME-AGENT"] == true
  @test runtime.world.observer.globals["BREED-NAME"] isa NetLogo.AgentSet
  @test runtime.world.observer.globals["BREED-NAME"].breed == "FROGS"
  @test call!(runtime, "frog-energy-at-zero") == 12.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "mouse-zero-status")

  call!(runtime, "go")

  @test call!(runtime, "live-saved?") == false
end

@testset "integration: link lookup and directed predicates" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [roads road]
  globals [default-color road-match directed-flag undirected-flag road-flag]

  to setup
    clear-all
    create-turtles 4
    ask turtle 0 [ create-link-with turtle 1 [ set color 15 ] ]
    ask turtle 1 [ create-road-with turtle 2 [ set color 25 ] ]
    ask turtle 2 [ create-directed-edge-to turtle 3 [ set color 35 ] ]
    set default-color [color] of link 0 1
    set road-match road 2 1 = road 1 2
    set directed-flag is-directed-link? directed-edge 2 3
    set undirected-flag is-undirected-link? road 1 2
    set road-flag is-road? road 1 2
  end

  to-report default-missing
    report (word link 2 3)
  end

  to-report road-color
    report [color] of road 2 1
  end

  to-report directed-color
    report [color] of directed-edge 2 3
  end
  """; seed=419)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["DEFAULT-COLOR"] == 15.0
  @test runtime.world.observer.globals["ROAD-MATCH"] == true
  @test runtime.world.observer.globals["DIRECTED-FLAG"] == true
  @test runtime.world.observer.globals["UNDIRECTED-FLAG"] == true
  @test runtime.world.observer.globals["ROAD-FLAG"] == true
  @test call!(runtime, "default-missing") == "nobody"
  @test call!(runtime, "road-color") == 25.0
  @test call!(runtime, "directed-color") == 35.0
end

@testset "integration: world topology and reset commands" begin
  runtime = create_runtime(netlogo"""
  globals [glob1 stale-patch wrapped-patch torus-distance box-missing box-distance dims stale-word]
  patches-own [mark]

  to setup
    clear-all
    set glob1 5
    create-turtles 1 [ setxy 1 0 ]
    set stale-patch patch 1 1
  end

  to topology-demo
    set-topology true true
    set wrapped-patch [list pxcor pycor] of patch 2 0
    set torus-distance [distancexy -1 0] of turtle 0
    set-topology false false
    set box-missing patch 2 0 = nobody
    set box-distance [distancexy -1 0] of turtle 0
  end

  to clear-demo
    set glob1 42
    ask patches [ set mark 2 set pcolor 55 set plabel "tag" ]
    clear-globals
    clear-patches
  end

  to resize-demo
    resize-world 0.5 10.5 (-0.5) 10.5
    set dims (list world-width world-height min-pxcor max-pxcor min-pycor max-pycor)
    set stale-word word stale-patch
  end

  to hard-clear
    reset-ticks
    tick
    __clear-all-and-reset-ticks
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=521)

  call!(runtime, "setup")
  call!(runtime, "topology-demo")

  @test runtime.world.observer.globals["WRAPPED-PATCH"] == Any[-1.0, 0.0]
  @test runtime.world.observer.globals["TORUS-DISTANCE"] == 1.0
  @test runtime.world.observer.globals["BOX-MISSING"] == true
  @test runtime.world.observer.globals["BOX-DISTANCE"] == 2.0
  @test runtime.world.topology == BoxTopology

  call!(runtime, "setup")
  call!(runtime, "clear-demo")

  @test runtime.world.observer.globals["GLOB1"] == 0.0
  @test count(t -> t.alive, runtime.world.turtles) == 1
  @test count(patch -> patch.own["MARK"] != 0.0 || patch.pcolor == 55.0 || patch.plabel == "tag", runtime.world.patches) == 0

  call!(runtime, "setup")
  call!(runtime, "resize-demo")

  @test runtime.world.observer.globals["DIMS"] == Any[11.0, 11.0, 0.0, 10.0, 0.0, 10.0]
  @test runtime.world.observer.globals["STALE-WORD"] == "nobody"
  @test count(t -> t.alive, runtime.world.turtles) == 0

  call!(runtime, "setup")
  call!(runtime, "hard-clear")

  @test runtime.world.ticks == 0.0
  @test runtime.world.observer.globals["GLOB1"] == 0.0
  @test count(t -> t.alive, runtime.world.turtles) == 0
end

@testset "integration: patch-size commands" begin
  runtime = create_runtime(netlogo"""
  globals [initial-size squared-size decimal-size]

  to setup
    clear-all
    set initial-size patch-size
    set-patch-size patch-size * patch-size
    set squared-size patch-size
    set-patch-size 5.2
    set decimal-size patch-size
  end

  to invalid-zero
    set-patch-size 5
    set-patch-size 0
  end

  to invalid-negative
    set-patch-size 5
    set-patch-size (-5)
  end
  """; seed=547)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["INITIAL-SIZE"] == 12.0
  @test runtime.world.observer.globals["SQUARED-SIZE"] == 144.0
  @test runtime.world.observer.globals["DECIMAL-SIZE"] == 5.2
  @test runtime.world.patch_size == 5.2

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "invalid-zero")
  @test runtime.world.patch_size == 5.0

  @test_throws NetLogo.LogoRuntimeError call!(runtime, "invalid-negative")
  @test runtime.world.patch_size == 5.0
end

@testset "integration: rng coordinate and normal reporters" begin
  runtime = create_runtime(netlogo"""
  globals [coord-extrema normal-one normal-two]

  to setup
    clear-all
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
    create-turtles 50 [ setxy random-xcor random-ycor ]
    random-seed 12
    set normal-one n-values 3 [random-normal 10 1]
    random-seed 12
    set normal-two n-values 3 [random-normal 10 1]
  end
  """; min_pxcor=-2, max_pxcor=2, min_pycor=-3, max_pycor=3, topology=BoxTopology, seed=631)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["COORD-EXTREMA"] == Any[-2.0, 2.0, -2.0, 2.0, -3.0, 3.0, -3.0, 3.0]
  @test runtime.world.observer.globals["NORMAL-ONE"] == runtime.world.observer.globals["NORMAL-TWO"]
  @test count(t -> t.alive, runtime.world.turtles) == 50
  @test all(t -> -2.5 <= t.xcor < 2.5 && -3.5 <= t.ycor < 3.5, runtime.world.turtles)
end

@testset "integration: no-wrap spatial reporters" begin
  runtime = create_runtime(netlogo"""
  breed [wolves wolf]
  wolves-own [wrapped-pack nowrap-pack wrapped-cone nowrap-cone]
  globals [
    wrapped-gap nowrap-gap wrapped-heading nowrap-heading
    wrapped-xy-gap nowrap-xy-gap wrapped-xy-heading nowrap-xy-heading
    wrapped-face nowrap-face wrapped-facexy nowrap-facexy
    wrapped-territory nowrap-territory alpha-nowrap-pack alpha-nowrap-cone
  ]

  to setup
    clear-all
    create-wolves 4 [
      setxy 0 0
      set wrapped-pack 0
      set nowrap-pack 0
      set wrapped-cone 0
      set nowrap-cone 0
    ]
    ask turtle 0 [ setxy 1 0 set heading 90 ]
    ask turtle 1 [ setxy -1 0 ]
    ask turtle 2 [ setxy 0 0 ]
    ask turtle 3 [ setxy 1 1 ]
    ask turtle 0 [
      set wrapped-pack count wolves in-radius 1
      set nowrap-pack count wolves in-radius-nowrap 1
      set wrapped-cone count wolves in-cone 2.1 90
      set nowrap-cone count wolves in-cone-nowrap 2.1 90
    ]
    set wrapped-gap [distance turtle 1] of turtle 0
    set nowrap-gap [distance-nowrap turtle 1] of turtle 0
    set wrapped-heading [towards turtle 1] of turtle 0
    set nowrap-heading [towards-nowrap turtle 1] of turtle 0
    set wrapped-xy-gap [distancexy -1 0] of turtle 0
    set nowrap-xy-gap [distancexy-nowrap -1 0] of turtle 0
    set wrapped-xy-heading [towardsxy -1 0] of turtle 0
    set nowrap-xy-heading [towardsxy-nowrap -1 0] of turtle 0
    ask turtle 0 [
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
    ]
    ask patch 1 0 [
      set wrapped-territory count patches in-radius 1
      set nowrap-territory count patches in-radius-nowrap 1
    ]
    set alpha-nowrap-pack [nowrap-pack] of turtle 0
    set alpha-nowrap-cone [nowrap-cone] of turtle 0
  end

  to-report nowrap-pack-again
    report [count wolves in-radius-nowrap 1] of turtle 0
  end

  to-report nowrap-cone-again
    report [count wolves in-cone-nowrap 2.1 90] of turtle 0
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
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=Torus, seed=59)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["WRAPPED-GAP"] == 1.0
  @test runtime.world.observer.globals["NOWRAP-GAP"] == 2.0
  @test runtime.world.observer.globals["WRAPPED-HEADING"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-HEADING"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-XY-GAP"] == 1.0
  @test runtime.world.observer.globals["NOWRAP-XY-GAP"] == 2.0
  @test runtime.world.observer.globals["WRAPPED-XY-HEADING"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-XY-HEADING"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-FACE"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-FACE"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-FACEXY"] == 90.0
  @test runtime.world.observer.globals["NOWRAP-FACEXY"] == 270.0
  @test runtime.world.observer.globals["WRAPPED-TERRITORY"] == 5.0
  @test runtime.world.observer.globals["NOWRAP-TERRITORY"] == 4.0
  @test runtime.world.observer.globals["ALPHA-NOWRAP-PACK"] == 3.0
  @test runtime.world.observer.globals["ALPHA-NOWRAP-CONE"] == 1.0
  @test call!(runtime, "nowrap-pack-again") == 3.0
  @test call!(runtime, "nowrap-cone-again") == 1.0
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-face-nowrap")
  @test_throws NetLogo.LogoRuntimeError call!(runtime, "bad-facexy-nowrap")
end

@testset "integration: selector expansion reporters" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [synapses synapse]
  synapses-own [weight]
  turtles-own [energy selected-input]
  globals [weak-count strong-count top-weight total-selected-input nonnumeric-count]

  to setup
    clear-all
    crt 4 [
      set energy item who [1 2 2 4]
      set selected-input 0
      setxy 0 0
    ]
    ask turtle 0 [ create-synapse-to turtle 3 [ set weight 1 ] ]
    ask turtle 1 [ create-synapse-to turtle 3 [ set weight 2 ] ]
    ask turtle 2 [ create-synapse-to turtle 3 [ set weight 3 ] ]
    set weak-count count min-n-of 2 turtles [energy]
    set strong-count count max-n-of 2 turtles [energy]
    set top-weight max [weight] of max-n-of 2 synapses [weight]
    ask turtle 3 [
      set selected-input sum [weight] of max-n-of 2 my-in-synapses [weight]
    ]
    set total-selected-input [selected-input] of turtle 3
    set nonnumeric-count count min-n-of 1 turtles [breed]
  end

  to-report weakest-has-turtle-zero?
    report member? turtle 0 min-n-of 2 turtles [energy]
  end

  to-report strongest-has-turtle-three?
    report member? turtle 3 max-n-of 2 turtles [energy]
  end
  """; seed=43)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["WEAK-COUNT"] == 2.0
  @test runtime.world.observer.globals["STRONG-COUNT"] == 2.0
  @test runtime.world.observer.globals["TOP-WEIGHT"] == 3.0
  @test runtime.world.observer.globals["TOTAL-SELECTED-INPUT"] == 5.0
  @test runtime.world.observer.globals["NONNUMERIC-COUNT"] == 0.0
  @test call!(runtime, "weakest-has-turtle-zero?") == true
  @test call!(runtime, "strongest-has-turtle-three?") == true
end

@testset "integration: statistical reporters" begin
  runtime = create_runtime(netlogo"""
  globals [
    sample-variance sample-standard-deviation ignored-variance empty-variance-message
    singleton-standard-deviation-message rounded-mean rounded-standard-deviation
    rounded-thousands rounded-hundreds
  ]

  to setup
    clear-all
    random-seed 2468
    let draws n-values 10000 [random-normal 10 1]
    set sample-variance variance [2 7 4 3 5]
    set sample-standard-deviation standard-deviation [1 2 3 4 5 6]
    set ignored-variance variance [2 "skip" 4]
    set empty-variance-message ""
    set singleton-standard-deviation-message ""
    carefully [ __ignore variance [] ] [ set empty-variance-message error-message ]
    carefully [ __ignore standard-deviation [5] ] [ set singleton-standard-deviation-message error-message ]
    set rounded-mean precision (mean draws) 1
    set rounded-standard-deviation precision (standard-deviation draws) 1
    set rounded-thousands precision 3834 (-3)
    set rounded-hundreds precision 2175 (-2)
  end

  to-report rounded-origin-distance
    clear-all
    crt 1 [ setxy 3 4 ]
    report [precision (distancexy 0 0) 12] of turtle 0
  end
  """; seed=109)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SAMPLE-VARIANCE"] == 3.7
  @test runtime.world.observer.globals["SAMPLE-STANDARD-DEVIATION"] ≈ 1.8708286933869707
  @test runtime.world.observer.globals["IGNORED-VARIANCE"] == 2.0
  @test runtime.world.observer.globals["EMPTY-VARIANCE-MESSAGE"] == "Can't find the variance of a list without at least two numbers: []."
  @test runtime.world.observer.globals["SINGLETON-STANDARD-DEVIATION-MESSAGE"] == "Can't find the standard deviation of a list without at least two numbers: [5]"
  @test runtime.world.observer.globals["ROUNDED-MEAN"] == 10.0
  @test runtime.world.observer.globals["ROUNDED-STANDARD-DEVIATION"] == 1.0
  @test runtime.world.observer.globals["ROUNDED-THOUSANDS"] == 4000.0
  @test runtime.world.observer.globals["ROUNDED-HUNDREDS"] == 2200.0
  @test call!(runtime, "rounded-origin-distance") == 5.0
end

@testset "integration: numeric compatibility reporters" begin
  runtime = create_runtime(netlogo"""
  globals [
    trig-values heading-values arithmetic-values tan-zero-count tan-overflow-count
    divide-message mod-message remainder-message atan-message asin-message acos-message
    mean-message median-message min-message max-message
    power-values power-nonnumber-message power-overflow-message
  ]

  to setup
    clear-all
    set trig-values (list (sin 90) (cos 180) (tan 45) (asin (-1)) (acos 0) (atan 1 (-1)) (atan (-1) 1) (sin 90 + 1))
    set heading-values (list (subtract-headings 355 10) (subtract-headings 10 355) (subtract-headings 0 180) (subtract-headings 3660 10))
    set arithmetic-values (list (62 mod 5) (remainder 62 5) (remainder (-8) 3) (3 / 1.5))
    set power-values (list (9 ^ 2) (9 ^ 0.5) (2 ^ 3 ^ 4) (2 ^ -1) (2 ^ -3) (2 ^ 0) (2 * 3 ^ 2) (2 ^ 3 * 4))
    set tan-zero-count 0
    set tan-overflow-count 0
    if tan (-540) = 0 [ set tan-zero-count tan-zero-count + 1 ]
    if tan (-360) = 0 [ set tan-zero-count tan-zero-count + 1 ]
    if tan (-180) = 0 [ set tan-zero-count tan-zero-count + 1 ]
    if tan 0 = 0 [ set tan-zero-count tan-zero-count + 1 ]
    if tan 180 = 0 [ set tan-zero-count tan-zero-count + 1 ]
    if tan 360 = 0 [ set tan-zero-count tan-zero-count + 1 ]
    if tan 540 = 0 [ set tan-zero-count tan-zero-count + 1 ]
    carefully [ __ignore tan (-450) ] [ if error-message = "math operation produced a number too large for NetLogo" [ set tan-overflow-count tan-overflow-count + 1 ] ]
    carefully [ __ignore tan (-270) ] [ if error-message = "math operation produced a number too large for NetLogo" [ set tan-overflow-count tan-overflow-count + 1 ] ]
    carefully [ __ignore tan (-90) ] [ if error-message = "math operation produced a number too large for NetLogo" [ set tan-overflow-count tan-overflow-count + 1 ] ]
    carefully [ __ignore tan 90 ] [ if error-message = "math operation produced a number too large for NetLogo" [ set tan-overflow-count tan-overflow-count + 1 ] ]
    carefully [ __ignore tan 270 ] [ if error-message = "math operation produced a number too large for NetLogo" [ set tan-overflow-count tan-overflow-count + 1 ] ]
    carefully [ __ignore tan 450 ] [ if error-message = "math operation produced a number too large for NetLogo" [ set tan-overflow-count tan-overflow-count + 1 ] ]
    set divide-message ""
    set mod-message ""
    set remainder-message ""
    set atan-message ""
    set asin-message ""
    set acos-message ""
    set mean-message ""
    set median-message ""
    set min-message ""
    set max-message ""
    set power-nonnumber-message ""
    set power-overflow-message ""
    carefully [ __ignore 3 / 0 ] [ set divide-message error-message ]
    carefully [ __ignore 10 mod 0 ] [ set mod-message error-message ]
    carefully [ __ignore remainder 10 0 ] [ set remainder-message error-message ]
    carefully [ __ignore atan 0 0 ] [ set atan-message error-message ]
    carefully [ __ignore asin 1.00001 ] [ set asin-message error-message ]
    carefully [ __ignore acos (-1.00001) ] [ set acos-message error-message ]
    carefully [ __ignore -1 ^ 0.5 ] [ set power-nonnumber-message error-message ]
    carefully [ __ignore (exp 1) ^ 1024 ] [ set power-overflow-message error-message ]
    carefully [ __ignore mean [] ] [ set mean-message error-message ]
    carefully [ __ignore median ["sports" "music" "dance"] ] [ set median-message error-message ]
    carefully [ __ignore min ["sports" "music" "dance"] ] [ set min-message error-message ]
    carefully [ __ignore max ["sports" "music" "dance"] ] [ set max-message error-message ]
  end
  """; seed=211)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["TRIG-VALUES"] == Any[1.0, -1.0, 0.9999999999999999, -90.0, 90.0, 135.0, 315.0, 2.0]
  @test runtime.world.observer.globals["HEADING-VALUES"] == Any[-15.0, 15.0, 180.0, 50.0]
  @test runtime.world.observer.globals["ARITHMETIC-VALUES"] == Any[2.0, 2.0, -2.0, 2.0]
  @test runtime.world.observer.globals["POWER-VALUES"] == Any[81.0, 3.0, 4096.0, 0.5, 0.125, 1.0, 18.0, 32.0]
  @test runtime.world.observer.globals["TAN-ZERO-COUNT"] == 7.0
  @test runtime.world.observer.globals["TAN-OVERFLOW-COUNT"] == 6.0
  @test runtime.world.observer.globals["DIVIDE-MESSAGE"] == "Division by zero."
  @test runtime.world.observer.globals["MOD-MESSAGE"] == "Division by zero."
  @test runtime.world.observer.globals["REMAINDER-MESSAGE"] == "Division by zero."
  @test runtime.world.observer.globals["ATAN-MESSAGE"] == "atan is undefined when both inputs are zero."
  @test runtime.world.observer.globals["ASIN-MESSAGE"] == "math operation produced a non-number"
  @test runtime.world.observer.globals["ACOS-MESSAGE"] == "math operation produced a non-number"
  @test runtime.world.observer.globals["POWER-NONNUMBER-MESSAGE"] == "math operation produced a non-number"
  @test runtime.world.observer.globals["POWER-OVERFLOW-MESSAGE"] == "math operation produced a number too large for NetLogo"
  @test runtime.world.observer.globals["MEAN-MESSAGE"] == "Can't find the mean of a list with no numbers: []."
  @test runtime.world.observer.globals["MEDIAN-MESSAGE"] == "Can't find the median of a list with no numbers: [sports music dance]."
  @test runtime.world.observer.globals["MIN-MESSAGE"] == "Can't find the minimum of a list with no numbers: [sports music dance]"
  @test runtime.world.observer.globals["MAX-MESSAGE"] == "Can't find the maximum of a list with no numbers: [sports music dance]"
end

@testset "integration: link identity reporters" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [streets street]
  undirected-link-breed [roads road]
  globals [
    source-out-links source-in-links dest-out-links dest-in-links
    generic-link-choices road-breed street-out-breed street-in-breed
    source-out-neighbors source-in-neighbors
  ]

  to setup
    clear-all
    crt 2 [ setxy who 0 ]
    ask turtle 0 [
      create-link-with turtle 1
      create-link-to turtle 1
      create-road-with turtle 1
      create-street-to turtle 1
    ]
    set source-out-links count [my-out-links] of turtle 0
    set source-in-links count [my-in-links] of turtle 0
    set dest-out-links count [my-out-links] of turtle 1
    set dest-in-links count [my-in-links] of turtle 1
    set source-out-neighbors count [out-link-neighbors] of turtle 0
    set source-in-neighbors count [in-link-neighbors] of turtle 0
    set generic-link-choices length remove-duplicates [ n-values 50 [ link-with turtle 1 ] ] of turtle 0
    ask turtle 0 [
      let road-link road-with turtle 1
      let street-link out-street-to turtle 1
      set road-breed [breed] of road-link
      set street-out-breed [breed] of street-link
    ]
    ask turtle 1 [
      let street-link in-street-from turtle 0
      set street-in-breed [breed] of street-link
    ]
  end

  to-report directed-generic-link?
    clear-all
    crt 2 [ setxy who 0 ]
    ask turtle 0 [ create-link-to turtle 1 ]
    report is-directed-link? [out-link-to turtle 1] of turtle 0
  end
  """; seed=149)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SOURCE-OUT-LINKS"] == 4.0
  @test runtime.world.observer.globals["SOURCE-IN-LINKS"] == 2.0
  @test runtime.world.observer.globals["DEST-OUT-LINKS"] == 2.0
  @test runtime.world.observer.globals["DEST-IN-LINKS"] == 4.0
  @test runtime.world.observer.globals["SOURCE-OUT-NEIGHBORS"] == 1.0
  @test runtime.world.observer.globals["SOURCE-IN-NEIGHBORS"] == 1.0
  @test runtime.world.observer.globals["GENERIC-LINK-CHOICES"] == 4.0
  @test runtime.world.observer.globals["ROAD-BREED"] isa NetLogo.AgentSet
  @test runtime.world.observer.globals["ROAD-BREED"].breed == "ROADS"
  @test runtime.world.observer.globals["STREET-OUT-BREED"] isa NetLogo.AgentSet
  @test runtime.world.observer.globals["STREET-OUT-BREED"].breed == "STREETS"
  @test runtime.world.observer.globals["STREET-IN-BREED"] isa NetLogo.AgentSet
  @test runtime.world.observer.globals["STREET-IN-BREED"].breed == "STREETS"
  @test call!(runtime, "directed-generic-link?") == true
end

@testset "integration: clear-links command" begin
  runtime = create_runtime(netlogo"""
  globals [
    post-clear-neighbor-count post-clear-my-link-count
    generic-before-clear generic-after-clear
    out-after-clear in-after-clear
  ]

  to seed-many-links
    clear-all
    crt 4
    ask turtle 0 [ create-links-with other turtles ]
  end

  to clear-demo
    clear-links
    set post-clear-neighbor-count count [link-neighbors] of turtle 0
    set post-clear-my-link-count count [my-links] of turtle 0
  end

  to seed-radius-links
    clear-all
    ask patch 0 0 [ sprout 3 ]
    ask turtle 0 [ create-link-with turtle 2 ]
    let ordered sort turtles
    set generic-before-clear map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (link-neighbor? myself)]] of target))] ordered
  end

  to relink-after-clear
    clear-links
    ask turtle 0 [ create-link-to turtle 1 ]
    let ordered sort turtles
    set generic-after-clear map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (link-neighbor? myself)]] of target))] ordered
    set out-after-clear map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (out-link-neighbor? myself)]] of target))] ordered
    set in-after-clear map [[target] -> (list ([who] of target) ([count turtles in-radius 2 with [not (in-link-neighbor? myself)]] of target))] ordered
  end
  """; seed=223)

  call!(runtime, "seed-many-links")
  @test length(runtime.world.links) == 3

  call!(runtime, "clear-demo")
  @test isempty(runtime.world.links)
  @test runtime.world.observer.globals["POST-CLEAR-NEIGHBOR-COUNT"] == 0.0
  @test runtime.world.observer.globals["POST-CLEAR-MY-LINK-COUNT"] == 0.0

  call!(runtime, "seed-radius-links")
  @test runtime.world.observer.globals["GENERIC-BEFORE-CLEAR"] == Any[Any[0.0, 2.0], Any[1.0, 3.0], Any[2.0, 2.0]]

  call!(runtime, "relink-after-clear")
  @test length(runtime.world.links) == 1
  @test runtime.world.observer.globals["GENERIC-AFTER-CLEAR"] == Any[Any[0.0, 2.0], Any[1.0, 2.0], Any[2.0, 3.0]]
  @test runtime.world.observer.globals["OUT-AFTER-CLEAR"] == Any[Any[0.0, 3.0], Any[1.0, 2.0], Any[2.0, 3.0]]
  @test runtime.world.observer.globals["IN-AFTER-CLEAR"] == Any[Any[0.0, 2.0], Any[1.0, 3.0], Any[2.0, 3.0]]
end

@testset "integration: RNG distribution reporters" begin
  runtime = create_runtime(netlogo"""
  globals [rounded-exp-mean rounded-gamma-mean rounded-gamma-variance rounded-poisson-mean]

  to setup
    clear-all
    random-seed 2025
    let exp-draws n-values 20000 [random-exponential 2]
    set rounded-exp-mean precision (mean exp-draws) 1
    random-seed 2722
    let gamma-draws n-values 50000 [random-gamma 50 5]
    set rounded-gamma-mean precision (mean gamma-draws) 1
    set rounded-gamma-variance precision (variance gamma-draws) 1
    random-seed 3031
    let poisson-draws n-values 20000 [random-poisson 3.4]
    set rounded-poisson-mean precision (mean poisson-draws) 1
  end

  to-report poisson-samples
    random-seed 4041
    report n-values 25 [random-poisson 3.4]
  end
  """; seed=163)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["ROUNDED-EXP-MEAN"] == 2.0
  @test runtime.world.observer.globals["ROUNDED-GAMMA-MEAN"] == 10.0
  @test runtime.world.observer.globals["ROUNDED-GAMMA-VARIANCE"] == 2.0
  @test runtime.world.observer.globals["ROUNDED-POISSON-MEAN"] == 3.4
  @test all(value -> value >= 0 && value == floor(value), call!(runtime, "poisson-samples"))
end

@testset "integration: shuffle and sampling helpers" begin
  runtime = create_runtime(netlogo"""
  globals [
    counter shuffled repeated-shuffle empty-one-of-error negative-n-of-error
    oversize-n-of-error rounded-lengths
  ]

  to-report foo
    set counter counter + 1
    report (list counter counter counter)
  end

  to setup
    clear-all
    set counter 0
    random-seed 2782
    set shuffled shuffle [1 2 3 4 5]
    random-seed 2782
    set repeated-shuffle shuffle [1 2 3 4 5]
    random-seed 27892
    let a n-of 2.2 [1 2 3]
    random-seed 27892
    let b n-of 2.5 [1 2 3]
    random-seed 27892
    let c n-of 2.7 [1 2 3]
    set rounded-lengths (list (length a) (length b) (length c))
    carefully [ set counter one-of [] ] [ set empty-one-of-error error-message ]
    carefully [ set rounded-lengths n-of (-1) [1 2 3] ] [ set negative-n-of-error error-message ]
    carefully [ set rounded-lengths n-of 1 [] ] [ set oversize-n-of-error error-message ]
  end

  to-report foo-draws
    report (list (one-of foo) (one-of foo))
  end
  """; seed=173)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SHUFFLED"] == runtime.world.observer.globals["REPEATED-SHUFFLE"]
  @test sort(runtime.world.observer.globals["SHUFFLED"]) == Any[1.0, 2.0, 3.0, 4.0, 5.0]
  @test runtime.world.observer.globals["ROUNDED-LENGTHS"] == Any[2.0, 2.0, 2.0]
  @test runtime.world.observer.globals["EMPTY-ONE-OF-ERROR"] == "ONE-OF got an empty list as input."
  @test runtime.world.observer.globals["NEGATIVE-N-OF-ERROR"] == "First input to N-OF can't be negative."
  @test runtime.world.observer.globals["OVERSIZE-N-OF-ERROR"] == "Requested 1 random items from a list of length 0."
  @test call!(runtime, "foo-draws") == Any[1.0, 2.0]
end

@testset "integration: tick and timer controls" begin
  runtime = create_runtime(netlogo"""
  globals [
    ticks-after-advance missing-before-reset missing-after-clear
    negative-advance-error
  ]

  to setup
    clear-all
    carefully [ set ticks-after-advance ticks ] [ set missing-before-reset error-message ]
    reset-ticks
    tick
    tick-advance 0.1
    set ticks-after-advance ticks
    carefully [ tick-advance (-0.1) ] [ set negative-advance-error error-message ]
    clear-ticks
    carefully [ set ticks-after-advance ticks ] [ set missing-after-clear error-message ]
  end

  to reset-the-timer
    reset-timer
  end

  to-report current-timer-demo
    report timer
  end
  """; seed=181)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["TICKS-AFTER-ADVANCE"] == 1.1
  @test runtime.world.observer.globals["MISSING-BEFORE-RESET"] == "The tick counter has not been started yet. Use RESET-TICKS."
  @test runtime.world.observer.globals["MISSING-AFTER-CLEAR"] == "The tick counter has not been started yet. Use RESET-TICKS."
  @test runtime.world.observer.globals["NEGATIVE-ADVANCE-ERROR"] == "Cannot advance the tick counter by a negative amount."
  @test call!(runtime, "current-timer-demo") >= 0.0
  call!(runtime, "reset-the-timer")
  sleep(0.05)
  @test call!(runtime, "current-timer-demo") >= 0.02
end

@testset "integration: dead agent control semantics" begin
  runtime = create_runtime(netlogo"""
  breed [mice mouse]
  globals [
    dead-ref dead-color-error dead-distance-error dead-towards-error
    nested-after-die hatch-after-die
  ]

  to setup
    clear-all
    set dead-ref nobody
    create-mice 1 [ set dead-ref self die ]
    create-turtles 1 [ setxy 1 0 ]
    carefully [ set dead-color-error [color] of dead-ref ] [ set dead-color-error error-message ]
    ask turtle 1 [ carefully [ __ignore distance dead-ref ] [ set dead-distance-error error-message ] ]
    ask turtle 1 [ carefully [ __ignore towards dead-ref ] [ set dead-towards-error error-message ] ]
  end

  to nested-death
    clear-all
    set nested-after-die 0
    create-turtles 2
    ask turtle 0 [ ask turtle 1 [ ask turtle 0 [ die ] ] set nested-after-die 5 ]
  end

  to hatch-parent-death
    clear-all
    set hatch-after-die 0
    create-turtles 1
    ask turtle 0 [ hatch 1 [ ask myself [ die ] ] set hatch-after-die 5 ]
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
    ask turtle 0 [ set dead-color-error fail-via-ask ]
  end

  to call-fail-direct
    clear-all
    create-turtles 1
    ask turtle 0 [ set dead-color-error fail-direct ]
  end

  to inspect-dead
    inspect dead-ref
  end
  """; seed=191)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["DEAD-COLOR-ERROR"] == "That mouse is dead."
  @test runtime.world.observer.globals["DEAD-DISTANCE-ERROR"] == "That mouse is dead."
  @test runtime.world.observer.globals["DEAD-TOWARDS-ERROR"] == "That mouse is dead."

  inspect_error = try
    call!(runtime, "inspect-dead")
    nothing
  catch err
    err
  end
  @test inspect_error isa NetLogo.LogoRuntimeError
  @test inspect_error.message == "That mouse is dead."

  call!(runtime, "nested-death")
  @test runtime.world.observer.globals["NESTED-AFTER-DIE"] == 0

  call!(runtime, "hatch-parent-death")
  @test runtime.world.observer.globals["HATCH-AFTER-DIE"] == 0

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

@testset "integration: comparison operators" begin
  runtime = create_runtime(netlogo"""
  directed-link-breed [directed-edges directed-edge]
  undirected-link-breed [undirected-edges undirected-edge]
  undirected-link-breed [undirected-edges2 undirected-edge2]
  directed-link-breed [directed-edges2 directed-edge2]
  globals [
    patch-ref string-flags turtle-flags patch-flags link-flags
    sorted-link-kinds mixed-error mixed-link-error
  ]

  to-report link-kind [link-agent]
    if is-directed-edge? link-agent [ report "DE1" ]
    if is-undirected-edge? link-agent [ report "UE1" ]
    if is-undirected-edge2? link-agent [ report "UE2" ]
    report "DE2"
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

  to setup
    clear-all
    create-turtles 3 [ setxy who 0 ]
    ask turtle 0 [ create-directed-edges-to other turtles ]
    ask turtle 1 [ create-directed-edges-to other turtles ]
    ask turtle 0 [ create-undirected-edges-with other turtles ]
    ask turtle 0 [ create-directed-edges2-to other turtles ]
    ask turtle 0 [ create-undirected-edges2-with other turtles ]
    set patch-ref [patch-here] of turtle 0
    set string-flags (list ("cow" < "moo") ("moo" < "cow") ("moo" >= "cow") ("cow" <= "cow"))
    set turtle-flags (list (turtle 0 < turtle 1) (turtle 0 <= turtle 1) (turtle 0 > turtle 1) (turtle 0 >= turtle 0))
    set patch-flags (list (patch 0 0 > patch 0 1) (patch 0 0 < patch 1 0) (patch 0 0 <= patch 0 0))
    set link-flags (list link-flag-1 link-flag-2 link-flag-3 link-flag-4 link-flag-5)
    set sorted-link-kinds map link-kind (sort links)
    carefully [ __ignore patch-ref < turtle 0 ] [ set mixed-error error-message ]
    carefully [ __ignore patch-ref <= undirected-edge 0 1 ] [ set mixed-link-error error-message ]
  end
  """; seed=223)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["STRING-FLAGS"] == Any[true, false, true, true]
  @test runtime.world.observer.globals["TURTLE-FLAGS"] == Any[true, true, false, true]
  @test runtime.world.observer.globals["PATCH-FLAGS"] == Any[true, true, true]
  @test runtime.world.observer.globals["LINK-FLAGS"] == Any[true, true, true, true, true]
  @test runtime.world.observer.globals["SORTED-LINK-KINDS"] == Any["DE1", "DE1", "DE1", "DE1", "UE1", "UE1", "UE2", "UE2", "DE2", "DE2"]
  @test runtime.world.observer.globals["MIXED-ERROR"] == "The < operator can only be used on two numbers, two strings, or two agents of the same type, but not on a patch and a turtle."
  @test runtime.world.observer.globals["MIXED-LINK-ERROR"] == "The <= operator can only be used on two numbers, two strings, or two agents of the same type, but not on a patch and a link."
end

@testset "integration: general type predicates" begin
  runtime = create_runtime(netlogo"""
  globals [
    cmd-task rep-task nested-total scalar-flags task-flags list-shape-flags
  ]

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

  to setup
    clear-all
    set nested-total 0
    set cmd-task [ -> set nested-total 5 ]
    set rep-task [ x -> x + 1 ]
    set scalar-flags (list scalar-flag-1 scalar-flag-2 scalar-flag-3 scalar-flag-4 scalar-flag-5 scalar-flag-6 scalar-flag-7 scalar-flag-8 scalar-flag-9)
    set task-flags (list task-flag-1 task-flag-2 task-flag-3 task-flag-4 task-flag-5 task-flag-6 task-flag-7 task-flag-8)
    set list-shape-flags map is-list? [1 [2] "skip" false]
  end
  """; seed=229)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SCALAR-FLAGS"] == Any[true, true, false, true, false, false, true, true, false]
  @test runtime.world.observer.globals["TASK-FLAGS"] == Any[true, false, true, true, true, true, false, false]
  @test runtime.world.observer.globals["LIST-SHAPE-FLAGS"] == Any[false, true, false, false]
end

@testset "integration: boolean reporters" begin
  runtime = create_runtime(netlogo"""
  globals [and-values or-values xor-values not-values false-and-boom-value true-or-boom-value xor-error-message precedence-value]

  to-report boom
    error "boom!"
  end

  to setup
    set and-values (list (true and true) (true and false) (false and true) (false and false))
    set or-values (list (true or true) (true or false) (false or true) (false or false))
    set xor-values (list (true xor true) (true xor false) (false xor true) (false xor false))
    set not-values (list (not true) (not false))
    set false-and-boom-value false and boom
    set true-or-boom-value true or boom
    carefully [ set xor-error-message true xor boom ] [ set xor-error-message error-message ]
    set precedence-value true or false and false
  end
  """; seed=244)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["AND-VALUES"] == Any[true, false, false, false]
  @test runtime.world.observer.globals["OR-VALUES"] == Any[true, true, true, false]
  @test runtime.world.observer.globals["XOR-VALUES"] == Any[false, true, true, false]
  @test runtime.world.observer.globals["NOT-VALUES"] == Any[false, true]
  @test runtime.world.observer.globals["FALSE-AND-BOOM-VALUE"] == false
  @test runtime.world.observer.globals["TRUE-OR-BOOM-VALUE"] == true
  @test runtime.world.observer.globals["XOR-ERROR-MESSAGE"] == "boom!"
  @test runtime.world.observer.globals["PRECEDENCE-VALUE"] == false
end

@testset "integration: agent identity and introspection" begin
  runtime = create_runtime(netlogo"""
  globals [self-count observer-myself nested-myself nested-of-myself self-after-error who-not-counts]
  breed [mice mouse]

  to-report carefully-myself
    let result -1
    carefully [ set result myself ] [ ]
    report result
  end

  to-report nested-carefully-myself
    let result -1
    ask turtle 1 [ carefully [ set result myself ] [ ] ]
    report [who] of result
  end

  to-report inner-myself-who
    report [who] of myself
  end

  to-report inner-of-myself
    report [inner-myself-who] of turtle 1
  end

  to-report selfish-self
    carefully [ ask other turtles [ error "Derp" ] ] [ ]
    report who
  end

  to setup
    clear-all
    crt 2 [
      setxy who 0
      set color 0
    ]
    create-mice 2 [
      setxy 0 0
      set color 15
    ]
    set self-count count turtles with [self = turtle who]
    set observer-myself [carefully-myself] of turtle 0
    set nested-myself [nested-carefully-myself] of turtle 0
    set nested-of-myself [inner-of-myself] of turtle 0
    set self-after-error [selfish-self] of turtle 0
    let picked one-of mice
    let remaining mice who-are-not picked
    let non-mice count (turtles who-are-not mice)
    let no-mice count (mice who-are-not turtles)
    let outer-patches count (patches who-are-not patches with [pxcor = 0])
    let remaining-count count remaining
    let contains-picked member? picked remaining
    set who-not-counts (list non-mice no-mice outer-patches remaining-count contains-picked)
  end

  to-report non-mice-colors
    report [color] of turtles who-are-not mice
  end
  """; min_pxcor=-1, max_pxcor=1, min_pycor=-1, max_pycor=1, topology=BoxTopology, seed=237)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["SELF-COUNT"] == 4.0
  @test runtime.world.observer.globals["OBSERVER-MYSELF"] == -1.0
  @test runtime.world.observer.globals["NESTED-MYSELF"] == 0.0
  @test runtime.world.observer.globals["NESTED-OF-MYSELF"] == 0.0
  @test runtime.world.observer.globals["SELF-AFTER-ERROR"] == 0.0
  @test runtime.world.observer.globals["WHO-NOT-COUNTS"] == Any[2.0, 0.0, 6.0, 1.0, false]
  @test call!(runtime, "non-mice-colors") == Any[0.0, 0.0]
end

@testset "integration: all reporter" begin
  runtime = create_runtime(netlogo"""
  globals [empty-all turtles-all-false patch-self-match patch-origin-match patch-labels-all patch-labels-error patch-labels-short-circuit]

  to setup
    clear-all
    ask patches [ set plabel true ]
    set empty-all all? no-turtles [false]
    crt 1 [ setxy 0 0 ]
    set turtles-all-false all? turtles [false]
    set patch-self-match all? patches [patch-at 0 0 = self]
    set patch-origin-match all? patches [patch 0 0 = self]
    set patch-labels-all all? patches [plabel]
    ask patch -4 3 [ set plabel 5 ]
    carefully [ set patch-labels-error all? patches [plabel] ] [ set patch-labels-error error-message ]
    ask patches [ set plabel false ]
    ask patch -4 3 [ set plabel 5 ]
    set patch-labels-short-circuit all? patches [false]
  end
  """; min_pxcor=-4, max_pxcor=4, min_pycor=-4, max_pycor=4, topology=BoxTopology, seed=240)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["EMPTY-ALL"] == true
  @test runtime.world.observer.globals["TURTLES-ALL-FALSE"] == false
  @test runtime.world.observer.globals["PATCH-SELF-MATCH"] == true
  @test runtime.world.observer.globals["PATCH-ORIGIN-MATCH"] == false
  @test runtime.world.observer.globals["PATCH-LABELS-ALL"] == true
  @test runtime.world.observer.globals["PATCH-LABELS-ERROR"] == "ALL? expected a true/false value from (patch -4 3), but got 5 instead."
  @test runtime.world.observer.globals["PATCH-LABELS-SHORT-CIRCUIT"] == false
end

@testset "integration: reference reporter" begin
  runtime = create_runtime(netlogo"""
  globals [foo bar patch-refs turtle-refs observer-refs bad-reference]
  turtles-own [foos]
  patches-own [foos]

  to setup
    clear-all
    crt 1 [ setxy 0 0 ]
    set patch-refs [ (list __reference pxcor __reference pycor __reference pcolor __reference foos) ] of patch 0 0
    set turtle-refs [ (list __reference xcor __reference ycor __reference foos) ] of turtle 0
    set observer-refs (list __reference foo __reference bar)
    set bad-reference __check-syntax "show __reference not-a-var"
  end
  """; seed=238)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["PATCH-REFS"] == Any[
    Any["PATCH", 0.0, "PXCOR"],
    Any["PATCH", 1.0, "PYCOR"],
    Any["PATCH", 2.0, "PCOLOR"],
    Any["PATCH", 5.0, "FOOS"],
  ]
  @test runtime.world.observer.globals["TURTLE-REFS"] == Any[
    Any["TURTLE", 3.0, "XCOR"],
    Any["TURTLE", 4.0, "YCOR"],
    Any["TURTLE", 13.0, "FOOS"],
  ]
  @test runtime.world.observer.globals["OBSERVER-REFS"] == Any[
    Any["OBSERVER", 0.0, "FOO"],
    Any["OBSERVER", 1.0, "BAR"],
  ]
  @test runtime.world.observer.globals["BAD-REFERENCE"] == "Nothing named NOT-A-VAR has been defined."
end

@testset "integration: task stringification" begin
  runtime = create_runtime(netlogo"""
  globals [cmd-task rep-task command-string reporter-string]

  to setup
    clear-all
    set cmd-task [ -> set cmd-task 5 ]
    set rep-task [ x -> x + 1 ]
    set command-string word cmd-task
    set reporter-string word rep-task
  end
  """; seed=239)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["COMMAND-STRING"] == "(anonymous command: [ -> set cmd-task 5 ])"
  @test runtime.world.observer.globals["REPORTER-STRING"] == "(anonymous reporter: [ x -> x + 1 ])"
end

@testset "integration: apply-result and codeblock helpers" begin
  runtime = create_runtime(netlogo"""
  globals [apply-power apply-empty apply-word apply-command apply-command-empty symbol-values block-values arity-one arity-two command-arity-one command-arity-two]

  to setup
    clear-all
    set apply-power __apply-result [ [x y] -> x ^ y ] [3 2]
    set apply-empty __apply-result [ 5 ] []
    set apply-word __apply-result word ["str1" "str2" "str3"]
    __apply [ [num col] -> crt num [ set color col ] ] [10 5]
    let turtle-color [color] of turtle 0
    set apply-command (list count turtles turtle-color)
    clear-turtles
    __apply [ crt 1 ] []
    set apply-command-empty count turtles
    clear-turtles
    set symbol-values (list (__symbol what-is-this) (__symbol xcor) (__symbol turtles) (__symbol turtle))
    set block-values (list (__block [ crt some-stuff ]) (__block [ crt [ setxy foo bar ] ]) (__block [ [foo] -> foo ]))
    set arity-one ""
    set arity-two ""
    set command-arity-one ""
    set command-arity-two ""
    carefully [ set arity-one __apply-result [ [num col] -> num * col ] [10] ] [ set arity-one error-message ]
    carefully [ set arity-two __apply-result [ [num] -> num ] [] ] [ set arity-two error-message ]
    carefully [ __apply [ [num col] -> crt num [ set color col ] ] [10] ] [ set command-arity-one error-message ]
    carefully [ __apply [ [num] -> crt num ] [] ] [ set command-arity-two error-message ]
  end
  """; seed=263)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["APPLY-POWER"] == 9.0
  @test runtime.world.observer.globals["APPLY-EMPTY"] == 5.0
  @test runtime.world.observer.globals["APPLY-WORD"] == "str1str2str3"
  @test runtime.world.observer.globals["APPLY-COMMAND"] == Any[10.0, 5.0]
  @test runtime.world.observer.globals["APPLY-COMMAND-EMPTY"] == 1.0
  @test runtime.world.observer.globals["SYMBOL-VALUES"] == Any["what-is-this", "xcor", "turtles", "turtle"]
  @test runtime.world.observer.globals["BLOCK-VALUES"] == Any["crt some-stuff", "crt [ setxy foo bar ]", "[ foo ] -> foo"]
  @test runtime.world.observer.globals["ARITY-ONE"] == "anonymous procedure expected 2 inputs, but only got 1"
  @test runtime.world.observer.globals["ARITY-TWO"] == "anonymous procedure expected 1 input, but only got 0"
  @test runtime.world.observer.globals["COMMAND-ARITY-ONE"] == "anonymous procedure expected 2 inputs, but only got 1"
  @test runtime.world.observer.globals["COMMAND-ARITY-TWO"] == "anonymous procedure expected 1 input, but only got 0"
end

@testset "integration: task kind mismatch handling" begin
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
  """; seed=251)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["RUNRESULT-ERROR"] ==
    "RUNRESULT expected this input to be a string or anonymous reporter, but got an anonymous command instead"
  @test runtime.world.observer.globals["RUN-ERROR"] ==
    "RUN expected this input to be a string or anonymous command, but got an anonymous reporter instead"
  @test runtime.world.observer.globals["FOREACH-ERROR"] ==
    "FOREACH expected this input to be an anonymous command, but got an anonymous reporter instead"
end

@testset "integration: string run runtime" begin
  runtime = create_runtime(netlogo"""
  globals [check counter message runresult-trace extra-run-error extra-runresult-error bare-run-state bare-runresult-state]
  turtles-own [turtle-var]

  to setup
    clear-all
    set check 0
    set counter 0
    set message ""
    set runresult-trace []
    set extra-run-error ""
    set extra-runresult-error ""
    set bare-run-state []
    set bare-runresult-state []
    crt 1 [ set turtle-var 700000 ]
    run "set check count turtles"
    set runresult-trace (list (runresult "3") (runresult "1 + 2") (runresult "1; + 2"))
    carefully [ run "__ignore 5" 1 ] [ set extra-run-error error-message ]
    carefully [ __ignore (runresult "5" 1) ] [ set extra-runresult-error error-message ]
  end

  to go [proc-arg]
    let proc-let 20
    ask turtle 0 [
      let ask-let 300
      carefully [ run "set check ask-let + turtle-var" ] [ set message error-message ]
      run "set check proc-arg + proc-let + turtle-var"
    ]
  end

  to stop-demo
    set check 0
    run "stop set check 10"
    set check 5
  end

  to-report duplicate-let-message
    let msg ""
    carefully [ run "let a 2 run \\\"let a 3\\\"" ] [ set msg error-message ]
    report msg
  end

  to-report local-isolation
    let s 0
    run "set s -1"
    report s
  end

  to-report paint-source
    report "set color 105"
  end

  to-report count-source
    set counter counter + 1
    report "count turtles + counter"
  end

  to reporter-source-demo
    set counter 0
    ask turtle 0 [ run paint-source ]
    set bare-run-state (list [color] of turtle 0 counter)
    set bare-runresult-state (list (runresult count-source) counter)
  end

  to-report run-once
    set counter 0
    run (word "set counter " (counter + 1))
    report counter
  end
  """; seed=269)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["CHECK"] == 1.0
  @test runtime.world.observer.globals["RUNRESULT-TRACE"] == Any[3.0, 3.0, 1.0]
  @test runtime.world.observer.globals["EXTRA-RUN-ERROR"] == "run doesn't accept further inputs if the first is a string"
  @test runtime.world.observer.globals["EXTRA-RUNRESULT-ERROR"] == "runresult doesn't accept further inputs if the first is a string"

  call!(runtime, "reporter-source-demo")
  @test runtime.world.observer.globals["BARE-RUN-STATE"] == Any[105.0, 0.0]
  @test runtime.world.observer.globals["BARE-RUNRESULT-STATE"] == Any[2.0, 1.0]

  call!(runtime, "go", 1)

  @test runtime.world.observer.globals["CHECK"] == 700021.0
  @test occursin("ASK-LET", runtime.world.observer.globals["MESSAGE"])
  @test call!(runtime, "local-isolation") == 0.0
  @test call!(runtime, "duplicate-let-message") == "There is already a local variable here called A"
  @test call!(runtime, "run-once") == 1.0

  call!(runtime, "stop-demo")
  @test runtime.world.observer.globals["CHECK"] == 0.0
end

@testset "integration: command task non-local exits" begin
  runtime = create_runtime(netlogo"""
  globals [check stop-error report-error globstop globrep]

  to setup
    clear-all
    set check 0
    set stop-error ""
    set report-error ""
    set globstop nobody
    set globrep nobody
  end

  to-report make-stop-task
    report [ -> stop ]
  end

  to-report make-report-task
    report [ -> report 5 ]
  end

  to stop-via-reported-task
    set check 1
    run make-stop-task
    set check 2
  end

  to-report report-via-reported-task
    run make-report-task
  end

  to make-stop-glob
    set globstop [ -> stop ]
  end

  to make-report-glob
    set globrep [ -> report 5 ]
  end

  to-report stop-error-demo
    make-stop-glob
    run globstop
    report 5
  end

  to report-error-demo
    make-report-glob
    run globrep
  end

  to collect-errors
    carefully [ __ignore stop-error-demo ] [ set stop-error error-message ]
    carefully [ report-error-demo ] [ set report-error error-message ]
  end

  to-report foreach-early-exit
    foreach ["apples" "oranges"] [0 0] [ [x y] -> if x = "oranges" [ report x ] ]
  end
  """; seed=283)

  call!(runtime, "setup")
  call!(runtime, "stop-via-reported-task")
  call!(runtime, "collect-errors")

  @test runtime.world.observer.globals["CHECK"] == 1.0
  @test call!(runtime, "report-via-reported-task") == 5.0
  @test runtime.world.observer.globals["STOP-ERROR"] == "STOP is not allowed inside TO-REPORT."
  @test runtime.world.observer.globals["REPORT-ERROR"] == "REPORT can only be used inside TO-REPORT."
  @test call!(runtime, "foreach-early-exit") == "oranges"
end

@testset "integration: ask stop handling" begin
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
  """; seed=287)

  call!(runtime, "setup")
  call!(runtime, "direct-stop-ask")
  call!(runtime, "run-stop-ask")

  @test runtime.world.observer.globals["DIRECT-STOP-HITS"] == Any[1.0, 1.0, 1.0]
  @test runtime.world.observer.globals["RUN-STOP-HITS"] == Any[1.0, 1.0, 1.0]
end

@testset "integration: foreach concise command references" begin
  runtime = create_runtime(netlogo"""
  globals [procedure-total turtle-count extra-input-count forward-y remaining-turtles]

  to foo
    set procedure-total procedure-total + 1
  end

  to-report foreach-procedure-value
    clear-all
    set procedure-total 0
    foreach [1 1 1] foo
    report procedure-total
  end

  to-report foreach-create-value
    clear-all
    foreach [1 2 3] crt
    report count turtles
  end

  to-report foreach-create-extra-input-value
    clear-all
    foreach [1 2 3] [9 9 9] crt
    report count turtles
  end

  to-report foreach-forward-value
    clear-all
    crt 1
    ask turtle 0 [
      set heading 0
      foreach [0.5 0.5 0.5] fd
    ]
    report [ycor] of turtle 0
  end

  to-report foreach-die-value
    clear-all
    crt 1
    ask turtle 0 [
      foreach [1] die
    ]
    report count turtles
  end

  to setup
    clear-all
    let procedure-total-value foreach-procedure-value
    let turtle-count-value foreach-create-value
    let extra-input-count-value foreach-create-extra-input-value
    let forward-y-value foreach-forward-value
    let remaining-turtles-value foreach-die-value
    set procedure-total procedure-total-value
    set turtle-count turtle-count-value
    set extra-input-count extra-input-count-value
    set forward-y forward-y-value
    set remaining-turtles remaining-turtles-value
  end
  """; seed=287)

  call!(runtime, "setup")

  @test runtime.world.observer.globals["PROCEDURE-TOTAL"] == 3.0
  @test runtime.world.observer.globals["TURTLE-COUNT"] == 6.0
  @test runtime.world.observer.globals["EXTRA-INPUT-COUNT"] == 6.0
  @test runtime.world.observer.globals["FORWARD-Y"] == 1.5
  @test runtime.world.observer.globals["REMAINING-TURTLES"] == 0.0
end

@testset "integration: loop and check-syntax" begin
  runtime = create_runtime(netlogo"""
  globals [loop-value syntax-ok syntax-bad scope-ok scope-bad]

  to setup
    clear-all
    set loop-value 0
    set syntax-ok __check-syntax "set loop-value 10"
    set syntax-bad __check-syntax "set loop-value unknown-name"
    set scope-ok ""
    set scope-bad ""
  end

  to loop-demo
    loop [
      if loop-value = 3 [ stop ]
      set loop-value loop-value + 1
    ]
  end

  to go [x]
    let y 5
    set scope-ok __check-syntax "set loop-value x + y"
    set scope-bad __check-syntax "set loop-value x + q"
  end
  """; seed=277)

  call!(runtime, "setup")
  call!(runtime, "loop-demo")
  call!(runtime, "go", 2)

  @test runtime.world.observer.globals["LOOP-VALUE"] == 3.0
  @test runtime.world.observer.globals["SYNTAX-OK"] == ""
  @test runtime.world.observer.globals["SYNTAX-BAD"] == "Nothing named UNKNOWN-NAME has been defined."
  @test runtime.world.observer.globals["SCOPE-OK"] == ""
  @test runtime.world.observer.globals["SCOPE-BAD"] == "Nothing named Q has been defined."
end

@testset "integration: every command" begin
  runtime = create_runtime(netlogo"""
  globals [glob1 first-run scope-run wait-run]

  to-report will-it-run?
    every 20 [ report true ]
    report false
  end

  to go
    set glob1 (fput who glob1)
  end

  to-report every-waits-for-time
    let i 0
    loop [
      every 20 [ if i > 0 [ report true ] ]
      if i > 0 [ report false ]
      set i i + 1
    ]
  end

  to setup
    clear-all
    set glob1 (list)
    crt 5
    ask turtles [ repeat 10 [ every 10 [ go ] ] ]
    set first-run will-it-run?
    set scope-run will-it-run?
    set wait-run every-waits-for-time
  end
  """; seed=577)

  call!(runtime, "setup")

  @test sum(runtime.world.observer.globals["GLOB1"]) == 10.0
  @test runtime.world.observer.globals["FIRST-RUN"] == true
  @test runtime.world.observer.globals["SCOPE-RUN"] == true
  @test runtime.world.observer.globals["WAIT-RUN"] == false
end

# ── csv extension integration ──────────────────────────────────────────
@testset "integration: csv extension" begin
  runtime = create_runtime(compile_model("""
  extensions [csv]
  globals [data encoded decoded]

  to setup
    set data (list (list 1 2 3) (list 4 5 6) (list 7 8 9))
    set encoded csv:to-string data
    set decoded csv:from-string encoded
  end
  """); seed=1)

  call!(runtime, "setup")
  @test runtime.world.observer.globals["ENCODED"] == "1,2,3\n4,5,6\n7,8,9"
  decoded = runtime.world.observer.globals["DECODED"]
  @test decoded == Any[Any[1.0, 2.0, 3.0], Any[4.0, 5.0, 6.0], Any[7.0, 8.0, 9.0]]
end

# ── csv file I/O integration ───────────────────────────────────────────
@testset "integration: csv file I/O" begin
  tmpdir = mktempdir()
  inpath = joinpath(tmpdir, "input.csv")
  outpath = joinpath(tmpdir, "output.csv")
  write(inpath, "name,age,active\nAlice,30,true\nBob,25,false\n\"Eve, Jr\",22,true")

  runtime = create_runtime(compile_model("""
  extensions [csv]
  globals [loaded saved roundtrip-ok semicol-data]

  to setup
    set loaded csv:from-file "$inpath"
    csv:to-file "$outpath" loaded
    set saved csv:from-file "$outpath"
    set roundtrip-ok (loaded = saved)
  end
  """); seed=1)

  call!(runtime, "setup")
  loaded = runtime.world.observer.globals["LOADED"]
  @test loaded == Any[
    Any["name", "age", "active"],
    Any["Alice", 30.0, true],
    Any["Bob", 25.0, false],
    Any["Eve, Jr", 22.0, true]
  ]
  @test runtime.world.observer.globals["ROUNDTRIP-OK"] == true

  # Test delimiter variant
  semipath = joinpath(tmpdir, "semi.csv")
  write(semipath, "a;b;c\n1;2;3")
  rt2 = create_runtime(compile_model("""
  extensions [csv]
  globals [result]
  to setup
    set result csv:from-file-with-delimiter "$semipath" ";"
  end
  """); seed=1)
  call!(rt2, "setup")
  @test rt2.world.observer.globals["RESULT"] == Any[Any["a", "b", "c"], Any[1.0, 2.0, 3.0]]

  rm(tmpdir; recursive=true)
end

# ── table extension integration ────────────────────────────────────────
@testset "integration: table extension" begin
  runtime = create_runtime(compile_model("""
  extensions [table]
  globals [inventory total-value]
  breed [items item]
  items-own [iname price]

  to setup
    set inventory table:make
    create-items 1 [ set iname "apple"  set price 1.50 ]
    create-items 1 [ set iname "bread"  set price 2.75 ]
    create-items 1 [ set iname "cheese" set price 4.00 ]
    ask items [
      table:put inventory iname price
    ]
    compute-total
  end

  to compute-total
    set total-value 0
    let vals table:values inventory
    foreach vals [ v -> set total-value total-value + v ]
  end

  to-report item-count
    report table:length inventory
  end

  to-report lookup [name]
    let found table:has-key? inventory name
    ifelse found [
      report table:get inventory name
    ] [
      report -1
    ]
  end
  """); seed=42)

  call!(runtime, "setup")
  @test call!(runtime, "item-count") == 3.0
  @test runtime.world.observer.globals["TOTAL-VALUE"] == 8.25
  @test call!(runtime, "lookup", Any["apple"]) == 1.5
  @test call!(runtime, "lookup", Any["bread"]) == 2.75
  @test call!(runtime, "lookup", Any["missing"]) == -1.0
end

# ── nw extension integration ──────────────────────────────────────────
@testset "integration: nw extension" begin
  runtime = create_runtime(compile_model("""
  extensions [nw]
  globals [avg-path clust-sum]
  undirected-link-breed [roads road]

  to setup
    create-turtles 6
    ; create a triangle (0-1-2) connected to a chain (2-3-4-5)
    ask turtle 0 [ create-road-with turtle 1 ]
    ask turtle 0 [ create-road-with turtle 2 ]
    ask turtle 1 [ create-road-with turtle 2 ]
    ask turtle 2 [ create-road-with turtle 3 ]
    ask turtle 3 [ create-road-with turtle 4 ]
    ask turtle 4 [ create-road-with turtle 5 ]
    nw:set-context turtles roads
    set avg-path nw:mean-path-length
    set clust-sum 0
    ask turtles [ set clust-sum clust-sum + nw:clustering-coefficient ]
  end

  to-report shortest-dist [a b]
    let d 0
    ask turtle a [ set d nw:distance-to turtle b ]
    report d
  end

  to-report path-nodes [a b]
    let p []
    ask turtle a [ set p nw:path-to turtle b ]
    report map [ t -> [who] of t ] p
  end
  """); seed=1)

  call!(runtime, "setup")

  # triangle distances
  @test call!(runtime, "shortest-dist", Any[0.0, 1.0]) == 1.0
  @test call!(runtime, "shortest-dist", Any[0.0, 2.0]) == 1.0

  # cross-cluster distance
  @test call!(runtime, "shortest-dist", Any[0.0, 5.0]) == 4.0

  # path from 0 to 5 should have 5 nodes
  @test call!(runtime, "path-nodes", Any[0.0, 5.0]) == Any[0.0, 2.0, 3.0, 4.0, 5.0]

  # mean path length should be a positive number
  avg = runtime.world.observer.globals["AVG-PATH"]
  @test avg isa Float64 && avg > 0

  # clustering: triangle nodes have nonzero, chain-only nodes have zero
  @test runtime.world.observer.globals["CLUST-SUM"] > 0
end
