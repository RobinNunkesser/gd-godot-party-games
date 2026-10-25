class_name MinigameBase
extends RefCounted
## Abstrakte Basisklasse für Minispiele in der Party-Suite.
## Headless-fähig, deterministisch und unabhängig vom SceneTree für Unit-Tests.

enum State { READY, RUNNING, FINISHED }

var state: State = State.READY
var time_limit_s: float = 45.0
var time_elapsed_s: float = 0.0


func start_round() -> void:
	state = State.RUNNING
	time_elapsed_s = 0.0


func update(_dt: float) -> void:
	pass


func is_round_over() -> bool:
	return state == State.FINISHED


func time_remaining_s() -> float:
	return maxf(0.0, time_limit_s - time_elapsed_s)


func get_scores() -> Dictionary:
	return {}


func get_winner_ids() -> Array[int]:
	return []
