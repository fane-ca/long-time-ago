class_name Diver
extends CharacterBody2D

## Diver: 2D Deep-Sea Underwater Exploration & Relic Salvage Controller
## Features:
## 1. 8-directional swimming with underwater inertia, drag, and idle sinking.
## 2. 1600x2400 scrolling ocean with Camera2D position smoothing and boundaries.
## 3. 3 Historical Depth Strata (Zone 1: War Zone, Zone 2: Metropolis, Zone 3: Pre-War Abyss).
## 4. Drifting naval mine hazards in Zone 1 (flashes screen red and knocks -15 O2).
## 5. Dynamic depth darkness (CanvasModulate) scaling from surface sunlight to 85% darkness at 1400m.
## 6. Directional Diver Headlamp / Flashlight rig with PointLight2D and volumetric cone polygons.
## 7. Zone 3 high-pressure radioactive trench (O2 drains 2x faster unless oxygen_level >= 2).
## 8. Relic salvage manifest and HUD stats.

signal oxygen_changed(current: float, max_value: float)
signal oxygen_depleted
signal surfaced
signal submerged

const OCEAN_WIDTH: float = 1600.0
const OCEAN_DEPTH: float = 2400.0
const ZONE_1_BOTTOM_Y: float = 750.0  # 70m
const ZONE_2_BOTTOM_Y: float = 1550.0 # 150m
const ZONE_3_BOTTOM_Y: float = 2400.0 # 235m

@export_group("Movement")
## Maximum underwater swimming speed in pixels per second.
@export var swim_speed: float = 240.0
## Acceleration rate when moving (higher = reaches max speed faster).
@export var acceleration: float = 4.5
## Water drag / deceleration rate when releasing controls (higher = stops faster).
@export var drag: float = 3.0
## Gentle downward sinking speed applied when not pressing movement keys.
@export var sink_speed: float = 28.0

@export_group("Visuals")
## Optional direct reference to the sprite node. If not assigned, auto-detects Sprite2D.
@export var sprite: Node2D
## Set to false if the sprite's default texture faces left.
@export var default_facing_right: bool = true
## Maximum tilt angle in degrees when swimming up or down.
@export_range(0.0, 60.0) var max_tilt_degrees: float = 25.0
## How quickly the sprite rotates toward the movement tilt angle.
@export var tilt_lerp_speed: float = 8.0

@export_group("Oxygen & Depth")
## Maximum oxygen capacity.
@export var max_oxygen: float = 100.0
## Rate of oxygen depletion in percentage points per second while underwater.
@export var oxygen_depletion_rate: float = 2.0
## Rate of oxygen refill in percentage points per second near the surface.
@export var oxygen_refill_rate: float = 35.0
## Y position threshold: position.y <= surface_y is considered near or at the water surface.
@export var surface_y: float = 50.0
## Number of pixels corresponding to 1 meter of depth.
@export var depth_scale: float = 10.0

@export_group("Boundary Limits")
## Screen boundary clamp limits: (min_x, max_x, min_y, max_y)
@export var min_boundary: Vector2 = Vector2(32.0, 32.0)
@export var max_boundary: Vector2 = Vector2(1568.0, 2368.0)

## Current oxygen level (0.0 to max_oxygen).
var oxygen: float = 100.0
## Current depth in meters (0.0 at surface, increasing as you dive deeper).
var depth: float = 0.0

## Internal Lighting, Camera & UI References
var _camera: Camera2D
var _headlamp_rig: Node2D
var _headlamp_spot_light: PointLight2D
var _ambient_point_light: PointLight2D
var _canvas_modulate: CanvasModulate
var _damage_flash_rect: ColorRect
var _shake_amount: float = 0.0

var _hud_label: Label
var _surface_prompt_label: Label
var _inventory_modal: Control
var _manifest_summary_label: Label
var _manifest_items_container: VBoxContainer
var _is_surfaced: bool = false
var _is_rescuing: bool = false
var _rescue_modal: Control


func _ready() -> void:
	add_to_group("diver")

	# Starting position (centered in the 1600 width, below water surface)
	position = Vector2(800.0, 160.0)

	# Read persistent upgrade stats from Backpack singleton
	var backpack = _get_backpack()
	if backpack != null:
		max_oxygen = float(backpack.get_effective_max_oxygen()) if backpack.has_method("get_effective_max_oxygen") else float(backpack.max_oxygen)
		swim_speed = float(backpack.swim_speed)
	oxygen = max_oxygen

	_ensure_visible_sprite()
	_ensure_collision_shape()

	# 1. Setup Camera2D with 1600x2400 boundaries & position smoothing
	_setup_camera()

	# 2. Setup Directional Diver Headlamp / Flashlight rig
	_setup_headlamp()

	# 3. Setup CanvasModulate ambient depth darkness
	_setup_ambient_lighting()

	# 4. Build 1600x2400 Ocean background & 3 historical depth strata silhouettes
	_setup_ocean_strata_world()

	# 5. Spawn floating naval mine hazards in Zone 1 & 2
	_spawn_naval_mines()

	# 5b. Spawn patrolling Pre-War security drones in Zone 2 & 3
	_spawn_security_drones()

	# 6. Setup dynamic HUD (layer 1), damage flash (layer 2), and Inventory modal (layer 5)
	_setup_dynamic_ui()

	# 7. Connect Backpack autoload events & oxygen depletion
	if backpack != null:
		backpack.inventory_changed.connect(_on_backpack_changed)
		backpack.item_dropped.connect(_on_item_dropped)
	oxygen_depleted.connect(_on_oxygen_depleted)

	# 8. Automatically spawn the 18 relics in the ocean
	_spawn_relics()


func _physics_process(delta: float) -> void:
	if _is_rescuing:
		velocity = Vector2.ZERO
		return

	_handle_movement(delta)
	_clamp_screen_position()
	_handle_oxygen_and_depth(delta)
	_update_depth_darkness()
	_update_headlamp(delta)
	_update_camera_shake(delta)
	_update_sprite_orientation(delta)
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_rescuing:
			if event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.keycode == KEY_ENTER or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
				_on_rescue_return_pressed()
				return

		# Go ashore when near water surface by pressing F
		if position.y <= 70.0 and (event.physical_keycode == KEY_F or event.keycode == KEY_F):
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			if is_inside_tree():
				get_tree().change_scene_to_file("res://land.tscn")
			return

		# Toggle manifest dialog with TAB or I
		if event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_I:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			_toggle_inventory_panel()
			return

		# Toggle Human Civilization Codex with C
		if event.physical_keycode == KEY_C or event.keycode == KEY_C:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			var bp = _get_backpack()
			if bp != null and bp.has_method("toggle_codex_ui"):
				bp.toggle_codex_ui()
			return

		# Quick-drop items with number keys 1-9 while manifest dialog is open
		if _inventory_modal != null and _inventory_modal.visible:
			var slot_idx: int = -1
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				slot_idx = event.keycode - KEY_1
			elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
				slot_idx = event.physical_keycode - KEY_1

			if slot_idx >= 0:
				var backpack = _get_backpack()
				if backpack != null and slot_idx < backpack.items.size():
					if get_viewport() != null:
						get_viewport().set_input_as_handled()
					backpack.remove_item_at(slot_idx)
					return


## Returns an 8-directional normalized movement vector from WASD or Arrow keys.
func get_swim_input() -> Vector2:
	var input_dir: Vector2 = Vector2.ZERO

	var left: bool = (
		Input.is_physical_key_pressed(KEY_A)
		or Input.is_physical_key_pressed(KEY_LEFT)
		or Input.is_key_pressed(KEY_A)
		or Input.is_key_pressed(KEY_LEFT)
		or Input.is_action_pressed("ui_left")
	)
	var right: bool = (
		Input.is_physical_key_pressed(KEY_D)
		or Input.is_physical_key_pressed(KEY_RIGHT)
		or Input.is_key_pressed(KEY_D)
		or Input.is_key_pressed(KEY_RIGHT)
		or Input.is_action_pressed("ui_right")
	)
	var up: bool = (
		Input.is_physical_key_pressed(KEY_W)
		or Input.is_physical_key_pressed(KEY_UP)
		or Input.is_key_pressed(KEY_W)
		or Input.is_key_pressed(KEY_UP)
		or Input.is_action_pressed("ui_up")
	)
	var down: bool = (
		Input.is_physical_key_pressed(KEY_S)
		or Input.is_physical_key_pressed(KEY_DOWN)
		or Input.is_key_pressed(KEY_S)
		or Input.is_key_pressed(KEY_DOWN)
		or Input.is_action_pressed("ui_down")
	)

	if left: input_dir.x -= 1.0
	if right: input_dir.x += 1.0
	if up: input_dir.y -= 1.0
	if down: input_dir.y += 1.0

	if input_dir.length_squared() > 1.0:
		return input_dir.normalized()
	return input_dir


