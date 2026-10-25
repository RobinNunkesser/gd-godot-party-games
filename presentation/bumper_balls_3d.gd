class_name BumperBalls3D
extends Node3D
## 3D-Bühne für Bumper Balls.
## Rendert die schwebende Plattform, Spieler-Kugeln, Kugel-Roll-Rotation und Effekte.

const PLAYER_COLORS: Array[Color] = [
	Color("29b6f6"), # P1 Cyan
	Color("ef5350"), # P2 Rot
	Color("ffd54f"), # P3 Gold
	Color("66bb6a")  # P4 Grün
]

var _sim: BumperBallsSim
var _ball_nodes: Dictionary = {} # id -> MeshInstance3D
var _ball_rotations: Dictionary = {} # id -> Basis
var _camera: Camera3D
var _shake_intensity := 0.0


func _ready() -> void:
	_setup_lighting_and_env()
	_setup_arena()
	_setup_camera()


func bind(sim: BumperBallsSim) -> void:
	_sim = sim
	_sim.player_bumped.connect(_on_player_bumped)
	_sim.player_fell.connect(_on_player_fell)
	_create_player_nodes()


func _setup_lighting_and_env() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 35, 0)
	light.light_color = Color(1.0, 0.98, 0.94)
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.12, 0.22) # Tiefblauer Nachthimmel
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.42, 0.55)
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	env.environment = environment
	add_child(env)


func _setup_arena() -> void:
	# Schwebende Plattform / Eisscholle
	var platform := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = BumperBallsSim.ARENA_RADIUS
	cyl.bottom_radius = BumperBallsSim.ARENA_RADIUS * 0.95
	cyl.height = 1.2
	cyl.radial_segments = 64
	platform.mesh = cyl
	platform.position.y = -0.6

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.93, 1.0)
	mat.roughness = 0.12
	mat.metallic = 0.25
	mat.rim_enabled = true
	mat.rim = 0.4
	platform.material_override = mat
	add_child(platform)

	# Gefahren-Warnring am Rand
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = BumperBallsSim.ARENA_RADIUS - 0.25
	torus.outer_radius = BumperBallsSim.ARENA_RADIUS
	torus.rings = 64
	ring.mesh = torus
	ring.position.y = 0.02
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.3, 0.25, 0.8)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.2, 0.15)
	ring_mat.emission_energy_multiplier = 0.6
	ring.material_override = ring_mat
	add_child(ring)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 15.0, 13.0)
	_camera.rotation_degrees = Vector3(-48.0, 0.0, 0.0)
	_camera.fov = 44.0
	_camera.current = true
	add_child(_camera)


func _create_player_nodes() -> void:
	for child in _ball_nodes.values():
		child.queue_free()
	_ball_nodes.clear()
	_ball_rotations.clear()

	for id in _sim.balls:
		var ball_data: BumperBallsSim.Ball = _sim.balls[id]
		var color: Color = PLAYER_COLORS[(id - 1) % PLAYER_COLORS.size()]

		var node := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = ball_data.radius
		sphere.height = ball_data.radius * 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		node.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.2
		mat.metallic = 0.4
		mat.rim_enabled = true
		mat.rim = 0.6
		node.material_override = mat

		# Kleines Visier / Gesichtspunkt für Blickrichtung
		var visor := MeshInstance3D.new()
		var visor_mesh := SphereMesh.new()
		visor_mesh.radius = ball_data.radius * 0.25
		visor_mesh.height = ball_data.radius * 0.5
		visor.mesh = visor_mesh
		visor.position = Vector3(0, ball_data.radius * 0.2, -ball_data.radius * 0.85)
		var v_mat := StandardMaterial3D.new()
		v_mat.albedo_color = Color(0.1, 0.1, 0.15)
		v_mat.emission_enabled = true
		v_mat.emission = Color.WHITE
		v_mat.emission_energy_multiplier = 0.5
		visor.material_override = v_mat
		node.add_child(visor)

		add_child(node)
		_ball_nodes[id] = node
		_ball_rotations[id] = Basis()


func _process(delta: float) -> void:
	if _sim == null:
		return

	# Kugel-Positionen und Roll-Rotation aktualisieren
	for id in _sim.balls:
		var data: BumperBallsSim.Ball = _sim.balls[id]
		var node: MeshInstance3D = _ball_nodes.get(id)
		if node == null:
			continue

		var target_y := data.radius - data.fall_y
		node.position = Vector3(data.pos.x, target_y, data.pos.y)

		# Roll-Animation entlang der Bewegungsachse
		if data.alive and data.vel.length_squared() > 0.01:
			var roll_axis := Vector3(data.vel.y, 0, -data.vel.x).normalized()
			var roll_angle := (data.vel.length() / data.radius) * delta
			_ball_rotations[id] = _ball_rotations[id].rotated(roll_axis, roll_angle)
			node.transform.basis = _ball_rotations[id]

	# Kamera-Shake abklingen
	if _shake_intensity > 0.0:
		_shake_intensity = maxf(0.0, _shake_intensity - delta * 5.0)
		_camera.h_offset = randf_range(-_shake_intensity, _shake_intensity)
		_camera.v_offset = randf_range(-_shake_intensity, _shake_intensity)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


func _on_player_bumped(_a: int, _b: int, contact_pos: Vector2, strength: float) -> void:
	_shake_intensity = minf(0.35, strength * 0.04)
	# Kleiner Funkenblitz am Aufprallpunkt
	_spawn_spark(Vector3(contact_pos.x, 0.75, contact_pos.y))


func _on_player_fell(_id: int, _pos: Vector2) -> void:
	_shake_intensity = maxf(_shake_intensity, 0.15)


func _spawn_spark(pos: Vector3) -> void:
	var spark := OmniLight3D.new()
	spark.light_color = Color(1.0, 0.9, 0.5)
	spark.light_energy = 3.5
	spark.omni_range = 3.5
	spark.position = pos
	add_child(spark)

	var tween := create_tween()
	tween.tween_property(spark, "light_energy", 0.0, 0.18)
	tween.tween_callback(spark.queue_free)
