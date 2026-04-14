# CSV Network Foraging Model
# csv extension: tests csv:from-row with file-open/file-read-line pattern,
#   csv:from-row-with-delimiter (semicolon), csv:to-file for output logging
# Resources form a network loaded from CSV files; consumers forage along links.
# Adapted from modelingcommons #6309 (Soil Network Simulation)

struct CsvNetworkForagingModel <: AbstractBenchmarkModel end

model_name(::CsvNetworkForagingModel) = "CSV Network Foraging"
n_ticks(::CsvNetworkForagingModel) = 150
tracked_globals(::CsvNetworkForagingModel) = ["total-supply", "num-consumers", "total-consumed"]
world_dims(::CsvNetworkForagingModel) = (-12, 12, -12, 12)
topology(::CsvNetworkForagingModel) = (false, false)

function setup_files(::CsvNetworkForagingModel, dir::AbstractString)
    # Create comma-delimited node file (id,x,y,capacity,regrow-rate)
    nodes = """id,x,y,capacity,regrow-rate
1,-8,-8,40,3
2,-4,-4,50,4
3,0,0,60,5
4,4,-4,50,4
5,8,-8,40,3
6,-8,4,45,3
7,-4,8,55,5
8,0,4,65,6
9,4,8,55,5
10,8,4,45,3
11,-6,0,35,2
12,6,0,35,2"""
    write(joinpath(dir, "nodes.csv"), nodes)

    # Create comma-delimited link file (from,to)
    links = """from,to
1,2
2,3
3,4
4,5
1,6
6,7
7,8
8,9
9,10
2,11
11,6
4,12
12,10
3,8
11,3
12,3"""
    write(joinpath(dir, "links.csv"), links)
end

function netlogo_code(::CsvNetworkForagingModel)
    return """
extensions [csv]
globals [total-supply num-consumers total-consumed]
breed [nodes a-node]
breed [consumers consumer]
nodes-own [node-id capacity supply regrow-rate]
consumers-own [energy target-node consumption-rate]
links-own []

to setup
  clear-all
  ;; Read nodes from comma-delimited CSV using file-open + csv:from-row pattern
  file-open "nodes.csv"
  let header csv:from-row file-read-line
  while [not file-at-end?] [
    let row csv:from-row file-read-line
    let nid item 0 row
    let nx item 1 row
    let ny item 2 row
    let cap item 3 row
    let rr item 4 row
    create-nodes 1 [
      set node-id nid
      set capacity cap
      set supply cap
      set regrow-rate rr
      setxy nx ny
      set shape "circle"
      set size 2
      set color blue
    ]
  ]
  file-close

  ;; Read links from comma-delimited CSV
  file-open "links.csv"
  let lheader csv:from-row file-read-line
  while [not file-at-end?] [
    let row csv:from-row file-read-line
    let from-id item 0 row
    let to-id item 1 row
    let n1 one-of nodes with [node-id = from-id]
    let n2 one-of nodes with [node-id = to-id]
    if n1 != nobody and n2 != nobody [
      ask n1 [ create-link-with n2 ]
    ]
  ]
  file-close

  ;; Create consumers at random nodes
  let n 15
  repeat n [
    create-consumers 1 [
      set energy 30
      set consumption-rate 2 + random 3
      set target-node nobody
      move-to one-of nodes
      set shape "person"
      set size 1.5
      set color red
    ]
  ]

  set total-consumed 0
  update-globals
  reset-ticks
end

to go
  ;; Resources regrow
  ask nodes [
    if supply < capacity [
      set supply min (list capacity (supply + regrow-rate))
    ]
    set color scale-color blue supply 0 (capacity * 1.5)
  ]

  ;; Consumers forage
  ask consumers [
    ;; Find the local node
    let my-node min-one-of nodes [distance myself]
    ;; Consume resources at current node
    if my-node != nobody [
      let available [supply] of my-node
      let take min (list consumption-rate available)
      ask my-node [ set supply supply - take ]
      set energy energy + take
      set total-consumed total-consumed + take
    ]

    ;; Metabolism
    set energy energy - 1

    ;; Move to a neighboring node with more resources
    if my-node != nobody [
      let neighbors-of-node [link-neighbors] of my-node
      if any? neighbors-of-node [
        let best max-one-of neighbors-of-node [supply]
        if best != nobody [
          if [supply] of best > 0 [
            move-to best
          ]
        ]
      ]
    ]

    ;; Die if no energy
    if energy <= 0 [ die ]
  ]

  ;; Reproduction for well-fed consumers
  ask consumers with [energy > 40] [
    hatch 1 [
      set energy energy / 2
      move-to one-of nodes
    ]
    set energy energy / 2
  ]

  ;; Every 25 ticks, write state to CSV (tests csv:to-file output)
  if ticks mod 25 = 0 [
    let log-data (list (list "tick" "node-id" "supply" "capacity"))
    ask nodes [
      set log-data lput (list ticks node-id supply capacity) log-data
    ]
    csv:to-file "node-state.csv" log-data
  ]

  update-globals
  tick
end

to update-globals
  set total-supply precision (sum [supply] of nodes) 4
  set num-consumers count consumers
end
"""
end