## Handles 8-directional swimming with inertia, drag, idle sinking, and cargo encumbrance.
func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = get_swim_input()

	var backpack = _get_backpack()
	var base_swim_speed: float = float(backpack.get_effective_swim_speed()) if (backpack != null and backpack.has_method("get_effective_swim_speed")) else (float(backpack.swim_speed) if backpack != null else swim_speed)

	var current_swim_speed: float = base_swim_speed
	if backpack != null and backpack.max_weight > 0.0:
		var threshold: float = backpack.max_weight * 0.7
		if backpack.current_weight > threshold:
			var encumbrance_factor: float = clampf(
				(backpack.current_weight - threshold) / (backpack.max_weight - threshold),
				0.0, 1.0
			)
			current_swim_speed *= lerpf(1.0, 0.65, encumbrance_factor)

	if input_dir != Vector2.ZERO:
		var target_velocity: Vector2 = input_dir * current_swim_speed
		var weight: float = clampf(acceleration * delta, 0.0, 1.0)
		velocity = velocity.lerp(target_velocity, weight)
	else:
		var target_velocity: Vector2 = Vector2(0.0, sink_speed)
		var weight: float = clampf(drag * delta, 0.0, 1.0)
		velocity = velocity.lerp(target_velocity, weight)

	move_and_slide()


## Clamps diver position within 1600x2400 ocean limits.
func _clamp_screen_position() -> void:
	if position.x < min_boundary.x:
		position.x = min_boundary.x
		if velocity.x < 0.0: velocity.x = 0.0
	elif position.x > max_boundary.x:
		position.x = max_boundary.x
		if velocity.x > 0.0: velocity.x = 0.0

	if position.y < min_boundary.y:
		position.y = min_boundary.y
		if velocity.y < 0.0: velocity.y = 0.0
	elif position.y > max_boundary.y:
		position.y = max_boundary.y
		if velocity.y > 0.0: velocity.y = 0.0


## Tracks depth (m) and handles oxygen depletion/replenishment + Zone 3 High-Pressure Abyss penalty.
func _handle_oxygen_and_depth(delta: float) -> void:
	depth = maxf((position.y - surface_y) / depth_scale, 0.0)

	var backpack = _get_backpack()
	if backpack != null:
		max_oxygen = float(backpack.get_effective_max_oxygen()) if backpack.has_method("get_effective_max_oxygen") else float(backpack.max_oxygen)

	var currently_surfaced: bool = position.y <= surface_y
	if currently_surfaced != _is_surfaced:
		_is_surfaced = currently_surfaced
		if _is_surfaced:
			surfaced.emit()
		else:
			submerged.emit()

	var previous_oxygen: float = oxygen
	if _is_surfaced:
		oxygen = minf(oxygen + oxygen_refill_rate * delta, max_oxygen)
	else:
		var current_depletion: float = oxygen_depletion_rate
		# Zone 3: Pre-War Abyss (depth >= 150m)
		# Oxygen drains 2x faster unless oxygen_level >= 2
		if depth >= 150.0:
			var o2_lvl: int = int(backpack.oxygen_level) if backpack != null else 1
			if o2_lvl < 2:
				current_depletion *= 2.0

		oxygen = maxf(oxygen - current_depletion * delta, 0.0)

	if oxygen != previous_oxygen:
		oxygen_changed.emit(oxygen, max_oxygen)

	if previous_oxygen > 0.0 and oxygen <= 0.0:
		oxygen_depleted.emit()


## Dynamically scales ambient ocean darkness from sunlight at surface down to 85% darkness at 1400m.
func _update_depth_darkness() -> void:
	if _canvas_modulate == null:
		return

	# y <= 400: Clear daylight water Color(1, 1, 1)
	# y = 1400: 85% darkness Color(0.15, 0.16, 0.22)
	# y = 2400: 93% deep abyss trench darkness Color(0.06, 0.07, 0.11)
	if position.y <= 400.0:
		_canvas_modulate.color = Color(1.0, 1.0, 1.0)
	elif position.y <= 1400.0:
		var t: float = (position.y - 400.0) / 1000.0
		_canvas_modulate.color = Color(1.0, 1.0, 1.0).lerp(Color(0.15, 0.16, 0.22), t)
	else:
		var t_abyss: float = clampf((position.y - 1400.0) / 1000.0, 0.0, 1.0)
		_canvas_modulate.color = Color(0.15, 0.16, 0.22).lerp(Color(0.06, 0.07, 0.11), t_abyss)


## Smoothly rotates the diver's directional headlamp beam toward swim direction or mouse cursor.
func _update_headlamp(delta: float) -> void:
	if _headlamp_rig == null:
		return

	var target_angle: float = 0.0
	if velocity.length() > 20.0:
		target_angle = velocity.angle()
	else:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_pos - global_position
		if to_mouse.length() > 30.0:
			target_angle = to_mouse.angle()
		else:
			target_angle = 0.0 if default_facing_right else PI

	_headlamp_rig.rotation = lerp_angle(_headlamp_rig.rotation, target_angle, clampf(9.0 * delta, 0.0, 1.0))


## Applies and decays screen shake on camera.
func _update_camera_shake(delta: float) -> void:
	if _camera != null and _shake_amount > 0.0:
		_camera.offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
		_shake_amount = move_toward(_shake_amount, 0.0, delta * 30.0)
	elif _camera != null and _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


## Flips and tilts the sprite toward the swimming direction for natural underwater motion.
func _update_sprite_orientation(delta: float) -> void:
	if sprite == null:
		return

	if absf(velocity.x) > 10.0:
		var moving_left: bool = velocity.x < 0.0
		var should_flip: bool = moving_left if default_facing_right else not moving_left
		if sprite is Sprite2D:
			(sprite as Sprite2D).flip_h = should_flip
		elif sprite is AnimatedSprite2D:
			(sprite as AnimatedSprite2D).flip_h = should_flip
		else:
			sprite.scale.x = -absf(sprite.scale.x) if should_flip else absf(sprite.scale.x)

	var target_rotation: float = 0.0
	if velocity.length() > 10.0:
		var pitch_ratio: float = clampf(velocity.y / swim_speed, -1.0, 1.0)
		var max_tilt_rad: float = deg_to_rad(max_tilt_degrees)
		target_rotation = pitch_ratio * max_tilt_rad

		var is_flipped_h: bool = false
		if sprite is Sprite2D:
			is_flipped_h = (sprite as Sprite2D).flip_h
		elif sprite is AnimatedSprite2D:
			is_flipped_h = (sprite as AnimatedSprite2D).flip_h
		else:
			is_flipped_h = sprite.scale.x < 0.0

		if is_flipped_h:
			target_rotation = - target_rotation

	sprite.rotation = lerp_angle(sprite.rotation, target_rotation, clampf(tilt_lerp_speed * delta, 0.0, 1.0))


## Attaches and configures the scrolling Camera2D.
func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "DiverCamera"
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(OCEAN_WIDTH)
	_camera.limit_bottom = int(OCEAN_DEPTH)
	add_child(_camera)


