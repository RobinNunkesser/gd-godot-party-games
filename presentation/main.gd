class_name Main
extends Node
## Haupt-Controller für den Bumper Balls Prototyp.
## Verbindet Headless-Simulation, 3D-Bühne, Eingabe und HUD.

const BumperBallsSim = preload("res://core/bumper_balls_sim.gd")
const BumperBalls3D = preload("res://presentation/bumper_balls_3d.gd")
const BumperAI = preload("res://core/bumper_ai.gd")

var _sim: BumperBallsSim
var _view: BumperBalls3D
var _ais: Array[BumperAI] = []

var _hud_time: Label
var _hud_status: RichTextLabel
var _hud_banner: Label


func _ready() -> void:
	_setup_ui()
	_start_new_match()


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Oberer Balken mit Zeit und Minispiel-Name
	_hud_time = Label.new()
	_hud_time.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_time.offset_top = 16
	_hud_time.add_theme_font_size_override("font_size", 28)
	canvas.add_child(_hud_time)

	# Spielerstatus-Leiste
	_hud_status = RichTextLabel.new()
	_hud_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud_status.bbcode_enabled = true
	_hud_status.fit_content = true
	_hud_status.offset_bottom = -20
	_hud_status.offset_top = -60
	_hud_status.add_theme_font_size_override("normal_font_size", 22)
	canvas.add_child(_hud_status)

	# Großes Banner für Rundenende
	_hud_banner = Label.new()
	_hud_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hud_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_banner.add_theme_font_size_override("font_size", 38)
	_hud_banner.visible = false
	canvas.add_child(_hud_banner)


func _start_new_match() -> void:
	if _view != null:
		_view.queue_free()

	_sim = BumperBallsSim.new(4)
	_ais = [BumperAI.new(2), BumperAI.new(3), BumperAI.new(4)]

	_view = BumperBalls3D.new()
	add_child(_view)
	_view.bind(_sim)

	_sim.start_round()
	_hud_banner.visible = false


func _physics_process(delta: float) -> void:
	if _sim == null:
		return

	# Eingabe Spieler 1 (WASD / Pfeile / Gamepad)
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1.0

	var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if Vector2(joy_x, joy_y).length_squared() > 0.05:
		move = Vector2(joy_x, joy_y)

	_sim.set_input(1, move.normalized())

	# KIs aktualisieren
	for ai in _ais:
		ai.update(_sim)

	# Simulation ticken
	_sim.update(delta)

	# HUD aktualisieren
	_update_hud()


func _update_hud() -> void:
	_hud_time.text = "★ BUMPER BALLS ★   %d s" % ceili(_sim.time_remaining_s())

	var status_parts: Array[String] = []
	var names := ["P1 (Du)", "P2 (KI)", "P3 (KI)", "P4 (KI)"]
	for id in _sim.balls:
		var b: BumperBallsSim.Ball = _sim.balls[id]
		var color_hex := BumperBalls3D.PLAYER_COLORS[id - 1].to_html(false)
		if b.alive:
			status_parts.append("[color=#%s]■ %s[/color]" % [color_hex, names[id - 1]])
		else:
			status_parts.append("[color=#666666]✖ %s[/color]" % names[id - 1])

	_hud_status.text = "   ".join(status_parts)

	if _sim.is_round_over():
		var winners := _sim.get_winner_ids()
		if winners.is_empty():
			_hud_banner.text = "UNENTSCHIEDEN!\n[Taste R für Neustart]"
		elif winners.has(1):
			_hud_banner.text = "🏆 SIEG FÜR SPIELER 1! 🏆\n[Taste R für Neustart]"
		else:
			_hud_banner.text = "SPIELER %d GEWINNT!\n[Taste R für Neustart]" % winners[0]
		_hud_banner.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or (event.keycode == KEY_ENTER and _sim.is_round_over()):
			_start_new_match()
