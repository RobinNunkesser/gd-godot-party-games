class_name BumperBallsSimTest
extends GdUnitTestSuite


func test_setup_creates_four_players() -> void:
	var sim := BumperBallsSim.new(4)
	assert_int(sim.balls.size()).is_equal(4)
	for id in [1, 2, 3, 4]:
		var b: BumperBallsSim.Ball = sim.balls[id]
		assert_bool(b.alive).is_true()
		assert_float(b.pos.length()).is_less(BumperBallsSim.ARENA_RADIUS)


func test_movement_accelerates_and_moves_ball() -> void:
	var sim := BumperBallsSim.new(4)
	sim.start_round()
	var b1: BumperBallsSim.Ball = sim.balls[1]
	var initial_pos := b1.pos

	sim.set_input(1, Vector2.RIGHT)
	sim.update(0.1)

	assert_float(b1.vel.x).is_greater(0.0)
	assert_float(b1.pos.x).is_greater(initial_pos.x)


func test_collision_bounces_players_apart() -> void:
	var sim := BumperBallsSim.new(2)
	sim.start_round()
	var b1: BumperBallsSim.Ball = sim.balls[1]
	var b2: BumperBallsSim.Ball = sim.balls[2]

	# Platziere beide frontal voreinander mit Gegenkurs
	b1.pos = Vector2(-1.0, 0.0)
	b1.vel = Vector2(4.0, 0.0)
	b2.pos = Vector2(0.3, 0.0)
	b2.vel = Vector2(-4.0, 0.0)

	var bump_detected := [false]
	sim.player_bumped.connect(func(a: int, b: int, _pos: Vector2, _strength: float) -> void:
		bump_detected[0] = true)

	sim.update(0.05)

	assert_bool(bump_detected[0]).is_true()
	# Nach dem Stoß müssen die Geschwindigkeiten umgekehrt sein
	assert_float(b1.vel.x).is_less(0.0)
	assert_float(b2.vel.x).is_greater(0.0)


func test_fall_off_arena_eliminates_player() -> void:
	var sim := BumperBallsSim.new(2)
	sim.start_round()
	var b1: BumperBallsSim.Ball = sim.balls[1]

	# Verschiebe Spieler 1 über den Rand
	b1.pos = Vector2(BumperBallsSim.ARENA_RADIUS + 0.5, 0.0)

	var fell := [false]
	sim.player_fell.connect(func(id: int, _pos: Vector2) -> void:
		if id == 1: fell[0] = true)

	sim.update(0.02)

	assert_bool(b1.alive).is_false()
	assert_bool(fell[0]).is_true()
	# Runde muss beendet sein, da nur noch Spieler 2 lebt
	assert_bool(sim.is_round_over()).is_true()
	assert_array(sim.get_winner_ids()).contains_exactly([2])


func test_ai_moves_towards_center_when_near_edge() -> void:
	var sim := BumperBallsSim.new(2)
	var ai := BumperAI.new(1)
	var b1: BumperBallsSim.Ball = sim.balls[1]

	# Platziere KI nahe am rechten Rand
	b1.pos = Vector2(BumperBallsSim.ARENA_RADIUS * 0.85, 0.0)
	ai.update(sim)

	# KI muss nach links steuern (Richtung Zentrum)
	assert_float(b1.input_dir.x).is_less(-0.5)


func test_ai_attacks_nearest_opponent() -> void:
	var sim := BumperBallsSim.new(2)
	var ai := BumperAI.new(1)
	var b1: BumperBallsSim.Ball = sim.balls[1]
	var b2: BumperBallsSim.Ball = sim.balls[2]

	# KI im Zentrum, Gegner bei (2, 0)
	b1.pos = Vector2.ZERO
	b2.pos = Vector2(2.0, 0.0)
	ai.update(sim)

	# KI muss nach rechts zum Gegner steuern
	assert_float(b1.input_dir.x).is_greater(0.8)
