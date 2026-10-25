class_name HexagonHeat3D
extends Node3D
## 3D-Bühne für Hexagon Heat (Farbflächen-Chaos).
## 19 Sechseck-Säulen über einem brodelnden Lava-See.

const TILE_COLORS: Array[Color] = [
	Color("ef5350"), # 0: Rot
	Color("42a5f5"), # 1: Blau
	Color("ffee58"), # 2: Gelb
	Color("66bb6a"), # 3: Grün
	Color("ab47bc")  # 4: Lila
]

const COLOR_NAMES: Array[String] = ["ROT", "BLAU", "GELB", "GRÜN", "LILA"]

const PLAYER_COLORS: Array[Color] = [
	Color("29b6f6"), # P1 Cyan
	Color("ef5350"), # P2 Rot
	Color("ffd54f"), # P3 Gold
	Color("66bb6a")  # P4 Grün
]

var _sim: HexagonHeatSim
var _tile_nodes: Array[MeshInstance3D] = []
var _tile_materials: Array[StandardMaterial3D] = []
var _player_nodes: Dictionary = {} # id -> Node3D
var _camera: Camera3D
var _shake_intensity := 0.0


func _ready() -> void:
	_setup_lighting_and_env()
	_setup_lava_sea()
	_setup_camera()


func bind(sim: HexagonHeatSim) -> void:
	_sim = sim
	_sim.player_bumped.connect(_on_player_bumped)
	_sim.player_eliminated.connect(_on_player_eliminated)
	_create_hex_nodes()
	_create_player_nodes()


func _setup_lighting_and_env() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, 40, 0)
	light.light_color = Color(1.0, 0.95, 0.9)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.05, 0.04) # Vulkanische Glut-Atmosphäre
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.25, 0.2)
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	env.environment = environment
	add_child(env)


func _setup_lava_sea() -> void:
	# Brodelnder Lava-See unterhalb der Kacheln
	var lava := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	lava.mesh = plane
	lava.position.y = -HexagonHeatSim.SINK_DEPTH - 1.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.18, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.28, 0.05)
	mat.emission_energy_multiplier = 1.2
	mat.roughness = 0.3
	lava.material_override = mat
	add_child(lava)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 18.5, 14.0)
	_camera.rotation_degrees = Vector3(-54.0, 0.0, 0.0)
	_camera.fov = 46.0
	_camera.current = true
	add_child(_camera)


func _create_hex_nodes() -> void:
	for n in _tile_nodes:
		n.queue_free()
	_tile_nodes.clear()
	_tile_materials.clear()

	for t in _sim.tiles:
		var node := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = HexagonHeatSim.HEX_OUTER_RADIUS * 0.96
		cyl.bottom_radius = HexagonHeatSim.HEX_OUTER_RADIUS * 0.94
		cyl.height = 2.0
		cyl.radial_segments = 6 # 6 Kanten = perfektes Hexagon!
		node.mesh = cyl
		node.position = Vector3(t.center.x, -1.0, t.center.y)
		node.rotation_degrees.y = 30.0 # Spitze nach oben ausrichten

		var mat := StandardMaterial3D.new()
		mat.albedo_color = TILE_COLORS[t.color_id]
		mat.roughness = 0.25
		mat.metallic = 0.15
		mat.rim_enabled = true
		mat.rim = 0.4
		node.material_override = mat

		add_child(node)
		_tile_nodes.append(node)
		_tile_materials.append(mat)


func _create_player_nodes() -> void:
	for child in _player_nodes.values():
		child.queue_free()
	_player_nodes.clear()

	for id in _sim.players:
		var p_data: HexagonHeatSim.Player = _sim.players[id]
		var color: Color = PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()]

		var node := Node3D.new()

		# Körper (Kapsel / Zylinder)
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = p_data.radius
		cap.height = p_data.radius * 2.2
		cap.radial_segments = 24
		body.mesh = cap
		body.position.y = p_data.radius * 1.1

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.2
		mat.metallic = 0.3
		mat.rim_enabled = true
		mat.rim = 0.5
		body.material_override = mat
		node.add_child(body)

		# Visier / Augen zur Erkennung der Blickrichtung
		var eyes := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = p_data.radius * 0.28
		sphere.height = p_data.radius * 0.5
		eyes.mesh = sphere
		eyes.position = Vector3(0, p_data.radius * 1.5, -p_data.radius * 0.8)
		var eye_mat := StandardMaterial3D.new()
		eye_mat.albedo_color = Color.WHITE
		eye_mat.emission_enabled = true
		eye_mat.emission = Color.WHITE
		eye_mat.emission_energy_multiplier = 0.8
		eyes.material_override = eye_mat
		node.add_child(eyes)

		add_child(node)
		_player_nodes[id] = node


func _process(delta: float) -> void:
	if _sim == null:
		return

	# 1. Kacheln Höhe und Leuchten animieren
	for i in _sim.tiles.size():
		var t: HexagonHeatSim.HexTile = _sim.tiles[i]
		var node: MeshInstance3D = _tile_nodes[i]
		var mat: StandardMaterial3D = _tile_materials[i]

		node.position.y = -1.0 + t.height_y

		# Leuchteffekt für die aufgerufene Zielfarbe
		if _sim.wave_phase == HexagonHeatSim.WavePhase.ALERT and t.color_id == _sim.target_color:
			mat.emission_enabled = true
			mat.emission = TILE_COLORS[t.color_id]
			mat.emission_energy_multiplier = 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.5
		else:
			mat.emission_enabled = false

	# 2. Spieler-Positionen und Blickrichtung aktualisieren
	for id in _sim.players:
		var p: HexagonHeatSim.Player = _sim.players[id]
		var node: Node3D = _player_nodes.get(id)
		if node == null:
			continue

		var target_y := -p.fall_y
		node.position = Vector3(p.pos.x, target_y, p.pos.y)

		if p.alive and p.vel.length_squared() > 0.05:
			var look_dir := Vector3(p.vel.x, 0, p.vel.y).normalized()
			node.rotation.y = atan2(-look_dir.x, -look_dir.z)

	# 3. Kamera-Shake
	if _shake_intensity > 0.0:
		_shake_intensity = maxf(0.0, _shake_intensity - delta * 4.0)
		_camera.h_offset = randf_range(-_shake_intensity, _shake_intensity)
		_camera.v_offset = randf_range(-_shake_intensity, _shake_intensity)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


func _on_player_bumped(_a: int, _b: int) -> void:
	_shake_intensity = maxf(_shake_intensity, 0.08)


func _on_player_eliminated(_id: int, pos: Vector2) -> void:
	_shake_intensity = maxf(_shake_intensity, 0.22)
	_spawn_lava_splash(Vector3(pos.x, -HexagonHeatSim.SINK_DEPTH, pos.y))


func _spawn_lava_splash(pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.35, 0.05)
	flash.light_energy = 5.0
	flash.omni_range = 6.0
	flash.position = pos
	add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.35)
	tween.tween_callback(flash.queue_free)