## Creates the diver's directional headlamp rig (ambient light, spot beam, and volumetric beam polygon).
func _setup_headlamp() -> void:
	_headlamp_rig = Node2D.new()
	_headlamp_rig.name = "HeadlampRig"
	_headlamp_rig.position = Vector2(18.0, -4.0) # Aligned with diver's helmet mask visor!

	# 1. Soft 360-degree ambient aura around diver so diver is always readable
	var amb_grad := Gradient.new()
	amb_grad.set_color(0, Color(1, 1, 1, 1))
	amb_grad.set_color(1, Color(1, 1, 1, 0))
	var amb_tex := GradientTexture2D.new()
	amb_tex.gradient = amb_grad
	amb_tex.fill = GradientTexture2D.FILL_RADIAL
	amb_tex.fill_from = Vector2(0.5, 0.5)
	amb_tex.fill_to = Vector2(0.5, 0.0)
	amb_tex.width = 128
	amb_tex.height = 128

	_ambient_point_light = PointLight2D.new()
	_ambient_point_light.name = "DiverAmbientLight"
	_ambient_point_light.texture = amb_tex
	_ambient_point_light.scale = Vector2(2.5, 2.5)
	_ambient_point_light.energy = 1.0
	_ambient_point_light.color = Color(0.85, 0.95, 1.0)
	add_child(_ambient_point_light)

	# 2. Forward Directional PointLight2D beam
	var spot_grad := Gradient.new()
	spot_grad.set_color(0, Color(1, 1, 1, 1))
	spot_grad.set_color(1, Color(1, 1, 1, 0))
	var spot_tex := GradientTexture2D.new()
	spot_tex.gradient = spot_grad
	spot_tex.fill = GradientTexture2D.FILL_RADIAL
	spot_tex.fill_from = Vector2(0.2, 0.5)
	spot_tex.fill_to = Vector2(0.95, 0.5)
	spot_tex.width = 256
	spot_tex.height = 256

	_headlamp_spot_light = PointLight2D.new()
	_headlamp_spot_light.name = "FlashlightBeamLight"
	_headlamp_spot_light.texture = spot_tex
	_headlamp_spot_light.position = Vector2(180.0, 0.0)
	_headlamp_spot_light.scale = Vector2(3.0, 1.8)
	_headlamp_spot_light.energy = 1.8
	_headlamp_spot_light.color = Color(0.92, 0.96, 1.0)
	_headlamp_rig.add_child(_headlamp_spot_light)

	# 3. Translucent Volumetric Light Beam Polygons (visible light cone)
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var outer_cone := Polygon2D.new()
	outer_cone.name = "VolumetricOuterCone"
	outer_cone.polygon = PackedVector2Array([
		Vector2(0.0, -5.0),
		Vector2(420.0, -110.0),
		Vector2(450.0, 0.0),
		Vector2(420.0, 110.0),
		Vector2(0.0, 5.0)
	])
	outer_cone.color = Color(0.65, 0.92, 1.0, 0.28)
	outer_cone.material = add_mat
	_headlamp_rig.add_child(outer_cone)

	var inner_cone := Polygon2D.new()
	inner_cone.name = "VolumetricInnerCore"
	inner_cone.polygon = PackedVector2Array([
		Vector2(0.0, -2.0),
		Vector2(280.0, -45.0),
		Vector2(300.0, 0.0),
		Vector2(280.0, 45.0),
		Vector2(0.0, 2.0)
	])
	inner_cone.color = Color(1.0, 1.0, 0.85, 0.45)
	inner_cone.material = add_mat
	_headlamp_rig.add_child(inner_cone)

	# Lens / Lamp bulb glow dot
	var bulb := Polygon2D.new()
	bulb.polygon = _make_ellipse(6.0, 6.0)
	bulb.color = Color(1.0, 1.0, 0.9, 0.85)
	_headlamp_rig.add_child(bulb)

	add_child(_headlamp_rig)


## Configures CanvasModulate for ambient depth darkness.
func _setup_ambient_lighting() -> void:
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "OceanAmbientDarkness"
	_canvas_modulate.color = Color(1.0, 1.0, 1.0)

	if get_parent() != null:
		get_parent().call_deferred("add_child", _canvas_modulate)
	else:
		call_deferred("add_child", _canvas_modulate)


