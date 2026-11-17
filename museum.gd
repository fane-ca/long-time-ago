class_name MuseumHall
extends Node2D

## MuseumHall: 2.5D Top-Down Human Relic Exhibition Hall
## Features 6 2.5D display pedestals with persistent exhibits, alien visitors,
## admission fees, funny alien reviews, and relic selling.

var player: CharacterBody2D
var world_25d: Node2D
var hud_label: Label
var prompt_label: Label
var visitor_review_panel: PanelContainer
var visitor_review_label: Label
var review_timer: float = 0.0

var pedestals: Array[Node2D] = []
var alien_visitors: Array[CharacterBody2D] = []

var inventory_modal: Control
var manifest_summary_label: Label
var manifest_items_container: VBoxContainer

const WALK_SPEED: float = 210.0
const EXIT_DOOR_POS: Vector2 = Vector2(576.0, 580.0)

const PEDESTAL_POSITIONS: Array[Vector2] = [
	Vector2(380.0, 220.0),
	Vector2(576.0, 220.0),
	Vector2(772.0, 220.0),
	Vector2(380.0, 390.0),
	Vector2(576.0, 390.0),
	Vector2(772.0, 390.0),
]


func _ready() -> void:
	_create_hall_architecture()
	_create_world_25d()
	_create_pedestals()
	_create_player()
	_create_alien_visitors()
	_setup_ui()


func _physics_process(delta: float) -> void:
	_handle_player_movement(delta)
	_update_pedestal_interactions()
	_update_alien_visitors(delta)
	_update_hud()

	if review_timer > 0.0:
		review_timer -= delta
		if review_timer <= 0.0 and visitor_review_panel != null:
			visitor_review_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Toggle backpack manifest
		if event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_I:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			_toggle_inventory()
			return

		# Toggle Human Civilization Codex with C
		if event.physical_keycode == KEY_C or event.keycode == KEY_C:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			var bp = _get_backpack()
			if bp != null and bp.has_method("toggle_codex_ui"):
				bp.toggle_codex_ui()
			return

		# Quick drop in inventory
		if inventory_modal != null and inventory_modal.visible:
			var slot_idx: int = -1
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				slot_idx = event.keycode - KEY_1
			elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
				slot_idx = event.physical_keycode - KEY_1
			if slot_idx >= 0:
				var bp = _get_backpack()
				if bp != null and slot_idx < bp.items.size():
					if get_viewport() != null:
						get_viewport().set_input_as_handled()
					bp.remove_item_at(slot_idx)
					_populate_inventory()
					return

		# Exit to Island with F key
		if event.physical_keycode == KEY_F or event.keycode == KEY_F:
			if player != null and player.position.distance_to(EXIT_DOOR_POS) < 70.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				if is_inside_tree():
					get_tree().change_scene_to_file("res://land.tscn")
				return

		# Handle Pedestal [E] (Exhibit / Take) and [R] (Sell)
		_handle_pedestal_key_input(event)


