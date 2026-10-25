class_name HexagonHeatSim
extends MinigameBase
## Physik- und Regel-Simulation für Hexagon Heat (Mushroom Mix-Up / Farbfelder).
## 19 sechseckige Säulen in 5 Farben. Kacheln der falschen Farbe versinken in Lava!

signal wave_alert(color_id: int, duration_s: float)
signal tiles_sinking(wrong_color_ids: Array[int])
signal tiles_rising()
signal player_bumped(id_a: int, id_b: int)
signal player_eliminated(id: int, pos: Vector2)
signal round_ended(winner_ids: Array[int])

enum WavePhase { WAITING, ALERT, SINKING, RISING }

const COLOR_COUNT := 5
const HEX_OUTER_RADIUS := 1.75
const SINK_DEPTH := 7.0

class HexTile:
	var id: int
	var q: int
	var r: int
	var center: Vector2
	var color_id: int
	var height_y: float = 0.0 # 0.0 = oben, -SINK_DEPTH = versunken
	var is_sinking: bool = false

	func _init(p_id: int, p_q: int, p_r: int, p_center: Vector2, p_color: int) -> void:
		id = p_id
		q = p_q
		r = p_r
		center = p_center
		color_id = p_color

class Player:
	var id: int
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var radius: float = 0.55
	var alive: bool = true
	var fall_y: float = 0.0
	var placement: int = 0
	var input_dir: Vector2 = Vector2.ZERO

	func _init(p_id: int, p_pos: Vector2) -> void:
		id = p_id
		pos = p_pos

var tiles: Array[HexTile] = []
var players: Dictionary = {} # id -> Player
var wave_phase: WavePhase = WavePhase.WAITING
var phase_timer_s: float = 0.0
var wave_index: int = 0
var target_color: int = -1

var _eliminated_order: Array[int] = []
var _rng: RandomNumberGenerator


func _init(player_count: int = 4, rng: RandomNumberGenerator = null) -> void:
	time_limit_s = 60.0
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_create_hex_grid()
	_setup_players(player_count)


func _create_hex_grid() -> void:
	tiles.clear()
	var tile_id := 0
	# Axialkoordinaten (q, r) mit Radius 2: 1 + 6 + 12 = 19 Hexagone
	for q in range(-2, 3):
		var r1 := maxi(-2, -q - 2)
		var r2 := mini(2, -q + 2)
		for r in range(r1, r2 + 1):
			var x := HEX_OUTER_RADIUS * sqrt(3.0) * (q + r / 2.0)
			var y := HEX_OUTER_RADIUS * 1.5 * r
			var color := tile_id % COLOR_COUNT
			tiles.append(HexTile.new(tile_id, q, r, Vector2(x, y), color))
			tile_id += 1

	# Farben zufällig durchmischen für jede Runde
	_shuffle_tile_colors()