## Procedurally constructs the 1600x2400 ocean background, waterline, dock, and 3 strata silhouettes.
func _setup_ocean_strata_world() -> void:
	var world := Node2D.new()
	world.name = "OceanStrataWorld"
	world.z_index = -8

	# --- 1. BASE OCEAN BACKDROPS ---
	# Air above water surface
	var air := ColorRect.new()
	air.color = Color(0.2, 0.4, 0.58, 0.75)
	air.position = Vector2(0.0, 0.0)
	air.size = Vector2(OCEAN_WIDTH, surface_y)
	world.add_child(air)

	# Waterline
	var waterline := ColorRect.new()
	waterline.color = Color(0.4, 0.9, 1.0, 0.95)
	waterline.position = Vector2(0.0, surface_y)
	waterline.size = Vector2(OCEAN_WIDTH, 3.0)
	world.add_child(waterline)

	# Zone 1 Base Water: Shallow War Zone (50 - 750)
	var z1_rect := ColorRect.new()
	z1_rect.color = Color(0.04, 0.12, 0.24)
	z1_rect.position = Vector2(0.0, surface_y)
	z1_rect.size = Vector2(OCEAN_WIDTH, ZONE_1_BOTTOM_Y - surface_y)
	world.add_child(z1_rect)

	# Zone 2 Base Water: Sunken Metropolis (750 - 1550)
	var z2_rect := ColorRect.new()
	z2_rect.color = Color(0.02, 0.06, 0.15)
	z2_rect.position = Vector2(0.0, ZONE_1_BOTTOM_Y)
	z2_rect.size = Vector2(OCEAN_WIDTH, ZONE_2_BOTTOM_Y - ZONE_1_BOTTOM_Y)
	world.add_child(z2_rect)

	# Zone 3 Base Water: Pre-War Abyss Trench (1550 - 2400)
	var z3_rect := ColorRect.new()
	z3_rect.color = Color(0.01, 0.018, 0.04)
	z3_rect.position = Vector2(0.0, ZONE_2_BOTTOM_Y)
	z3_rect.size = Vector2(OCEAN_WIDTH, ZONE_3_BOTTOM_Y - ZONE_2_BOTTOM_Y)
	world.add_child(z3_rect)

	# --- 2. SURFACE EXPEDITION BOAT & DOCK (At x: 800, y: 35) ---
	var boat := Node2D.new()
	boat.position = Vector2(800.0, 35.0)

	var hull := Polygon2D.new()
	hull.polygon = PackedVector2Array([
		Vector2(-120.0, -14.0),
		Vector2(120.0, -14.0),
		Vector2(95.0, 18.0),
		Vector2(-95.0, 18.0)
	])
	hull.color = Color(0.38, 0.22, 0.12)
	boat.add_child(hull)

	var deck := ColorRect.new()
	deck.color = Color(0.58, 0.38, 0.22)
	deck.position = Vector2(-110.0, -18.0)
	deck.size = Vector2(220.0, 6.0)
	boat.add_child(deck)

	var mast := ColorRect.new()
	mast.color = Color(0.3, 0.32, 0.35)
	mast.position = Vector2(0.0, -55.0)
	mast.size = Vector2(4.0, 38.0)
	boat.add_child(mast)

	var boat_lbl := Label.new()
	boat_lbl.text = "SURFACE DOCK & EXPEDITION BOAT"
	boat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boat_lbl.position = Vector2(-160.0, -42.0)
	boat_lbl.size = Vector2(320.0, 18.0)
	boat_lbl.add_theme_font_size_override("font_size", 12)
	boat_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	boat.add_child(boat_lbl)

	world.add_child(boat)

	# --- 3. ZONE 1 SILHOUETTES: SUNKEN WARSHIP & ARTILLERY ---
	var z1_label := Label.new()
	z1_label.text = "▼ ZONE 1: SHALLOW WAR ZONE (0m - 70m)  •  DANGER: DRIFTING NAVAL MINES ▼"
	z1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z1_label.position = Vector2(0.0, 85.0)
	z1_label.size = Vector2(OCEAN_WIDTH, 20.0)
	z1_label.add_theme_font_size_override("font_size", 13)
	z1_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.45, 0.7))
	world.add_child(z1_label)

	# Sunken Battleship 1 at (320, 500)
	var ship1 := Polygon2D.new()
	ship1.polygon = PackedVector2Array([
		Vector2(140.0, 560.0),
		Vector2(500.0, 480.0),
		Vector2(520.0, 540.0),
		Vector2(460.0, 580.0),
		Vector2(180.0, 620.0)
	])
	ship1.color = Color(0.1, 0.14, 0.2, 0.88)
	world.add_child(ship1)

	# Dual naval artillery gun barrels
	var barrel1 := ColorRect.new()
	barrel1.color = Color(0.08, 0.11, 0.16)
	barrel1.position = Vector2(340.0, 475.0)
	barrel1.size = Vector2(110.0, 7.0)
	barrel1.rotation = -0.38
	world.add_child(barrel1)

	var barrel2 := ColorRect.new()
	barrel2.color = Color(0.08, 0.11, 0.16)
	barrel2.position = Vector2(335.0, 488.0)
	barrel2.size = Vector2(105.0, 7.0)
	barrel2.rotation = -0.38
	world.add_child(barrel2)

	# Exposed Destroyer Hull Ribs at (1240, 580)
	for i in range(5):
		var rib := Polygon2D.new()
		var rx: float = 1140.0 + float(i) * 55.0
		rib.polygon = PackedVector2Array([
			Vector2(rx, 630.0),
			Vector2(rx + 14.0, 520.0),
			Vector2(rx + 24.0, 520.0),
			Vector2(rx + 10.0, 630.0)
		])
		rib.color = Color(0.12, 0.16, 0.22, 0.75)
		world.add_child(rib)

	# --- 4. ZONE 2 SILHOUETTES: SUNKEN METROPOLIS SKYSCRAPERS ---
	var z2_label := Label.new()
	z2_label.text = "▼ ZONE 2: SUNKEN METROPOLIS (70m - 150m)  •  OLD WORLD TOWERS & MEMORIES ▼"
	z2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z2_label.position = Vector2(0.0, 770.0)
	z2_label.size = Vector2(OCEAN_WIDTH, 20.0)
	z2_label.add_theme_font_size_override("font_size", 13)
	z2_label.add_theme_color_override("font_color", Color(0.35, 0.8, 0.95, 0.75))
	world.add_child(z2_label)

	# Tilted West Skyscraper at x: 220, y: 1180
	var tower1 := Polygon2D.new()
	tower1.polygon = PackedVector2Array([
		Vector2(120.0, 1480.0),
		Vector2(160.0, 960.0),
		Vector2(300.0, 980.0),
		Vector2(260.0, 1500.0)
	])
	tower1.color = Color(0.06, 0.09, 0.14)
	world.add_child(tower1)

	# Broken window grids on tower 1
	for wy in range(1020, 1440, 48):
		for wx in range(175, 275, 24):
			var win := ColorRect.new()
			win.position = Vector2(float(wx), float(wy))
			win.size = Vector2(10.0, 12.0)
			# Subtle emergency cyan glow on some windows
			if (wx + wy) % 5 == 0:
				win.color = Color(0.2, 0.5, 0.65, 0.4)
			else:
				win.color = Color(0.03, 0.05, 0.08, 0.8)
			world.add_child(win)

	# Grand Monolith Central Tower at x: 820, y: 1260
	var tower2 := ColorRect.new()
	tower2.color = Color(0.05, 0.08, 0.13)
	tower2.position = Vector2(700.0, 920.0)
	tower2.size = Vector2(240.0, 620.0)
	world.add_child(tower2)

	# Antenna Spire on Monolith Tower
	var spire := ColorRect.new()
	spire.color = Color(0.2, 0.25, 0.3)
	spire.position = Vector2(818.0, 830.0)
	spire.size = Vector2(4.0, 90.0)
	world.add_child(spire)

	# Amber warning light at spire tip
	var amber := Polygon2D.new()
	amber.polygon = _make_ellipse(5.0, 5.0, Vector2(820.0, 830.0))
	amber.color = Color(1.0, 0.65, 0.1, 0.9)
	world.add_child(amber)

	# Monolith window grid
	for my in range(960, 1500, 36):
		for mx in range(720, 920, 26):
			var mwin := ColorRect.new()
			mwin.position = Vector2(float(mx), float(my))
			mwin.size = Vector2(14.0, 10.0)
			if (mx + my) % 7 == 0:
				mwin.color = Color(0.3, 0.7, 0.8, 0.35)
			else:
				mwin.color = Color(0.02, 0.04, 0.07, 0.9)
			world.add_child(mwin)

	# Collapsed Freeway Overpass at x: 1260, y: 1020
	var overpass := Polygon2D.new()
	overpass.polygon = PackedVector2Array([
		Vector2(1080.0, 1080.0),
		Vector2(1420.0, 980.0),
		Vector2(1440.0, 1010.0),
		Vector2(1100.0, 1110.0)
	])
	overpass.color = Color(0.07, 0.1, 0.15)
	world.add_child(overpass)

	# East Tower at x: 1420, y: 1340
	var tower3 := ColorRect.new()
	tower3.color = Color(0.05, 0.08, 0.13)
	tower3.position = Vector2(1330.0, 1080.0)
	tower3.size = Vector2(170.0, 460.0)
	world.add_child(tower3)

	# --- 5. ZONE 3 SILHOUETTES: PRE-WAR ABYSS TRENCH & HYDROTHERMAL CHIMNEYS ---
	var z3_label := Label.new()
	z3_label.text = "⚠ ZONE 3: PRE-WAR ABYSS TRENCH (150m - 240m)  •  EXTREME PRESSURE: O2 DRAIN 2x ⚠"
	z3_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	z3_label.position = Vector2(0.0, 1570.0)
	z3_label.size = Vector2(OCEAN_WIDTH, 20.0)
	z3_label.add_theme_font_size_override("font_size", 14)
	z3_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 0.85))
	world.add_child(z3_label)

	# Left Abyssal Canyon Wall (x: 0 to 240)
	var left_canyon := Polygon2D.new()
	left_canyon.polygon = PackedVector2Array([
		Vector2(0.0, 1540.0),
		Vector2(180.0, 1680.0),
		Vector2(120.0, 1840.0),
		Vector2(240.0, 2020.0),
		Vector2(160.0, 2220.0),
		Vector2(260.0, 2380.0),
		Vector2(0.0, 2400.0)
	])
	left_canyon.color = Color(0.02, 0.03, 0.05)
	world.add_child(left_canyon)

	# Right Abyssal Canyon Wall (x: 1360 to 1600)
	var right_canyon := Polygon2D.new()
	right_canyon.polygon = PackedVector2Array([
		Vector2(1600.0, 1540.0),
		Vector2(1420.0, 1690.0),
		Vector2(1480.0, 1880.0),
		Vector2(1360.0, 2060.0),
		Vector2(1440.0, 2240.0),
		Vector2(1340.0, 2380.0),
		Vector2(1600.0, 2400.0)
	])
	right_canyon.color = Color(0.02, 0.03, 0.05)
	world.add_child(right_canyon)

	# Trench Floor Bedrock (y: 2340 to 2400)
	var bedrock := ColorRect.new()
	bedrock.color = Color(0.015, 0.02, 0.04)
	bedrock.position = Vector2(0.0, 2340.0)
	bedrock.size = Vector2(OCEAN_WIDTH, 60.0)
	world.add_child(bedrock)

	# Glowing Radioactive Crystal Shards in Abyss
	var crystal_points: Array[Vector2] = [
		Vector2(160.0, 1720.0),
		Vector2(220.0, 2040.0),
		Vector2(1400.0, 1750.0),
		Vector2(1370.0, 2100.0),
		Vector2(850.0, 2330.0)
	]
	for cp in crystal_points:
		var crystal := Polygon2D.new()
		crystal.polygon = PackedVector2Array([
			cp + Vector2(0.0, -14.0),
			cp + Vector2(8.0, 0.0),
			cp + Vector2(0.0, 14.0),
			cp + Vector2(-8.0, 0.0)
		])
		crystal.color = Color(0.2, 1.0, 0.6, 0.55)
		world.add_child(crystal)

	# Hydrothermal Vent Chimneys at x: 480 and x: 1100
	var chimney1 := Polygon2D.new()
	chimney1.polygon = PackedVector2Array([
		Vector2(450.0, 2340.0),
		Vector2(470.0, 2260.0),
		Vector2(495.0, 2260.0),
		Vector2(515.0, 2340.0)
	])
	chimney1.color = Color(0.03, 0.04, 0.06)
	world.add_child(chimney1)

	var chimney2 := Polygon2D.new()
	chimney2.polygon = PackedVector2Array([
		Vector2(1070.0, 2340.0),
		Vector2(1090.0, 2250.0),
		Vector2(1115.0, 2250.0),
		Vector2(1135.0, 2340.0)
	])
	chimney2.color = Color(0.03, 0.04, 0.06)
	world.add_child(chimney2)

	# Pre-War Ancient Laboratory Vault Door at (780, 2315)
	var vault := ColorRect.new()
	vault.color = Color(0.08, 0.12, 0.16)
	vault.position = Vector2(740.0, 2280.0)
	vault.size = Vector2(80.0, 60.0)
	world.add_child(vault)

	var vault_glow := Polygon2D.new()
	vault_glow.polygon = _make_ellipse(16.0, 16.0, Vector2(780.0, 2310.0))
	vault_glow.color = Color(0.2, 0.9, 0.7, 0.45)
	world.add_child(vault_glow)

	if get_parent() != null:
		get_parent().call_deferred("add_child", world)
	else:
		world.top_level = true
		call_deferred("add_child", world)