## Draws the museum floor tiles, back walls, banners, and exit doorway.
func _create_hall_architecture() -> void:
	var arch := CanvasGroup.new()
	arch.name = "ArchitectureBackground"

	# 1. Hall Background / Outside darkness
	var dark_bg := ColorRect.new()
	dark_bg.color = Color(0.04, 0.05, 0.08)
	dark_bg.size = Vector2(1152.0, 648.0)
	arch.add_child(dark_bg)

	# 2. Polished Checkered Slate Floor (x: 200 to 952, y: 120 to 600)
	var floor_rect := ColorRect.new()
	floor_rect.color = Color(0.12, 0.16, 0.22)
	floor_rect.position = Vector2(200.0, 110.0)
	floor_rect.size = Vector2(752.0, 490.0)
	arch.add_child(floor_rect)

	# Decorative floor checkerboard grid lines
	for gx in range(200, 952, 48):
		var vl := ColorRect.new()
		vl.color = Color(0.16, 0.22, 0.28, 0.4)
		vl.position = Vector2(float(gx), 110.0)
		vl.size = Vector2(1.0, 490.0)
		arch.add_child(vl)
	for gy in range(110, 600, 48):
		var hl := ColorRect.new()
		hl.color = Color(0.16, 0.22, 0.28, 0.4)
		hl.position = Vector2(200.0, float(gy))
		hl.size = Vector2(752.0, 1.0)
		arch.add_child(hl)

	# Red carpet runner leading from exit to center
	var carpet := ColorRect.new()
	carpet.color = Color(0.48, 0.12, 0.16, 0.75)
	carpet.position = Vector2(536.0, 110.0)
	carpet.size = Vector2(80.0, 490.0)
	arch.add_child(carpet)

	# 3. North Interior Wall (Dark Wood & Brass accents)
	var north_wall := ColorRect.new()
	north_wall.color = Color(0.08, 0.11, 0.16)
	north_wall.position = Vector2(180.0, 30.0)
	north_wall.size = Vector2(792.0, 90.0)
	arch.add_child(north_wall)

	var wall_trim := ColorRect.new()
	wall_trim.color = Color(0.65, 0.52, 0.25) # Brass molding
	wall_trim.position = Vector2(180.0, 115.0)
	wall_trim.size = Vector2(792.0, 5.0)
	arch.add_child(wall_trim)

	# Grand Museum Banner
	var banner := Label.new()
	banner.text = "HUMAN CIVILIZATION MEMORIAL EXHIBITION"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(300.0, 55.0)
	banner.size = Vector2(552.0, 30.0)
	banner.add_theme_font_size_override("font_size", 16)
	banner.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.add_theme_constant_override("outline_size", 2)
	arch.add_child(banner)

	# 4. South Exit Door
	var exit_mat := ColorRect.new()
	exit_mat.color = Color(0.1, 0.14, 0.2)
	exit_mat.position = Vector2(536.0, 570.0)
	exit_mat.size = Vector2(80.0, 30.0)
	arch.add_child(exit_mat)

	var exit_sign := Label.new()
	exit_sign.text = "🚪 EXIT TO ISLAND"
	exit_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_sign.position = Vector2(480.0, 575.0)
	exit_sign.size = Vector2(192.0, 20.0)
	exit_sign.add_theme_font_size_override("font_size", 12)
	exit_sign.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	arch.add_child(exit_sign)

	add_child(arch)


## Sets up the Y-Sorted 2.5D World container.
func _create_world_25d() -> void:
	world_25d = Node2D.new()
	world_25d.name = "World25D"
	world_25d.y_sort_enabled = true
	add_child(world_25d)


## Creates the 6 2.5D Display Pedestals inside World25D.
func _create_pedestals() -> void:
	pedestals.clear()
	for i in range(PEDESTAL_POSITIONS.size()):
		var pos: Vector2 = PEDESTAL_POSITIONS[i]
		var pedestal := _build_pedestal_node(i, pos)
		world_25d.add_child(pedestal)
		pedestals.append(pedestal)
		_refresh_pedestal_display(i)


## Builds a single 2.5D pedestal StaticBody2D with top face, darker front face, and shadow.
func _build_pedestal_node(index: int, pos: Vector2) -> StaticBody2D:
	var pedestal := StaticBody2D.new()
	pedestal.name = "Pedestal_%d" % index
	# Footprint origin at the base for accurate 2.5D Y-sorting
	pedestal.position = pos

	# Footprint Collision Box at base
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56.0, 26.0)
	col.shape = rect
	col.position = Vector2(0.0, -8.0)
	pedestal.add_child(col)

	# Ground shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(34.0, 14.0, Vector2(0.0, 2.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.4)
	pedestal.add_child(shadow)

	# 2.5D Darker Front Face (y = -28 to y = 0)
	var front_face := Polygon2D.new()
	front_face.polygon = PackedVector2Array([
		Vector2(-26.0, 0.0),
		Vector2(26.0, 0.0),
		Vector2(26.0, -28.0),
		Vector2(-26.0, -28.0)
	])
	front_face.color = Color(0.3, 0.24, 0.18) # Dark polished mahogany
	pedestal.add_child(front_face)

	# Front Brass Plaque
	var plaque := ColorRect.new()
	plaque.name = "Plaque"
	plaque.color = Color(0.85, 0.72, 0.35)
	plaque.position = Vector2(-16.0, -20.0)
	plaque.size = Vector2(32.0, 10.0)
	pedestal.add_child(plaque)

	# 2.5D Top Face (Isometric/perspective oval cushion, y = -40 to y = -28)
	var top_face := Polygon2D.new()
	top_face.polygon = PackedVector2Array([
		Vector2(0.0, -42.0),
		Vector2(26.0, -28.0),
		Vector2(0.0, -18.0),
		Vector2(-26.0, -28.0)
	])
	top_face.color = Color(0.48, 0.38, 0.28) # Lighter top face
	pedestal.add_child(top_face)

	# Red Velvet Cushion on Top
	var cushion := Polygon2D.new()
	cushion.polygon = PackedVector2Array([
		Vector2(0.0, -38.0),
		Vector2(20.0, -28.0),
		Vector2(0.0, -21.0),
		Vector2(-20.0, -28.0)
	])
	cushion.color = Color(0.68, 0.12, 0.18)
	pedestal.add_child(cushion)

	# Container for the exhibited relic's floating visual
	var relic_container := Node2D.new()
	relic_container.name = "RelicContainer"
	relic_container.position = Vector2(0.0, -38.0)
	pedestal.add_child(relic_container)

	# Floating Label above pedestal
	var info_label := Label.new()
	info_label.name = "InfoLabel"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.position = Vector2(-110.0, -78.0)
	info_label.size = Vector2(220.0, 36.0)
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	info_label.add_theme_constant_override("shadow_offset_x", 1)
	info_label.add_theme_constant_override("shadow_offset_y", 1)
	info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	info_label.add_theme_constant_override("outline_size", 2)
	pedestal.add_child(info_label)

	return pedestal


