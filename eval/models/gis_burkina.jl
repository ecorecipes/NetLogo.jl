# ── GIS Burkina Faso Migration Flow ──────────────────────────────
# Simplified wrapper using real GIS data from modelingcommons #6760
# Exercises: load-dataset (shp + asc), set-world-envelope, apply-raster,
#            feature-list-of, centroid-of, location-of, property-value, draw
# Agents migrate between GIS-defined regions based on patch region values.

struct GisBurkinaModel <: AbstractBenchmarkModel end

model_name(::GisBurkinaModel) = "GIS Burkina Faso"
n_ticks(::GisBurkinaModel) = 100
tracked_globals(::GisBurkinaModel) = ["total-moves", "pct-region1"]
world_dims(::GisBurkinaModel) = (-70, 70, -50, 50)
topology(::GisBurkinaModel) = (false, false)

function netlogo_code(::GisBurkinaModel)
    base = dirname(dirname(@__DIR__))
    mc_dir = joinpath(dirname(base), "modelingcommons", "6760-burkina-faso-migration-flows", "model")
    shp_path = joinpath(mc_dir, "BFA_adm1_UTM.shp")
    asc_path = joinpath(mc_dir, "bfa_adm1_utm_ascii.asc")
"""
extensions [gis]
globals [regions-dataset regions-ras-dataset total-moves pct-region1]
breed [migrants migrant]
patches-own [region]
migrants-own [origin destination energy]

to setup
  clear-all
  set regions-dataset gis:load-dataset "$(replace(shp_path, "\\" => "/"))"
  set regions-ras-dataset gis:load-dataset "$(replace(asc_path, "\\" => "/"))"
  gis:set-world-envelope (gis:envelope-of regions-dataset)
  gis:apply-raster regions-ras-dataset region

  ;; Place migrants in region patches
  ask n-of 200 patches with [region > 0 and region <= 13] [
    sprout-migrants 1 [
      set shape "person"
      set color scale-color blue region 0 14
      set origin region
      set destination 0
      set energy 10 + random 20
    ]
  ]

  set total-moves 0
  set pct-region1 count migrants with [origin = 1] / max list 1 count migrants * 100
  reset-ticks
end

to go
  ask migrants [
    ;; Random walk within region
    rt random 90 - 45
    fd 1 + random-float 1

    ;; Check current region
    let here-region [region] of patch-here
    if here-region > 0 and here-region != origin [
      set total-moves total-moves + 1
      set color scale-color red here-region 0 14
    ]

    ;; Energy-based movement
    set energy energy - 1
    if energy <= 0 [
      ;; Return to origin region
      let home-patches patches with [region = [origin] of myself]
      if any? home-patches [
        move-to one-of home-patches
        set energy 10 + random 20
        set color scale-color blue origin 0 14
      ]
    ]
  ]

  set pct-region1 count migrants with [[region] of patch-here = 1] / max list 1 count migrants * 100
  tick
end
"""
end
