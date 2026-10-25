class_name BumperAI
extends RefCounted
## Heuristik-KI für Bumper Balls.
## Hält Sicherheitsabstand zum Rand und rammt Gegner in Richtung Abgrund.

var player_id: int


func _init(p_id: int) -> void:
	player_id = p_id


func update(sim: BumperBallsSim) -> void:
	var me: BumperBallsSim.Ball = sim.balls.get(player_id)
	if me == null or not me.alive:
		return

	# 1. Selbsterhaltung: Wenn zu nah am Rand, mit voller Kraft zum Zentrum steuern
	var dist_from_center := me.pos.length()
	if dist_from_center > BumperBallsSim.ARENA_RADIUS * 0.62:
		var back_to_center := -me.pos.normalized()
		sim.set_input(player_id, back_to_center)
		return

	# 2. Zielsuche: Nächster lebender Gegner
	var nearest_enemy: BumperBallsSim.Ball = null
	var min_dist_sq := INF

	for id in sim.balls:
		if id == player_id:
			continue
		var enemy: BumperBallsSim.Ball = sim.balls[id]
		if not enemy.alive:
			continue
		var d_sq := me.pos.distance_squared_to(enemy.pos)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			nearest_enemy = enemy

	if nearest_enemy == null:
		sim.set_input(player_id, Vector2.ZERO)
		return

	# 3. Rammen: Ausrichten auf den Gegner
	var to_enemy := nearest_enemy.pos - me.pos
	var attack_dir := to_enemy.normalized()

	# Bonus-Taktik: Wenn der Gegner zwischen mir und dem Rand liegt, voll draufhalten!
	sim.set_input(player_id, attack_dir)