## Refreshes a pedestal's visual representation based on Backpack.exhibited_relics.
func _refresh_pedestal_display(index: int) -> void:
	if index < 0 or index >= pedestals.size():
		return

	var pedestal: Node2D = pedestals[index]
	var relic_container: Node2D = pedestal.get_node_or_null("RelicContainer") as Node2D
	var info_label: Label = pedestal.get_node_or_null("InfoLabel") as Label

	# Clear previous visual
	for c in relic_container.get_children():
		c.queue_free()

	var bp = _get_backpack()
	var exhibits: Dictionary = bp.exhibited_relics if bp != null else {}

	if exhibits.has(index):
		var relic_id: String = str(exhibits[index])
		var db: Dictionary = bp.RELIC_DB if bp != null else {}
		var relic_data: Dictionary = db.get(relic_id, {})
		var relic_color: Color = relic_data.get("color", Color.CYAN)
		var relic_name: String = str(relic_data.get("name", "Unknown Relic"))

		# Glowing aura
		var glow := Polygon2D.new()
		glow.polygon = _make_ellipse(18.0, 10.0)
		glow.color = Color(relic_color.r, relic_color.g, relic_color.b, 0.35)
		relic_container.add_child(glow)

		# Faceted Relic Crystal Shape
		var relic_poly := Polygon2D.new()
		relic_poly.polygon = PackedVector2Array([
			Vector2(0.0, -14.0),
			Vector2(10.0, -3.0),
			Vector2(7.0, 10.0),
			Vector2(-7.0, 10.0),
			Vector2(-10.0, -3.0)
		])
		relic_poly.color = relic_color
		relic_container.add_child(relic_poly)

		# Highlight
		var hi := Polygon2D.new()
		hi.polygon = PackedVector2Array([
			Vector2(0.0, -9.0),
			Vector2(5.0, -2.0),
			Vector2(3.0, 5.0),
			Vector2(-3.0, 5.0),
			Vector2(-5.0, -2.0)
		])
		hi.color = Color.WHITE.lerp(relic_color, 0.4)
		relic_container.add_child(hi)

		# Floating animation on the relic
		var tween := relic_container.create_tween().set_loops()
		tween.tween_property(relic_container, "position:y", -42.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(relic_container, "position:y", -36.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		info_label.text = "%s\n$%d cr" % [relic_name, int(relic_data.get("value", 0))]
		info_label.add_theme_color_override("font_color", relic_color)
	else:
		info_label.text = "[Empty Pedestal #%d]" % (index + 1)
		info_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8, 0.7))


## Creates the 2.5D Player Survivor with foot-centered Y-sorting origin.
func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "PlayerSurvivor"
	player.position = Vector2(576.0, 500.0)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	col.shape = circle
	col.position = Vector2(0.0, -4.0)
	player.add_child(col)

	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(18.0, 8.0)
	shadow.color = Color(0.0, 0.0, 0.0, 0.38)
	player.add_child(shadow)

	# Modular Paper-Doll Equipment Visuals (Signature yellow hazmat suit & dynamic gear)
	var bp = _get_backpack()
	var built_visual: bool = false
	if bp != null and bp.has_method("build_character_visuals"):
		var vis = bp.build_character_visuals(player, false)
		if vis != null:
			vis.position = Vector2.ZERO
			built_visual = true

	if not built_visual:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		if ResourceLoader.exists("res://icon.svg"):
			sprite.texture = load("res://icon.svg")
		sprite.scale = Vector2(0.4, 0.4)
		sprite.position = Vector2(0.0, -26.0)
		player.add_child(sprite)

	world_25d.add_child(player)