## Spawns drifting naval mine hazards in Zone 1 & 2.
func _spawn_naval_mines() -> void:
	var mine_positions: Array[Vector2] = [
		Vector2(360.0, 220.0),
		Vector2(780.0, 360.0),
		Vector2(1180.0, 260.0),
		Vector2(1440.0, 520.0),
		Vector2(580.0, 620.0),
		Vector2(450.0, 880.0),
		Vector2(1240.0, 1180.0)
	]

	for pos in mine_positions:
		var mine := NavalMine.new()
		mine.position = pos
		mine.base_position = pos
		mine.diver_ref = self
		if get_parent() != null:
			get_parent().call_deferred("add_child", mine)
		else:
			mine.top_level = true
			call_deferred("add_child", mine)


## Spawns patrolling Pre-War security drones in Zone 2 & 3.
func _spawn_security_drones() -> void:
	var drone_configs: Array[Dictionary] = [
		{"pos": Vector2(400.0, 920.0), "min_x": 220.0, "max_x": 1380.0, "speed": 110.0, "dir": 1.0},
		{"pos": Vector2(1200.0, 1260.0), "min_x": 180.0, "max_x": 1420.0, "speed": 125.0, "dir": -1.0},
		{"pos": Vector2(500.0, 1750.0), "min_x": 280.0, "max_x": 1320.0, "speed": 95.0, "dir": 1.0},
		{"pos": Vector2(1050.0, 2120.0), "min_x": 320.0, "max_x": 1280.0, "speed": 115.0, "dir": -1.0}
	]

	for cfg in drone_configs:
		var drone := SecurityDrone.new()
		drone.position = cfg["pos"]
		drone.patrol_min_x = cfg["min_x"]
		drone.patrol_max_x = cfg["max_x"]
		drone.patrol_speed = cfg["speed"]
		drone.direction = cfg["dir"]
		drone.diver_ref = self
		if get_parent() != null:
			get_parent().call_deferred("add_child", drone)
		else:
			drone.top_level = true
			call_deferred("add_child", drone)


## Called when the diver collides with a naval mine: knocks -18.0 O2, flashes screen red, shakes camera.
func trigger_mine_explosion(mine_pos: Vector2) -> void:
	# 1. Knock 18.0 Oxygen
	oxygen = maxf(oxygen - 18.0, 0.0)
	oxygen_changed.emit(oxygen, max_oxygen)
	if oxygen <= 0.0:
		oxygen_depleted.emit()

	# 2. Flash screen red
	if _damage_flash_rect != null:
		_damage_flash_rect.color = Color(1.0, 0.05, 0.05, 0.8)
		var tween := create_tween()
		tween.tween_property(_damage_flash_rect, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Knockback velocity away from mine
	var knock_dir: Vector2 = (global_position - mine_pos).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = Vector2.UP
	velocity += knock_dir * 350.0

	# 4. Trigger camera screen shake
	_shake_amount = 14.0
	_update_ui()


## Called when diver encounters a patrolling Pre-War security drone sensor cone or body.
func trigger_drone_hazard(drone_pos: Vector2) -> void:
	# 1. Knock 18.0 Oxygen
	oxygen = maxf(oxygen - 18.0, 0.0)
	oxygen_changed.emit(oxygen, max_oxygen)
	if oxygen <= 0.0:
		oxygen_depleted.emit()

	# 2. Flash screen red
	if _damage_flash_rect != null:
		_damage_flash_rect.color = Color(1.0, 0.1, 0.1, 0.8)
		var tween := create_tween()
		tween.tween_property(_damage_flash_rect, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Knockback velocity away from drone
	var knock_dir: Vector2 = (global_position - drone_pos).normalized()
	if knock_dir == Vector2.ZERO:
		knock_dir = Vector2.UP
	velocity += knock_dir * 350.0

	# 4. Camera screen shake
	_shake_amount = 14.0
	_update_ui()


## Ensures this CharacterBody2D has the modular paper-doll character visuals attached.
func _ensure_visible_sprite() -> void:
	var bp = _get_backpack()
	if bp != null and bp.has_method("build_character_visuals"):
		sprite = bp.build_character_visuals(self, true)
		return

	var sprite_node: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
	if sprite_node == null:
		sprite_node = Sprite2D.new()
		sprite_node.name = "Sprite2D"
		add_child(sprite_node)
	sprite_node.position = Vector2.ZERO
	if sprite_node.texture == null:
		sprite_node.texture = preload("res://icon.svg")
	sprite = sprite_node


## Adjusts headlamp beam power, scale, and color based on mask/helmet upgrade level.
func _update_headlamp_for_mask() -> void:
	if _headlamp_spot_light == null:
		return
	var bp = _get_backpack()
	var o2_lvl: int = int(bp.oxygen_level) if bp != null else 1
	if o2_lvl >= 3:
		_headlamp_spot_light.energy = 2.4
		_headlamp_spot_light.scale = Vector2(3.6, 2.2)
		_headlamp_spot_light.color = Color(0.95, 0.98, 1.0)
	elif o2_lvl == 2:
		_headlamp_spot_light.energy = 2.0
		_headlamp_spot_light.scale = Vector2(3.2, 1.9)
		_headlamp_spot_light.color = Color(0.92, 0.96, 1.0)
	else:
		_headlamp_spot_light.energy = 1.6
		_headlamp_spot_light.scale = Vector2(2.8, 1.7)
		_headlamp_spot_light.color = Color(0.9, 0.94, 1.0)


## Ensures this CharacterBody2D node has a CollisionShape2D for Area2D detection.
func _ensure_collision_shape() -> void:
	var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if col_shape == null:
		for child in get_children():
			if child is CollisionShape2D:
				col_shape = child as CollisionShape2D
				break

	if col_shape == null:
		col_shape = CollisionShape2D.new()
		col_shape.name = "CollisionShape2D"
		var capsule := CapsuleShape2D.new()
		capsule.radius = 24.0
		capsule.height = 56.0
		col_shape.shape = capsule
		add_child(col_shape)


## Automatically loads and instantiates relic_spawner.gd in the ocean.
func _spawn_relics() -> void:
	if get_tree().get_first_node_in_group("relic_spawner") != null or has_node("RelicSpawner"):
		return

	var spawner_script = load("res://relic_spawner.gd")
	if spawner_script != null:
		var spawner: Node2D = Node2D.new()
		spawner.set_script(spawner_script)
		spawner.name = "RelicSpawner"
		spawner.add_to_group("relic_spawner")

		if get_parent() != null:
			get_parent().call_deferred("add_child", spawner)
		else:
			spawner.top_level = true
			call_deferred("add_child", spawner)


## Dynamically sets up HUD stats, damage flash overlay, and the inventory manifest dialog.
func _setup_dynamic_ui() -> void:
	# -------------------------------------------------------------
	# 1. Foreground HUD CanvasLayer: layer = 1
	# -------------------------------------------------------------
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1

	# On-screen prompt when near water surface
	_surface_prompt_label = Label.new()
	_surface_prompt_label.name = "SurfacePrompt"
	_surface_prompt_label.text = "⚓ Press [F] to Go Ashore (Island Hub)"
	_surface_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_surface_prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_surface_prompt_label.position = Vector2(376.0, 72.0)
	_surface_prompt_label.size = Vector2(400.0, 32.0)
	_surface_prompt_label.add_theme_font_size_override("font_size", 16)
	_surface_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
	_surface_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_surface_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_surface_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_surface_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_surface_prompt_label.add_theme_constant_override("outline_size", 3)
	_surface_prompt_label.visible = false
	hud_layer.add_child(_surface_prompt_label)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.offset_left = 24.0
	margin.offset_top = 24.0

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.14, 0.82)
	style.set_corner_radius_all(6)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.18, 0.42, 0.65, 0.6)
	panel.add_theme_stylebox_override("panel", style)

	_hud_label = Label.new()
	_hud_label.name = "StatsLabel"
	_hud_label.add_theme_font_size_override("font_size", 15)
	_hud_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_hud_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_hud_label.add_theme_constant_override("shadow_offset_x", 1)
	_hud_label.add_theme_constant_override("shadow_offset_y", 1)
	_hud_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_hud_label.add_theme_constant_override("outline_size", 2)

	panel.add_child(_hud_label)
	margin.add_child(panel)
	hud_layer.add_child(margin)
	add_child(hud_layer)

	# -------------------------------------------------------------
	# 2. Red Damage Flash Overlay CanvasLayer: layer = 2
	# -------------------------------------------------------------
	var flash_layer := CanvasLayer.new()
	flash_layer.name = "DamageFlashLayer"
	flash_layer.layer = 2

	_damage_flash_rect = ColorRect.new()
	_damage_flash_rect.name = "RedDamageFlash"
	_damage_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash_rect.color = Color(1.0, 0.0, 0.0, 0.0)
	_damage_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_damage_flash_rect)
	add_child(flash_layer)

	# -------------------------------------------------------------
	# 3. Backpack Inventory Manifest Dialog Layer: layer = 5
	# -------------------------------------------------------------
	_setup_inventory_modal()
	_update_ui()


