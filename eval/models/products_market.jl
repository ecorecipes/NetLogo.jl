# ── Products Into the Market ─────────────────────────────────────
# Source: modelingcommons #4483
# NW extension: generate-random, generate-preferential-attachment,
#               betweenness-centrality (for betweenness seeding)
# Bass-model product diffusion on network: agents adopt Apple or Samsung
# based on random chance (2%) or neighbor influence (98%).
# Network effects drive market competition between two products.

struct ProductsModel <: AbstractBenchmarkModel end

model_name(::ProductsModel) = "Products Market"
n_ticks(::ProductsModel) = 200
tracked_globals(::ProductsModel) = ["count-apple", "count-samsung"]

function netlogo_code(::ProductsModel)
"""
extensions [nw]

breed [people person]

people-own [
  buyapple?
  buysamsung?
  randomapplen?
  randomsamsungn?
  friendapplen?
  friendsamsungn?
  friendsamsungbutapplen?
  friendapplebutsamsungn?
  drawsamsungn?
  drawapplen?
  drawsamsungbutapplen?
  drawapplebutsamsungn?
]

globals [
  network-type
  seeding-method
  number-of-people
  sponsorapple
  sponsorsamsung
  popularityapple
  popularitysamsung
  forever?
  count-apple
  count-samsung
]

to setup
  clear-all
  set network-type "preferential-attachment"
  set seeding-method "random"
  set number-of-people 100
  set sponsorapple 5
  set sponsorsamsung 5
  set popularityapple 50
  set popularitysamsung 50
  set forever? true

  create-network
  seed
  reset-ticks
end

to create-network
  if network-type = "random" [ create-random-network ]
  if network-type = "preferential-attachment" [ create-preferential-attachment ]
end

to create-random-network
  nw:generate-random people links number-of-people 0.004 [
    set shape "person"
    set color yellow
    set size 1.5
    set buyapple? false
    set buysamsung? false
  ]
end

to create-preferential-attachment
  nw:generate-preferential-attachment people links number-of-people [
    set size 1.5
    set shape "person"
    set color yellow
    set buyapple? false
    set buysamsung? false
  ]
end

to seed
  if seeding-method = "random" [
    ask n-of sponsorapple people [
      set buyapple? true
      set buysamsung? false
      update-color
    ]
    ask n-of sponsorsamsung people [
      set buysamsung? true
      set buyapple? false
      update-color
    ]
  ]
  if seeding-method = "betweenness" [
    ask max-n-of sponsorsamsung people [ nw:betweenness-centrality ] [
      set buysamsung? true
      set buyapple? false
      update-color
    ]
    ask max-n-of sponsorapple people [ nw:betweenness-centrality ] [
      set buyapple? true
      set buysamsung? false
      update-color
    ]
  ]
end

to go
  ifelse forever? [] [
    if all? people [buyapple? or buysamsung?] [stop]
  ]
  if all? people [buyapple?] [stop]
  if all? people [buysamsung?] [stop]

  ask people [ decide-to-adopt ]
  ask people [ update-color ]
  set count-apple count people with [buyapple?]
  set count-samsung count people with [buysamsung?]
  tick
end

to decide-to-adopt
  let firstrandom random-float 1.0
  ifelse firstrandom < 0.02 [
    let secondrandom random-float 2.0
    ifelse secondrandom < 1 [
      set randomapplen? true
      set buyapple? true
      set buysamsung? false
    ] [
      set randomsamsungn? true
      set buysamsung? true
      set buyapple? false
    ]
  ] [
    ifelse any? link-neighbors [
      ifelse any? link-neighbors with [ buyapple? = true or buysamsung? = true ] [
        let valoreapple 5 - popularityapple
        let valoresamsung 5 - popularitysamsung
        let apple count link-neighbors with [ buyapple? = true ] / count link-neighbors
        let samsung count link-neighbors with [ buysamsung? = true ] / count link-neighbors

        ifelse apple > samsung [
          let probabilitaa apple * 0.5
          let randomnuma random-float valoreapple
          ifelse randomnuma < probabilitaa [
            set friendapplen? true
            set buyapple? true
            set buysamsung? false
          ] [
            let probabilitas samsung * 0.5
            let randomnums random-float valoresamsung
            if randomnums < probabilitas [
              set friendsamsungbutapplen? true
              set buysamsung? true
              set buyapple? false
            ]
          ]
        ] [
          ifelse samsung > apple [
            let probabilitas samsung * 0.5
            let randomnums random-float valoresamsung
            ifelse randomnums < probabilitas [
              set friendsamsungn? true
              set buysamsung? true
              set buyapple? false
            ] [
              let probabilitaa apple * 0.5
              let randomnuma random-float valoreapple
              if randomnuma < probabilitaa [
                set friendapplebutsamsungn? true
                set buyapple? true
                set buysamsung? false
              ]
            ]
          ] [
            if samsung = apple [
              let randomdraw random-float 1.0
              ifelse randomdraw < 0.5 [
                let probabilitas samsung * 0.5
                let randomnums random-float valoresamsung
                ifelse randomnums < probabilitas [
                  set drawsamsungn? true
                  set buysamsung? true
                  set buyapple? false
                ] [
                  let probabilitaa apple * 0.5
                  let randomnuma random-float valoreapple
                  if randomnuma < probabilitaa [
                    set drawapplebutsamsungn? true
                    set buyapple? true
                    set buysamsung? false
                  ]
                ]
              ] [
                let probabilitaa apple * 0.5
                let randomnuma random-float valoreapple
                ifelse randomnuma < probabilitaa [
                  set drawapplen? true
                  set buyapple? true
                  set buysamsung? false
                ] [
                  let probabilitas samsung * 0.5
                  let randomnums random-float valoresamsung
                  if randomnums < probabilitas [
                    set drawsamsungbutapplen? true
                    set buysamsung? true
                    set buyapple? false
                  ]
                ]
              ]
            ]
          ]
        ]
      ] [
      ]
    ] [
    ]
  ]
end

to update-color
  if buyapple? [ set color white ]
  if buysamsung? [ set color blue ]
end
"""
end