## Spawns 3 wandering extraterrestrial visitor NPCs that inspect pedestals.
func _create_alien_visitors() -> void:
	alien_visitors.clear()
	var alien_colors: Array[Color] = [
		Color(0.3, 0.85, 0.4), # Green Alien
		Color(0.85, 0.4, 0.9), # Purple Alien
		Color(0.2, 0.85, 0.9)  # Cyan Alien
	]

	for i in range(3):
		var alien := CharacterBody2D.new()
		alien.name = "AlienVisitor_%d" % i
		alien.position = Vector2(400.0 + (i * 180.0), 300.0 + (i * 40.0))

		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		col.shape = circle
		col.position = Vector2(0.0, -4.0)
		alien.add_child(col)

		# Shadow
		var shadow := Polygon2D.new()
		shadow.polygon = _make_ellipse(16.0, 8.0)
		shadow.color = Color(0.0, 0.0, 0.0, 0.35)
		alien.add_child(shadow)

		# Cute alien body & head
		var a_color: Color = alien_colors[i]
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-10.0, 0.0),
			Vector2(10.0, 0.0),
			Vector2(12.0, -24.0),
			Vector2(0.0, -32.0),
			Vector2(-12.0, -24.0)
		])
		body.color = a_color
		alien.add_child(body)

		# Glowing Antenna
		var antenna := Polygon2D.new()
		antenna.polygon = PackedVector2Array([
			Vector2(-2.0, -32.0),
			Vector2(2.0, -32.0),
			Vector2(1.0, -44.0),
			Vector2(-1.0, -44.0)
		])
		antenna.color = a_color
		alien.add_child(antenna)

		var bulb := Polygon2D.new()
		bulb.polygon = _make_ellipse(4.0, 4.0, Vector2(0.0, -46.0))
		bulb.color = Color.WHITE.lerp(a_color, 0.3)
		alien.add_child(bulb)

		# Big cute alien eyes
		var eye_l := Polygon2D.new()
		eye_l.polygon = _make_ellipse(3.5, 4.5, Vector2(-5.0, -20.0))
		eye_l.color = Color(0.08, 0.08, 0.12)
		alien.add_child(eye_l)

		var eye_r := Polygon2D.new()
		eye_r.polygon = _make_ellipse(3.5, 4.5, Vector2(5.0, -20.0))
		eye_r.color = Color(0.08, 0.08, 0.12)
		alien.add_child(eye_r)

		# Metadata for AI state machine
		alien.set_meta("state", "walking")
		alien.set_meta("target_pedestal", i % PEDESTAL_POSITIONS.size())
		alien.set_meta("inspect_time", 0.0)
		alien.set_meta("alien_index", i)

		world_25d.add_child(alien)
		alien_visitors.append(alien)


## Updates alien visitor wandering AI, reviews, and admission fee collection.
func _update_alien_visitors(delta: float) -> void:
	for alien in alien_visitors:
		if not is_instance_valid(alien):
			continue

		var state: String = str(alien.get_meta("state", "walking"))
		var target_idx: int = int(alien.get_meta("target_pedestal", 0))
		var target_pos: Vector2 = PEDESTAL_POSITIONS[target_idx] + Vector2(0.0, 36.0)

		if state == "walking":
			var dir: Vector2 = (target_pos - alien.position)
			var dist: float = dir.length()
			if dist > 8.0:
				alien.velocity = dir.normalized() * 65.0
				alien.move_and_slide()
			else:
				# Reached pedestal -> start inspecting
				alien.velocity = Vector2.ZERO
				alien.set_meta("state", "inspecting")
				alien.set_meta("inspect_time", randf_range(3.0, 5.0))
				_on_alien_inspect_pedestal(alien, target_idx)

		elif state == "inspecting":
			var t: float = float(alien.get_meta("inspect_time", 0.0)) - delta
			alien.set_meta("inspect_time", t)
			if t <= 0.0:
				# Pick next pedestal to visit
				alien.set_meta("state", "walking")
				var next_idx: int = _pick_next_pedestal_for_alien(target_idx)
				alien.set_meta("target_pedestal", next_idx)


