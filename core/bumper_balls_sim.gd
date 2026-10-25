class_name BumperBallsSim
extends MinigameBase
## Physik- und Regel-Simulation für Bumper Balls (Knock Off).
## 4 Spieler auf Rollbällen stoßen sich auf einer schwebenden Plattform ab.

signal player_bumped(id_a: int, id_b: int, contact_pos: Vector2, strength: float)
signal player_fell(id: int, pos: Vector2)
signal round_ended(winner_ids: Array[int])

class Ball:
	var id: int
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var radius: float = 0.75
	var alive: bool = true
	var fall_y: float = 0.0
	var placement: int = 0
	var input_dir: Vector2 = Vector2.ZERO

	func _init(p_id: int, p_pos: Vector2) -> void:
		id = p_id
		pos = p_pos

const ARENA_RADIUS := 7.5
const ACCEL := 26.0
const MAX_SPEED := 8.5
const FRICTION := 4.5
const BUMP_BOUNCE := 1.75
const MASS := 1.0

var balls: Dictionary = {} # id -> Ball
var _eliminated_order: Array[int] = []


func _init(player_count: int = 4) -> void:
	time_limit_s = 45.0
	setup_players(player_count)


func setup_players(count: int) -> void:
	balls.clear()
	_eliminated_order.clear()
	var spawn_dist := ARENA_RADIUS * 0.58
	for i in count:
		var angle := (TAU / count) * i
		var spawn := Vector2(cos(angle), sin(angle)) * spawn_dist
		balls[i + 1] = Ball.new(i + 1, spawn)


func set_input(player_id: int, dir: Vector2) -> void:
	var b: Ball = balls.get(player_id)
	if b != null and b.alive:
		b.input_dir = dir.limit_length(1.0)


func update(dt: float) -> void:
	if state != State.RUNNING:
		return

	time_elapsed_s += dt

	# 1. Bewegung und Reibung
	for id in balls:
		var b: Ball = balls[id]
		if not b.alive:
			if b.fall_y < 10.0:
				b.fall_y += dt * 18.0
			continue

		if b.input_dir.length_squared() > 0.001:
			b.vel += b.input_dir * ACCEL * dt
		else:
			b.vel = b.vel.move_toward(Vector2.ZERO, FRICTION * dt)

		b.vel = b.vel.limit_length(MAX_SPEED)
		b.pos += b.vel * dt

	# 2. Elastische Kugel-Kollisionen (Bumper Impulse)
	var keys := balls.keys()
	for i in keys.size():
		var id_a: int = keys[i]
		var b1: Ball = balls[id_a]
		if not b1.alive:
			continue

		for j in range(i + 1, keys.size()):
			var id_b: int = keys[j]
			var b2: Ball = balls[id_b]
			if not b2.alive:
				continue

			var diff := b2.pos - b1.pos
			var dist := diff.length()
			var min_dist := b1.radius + b2.radius

			if dist < min_dist and dist > 0.0001:
				var normal := diff / dist
				var overlap := min_dist - dist

				# Positionskorrektur (Vermeidung von Durchdringung)
				b1.pos -= normal * (overlap * 0.5)
				b2.pos += normal * (overlap * 0.5)

				# Relativgeschwindigkeit entlang der Kollisionsnormale
				var rel_vel := b2.vel - b1.vel
				var vel_along_norm := rel_vel.dot(normal)

				# Stoß nur berechnen, wenn sich die Kugeln aufeinander zubewegen
				if vel_along_norm < 0.0:
					var impulse_mag := -(1.0 + BUMP_BOUNCE) * vel_along_norm / 2.0
					# Mindest-Impuls für befriedigenden Arcade-Punch
					impulse_mag = maxf(impulse_mag, 3.5)
					var impulse := normal * impulse_mag
					b1.vel -= impulse
					b2.vel += impulse
					var contact := b1.pos + normal * b1.radius
					player_bumped.emit(id_a, id_b, contact, impulse_mag)

	# 3. Arena-Bounds & Knockout-Prüfung
	for id in balls:
		var b: Ball = balls[id]
		if b.alive and b.pos.length() > ARENA_RADIUS:
			b.alive = false
			_eliminated_order.append(id)
			player_fell.emit(id, b.pos)

	# 4. Rundenende-Bedingungen (Last Man Standing oder Timeout)
	var alive_count := 0
	for id in balls:
		if balls[id].alive:
			alive_count += 1

	if alive_count <= 1 or time_elapsed_s >= time_limit_s:
		state = State.FINISHED
		_assign_placements()
		round_ended.emit(get_winner_ids())


func _assign_placements() -> void:
	# Noch lebende Spieler erhalten Platz 1
	var place := 1
	for id in balls:
		var b: Ball = balls[id]
		if b.alive:
			b.placement = place

	# Zuletzt ausgeschiedene Spieler erhalten die nächsten Plätze
	var curr_place := balls.size()
	for id in _eliminated_order:
		var b: Ball = balls[id]
		b.placement = curr_place
		curr_place -= 1


func get_winner_ids() -> Array[int]:
	var winners: Array[int] = []
	for id in balls:
		if balls[id].placement == 1:
			winners.append(id)
	return winners


func get_scores() -> Dictionary:
	var scores: Dictionary = {}
	for id in balls:
		var b: Ball = balls[id]
		# Punkte nach Platzierung: 1. Platz = 100, 2. = 60, 3. = 30, 4. = 10
		match b.placement:
			1: scores[id] = 100
			2: scores[id] = 60
			3: scores[id] = 30
			_: scores[id] = 10
	return scores
