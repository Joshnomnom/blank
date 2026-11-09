class_name Layers
extends RefCounted
## Physics layer bits used everywhere. Keep CLAUDE.md / DEVLOG in sync when changing.
##   1 SOLID  - walls, ramps (+ground), target dummies. Everything collides with these.
##   2 GROUND - terrain / flat ground. Only rays (car wheels, enemy ground snap, sight, shots).
##   4 PLAYER - player cars.
##   8 ENEMY  - enemies.

const SOLID := 1
const GROUND := 2
const PLAYER := 4
const ENEMY := 8

## What player bullets / rockets / aim rays hit.
const PLAYER_SHOTS := SOLID | GROUND | ENEMY
## What enemy bullets hit.
const ENEMY_SHOTS := SOLID | GROUND | PLAYER
## What blocks line of sight.
const SIGHT_BLOCKERS := SOLID | GROUND