## Picks a pedestal for an alien to visit (prioritizes occupied exhibits).
func _pick_next_pedestal_for_alien(current_idx: int) -> int:
	var bp = _get_backpack()
	var exhibits: Dictionary = bp.exhibited_relics if bp != null else {}
	var occupied_indices: Array = exhibits.keys()

	# If there are occupied pedestals not equal to current, favor them!
	var candidates: Array = []
	for idx in occupied_indices:
		if int(idx) != current_idx:
			candidates.append(int(idx))

	if not candidates.is_empty() and randf() < 0.75:
		return candidates[randi() % candidates.size()]

	# Fallback to random pedestal
	var next_idx: int = randi() % PEDESTAL_POSITIONS.size()
	while next_idx == current_idx and PEDESTAL_POSITIONS.size() > 1:
		next_idx = randi() % PEDESTAL_POSITIONS.size()
	return next_idx


## Called when an alien visitor arrives and inspects a pedestal.
func _on_alien_inspect_pedestal(alien: CharacterBody2D, pedestal_idx: int) -> void:
	var bp = _get_backpack()
	if bp == null:
		return

	if bp.exhibited_relics.has(pedestal_idx):
		var relic_id: String = str(bp.exhibited_relics[pedestal_idx])
		var db: Dictionary = bp.RELIC_DB
		var relic_data: Dictionary = db.get(relic_id, {})
		var relic_name: String = str(relic_data.get("name", "Human Relic"))
		var alien_desc: String = str(relic_data.get("alien_desc", "Fascinating human artifact."))

		# 1. Award Admission fee: $15 base, or $25 (+50%) if Archive Study is unlocked!
		var fee: int = 15
		var is_study_unlocked: bool = bp.unlocked_rooms.get("archive_study", false)
		if is_study_unlocked:
			fee = 25
		bp.gold += fee

		# 2. Spawn floating admission text
		var fee_note: String = "+$%d Admission!" % fee
		if is_study_unlocked:
			fee_note += " (Archive +50%)"
		_spawn_floating_cash_text(alien.position + Vector2(0.0, -50.0), fee_note)

		# 3. Show funny alien review dialog banner at bottom of screen
		var alien_names: Array[String] = ["Xylar-4", "Glip-Glop", "Zorblax", "Dr. Vorn"]
		var alien_i: int = int(alien.get_meta("alien_index", 0))
		var a_name: String = alien_names[alien_i % alien_names.size()]

		_show_visitor_review(a_name, relic_name, alien_desc)


