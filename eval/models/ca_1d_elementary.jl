# ── CA 1D Elementary model (NetLogo models library) ─────────────────

struct Ca1dElementaryModel <: AbstractBenchmarkModel end

model_name(::Ca1dElementaryModel) = "CA 1D Elementary"
n_ticks(::Ca1dElementaryModel) = 49
tracked_globals(::Ca1dElementaryModel) = ["current-row", "density-on"]
world_dims(::Ca1dElementaryModel) = (-25, 25, 0, 49)

function netlogo_code(::Ca1dElementaryModel)
"""
globals [randomSeed rule current-row density-on
         ooo ooi oio oii ioo ioi iio iii]

patches-own [on?]

to setup
  clear-all
  resize-world (- 25) 25 0 49
  set rule 30
  extrapolate-switches
  set current-row max-pycor
  ask patches [ set on? false set pcolor white ]
  ask patch 0 max-pycor [
    set on? true
    set pcolor black
  ]
  set density-on count patches with [pycor = current-row and on?] / count patches with [pycor = current-row]
  reset-ticks
end

to go
  if current-row = min-pycor [ stop ]
  ask patches with [pycor = current-row] [ do-rule ]
  set current-row current-row - 1
  ask patches with [pycor = current-row] [ color-patch ]
  set density-on count patches with [pycor = current-row and on?] / count patches with [pycor = current-row]
  tick
end

to do-rule
  let left-on? [on?] of patch-at -1 0
  let right-on? [on?] of patch-at 1 0
  let new-value
    (iii and left-on? and on? and right-on?) or
    (iio and left-on? and on? and (not right-on?)) or
    (ioi and left-on? and (not on?) and right-on?) or
    (ioo and left-on? and (not on?) and (not right-on?)) or
    (oii and (not left-on?) and on? and right-on?) or
    (oio and (not left-on?) and on? and (not right-on?)) or
    (ooi and (not left-on?) and (not on?) and right-on?) or
    (ooo and (not left-on?) and (not on?) and (not right-on?))
  ask patch-at 0 -1 [ set on? new-value ]
end

to color-patch
  ifelse on?
    [ set pcolor black ]
    [ set pcolor white ]
end

to extrapolate-switches
  set ooo ((bindigit rule 0) = 1)
  set ooi ((bindigit rule 1) = 1)
  set oio ((bindigit rule 2) = 1)
  set oii ((bindigit rule 3) = 1)
  set ioo ((bindigit rule 4) = 1)
  set ioi ((bindigit rule 5) = 1)
  set iio ((bindigit rule 6) = 1)
  set iii ((bindigit rule 7) = 1)
end

to-report bindigit [num power-of-two]
  ifelse (power-of-two = 0)
    [ report floor num mod 2 ]
    [ report bindigit (floor num / 2) (power-of-two - 1) ]
end
"""
end
