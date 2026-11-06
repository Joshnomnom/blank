class_name Health
extends Node
## Reusable hit points component (targets now; enemies, bosses and player cars later).
## The owner forwards take_damage() here and listens to the signals.

signal damaged(amount: float, at: Vector3)
signal died

@export var max_hp: float = 100.0

var hp: float = 100.0


func _ready() -> void:
	hp = max_hp


func is_alive() -> bool:
	return hp > 0.0


func ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


func take_damage(amount: float, at: Vector3) -> void:
	if hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, at)
	if hp <= 0.0:
		died.emit()


func reset() -> void:
	hp = max_hp
