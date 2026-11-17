extends Node

## BackpackManager: Global Autoload Singleton (Backpack)
## Manages salvage inventory, weight limits, human relic database,
## Alien VIP quests, Human Civilization Codex, and Smart Sprite loading.

signal inventory_changed
signal item_added(item: Dictionary)
signal item_removed(item: Dictionary)
signal item_dropped(relic_id: String)
signal vip_quest_updated

## Global persistent stats across scenes
var gold: int = 300
var current_day: int = 1
var daily_museum_earnings: int = 0

## Maps pedestal_index: int -> relic_id: String so museum exhibits persist across scene transitions
var exhibited_relics: Dictionary = {}

## Modular Survivor's Home expansion blueprints count
var blueprints: int = 1
## Tracks unlocked wings/rooms in Survivor's Home
var unlocked_rooms: Dictionary = {
	"main_hall": true,
	"cleaning_lab": true,
	"archive_study": false,
	"bio_recycler": false
}
## Accumulated barnacle crust units from cleaning relics (for Bio-Synthesizer)
var cleaned_crust_units: int = 0

## Discovered relics catalog (maps relic_id: String -> bool: true)
## Unlocked when player cleans encrusted relic in Home Cleaning Lab
var discovered_relics: Dictionary = {}

## Daily Alien VIP request quest dictionary
## Format: { relic_id, relic_name, reward_gold, client_name, dialogue, completed }
var active_vip_quest: Dictionary = {}

## Persistent player upgrade levels & equipment stats
var oxygen_level: int = 1
var max_oxygen: float = 100.0

var fins_level: int = 1
var swim_speed: float = 200.0

var exo_level: int = 1
var max_weight: float = 15.0

const SAVE_FILE_PATH: String = "user://savegame.json"
const RELICS_DATA_PATH: String = "res://relics_data.json"

## Fallback relic dictionary in case JSON is missing or corrupted
var RELIC_DB: Dictionary = {
	"relic_keyboard": {
		"id": "relic_keyboard",
		"name": "Barnacle-Crusted Mechanical Keyboard",
		"weight": 2.5,
		"value": 150,
		"min_depth": 15.0,
		"rarity": "Common",
		"set_name": "21st Century Computing",
		"color": Color.CYAN,
		"color_hex": "#00ffff",
		"icon_path": "res://assets/relics/relic_keyboard.png",
		"alien_desc": "Ancient ritual altar with 104 clickable switches."
	},
	"relic_mouse": {
		"id": "relic_mouse",
		"name": "Optical Gaming Mouse",
		"weight": 0.8,
		"value": 110,
		"min_depth": 25.0,
		"rarity": "Common",
		"set_name": "21st Century Computing",
		"color": Color(0.2, 0.73, 1.0),
		"color_hex": "#33bbff",
		"icon_path": "res://assets/relics/relic_mouse.png",
		"alien_desc": "Handheld tracking rodent with a glowing RGB optical eye."
	},
	"relic_core": {
		"id": "relic_core",
		"name": "Sunken AI Server Core",
		"weight": 6.5,
		"value": 650,
		"min_depth": 160.0,
		"rarity": "Legendary",
		"set_name": "21st Century Computing",
		"color": Color.MAGENTA,
		"color_hex": "#ff00ff",
		"icon_path": "res://assets/relics/relic_core.png",
		"alien_desc": "Heavy silicon monolith containing pre-war digital human consciousness."
	},
	"relic_cup": {
		"id": "relic_cup",
		"name": "Rusty Thermal Mug",
		"weight": 1.2,
		"value": 80,
		"min_depth": 10.0,
		"rarity": "Common",
		"set_name": "Daily Café Life",
		"color": Color.ORANGE,
		"color_hex": "#ff9933",
		"icon_path": "res://assets/relics/relic_cup.png",
		"alien_desc": "Insulated vessel once used to hold dark caffeinated morning stimulant."
	},
	"relic_toaster": {
		"id": "relic_toaster",
		"name": "Chrome Bread Warmer",
		"weight": 3.2,
		"value": 240,
		"min_depth": 85.0,
		"rarity": "Rare",
		"set_name": "Daily Café Life",
		"color": Color(1.0, 0.84, 0.0),
		"color_hex": "#ffd700",
		"icon_path": "res://assets/relics/relic_toaster.png",
		"alien_desc": "Dual-slot thermal catapult designed to scorch carbohydrate slices."
	},
	"relic_console": {
		"id": "relic_console",
		"name": "Ancient Handheld Console",
		"weight": 1.8,
		"value": 380,
		"min_depth": 110.0,
		"rarity": "Rare",
		"set_name": "Daily Café Life",
		"color": Color(1.0, 0.33, 0.53),
		"color_hex": "#ff5588",
		"icon_path": "res://assets/relics/relic_console.png",
		"alien_desc": "Portable silicon entertainment brick with directional cross pad."
	},
	"relic_dogtag": {
		"id": "relic_dogtag",
		"name": "Tarnished Titanium Dogtags",
		"weight": 0.4,
		"value": 190,
		"min_depth": 45.0,
		"rarity": "Common",
		"set_name": "Resource War Remnants",
		"color": Color(0.75, 0.75, 0.75),
		"color_hex": "#c0c0c0",
		"icon_path": "res://assets/relics/relic_dogtag.png",
		"alien_desc": "Stamped metal identity plates of pre-war oceanic combat personnel."
	},
	"relic_mask": {
		"id": "relic_mask",
		"name": "Cracked Gas Mask",
		"weight": 3.0,
		"value": 280,
		"min_depth": 95.0,
		"rarity": "Rare",
		"set_name": "Resource War Remnants",
		"color": Color.GREEN_YELLOW,
		"color_hex": "#adff2f",
		"icon_path": "res://assets/relics/relic_mask.png",
		"alien_desc": "Late-war synthetic breathing apparatus with cracked reinforced lenses."
	},
	"blueprint_tube": {
		"id": "blueprint_tube",
		"name": "Pre-War Architectural Blueprint",
		"weight": 0.5,
		"value": 200,
		"min_depth": 40.0,
		"rarity": "Rare",
		"set_name": "Survivor Technology",
		"color": Color.DEEP_SKY_BLUE,
		"color_hex": "#00bfff",
		"icon_path": "res://assets/relics/relic_blueprint.png",
		"alien_desc": "Hermetically sealed alloy canister holding modular human hab schematics."
	}
}

## List of collected relic instances currently in the backpack
var items: Array[Dictionary] = []

## Current cumulative cargo weight in kilograms
var current_weight: float = 0.0

## Global Codex UI CanvasLayer instance
var _codex_layer: CanvasLayer = null
var _codex_modal: Control = null
var _codex_scroll: ScrollContainer = null
var _codex_content_vbox: VBoxContainer = null

## Zero-Dependency Procedural Retro Audio Synthesizer (AudioStreamGenerator)
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_generators: Array[AudioStreamGenerator] = []
var _sfx_pool_index: int = 0
var _sfx_cache: Dictionary = {}


func _ready() -> void:
	_init_sfx()
	_load_relics_from_json()
	load_game()
	if active_vip_quest.is_empty():
		generate_daily_vip_quest()


## Initializes a pool of 4 AudioStreamPlayers with AudioStreamGenerators for zero-latency procedural SFX.
func _init_sfx() -> void:
	if not _sfx_players.is_empty():
		return
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.name = "ProceduralSFXPlayer_%d" % i
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.6
		p.stream = gen
		add_child(p)
		_sfx_players.append(p)
		_sfx_generators.append(gen)