## Displays floating green cash feedback text that drifts up and fades.
func _spawn_floating_cash_text(pos: Vector2, text: String) -> void:
	var float_label := Label.new()
	float_label.text = text
	float_label.position = pos
	float_label.add_theme_font_size_override("font_size", 14)
	float_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.45))
	float_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	float_label.add_theme_constant_override("outline_size", 3)
	world_25d.add_child(float_label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(float_label, "position:y", pos.y - 35.0, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_label, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(float_label.queue_free)


## Shows the visitor alien's hilarious reaction quote banner.
func _show_visitor_review(alien_name: String, relic_name: String, desc: String) -> void:
	if visitor_review_panel == null or visitor_review_label == null:
		return

	visitor_review_label.text = "👽 %s inspecting %s: \"%s\" (+$15 Paid!)" % [
		alien_name, relic_name, desc
	]
	visitor_review_panel.visible = true
	review_timer = 4.5


## Handles 8-directional walking controls inside the museum.
func _handle_player_movement(_delta: float) -> void:
	if player == null:
		return

	var input_dir: Vector2 = Vector2.ZERO
	var left: bool = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left")
	var right: bool = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right")
	var up: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_action_pressed("ui_up")
	var down: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_action_pressed("ui_down")

	if left: input_dir.x -= 1.0
	if right: input_dir.x += 1.0
	if up: input_dir.y -= 1.0
	if down: input_dir.y += 1.0

	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()

	player.velocity = input_dir * WALK_SPEED
	player.move_and_slide()

	# Clamp to interior museum hall bounds
	player.position.x = clampf(player.position.x, 220.0, 930.0)
	player.position.y = clampf(player.position.y, 140.0, 585.0)

	# Flip character visuals / sprite according to walking direction
	var vis = player.get_node_or_null("CharacterVisuals")
	if vis != null and absf(player.velocity.x) > 5.0:
		vis.scale.x = -1.0 if player.velocity.x < 0.0 else 1.0

	var sprite: Sprite2D = player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and absf(player.velocity.x) > 5.0:
		sprite.flip_h = player.velocity.x < 0.0


## Checks nearest pedestal to display interaction prompts.
func _update_pedestal_interactions() -> void:
	if player == null or prompt_label == null:
		return

	# Check Exit Door proximity
	if player.position.distance_to(EXIT_DOOR_POS) < 70.0:
		prompt_label.text = "🚪 Press [F] to Exit to Island"
		prompt_label.visible = true
		return

	var nearest_idx: int = _get_nearest_pedestal_index()
	if nearest_idx == -1:
		prompt_label.visible = false
		return

	var bp = _get_backpack()
	var exhibits: Dictionary = bp.exhibited_relics if bp != null else {}

	if exhibits.has(nearest_idx):
		var relic_id: String = str(exhibits[nearest_idx])
		var db: Dictionary = bp.RELIC_DB
		var relic_data: Dictionary = db.get(relic_id, {})
		var val: int = int(relic_data.get("value", 0))
		var r_name: String = str(relic_data.get("name", "Relic"))
		prompt_label.text = "🏛️ %s  |  [E] Take Relic  |  [R] Sell for $%d" % [r_name, val]
		prompt_label.visible = true
	else:
		if bp != null and not bp.items.is_empty():
			# Find first identified relic
			var exhibitable_idx: int = -1
			for idx in range(bp.items.size()):
				if bp.items[idx].get("identified", true) == true:
					exhibitable_idx = idx
					break

			if exhibitable_idx != -1:
				var first_item: Dictionary = bp.items[exhibitable_idx]
				var f_name: String = str(first_item.get("name", "Relic"))
				prompt_label.text = "✨ Pedestal #%d: Press [E] to Exhibit \"%s\"" % [nearest_idx + 1, f_name]
			else:
				prompt_label.text = "⚠️ Pedestal #%d: Relics in pack are encrusted! Clean at Home Lab first" % (nearest_idx + 1)
			prompt_label.visible = true
		else:
			prompt_label.text = "Pedestal #%d Empty (No Relics in Backpack to Exhibit)" % (nearest_idx + 1)
			prompt_label.visible = true


## Handles keyboard events for exhibiting [E] and selling [R].
func _handle_pedestal_key_input(event: InputEvent) -> void:
	if player == null:
		return

	var nearest_idx: int = _get_nearest_pedestal_index()
	if nearest_idx == -1:
		return

	var bp = _get_backpack()
	if bp == null:
		return

	# Key [E]: Exhibit first identified backpack item OR Take exhibited relic back
	if event.physical_keycode == KEY_E or event.keycode == KEY_E:
		if bp.exhibited_relics.has(nearest_idx):
			# Take relic back into backpack
			var relic_id: String = str(bp.exhibited_relics[nearest_idx])
			if bp.can_add_item(relic_id):
				bp.add_item(relic_id, true) # Remains identified
				bp.clear_pedestal_relic(nearest_idx)
				_refresh_pedestal_display(nearest_idx)
				_spawn_floating_cash_text(player.position + Vector2(0.0, -40.0), "Relic Taken Back!")
			else:
				_spawn_floating_cash_text(player.position + Vector2(0.0, -40.0), "Backpack Too Heavy!")
		else:
			# Exhibit first identified item from backpack
			if not bp.items.is_empty():
				var target_slot: int = -1
				for slot in range(bp.items.size()):
					if bp.items[slot].get("identified", true) == true:
						target_slot = slot
						break

				if target_slot != -1:
					var consumed_item: Dictionary = bp.consume_item_at(target_slot)
					var relic_id: String = str(consumed_item.get("id", ""))
					bp.set_pedestal_relic(nearest_idx, relic_id)
					_refresh_pedestal_display(nearest_idx)
					_spawn_floating_cash_text(PEDESTAL_POSITIONS[nearest_idx] + Vector2(0.0, -60.0), "Exhibited!")
				else:
					_spawn_floating_cash_text(player.position + Vector2(0.0, -40.0), "Relic is encrusted in barnacles! Clean it at your Home Lab first!")

		if get_viewport() != null:
			get_viewport().set_input_as_handled()

	# Key [R]: Sell exhibited relic for its full gold value
	elif event.physical_keycode == KEY_R or event.keycode == KEY_R:
		if bp.exhibited_relics.has(nearest_idx):
			var relic_id: String = str(bp.exhibited_relics[nearest_idx])
			var db: Dictionary = bp.RELIC_DB
			var relic_data: Dictionary = db.get(relic_id, {})
			var val: int = int(relic_data.get("value", 0))
			var mult: float = bp.get_salvage_value_multiplier() if bp.has_method("get_salvage_value_multiplier") else 1.0
			val = int(round(float(val) * mult))

			bp.gold += val
			bp.clear_pedestal_relic(nearest_idx)
			_refresh_pedestal_display(nearest_idx)
			_spawn_floating_cash_text(PEDESTAL_POSITIONS[nearest_idx] + Vector2(0.0, -60.0), "+$%d Sold!" % val)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()


## Returns the index of the nearest pedestal within 68 pixels, or -1 if none in range.
func _get_nearest_pedestal_index() -> int:
	if player == null:
		return -1

	var best_idx: int = -1
	var best_dist: float = 68.0

	for i in range(PEDESTAL_POSITIONS.size()):
		var p_pos: Vector2 = PEDESTAL_POSITIONS[i]
		var dist: float = player.position.distance_to(p_pos)
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	return best_idx


## Updates the top HUD overview.
func _update_hud() -> void:
	if hud_label == null:
		return

	var bp = _get_backpack()
	var cur_day: int = int(bp.current_day) if bp != null else 1
	var gold_val: int = int(bp.gold) if bp != null else 0
	var exhibits_count: int = bp.exhibited_relics.size() if bp != null else 0
	var pack_count: int = bp.items.size() if bp != null else 0
	var cur_w: float = float(bp.current_weight) if bp != null else 0.0
	var max_w: float = float(bp.max_weight) if bp != null else 15.0

	hud_label.text = "MUSEUM HALL  |  Day %d  |  Gold: $%d  |  Exhibited: %d / 6  |  In Pack: %d (%.1f/%.1f kg)  |  [TAB / I] Manifest" % [
		cur_day, gold_val, exhibits_count, pack_count, cur_w, max_w
	]


## Sets up HUD, prompts, and the visitor review banner.
func _setup_ui() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1

	# Top info bar
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.16, 0.85)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(24.0, 20.0)

	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 15)
	hud_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	panel.add_child(hud_label)
	hud_layer.add_child(panel)

	# Interaction Prompt
	prompt_label = Label.new()
	prompt_label.name = "ActionPrompt"
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt_label.position = Vector2(276.0, 75.0)
	prompt_label.size = Vector2(600.0, 32.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.visible = false
	hud_layer.add_child(prompt_label)

	# Visitor Alien Review banner at bottom
	visitor_review_panel = PanelContainer.new()
	visitor_review_panel.name = "VisitorReviewPanel"
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.03, 0.07, 0.14, 0.9)
	r_style.set_corner_radius_all(8)
	r_style.border_color = Color(0.4, 0.85, 0.5, 0.7)
	r_style.border_width_left = 2
	r_style.border_width_top = 2
	r_style.border_width_right = 2
	r_style.border_width_bottom = 2
	r_style.content_margin_left = 18.0
	r_style.content_margin_right = 18.0
	r_style.content_margin_top = 8.0
	r_style.content_margin_bottom = 8.0
	visitor_review_panel.add_theme_stylebox_override("panel", r_style)
	visitor_review_panel.position = Vector2(176.0, 600.0)
	visitor_review_panel.custom_minimum_size = Vector2(800.0, 36.0)
	visitor_review_panel.visible = false

	visitor_review_label = Label.new()
	visitor_review_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visitor_review_label.add_theme_font_size_override("font_size", 14)
	visitor_review_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.75))
	visitor_review_panel.add_child(visitor_review_label)
	hud_layer.add_child(visitor_review_panel)

	add_child(hud_layer)

	# Inventory Overlay Layer (layer = 5)
	_setup_inventory_ui()


