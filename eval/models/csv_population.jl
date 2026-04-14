# CSV Population Model
# csv extension: tests csv:to-file, csv:from-file, csv:to-string, csv:from-string,
#   csv:to-row, csv:from-row round-trip in go loop
# Agents are initialized from a CSV file written in setup, then periodically
# the full state is serialized to CSV and read back (testing file I/O round-trip).

struct CsvPopulationModel <: AbstractBenchmarkModel end

model_name(::CsvPopulationModel) = "CSV Population"
n_ticks(::CsvPopulationModel) = 100
tracked_globals(::CsvPopulationModel) = ["total-energy", "avg-age", "pop-count"]
world_dims(::CsvPopulationModel) = (-10, 10, -10, 10)
topology(::CsvPopulationModel) = (true, true)

function netlogo_code(::CsvPopulationModel)
    return """
extensions [csv]
globals [total-energy avg-age pop-count csv-roundtrip-ok]
breed [critters critter]
critters-own [energy age-val speed-val]
patches-own [food]

to setup
  clear-all
  ;; Initialize patch food
  ask patches [ set food 2 + random 3  set pcolor scale-color green food 0 8 ]

  ;; Generate initial population data as a list of rows and write to CSV
  let header (list "energy" "age" "speed")
  let rows (list header)
  let idx 0
  while [idx < 30] [
    let en 30 + random 40
    let ag random 10
    let sp 1 + random 4
    set rows lput (list en ag sp) rows
    set idx idx + 1
  ]
  csv:to-file "population.csv" rows

  ;; Read back from CSV and create agents
  let loaded csv:from-file "population.csv"
  foreach but-first loaded [ row ->
    create-critters 1 [
      set energy item 0 row
      set age-val item 1 row
      set speed-val item 2 row
      setxy random-xcor random-ycor
      set shape "circle"
      set color scale-color red energy 0 100
    ]
  ]
  update-globals
  reset-ticks
end

to go
  ;; Patch food regrowth
  ask patches [
    if food < 5 [ set food food + 0.2 ]
    set pcolor scale-color green food 0 8
  ]

  ;; Movement, foraging, and metabolism
  ask critters [
    rt random 360
    fd speed-val / 5
    ;; Eat food on current patch
    let meal min (list food 1.5)
    set food food - meal
    set energy energy + meal
    set age-val age-val + 1
    set energy energy - 0.2
    set color scale-color red energy 0 100
    if energy <= 0 or age-val > 120 [ die ]
  ]

  ;; Reproduction for high-energy agents
  ask critters with [energy > 60] [
    hatch 1 [
      set energy energy / 2
      set age-val 0
      rt random 360
      fd 1
    ]
    set energy energy / 2
  ]

  ;; Every 10 ticks, serialize state to CSV and read back (round-trip test)
  if ticks mod 10 = 0 and any? critters [
    ;; Build state as list-of-lists, write to file
    let state-data (list (list "who" "energy" "age" "speed"))
    ask critters [
      set state-data lput (list who energy age-val speed-val) state-data
    ]
    csv:to-file "state.csv" state-data

    ;; Read back and verify count matches
    let reloaded csv:from-file "state.csv"
    set csv-roundtrip-ok (length reloaded - 1 = count critters)

    ;; Also test csv:to-string / csv:from-string round-trip
    let as-string csv:to-string state-data
    let from-string csv:from-string as-string
    if length from-string != length state-data [
      set csv-roundtrip-ok false
    ]
  ]

  update-globals
  tick
end

to update-globals
  set pop-count count critters
  ifelse any? critters [
    set total-energy precision (sum [energy] of critters) 4
    set avg-age precision (mean [age-val] of critters) 4
  ] [
    set total-energy 0
    set avg-age 0
  ]
end
"""
end
