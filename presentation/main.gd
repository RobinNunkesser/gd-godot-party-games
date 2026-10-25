class_name Main
extends Node
## Haupt-Controller & Minispiel-Lobby für die Party-Games-Suite.
## Ermöglicht nahtlose Auswahl und Start von Bumper Balls & Hexagon Heat.

const BumperBallsSim = preload("res://core/bumper_balls_sim.gd")
const BumperBalls3D = preload("res://presentation/bumper_balls_3d.gd")
const BumperAI = preload("res://core/bumper_ai.gd")

const HexagonHeatSim = preload("res://core/hexagon_heat_sim.gd")
const HexagonHeat3D = preload("res://presentation/hexagon_heat_3d.gd")
const HexagonAI = preload("res://core/hexagon_ai.gd")

enum Mode { LOBBY, BUMPER_BALLS, HEXAGON_HEAT }

var _mode: Mode = Mode.LOBBY
var _selected_lobby_index: int = 0

# Aktive Simulation & Präsentation
var _current_sim: MinigameBase
var _current_view: Node3D
var _current_ais: Array = []

# UI Elemente
var _canvas: CanvasLayer
var _lobby_panel: PanelContainer
var _lobby_text: RichTextLabel

var _hud_time: Label
var _hud_status: RichTextLabel
var _hud_alert: RichTextLabel
var _hud_banner: Label


func _ready() -> void:
	_setup_ui()
	_show_lobby()


func _setup_ui() -> void:
	_canvas = CanvasLayer.new()
	add_child(_canvas)

	# 1. Lobby-Panel (Dark Arcade Style)
	_lobby_panel = PanelContainer.new()
	_lobby_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_lobby_panel.custom_minimum_size = Vector2(720, 480)
	_lobby_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lobby_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.25, 0.65, 0.95, 0.85)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.shadow_size = 24
	panel_style.shadow_color = Color(0, 0, 0, 0.8)
	panel_style.content_margin_left = 36
	panel_style.content_margin_right = 36
	panel_style.content_margin_top = 32
	panel_style.content_margin_bottom = 32
	_lobby_panel.add_theme_stylebox_override("panel", panel_style)

	_lobby_text = RichTextLabel.new()
	_lobby_text.bbcode_enabled = true
	_lobby_text.fit_content = true
	_lobby_text.scroll_active = false
	_lobby_text.add_theme_font_size_override("normal_font_size", 20)
	_lobby_panel.add_child(_lobby_text)
	_canvas.add_child(_lobby_panel)

	# 2. In-Game HUD: Oberer Balken mit Zeit und Minispiel-Name
	_hud_time = Label.new()
	_hud_time.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_time.offset_top = 16
	_hud_time.add_theme_font_size_override("font_size", 28)
	_canvas.add_child(_hud_time)

	# In-Game HUD: Farbalarm-Banner bei Hexagon Heat
	_hud_alert = RichTextLabel.new()
	_hud_alert.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_alert.bbcode_enabled = true
	_hud_alert.fit_content = true
	_hud_alert.offset_top = 56
	_hud_alert.offset_bottom = 110
	_canvas.add_child(_hud_alert)

	# In-Game HUD: Spielerstatus-Leiste
	_hud_status = RichTextLabel.new()
	_hud_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hud_status.bbcode_enabled = true
	_hud_status.fit_content = true
	_hud_status.offset_bottom = -20
	_hud_status.offset_top = -60
	_hud_status.add_theme_font_size_override("normal_font_size", 22)
	_canvas.add_child(_hud_status)

	# In-Game HUD: Großes Banner für Rundenende
	_hud_banner = Label.new()
	_hud_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hud_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_banner.add_theme_font_size_override("font_size", 36)
	_canvas.add_child(_hud_banner)


func _show_lobby() -> void:
	_mode = Mode.LOBBY
	_clear_current_game()

	_lobby_panel.visible = true
	_hud_time.visible = false
	_hud_alert.visible = false
	_hud_status.visible = false
	_hud_banner.visible = false

	_render_lobby_text()


