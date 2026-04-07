# ── Evolution of Norms (Axelrod 1986) ────────────────────────────────
# Source: modelingcommons #4538
# Modifications:
#   - Added Metanorm to globals (originally a switch widget)
#   - Set Metanorm true in setup
#   - Removed go100 helper procedure (not needed for harness)
#   - defections resets to 0 at end of go, so track mn and sd instead

struct EvolutionOfNormsModel <: AbstractBenchmarkModel end

model_name(::EvolutionOfNormsModel) = "EvolutionOfNorms"
n_ticks(::EvolutionOfNormsModel) = 100
tracked_globals(::EvolutionOfNormsModel) = ["mn", "sd"]
world_dims(::EvolutionOfNormsModel) = (-16, 16, -16, 16)

function netlogo_code(::EvolutionOfNormsModel)
"""
globals[defections turtlecount turtleno punishcount metapunishcount sd mn difft Metanorm]
turtles-own[points boldness vengefullness seen? punish?]

to setup
  clear-all
  set Metanorm true
  set turtlecount 20
  set defections 0
  addturtles turtlecount 0 0 0
  reset-ticks
end

to go
  ask turtles[
    repeat 4[
      set punishcount 0
      set metapunishcount 0
      set seen? random-float 1
      if seen? < boldness / 7 [
        set points points + 3
        set defections defections + 1
        ask other turtles [
          set points points - 1
          if random-float 1 < seen?[
            set punish? random-float 1
            ifelse vengefullness / 7 > punish? [
              set punishcount punishcount + 1
              set points points - 2
            ][
              if Metanorm[
                ask other turtles[
                  if random-float 1 < seen?[
                    set metapunishcount metapunishcount + 1
                    set points points - 2
                  ]
                ]
                set points points - (9 * metapunishcount)
                set metapunishcount 0
              ]
            ]
          ]
        ]
        set points points - (9 * punishcount)
        set punishcount 0
      ]
    ]
  ]
  set sd standard-deviation [points] of turtles
  set mn mean [points] of turtles
  ask turtles[
    if points >= mn + sd[
      hatch 2 [ set points 0 setxy random-xcor random-ycor ]
    ]
    if (points >= mn - sd) and (points < mn + sd) [
      hatch 1 [ set points 0 setxy random-xcor random-ycor ]
    ]
    die
  ]
  set difft turtlecount - count turtles
  ifelse difft < 0[
    repeat difft * -1[ ask turtle max[who] of turtles [ die ] ]
  ][
    addturtles difft 0 0 0
  ]
  ask turtles[
    if random-float 1 <= 0.01[ set boldness random 8 ]
    if random-float 1 <= 0.01[ set vengefullness random 8 ]
  ]
  tick
  set defections 0
end

to addturtles [num bold venge pts]
  create-turtles num[
    ifelse bold = 0[ set boldness random 8 ][ set boldness bold ]
    ifelse venge = 0[ set vengefullness random 8 ][ set vengefullness venge ]
    set points pts
    setxy random-xcor random-ycor
    set shape "person"
    set size 3
    set color blue
  ]
end
"""
end
