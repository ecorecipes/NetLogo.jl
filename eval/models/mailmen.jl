# ── Mailmen (Letter Delivery) ──────────────────────────────────────
# Adapted from netlogomas/mailmen by Jose M. Vidal

struct MailmenModel <: AbstractBenchmarkModel end

model_name(::MailmenModel) = "Mailmen Delivery"
n_ticks(::MailmenModel) = 200
tracked_globals(::MailmenModel) = ["total-dist", "num-remaining"]
world_dims(::MailmenModel) = (-10, 10, -10, 10)

function netlogo_code(::MailmenModel)
"""
globals [randomSeed num-mailmen num-letters total-dist num-remaining]

breed [mailmen mailman]
breed [letters letter]
breed [delivered-letters delivered-letter]

letters-own [destination-x destination-y carrier]
mailmen-own [my-letters distance-travelled]

to-report get-random-xcor
  report (random world-width) + min-pxcor
end

to-report get-random-ycor
  report (random world-height) + min-pycor
end

to setup
  clear-all
  resize-world (- 10) 10 (- 10) 10
  set num-mailmen 5
  set num-letters 30
  set-default-shape mailmen "default"
  create-mailmen num-mailmen [
    setxy get-random-xcor get-random-ycor
  ]
  set-default-shape letters "circle"
  create-letters num-letters [
    setxy get-random-xcor get-random-ycor
    set carrier nobody
    set heading 0
    set destination-x get-random-xcor
    set destination-y get-random-ycor
    set color white
  ]
  set total-dist 0
  set num-remaining count letters
  reset-ticks
end

to go
  if (not any? letters) [ stop ]
  ask mailmen [deliver-letters]
  set total-dist sum [distance-travelled] of mailmen
  set num-remaining count letters
  tick
end

to deliver-letters
  set my-letters letters with [carrier = [who] of myself]
  ifelse (any? my-letters) [
    let next-letter (min-one-of my-letters [distancexy destination-x destination-y])
    goto-xy ([destination-x] of next-letter) ([destination-y] of next-letter)
    drop-letter next-letter
  ][
    let next-letter (min-one-of (letters with [carrier = nobody]) [distance myself])
    if next-letter = nobody [ stop ]
    goto-xy ([xcor] of next-letter) ([ycor] of next-letter)
    pickup-letters-here
  ]
end

to pickup-letters-here
  let here-letters letters-here with [carrier = nobody]
  ask here-letters [
    set carrier [who] of myself
  ]
end

to drop-letter [the-letter]
  ask the-letter [ set carrier nobody ]
  if (([destination-x] of the-letter = (round xcor)) and ([destination-y] of the-letter = (round ycor))) [
    ask the-letter [
      set breed delivered-letters
      set color yellow
    ]
  ]
  set heading 0
end

to goto-xy [x y]
  let steps distancexy x y
  if steps >= 1 [
    set heading towardsxy x y
  ]
  fd steps
  ask my-letters [
    setxy ([xcor] of myself) ([ycor] of myself)
  ]
  set distance-travelled (distance-travelled + steps)
end
"""
end