func _render_lobby_text() -> void:
	var lines: Array[String] = [
		"[center][font_size=34][b][color=#ffd54f]PARTY GAMES 3D[/color][/b][/font_size][/center]",
		"[center][color=#64b5f6]★ MODULARE GODOT 4 MINISPIEL-SUITE ★[/color][/center]",
		"",
		"[center][color=#aaaaaa]Wähle ein Minispiel mit den Tasten [b]1[/b] / [b]2[/b] oder Pfeiltasten + Enter:[/color][/center]",
		""
	]

	var games := [
		{
			"key": "1",
			"icon": "💣",
			"title": "BUMPER BALLS (Knock Off)",
			"desc": "Stoße deine 3 Gegner mit deiner Kugel von der rutschigen Plattform. Last Man Standing gewinnt!",
			"tag": "Physik & Rammen"
		},
		{
			"key": "2",
			"icon": "🔥",
			"title": "HEXAGON HEAT (Farbfelder)",
			"desc": "19 Kacheln über glühender Lava. Renne rechtzeitig auf die aufgerufene Farbe, bevor der Rest versinkt!",
			"tag": "Reaktion & Timing"
		}
	]

	for i in games.size():
		var g: Dictionary = games[i]
		var is_selected: bool = (i == _selected_lobby_index)
		var prefix: String = "[color=#ffd54f]▶ " if is_selected else "  "
		var suffix: String = "[/color]" if is_selected else ""
		var title_color: String = "#ffffff" if is_selected else "#cccccc"

		lines.append("%s[font_size=24][b][%s] %s [color=%s]%s[/color][/b][/font_size]%s" % [
			prefix, g.key, g.icon, title_color, g.title, suffix
		])
		lines.append("     [color=#90caf9]Kategorie: %s[/color]" % g.tag)
		lines.append("     [color=#aaaaaa]%s[/color]" % g.desc)
		lines.append("")

	lines.append("[center][color=#888888]Steuerung im Spiel: WASD / Pfeile / Gamepad | [R] Neustart | [M / Esc] Lobby[/color][/center]")
	_lobby_text.text = "\n".join(lines)


func _start_game(mode: Mode) -> void:
	_mode = mode
	_clear_current_game()

	_lobby_panel.visible = false
	_hud_time.visible = true
	_hud_alert.visible = true
	_hud_status.visible = true
	_hud_banner.visible = false

	match _mode:
		Mode.BUMPER_BALLS:
			var sim := BumperBallsSim.new(4)
			_current_sim = sim
			_current_ais = [BumperAI.new(2), BumperAI.new(3), BumperAI.new(4)]
			var view := BumperBalls3D.new()
			_current_view = view
			add_child(view)
			view.bind(sim)
			sim.start_round()

		Mode.HEXAGON_HEAT:
			var sim := HexagonHeatSim.new(4)
			_current_sim = sim
			_current_ais = [HexagonAI.new(2), HexagonAI.new(3), HexagonAI.new(4)]
			var view := HexagonHeat3D.new()
			_current_view = view
			add_child(view)
			view.bind(sim)
			sim.start_round()


func _clear_current_game() -> void:
	if _current_view != null:
		_current_view.queue_free()
		_current_view = null
	_current_sim = null
	_current_ais.clear()


func _physics_process(delta: float) -> void:
	if _mode == Mode.LOBBY or _current_sim == null:
		return

	# Eingabe Spieler 1
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1.0

	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length_squared() > 0.05:
		move = joy

	if _mode == Mode.BUMPER_BALLS:
		var sim: BumperBallsSim = _current_sim
		sim.set_input(1, move.normalized())
		for ai in _current_ais:
			ai.update(sim)
		sim.update(delta)
	elif _mode == Mode.HEXAGON_HEAT:
		var sim: HexagonHeatSim = _current_sim
		sim.set_input(1, move.normalized())
		for ai in _current_ais:
			ai.update(sim)
		sim.update(delta)

	_update_hud()