func _setup_inventory_ui() -> void:
	var inv_layer := CanvasLayer.new()
	inv_layer.name = "InventoryLayer"
	inv_layer.layer = 5

	inventory_modal = Control.new()
	inventory_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_modal.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 420.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.08, 0.16, 0.95)
	p_style.set_corner_radius_all(10)
	p_style.border_color = Color(0.3, 0.7, 0.9, 0.8)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.content_margin_left = 20.0
	p_style.content_margin_right = 20.0
	p_style.content_margin_top = 16.0
	p_style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "SURVIVOR BACKPACK MANIFEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(title)

	manifest_summary_label = Label.new()
	manifest_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	manifest_summary_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(manifest_summary_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520.0, 240.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	manifest_items_container = VBoxContainer.new()
	manifest_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manifest_items_container.add_theme_constant_override("separation", 6)
	scroll.add_child(manifest_items_container)
	vbox.add_child(scroll)

	var footer := Label.new()
	footer.text = "[TAB] or [I] Close  |  Walk to Pedestal and Press [E] to Exhibit"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.6, 0.8, 0.95))
	vbox.add_child(footer)

	panel.add_child(vbox)
	center.add_child(panel)
	inv_layer.add_child(inventory_modal)
	add_child(inv_layer)


func _toggle_inventory() -> void:
	if inventory_modal == null:
		return
	inventory_modal.visible = not inventory_modal.visible
	if inventory_modal.visible:
		_populate_inventory()


