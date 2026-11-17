class_name RelicSpawner
extends Node2D

## RelicSpawner
## Spawns collectible relics across depth zones and manages salvage interactions.

## Script or class for individual relic pickups
## 18 collectible relics distributed across Zone 1 (War Zone), Zone 2 (Metropolis), and Zone 3 (Abyss)
const RELIC_SPAWN_PLAN: Array[Dictionary] = [
	# --- ZONE 1: Shallow Ruins (0m - 70m / y: 50 - 750) ---
	{"id": "relic_cup", "base_x": 240.0, "base_depth": 10.0},
	{"id": "relic_cup", "base_x": 1040.0, "base_depth": 14.0},
	{"id": "relic_keyboard", "base_x": 480.0, "base_depth": 16.0},
	{"id": "relic_keyboard", "base_x": 1220.0, "base_depth": 22.0},
	{"id": "relic_mouse", "base_x": 760.0, "base_depth": 26.0},
	{"id": "relic_mouse", "base_x": 340.0, "base_depth": 36.0},
	{"id": "relic_dogtag", "base_x": 620.0, "base_depth": 46.0},
	{"id": "relic_dogtag", "base_x": 1400.0, "base_depth": 58.0},
	{"id": "blueprint_tube", "base_x": 880.0, "base_depth": 40.0},

	# --- ZONE 2: Sunken Metropolis (70m - 150m / y: 750 - 1550) ---
	{"id": "relic_toaster", "base_x": 390.0, "base_depth": 85.0},
	{"id": "relic_toaster", "base_x": 1120.0, "base_depth": 102.0},
	{"id": "relic_mask", "base_x": 280.0, "base_depth": 95.0},
	{"id": "relic_mask", "base_x": 840.0, "base_depth": 125.0},
	{"id": "relic_console", "base_x": 630.0, "base_depth": 112.0},
	{"id": "relic_console", "base_x": 1320.0, "base_depth": 136.0},
	{"id": "blueprint_tube", "base_x": 520.0, "base_depth": 88.0},

	# --- ZONE 3: Pre-War Abyss (150m - 240m / y: 1550 - 2400) ---
	{"id": "relic_core", "base_x": 460.0, "base_depth": 165.0},
	{"id": "relic_core", "base_x": 1140.0, "base_depth": 205.0},
]


func _ready() -> void:
	spawn_all_relics()


## Spawns the 18 relics across the 1600x2400 ocean based on depth zones.
func spawn_all_relics() -> void:
	# Clean up any existing relic children first
	for child in get_children():
		child.queue_free()

	var surface_y: float = 50.0
	var depth_scale: float = 10.0

	# Retrieve surface_y and depth_scale dynamically if Diver exists in scene
	var diver: Node = get_tree().get_first_node_in_group("diver")
	if diver != null:
		if "surface_y" in diver:
			surface_y = float(diver.surface_y)
		if "depth_scale" in diver:
			depth_scale = float(diver.depth_scale)

	var backpack = _get_backpack()
	var db: Dictionary = backpack.RELIC_DB if backpack != null else {}

	for spawn_info in RELIC_SPAWN_PLAN:
		var relic_id: String = spawn_info["id"]
		var relic_data: Dictionary = db.get(relic_id, {})
		if relic_data.is_empty():
			continue

		var relic_item := RelicItem.new()
		relic_item.relic_id = relic_id
		relic_item.relic_data = relic_data

		# Calculate coordinates: x between 80 and 1520, y corresponding to min_depth
		var spawn_x: float = clampf(spawn_info["base_x"] + randf_range(-30.0, 30.0), 80.0, 1520.0)
		var target_depth: float = float(relic_data.get("min_depth", spawn_info["base_depth"]))
		var spawn_y: float = surface_y + (target_depth * depth_scale) + randf_range(-10.0, 10.0)
		# Clamp within playable depth bounds
		spawn_y = clampf(spawn_y, 80.0, 2350.0)

		relic_item.position = Vector2(spawn_x, spawn_y)
		relic_item.name = "Relic_%s" % relic_id
		add_child(relic_item)