func _update_hud() -> void:
	if _mode == Mode.BUMPER_BALLS:
		var sim: BumperBallsSim = _current_sim
		_hud_time.text = "★ BUMPER BALLS ★   %d s" % ceili(sim.time_remaining_s())
		_hud_alert.text = ""

		var status_parts: Array[String] = []
		var names := ["P1 (Du)", "P2 (KI)", "P3 (KI)", "P4 (KI)"]
		for id in sim.balls:
			var b: BumperBallsSim.Ball = sim.balls[id]
			var color_hex := BumperBalls3D.PLAYER_COLORS[id - 1].to_html(false)
			if b.alive:
				status_parts.append("[color=#%s]■ %s[/color]" % [color_hex, names[id - 1]])
			else:
				status_parts.append("[color=#666666]✖ %s[/color]" % names[id - 1])
		_hud_status.text = "[center]%s[/center]" % "   ".join(status_parts)

		if sim.is_round_over():
			_show_winner_banner(sim.get_winner_ids())

	elif _mode == Mode.HEXAGON_HEAT:
		var sim: HexagonHeatSim = _current_sim
		_hud_time.text = "★ HEXAGON HEAT ★   %d s" % ceili(sim.time_remaining_s())

		if sim.wave_phase == HexagonHeatSim.WavePhase.ALERT and sim.target_color >= 0:
			var color_hex := HexagonHeat3D.TILE_COLORS[sim.target_color].to_html(false)
			var color_name := HexagonHeat3D.COLOR_NAMES[sim.target_color]
			_hud_alert.text = "[center][font_size=28][b][color=#%s]⚡ ZIELFARBE: %s! ⚡[/color][/b][/font_size][/center]" % [
				color_hex, color_name
			]
		elif sim.wave_phase == HexagonHeatSim.WavePhase.SINKING:
			_hud_alert.text = "[center][font_size=26][b][color=#ff5252]ACHTUNG: KACHELN VERSINKEN IN LAVA![/color][/b][/font_size][/center]"
		else:
			_hud_alert.text = ""

		var status_parts: Array[String] = []
		var names := ["P1 (Du)", "P2 (KI)", "P3 (KI)", "P4 (KI)"]
		for id in sim.players:
			var p: HexagonHeatSim.Player = sim.players[id]
			var color_hex := HexagonHeat3D.PLAYER_COLORS[id - 1].to_html(false)
			if p.alive:
				status_parts.append("[color=#%s]■ %s[/color]" % [color_hex, names[id - 1]])
			else:
				status_parts.append("[color=#666666]✖ %s[/color]" % names[id - 1])
		_hud_status.text = "[center]%s[/center]" % "   ".join(status_parts)

		if sim.is_round_over():
			_show_winner_banner(sim.get_winner_ids())


func _show_winner_banner(winners: Array[int]) -> void:
	if winners.is_empty():
		_hud_banner.text = "UNENTSCHIEDEN!\n[Taste R: Neustart | M: Lobby]"
	elif winners.has(1):
		_hud_banner.text = "🏆 SIEG FÜR SPIELER 1! 🏆\n[Taste R: Neustart | M: Lobby]"
	else:
		_hud_banner.text = "SPIELER %d GEWINNT!\n[Taste R: Neustart | M: Lobby]" % winners[0]
	_hud_banner.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	if _mode == Mode.LOBBY:
		match event.keycode:
			KEY_1:
				_start_game(Mode.BUMPER_BALLS)
			KEY_2:
				_start_game(Mode.HEXAGON_HEAT)
			KEY_UP:
				_selected_lobby_index = posmod(_selected_lobby_index - 1, 2)
				_render_lobby_text()
			KEY_DOWN:
				_selected_lobby_index = posmod(_selected_lobby_index + 1, 2)
				_render_lobby_text()
			KEY_ENTER, KEY_SPACE:
				_start_game(Mode.BUMPER_BALLS if _selected_lobby_index == 0 else Mode.HEXAGON_HEAT)
	else:
		match event.keycode:
			KEY_ESCAPE, KEY_M:
				_show_lobby()
			KEY_R:
				_start_game(_mode)
			KEY_1:
				_start_game(Mode.BUMPER_BALLS)
			KEY_2:
				_start_game(Mode.HEXAGON_HEAT)