func _populate_inventory() -> void:
	if manifest_items_container == null:
		return

	for c in manifest_items_container.get_children():
		c.queue_free()

	var bp = _get_backpack()
	var items_list: Array = bp.items if bp != null else []
	var total_w: float = float(bp.current_weight) if bp != null else 0.0
	var max_w: float = float(bp.max_weight) if bp != null else 15.0
	var total_val: int = bp.get_total_value() if bp != null else 0

	manifest_summary_label.text = "Relics: %d  |  Total Value: %d cr  |  Cargo: %.1f / %.1f kg" % [
		items_list.size(), total_val, total_w, max_w
	]

	if items_list.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "\nBackpack is empty.\nDive into the ocean to salvage human relics."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		manifest_items_container.add_child(empty_lbl)
		return

	for i in range(items_list.size()):
		var item: Dictionary = items_list[i]
		var is_identified: bool = bool(item.get("identified", true))
		var item_color: Color = item.get("color", Color.CYAN) if is_identified else Color(0.72, 0.68, 0.58)

		var row := PanelContainer.new()
		var r_style := StyleBoxFlat.new()
		r_style.bg_color = Color(0.06, 0.12, 0.22, 0.8)
		r_style.set_corner_radius_all(6)
		r_style.content_margin_left = 10.0
		r_style.content_margin_right = 10.0
		r_style.content_margin_top = 6.0
		r_style.content_margin_bottom = 6.0
		r_style.border_width_left = 2
		r_style.border_color = item_color
		row.add_theme_stylebox_override("panel", r_style)

		var hbox := HBoxContainer.new()
		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		var slot_p: String = "[%d] " % (i + 1) if (i < 9) else ""
		if is_identified:
			name_lbl.text = "%s%s  •  %.1f kg  •  %d cr" % [slot_p, item.get("name", ""), item.get("weight", 0.0), item.get("value", 0)]
		else:
			name_lbl.text = "%sEncrusted Relic Lump (%.1f kg)  •  ??? cr" % [slot_p, float(item.get("weight", 0.0))]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", item_color)
		info_vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		if is_identified:
			desc_lbl.text = "\"%s\"" % str(item.get("alien_desc", ""))
		else:
			desc_lbl.text = "\"[Heavily encrusted in calcified ocean sediment. Clean at Home Lab workbench to reveal.]\""
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.8))
		info_vbox.add_child(desc_lbl)

		hbox.add_child(info_vbox)

		var drop_btn := Button.new()
		drop_btn.text = "[Drop]"
		drop_btn.custom_minimum_size = Vector2(65.0, 28.0)
		drop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		drop_btn.add_theme_font_size_override("font_size", 12)
		drop_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		drop_btn.pressed.connect(func():
			if bp != null:
				bp.remove_item_at(i)
				_populate_inventory()
		)
		hbox.add_child(drop_btn)

		row.add_child(hbox)
		manifest_items_container.add_child(row)


func _make_ellipse(rx: float, ry: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs: int = 16
	for i in range(segs):
		var ang: float = (i / float(segs)) * TAU
		pts.append(offset + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


func _get_backpack() -> Node:
	if Engine.has_singleton("Backpack"):
		return Engine.get_singleton("Backpack")
	if get_node_or_null("/root/Backpack") != null:
		return get_node("/root/Backpack")
	return null
