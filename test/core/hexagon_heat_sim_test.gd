class_name HexagonHeatSimTest
extends GdUnitTestSuite


func test_creates_nineteen_hexagons() -> void:
	var sim := HexagonHeatSim.new(4)
	assert_int(sim.tiles.size()).is_equal(19)
	# Jede der 5 Farben muss mindestens 3 Mal vorkommen
	var counts: Dictionary = {}
	for t in sim.tiles:
		counts[t.color_id] = counts.get(t.color_id, 0) + 1
	for c in HexagonHeatSim.COLOR_COUNT:
		assert_int(counts.get(c, 0)).is_greater_equal(3)


func test_round_starts_and_cycles_to_alert() -> void:
	var sim := HexagonHeatSim.new(4)
	sim.start_round()
	assert_int(sim.wave_phase).is_equal(HexagonHeatSim.WavePhase.WAITING)

	# Nach Ablauf der Wartephase (2.2s) muss ALERT aktiv sein mit gültiger Zielfarbe
	sim.update(2.3)
	assert_int(sim.wave_phase).is_equal(HexagonHeatSim.WavePhase.ALERT)
	assert_int(sim.target_color).is_greater_equal(0)
	assert_int(sim.target_color).is_less(HexagonHeatSim.COLOR_COUNT)


func test_player_on_wrong_tile_falls_when_sinking() -> void:
	var sim := HexagonHeatSim.new(2)
	sim.start_round()
	# Schalte auf Alert
	sim.update(2.3)
	var correct_color := sim.target_color

	# Finde eine Kachel mit falscher Farbe und setze Spieler 1 darauf
	var wrong_tile: HexagonHeatSim.HexTile = null
	for t in sim.tiles:
		if t.color_id != correct_color:
			wrong_tile = t
			break

	var p1: HexagonHeatSim.Player = sim.players[1]
	p1.pos = wrong_tile.center

	# Finde eine Kachel mit richtiger Farbe und setze Spieler 2 darauf
	var correct_tile: HexagonHeatSim.HexTile = null
	for t in sim.tiles:
		if t.color_id == correct_color:
			correct_tile = t
			break
	var p2: HexagonHeatSim.Player = sim.players[2]
	p2.pos = correct_tile.center

	# Schalte von Alert auf Sinking (weitere ~2.5s)
	sim.update(2.5)
	assert_int(sim.wave_phase).is_equal(HexagonHeatSim.WavePhase.SINKING)

	# Nach Absinken muss Spieler 1 eliminiert sein, Spieler 2 überleben
	sim.update(0.8)
	assert_bool(p1.alive).is_false()
	assert_bool(p2.alive).is_true()
	assert_bool(sim.is_round_over()).is_true()
	assert_array(sim.get_winner_ids()).contains_exactly([2])


func test_ai_steers_towards_correct_color_tile() -> void:
	var sim := HexagonHeatSim.new(2)
	var ai := HexagonAI.new(1)
	sim.start_round()
	sim.update(2.3) # Schalte auf Alert

	var p1: HexagonHeatSim.Player = sim.players[1]
	p1.pos = Vector2(0, 0)
	ai.update(sim)

	# KI muss einen Richtungsvektor ungleich ZERO gewählt haben
	assert_float(p1.input_dir.length_squared()).is_greater(0.5)

	# Finde die Kachel, auf die sie zusteuert
	var best_tile := ai._find_nearest_target_tile(sim, p1.pos, sim.target_color)
	var expected_dir := (best_tile.center - p1.pos).normalized()
	assert_float(p1.input_dir.dot(expected_dir)).is_greater(0.9)