## Sets up the Backpack Inventory Panel modal overlay.
func _setup_inventory_modal() -> void:
	var inv_layer := CanvasLayer.new()
	inv_layer.name = "InventoryModalLayer"
	inv_layer.layer = 5

	_inventory_modal = Control.new()
	_inventory_modal.name = "InventoryOverlay"
	_inventory_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_modal.visible = false

	var dim := ColorRect.new()
	dim.name = "DimBackdrop"
	dim.color = Color(0.0, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory_modal.add_child(center)

	var panel_container := PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(580.0, 440.0)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.03, 0.08, 0.16, 0.95)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.24, 0.65, 0.92, 0.8)
	p_style.content_margin_left = 22.0
	p_style.content_margin_right = 22.0
	p_style.content_margin_top = 18.0
	p_style.content_margin_bottom = 18.0
	panel_container.add_theme_stylebox_override("panel", p_style)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "HUMAN RELIC SALVAGE MANIFEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	content_vbox.add_child(title)

	_manifest_summary_label = Label.new()
	_manifest_summary_label.text = "Relics: 0  |  Est. Value: 0 cr  |  Cargo: 0.0 / 15.0 kg"
	_manifest_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_manifest_summary_label.add_theme_font_size_override("font_size", 14)
	_manifest_summary_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.96))
	content_vbox.add_child(_manifest_summary_label)

	var sep1 := HSeparator.new()
	content_vbox.add_child(sep1)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(536.0, 260.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_manifest_items_container = VBoxContainer.new()
	_manifest_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_manifest_items_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_manifest_items_container)
	content_vbox.add_child(scroll)

	var sep2 := HSeparator.new()
	content_vbox.add_child(sep2)

	var footer := Label.new()
	footer.text = "[TAB] or [I] Close  |  Click [Drop] or Press [1-9] to Discard Cargo"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9))
	content_vbox.add_child(footer)

	panel_container.add_child(content_vbox)
	center.add_child(panel_container)
	inv_layer.add_child(_inventory_modal)
	add_child(inv_layer)


## Toggles visibility of the Backpack Inventory Panel.
func _toggle_inventory_panel() -> void:
	if _inventory_modal == null:
		return
	_inventory_modal.visible = not _inventory_modal.visible
	if _inventory_modal.visible:
		_populate_inventory_panel()


## Populates the inventory dialog list with relics currently in the backpack.
func _populate_inventory_panel() -> void:
	if _manifest_items_container == null:
		return

	for child in _manifest_items_container.get_children():
		child.queue_free()

	var backpack = _get_backpack()
	var items_list: Array = backpack.items if backpack != null else []
	var total_w: float = float(backpack.current_weight) if backpack != null else 0.0
	var max_w: float = float(backpack.max_weight) if backpack != null else 15.0
	var total_val: int = backpack.get_total_value() if backpack != null else 0

	var encumbered_tag: String = ""
	if backpack != null and backpack.is_encumbered():
		encumbered_tag = " (ENCUMBERED)"

	_manifest_summary_label.text = "Relics: %d  |  Est. Value: %d cr  |  Cargo: %.1f / %.1f kg%s" % [
		items_list.size(), total_val, total_w, max_w, encumbered_tag
	]

	if items_list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "\nNo human relics salvaged yet.\nExplore the depth zones and press [E] near artifacts to recover history."
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85, 0.8))
		_manifest_items_container.add_child(empty_label)
		return

	for i in range(items_list.size()):
		var item: Dictionary = items_list[i]
		var is_id: bool = bool(item.get("identified", true))
		var item_color: Color = item.get("color", Color.CYAN) if is_id else Color(0.72, 0.68, 0.58)

		var item_panel := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.04, 0.11, 0.2, 0.85)
		row_style.set_corner_radius_all(6)
		row_style.content_margin_left = 12.0
		row_style.content_margin_right = 12.0
		row_style.content_margin_top = 8.0
		row_style.content_margin_bottom = 8.0
		row_style.border_width_left = 2
		row_style.border_color = item_color
		item_panel.add_theme_stylebox_override("panel", row_style)

		var row_hbox := HBoxContainer.new()
		row_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

		var item_info_vbox := VBoxContainer.new()
		item_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		var slot_prefix: String = "[%d] " % (i + 1) if (i < 9) else ""
		if is_id:
			name_label.text = "%s%s  •  %.1f kg  •  %d cr" % [
				slot_prefix,
				str(item.get("name", "Unknown Relic")),
				float(item.get("weight", 0.0)),
				int(item.get("value", 0))
			]
		else:
			name_label.text = "%sEncrusted Relic Lump (%.1f kg)  •  ??? cr" % [
				slot_prefix,
				float(item.get("weight", 0.0))
			]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", item_color)
		item_info_vbox.add_child(name_label)

		var desc_label := Label.new()
		if is_id:
			desc_label.text = "\"%s\"" % str(item.get("alien_desc", ""))
		else:
			desc_label.text = "\"[Heavily encrusted in ocean calcification. Clean at Home Lab workbench to reveal.]\""
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92, 0.85))
		item_info_vbox.add_child(desc_label)

		row_hbox.add_child(item_info_vbox)

		var drop_btn := Button.new()
		drop_btn.name = "DropButton_%d" % i
		drop_btn.text = "[Drop]"
		drop_btn.custom_minimum_size = Vector2(72.0, 32.0)
		drop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		drop_btn.add_theme_font_size_override("font_size", 13)
		drop_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		drop_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.25, 0.25))
		drop_btn.pressed.connect(_on_drop_button_pressed.bind(i))
		row_hbox.add_child(drop_btn)

		item_panel.add_child(row_hbox)
		_manifest_items_container.add_child(item_panel)


## Called when the player clicks the [Drop] button on a relic item.
func _on_drop_button_pressed(index: int) -> void:
	var backpack = _get_backpack()
	if backpack != null:
		backpack.remove_item_at(index)