func _shuffle_tile_colors() -> void:
	# Sicherstellen, dass jede der 5 Farben mindestens 3-4 Kacheln hat
	var color_pool: Array[int] = []
	for i in COLOR_COUNT:
		for rep in 3:
			color_pool.append(i)
	while color_pool.size() < tiles.size():
		color_pool.append(_rng.randi_range(0, COLOR_COUNT - 1))

	# Fisher-Yates Shuffle
	for i in range(color_pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := color_pool[i]
		color_pool[i] = color_pool[j]
		color_pool[j] = tmp

	for i in tiles.size():
		tiles[i].color_id = color_pool[i]


func _setup_players(count: int) -> void:
	players.clear()
	_eliminated_order.clear()
	for i in count:
		var angle := (TAU / count) * i
		var spawn := Vector2(cos(angle), sin(angle)) * (HEX_OUTER_RADIUS * 1.4)
		players[i + 1] = Player.new(i + 1, spawn)


func set_input(player_id: int, dir: Vector2) -> void:
	var p: Player = players.get(player_id)
	if p != null and p.alive:
		p.input_dir = dir.limit_length(1.0)


func start_round() -> void:
	super.start_round()
	wave_index = 0
	_start_waiting_phase(2.2)


func _start_waiting_phase(duration: float) -> void:
	wave_phase = WavePhase.WAITING
	phase_timer_s = duration
	target_color = -1
	for t in tiles:
		t.is_sinking = false
		t.height_y = 0.0
	tiles_rising.emit()


func _start_alert_phase() -> void:
	wave_index += 1
	wave_phase = WavePhase.ALERT
	# Reaktionszeit sinkt mit jeder Welle von 2.4s auf 1.2s
	var alert_duration := maxf(1.2, 2.4 - (wave_index - 1) * 0.22)
	phase_timer_s = alert_duration

	# Zielfarbe zufällig wählen
	target_color = _rng.randi_range(0, COLOR_COUNT - 1)
	wave_alert.emit(target_color, alert_duration)


func _start_sinking_phase() -> void:
	wave_phase = WavePhase.SINKING
	phase_timer_s = 2.2
	var wrong_colors: Array[int] = []
	for i in COLOR_COUNT:
		if i != target_color:
			wrong_colors.append(i)

	for t in tiles:
		t.is_sinking = (t.color_id != target_color)

	tiles_sinking.emit(wrong_colors)


func _start_rising_phase() -> void:
	wave_phase = WavePhase.RISING
	phase_timer_s = 1.0


func update(dt: float) -> void:
	if state != State.RUNNING:
		return

	time_elapsed_s += dt

	# 1. Phasen-Management
	phase_timer_s -= dt
	match wave_phase:
		WavePhase.WAITING:
			if phase_timer_s <= 0.0:
				_start_alert_phase()

		WavePhase.ALERT:
			if phase_timer_s <= 0.0:
				_start_sinking_phase()

		WavePhase.SINKING:
			# Kacheln senken sich stetig ab
			for t in tiles:
				if t.is_sinking and t.height_y > -SINK_DEPTH:
					t.height_y = maxf(-SINK_DEPTH, t.height_y - dt * 6.5)

			# Sturzprüfung: Wer auf einer versunkenen Kachel steht oder neben der Arena ist, stürzt ab
			_check_player_falls()

			if phase_timer_s <= 0.0:
				_start_rising_phase()

		WavePhase.RISING:
			# Kacheln fahren wieder hoch
			for t in tiles:
				if t.height_y < 0.0:
					t.height_y = minf(0.0, t.height_y + dt * 7.5)

			if phase_timer_s <= 0.0:
				_start_waiting_phase(1.8)

	# 2. Spieler-Bewegung & Reibung
	for id in players:
		var p: Player = players[id]
		if not p.alive:
			p.fall_y += dt * 15.0
			continue

		if p.input_dir.length_squared() > 0.01:
			p.vel = p.vel.move_toward(p.input_dir * 7.5, dt * 38.0)
		else:
			p.vel = p.vel.move_toward(Vector2.ZERO, dt * 26.0)

		p.pos += p.vel * dt

	# 3. Spieler-Kollision & Schubsen
	var p_keys := players.keys()
	for i in p_keys.size():
		var id_a: int = p_keys[i]
		var p1: Player = players[id_a]
		if not p1.alive: continue

		for j in range(i + 1, p_keys.size()):
			var id_b: int = p_keys[j]
			var p2: Player = players[id_b]
			if not p2.alive: continue

			var diff := p2.pos - p1.pos
			var dist := diff.length()
			var min_dist := p1.radius + p2.radius
			if dist < min_dist and dist > 0.0001:
				var normal := diff / dist
				var overlap := min_dist - dist
				p1.pos -= normal * (overlap * 0.5)
				p2.pos += normal * (overlap * 0.5)

				# Schubs-Impuls
				var push := normal * 3.5
				p1.vel -= push
				p2.vel += push
				player_bumped.emit(id_a, id_b)

	# 4. Rundenende-Prüfung
	var alive_count := 0
	for id in players:
		if players[id].alive:
			alive_count += 1

	if alive_count <= 1 or time_elapsed_s >= time_limit_s:
		state = State.FINISHED
		_assign_placements()
		round_ended.emit(get_winner_ids())


func _check_player_falls() -> void:
	for id in players:
		var p: Player = players[id]
		if not p.alive:
			continue

		var standing_tile := get_tile_at(p.pos)
		# Steht außerhalb des Wabenmusters ODER auf einer Kachel, die bereits mehr als 1.2m abgesunken ist
		if standing_tile == null or standing_tile.height_y < -1.2:
			p.alive = false
			_eliminated_order.append(id)
			player_eliminated.emit(id, p.pos)


func get_tile_at(pos: Vector2) -> HexTile:
	# Findet die Kachel, in deren Bereich pos liegt
	var best_tile: HexTile = null
	var best_dist_sq := INF
	for t in tiles:
		var d_sq := t.center.distance_squared_to(pos)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_tile = t

	# Prüfe grobe Maximaldistanz zum Hex-Zentrum
	if best_tile != null and best_dist_sq <= (HEX_OUTER_RADIUS * 1.05) ** 2:
		return best_tile
	return null


func _assign_placements() -> void:
	var place := 1
	for id in players:
		var p: Player = players[id]
		if p.alive:
			p.placement = place

	var curr_place := players.size()
	for id in _eliminated_order:
		var p: Player = players[id]
		p.placement = curr_place
		curr_place -= 1


func get_winner_ids() -> Array[int]:
	var winners: Array[int] = []
	for id in players:
		if players[id].placement == 1:
			winners.append(id)
	return winners


func get_scores() -> Dictionary:
	var scores: Dictionary = {}
	for id in players:
		var p: Player = players[id]
		match p.placement:
			1: scores[id] = 100
			2: scores[id] = 60
			3: scores[id] = 30
			_: scores[id] = 10
	return scores
