# ── Party model (NetLogo models library) ─────────────────────────────

struct PartyModel <: AbstractBenchmarkModel end

model_name(::PartyModel) = "Party"
n_ticks(::PartyModel) = 100
tracked_globals(::PartyModel) = ["boring-groups"]
world_dims(::PartyModel) = (-80, 1, -55, 55)

function netlogo_code(::PartyModel)
"""
globals [randomSeed num-groups number tolerance group-sites boring-groups]

turtles-own [happy? my-group-site]

to setup
  clear-all
  resize-world (- 80) 1 (- 55) 55
  set num-groups 10
  set number 70
  set tolerance 25
  set group-sites patches with [group-site?]
  create-turtles number [
    choose-sex
    set size 3
    set my-group-site one-of group-sites
    move-to my-group-site
  ]
  ask turtles [ update-happiness ]
  count-boring-groups
  update-labels
  ask turtles [ spread-out-vertically ]
  reset-ticks
end

to go
  if all? turtles [happy?] [ stop ]
  ask turtles [ move-to my-group-site ]
  ask turtles [ update-happiness ]
  ask turtles [ leave-if-unhappy ]
  find-new-groups
  update-labels
  count-boring-groups
  ask turtles [
    set my-group-site patch-here
    spread-out-vertically
  ]
  tick
end

to update-happiness
  let total count turtles-here
  if total = 0 [ set happy? true stop ]
  let same count turtles-here with [color = [color] of myself]
  let opposite (total - same)
  set happy? (opposite / total) <= (tolerance / 100)
end

to leave-if-unhappy
  if not happy? [
    set heading one-of [90 270]
    fd 1
  ]
end

to find-new-groups
  let malcontents turtles with [not member? patch-here group-sites]
  if not any? malcontents [ stop ]
  ask malcontents [ fd 1 ]
  find-new-groups
end

to-report group-site?
  let group-interval floor (world-width / num-groups)
  report
    (pycor = 0) and
    (pxcor <= 0) and
    (pxcor mod group-interval = 0) and
    (floor ((- pxcor) / group-interval) < num-groups)
end

to spread-out-vertically
  ifelse woman?
    [ set heading 180 ]
    [ set heading   0 ]
  fd 4
  while [any? other turtles-here] [
    ifelse can-move? 2 [
      fd 1
    ] [
      set xcor xcor - 1
      set ycor 0
      fd 4
    ]
  ]
end

to count-boring-groups
  ask group-sites [
    ifelse boring?
      [ set plabel-color gray  ]
      [ set plabel-color white ]
  ]
  set boring-groups count group-sites with [plabel-color = gray]
end

to-report boring?
  report length remove-duplicates ([color] of turtles-here) = 1
end

to update-labels
  ask group-sites [ set plabel count turtles-here ]
end

to choose-sex
  set color one-of [pink blue]
end

to-report woman?
  report color = pink
end
"""
end