## Called when a relic is dropped from the backpack while in the ocean.
func _on_item_dropped(relic_id: String) -> void:
	var spawner = get_tree().get_first_node_in_group("relic_spawner")
	if spawner != null and spawner.has_method("spawn_single_relic"):
		spawner.spawn_single_relic(relic_id, position + Vector2(0.0, 25.0))


## Called whenever items are added or removed from the backpack.
func _on_backpack_changed() -> void:
	_update_ui()
	if _inventory_modal != null and _inventory_modal.visible:
		_populate_inventory_panel()


## Updates the HUD stats label with current oxygen %, depth (m), historical zone, gold, and cargo weight.
func _update_ui() -> void:
	if _hud_label == null:
		return

	if _surface_prompt_label != null:
		_surface_prompt_label.visible = position.y <= 70.0

	var status_text: String = ""
	if _is_surfaced:
		status_text = " [SURFACED - REFILLING]"
	elif oxygen <= 0.0:
		status_text = " [NO OXYGEN!]"
	elif oxygen <= 25.0:
		status_text = " [LOW OXYGEN]"

	var backpack = _get_backpack()
	var cur_w: float = float(backpack.current_weight) if backpack != null else 0.0
	var max_w: float = float(backpack.max_weight) if backpack != null else 15.0
	var player_gold: int = int(backpack.gold) if backpack != null else 0
	var cur_max_o2: float = float(backpack.max_oxygen) if backpack != null else max_oxygen
	var cargo_status: String = ""

	if backpack != null:
		if cur_w >= max_w:
			cargo_status = " [CARGO FULL!]"
		elif backpack.is_encumbered():
			cargo_status = " [ENCUMBERED]"

	var zone_str: String = ""
	var pressure_note: String = ""
	if depth < 70.0:
		zone_str = "Zone 1: Shallow War Zone"
	elif depth < 150.0:
		zone_str = "Zone 2: Sunken Metropolis"
	else:
		zone_str = "Zone 3: Pre-War Abyss"
		var o2_lvl: int = int(backpack.oxygen_level) if backpack != null else 1
		if o2_lvl < 2:
			pressure_note = " ⚠ HIGH PRESSURE (O2 DRAIN x2!)"
		else:
			pressure_note = " [PRESSURE RESISTANT (L%d)]" % o2_lvl

	var bp_count: int = int(backpack.blueprints) if backpack != null else 0
	var cur_day: int = int(backpack.current_day) if backpack != null else 1

	_hud_label.text = "Day: %d  |  Oxygen: %3.0f / %3.0f%s%s\nDepth:  %5.1f m  (%s)\nGold:   $%d  |  Blueprints: %d\nCargo:  %4.1f / %4.1f kg%s\n[TAB / I] Manifest" % [
		cur_day, oxygen, cur_max_o2, status_text, pressure_note, depth, zone_str, player_gold, bp_count, cur_w, max_w, cargo_status
	]

	if oxygen <= 25.0 and not _is_surfaced:
		_hud_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	elif pressure_note.contains("HIGH PRESSURE") and not _is_surfaced:
		_hud_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
	elif _is_surfaced:
		_hud_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	elif backpack != null and cur_w >= max_w:
		_hud_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	elif backpack != null and backpack.is_encumbered():
		_hud_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	else:
		_hud_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))


