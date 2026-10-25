class_name HexagonAI
extends RefCounted
## Heuristik-KI für Hexagon Heat.
## Sucht bei Alarm die nächste sichere Farbkachel und verteidigt ihren Platz.

var player_id: int


func _init(p_id: int) -> void:
	player_id = p_id


func update(sim: HexagonHeatSim) -> void:
	var me: HexagonHeatSim.Player = sim.players.get(player_id)
	if me == null or not me.alive:
		return

	# Bei Alarm oder Absenken: Renne zur nächsten Kachel mit der Zielfarbe!
	if sim.wave_phase == HexagonHeatSim.WavePhase.ALERT or sim.wave_phase == HexagonHeatSim.WavePhase.SINKING:
		if sim.target_color >= 0:
			var target_tile := _find_nearest_target_tile(sim, me.pos, sim.target_color)
			if target_tile != null:
				var to_tile := target_tile.center - me.pos
				if to_tile.length_squared() > 0.1:
					sim.set_input(player_id, to_tile.normalized())
				else:
					# Bereits im Zentrum der sicheren Kachel: Ruhig bleiben
					sim.set_input(player_id, Vector2.ZERO)
				return

	# In der Warte- oder Hebephase: Bewege dich leicht Richtung Arenamitte für beste Reichweite
	if me.pos.length_squared() > 4.0:
		sim.set_input(player_id, -me.pos.normalized() * 0.5)
	else:
		sim.set_input(player_id, Vector2.ZERO)


func _find_nearest_target_tile(sim: HexagonHeatSim, from_pos: Vector2, color_id: int) -> HexagonHeatSim.HexTile:
	var best_tile: HexagonHeatSim.HexTile = null
	var min_dist_sq := INF

	for t in sim.tiles:
		if t.color_id == color_id:
			var d_sq := t.center.distance_squared_to(from_pos)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_tile = t

	return best_tile