## Plays a zero-asset procedural retro sound effect synthesized in real-time.
## Supported types: "pickup", "sonar", "laser_clean", "cash", "hit"
func play_sfx(sfx_type: String) -> void:
	if not is_inside_tree():
		return
	_init_sfx()
	if _sfx_players.is_empty():
		return

	var frames: PackedVector2Array
	if _sfx_cache.has(sfx_type):
		frames = _sfx_cache[sfx_type]
	else:
		frames = _synthesize_sfx(sfx_type)
		_sfx_cache[sfx_type] = frames

	if frames.is_empty():
		return

	var player = _sfx_players[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _sfx_players.size()
	if player.is_inside_tree():
		player.play()
		var pb = player.get_stream_playback() as AudioStreamGeneratorPlayback
		if pb != null:
			pb.push_buffer(frames)


## Synthesizes short retro waveforms (sine, square, frequency chirps, and noise bursts).
func _synthesize_sfx(sfx_type: String) -> PackedVector2Array:
	var mix_rate: float = 22050.0
	var frames := PackedVector2Array()

	match sfx_type:
		"pickup":
			# Rising two-tone chime (D5 587.3Hz -> A5 880.0Hz)
			var n1_dur: float = 0.08
			var n2_dur: float = 0.16
			var n1_samples: int = int(n1_dur * mix_rate)
			var n2_samples: int = int(n2_dur * mix_rate)

			var f1: float = 587.33
			for i in range(n1_samples):
				var t: float = float(i) / mix_rate
				var env: float = clampf(t / 0.008, 0.0, 1.0) * (1.0 - (float(i) / float(n1_samples)) * 0.25)
				var val: float = (sin(t * f1 * TAU) * 0.5 + sin(t * f1 * 2.0 * TAU) * 0.15) * env
				frames.append(Vector2(val, val))

			var f2: float = 880.0
			for i in range(n2_samples):
				var t: float = float(i) / mix_rate
				var env: float = exp(-t * 12.0)
				var val: float = (sin(t * f2 * TAU) * 0.5 + sin(t * f2 * 2.0 * TAU) * 0.15) * env
				frames.append(Vector2(val, val))

		"sonar":
			# High-pitched submarine ping with echo decay
			var dur: float = 0.44
			var total_samples: int = int(dur * mix_rate)
			var f_ping: float = 1200.0

			for i in range(total_samples):
				var t: float = float(i) / mix_rate
				var val: float = 0.0

				# Main ping (t = 0 to 0.16)
				if t < 0.16:
					var p_t: float = t
					var env1: float = clampf(p_t / 0.004, 0.0, 1.0) * exp(-p_t * 14.0)
					val += sin(p_t * f_ping * TAU) * 0.55 * env1

				# Echo 1 (t = 0.16 to 0.30)
				if t >= 0.16 and t < 0.30:
					var p_t: float = t - 0.16
					var env2: float = clampf(p_t / 0.005, 0.0, 1.0) * exp(-p_t * 16.0)
					val += sin(p_t * (f_ping * 0.94) * TAU) * 0.22 * env2

				# Echo 2 (t = 0.30 to 0.44)
				if t >= 0.30:
					var p_t: float = t - 0.30
					var env3: float = clampf(p_t / 0.005, 0.0, 1.0) * exp(-p_t * 18.0)
					val += sin(p_t * (f_ping * 0.88) * TAU) * 0.10 * env3

				frames.append(Vector2(val, val))

		"laser_clean":
			# Short crisp zapping/chipping sound (2200Hz -> 280Hz chirp + crunchy noise)
			var dur: float = 0.08
			var total_samples: int = int(dur * mix_rate)
			var phase: float = 0.0

			for i in range(total_samples):
				var t: float = float(i) / mix_rate
				var prog: float = float(i) / float(total_samples)
				var cur_f: float = lerpf(2200.0, 280.0, prog)
				phase += (cur_f / mix_rate) * TAU

				var env: float = clampf(t / 0.004, 0.0, 1.0) * (1.0 - prog)
				var chirp: float = sin(phase) * 0.42
				var noise: float = randf_range(-0.18, 0.18) * exp(-prog * 4.0)
				var val: float = (chirp + noise) * env
				frames.append(Vector2(val, val))

		"cash":
			# Bright coin register arpeggio (B5 987Hz -> E6 1318Hz -> A6 1760Hz)
			var notes: Array[float] = [987.77, 1318.51, 1760.00]
			var note_durs: Array[float] = [0.055, 0.055, 0.16]

			for n in range(notes.size()):
				var f_note: float = notes[n]
				var n_dur: float = note_durs[n]
				var n_samples: int = int(n_dur * mix_rate)
				for i in range(n_samples):
					var t: float = float(i) / mix_rate
					var env: float = clampf(t / 0.005, 0.0, 1.0) * exp(-t * (10.0 if n == 2 else 16.0))
					var s: float = sin(t * f_note * TAU)
					var tri: float = asin(clampf(s, -1.0, 1.0)) * (2.0 / PI)
					var val: float = (s * 0.6 + tri * 0.4) * 0.45 * env
					frames.append(Vector2(val, val))

		"hit":
			# Low rumble buzzer when hitting underwater hazard (85Hz drop + noise)
			var dur: float = 0.24
			var total_samples: int = int(dur * mix_rate)
			var phase: float = 0.0

			for i in range(total_samples):
				var t: float = float(i) / mix_rate
				var prog: float = float(i) / float(total_samples)
				var cur_f: float = lerpf(90.0, 48.0, prog)
				phase += (cur_f / mix_rate) * TAU

				var env: float = clampf(t / 0.008, 0.0, 1.0) * exp(-prog * 4.5)
				var buzz: float = signf(sin(phase)) * 0.35
				var rumble: float = randf_range(-0.25, 0.25) * (1.0 - prog)
				var val: float = (buzz + rumble) * 0.55 * env
				frames.append(Vector2(val, val))

	return frames


## Loads data-driven relics definitions from res://relics_data.json
func _load_relics_from_json() -> void:
	if not FileAccess.file_exists(RELICS_DATA_PATH):
		return

	var file := FileAccess.open(RELICS_DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var text_content: String = file.get_as_text()
	file.close()

	if text_content.strip_edges().is_empty():
		return

	var parsed = JSON.parse_string(text_content)
	if parsed is Dictionary:
		for k in parsed.keys():
			var r_data: Dictionary = parsed[k]
			# Ensure color property exists from color_hex
			if r_data.has("color_hex"):
				r_data["color"] = Color.from_string(str(r_data["color_hex"]), Color.WHITE)
			elif not r_data.has("color"):
				r_data["color"] = Color.WHITE
			RELIC_DB[str(k)] = r_data


# ==============================================================================
# Smart Sprite Auto-Loader Pipeline (Direction 4)
# ==============================================================================

## Animated Smart Sprite that automatically cycles horizontal animation sheets
class SmartAnimatedSprite extends Sprite2D:
	var frame_speed: float = 8.0 # frames per second
	var _anim_timer: float = 0.0

	func _process(delta: float) -> void:
		if hframes > 1 and is_visible_in_tree():
			_anim_timer += delta
			var interval: float = 1.0 / maxf(frame_speed, 1.0)
			if _anim_timer >= interval:
				_anim_timer = 0.0
				frame = (frame + 1) % hframes


## Dynamically loads a PNG texture if it exists on disk, centers & scales it to target_node,
## auto-detects horizontal animation strips (width >= height * 2), sets NEAREST filter,
## and hides procedural placeholder geometry (Polygon2D, ColorRect, Line2D).
static func load_smart_sprite(target_node: Node2D, path: String, target_size: Vector2 = Vector2.ZERO, pivot_offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	if target_node == null or path.is_empty():
		return null

	if not ResourceLoader.exists(path):
		return null

	var tex := load(path) as Texture2D
	if tex == null:
		return null

	# Check if target_node already has a SmartSprite child
	var sprite: SmartAnimatedSprite = target_node.get_node_or_null("SmartSprite") as SmartAnimatedSprite
	if sprite == null:
		sprite = SmartAnimatedSprite.new()
		sprite.name = "SmartSprite"
		target_node.add_child(sprite)

	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = pivot_offset

	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var h_frames: int = 1
	if th > 0.0 and tw >= th * 2.0:
		h_frames = int(tw / th)
		sprite.hframes = h_frames
		sprite.frame = 0
	else:
		sprite.hframes = 1
		sprite.frame = 0

	var frame_w: float = tw / float(h_frames)
	var frame_h: float = th
	if target_size != Vector2.ZERO and frame_w > 0.0 and frame_h > 0.0:
		sprite.scale = Vector2(target_size.x / frame_w, target_size.y / frame_h)
	else:
		sprite.scale = Vector2.ONE

	# Automatically hide procedural placeholder sibling geometry
	for child in target_node.get_children():
		if child == sprite:
			continue
		if child is Polygon2D or child is ColorRect or child is Line2D:
			child.visible = false

	return sprite


## Universal floating cash / status feedback label that drifts upward and fades out.
func spawn_floating_text(parent_node: Node, pos: Vector2, text: String, color: Color = Color(0.4, 1.0, 0.45)) -> void:
	if parent_node == null or not is_inside_tree():
		return
	var float_label := Label.new()
	float_label.text = text
	float_label.position = pos
	float_label.add_theme_font_size_override("font_size", 14)
	float_label.add_theme_color_override("font_color", color)
	float_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	float_label.add_theme_constant_override("outline_size", 3)
	parent_node.add_child(float_label)

	var tween := parent_node.create_tween().set_parallel(true)
	tween.tween_property(float_label, "position:y", pos.y - 35.0, 1.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(float_label, "modulate:a", 0.0, 1.1).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(float_label.queue_free)


func _spawn_floating_cash_text(pos: Vector2, text: String, color: Color = Color(0.4, 1.0, 0.45)) -> void:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		spawn_floating_text(tree.current_scene, pos, text, color)


# ==============================================================================
# Consistent Player Character & Modular "Paper-Doll" Equipment Visual System
# ==============================================================================

## Builds or updates a consistent player character with modular equipment paper-doll layers.
## Supports both swimming (horizontal side-scroller) and upright (2.5D top-down) stances.
func build_character_visuals(target_node: Node2D, is_swimming_mode: bool = false, use_custom_sprite: bool = true) -> Node2D:
	if target_node == null:
		return null

	# Remove any existing CharacterVisuals child to perform a clean build
	var existing = target_node.get_node_or_null("CharacterVisuals")
	if existing != null:
		existing.queue_free()

	# Hide legacy placeholder Sprite2D nodes on target_node
	var old_sprite = target_node.get_node_or_null("Sprite2D")
	if old_sprite != null:
		old_sprite.visible = false

	var vis := PlayerVisuals.new()
	vis.name = "CharacterVisuals"
	vis.bp_ref = self
	vis.is_swimming = is_swimming_mode
	vis.use_custom_sprite = use_custom_sprite

	target_node.add_child(vis)
	return vis


# ==============================================================================
# VisualRig & CharacterAnimator: Modular Articulated Character System
# ==============================================================================

class CharacterAnimator extends Node:
	var rig: Node2D = null

	func _init(p_rig: Node2D = null) -> void:
		rig = p_rig


class VisualRig extends Node2D:
	var bp_ref: Node = null
	var is_swimming: bool = false
	var use_custom_sprite: bool = true
	var has_custom_sprite: bool = false

	# Articulated Child Pivots
	var body_pivot: Node2D
	var head_mask_pivot: Node2D
	var back_tank_pivot: Node2D
	var fins_pivot: Node2D
	var exo_frame_pivot: Node2D
	var ground_shadow: Polygon2D
	var animator: CharacterAnimator

	# Compatibility Slot Aliases
	var body_container: Node2D
	var tank_slot: Node2D
	var mask_slot: Node2D
	var fins_slot: Node2D
	var exo_slot: Node2D

	enum Facing { DOWN, UP, LEFT, RIGHT }
	var current_facing: Facing = Facing.DOWN
	var anim_time: float = 0.0
	var walk_time: float = 0.0
	var bubble_timer: float = 0.0
	var hydrojet_timer: float = 0.0
	var dust_timer: float = 0.0
	var aim_target: Vector2 = Vector2.ZERO

	const COLOR_SUIT: Color = Color("#E5A93B") # Signature mustard-yellow hazmat
	const COLOR_SUIT_SHADOW: Color = Color("#B87E1E") # Darker seam/shading
	const COLOR_SUIT_HIGHLIGHT: Color = Color("#F5C35D") # Bright highlight
	const COLOR_PADS: Color = Color("#2C3539") # Dark slate pads/knees/boots/gloves
	const COLOR_PADS_LIGHT: Color = Color("#3F494E")
	const COLOR_STRAPS: Color = Color("#181D1F") # Black rubber seals & harness
	const COLOR_BUCKLE: Color = Color("#D0D8E0") # Silver alloy buckles
	const COLOR_SKIN: Color = Color("#F5C396") # Warm face skin

	func _ready() -> void:
		_setup_layers()
		update_gear_visuals()

		if bp_ref != null and bp_ref.has_signal("inventory_changed"):
			bp_ref.inventory_changed.connect(update_gear_visuals)

		tree_exiting.connect(func():
			if bp_ref != null and is_instance_valid(bp_ref) and bp_ref.inventory_changed.is_connected(update_gear_visuals):
				bp_ref.inventory_changed.disconnect(update_gear_visuals)
		)

	func _setup_layers() -> void:
		animator = CharacterAnimator.new(self)
		animator.name = "CharacterAnimator"
		add_child(animator)

		if not is_swimming:
			var existing_shadow = null
			if get_parent() != null:
				for c in get_parent().get_children():
					if c is Polygon2D and (c.name.to_lower().contains("shadow") or c.name == "GroundShadow"):
						existing_shadow = c
						break
			if existing_shadow == null:
				ground_shadow = Polygon2D.new()
				ground_shadow.name = "GroundShadow"
				ground_shadow.polygon = _make_ellipse(15.0, 6.0, Vector2(0.0, 0.0))
				ground_shadow.color = Color(0.0, 0.0, 0.0, 0.38)
				add_child(ground_shadow)

		fins_pivot = Node2D.new()
		fins_pivot.name = "FinsPivot"
		if is_swimming:
			fins_pivot.position = Vector2(-20.0, 3.0) # Ankle pivot
		add_child(fins_pivot)
		fins_slot = fins_pivot

		back_tank_pivot = Node2D.new()
		back_tank_pivot.name = "BackTankPivot"
		if is_swimming:
			back_tank_pivot.position = Vector2(-2.0, -9.0)
		else:
			back_tank_pivot.position = Vector2(0.0, -28.0)
		add_child(back_tank_pivot)
		tank_slot = back_tank_pivot

		body_pivot = Node2D.new()
		body_pivot.name = "BodyPivot"
		add_child(body_pivot)
		body_container = body_pivot

		exo_frame_pivot = Node2D.new()
		exo_frame_pivot.name = "ExoFramePivot"
		if is_swimming:
			exo_frame_pivot.position = Vector2(-1.0, 0.0)
		else:
			exo_frame_pivot.position = Vector2(0.0, -24.0)
		add_child(exo_frame_pivot)
		exo_slot = exo_frame_pivot

		head_mask_pivot = Node2D.new()
		head_mask_pivot.name = "HeadMaskPivot"
		if is_swimming:
			head_mask_pivot.position = Vector2(18.0, -2.0)
		else:
			head_mask_pivot.position = Vector2(0.0, -40.0)
		add_child(head_mask_pivot)
		mask_slot = head_mask_pivot

		_build_base_body()

	func set_aim_target(target_pos: Vector2) -> void:
		aim_target = target_pos

	func _process(delta: float) -> void:
		var parent_body := get_parent() as CharacterBody2D
		var vel: Vector2 = parent_body.velocity if parent_body != null else Vector2.ZERO

		if is_swimming:
			_process_swimming_animation(vel, delta)
		else:
			_process_walking_animation(vel, delta)

	func _process_swimming_animation(vel: Vector2, delta: float) -> void:
		var spd: float = vel.length()
		anim_time += delta * (1.0 + (spd / 200.0) * 2.0)

		# Horizontal orientation & smooth flipping
		if vel.x > 8.0:
			scale.x = move_toward(scale.x, 1.0, delta * 12.0)
		elif vel.x < -8.0:
			scale.x = move_toward(scale.x, -1.0, delta * 12.0)

		var facing_sign: float = 1.0 if scale.x >= 0.0 else -1.0

		if spd < 10.0:
			# Idle Treading Water: gentle vertical sine-wave bobbing & pitch oscillation
			body_pivot.position.y = sin(anim_time * 2.5) * 4.0
			body_pivot.rotation = lerp_angle(body_pivot.rotation, sin(anim_time * 1.8) * 0.05, delta * 6.0)
			body_pivot.scale = body_pivot.scale.lerp(Vector2.ONE, delta * 8.0)
			fins_pivot.rotation = sin(anim_time * 3.0) * 0.2
		else:
			# Active Swimming: tilts into movement vector (±25° / ±0.436 rad), speed-scaled wave, axial stretch
			var pitch_angle: float = clampf(vel.normalized().y * 0.436 * facing_sign, -0.436, 0.436)
			body_pivot.rotation = lerp_angle(body_pivot.rotation, pitch_angle, delta * 8.0)
			body_pivot.position.y = sin(anim_time * (2.5 + (spd / 200.0) * 6.0)) * 2.5

			var stretch: float = 1.0 + clampf(spd / 600.0, 0.0, 0.12)
			var squash: float = 1.0 - clampf(spd / 1200.0, 0.0, 0.06)
			body_pivot.scale = body_pivot.scale.lerp(Vector2(stretch, squash), delta * 8.0)

			var kick_speed: float = 3.0 + (spd / 200.0) * 11.0
			fins_pivot.rotation = sin(anim_time * kick_speed) * 0.35

			var f_lvl: int = int(bp_ref.get("fins_level")) if (bp_ref != null and bp_ref.get("fins_level") != null) else 1
			if f_lvl >= 3:
				hydrojet_timer += delta
				if hydrojet_timer >= 0.07:
					hydrojet_timer = 0.0
					_spawn_hydrojet_thrust(vel)

		# Oxygen Tank bubble particles
		bubble_timer += delta
		var b_interval: float = 2.0 if spd < 15.0 else 1.2
		if bubble_timer >= b_interval:
			bubble_timer = 0.0
			_spawn_tank_bubble()

		# Mask & headlamp cone aim tracking
		var target_aim_angle: float = 0.0
		if aim_target != Vector2.ZERO:
			var diff := aim_target - head_mask_pivot.global_position
			target_aim_angle = diff.angle()
			if scale.x < 0.0:
				target_aim_angle = PI - target_aim_angle
		elif spd > 15.0:
			target_aim_angle = clampf(vel.normalized().y * 0.5 * facing_sign, -0.55, 0.55)
		head_mask_pivot.rotation = lerp_angle(head_mask_pivot.rotation, target_aim_angle, delta * 8.0)

	func _process_walking_animation(vel: Vector2, delta: float) -> void:
		var spd: float = vel.length()

		if spd > 5.0:
			if absf(vel.y) > absf(vel.x) * 1.1:
				current_facing = Facing.UP if vel.y < 0.0 else Facing.DOWN
			else:
				current_facing = Facing.LEFT if vel.x < 0.0 else Facing.RIGHT

			_update_perspective_for_facing()

			walk_time += delta
			body_pivot.position.y = -absf(sin(walk_time * 14.0)) * 5.0
			body_pivot.rotation = sin(walk_time * 14.0) * 0.12
			body_pivot.scale.y = 1.0 + sin(walk_time * 14.0) * 0.08
			body_pivot.scale.x = 1.0 - sin(walk_time * 14.0) * 0.05

			dust_timer += delta
			if dust_timer >= 0.22:
				dust_timer = 0.0
				_spawn_footstep_dust()
		else:
			body_pivot.position.y = lerpf(body_pivot.position.y, 0.0, delta * 12.0)
			body_pivot.rotation = lerp_angle(body_pivot.rotation, 0.0, delta * 12.0)
			body_pivot.scale = body_pivot.scale.lerp(Vector2.ONE, delta * 12.0)

	func _update_perspective_for_facing() -> void:
		if is_swimming:
			return

		var exo_lvl: int = int(bp_ref.get("exo_level")) if (bp_ref != null and bp_ref.get("exo_level") != null) else 1

		if current_facing == Facing.UP:
			scale.x = 1.0
			exo_frame_pivot.z_index = 2
			exo_frame_pivot.position = Vector2(0.0, -25.0)
			back_tank_pivot.z_index = 1
			back_tank_pivot.position = Vector2(0.0, -28.0)
			head_mask_pivot.visible = false
			body_pivot.z_index = 0
			_check_view_specific_gear("back", exo_lvl)

		elif current_facing == Facing.DOWN:
			scale.x = 1.0
			exo_frame_pivot.z_index = -1
			exo_frame_pivot.position = Vector2(0.0, -25.0)
			back_tank_pivot.z_index = -2
			back_tank_pivot.position = Vector2(0.0, -28.0)
			head_mask_pivot.z_index = 2
			head_mask_pivot.visible = true
			head_mask_pivot.position = Vector2(0.0, -40.0)
			body_pivot.z_index = 0
			_check_view_specific_gear("front", exo_lvl)

		elif current_facing == Facing.LEFT or current_facing == Facing.RIGHT:
			scale.x = -1.0 if current_facing == Facing.LEFT else 1.0
			exo_frame_pivot.z_index = 1
			exo_frame_pivot.position = Vector2(-2.0, -22.0)
			back_tank_pivot.z_index = -1
			back_tank_pivot.position = Vector2(-7.0, -25.0)
			head_mask_pivot.z_index = 2
			head_mask_pivot.visible = true
			head_mask_pivot.position = Vector2(3.0, -40.0)
			body_pivot.z_index = 0
			_check_view_specific_gear("side", exo_lvl)

	func _check_view_specific_gear(view_suffix: String, exo_lvl: int) -> void:
		var custom_exo := "res://assets/gear/exo_lv%d_%s.png" % [exo_lvl, view_suffix]
		if ResourceLoader.exists(custom_exo):
			var spr = exo_frame_pivot.get_node_or_null("SmartSprite") as Sprite2D
			if spr == null or spr.texture.resource_path != custom_exo:
				_clear_slot(exo_frame_pivot)
				if bp_ref != null and bp_ref.has_method("load_smart_sprite"):
					bp_ref.load_smart_sprite(exo_frame_pivot, custom_exo, Vector2(30.0, 26.0))

	func _spawn_tank_bubble() -> void:
		var world = get_parent()
		if world == null or not is_inside_tree():
			return
		var spawn_pos: Vector2 = back_tank_pivot.global_position + Vector2(randf_range(-4.0, 4.0), -8.0)
		var bubble := Polygon2D.new()
		bubble.polygon = _make_ellipse(2.5, 2.5)
		bubble.color = Color(0.8, 0.95, 1.0, 0.6)

		var spec := Polygon2D.new()
		spec.polygon = _make_ellipse(0.8, 0.8, Vector2(0.8, -0.8))
		spec.color = Color(1.0, 1.0, 1.0, 0.9)
		bubble.add_child(spec)

		bubble.global_position = spawn_pos
		world.add_child(bubble)

		var tween := bubble.create_tween().set_parallel(true)
		var rise_y: float = spawn_pos.y - randf_range(35.0, 60.0)
		var drift_x: float = spawn_pos.x + randf_range(-8.0, 8.0)
		tween.tween_property(bubble, "global_position:y", rise_y, 1.2).set_ease(Tween.EASE_OUT)
		tween.tween_property(bubble, "global_position:x", drift_x, 1.2).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(bubble, "scale", Vector2(1.3, 1.3), 1.2)
		tween.tween_property(bubble, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(bubble.queue_free)

	func _spawn_hydrojet_thrust(vel: Vector2) -> void:
		var world = get_parent()
		if world == null or not is_inside_tree():
			return
		var dir := -vel.normalized() if vel.length() > 0.0 else Vector2(-1.0, 0.0)
		var spawn_pos: Vector2 = fins_pivot.global_position + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))

		var jet := Polygon2D.new()
		jet.polygon = _make_ellipse(2.2, 2.2)
		jet.color = Color(0.0, 1.0, 1.0, 0.85)
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		jet.material = add_mat
		jet.global_position = spawn_pos
		world.add_child(jet)

		var tween := jet.create_tween().set_parallel(true)
		tween.tween_property(jet, "global_position", spawn_pos + (dir * randf_range(12.0, 24.0)), 0.22)
		tween.tween_property(jet, "scale", Vector2(0.2, 0.2), 0.22)
		tween.tween_property(jet, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(jet.queue_free)

	func _spawn_footstep_dust() -> void:
		var world = get_parent()
		if world == null or not is_inside_tree():
			return
		var dust := Polygon2D.new()
		dust.polygon = _make_ellipse(3.0, 1.8)
		dust.color = Color(0.82, 0.78, 0.70, 0.45)
		dust.global_position = global_position + Vector2(randf_range(-4.0, 4.0), randf_range(-1.0, 2.0))
		world.add_child(dust)

		var tween := dust.create_tween().set_parallel(true)
		tween.tween_property(dust, "scale", Vector2(2.2, 1.4), 0.32).set_ease(Tween.EASE_OUT)
		tween.tween_property(dust, "modulate:a", 0.0, 0.32).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(dust.queue_free)

	func _build_base_body() -> void:
		var char_tex_path: String = "res://assets/characters/diver.png" if is_swimming else "res://assets/characters/survivor.png"
		var exists: bool = ResourceLoader.exists(char_tex_path) or FileAccess.file_exists(char_tex_path)
		if exists:
			var tex := load(char_tex_path) as Texture2D
			if tex != null:
				var spr := Sprite2D.new()
				spr.name = "CharacterSprite"
				spr.texture = tex
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

				var max_dim: float = 72.0 if is_swimming else 64.0
				var tex_w: float = float(tex.get_width())
				var tex_h: float = float(tex.get_height())
				var tex_max: float = maxf(tex_w, tex_h)
				var scale_factor: float = max_dim / maxf(tex_max, 1.0)
				spr.scale = Vector2(scale_factor, scale_factor)

				if is_swimming:
					spr.position = Vector2.ZERO
				else:
					spr.position = Vector2(0.0, -max_dim * 0.5)

				body_pivot.add_child(spr)
				has_custom_sprite = true
				print("Loaded custom character sprite: " + char_tex_path)
				return

		# Fallback: Procedural Mustard-Yellow Hazmat Suit & Slate Pads
		has_custom_sprite = false
		if is_swimming:
			_build_swimming_body()
		else:
			_build_upright_body()

	func _build_swimming_body() -> void:
		# Centered at (0, 0), horizontal swimmer facing right (x+ forward, y- dorsal/up)
		# 1. Legs kicking backward
		var upper_leg := Polygon2D.new()
		upper_leg.polygon = PackedVector2Array([
			Vector2(-7.0, -4.0), Vector2(-1.0, -3.0),
			Vector2(-3.0, 4.0), Vector2(-9.0, 3.0)
		])
		upper_leg.color = COLOR_SUIT
		body_container.add_child(upper_leg)

		var knee_pad := Polygon2D.new()
		knee_pad.polygon = PackedVector2Array([
			Vector2(-9.0, -2.0), Vector2(-13.0, -2.0),
			Vector2(-13.0, 3.0), Vector2(-9.0, 3.0)
		])
		knee_pad.color = COLOR_PADS
		body_container.add_child(knee_pad)

		var lower_leg := Polygon2D.new()
		lower_leg.polygon = PackedVector2Array([
			Vector2(-13.0, -1.0), Vector2(-22.0, 0.0),
			Vector2(-22.0, 5.0), Vector2(-13.0, 4.0)
		])
		lower_leg.color = COLOR_SUIT
		body_container.add_child(lower_leg)

		var boot := Polygon2D.new()
		boot.polygon = PackedVector2Array([
			Vector2(-20.0, 0.0), Vector2(-25.0, 0.0),
			Vector2(-25.0, 5.0), Vector2(-20.0, 5.0)
		])
		boot.color = COLOR_PADS
		body_container.add_child(boot)

		# 2. Torso (Mustard-yellow suit)
		var torso := Polygon2D.new()
		torso.polygon = PackedVector2Array([
			Vector2(-12.0, -7.0), Vector2(12.0, -7.0),
			Vector2(10.0, 7.0), Vector2(-10.0, 7.0)
		])
		torso.color = COLOR_SUIT
		body_container.add_child(torso)

		# Torso shadow seam
		var torso_shadow := Polygon2D.new()
		torso_shadow.polygon = PackedVector2Array([
			Vector2(-10.0, 2.0), Vector2(10.0, 2.0),
			Vector2(10.0, 7.0), Vector2(-10.0, 7.0)
		])
		torso_shadow.color = COLOR_SUIT_SHADOW
		body_container.add_child(torso_shadow)

		# Slate belt trim
		var belt := Polygon2D.new()
		belt.polygon = PackedVector2Array([
			Vector2(-11.0, 5.0), Vector2(10.0, 5.0),
			Vector2(9.0, 7.0), Vector2(-10.0, 7.0)
		])
		belt.color = COLOR_PADS
		body_container.add_child(belt)

		# Chest harness webbing (dark straps & buckles)
		var strap_v := Polygon2D.new()
		strap_v.polygon = PackedVector2Array([
			Vector2(-3.0, -7.0), Vector2(1.0, -7.0),
			Vector2(1.0, 7.0), Vector2(-3.0, 7.0)
		])
		strap_v.color = COLOR_STRAPS
		body_container.add_child(strap_v)

		var buckle := Polygon2D.new()
		buckle.polygon = PackedVector2Array([
			Vector2(-4.0, -2.0), Vector2(2.0, -2.0),
			Vector2(2.0, 2.0), Vector2(-4.0, 2.0)
		])
		buckle.color = COLOR_BUCKLE
		body_container.add_child(buckle)

		# 3. Arm extending forward in swimming stroke
		var arm := Polygon2D.new()
		arm.polygon = PackedVector2Array([
			Vector2(4.0, 0.0), Vector2(12.0, 1.0),
			Vector2(11.0, 6.0), Vector2(3.0, 5.0)
		])
		arm.color = COLOR_SUIT
		body_container.add_child(arm)

		var elbow_pad := Polygon2D.new()
		elbow_pad.polygon = PackedVector2Array([
			Vector2(11.0, 1.0), Vector2(15.0, 2.0),
			Vector2(14.0, 7.0), Vector2(10.0, 6.0)
		])
		elbow_pad.color = COLOR_PADS
		body_container.add_child(elbow_pad)

		var glove := Polygon2D.new()
		glove.polygon = PackedVector2Array([
			Vector2(14.0, 2.0), Vector2(21.0, 4.0),
			Vector2(20.0, 8.0), Vector2(13.0, 7.0)
		])
		glove.color = COLOR_PADS
		body_container.add_child(glove)

		# 4. Head & Hood
		var hood := Polygon2D.new()
		hood.polygon = _make_ellipse(8.0, 7.0, Vector2(16.0, -2.0))
		hood.color = COLOR_SUIT
		body_container.add_child(hood)

		var neck_seal := Polygon2D.new()
		neck_seal.polygon = PackedVector2Array([
			Vector2(11.0, -6.0), Vector2(14.0, -6.0),
			Vector2(14.0, 3.0), Vector2(11.0, 3.0)
		])
		neck_seal.color = COLOR_STRAPS
		body_container.add_child(neck_seal)

		var face_skin := Polygon2D.new()
		face_skin.polygon = PackedVector2Array([
			Vector2(16.0, -4.0), Vector2(22.0, -4.0),
			Vector2(22.0, 1.0), Vector2(16.0, 1.0)
		])
		face_skin.color = COLOR_SKIN
		body_container.add_child(face_skin)

	func _build_upright_body() -> void:
		# Foot-centered origin (0, 0), head reaches up to y: -45.0
		# 1. Legs (Trousers & Slate Knee Pads)
		var leg_left := Polygon2D.new()
		leg_left.polygon = PackedVector2Array([
			Vector2(-8.0, -18.0), Vector2(-2.0, -18.0),
			Vector2(-1.0, -4.0), Vector2(-8.0, -4.0)
		])
		leg_left.color = COLOR_SUIT
		body_container.add_child(leg_left)

		var leg_right := Polygon2D.new()
		leg_right.polygon = PackedVector2Array([
			Vector2(2.0, -18.0), Vector2(8.0, -18.0),
			Vector2(8.0, -4.0), Vector2(1.0, -4.0)
		])
		leg_right.color = COLOR_SUIT
		body_container.add_child(leg_right)

		var knee_left := Polygon2D.new()
		knee_left.polygon = PackedVector2Array([
			Vector2(-8.0, -12.0), Vector2(-2.0, -12.0),
			Vector2(-2.0, -8.0), Vector2(-8.0, -8.0)
		])
		knee_left.color = COLOR_PADS
		body_container.add_child(knee_left)

		var knee_right := Polygon2D.new()
		knee_right.polygon = PackedVector2Array([
			Vector2(2.0, -12.0), Vector2(8.0, -12.0),
			Vector2(8.0, -8.0), Vector2(2.0, -8.0)
		])
		knee_right.color = COLOR_PADS
		body_container.add_child(knee_right)

		# Heavy diving boots
		var boot_left := Polygon2D.new()
		boot_left.polygon = PackedVector2Array([
			Vector2(-9.0, -4.0), Vector2(-1.0, -4.0),
			Vector2(-1.0, 0.0), Vector2(-10.0, 0.0)
		])
		boot_left.color = COLOR_PADS
		body_container.add_child(boot_left)

		var boot_right := Polygon2D.new()
		boot_right.polygon = PackedVector2Array([
			Vector2(1.0, -4.0), Vector2(9.0, -4.0),
			Vector2(10.0, 0.0), Vector2(1.0, 0.0)
		])
		boot_right.color = COLOR_PADS
		body_container.add_child(boot_right)

		# 2. Torso (Mustard-yellow jacket)
		var jacket := Polygon2D.new()
		jacket.polygon = PackedVector2Array([
			Vector2(-9.0, -32.0), Vector2(9.0, -32.0),
			Vector2(8.0, -17.0), Vector2(-8.0, -17.0)
		])
		jacket.color = COLOR_SUIT
		body_container.add_child(jacket)

		# Jacket shadow contour
		var jacket_sh := Polygon2D.new()
		jacket_sh.polygon = PackedVector2Array([
			Vector2(1.0, -32.0), Vector2(9.0, -32.0),
			Vector2(8.0, -17.0), Vector2(3.0, -17.0)
		])
		jacket_sh.color = COLOR_SUIT_SHADOW
		body_container.add_child(jacket_sh)

		# Dark slate belt & collar
		var belt := Polygon2D.new()
		belt.polygon = PackedVector2Array([
			Vector2(-8.0, -18.0), Vector2(8.0, -18.0),
			Vector2(8.0, -16.0), Vector2(-8.0, -16.0)
		])
		belt.color = COLOR_PADS
		body_container.add_child(belt)

		var collar := Polygon2D.new()
		collar.polygon = PackedVector2Array([
			Vector2(-7.0, -33.0), Vector2(7.0, -33.0),
			Vector2(7.0, -31.0), Vector2(-7.0, -31.0)
		])
		collar.color = COLOR_PADS
		body_container.add_child(collar)

		# Chest harness straps & buckle
		var strap_l := Polygon2D.new()
		strap_l.polygon = PackedVector2Array([
			Vector2(-6.0, -31.0), Vector2(-4.0, -31.0),
			Vector2(-5.0, -17.0), Vector2(-7.0, -17.0)
		])
		strap_l.color = COLOR_STRAPS
		body_container.add_child(strap_l)

		var strap_r := Polygon2D.new()
		strap_r.polygon = PackedVector2Array([
			Vector2(4.0, -31.0), Vector2(6.0, -31.0),
			Vector2(7.0, -17.0), Vector2(5.0, -17.0)
		])
		strap_r.color = COLOR_STRAPS
		body_container.add_child(strap_r)

		var chest_buckle := Polygon2D.new()
		chest_buckle.polygon = PackedVector2Array([
			Vector2(-3.0, -26.0), Vector2(3.0, -26.0),
			Vector2(3.0, -23.0), Vector2(-3.0, -23.0)
		])
		chest_buckle.color = COLOR_BUCKLE
		body_container.add_child(chest_buckle)

		# 3. Arms & Gloves at sides
		var arm_l := Polygon2D.new()
		arm_l.polygon = PackedVector2Array([
			Vector2(-12.0, -30.0), Vector2(-8.0, -30.0),
			Vector2(-7.0, -15.0), Vector2(-12.0, -15.0)
		])
		arm_l.color = COLOR_SUIT
		body_container.add_child(arm_l)

		var elbow_l := Polygon2D.new()
		elbow_l.polygon = PackedVector2Array([
			Vector2(-12.0, -23.0), Vector2(-8.0, -23.0),
			Vector2(-7.0, -19.0), Vector2(-12.0, -19.0)
		])
		elbow_l.color = COLOR_PADS
		body_container.add_child(elbow_l)

		var glove_l := Polygon2D.new()
		glove_l.polygon = PackedVector2Array([
			Vector2(-12.0, -18.0), Vector2(-7.0, -18.0),
			Vector2(-7.0, -13.0), Vector2(-12.0, -13.0)
		])
		glove_l.color = COLOR_PADS
		body_container.add_child(glove_l)

		var arm_r := Polygon2D.new()
		arm_r.polygon = PackedVector2Array([
			Vector2(8.0, -30.0), Vector2(12.0, -30.0),
			Vector2(12.0, -15.0), Vector2(7.0, -15.0)
		])
		arm_r.color = COLOR_SUIT
		body_container.add_child(arm_r)

		var elbow_r := Polygon2D.new()
		elbow_r.polygon = PackedVector2Array([
			Vector2(8.0, -23.0), Vector2(12.0, -23.0),
			Vector2(12.0, -19.0), Vector2(7.0, -19.0)
		])
		elbow_r.color = COLOR_PADS
		body_container.add_child(elbow_r)

		var glove_r := Polygon2D.new()
		glove_r.polygon = PackedVector2Array([
			Vector2(7.0, -18.0), Vector2(12.0, -18.0),
			Vector2(12.0, -13.0), Vector2(7.0, -13.0)
		])
		glove_r.color = COLOR_PADS
		body_container.add_child(glove_r)

		# 4. Head & Diving Hood
		var hood := Polygon2D.new()
		hood.polygon = _make_ellipse(8.0, 7.5, Vector2(0.0, -39.0))
		hood.color = COLOR_SUIT
		body_container.add_child(hood)

		var neck_gasket := Polygon2D.new()
		neck_gasket.polygon = PackedVector2Array([
			Vector2(-6.0, -33.5), Vector2(6.0, -33.5),
			Vector2(6.0, -31.5), Vector2(-6.0, -31.5)
		])
		neck_gasket.color = COLOR_STRAPS
		body_container.add_child(neck_gasket)

		var face := Polygon2D.new()
		face.polygon = PackedVector2Array([
			Vector2(-5.0, -42.0), Vector2(5.0, -42.0),
			Vector2(5.0, -35.0), Vector2(-5.0, -35.0)
		])
		face.color = COLOR_SKIN
		body_container.add_child(face)

	# ==========================================================================
	# Modular Equipment Layers Updating (Real-Time Upgrades!)
	# ==========================================================================
	func update_gear_visuals() -> void:
		var o2_lvl: int = 1
		var fins_lvl: int = 1
		var exo_lvl: int = 1

		if bp_ref != null:
			o2_lvl = int(bp_ref.get("oxygen_level")) if bp_ref.get("oxygen_level") != null else 1
			fins_lvl = int(bp_ref.get("fins_level")) if bp_ref.get("fins_level") != null else 1
			exo_lvl = int(bp_ref.get("exo_level")) if bp_ref.get("exo_level") != null else 1
		elif Engine.has_singleton("Backpack"):
			var bp = Engine.get_singleton("Backpack")
			o2_lvl = int(bp.oxygen_level)
			fins_lvl = int(bp.fins_level)
			exo_lvl = int(bp.exo_level)

		_build_tank_visual(o2_lvl)
		_build_mask_visual(o2_lvl)
		_build_fins_visual(fins_lvl)
		_build_exo_visual(exo_lvl)

	# --- 1. OXYGEN TANK LAYER ---
	func _build_tank_visual(level: int) -> void:
		_clear_slot(tank_slot)

		# Skip if using custom sprite and level <= 1 (base tank already visible on sprite!)
		if has_custom_sprite and level <= 1:
			return

		var custom_tex_path: String = "res://assets/gear/tank_lv%d.png" % level
		if ResourceLoader.exists(custom_tex_path):
			var spr := _create_gear_sprite(custom_tex_path, Vector2(28.0, 24.0))
			if spr != null:
				spr.position = Vector2.ZERO
				tank_slot.add_child(spr)
				return

		if is_swimming:
			if level == 1:
				# Single small rusty grey cylinder (procedural fallback only)
				var tank := Polygon2D.new()
				tank.polygon = PackedVector2Array([
					Vector2(-10.0, -3.0), Vector2(8.0, -3.0),
					Vector2(8.0, 3.0), Vector2(-10.0, 3.0)
				])
				tank.color = Color("#636B72")
				tank_slot.add_child(tank)

				var rust := Polygon2D.new()
				rust.polygon = PackedVector2Array([
					Vector2(-4.0, -2.0), Vector2(1.0, -2.0),
					Vector2(0.0, 2.0), Vector2(-5.0, 2.0)
				])
				rust.color = Color("#8D5B2A")
				tank_slot.add_child(rust)

				var valve := ColorRect.new()
				valve.color = Color("#2C3539")
				valve.position = Vector2(8.0, -1.5)
				valve.size = Vector2(3.0, 3.0)
				tank_slot.add_child(valve)

				var hose := Line2D.new()
				hose.points = PackedVector2Array([Vector2(10.0, 0.0), Vector2(14.0, 2.0), Vector2(18.0, 6.0)])
				hose.width = 1.5
				hose.default_color = Color("#181D1F")
				tank_slot.add_child(hose)
			elif level == 2:
				# Larger bright cyan high-pressure tank with gauge
				var tank := Polygon2D.new()
				tank.polygon = PackedVector2Array([
					Vector2(-12.0, -5.0), Vector2(10.0, -5.0),
					Vector2(10.0, 4.0), Vector2(-12.0, 4.0)
				])
				tank.color = Color("#00B4D8")
				tank_slot.add_child(tank)

				var highlight := Line2D.new()
				highlight.points = PackedVector2Array([Vector2(-10.0, -3.5), Vector2(8.0, -3.5)])
				highlight.width = 1.5
				highlight.default_color = Color("#90E0EF")
				tank_slot.add_child(highlight)

				# Pressure dial gauge
				var gauge := Polygon2D.new()
				gauge.polygon = _make_ellipse(3.0, 3.0, Vector2(10.0, 0.0))
				gauge.color = Color.WHITE
				tank_slot.add_child(gauge)

				var needle := Line2D.new()
				needle.points = PackedVector2Array([Vector2(10.0, 0.0), Vector2(11.5, -1.5)])
				needle.width = 1.0
				needle.default_color = Color.RED
				tank_slot.add_child(needle)
			else:
				# Level 3+: Dual twin golden/plasma tanks with glowing core stripe!
				var tank_top := Polygon2D.new()
				tank_top.polygon = PackedVector2Array([
					Vector2(-13.0, -7.0), Vector2(10.0, -7.0),
					Vector2(10.0, -2.0), Vector2(-13.0, -2.0)
				])
				tank_top.color = Color("#E5A00D")
				tank_slot.add_child(tank_top)

				var tank_bot := Polygon2D.new()
				tank_bot.polygon = PackedVector2Array([
					Vector2(-13.0, 0.0), Vector2(10.0, 0.0),
					Vector2(10.0, 5.0), Vector2(-13.0, 5.0)
				])
				tank_bot.color = Color("#E5A00D")
				tank_slot.add_child(tank_bot)

				# Glowing plasma core stripe between tanks
				var plasma := Line2D.new()
				plasma.points = PackedVector2Array([Vector2(-11.0, -1.0), Vector2(8.0, -1.0)])
				plasma.width = 2.0
				plasma.default_color = Color("#00FFFF")
				var add_mat := CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				plasma.material = add_mat
				tank_slot.add_child(plasma)
		else:
			# Upright (2.5D Top-Down) Tank peeking over shoulders
			if level == 1:
				# Small rusty cylinder on back right (procedural fallback only)
				var tank := Polygon2D.new()
				tank.polygon = PackedVector2Array([
					Vector2(5.0, -10.0), Vector2(10.0, -10.0),
					Vector2(10.0, 6.0), Vector2(5.0, 6.0)
				])
				tank.color = Color("#636B72")
				tank_slot.add_child(tank)

				var valve := ColorRect.new()
				valve.color = Color("#C8961E")
				valve.position = Vector2(6.0, -12.0)
				valve.size = Vector2(2.5, 3.0)
				tank_slot.add_child(valve)
			elif level == 2:
				var tank := Polygon2D.new()
				tank.polygon = PackedVector2Array([
					Vector2(4.0, -12.0), Vector2(11.0, -12.0),
					Vector2(11.0, 7.0), Vector2(4.0, 7.0)
				])
				tank.color = Color("#00B4D8")
				tank_slot.add_child(tank)

				var gauge := Polygon2D.new()
				gauge.polygon = _make_ellipse(2.5, 2.5, Vector2(9.0, -8.0))
				gauge.color = Color.WHITE
				tank_slot.add_child(gauge)
			else:
				# Level 3+: Dual golden tanks flanking both shoulders
				var tank_l := Polygon2D.new()
				tank_l.polygon = PackedVector2Array([
					Vector2(-11.0, -14.0), Vector2(-4.0, -14.0),
					Vector2(-4.0, 6.0), Vector2(-11.0, 6.0)
				])
				tank_l.color = Color("#E5A00D")
				tank_slot.add_child(tank_l)

				var tank_r := Polygon2D.new()
				tank_r.polygon = PackedVector2Array([
					Vector2(4.0, -14.0), Vector2(11.0, -14.0),
					Vector2(11.0, 6.0), Vector2(4.0, 6.0)
				])
				tank_r.color = Color("#E5A00D")
				tank_slot.add_child(tank_r)

				# Glowing plasma energy nodes
				var glow_l := Polygon2D.new()
				glow_l.polygon = _make_ellipse(2.5, 2.5, Vector2(-7.5, -14.5))
				glow_l.color = Color("#00FFFF")
				var add_mat := CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				glow_l.material = add_mat
				tank_slot.add_child(glow_l)

				var glow_r := Polygon2D.new()
				glow_r.polygon = _make_ellipse(2.5, 2.5, Vector2(7.5, -14.5))
				glow_r.color = Color("#00FFFF")
				glow_r.material = add_mat
				tank_slot.add_child(glow_r)

	# --- 2. DIVING MASK / HELMET VISOR LAYER ---
	func _build_mask_visual(level: int) -> void:
		_clear_slot(mask_slot)

		# Skip if using custom sprite and level <= 1 (base mask/helmet already visible on sprite!)
		if has_custom_sprite and level <= 1:
			return

		var custom_tex_path: String = "res://assets/gear/mask_lv%d.png" % level
		if ResourceLoader.exists(custom_tex_path):
			var spr := _create_gear_sprite(custom_tex_path, Vector2(24.0, 20.0))
			if spr != null:
				spr.position = Vector2.ZERO
				mask_slot.add_child(spr)
				return

		if is_swimming:
			if level == 1:
				# Basic glass goggles with rubber strap (procedural fallback only)
				var strap := Line2D.new()
				strap.points = PackedVector2Array([Vector2(-6.0, 0.0), Vector2(1.0, 0.0)])
				strap.width = 1.5
				strap.default_color = Color("#181D1F")
				mask_slot.add_child(strap)

				var lens := Polygon2D.new()
				lens.polygon = PackedVector2Array([
					Vector2(0.0, -3.0), Vector2(7.0, -3.0),
					Vector2(6.0, 3.0), Vector2(0.0, 3.0)
				])
				lens.color = Color(0.55, 0.85, 0.95, 0.75)
				mask_slot.add_child(lens)
			elif level == 2:
				# Brass deep-sea helmet with glowing cyan visor
				var frame := Polygon2D.new()
				frame.polygon = _make_ellipse(5.0, 5.0, Vector2.ZERO)
				frame.color = Color("#D49B24")
				mask_slot.add_child(frame)

				var viewport := Polygon2D.new()
				viewport.polygon = _make_ellipse(3.5, 3.5, Vector2.ZERO)
				viewport.color = Color(0.1, 0.95, 0.95, 0.88)
				mask_slot.add_child(viewport)
			else:
				# Level 3+: High-tech neon magenta/gold abyssal visor
				var frame := Polygon2D.new()
				frame.polygon = _make_ellipse(6.0, 5.0, Vector2.ZERO)
				frame.color = Color("#181A20")
				mask_slot.add_child(frame)

				var neon_visor := Polygon2D.new()
				neon_visor.polygon = _make_ellipse(4.2, 3.2, Vector2.ZERO)
				neon_visor.color = Color("#FF1493")
				var add_mat := CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				neon_visor.material = add_mat
				mask_slot.add_child(neon_visor)
		else:
			# Upright (2.5D Top-Down) Mask on Face
			if level == 1:
				var goggles := Polygon2D.new()
				goggles.polygon = PackedVector2Array([
					Vector2(-5.0, -2.0), Vector2(5.0, -2.0),
					Vector2(5.0, 2.0), Vector2(-5.0, 2.0)
				])
				goggles.color = Color(0.55, 0.85, 0.95, 0.8)
				mask_slot.add_child(goggles)

				var rim := Line2D.new()
				rim.points = PackedVector2Array([
					Vector2(-5.0, -2.0), Vector2(5.0, -2.0),
					Vector2(5.0, 2.0), Vector2(-5.0, 2.0), Vector2(-5.0, -2.0)
				])
				rim.width = 1.0
				rim.default_color = Color("#181D1F")
				mask_slot.add_child(rim)
			elif level == 2:
				var frame := Polygon2D.new()
				frame.polygon = _make_ellipse(5.5, 4.5, Vector2.ZERO)
				frame.color = Color("#D49B24")
				mask_slot.add_child(frame)

				var glass := Polygon2D.new()
				glass.polygon = _make_ellipse(4.0, 3.0, Vector2.ZERO)
				glass.color = Color(0.1, 0.95, 0.95, 0.9)
				mask_slot.add_child(glass)
			else:
				# Level 3+: High-tech neon magenta/gold abyssal visor
				var frame := Polygon2D.new()
				frame.polygon = _make_ellipse(6.5, 5.0, Vector2.ZERO)
				frame.color = Color("#181A20")
				mask_slot.add_child(frame)

				var trim := Line2D.new()
				trim.points = _make_ellipse(6.5, 5.0, Vector2.ZERO)
				trim.width = 1.2
				trim.default_color = Color("#FFD700")
				trim.closed = true
				mask_slot.add_child(trim)

				var neon_lens := Polygon2D.new()
				neon_lens.polygon = _make_ellipse(4.5, 3.5, Vector2.ZERO)
				neon_lens.color = Color("#FF1493")
				var add_mat := CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				neon_lens.material = add_mat
				mask_slot.add_child(neon_lens)

	# --- 3. HYDRO-FINS LAYER (Active in Swimming Pose) ---
	func _build_fins_visual(level: int) -> void:
		_clear_slot(fins_slot)
		if not is_swimming:
			return

		# Skip if using custom sprite and level <= 1 (base fins already visible on sprite!)
		if has_custom_sprite and level <= 1:
			return

		var custom_tex_path: String = "res://assets/gear/fins_lv%d.png" % level
		if ResourceLoader.exists(custom_tex_path):
			var spr := _create_gear_sprite(custom_tex_path, Vector2(24.0, 18.0))
			if spr != null:
				spr.position = Vector2.ZERO
				fins_slot.add_child(spr)
				return

		if level == 1:
			# Short black rubber flippers (procedural fallback only)
			var fin := Polygon2D.new()
			fin.polygon = PackedVector2Array([
				Vector2(-2.0, -3.0), Vector2(-16.0, -5.0),
				Vector2(-17.0, 4.0), Vector2(-2.0, 2.0)
			])
			fin.color = Color("#1C2024")
			fins_slot.add_child(fin)
		elif level == 2:
			# Long cyan carbon-fiber blades
			var blade := Polygon2D.new()
			blade.polygon = PackedVector2Array([
				Vector2(-2.0, -4.0), Vector2(-26.0, -6.0),
				Vector2(-24.0, 6.0), Vector2(-2.0, 3.0)
			])
			blade.color = Color("#00C8D6")
			fins_slot.add_child(blade)

			var carbon_ridge := Line2D.new()
			carbon_ridge.points = PackedVector2Array([Vector2(-3.0, 0.0), Vector2(-25.0, 0.0)])
			carbon_ridge.width = 1.5
			carbon_ridge.default_color = Color("#163A42")
			fins_slot.add_child(carbon_ridge)
		else:
			# Level 3+: Glowing hydro-jet thruster fins!
			var thruster := Polygon2D.new()
			thruster.polygon = PackedVector2Array([
				Vector2(-2.0, -5.0), Vector2(-14.0, -6.0),
				Vector2(-14.0, 5.0), Vector2(-2.0, 4.0)
			])
			thruster.color = Color("#262930")
			fins_slot.add_child(thruster)

			# Jet exhaust plume / plasma wake
			var jet := Polygon2D.new()
			jet.polygon = PackedVector2Array([
				Vector2(-14.0, -3.0), Vector2(-28.0, 0.0),
				Vector2(-14.0, 3.0)
			])
			jet.color = Color(0.0, 0.95, 1.0, 0.85)
			var add_mat := CanvasItemMaterial.new()
			add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			jet.material = add_mat
			fins_slot.add_child(jet)

			var core := Polygon2D.new()
			core.polygon = PackedVector2Array([
				Vector2(-14.0, -1.5), Vector2(-22.0, 0.0),
				Vector2(-14.0, 1.5)
			])
			core.color = Color(1.0, 1.0, 1.0, 0.9)
			core.material = add_mat
			fins_slot.add_child(core)

	# --- 4. EXO-RIG FRAME LAYER (Visible on BOTH Land and Water!) ---
	func _build_exo_visual(level: int) -> void:
		_clear_slot(exo_slot)

		# Skip if using custom sprite and level <= 1 (base harness already visible on sprite!)
		if has_custom_sprite and level <= 1:
			return

		var custom_tex_path: String = "res://assets/gear/exo_lv%d.png" % level
		if ResourceLoader.exists(custom_tex_path):
			var spr := _create_gear_sprite(custom_tex_path, Vector2(30.0, 26.0))
			if spr != null:
				spr.position = Vector2.ZERO
				exo_slot.add_child(spr)
				return

		if is_swimming:
			if level == 1:
				# Simple leather strap & utility pouch (procedural fallback only)
				var strap := Line2D.new()
				strap.points = PackedVector2Array([Vector2(-7.0, -7.0), Vector2(5.0, 7.0)])
				strap.width = 2.0
				strap.default_color = Color("#4A2E1B")
				exo_slot.add_child(strap)

				var pouch := ColorRect.new()
				pouch.color = Color("#3D2515")
				pouch.position = Vector2(-3.0, 3.0)
				pouch.size = Vector2(4.0, 4.0)
				exo_slot.add_child(pouch)
			elif level == 2:
				# Yellow industrial steel exo-frame bars around shoulders/spine
				var spine_bar := Line2D.new()
				spine_bar.points = PackedVector2Array([Vector2(-11.0, -8.0), Vector2(9.0, -8.0)])
				spine_bar.width = 2.5
				spine_bar.default_color = Color("#FF8C00")
				exo_slot.add_child(spine_bar)

				var piston := Line2D.new()
				piston.points = PackedVector2Array([Vector2(-7.0, -8.0), Vector2(-7.0, 4.0)])
				piston.width = 2.0
				piston.default_color = Color("#A0AAB2")
				exo_slot.add_child(piston)
			else:
				# Level 3+: Heavy powered mech-harness with glowing status lights!
				var chassis := Polygon2D.new()
				chassis.polygon = PackedVector2Array([
					Vector2(-11.0, -9.0), Vector2(11.0, -9.0),
					Vector2(9.0, -5.0), Vector2(-11.0, -5.0)
				])
				chassis.color = Color("#263238")
				exo_slot.add_child(chassis)

				var hazard_stripe := Line2D.new()
				hazard_stripe.points = PackedVector2Array([Vector2(-9.0, -7.0), Vector2(8.0, -7.0)])
				hazard_stripe.width = 1.5
				hazard_stripe.default_color = Color("#FFB300")
				exo_slot.add_child(hazard_stripe)

				var piston := Line2D.new()
				piston.points = PackedVector2Array([Vector2(-6.0, -7.0), Vector2(-6.0, 5.0)])
				piston.width = 2.5
				piston.default_color = Color("#E0E6ED")
				exo_slot.add_child(piston)

				# Glowing status LED
				var led := Polygon2D.new()
				led.polygon = _make_ellipse(1.5, 1.5, Vector2(3.0, -7.0))
				led.color = Color("#00E676")
				var add_mat := CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				led.material = add_mat
				exo_slot.add_child(led)
		else:
			# Upright (2.5D Top-Down) Exo-Rig
			if level == 1:
				var strap := Line2D.new()
				strap.points = PackedVector2Array([Vector2(-7.0, -6.0), Vector2(6.0, 7.0)])
				strap.width = 2.0
				strap.default_color = Color("#4A2E1B")
				exo_slot.add_child(strap)

				var buckle := Polygon2D.new()
				buckle.polygon = PackedVector2Array([
					Vector2(-1.5, -0.5), Vector2(1.5, -0.5),
					Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
				])
				buckle.color = Color("#C8961E")
				exo_slot.add_child(buckle)
			elif level == 2:
				# Industrial steel exo-frame bars over shoulders
				var shoulder_l := ColorRect.new()
				shoulder_l.color = Color("#FF8C00")
				shoulder_l.position = Vector2(-11.0, -8.0)
				shoulder_l.size = Vector2(3.0, 5.0)
				exo_slot.add_child(shoulder_l)

				var shoulder_r := ColorRect.new()
				shoulder_r.color = Color("#FF8C00")
				shoulder_r.position = Vector2(8.0, -8.0)
				shoulder_r.size = Vector2(3.0, 5.0)
				exo_slot.add_child(shoulder_r)

				var hip_strut := Line2D.new()
				hip_strut.points = PackedVector2Array([Vector2(-9.0, 6.0), Vector2(-9.0, 16.0)])
				hip_strut.width = 2.0
				hip_strut.default_color = Color("#A0AAB2")
				exo_slot.add_child(hip_strut)

				var hip_strut_r := Line2D.new()
				hip_strut_r.points = PackedVector2Array([Vector2(9.0, 6.0), Vector2(9.0, 16.0)])
				hip_strut_r.width = 2.0
				hip_strut_r.default_color = Color("#A0AAB2")
				exo_slot.add_child(hip_strut_r)
			else:
				# Level 3+: Heavy powered mech-harness with glowing status lights!
				var pauldron_l := Polygon2D.new()
				pauldron_l.polygon = PackedVector2Array([
					Vector2(-13.0, -9.0), Vector2(-7.0, -9.0),
					Vector2(-6.0, -2.0), Vector2(-13.0, -2.0)
				])
				pauldron_l.color = Color("#263238")
				exo_slot.add_child(pauldron_l)

				var pauldron_r := Polygon2D.new()
				pauldron_r.polygon = PackedVector2Array([
					Vector2(7.0, -9.0), Vector2(13.0, -9.0),
					Vector2(13.0, -2.0), Vector2(6.0, -2.0)
				])
				pauldron_r.color = Color("#263238")
				exo_slot.add_child(pauldron_r)

				var stripe_l := Line2D.new()
				stripe_l.points = PackedVector2Array([Vector2(-12.0, -5.0), Vector2(-7.0, -5.0)])
				stripe_l.width = 1.5
				stripe_l.default_color = Color("#FFB300")
				exo_slot.add_child(stripe_l)

				var stripe_r := Line2D.new()
				stripe_r.points = PackedVector2Array([Vector2(7.0, -5.0), Vector2(12.0, -5.0)])
				stripe_r.width = 1.5
				stripe_r.default_color = Color("#FFB300")
				exo_slot.add_child(stripe_r)

				var hip_l := Line2D.new()
				hip_l.points = PackedVector2Array([Vector2(-10.0, 6.0), Vector2(-10.0, 17.0)])
				hip_l.width = 2.5
				hip_l.default_color = Color("#E0E6ED")
				exo_slot.add_child(hip_l)

				var hip_r := Line2D.new()
				hip_r.points = PackedVector2Array([Vector2(10.0, 6.0), Vector2(10.0, 17.0)])
				hip_r.width = 2.5
				hip_r.default_color = Color("#E0E6ED")
				exo_slot.add_child(hip_r)

				# Status LEDs on shoulders
				var led_l := Polygon2D.new()
				led_l.polygon = _make_ellipse(1.5, 1.5, Vector2(-10.0, -7.5))
				led_l.color = Color("#00E676")
				var add_mat := CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				led_l.material = add_mat
				exo_slot.add_child(led_l)

				var led_r := Polygon2D.new()
				led_r.polygon = _make_ellipse(1.5, 1.5, Vector2(10.0, -7.5))
				led_r.color = Color("#00E5FF")
				led_r.material = add_mat
				exo_slot.add_child(led_r)

	func _create_gear_sprite(path: String, fallback_size: Vector2) -> Sprite2D:
		var tex := load(path) as Texture2D
		if tex == null:
			return null
		var spr := Sprite2D.new()
		spr.texture = tex
		if fallback_size != Vector2.ZERO and tex.get_width() > 0 and tex.get_height() > 0:
			spr.scale = Vector2(fallback_size.x / float(tex.get_width()), fallback_size.y / float(tex.get_height()))
		return spr

	func _clear_slot(slot: Node2D) -> void:
		if slot != null:
			for c in slot.get_children():
				slot.remove_child(c)
				c.queue_free()

	static func _make_ellipse(rx: float, ry: float, offset: Vector2 = Vector2.ZERO, segments: int = 12) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in range(segments):
			var angle: float = (float(i) / float(segments)) * TAU
			pts.append(offset + Vector2(cos(angle) * rx, sin(angle) * ry))
		return pts


## Helper generating an ellipse / circle polygon vector array
static func _make_ellipse(rx: float, ry: float, offset: Vector2 = Vector2.ZERO, segments: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var angle: float = (float(i) / float(segments)) * TAU
		pts.append(offset + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts


class PlayerVisuals extends VisualRig:
	pass


# ==============================================================================
# Four-State Relic Visual System (Direction 4)
# ==============================================================================

class RelicVisualNode extends Node2D:
	var visual_state: String = ""
	var relic_color: Color = Color.CYAN
	var hover_container: Node2D = null
	var halo_poly: Polygon2D = null
	var shimmer_spark: Polygon2D = null
	var _anim_time: float = 0.0

	func _ready() -> void:
		_anim_time = randf() * TAU

	func _process(delta: float) -> void:
		_anim_time += delta
		if visual_state == "underwater_buried":
			if halo_poly != null:
				var pulse: float = 1.0 + sin(_anim_time * 3.2) * 0.16
				halo_poly.scale = Vector2(pulse, pulse)
		elif visual_state == "pedestal_25d":
			if hover_container != null:
				hover_container.position.y = -18.0 + sin(_anim_time * 3.0) * 3.0
			if shimmer_spark != null:
				shimmer_spark.rotation += delta * 1.8
				shimmer_spark.scale = Vector2.ONE * (0.8 + sin(_anim_time * 4.0) * 0.25)


## Builds a 4-state visual node for a relic:
## "underwater_buried", "encrusted_icon", "clean_icon", "pedestal_25d"
func build_relic_visual(relic_id: String, state: String) -> Node2D:
	var root := RelicVisualNode.new()
	root.name = "RelicVisual_%s" % state
	root.visual_state = state

	var db: Dictionary = RELIC_DB
	var relic_data: Dictionary = db.get(relic_id, {})
	var r_color := Color.from_string(str(relic_data.get("color_hex", "#00ffff")), Color.CYAN)
	if relic_data.has("color") and relic_data["color"] is Color:
		r_color = relic_data["color"]
	root.relic_color = r_color

	var icon_p: String = str(relic_data.get("icon_path", "res://assets/relics/%s.png" % relic_id))

	if state == "underwater_buried":
		root.rotation = deg_to_rad(14.0)

		# 1. Pulsing underwater glint halo
		var halo := Polygon2D.new()
		halo.name = "BuriedHalo"
		halo.polygon = _make_ellipse(24.0, 14.0)
		halo.color = Color(r_color.r, r_color.g, r_color.b, 0.26)
		root.add_child(halo)
		root.halo_poly = halo

		# 2. Base relic (custom buried PNG -> clean PNG -> procedural crystal)
		var custom_buried: String = "res://assets/relics/%s_buried.png" % relic_id
		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(custom_buried):
			loaded_spr = load_smart_sprite(root, custom_buried, Vector2(36.0, 36.0))
		elif ResourceLoader.exists(icon_p):
			loaded_spr = load_smart_sprite(root, icon_p, Vector2(32.0, 32.0))

		if loaded_spr == null:
			var crystal := Polygon2D.new()
			crystal.name = "CrystalCore"
			crystal.polygon = PackedVector2Array([
				Vector2(0.0, -14.0), Vector2(11.0, -3.0),
				Vector2(8.0, 12.0), Vector2(-8.0, 12.0),
				Vector2(-11.0, -3.0)
			])
			crystal.color = r_color
			root.add_child(crystal)

			var hi := Polygon2D.new()
			hi.name = "CrystalHighlight"
			hi.polygon = PackedVector2Array([
				Vector2(0.0, -9.0), Vector2(6.0, -2.0),
				Vector2(4.0, 6.0), Vector2(-4.0, 6.0),
				Vector2(-6.0, -2.0)
			])
			hi.color = Color.WHITE.lerp(r_color, 0.4)
			root.add_child(hi)

		# 3. Seabed mud silt & barnacle clumps covering bottom half
		var mud := Polygon2D.new()
		mud.name = "SeabedMud"
		mud.polygon = PackedVector2Array([
			Vector2(-14.0, 1.0), Vector2(-4.0, -2.0), Vector2(4.0, 2.0),
			Vector2(14.0, 0.0), Vector2(16.0, 15.0), Vector2(-16.0, 15.0)
		])
		mud.color = Color("#261D16")
		root.add_child(mud)

		var silt := Line2D.new()
		silt.points = PackedVector2Array([
			Vector2(-14.0, 1.0), Vector2(-4.0, -2.0), Vector2(4.0, 2.0), Vector2(14.0, 0.0)
		])
		silt.width = 1.8
		silt.default_color = Color("#3D3025")
		root.add_child(silt)

		for b_pos in [Vector2(-6.0, 5.0), Vector2(2.0, 7.0), Vector2(9.0, 4.0)]:
			var b_shell := Polygon2D.new()
			b_shell.polygon = _make_ellipse(3.0, 2.5, b_pos)
			b_shell.color = Color("#6E6252")
			root.add_child(b_shell)
			var b_pit := Polygon2D.new()
			b_pit.polygon = _make_ellipse(1.2, 1.0, b_pos)
			b_pit.color = Color("#1F1813")
			root.add_child(b_pit)

	elif state == "encrusted_icon":
		var encrusted_p: String = "res://assets/relics/%s_encrusted.png" % relic_id
		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(encrusted_p):
			loaded_spr = load_smart_sprite(root, encrusted_p, Vector2(32.0, 32.0))

		if loaded_spr == null:
			var sil := Polygon2D.new()
			sil.polygon = PackedVector2Array([
				Vector2(-13.0, -11.0), Vector2(2.0, -14.0), Vector2(14.0, -8.0),
				Vector2(15.0, 8.0), Vector2(5.0, 14.0), Vector2(-11.0, 12.0),
				Vector2(-15.0, 2.0)
			])
			sil.color = Color("#2B221B")
			root.add_child(sil)

			var rock1 := Polygon2D.new()
			rock1.polygon = PackedVector2Array([
				Vector2(-11.0, -9.0), Vector2(1.0, -12.0), Vector2(7.0, -4.0),
				Vector2(-2.0, 2.0), Vector2(-12.0, -2.0)
			])
			rock1.color = Color("#4E4236")
			root.add_child(rock1)

			var rock2 := Polygon2D.new()
			rock2.polygon = PackedVector2Array([
				Vector2(0.0, -4.0), Vector2(13.0, -6.0), Vector2(13.0, 7.0),
				Vector2(3.0, 12.0), Vector2(-3.0, 3.0)
			])
			rock2.color = Color("#5C5042")
			root.add_child(rock2)

			var rock3 := Polygon2D.new()
			rock3.polygon = PackedVector2Array([
				Vector2(-12.0, 0.0), Vector2(-1.0, 4.0), Vector2(4.0, 12.0),
				Vector2(-9.0, 11.0), Vector2(-14.0, 4.0)
			])
			rock3.color = Color("#382F26")
			root.add_child(rock3)

			var fissure := Line2D.new()
			fissure.points = PackedVector2Array([
				Vector2(-6.0, -5.0), Vector2(1.0, -1.0), Vector2(5.0, 6.0)
			])
			fissure.width = 1.2
			fissure.default_color = Color("#8D7E6C")
			root.add_child(fissure)

			var glint := Polygon2D.new()
			glint.polygon = _make_ellipse(1.5, 1.5, Vector2(1.0, -1.0))
			glint.color = Color(r_color.r, r_color.g, r_color.b, 0.65)
			root.add_child(glint)

	elif state == "clean_icon":
		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(icon_p):
			loaded_spr = load_smart_sprite(root, icon_p, Vector2(32.0, 32.0))

		if loaded_spr == null:
			var rim := Polygon2D.new()
			rim.polygon = PackedVector2Array([
				Vector2(0.0, -15.0), Vector2(12.0, -4.0),
				Vector2(9.0, 13.0), Vector2(-9.0, 13.0),
				Vector2(-12.0, -4.0)
			])
			rim.color = Color("#151D24")
			root.add_child(rim)

			var core := Polygon2D.new()
			core.polygon = PackedVector2Array([
				Vector2(0.0, -13.5), Vector2(10.5, -3.5),
				Vector2(7.5, 11.5), Vector2(-7.5, 11.5),
				Vector2(-10.5, -3.5)
			])
			core.color = r_color
			root.add_child(core)

			var spec := Polygon2D.new()
			spec.polygon = PackedVector2Array([
				Vector2(0.0, -9.0), Vector2(5.5, -2.5),
				Vector2(3.5, 5.0), Vector2(-3.5, 5.0),
				Vector2(-5.5, -2.5)
			])
			spec.color = Color.WHITE.lerp(r_color, 0.45)
			root.add_child(spec)

			var dot := Polygon2D.new()
			dot.polygon = _make_ellipse(1.5, 1.5, Vector2(0.0, -1.0))
			dot.color = Color.WHITE
			root.add_child(dot)

	elif state == "pedestal_25d":
		var shadow := Polygon2D.new()
		shadow.name = "PedestalShadow"
		shadow.polygon = _make_ellipse(18.0, 8.0, Vector2(0.0, 8.0))
		shadow.color = Color(0.0, 0.0, 0.0, 0.45)
		root.add_child(shadow)

		var hover := Node2D.new()
		hover.name = "HoverContainer"
		hover.position = Vector2(0.0, -18.0)
		root.add_child(hover)
		root.hover_container = hover

		var aura := Polygon2D.new()
		aura.name = "SpotlightAura"
		aura.polygon = _make_ellipse(20.0, 13.0)
		aura.color = Color(r_color.r, r_color.g, r_color.b, 0.32)
		hover.add_child(aura)

		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(icon_p):
			loaded_spr = load_smart_sprite(hover, icon_p, Vector2(32.0, 32.0))

		if loaded_spr == null:
			var crystal := Polygon2D.new()
			crystal.polygon = PackedVector2Array([
				Vector2(0.0, -13.0), Vector2(10.0, -3.0),
				Vector2(7.0, 10.0), Vector2(-7.0, 10.0),
				Vector2(-10.0, -3.0)
			])
			crystal.color = r_color
			hover.add_child(crystal)

			var hi := Polygon2D.new()
			hi.polygon = PackedVector2Array([
				Vector2(0.0, -8.0), Vector2(5.0, -2.0),
				Vector2(3.0, 5.0), Vector2(-3.0, 5.0),
				Vector2(-5.0, -2.0)
			])
			hi.color = Color.WHITE.lerp(r_color, 0.4)
			hover.add_child(hi)

		var spark := Polygon2D.new()
		spark.name = "ShimmerSpark"
		spark.polygon = PackedVector2Array([
			Vector2(0.0, -4.5), Vector2(1.5, -1.0), Vector2(4.5, 0.0),
			Vector2(1.5, 1.0), Vector2(0.0, 4.5), Vector2(-1.5, 1.0),
			Vector2(-4.5, 0.0), Vector2(-1.5, -1.0)
		])
		spark.color = Color.WHITE
		spark.position = Vector2(6.0, -8.0)
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		spark.material = add_mat
		hover.add_child(spark)
		root.shimmer_spark = spark

	return root


# ==============================================================================
# Historical Sets & Completion Buffs (Direction 3)
# ==============================================================================

## Returns true if all relics belonging to set_name have been discovered and cleaned
func is_set_completed(set_name: String) -> bool:
	var set_relics: Array[String] = []
	for rid in RELIC_DB.keys():
		if rid == "blueprint_tube":
			continue
		var r_set: String = str(RELIC_DB[rid].get("set_name", ""))
		if r_set == set_name:
			set_relics.append(rid)

	if set_relics.is_empty():
		return false

	for rid in set_relics:
		if not discovered_relics.get(rid, false):
			return false
	return true


## Returns a list of all historical sets currently 100% completed
func get_completed_sets() -> Array[String]:
	var completed: Array[String] = []
	var set_names: Array[String] = [
		"21st Century Computing",
		"Daily Café Life",
		"Resource War Remnants"
	]
	for s_name in set_names:
		if is_set_completed(s_name):
			completed.append(s_name)
	return completed


## Returns effective max oxygen including +15 O2 set completion buff from "Daily Café Life"
func get_effective_max_oxygen() -> float:
	var bonus: float = 15.0 if is_set_completed("Daily Café Life") else 0.0
	return max_oxygen + bonus


## Returns effective swim speed including +25 px/s set completion buff from "Resource War Remnants"
func get_effective_swim_speed() -> float:
	var bonus: float = 25.0 if is_set_completed("Resource War Remnants") else 0.0
	return swim_speed + bonus


## Returns scrap salvage multiplier (+20% value if "21st Century Computing" set completed)
func get_salvage_value_multiplier() -> float:
	return 1.2 if is_set_completed("21st Century Computing") else 1.0


# ==============================================================================
# Alien VIP Request Board System (Direction 3)
# ==============================================================================

const VIP_CLIENTS: Array[Dictionary] = [
	{
		"name": "Ambassador Vaelen (Hydra Oceanic Syndicate)",
		"flavor": "Our aquatic high council craves authentic human artifacts. Supply our delegation with the requested item for generous compensation!"
	},
	{
		"name": "Archivist Xylar (Gliese-667 Expedition)",
		"flavor": "Deep-sea scans indicate a rare human relic in this trench. Deliver a cleaned sample to advance interspecies anthropology!"
	},
	{
		"name": "Mechanist Korath (Titan Sub-Surface Enclave)",
		"flavor": "Our biomechanical engineers seek pre-collapse metallurgy. Bring us the artifact in pristine condition for immediate payment."
	},
	{
		"name": "Collector Zephyra (Orion Antiquities Guild)",
		"flavor": "Private collectors across the stars pay fortunes for genuine human remnants. Clean this relic and the credits are yours!"
	},
	{
		"name": "Consul Theron (Europa Research Fleet)",
		"flavor": "We are reconstructing Old Earth daily life routines. Your human salvage will be treasured in our off-world memorial dome."
	}
]

## Generates a new random daily VIP request for a specific human relic at 2.5x scrap value
func generate_daily_vip_quest() -> void:
	var valid_ids: Array[String] = [
		"relic_keyboard", "relic_mouse", "relic_core",
		"relic_cup", "relic_toaster", "relic_console",
		"relic_dogtag", "relic_mask"
	]
	var chosen_id: String = valid_ids[randi() % valid_ids.size()]
	var relic_data: Dictionary = RELIC_DB.get(chosen_id, {})
	var client: Dictionary = VIP_CLIENTS[randi() % VIP_CLIENTS.size()]

	var base_val: int = int(relic_data.get("value", 100))
	var reward: int = int(round(float(base_val) * 2.5))

	active_vip_quest = {
		"day_generated": current_day,
		"relic_id": chosen_id,
		"relic_name": str(relic_data.get("name", "Unknown Relic")),
		"rarity": str(relic_data.get("rarity", "Common")),
		"set_name": str(relic_data.get("set_name", "Unknown Set")),
		"base_value": base_val,
		"reward_gold": reward,
		"client_name": str(client.get("name", "Alien Envoy")),
		"dialogue": str(client.get("flavor", "We seek human relics.")),
		"completed": false
	}
	save_game()
	vip_quest_updated.emit()


## Checks if player currently possesses the requested VIP quest item AND it has been cleaned (identified)
func has_vip_quest_item() -> bool:
	if active_vip_quest.is_empty():
		return false
	var target_id: String = str(active_vip_quest.get("relic_id", ""))
	for it in items:
		if str(it.get("id", "")) == target_id and bool(it.get("identified", false)):
			return true
	return false


## Fulfills active VIP quest: consumes the identified relic, awards 2.5x gold reward, marks quest completed
func fulfill_vip_quest() -> bool:
	if active_vip_quest.is_empty() or bool(active_vip_quest.get("completed", false)):
		return false

	var target_id: String = str(active_vip_quest.get("relic_id", ""))
	var found_index: int = -1
	for i in range(items.size()):
		if str(items[i].get("id", "")) == target_id and bool(items[i].get("identified", false)):
			found_index = i
			break

	if found_index == -1:
		return false

	consume_item_at(found_index)
	var reward_payout: int = int(active_vip_quest.get("reward_gold", 0))
	gold += reward_payout
	active_vip_quest["completed"] = true
	save_game()
	inventory_changed.emit()
	vip_quest_updated.emit()
	return true


# ==============================================================================
# Inventory & Weight Calculations
# ==============================================================================

## Checks if an item with relic_id can fit inside the backpack without exceeding max_weight.
func can_add_item(relic_id: String) -> bool:
	if not RELIC_DB.has(relic_id):
		push_warning("Backpack: Unknown relic_id '%s'" % relic_id)
		return false

	var relic_data: Dictionary = RELIC_DB[relic_id]
	var item_weight: float = float(relic_data.get("weight", 0.0))
	return (current_weight + item_weight) <= (max_weight + 0.001)


## Attempts to add a relic into the backpack. Newly salvaged relics start with identified = false (encrusted).
func add_item(relic_id: String, is_identified: bool = false) -> bool:
	if not can_add_item(relic_id):
		return false

	var base_data: Dictionary = RELIC_DB[relic_id]
	var item_instance: Dictionary = base_data.duplicate(true)

	# Architectural blueprints immediately grant +1 blueprint and are already legible
	if relic_id == "blueprint_tube":
		blueprints += 1
		item_instance["identified"] = true
	else:
		item_instance["identified"] = is_identified

	items.append(item_instance)
	_recalculate_weight()

	item_added.emit(item_instance)
	inventory_changed.emit()
	return true


## Cleans an encrusted relic at index, setting identified = true, harvesting crust, and unlocking in Codex!
func clean_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	items[index]["identified"] = true
	var rid: String = str(items[index].get("id", ""))
	discovered_relics[rid] = true

	cleaned_crust_units += 1
	save_game()
	inventory_changed.emit()
	return items[index]


## Unlocks a room wing in the Survivor's Home using gold and blueprints.
func unlock_room(room_id: String, gold_cost: int, bp_cost: int) -> bool:
	if gold >= gold_cost and blueprints >= bp_cost:
		gold -= gold_cost
		blueprints -= bp_cost
		unlocked_rooms[room_id] = true
		save_game()
		inventory_changed.emit()
		play_sfx("cash")
		return true
	return false


## Removes the item at index from the items array, subtracts weight, emits item_dropped, and returns item.
func remove_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	var removed_item: Dictionary = items[index]
	items.remove_at(index)
	var item_weight: float = float(removed_item.get("weight", 0.0))
	current_weight = maxf(0.0, snappedf(current_weight - item_weight, 0.01))

	var relic_id: String = str(removed_item.get("id", ""))
	item_removed.emit(removed_item)
	item_dropped.emit(relic_id)
	inventory_changed.emit()
	return removed_item


## Removes item at index WITHOUT emitting item_dropped (used when placing on a pedestal or selling).
func consume_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	var removed_item: Dictionary = items[index]
	items.remove_at(index)
	var item_weight: float = float(removed_item.get("weight", 0.0))
	current_weight = maxf(0.0, snappedf(current_weight - item_weight, 0.01))

	item_removed.emit(removed_item)
	inventory_changed.emit()
	return removed_item


## Removes an item at a specific inventory index.
func remove_item(index: int) -> bool:
	var res = remove_item_at(index)
	return not res.is_empty()


## Clears all items from the backpack.
func clear_inventory() -> void:
	items.clear()
	current_weight = 0.0
	inventory_changed.emit()


## Calculates the total museum/scrap value of all relics currently held (including set completion buff).
func get_total_value() -> int:
	var total: int = 0
	var mult: float = get_salvage_value_multiplier()
	for item in items:
		total += int(round(float(item.get("value", 0)) * mult))
	return total


## Returns true if current weight exceeds 70% of max capacity.
func is_encumbered() -> bool:
	return current_weight > (max_weight * 0.7)


## Calculates the encumbrance factor between 0.0 (normal) and 1.0 (at maximum capacity).
func get_encumbrance_factor() -> float:
	var threshold: float = max_weight * 0.7
	if current_weight <= threshold:
		return 0.0
	return clampf((current_weight - threshold) / (max_weight - threshold), 0.0, 1.0)


## Recalculates total weight rounded to 2 decimal places.
func _recalculate_weight() -> void:
	var total_w: float = 0.0
	for item in items:
		total_w += float(item.get("weight", 0.0))
	current_weight = snappedf(total_w, 0.01)


# ==============================================================================
# Upgrades & Pedestals
# ==============================================================================

func get_oxygen_upgrade_cost() -> int:
	return oxygen_level * 100

func get_fins_upgrade_cost() -> int:
	return fins_level * 120

func get_exo_upgrade_cost() -> int:
	return exo_level * 150

func upgrade_oxygen() -> bool:
	var cost: int = get_oxygen_upgrade_cost()
	if gold >= cost:
		gold -= cost
		oxygen_level += 1
		max_oxygen = 100.0 + float(oxygen_level - 1) * 25.0
		play_sfx("cash")
		save_game()
		inventory_changed.emit()
		return true
	return false

func upgrade_fins() -> bool:
	var cost: int = get_fins_upgrade_cost()
	if gold >= cost:
		gold -= cost
		fins_level += 1
		swim_speed = 200.0 + float(fins_level - 1) * 35.0
		play_sfx("cash")
		save_game()
		inventory_changed.emit()
		return true
	return false

func upgrade_exo() -> bool:
	var cost: int = get_exo_upgrade_cost()
	if gold >= cost:
		gold -= cost
		exo_level += 1
		max_weight = 15.0 + float(exo_level - 1) * 7.5
		play_sfx("cash")
		save_game()
		inventory_changed.emit()
		return true
	return false

func set_pedestal_relic(pedestal_idx: int, relic_id: String) -> void:
	exhibited_relics[pedestal_idx] = relic_id
	save_game()
	inventory_changed.emit()

func clear_pedestal_relic(pedestal_idx: int) -> void:
	exhibited_relics.erase(pedestal_idx)
	save_game()
	inventory_changed.emit()


# ==============================================================================
# Global Human History Codex UI (CanvasLayer)
# ==============================================================================

## Toggles the global Human Civilization Codex modal UI
func toggle_codex_ui() -> void:
	if _codex_layer == null:
		_create_codex_ui()

	if _codex_modal == null:
		return

	_codex_modal.visible = not _codex_modal.visible
	if _codex_modal.visible:
		_populate_codex_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C or event.keycode == KEY_C:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			toggle_codex_ui()
		elif (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE) and _codex_modal != null and _codex_modal.visible:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			_codex_modal.visible = false


func _create_codex_ui() -> void:
	_codex_layer = CanvasLayer.new()
	_codex_layer.name = "CodexCanvasLayer"
	_codex_layer.layer = 20
	add_child(_codex_layer)

	_codex_modal = Control.new()
	_codex_modal.name = "CodexModal"
	_codex_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_codex_modal.visible = false
	_codex_layer.add_child(_codex_modal)

	# Fullscreen darkened backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.08, 0.88)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_codex_modal.add_child(backdrop)

	# Centered main frame panel (960 x 580)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(960.0, 580.0)
	panel.position = Vector2(-480.0, -290.0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.98)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.2, 0.75, 0.9)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	_codex_modal.add_child(panel)

	var root_margin := MarginContainer.new()
	root_margin.add_theme_constant_override("margin_left", 24)
	root_margin.add_theme_constant_override("margin_right", 24)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	root_margin.add_child(main_vbox)

	# Header bar
	var header_bar := HBoxContainer.new()
	main_vbox.add_child(header_bar)

	var title_lbl := Label.new()
	title_lbl.name = "CodexTitleLabel"
	title_lbl.text = "HUMAN CIVILIZATION CODEX  •  ARCHIVES"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	header_bar.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = " [X] Close (ESC / C) "
	close_btn.custom_minimum_size = Vector2(160.0, 32.0)
	close_btn.pressed.connect(func(): _codex_modal.visible = false)
	header_bar.add_child(close_btn)

	# Scrollable container for sets and relic cards
	_codex_scroll = ScrollContainer.new()
	_codex_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_codex_scroll)

	_codex_content_vbox = VBoxContainer.new()
	_codex_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_content_vbox.add_theme_constant_override("separation", 18)
	_codex_scroll.add_child(_codex_content_vbox)


func _populate_codex_ui() -> void:
	if _codex_content_vbox == null:
		return

	for c in _codex_content_vbox.get_children():
		c.queue_free()

	# Count discovered relics out of 8
	var all_relic_ids: Array[String] = [
		"relic_keyboard", "relic_mouse", "relic_core",
		"relic_cup", "relic_toaster", "relic_console",
		"relic_dogtag", "relic_mask"
	]
	var total_discovered: int = 0
	for rid in all_relic_ids:
		if discovered_relics.get(rid, false):
			total_discovered += 1

	var sets_def: Array[Dictionary] = [
		{
			"set_name": "21st Century Computing",
			"bonus_desc": "+20% Scrap & Museum Salvage Value",
			"relics": ["relic_keyboard", "relic_mouse", "relic_core"]
		},
		{
			"set_name": "Daily Café Life",
			"bonus_desc": "+15 Max Oxygen Capacity",
			"relics": ["relic_cup", "relic_toaster", "relic_console"]
		},
		{
			"set_name": "Resource War Remnants",
			"bonus_desc": "+25 Swim Speed (Hydro-Dynamics)",
			"relics": ["relic_dogtag", "relic_mask"]
		}
	]

	# Summary banner
	var summary_lbl := Label.new()
	summary_lbl.text = "Archival Progress: %d / 8 Relics Decoded  •  Completed Sets: %d / 3" % [
		total_discovered,
		get_completed_sets().size()
	]
	summary_lbl.add_theme_font_size_override("font_size", 14)
	summary_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.98))
	_codex_content_vbox.add_child(summary_lbl)

	for s_info in sets_def:
		var s_name: String = str(s_info["set_name"])
		var bonus_text: String = str(s_info["bonus_desc"])
		var s_relics: Array = s_info["relics"]
		var is_comp: bool = is_set_completed(s_name)

		# Set Section Container
		var set_box := VBoxContainer.new()
		set_box.add_theme_constant_override("separation", 6)
		_codex_content_vbox.add_child(set_box)

		# Set Header
		var s_header := HBoxContainer.new()
		set_box.add_child(s_header)

		var s_name_lbl := Label.new()
		s_name_lbl.text = "■ " + s_name.to_upper()
		s_name_lbl.add_theme_font_size_override("font_size", 16)
		s_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4) if is_comp else Color(0.7, 0.8, 0.9))
		s_header.add_child(s_name_lbl)

		var s_spacer := Control.new()
		s_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_header.add_child(s_spacer)

		var badge_lbl := Label.new()
		if is_comp:
			badge_lbl.text = "★ [SET COMPLETED] Active Buff: " + bonus_text
			badge_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
		else:
			badge_lbl.text = "🔒 [LOCKED] Inactive Buff: " + bonus_text
			badge_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		badge_lbl.add_theme_font_size_override("font_size", 13)
		s_header.add_child(badge_lbl)

		# Relic Cards Grid / HBox
		var cards_hbox := HBoxContainer.new()
		cards_hbox.add_theme_constant_override("separation", 10)
		set_box.add_child(cards_hbox)

		for rid in s_relics:
			var r_data: Dictionary = RELIC_DB.get(rid, {})
			var is_unlocked: bool = bool(discovered_relics.get(rid, false))

			var card := PanelContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.custom_minimum_size = Vector2(280.0, 110.0)

			var card_sb := StyleBoxFlat.new()
			card_sb.corner_radius_top_left = 6
			card_sb.corner_radius_top_right = 6
			card_sb.corner_radius_bottom_left = 6
			card_sb.corner_radius_bottom_right = 6

			if is_unlocked:
				card_sb.bg_color = Color(0.09, 0.13, 0.2, 0.9)
				card_sb.border_width_left = 2
				card_sb.border_width_right = 2
				card_sb.border_width_top = 2
				card_sb.border_width_bottom = 2
				card_sb.border_color = r_data.get("color", Color.CYAN)
			else:
				card_sb.bg_color = Color(0.05, 0.07, 0.1, 0.85)
				card_sb.border_width_left = 1
				card_sb.border_width_right = 1
				card_sb.border_width_top = 1
				card_sb.border_width_bottom = 1
				card_sb.border_color = Color(0.2, 0.25, 0.3)

			card.add_theme_stylebox_override("panel", card_sb)
			cards_hbox.add_child(card)

			var c_margin := MarginContainer.new()
			c_margin.add_theme_constant_override("margin_left", 10)
			c_margin.add_theme_constant_override("margin_right", 10)
			c_margin.add_theme_constant_override("margin_top", 8)
			c_margin.add_theme_constant_override("margin_bottom", 8)
			card.add_child(c_margin)

			var c_vbox := VBoxContainer.new()
			c_vbox.add_theme_constant_override("separation", 3)
			c_margin.add_child(c_vbox)

			if is_unlocked:
				var name_lbl := Label.new()
				name_lbl.text = str(r_data.get("name", "Relic"))
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				name_lbl.add_theme_font_size_override("font_size", 13)
				name_lbl.add_theme_color_override("font_color", r_data.get("color", Color.WHITE))
				c_vbox.add_child(name_lbl)

				var stats_lbl := Label.new()
				stats_lbl.text = "[%s]  •  %.1f kg  •  $%d Scrap" % [
					str(r_data.get("rarity", "Common")),
					float(r_data.get("weight", 1.0)),
					int(r_data.get("value", 100))
				]
				stats_lbl.add_theme_font_size_override("font_size", 11)
				stats_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
				c_vbox.add_child(stats_lbl)

				var desc_lbl := Label.new()
				desc_lbl.text = "\"%s\"" % str(r_data.get("alien_desc", ""))
				desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				desc_lbl.add_theme_font_size_override("font_size", 10)
				desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.8, 0.85))
				c_vbox.add_child(desc_lbl)
			else:
				var unknown_title := Label.new()
				unknown_title.text = "🔒 [??? Undiscovered Relic]"
				unknown_title.add_theme_font_size_override("font_size", 13)
				unknown_title.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
				c_vbox.add_child(unknown_title)

				var hint_depth := Label.new()
				hint_depth.text = "Depth Zone: %dm+  •  Rarity: %s" % [
					int(r_data.get("min_depth", 10)),
					str(r_data.get("rarity", "Common"))
				]
				hint_depth.add_theme_font_size_override("font_size", 11)
				hint_depth.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
				c_vbox.add_child(hint_depth)

				var clean_hint := Label.new()
				clean_hint.text = "Salvage from trench and clean at Home Lab to decipher."
				clean_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
				clean_hint.add_theme_font_size_override("font_size", 10)
				clean_hint.add_theme_color_override("font_color", Color(0.35, 0.4, 0.45))
				c_vbox.add_child(clean_hint)