func _make_ellipse(rx: float, ry: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs: int = 16
	for i in range(segs):
		var ang: float = (float(i) / float(segs)) * TAU
		pts.append(offset + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


func _get_backpack() -> Node:
	if Engine.has_singleton("Backpack"):
		return Engine.get_singleton("Backpack")
	if get_node_or_null("/root/Backpack") != null:
		return get_node("/root/Backpack")
	return null


## Displays floating cash / status feedback text that drifts up and fades.
func _spawn_floating_cash_text(pos: Vector2, text: String, color: Color = Color(0.4, 1.0, 0.45)) -> void:
	var float_label := Label.new()
	float_label.text = text
	float_label.position = pos
	float_label.add_theme_font_size_override("font_size", 14)
	float_label.add_theme_color_override("font_color", color)
	float_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	float_label.add_theme_constant_override("outline_size", 3)
	if get_parent() != null:
		get_parent().add_child(float_label)
	else:
		add_child(float_label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(float_label, "position:y", pos.y - 35.0, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_label, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(float_label.queue_free)


func _on_oxygen_depleted() -> void:
	_trigger_emergency_drone_rescue()


func _trigger_emergency_drone_rescue() -> void:
	if _is_rescuing:
		return
	_is_rescuing = true
	velocity = Vector2.ZERO

	# 1. Deduct 1 random item from backpack (if any)
	var backpack = _get_backpack()
	var lost_item_name: String = ""
	if backpack != null and not backpack.items.is_empty():
		var lost_idx: int = randi() % backpack.items.size()
		var lost_item: Dictionary = backpack.items[lost_idx]
		lost_item_name = str(lost_item.get("name", "Unknown Relic"))
		backpack.consume_item_at(lost_idx)

	# 2. Refill oxygen
	oxygen = max_oxygen
	if backpack != null:
		backpack.save_game()

	# 3. Create full-screen blackout & rescue UI
	_show_rescue_modal(lost_item_name)


func _show_rescue_modal(lost_item_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "RescueOverlayLayer"
	layer.layer = 100

	_rescue_modal = Control.new()
	_rescue_modal.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rescue_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rescue_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 340.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.03, 0.04, 0.98)
	p_style.set_corner_radius_all(12)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(1.0, 0.3, 0.3, 0.9)
	p_style.content_margin_left = 32.0
	p_style.content_margin_right = 32.0
	p_style.content_margin_top = 28.0
	p_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "🚨 EMERGENCY DRONE RESCUE! 🚨"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Oxygen tank fully depleted!\nThe surface recovery drone detected emergency telemetry\nand deployed a high-speed winch to retrieve your unconscious body."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	vbox.add_child(desc)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var penalty_label := Label.new()
	if lost_item_name != "":
		penalty_label.text = "⚠️ PENALTY: Lost [%s] during the emergency winch ascent!" % lost_item_name
		penalty_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	else:
		penalty_label.text = "✓ No cargo was lost (backpack was empty)."
		penalty_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	penalty_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(penalty_label)

	var o2_status := Label.new()
	o2_status.text = "Oxygen tank refilled to 100%. Returning to island hub..."
	o2_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o2_status.add_theme_font_size_override("font_size", 13)
	o2_status.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(o2_status)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var btn_center := CenterContainer.new()
	var return_btn := Button.new()
	return_btn.text = "🏝️ Wake up on Island Hub (Space / Click)"
	return_btn.custom_minimum_size = Vector2(300.0, 44.0)
	return_btn.add_theme_font_size_override("font_size", 15)
	return_btn.pressed.connect(_on_rescue_return_pressed)
	btn_center.add_child(return_btn)
	vbox.add_child(btn_center)

	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(_rescue_modal)
	add_child(layer)

	# Auto-timeout to transition after 4.5 seconds
	var timer := get_tree().create_timer(4.5)
	timer.timeout.connect(_on_rescue_return_pressed)


func _on_rescue_return_pressed() -> void:
	if not _is_rescuing:
		return
	if get_viewport() != null:
		get_viewport().set_input_as_handled()
	if is_inside_tree():
		get_tree().change_scene_to_file("res://land.tscn")


# ==============================================================================
# Inner class representing a floating naval mine hazard in Zone 1
# ==============================================================================
class NavalMine extends Area2D:
	var base_position: Vector2 = Vector2.ZERO
	var bobbing_seed: float = 0.0
	var diver_ref: Diver
	var has_exploded: bool = false
	var led_polygon: Polygon2D


	func _ready() -> void:
		bobbing_seed = randf() * TAU
		_create_visuals()
		_create_collision()
		body_entered.connect(_on_body_entered)


	func _physics_process(_delta: float) -> void:
		if has_exploded:
			return

		var time_sec: float = Time.get_ticks_msec() / 1000.0
		position.y = base_position.y + sin((time_sec * 2.2) + bobbing_seed) * 5.0

		if led_polygon != null:
			var pulse: float = (sin(time_sec * 6.0) + 1.0) * 0.5
			led_polygon.color = Color(1.0, 0.1, 0.1, lerpf(0.3, 1.0, pulse))

		# Proximity check fallback against diver
		if diver_ref != null and is_instance_valid(diver_ref):
			if global_position.distance_to(diver_ref.global_position) < 32.0:
				_explode()


	func _create_collision() -> void:
		var col := CollisionShape2D.new()
		col.name = "MineCollision"
		var circle := CircleShape2D.new()
		circle.radius = 22.0
		col.shape = circle
		add_child(col)


	func _create_visuals() -> void:
		# Mooring Cable
		var cable := ColorRect.new()
		cable.color = Color(0.25, 0.28, 0.3, 0.7)
		cable.position = Vector2(-1.5, 12.0)
		cable.size = Vector2(3.0, 60.0)
		add_child(cable)

		# 8 Spiked contact detonator horns
		for i in range(8):
			var ang: float = (float(i) / 8.0) * TAU
			var spike := Polygon2D.new()
			var tip: Vector2 = Vector2(cos(ang), sin(ang)) * 28.0
			var b1: Vector2 = Vector2(cos(ang + 0.15), sin(ang + 0.15)) * 16.0
			var b2: Vector2 = Vector2(cos(ang - 0.15), sin(ang - 0.15)) * 16.0
			spike.polygon = PackedVector2Array([tip, b1, b2])
			spike.color = Color(0.18, 0.22, 0.26)
			add_child(spike)

		# Main dark iron mine sphere
		var sphere := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(16):
			var ang: float = (float(i) / 16.0) * TAU
			pts.append(Vector2(cos(ang), sin(ang)) * 18.0)
		sphere.polygon = pts
		sphere.color = Color(0.16, 0.2, 0.24)
		add_child(sphere)

		# Inner rusted rim
		var rim := Polygon2D.new()
		var r_pts := PackedVector2Array()
		for i in range(12):
			var ang: float = (float(i) / 12.0) * TAU
			r_pts.append(Vector2(cos(ang), sin(ang)) * 12.0)
		rim.polygon = r_pts
		rim.color = Color(0.24, 0.28, 0.32)
		add_child(rim)

		# Red flashing detonator LED
		led_polygon = Polygon2D.new()
		var l_pts := PackedVector2Array()
		for i in range(8):
			var ang: float = (float(i) / 8.0) * TAU
			l_pts.append(Vector2(cos(ang), sin(ang)) * 5.0)
		led_polygon.polygon = l_pts
		led_polygon.color = Color(1.0, 0.1, 0.1)
		add_child(led_polygon)


	func _on_body_entered(body: Node2D) -> void:
		if has_exploded:
			return
		if body.is_in_group("diver") or body is Diver or body.name == "Diver":
			_explode()


	func _explode() -> void:
		if has_exploded:
			return
		has_exploded = true

		if diver_ref != null and is_instance_valid(diver_ref):
			diver_ref.trigger_mine_explosion(global_position)

		# Explosion shockwave ring
		var burst := Polygon2D.new()
		var b_pts := PackedVector2Array()
		for i in range(16):
			var ang: float = (float(i) / 16.0) * TAU
			b_pts.append(Vector2(cos(ang), sin(ang)) * 18.0)
		burst.polygon = b_pts
		burst.color = Color(1.0, 0.6, 0.1, 0.85)
		add_child(burst)

		var tween := create_tween().set_parallel(true)
		tween.tween_property(burst, "scale", Vector2(3.5, 3.5), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(burst, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(queue_free)


# ==============================================================================
# Inner class representing a patrolling Pre-War Security Drone hazard (Zone 2 & 3)
# ==============================================================================
class SecurityDrone extends Area2D:
	var patrol_min_x: float = 200.0
	var patrol_max_x: float = 1400.0
	var patrol_speed: float = 110.0
	var direction: float = 1.0
	var base_position_y: float = 0.0
	var diver_ref: Diver
	var body_polygon: Polygon2D
	var sensor_cone: Polygon2D
	var red_eye: Polygon2D
	var hit_cooldown: float = 0.0

	func _ready() -> void:
		base_position_y = position.y
		_create_collision()
		_create_visuals()
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		if hit_cooldown > 0.0:
			hit_cooldown -= delta

		# Horizontal patrol
		position.x += direction * patrol_speed * delta
		if position.x >= patrol_max_x:
			position.x = patrol_max_x
			direction = -1.0
		elif position.x <= patrol_min_x:
			position.x = patrol_min_x
			direction = 1.0

		# Gentle vertical hover bobbing
		var time_sec: float = Time.get_ticks_msec() / 1000.0
		position.y = base_position_y + sin(time_sec * 2.8) * 6.0

		# Flip visually toward patrol direction
		var facing_scale_x: float = 1.0 if direction > 0.0 else -1.0
		scale.x = facing_scale_x

		# Sensor pulse animation
		if sensor_cone != null:
			var pulse: float = 0.18 + (sin(time_sec * 5.5) + 1.0) * 0.12
			sensor_cone.color.a = pulse

		# Distance check against diver
		if diver_ref != null and is_instance_valid(diver_ref) and hit_cooldown <= 0.0:
			var dist: float = global_position.distance_to(diver_ref.global_position)
			if dist < 38.0:
				_trigger_hit()
			elif dist < 170.0:
				var to_diver: Vector2 = (diver_ref.global_position - global_position).normalized()
				var forward: Vector2 = Vector2.RIGHT if direction > 0.0 else Vector2.LEFT
				if forward.dot(to_diver) > 0.6:
					_trigger_hit()

	func _create_collision() -> void:
		var col := CollisionShape2D.new()
		col.name = "DroneCollision"
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		col.shape = circle
		add_child(col)

	func _create_visuals() -> void:
		# 1. Front Red Sensor Cone (Volumetric warning beam)
		sensor_cone = Polygon2D.new()
		sensor_cone.name = "SensorCone"
		sensor_cone.polygon = PackedVector2Array([
			Vector2(12.0, -4.0),
			Vector2(170.0, -45.0),
			Vector2(190.0, 0.0),
			Vector2(170.0, 45.0),
			Vector2(12.0, 4.0)
		])
		sensor_cone.color = Color(1.0, 0.15, 0.15, 0.25)
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sensor_cone.material = add_mat
		add_child(sensor_cone)

		# 2. Mechanical Drone Body
		body_polygon = Polygon2D.new()
		body_polygon.name = "DroneBody"
		body_polygon.polygon = PackedVector2Array([
			Vector2(18.0, 0.0),
			Vector2(6.0, 14.0),
			Vector2(-14.0, 16.0),
			Vector2(-22.0, 6.0),
			Vector2(-22.0, -6.0),
			Vector2(-14.0, -16.0),
			Vector2(6.0, -14.0)
		])
		body_polygon.color = Color(0.18, 0.22, 0.28)
		add_child(body_polygon)

		# 3. Metallic armor plating
		var plating := Polygon2D.new()
		plating.polygon = PackedVector2Array([
			Vector2(10.0, 0.0),
			Vector2(0.0, 9.0),
			Vector2(-12.0, 10.0),
			Vector2(-12.0, -10.0),
			Vector2(0.0, -9.0)
		])
		plating.color = Color(0.32, 0.38, 0.45)
		add_child(plating)

		# 4. Red glowing sensor lens
		red_eye = Polygon2D.new()
		red_eye.name = "SensorEye"
		var pts := PackedVector2Array()
		for i in range(8):
			var ang: float = (float(i) / 8.0) * TAU
			pts.append(Vector2(cos(ang), sin(ang)) * 6.0 + Vector2(10.0, 0.0))
		red_eye.polygon = pts
		red_eye.color = Color(1.0, 0.2, 0.2)
		add_child(red_eye)

	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("diver") or body is Diver or body.name == "Diver":
			_trigger_hit()

	func _trigger_hit() -> void:
		if hit_cooldown > 0.0:
			return
		hit_cooldown = 1.3
		if diver_ref != null and is_instance_valid(diver_ref):
			diver_ref.trigger_drone_hazard(global_position)

