# ── GIS Hill Climber ──────────────────────────────────────────────────
# A self-contained model exercising GIS extension primitives:
# - gis:create-raster, gis:set-raster-value, gis:set-world-envelope
# - gis:apply-raster (symbol-mode variable name)
# - gis:convolve (Sobel gradient filter)
# - gis:minimum-of, gis:maximum-of, gis:width-of, gis:height-of
# - gis:raster-sample (agent form)
# Turtles climb a Gaussian elevation surface toward peaks.
# Tracked: mean-elevation (average turtle elevation), n-at-peak.

struct GisHillClimberModel <: AbstractBenchmarkModel end

model_name(::GisHillClimberModel) = "GIS HillClimber"
n_ticks(::GisHillClimberModel) = 100
tracked_globals(::GisHillClimberModel) = ["mean-elevation", "n-at-peak"]
world_dims(::GisHillClimberModel) = (-25, 25, -25, 25)
topology(::GisHillClimberModel) = (true, true)

function netlogo_code(::GisHillClimberModel)
"""
extensions [gis]

globals [
  elevation-raster
  slope-x-raster
  slope-y-raster
  mean-elevation
  n-at-peak
]

patches-own [elev slope-x slope-y]

to setup
  clear-all

  ;; Create a 51x51 raster matching world dimensions
  let w (max-pxcor - min-pxcor + 1)
  let h (max-pycor - min-pycor + 1)
  let env (list min-pxcor max-pxcor min-pycor max-pycor)
  set elevation-raster gis:create-raster w h env
  gis:set-world-envelope env

  ;; Fill with a multi-peak Gaussian surface:
  ;;   Peak 1: center (0,0), sigma=8, height=100
  ;;   Peak 2: offset (12,-10), sigma=5, height=80
  ;;   Peak 3: offset (-15,8), sigma=6, height=60
  let col 0
  repeat w [
    let row 0
    repeat h [
      let gx (col + min-pxcor)
      let gy (row + min-pycor)
      let z1 100.0 * exp (- (gx * gx + gy * gy) / 128.0)
      let dx2 (gx - 12)
      let dy2 (gy + 10)
      let z2 80.0 * exp (- (dx2 * dx2 + dy2 * dy2) / 50.0)
      let dx3 (gx + 15)
      let dy3 (gy - 8)
      let z3 60.0 * exp (- (dx3 * dx3 + dy3 * dy3) / 72.0)
      gis:set-raster-value elevation-raster col row (z1 + z2 + z3)
      set row row + 1
    ]
    set col col + 1
  ]

  ;; Apply elevation to patches
  gis:apply-raster elevation-raster elev

  ;; Compute Sobel gradients (exercises gis:convolve)
  set slope-x-raster gis:convolve elevation-raster 3 3 (list -1 0 1 -2 0 2 -1 0 1) 1 1
  set slope-y-raster gis:convolve elevation-raster 3 3 (list -1 -2 -1 0 0 0 1 2 1) 1 1
  gis:apply-raster slope-x-raster slope-x
  gis:apply-raster slope-y-raster slope-y

  ;; Create hill-climbing agents
  create-turtles 100 [
    setxy random-xcor random-ycor
    set color green
    set size 1
  ]

  update-stats
  reset-ticks
end

to go
  ask turtles [
    ;; Climb: move to highest neighboring patch
    let best max-one-of neighbors [elev]
    if best != nobody [
      if [elev] of best > [elev] of patch-here [
        face best
        move-to best
      ]
    ]
  ]

  update-stats
  tick
end

to update-stats
  ;; Use gis:raster-sample with agent (exercises the agent-form fix)
  set mean-elevation mean [gis:raster-sample elevation-raster self] of turtles
  set n-at-peak count turtles with [[elev] of patch-here > 90]
end
"""
end