## Spawns an individual relic at spawn_pos with a sinking tween (+30 px on Y).
func spawn_single_relic(relic_id: String, spawn_pos: Vector2) -> Area2D:
	var backpack = _get_backpack()
	var db: Dictionary = backpack.RELIC_DB if backpack != null else {}
	var relic_data: Dictionary = db.get(relic_id, {})
	if relic_data.is_empty():
		return null

	var relic_item := RelicItem.new()
	relic_item.relic_id = relic_id
	relic_item.relic_data = relic_data
	relic_item.position = spawn_pos
	relic_item.name = "Relic_%s_dropped" % relic_id
	add_child(relic_item)

	# Quick downward tween of +30 pixels on Y so it looks like it sinks out of diver's hands
	var target_y: float = clampf(spawn_pos.y + 30.0, 70.0, 2350.0)
	var tween := create_tween()
	tween.tween_property(relic_item, "position:y", target_y, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		if is_instance_valid(relic_item):
			relic_item.base_position_y = relic_item.position.y
	)

	return relic_item


func _get_backpack() -> Node:
	if Engine.has_singleton("Backpack"):
		return Engine.get_singleton("Backpack")
	if get_node_or_null("/root/Backpack") != null:
		return get_node("/root/Backpack")
	return null


# ==============================================================================
# Inner class representing an individual collectible Relic in the ocean
# ==============================================================================
class RelicItem extends Area2D:
	var relic_id: String = ""
	var relic_data: Dictionary = {}
	var is_player_in_range: bool = false
	var is_collected: bool = false

	var base_position_y: float = 0.0
	var bobbing_seed: float = 0.0
	var warning_timer: float = 0.0
	var e_key_handled: bool = false

	var glow_polygon: Polygon2D
	var core_polygon: Polygon2D
	var prompt_label: Label
	var collision_shape: CollisionShape2D

	const INTERACTION_DISTANCE: float = 70.0


	func _ready() -> void:
		add_to_group("relics")
		base_position_y = position.y
		bobbing_seed = randf() * TAU

		_create_collision()
		_create_visuals()
		_create_prompt_label()

		# Proximity signals
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)


	func _physics_process(delta: float) -> void:
		if is_collected:
			return

		# Floating idle bobbing animation in the water
		var time_sec: float = Time.get_ticks_msec() / 1000.0
		position.y = base_position_y + sin((time_sec * 2.5) + bobbing_seed) * 4.0

		# Subtle breathing glow pulsation
		if glow_polygon != null:
			var pulse: float = 1.0 + sin((time_sec * 3.5) + bobbing_seed) * 0.15
			glow_polygon.scale = Vector2(pulse, pulse)

		# Distance check fallback against Diver node
		_check_distance_to_diver()

		# Handle warning timer if backpack was overweight
		if warning_timer > 0.0:
			warning_timer -= delta
			if warning_timer <= 0.0:
				_reset_prompt_text()

		# Check E key press while in range
		if is_player_in_range and not is_collected:
			var e_pressed: bool = Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_E)
			if e_pressed:
				if not e_key_handled:
					e_key_handled = true
					_try_salvage()
			else:
				e_key_handled = false


	func _unhandled_input(event: InputEvent) -> void:
		if is_collected or not is_player_in_range:
			return

		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_E or event.keycode == KEY_E:
				_try_salvage()


	func _create_collision() -> void:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = INTERACTION_DISTANCE
		collision_shape.shape = circle
		add_child(collision_shape)


	func _create_visuals() -> void:
		# 1. Use Unified 4-State Relic Visual System ("underwater_buried")
		var bp = _get_backpack()
		if bp != null and bp.has_method("build_relic_visual"):
			var vis = bp.build_relic_visual(relic_id, "underwater_buried")
			if vis != null:
				add_child(vis)
				return

		var relic_color: Color = relic_data.get("color", Color.CYAN)

		# Fallback procedural visual if backpack is missing
		glow_polygon = Polygon2D.new()
		glow_polygon.name = "GlowPolygon"
		var glow_points := PackedVector2Array()
		var glow_segments: int = 12
		var glow_radius: float = 22.0
		for i in range(glow_segments):
			var angle: float = (i / float(glow_segments)) * TAU
			glow_points.append(Vector2(cos(angle), sin(angle)) * glow_radius)
		glow_polygon.polygon = glow_points
		glow_polygon.color = Color(relic_color.r, relic_color.g, relic_color.b, 0.28)
		add_child(glow_polygon)

		core_polygon = Polygon2D.new()
		core_polygon.name = "CorePolygon"
		var core_points := PackedVector2Array([
			Vector2(0.0, -16.0),
			Vector2(13.0, -4.0),
			Vector2(9.0, 14.0),
			Vector2(-9.0, 14.0),
			Vector2(-13.0, -4.0)
		])
		core_polygon.polygon = core_points
		core_polygon.color = relic_color
		add_child(core_polygon)

		var highlight := Polygon2D.new()
		highlight.name = "HighlightPolygon"
		var highlight_points := PackedVector2Array([
			Vector2(0.0, -10.0),
			Vector2(7.0, -2.0),
			Vector2(5.0, 7.0),
			Vector2(-5.0, 7.0),
			Vector2(-7.0, -2.0)
		])
		highlight.polygon = highlight_points
		highlight.color = Color.WHITE.lerp(relic_color, 0.35)
		add_child(highlight)

		var icon_p: String = str(relic_data.get("icon_path", ""))
		if not icon_p.is_empty():
			if Engine.has_singleton("Backpack"):
				Engine.get_singleton("Backpack").load_smart_sprite(self, icon_p, Vector2(32.0, 32.0))
			elif get_node_or_null("/root/Backpack") != null:
				get_node("/root/Backpack").load_smart_sprite(self, icon_p, Vector2(32.0, 32.0))


	func _create_prompt_label() -> void:
		prompt_label = Label.new()
		prompt_label.name = "PromptLabel"
		prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		prompt_label.position = Vector2(-150.0, -46.0)
		prompt_label.size = Vector2(300.0, 26.0)
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.visible = false

		prompt_label.add_theme_font_size_override("font_size", 14)
		prompt_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		prompt_label.add_theme_constant_override("shadow_offset_x", 1)
		prompt_label.add_theme_constant_override("shadow_offset_y", 1)
		prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		prompt_label.add_theme_constant_override("outline_size", 3)

		_reset_prompt_text()
		add_child(prompt_label)


	func _reset_prompt_text() -> void:
		if prompt_label == null:
			return
		var item_name: String = str(relic_data.get("name", "Unknown Relic"))
		var weight_val: float = float(relic_data.get("weight", 0.0))
		prompt_label.text = "[E] Salvage: %s (%.1f kg)" % [item_name, weight_val]
		prompt_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))


	func _check_distance_to_diver() -> void:
		var diver: Node2D = get_tree().get_first_node_in_group("diver") as Node2D
		if diver != null:
			var dist: float = global_position.distance_to(diver.global_position)
			var in_range: bool = dist <= INTERACTION_DISTANCE
			if in_range != is_player_in_range:
				is_player_in_range = in_range
				if warning_timer <= 0.0:
					_reset_prompt_text()
				prompt_label.visible = is_player_in_range


	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("diver") or body.name == "Diver" or body is CharacterBody2D:
			is_player_in_range = true
			if warning_timer <= 0.0:
				_reset_prompt_text()
			prompt_label.visible = true


	func _on_body_exited(body: Node2D) -> void:
		if body.is_in_group("diver") or body.name == "Diver" or body is CharacterBody2D:
			is_player_in_range = false
			prompt_label.visible = false


	func _try_salvage() -> void:
		if is_collected:
			return

		var backpack = _get_backpack()
		if backpack == null:
			push_error("RelicItem: Backpack singleton could not be found.")
			return

		if backpack.can_add_item(relic_id):
			is_collected = true
			backpack.add_item(relic_id)
			if backpack.has_method("play_sfx"):
				backpack.play_sfx("pickup")

			prompt_label.text = "+ Salvaged %s!" % relic_data.get("name", "Relic")
			prompt_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))

			# Play smooth scale-down and fade collection tween
			var tween := create_tween().set_parallel(true)
			tween.tween_property(self, "scale", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "modulate:a", 0.0, 0.25)
			tween.chain().tween_callback(queue_free)
		else:
			# Overweight feedback
			warning_timer = 1.8
			prompt_label.text = "[!] Backpack Too Heavy! (Max %.1f kg)" % float(backpack.max_weight)
			prompt_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

			# Shake animation on the label
			var orig_pos_x: float = prompt_label.position.x
			var shake := create_tween()
			shake.tween_property(prompt_label, "position:x", orig_pos_x + 8.0, 0.04)
			shake.tween_property(prompt_label, "position:x", orig_pos_x - 8.0, 0.04)
			shake.tween_property(prompt_label, "position:x", orig_pos_x + 4.0, 0.04)
			shake.tween_property(prompt_label, "position:x", orig_pos_x, 0.04)


	func _get_backpack() -> Node:
		if Engine.has_singleton("Backpack"):
			return Engine.get_singleton("Backpack")
		if get_node_or_null("/root/Backpack") != null:
			return get_node("/root/Backpack")
		return null