# ==============================================================================
# Save / Load Persistence System
# ==============================================================================

func _serialize_items() -> Array:
	var serialized: Array = []
	for it in items:
		serialized.append({
			"id": str(it.get("id", "")),
			"identified": bool(it.get("identified", false))
		})
	return serialized


func _deserialize_items(loaded_list: Array) -> void:
	items.clear()
	for entry in loaded_list:
		if entry is Dictionary:
			var rid: String = str(entry.get("id", ""))
			var is_id: bool = bool(entry.get("identified", false))
			if RELIC_DB.has(rid):
				var inst: Dictionary = RELIC_DB[rid].duplicate(true)
				inst["identified"] = is_id
				items.append(inst)
	_recalculate_weight()


func save_game() -> void:
	var save_dict: Dictionary = {
		"version": 2,
		"gold": gold,
		"current_day": current_day,
		"daily_museum_earnings": daily_museum_earnings,
		"oxygen_level": oxygen_level,
		"max_oxygen": max_oxygen,
		"fins_level": fins_level,
		"swim_speed": swim_speed,
		"exo_level": exo_level,
		"max_weight": max_weight,
		"blueprints": blueprints,
		"cleaned_crust_units": cleaned_crust_units,
		"unlocked_rooms": unlocked_rooms,
		"exhibited_relics": exhibited_relics,
		"discovered_relics": discovered_relics,
		"active_vip_quest": active_vip_quest,
		"items": _serialize_items()
	}

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	if content.strip_edges().is_empty():
		return

	var data = JSON.parse_string(content)
	if not (data is Dictionary):
		return

	gold = int(data.get("gold", 300))
	current_day = int(data.get("current_day", 1))
	daily_museum_earnings = int(data.get("daily_museum_earnings", 0))
	oxygen_level = int(data.get("oxygen_level", 1))
	max_oxygen = float(data.get("max_oxygen", 100.0))
	fins_level = int(data.get("fins_level", 1))
	swim_speed = float(data.get("swim_speed", 200.0))
	exo_level = int(data.get("exo_level", 1))
	max_weight = float(data.get("max_weight", 15.0))
	blueprints = int(data.get("blueprints", 1))
	cleaned_crust_units = int(data.get("cleaned_crust_units", 0))

	# Unlocked rooms
	var loaded_rooms = data.get("unlocked_rooms", {})
	if loaded_rooms is Dictionary:
		for room_id in loaded_rooms.keys():
			unlocked_rooms[str(room_id)] = bool(loaded_rooms[room_id])

	# Exhibited relics
	exhibited_relics.clear()
	var loaded_exhibits = data.get("exhibited_relics", {})
	if loaded_exhibits is Dictionary:
		for k in loaded_exhibits.keys():
			exhibited_relics[int(k)] = str(loaded_exhibits[k])

	# Discovered relics
	discovered_relics.clear()
	var loaded_disc = data.get("discovered_relics", {})
	if loaded_disc is Dictionary:
		for k in loaded_disc.keys():
			discovered_relics[str(k)] = bool(loaded_disc[k])

	# Active VIP Quest
	var loaded_quest = data.get("active_vip_quest", {})
	if loaded_quest is Dictionary and not loaded_quest.is_empty():
		active_vip_quest = loaded_quest
	else:
		active_vip_quest = {}

	# Items
	var loaded_items = data.get("items", [])
	if loaded_items is Array:
		_deserialize_items(loaded_items)
	else:
		items.clear()
		_recalculate_weight()

	inventory_changed.emit()


func reset_save_data() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)

	gold = 300
	current_day = 1
	daily_museum_earnings = 0
	oxygen_level = 1
	max_oxygen = 100.0
	fins_level = 1
	swim_speed = 200.0
	exo_level = 1
	max_weight = 15.0
	blueprints = 1
	cleaned_crust_units = 0
	items.clear()
	current_weight = 0.0
	exhibited_relics.clear()
	discovered_relics.clear()
	active_vip_quest.clear()
	unlocked_rooms = {
		"main_hall": true,
		"cleaning_lab": true,
		"archive_study": false,
		"bio_recycler": false
	}
	generate_daily_vip_quest()
	save_game()
	inventory_changed.emit()
