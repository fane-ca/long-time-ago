extends Node

## BackpackManager: Global Autoload Singleton (Backpack)
## Manages salvage inventory, weight limits, human relic database,
## Alien VIP quests, Human Civilization Codex, and Smart Sprite loading.

signal inventory_changed
signal item_added(item: Dictionary)
signal item_removed(item: Dictionary)
signal item_dropped(relic_id: String)
signal vip_quest_updated
signal gravity_settled(moved_items: Dictionary)

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
const GRID_UNIT_PX: float = 32.0

## Master Building & Character Asset Registry
## Defines canonical sprite file paths and target in-game pixel dimensions [width_px, height_px]
const ASSET_CATALOG: Dictionary = {
	"characters": {
		"diver": {
			"id": "diver",
			"sprite_path": "res://assets/characters/diver.png",
			"target_px": [72, 72]
		},
		"survivor": {
			"id": "survivor",
			"sprite_path": "res://assets/characters/survivor.png",
			"target_px": [64, 64]
		}
	},
	"buildings": {
		"museum": {
			"id": "museum",
			"sprite_path": "res://assets/buildings/museum.png",
			"target_px": [256, 256]
		},
		"home": {
			"id": "home",
			"sprite_path": "res://assets/buildings/home.png",
			"target_px": [256, 256]
		},
		"workshop_o2": {
			"id": "workshop_o2",
			"sprite_path": "res://assets/buildings/workshop_o2.png",
			"target_px": [192, 192]
		},
		"workshop_exo": {
			"id": "workshop_exo",
			"sprite_path": "res://assets/buildings/workshop_exo.png",
			"target_px": [192, 192]
		}
	}
}

## Fallback Master Item Library in case res://relics_data.json is missing or corrupted
var RELIC_DB: Dictionary = {
	"relic_keyboard": {
		"id": "relic_keyboard",
		"name": "Barnacle-Crusted Mechanical Keyboard",
		"set": "21st Century Computing",
		"set_name": "21st Century Computing",
		"value": 150,
		"rarity": "Common",
		"min_depth": 15.0,
		"lore": "Ancient ritual altar with 104 clickable tactile switches once used to commune with silicon gods.",
		"alien_desc": "Ancient ritual altar with 104 clickable tactile switches once used to commune with silicon gods.",
		"size_3d": [3, 1, 2],
		"weight": 2,
		"fragile": false,
		"color": Color.CYAN,
		"color_hex": "#00ffff",
		"sprite_path": "res://assets/relics/relic_keyboard.png",
		"icon_path": "res://assets/relics/relic_keyboard.png",
		"target_px": [96, 32],
		"ai_prompt": ""
	},
	"relic_mouse": {
		"id": "relic_mouse",
		"name": "Optical Gaming Mouse",
		"set": "21st Century Computing",
		"set_name": "21st Century Computing",
		"value": 110,
		"rarity": "Common",
		"min_depth": 25.0,
		"lore": "Handheld tracking rodent with a glowing cyan optical eye and braided tail.",
		"alien_desc": "Handheld tracking rodent with a glowing cyan optical eye and braided tail.",
		"size_3d": [1, 1, 1],
		"weight": 1,
		"fragile": false,
		"color": Color(0.2, 0.73, 1.0),
		"color_hex": "#33bbff",
		"sprite_path": "res://assets/relics/relic_mouse.png",
		"icon_path": "res://assets/relics/relic_mouse.png",
		"target_px": [32, 32],
		"ai_prompt": ""
	},
	"relic_core": {
		"id": "relic_core",
		"name": "Sunken AI Server Core",
		"set": "21st Century Computing",
		"set_name": "21st Century Computing",
		"value": 650,
		"rarity": "Legendary",
		"min_depth": 160.0,
		"lore": "Heavy quantum-silicon monolith preserving fragments of pre-war human digital consciousness.",
		"alien_desc": "Heavy quantum-silicon monolith preserving fragments of pre-war human digital consciousness.",
		"size_3d": [2, 3, 2],
		"weight": 5,
		"fragile": true,
		"color": Color.MAGENTA,
		"color_hex": "#ff00ff",
		"sprite_path": "res://assets/relics/relic_core.png",
		"icon_path": "res://assets/relics/relic_core.png",
		"target_px": [64, 96],
		"ai_prompt": ""
	},
	"relic_cup": {
		"id": "relic_cup",
		"name": "Rusty Thermal Mug",
		"set": "Daily Café Life",
		"set_name": "Daily Café Life",
		"value": 80,
		"rarity": "Common",
		"min_depth": 10.0,
		"lore": "Insulated vessel once used to hold dark caffeinated morning stimulant for office workers.",
		"alien_desc": "Insulated vessel once used to hold dark caffeinated morning stimulant for office workers.",
		"size_3d": [1, 2, 1],
		"weight": 1,
		"fragile": true,
		"color": Color.ORANGE,
		"color_hex": "#ff9933",
		"sprite_path": "res://assets/relics/relic_cup.png",
		"icon_path": "res://assets/relics/relic_cup.png",
		"target_px": [32, 64],
		"ai_prompt": ""
	},
	"relic_toaster": {
		"id": "relic_toaster",
		"name": "Chrome Bread Warmer",
		"set": "Daily Café Life",
		"set_name": "Daily Café Life",
		"value": 240,
		"rarity": "Rare",
		"min_depth": 85.0,
		"lore": "Dual-slot thermal catapult designed to scorch carbohydrate slices to golden perfection.",
		"alien_desc": "Dual-slot thermal catapult designed to scorch carbohydrate slices to golden perfection.",
		"size_3d": [2, 2, 2],
		"weight": 3,
		"fragile": false,
		"color": Color(1.0, 0.84, 0.0),
		"color_hex": "#ffd700",
		"sprite_path": "res://assets/relics/relic_toaster.png",
		"icon_path": "res://assets/relics/relic_toaster.png",
		"target_px": [64, 64],
		"ai_prompt": ""
	},
	"relic_console": {
		"id": "relic_console",
		"name": "Ancient Handheld Console",
		"set": "Daily Café Life",
		"set_name": "Daily Café Life",
		"value": 380,
		"rarity": "Rare",
		"min_depth": 110.0,
		"lore": "Portable silicon entertainment brick with a directional cross pad and glowing pixel screen.",
		"alien_desc": "Portable silicon entertainment brick with a directional cross pad and glowing pixel screen.",
		"size_3d": [2, 2, 1],
		"weight": 2,
		"fragile": true,
		"color": Color(1.0, 0.33, 0.53),
		"color_hex": "#ff5588",
		"sprite_path": "res://assets/relics/relic_console.png",
		"icon_path": "res://assets/relics/relic_console.png",
		"target_px": [64, 64],
		"ai_prompt": ""
	},
	"relic_dogtag": {
		"id": "relic_dogtag",
		"name": "Tarnished Titanium Dogtags",
		"set": "Resource War Remnants",
		"set_name": "Resource War Remnants",
		"value": 190,
		"rarity": "Common",
		"min_depth": 45.0,
		"lore": "Stamped metal identity plates worn by pre-war oceanic defense personnel.",
		"alien_desc": "Stamped metal identity plates worn by pre-war oceanic defense personnel.",
		"size_3d": [1, 1, 1],
		"weight": 1,
		"fragile": false,
		"color": Color(0.75, 0.75, 0.75),
		"color_hex": "#c0c0c0",
		"sprite_path": "res://assets/relics/relic_dogtag.png",
		"icon_path": "res://assets/relics/relic_dogtag.png",
		"target_px": [32, 32],
		"ai_prompt": ""
	},
	"relic_mask": {
		"id": "relic_mask",
		"name": "Cracked Gas Mask",
		"set": "Resource War Remnants",
		"set_name": "Resource War Remnants",
		"value": 280,
		"rarity": "Rare",
		"min_depth": 95.0,
		"lore": "Late-war synthetic breathing apparatus with cracked reinforced lenses from the final coastal evacuation.",
		"alien_desc": "Late-war synthetic breathing apparatus with cracked reinforced lenses from the final coastal evacuation.",
		"size_3d": [2, 2, 1],
		"weight": 1,
		"fragile": true,
		"color": Color.GREEN_YELLOW,
		"color_hex": "#adff2f",
		"sprite_path": "res://assets/relics/relic_mask.png",
		"icon_path": "res://assets/relics/relic_mask.png",
		"target_px": [64, 64],
		"ai_prompt": ""
	},
	"blueprint_tube": {
		"id": "blueprint_tube",
		"name": "Pre-War Architectural Blueprint",
		"set": "Survivor Technology",
		"set_name": "Survivor Technology",
		"value": 200,
		"rarity": "Rare",
		"min_depth": 40.0,
		"lore": "Hermetically sealed alloy canister holding modular human habitat expansion schematics.",
		"alien_desc": "Hermetically sealed alloy canister holding modular human habitat expansion schematics.",
		"size_3d": [2, 1, 1],
		"weight": 1,
		"fragile": false,
		"color": Color.DEEP_SKY_BLUE,
		"color_hex": "#00bfff",
		"sprite_path": "res://assets/relics/relic_blueprint.png",
		"icon_path": "res://assets/relics/relic_blueprint.png",
		"target_px": [64, 32],
		"ai_prompt": ""
	}
}

## List of collected relic instances currently in the backpack
## Each item includes: { "uid": int, "id": String, "cleaned": bool, "identified": bool, "pos": Vector3i, "size": Vector3i, ... }
var items: Array[Dictionary] = []

## 3D Volumetric Grid: grid_3d[x][y][z] holds item uid (int) or -1 if empty
var grid_3d: Array = []
var _next_item_uid: int = 1

## Current cumulative cargo weight in kilograms
var current_weight: float = 0.0

## Global 3D Volumetric Crate Inspector UI (CanvasLayer)
var _crate_layer: CanvasLayer = null
var _crate_modal: Control = null
var _crate_viewport: Control = null
var _crate_stats_label: Label = null
var _crate_layer_bar: HBoxContainer = null
var _crate_inspector_title: Label = null
var _crate_inspector_meta: Label = null
var _crate_inspector_lore: Label = null
var _crate_drop_btn: Button = null
var _crate_status_label: Label = null

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
	_rebuild_grid_3d()
	load_game()
	_rebuild_grid_3d()
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


## Normalizes a Master Item Library entry, ensuring standardized 3D/asset fields
## and backward-compatible aliases (set_name, alien_desc, icon_path) are populated.
func _normalize_relic_entry(relic_id: String, raw: Dictionary) -> Dictionary:
	var r_data: Dictionary = raw.duplicate(true)
	r_data["id"] = str(r_data.get("id", relic_id))

	# Standardize "set" <-> "set_name"
	var set_val: String = str(r_data.get("set", r_data.get("set_name", "Unknown Set")))
	r_data["set"] = set_val
	r_data["set_name"] = set_val

	# Standardize "lore" <-> "alien_desc"
	var lore_val: String = str(r_data.get("lore", r_data.get("alien_desc", "")))
	r_data["lore"] = lore_val
	r_data["alien_desc"] = lore_val

	# Standardize "sprite_path" <-> "icon_path"
	var path_val: String = str(r_data.get("sprite_path", r_data.get("icon_path", "res://assets/relics/%s.png" % relic_id)))
	r_data["sprite_path"] = path_val
	r_data["icon_path"] = path_val

	# Standardize 3D volume grid dimensions [width_x, height_y, thickness_z]
	var s3d = r_data.get("size_3d", [1, 1, 1])
	var sx: int = 1
	var sy: int = 1
	var sz: int = 1
	if s3d is Array and s3d.size() >= 3:
		sx = maxi(int(s3d[0]), 1)
		sy = maxi(int(s3d[1]), 1)
		sz = maxi(int(s3d[2]), 1)
	r_data["size_3d"] = [sx, sy, sz]

	# Standardize target_px [width_px, height_px] proportionally from size_3d (1 unit = 32px)
	var tpx = r_data.get("target_px", [])
	if tpx is Array and tpx.size() >= 2 and float(tpx[0]) > 0.0 and float(tpx[1]) > 0.0:
		r_data["target_px"] = [int(tpx[0]), int(tpx[1])]
	else:
		r_data["target_px"] = [int(sx * GRID_UNIT_PX), int(sy * GRID_UNIT_PX)]

	# Standardize weight (int 1..5) and fragile (bool)
	r_data["weight"] = clampi(int(round(float(r_data.get("weight", 1)))), 1, 5)
	r_data["fragile"] = bool(r_data.get("fragile", false))
	r_data["ai_prompt"] = str(r_data.get("ai_prompt", ""))

	# Ensure Color property exists from color_hex
	if r_data.has("color_hex"):
		r_data["color"] = Color.from_string(str(r_data["color_hex"]), Color.WHITE)
	elif not r_data.has("color"):
		r_data["color"] = Color.WHITE

	return r_data


## Loads data-driven Master Item Library definitions from res://relics_data.json
func _load_relics_from_json() -> void:
	# Always normalize fallback entries first
	for fallback_key in RELIC_DB.keys():
		RELIC_DB[fallback_key] = _normalize_relic_entry(str(fallback_key), RELIC_DB[fallback_key])

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
			if parsed[k] is Dictionary:
				RELIC_DB[str(k)] = _normalize_relic_entry(str(k), parsed[k])


## Looks up a canonical asset specification (sprite_path & target_px) by asset ID or file path
## across ASSET_CATALOG (characters, buildings) and RELIC_DB (relics).
func get_asset_spec(id_or_path: String) -> Dictionary:
	if id_or_path.is_empty():
		return {}

	# 1. Direct key lookup in ASSET_CATALOG categories
	for category in ASSET_CATALOG.keys():
		var group: Dictionary = ASSET_CATALOG[category]
		if group.has(id_or_path):
			return group[id_or_path]
		for entry_id in group.keys():
			var spec: Dictionary = group[entry_id]
			if str(spec.get("sprite_path", "")) == id_or_path:
				return spec

	# 2. Direct key or sprite_path lookup in RELIC_DB
	if RELIC_DB.has(id_or_path):
		return RELIC_DB[id_or_path]
	for rid in RELIC_DB.keys():
		var r_spec: Dictionary = RELIC_DB[rid]
		if str(r_spec.get("sprite_path", "")) == id_or_path or str(r_spec.get("icon_path", "")) == id_or_path:
			return r_spec

	return {}


## Returns the 3D backpack grid volume (width_x, height_y, thickness_z) for a relic.
func get_relic_size_3d(relic_id: String) -> Vector3i:
	var r_data: Dictionary = RELIC_DB.get(relic_id, {})
	var s3d = r_data.get("size_3d", [1, 1, 1])
	if s3d is Array and s3d.size() >= 3:
		return Vector3i(maxi(int(s3d[0]), 1), maxi(int(s3d[1]), 1), maxi(int(s3d[2]), 1))
	return Vector3i(1, 1, 1)


## Returns the canonical target display pixel size Vector2(width_px, height_px) for a relic.
## Reads "target_px" directly or computes proportionally from "size_3d" (1 unit = 32px).
func get_relic_target_px(relic_id: String) -> Vector2:
	var r_data: Dictionary = RELIC_DB.get(relic_id, {})
	var tpx = r_data.get("target_px", [])
	if tpx is Array and tpx.size() >= 2 and float(tpx[0]) > 0.0 and float(tpx[1]) > 0.0:
		return Vector2(float(tpx[0]), float(tpx[1]))
	var s3d: Vector3i = get_relic_size_3d(relic_id)
	return Vector2(float(s3d.x) * GRID_UNIT_PX, float(s3d.y) * GRID_UNIT_PX)


# ==============================================================================
# Smart Sprite Auto-Loader Pipeline (Master Asset Registry Powered)
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


## Dynamically loads a PNG texture by registry ID ("museum", "diver", "relic_keyboard") OR res:// path.
## Automatically resolves "sprite_path" and "target_px" / "size_3d" from ASSET_CATALOG / RELIC_DB,
## scales any raw PNG resolution (e.g. 512x512, 1024x1024) proportionally to fit its exact in-game
## pixel bounds without aspect distortion, sets NEAREST filter, and hides procedural placeholders.
func load_smart_sprite(target_node: Node2D, path_or_id: String, target_size: Vector2 = Vector2.ZERO, pivot_offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	if target_node == null or path_or_id.is_empty():
		return null

	# Resolve registry specification from ASSET_CATALOG or RELIC_DB
	var spec: Dictionary = get_asset_spec(path_or_id)
	var resolved_path: String = path_or_id
	if not spec.is_empty():
		var spec_path: String = str(spec.get("sprite_path", ""))
		if not spec_path.is_empty():
			resolved_path = spec_path

	# Auto-populate target_size from registry target_px or size_3d if caller passed Vector2.ZERO
	var resolved_size: Vector2 = target_size
	if resolved_size == Vector2.ZERO and not spec.is_empty():
		var tpx = spec.get("target_px", [])
		if tpx is Array and tpx.size() >= 2 and float(tpx[0]) > 0.0 and float(tpx[1]) > 0.0:
			resolved_size = Vector2(float(tpx[0]), float(tpx[1]))
		elif spec.has("size_3d"):
			var s3d = spec["size_3d"]
			if s3d is Array and s3d.size() >= 2:
				resolved_size = Vector2(float(s3d[0]) * GRID_UNIT_PX, float(s3d[1]) * GRID_UNIT_PX)

	if not ResourceLoader.exists(resolved_path):
		return null

	var tex := load(resolved_path) as Texture2D
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
	var target_aspect: float = (resolved_size.x / resolved_size.y) if (resolved_size.y > 0.0) else 1.0
	var is_explicit_sheet: bool = resolved_path.contains("_sheet") or resolved_path.contains("_strip") or resolved_path.contains("_anim")
	# Only auto-slice horizontal strips if texture is >=2x wide AND target isn't already a wide static item (e.g. 3x1 keyboard)
	if th > 0.0 and tw >= th * 2.0 and (is_explicit_sheet or target_aspect <= 1.5):
		h_frames = int(tw / th)
		sprite.hframes = h_frames
		sprite.frame = 0
	else:
		sprite.hframes = 1
		sprite.frame = 0

	var frame_w: float = tw / float(h_frames)
	var frame_h: float = th
	if resolved_size != Vector2.ZERO and frame_w > 0.0 and frame_h > 0.0:
		# Uniform aspect-preserving fit so 512x512, 1024x1024, or non-square AI PNGs never squash or overflow target_px
		var uniform_scale: float = minf(resolved_size.x / frame_w, resolved_size.y / frame_h)
		sprite.scale = Vector2(uniform_scale, uniform_scale)
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
		var char_id: String = "diver" if is_swimming else "survivor"
		var char_tex_path: String = "res://assets/characters/%s.png" % char_id
		var target_px: Vector2 = Vector2(72.0, 72.0) if is_swimming else Vector2(64.0, 64.0)

		if bp_ref != null and bp_ref.has_method("get_asset_spec"):
			var spec: Dictionary = bp_ref.get_asset_spec(char_id)
			if not spec.is_empty():
				char_tex_path = str(spec.get("sprite_path", char_tex_path))
				var tpx = spec.get("target_px", [])
				if tpx is Array and tpx.size() >= 2:
					target_px = Vector2(float(tpx[0]), float(tpx[1]))

		var exists: bool = ResourceLoader.exists(char_tex_path) or FileAccess.file_exists(char_tex_path)
		if exists:
			var tex := load(char_tex_path) as Texture2D
			if tex != null:
				var spr := Sprite2D.new()
				spr.name = "CharacterSprite"
				spr.texture = tex
				spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

				var tex_w: float = float(tex.get_width())
				var tex_h: float = float(tex.get_height())
				var scale_factor: float = minf(target_px.x / maxf(tex_w, 1.0), target_px.y / maxf(tex_h, 1.0))
				spr.scale = Vector2(scale_factor, scale_factor)

				if is_swimming:
					spr.position = Vector2.ZERO
				else:
					spr.position = Vector2(0.0, -(tex_h * scale_factor) * 0.5)

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


## Builds a standardized multi-state visual node for a relic using RELIC_DB's sprite_path & target_px / size_3d:
## "underwater_buried", "encrusted_icon", "clean_icon", "pedestal_25d", "backpack_3d"
func build_relic_visual(relic_id: String, state: String, custom_target_px: Vector2 = Vector2.ZERO) -> Node2D:
	var root := RelicVisualNode.new()
	root.name = "RelicVisual_%s" % state
	root.visual_state = state

	var db: Dictionary = RELIC_DB
	var relic_data: Dictionary = db.get(relic_id, {})
	var r_color := Color.from_string(str(relic_data.get("color_hex", "#00ffff")), Color.CYAN)
	if relic_data.has("color") and relic_data["color"] is Color:
		r_color = relic_data["color"]
	root.relic_color = r_color

	var sprite_p: String = str(relic_data.get("sprite_path", relic_data.get("icon_path", "res://assets/relics/%s.png" % relic_id)))
	var target_px: Vector2 = custom_target_px if custom_target_px != Vector2.ZERO else get_relic_target_px(relic_id)

	if state == "underwater_buried":
		root.rotation = deg_to_rad(14.0)

		# 1. Base relic (custom buried PNG -> Master Library sprite_path -> procedural crystal)
		var custom_buried: String = "res://assets/relics/%s_buried.png" % relic_id
		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(custom_buried):
			loaded_spr = load_smart_sprite(root, custom_buried, target_px)
		elif ResourceLoader.exists(sprite_p):
			loaded_spr = load_smart_sprite(root, sprite_p, target_px)

		# 2. Pulsing underwater glint halo (added after smart sprite so it stays visible)
		var halo := Polygon2D.new()
		halo.name = "BuriedHalo"
		halo.z_index = -1
		halo.polygon = _make_ellipse(maxf(target_px.x * 0.45, 22.0), maxf(target_px.y * 0.35, 14.0))
		halo.color = Color(r_color.r, r_color.g, r_color.b, 0.26)
		root.add_child(halo)
		root.halo_poly = halo

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
			loaded_spr = load_smart_sprite(root, encrusted_p, target_px)

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

	elif state == "clean_icon" or state == "backpack_3d":
		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(sprite_p):
			loaded_spr = load_smart_sprite(root, sprite_p, target_px)

		if loaded_spr == null:
			var hw: float = target_px.x * 0.42
			var hh: float = target_px.y * 0.42
			var rim := Polygon2D.new()
			rim.polygon = PackedVector2Array([
				Vector2(-hw, -hh), Vector2(hw, -hh),
				Vector2(hw, hh), Vector2(-hw, hh)
			])
			rim.color = Color("#151D24")
			root.add_child(rim)

			var core := Polygon2D.new()
			core.polygon = PackedVector2Array([
				Vector2(-hw + 2.0, -hh + 2.0), Vector2(hw - 2.0, -hh + 2.0),
				Vector2(hw - 2.0, hh - 2.0), Vector2(-hw + 2.0, hh - 2.0)
			])
			core.color = r_color
			root.add_child(core)

			var dot := Polygon2D.new()
			dot.polygon = _make_ellipse(2.0, 2.0, Vector2(0.0, 0.0))
			dot.color = Color.WHITE
			root.add_child(dot)

	elif state == "pedestal_25d":
		var shadow := Polygon2D.new()
		shadow.name = "PedestalShadow"
		shadow.polygon = _make_ellipse(maxf(target_px.x * 0.35, 18.0), 8.0, Vector2(0.0, 8.0))
		shadow.color = Color(0.0, 0.0, 0.0, 0.45)
		root.add_child(shadow)

		var hover := Node2D.new()
		hover.name = "HoverContainer"
		hover.position = Vector2(0.0, -18.0)
		root.add_child(hover)
		root.hover_container = hover

		var loaded_spr: Sprite2D = null
		if ResourceLoader.exists(sprite_p):
			loaded_spr = load_smart_sprite(hover, sprite_p, target_px)

		var aura := Polygon2D.new()
		aura.name = "SpotlightAura"
		aura.z_index = -1
		aura.polygon = _make_ellipse(maxf(target_px.x * 0.42, 20.0), maxf(target_px.y * 0.32, 13.0))
		aura.color = Color(r_color.r, r_color.g, r_color.b, 0.32)
		hover.add_child(aura)

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
# 3D Volumetric Gravity Backpack Grid & Physics Engine
# ==============================================================================

## Returns the 3D backpack crate dimensions Vector3i(max_x, max_y, max_z) scaled by exo_level.
## Level 1: 5x6x2, Level 2: 6x7x3, Level 3: 7x8x4 (scales +1 per level above 3).
func get_grid_dimensions() -> Vector3i:
	var lvl: int = maxi(exo_level, 1)
	if lvl == 1:
		return Vector3i(5, 6, 2)
	elif lvl == 2:
		return Vector3i(6, 7, 3)
	elif lvl == 3:
		return Vector3i(7, 8, 4)
	return Vector3i(mini(4 + lvl, 9), mini(5 + lvl, 10), mini(1 + lvl, 5))


## Allocates an empty 3D grid array grid_3d[x][y][z] filled with -1.
func _allocate_empty_grid(dims: Vector3i) -> Array:
	var g: Array = []
	g.resize(dims.x)
	for x in range(dims.x):
		var col: Array = []
		col.resize(dims.y)
		for y in range(dims.y):
			var depth_row: Array = []
			depth_row.resize(dims.z)
			for z in range(dims.z):
				depth_row[z] = -1
			col[y] = depth_row
		g[x] = col
	return g


## Rebuilds grid_3d[x][y][z] from the current packed items list (optionally excluding ignore_uid).
func _rebuild_grid_3d(ignore_uid: int = -1) -> void:
	var dims: Vector3i = get_grid_dimensions()
	grid_3d = _allocate_empty_grid(dims)

	for it in items:
		var uid: int = int(it.get("uid", -1))
		if uid == -1 or uid == ignore_uid:
			continue
		var p: Vector3i = it.get("pos", Vector3i.ZERO)
		var s: Vector3i = it.get("size", Vector3i.ONE)
		_stamp_item_in_grid(p, s, uid)


func _stamp_item_in_grid(pos: Vector3i, size: Vector3i, uid: int) -> void:
	var dims: Vector3i = get_grid_dimensions()
	if grid_3d.size() != dims.x:
		return
	for dx in range(size.x):
		var cx: int = pos.x + dx
		if cx < 0 or cx >= dims.x:
			continue
		for dy in range(size.y):
			var cy: int = pos.y + dy
			if cy < 0 or cy >= dims.y:
				continue
			for dz in range(size.z):
				var cz: int = pos.z + dz
				if cz < 0 or cz >= dims.z:
					continue
				grid_3d[cx][cy][cz] = uid


func _clear_item_from_grid(pos: Vector3i, size: Vector3i, uid: int) -> void:
	var dims: Vector3i = get_grid_dimensions()
	if grid_3d.size() != dims.x:
		return
	for dx in range(size.x):
		var cx: int = pos.x + dx
		if cx < 0 or cx >= dims.x:
			continue
		for dy in range(size.y):
			var cy: int = pos.y + dy
			if cy < 0 or cy >= dims.y:
				continue
			for dz in range(size.z):
				var cz: int = pos.z + dz
				if cz < 0 or cz >= dims.z:
					continue
				if int(grid_3d[cx][cy][cz]) == uid:
					grid_3d[cx][cy][cz] = -1


## Checks whether an item of volume `size` can be placed at `pos` without colliding or leaving bounds.
func can_place_in_grid(pos: Vector3i, size: Vector3i, ignore_uid: int = -1) -> bool:
	var dims: Vector3i = get_grid_dimensions()
	if grid_3d.size() != dims.x:
		_rebuild_grid_3d()

	if pos.x < 0 or pos.y < 0 or pos.z < 0:
		return false
	if pos.x + size.x > dims.x or pos.y + size.y > dims.y or pos.z + size.z > dims.z:
		return false

	for dx in range(size.x):
		for dy in range(size.y):
			for dz in range(size.z):
				var cell_uid: int = int(grid_3d[pos.x + dx][pos.y + dy][pos.z + dz])
				if cell_uid != -1 and cell_uid != ignore_uid:
					return false
	return true


## Scans from the top opening (y = 0) across all (x, z) slots for a valid 3D entry volume.
## Tries default orientation first, then 90-deg X<->Y and X<->Z rotations if blocked.
func find_top_entry_slot(base_size: Vector3i) -> Dictionary:
	var dims: Vector3i = get_grid_dimensions()
	if grid_3d.size() != dims.x:
		_rebuild_grid_3d()

	var candidate_sizes: Array[Vector3i] = [base_size]
	var rot_xy := Vector3i(base_size.y, base_size.x, base_size.z)
	if not candidate_sizes.has(rot_xy):
		candidate_sizes.append(rot_xy)
	var flip_xz := Vector3i(base_size.z, base_size.y, base_size.x)
	if not candidate_sizes.has(flip_xz):
		candidate_sizes.append(flip_xz)
	var flip_yz := Vector3i(base_size.x, base_size.z, base_size.y)
	if not candidate_sizes.has(flip_yz):
		candidate_sizes.append(flip_yz)

	for sz in candidate_sizes:
		if sz.x > dims.x or sz.y > dims.y or sz.z > dims.z:
			continue
		for z in range(dims.z - sz.z + 1):
			for x in range(dims.x - sz.x + 1):
				var entry_pos := Vector3i(x, 0, z)
				if can_place_in_grid(entry_pos, sz):
					return {"found": true, "pos": entry_pos, "size": sz}

	return {"found": false, "pos": Vector3i(-1, -1, -1), "size": base_size}


## Predicts the resting Y coordinate an item placed at `pos` with `size` will fall to under gravity.
func predict_drop_y(pos: Vector3i, size: Vector3i, ignore_uid: int = -1) -> int:
	var dims: Vector3i = get_grid_dimensions()
	if not can_place_in_grid(pos, size, ignore_uid):
		return pos.y

	var cur_y: int = pos.y
	while cur_y + size.y < dims.y:
		var next_y: int = cur_y + 1
		if can_place_in_grid(Vector3i(pos.x, next_y, pos.z), size, ignore_uid):
			cur_y = next_y
		else:
			break
	return cur_y


## Applies 3D gravity physics to all packed items inside the backpack.
## Iterates bottom-to-top (y from max_y - 1 down to 0), dropping each item step-by-step
## whenever all cells beneath its (x, z) footprint are empty until hitting the floor or another item.
## Returns a Dictionary mapping moved uid -> { "from_y": int, "to_y": int }.
func apply_backpack_gravity(emit_signal_flag: bool = true) -> Dictionary:
	var dims: Vector3i = get_grid_dimensions()
	_rebuild_grid_3d()

	var initial_y_map: Dictionary = {}
	for it in items:
		var uid: int = int(it.get("uid", -1))
		var p: Vector3i = it.get("pos", Vector3i.ZERO)
		initial_y_map[uid] = p.y

	var any_moved_pass: bool = true
	var max_passes: int = dims.y + 4
	var pass_idx: int = 0

	while any_moved_pass and pass_idx < max_passes:
		any_moved_pass = false
		pass_idx += 1

		# Scan strictly bottom-to-top so lower items fall first and clear space for stacked items above
		for scan_y in range(dims.y - 1, -1, -1):
			for i in range(items.size()):
				var it: Dictionary = items[i]
				var uid: int = int(it.get("uid", -1))
				var pos: Vector3i = it.get("pos", Vector3i.ZERO)
				var sz: Vector3i = it.get("size", Vector3i.ONE)
				if pos.y + sz.y - 1 != scan_y:
					continue

				# Drop step-by-step while footprint underneath is completely empty
				while pos.y + sz.y < dims.y:
					var below_y: int = pos.y + sz.y
					var can_drop: bool = true
					for dx in range(sz.x):
						for dz in range(sz.z):
							var cell_uid: int = int(grid_3d[pos.x + dx][below_y][pos.z + dz])
							if cell_uid != -1:
								can_drop = false
								break
						if not can_drop:
							break

					if not can_drop:
						break

					# Shift item down by 1 unit in grid_3d
					for dx in range(sz.x):
						for dz in range(sz.z):
							grid_3d[pos.x + dx][pos.y][pos.z + dz] = -1
							grid_3d[pos.x + dx][below_y][pos.z + dz] = uid
					pos.y += 1
					it["pos"] = pos
					any_moved_pass = true

	var moved_items: Dictionary = {}
	for it in items:
		var uid: int = int(it.get("uid", -1))
		var final_y: int = (it.get("pos", Vector3i.ZERO) as Vector3i).y
		var start_y: int = int(initial_y_map.get(uid, final_y))
		if final_y != start_y:
			moved_items[uid] = {"from_y": start_y, "to_y": final_y}

	if emit_signal_flag and not moved_items.is_empty():
		gravity_settled.emit(moved_items)

	return moved_items


## Returns "" if relic_id can be added (weight + 3D top entry volume), or a descriptive error reason.
func get_add_item_error(relic_id: String) -> String:
	if not RELIC_DB.has(relic_id):
		return "Unknown Relic!"

	var relic_data: Dictionary = RELIC_DB[relic_id]
	var item_weight: float = float(relic_data.get("weight", 1.0))
	if (current_weight + item_weight) > (max_weight + 0.001):
		return "Backpack Too Heavy! (Max %.1f kg)" % max_weight

	var base_size: Vector3i = get_relic_size_3d(relic_id)
	var entry: Dictionary = find_top_entry_slot(base_size)
	if not bool(entry.get("found", false)):
		return "3D Cargo Volume Blocked!"

	return ""


## Checks if an item with relic_id can fit inside the backpack (both weight and 3D top-opening space).
func can_add_item(relic_id: String) -> bool:
	if not RELIC_DB.has(relic_id):
		push_warning("Backpack: Unknown relic_id '%s'" % relic_id)
		return false
	return get_add_item_error(relic_id).is_empty()


## Attempts to drop a salvaged relic through the top opening (y=0) of the 3D backpack
## and settles it to the lowest supported position under gravity.
func add_item(relic_id: String, is_identified: bool = false) -> bool:
	if not can_add_item(relic_id):
		return false

	var base_data: Dictionary = RELIC_DB[relic_id]
	var base_size: Vector3i = get_relic_size_3d(relic_id)
	var entry: Dictionary = find_top_entry_slot(base_size)
	if not bool(entry.get("found", false)):
		return false

	var item_instance: Dictionary = base_data.duplicate(true)
	var uid: int = _next_item_uid
	_next_item_uid += 1

	item_instance["uid"] = uid
	item_instance["id"] = relic_id
	item_instance["pos"] = entry["pos"]
	item_instance["size"] = entry["size"]

	# Architectural blueprints immediately grant +1 blueprint and are already legible
	if relic_id == "blueprint_tube":
		blueprints += 1
		item_instance["identified"] = true
		item_instance["cleaned"] = true
	else:
		item_instance["identified"] = is_identified
		item_instance["cleaned"] = is_identified

	items.append(item_instance)
	_recalculate_weight()
	_rebuild_grid_3d()
	apply_backpack_gravity(true)

	item_added.emit(item_instance)
	inventory_changed.emit()
	return true


## Returns item dictionary by unique 3D uid, or empty dictionary if not found.
func get_item_by_uid(uid: int) -> Dictionary:
	for it in items:
		if int(it.get("uid", -1)) == uid:
			return it
	return {}


## Returns index in `items` array for a given uid, or -1.
func get_item_index_by_uid(uid: int) -> int:
	for i in range(items.size()):
		if int(items[i].get("uid", -1)) == uid:
			return i
	return -1


## Places a dragged item at target_pos with new_size, then triggers 3D gravity settling.
## Returns Dictionary of moved items { uid -> { from_y, to_y } } if valid, or empty dict if rejected.
func place_item_at(uid: int, target_pos: Vector3i, new_size: Vector3i) -> Dictionary:
	var idx: int = get_item_index_by_uid(uid)
	if idx == -1:
		return {}

	_rebuild_grid_3d(uid)
	if not can_place_in_grid(target_pos, new_size, uid):
		_rebuild_grid_3d()
		return {}

	items[idx]["pos"] = target_pos
	items[idx]["size"] = new_size
	var moved: Dictionary = apply_backpack_gravity(true)
	save_game()
	inventory_changed.emit()
	return moved


## Removes an item by its 3D uid, dropping it if emit_drop is true, then settles items above via gravity.
func remove_item_by_uid(uid: int, emit_drop: bool = true) -> Dictionary:
	var idx: int = get_item_index_by_uid(uid)
	if idx == -1:
		return {}
	if emit_drop:
		return remove_item_at(idx)
	return consume_item_at(idx)


## Repacks all currently held items (largest volume first) cleanly into the 3D crate under gravity.
func auto_pack_all() -> Dictionary:
	var sorted_items: Array[Dictionary] = items.duplicate()
	sorted_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: Vector3i = a.get("size", Vector3i.ONE)
		var sb: Vector3i = b.get("size", Vector3i.ONE)
		var va: int = sa.x * sa.y * sa.z
		var vb: int = sb.x * sb.y * sb.z
		if va != vb:
			return va > vb
		return int(a.get("weight", 1)) > int(b.get("weight", 1))
	)

	var dims: Vector3i = get_grid_dimensions()
	grid_3d = _allocate_empty_grid(dims)
	var old_y: Dictionary = {}
	for it in sorted_items:
		old_y[int(it.get("uid", -1))] = (it.get("pos", Vector3i.ZERO) as Vector3i).y

	for it in sorted_items:
		var base_sz: Vector3i = get_relic_size_3d(str(it.get("id", "")))
		var entry: Dictionary = find_top_entry_slot(base_sz)
		if bool(entry.get("found", false)):
			var p: Vector3i = entry["pos"]
			var sz: Vector3i = entry["size"]
			var drop_y: int = predict_drop_y(p, sz)
			var final_p := Vector3i(p.x, drop_y, p.z)
			it["pos"] = final_p
			it["size"] = sz
			_stamp_item_in_grid(final_p, sz, int(it.get("uid", -1)))

	items = sorted_items
	var moved: Dictionary = apply_backpack_gravity(false)
	for it in items:
		var uid: int = int(it.get("uid", -1))
		var fy: int = (it.get("pos", Vector3i.ZERO) as Vector3i).y
		moved[uid] = {"from_y": 0, "to_y": fy}
	gravity_settled.emit(moved)
	save_game()
	inventory_changed.emit()
	return moved


func get_occupied_cells() -> int:
	var total: int = 0
	for it in items:
		var s: Vector3i = it.get("size", Vector3i.ONE)
		total += s.x * s.y * s.z
	return total


func get_total_cells() -> int:
	var d: Vector3i = get_grid_dimensions()
	return d.x * d.y * d.z


## Cleans an encrusted relic at index, setting identified/cleaned = true, harvesting crust, and unlocking in Codex!
func clean_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	items[index]["identified"] = true
	items[index]["cleaned"] = true
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


## Removes the item at index from the items array, subtracts weight, applies 3D gravity, emits item_dropped, and returns item.
func remove_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	var removed_item: Dictionary = items[index]
	items.remove_at(index)
	_recalculate_weight()
	_rebuild_grid_3d()
	apply_backpack_gravity(true)

	var relic_id: String = str(removed_item.get("id", ""))
	item_removed.emit(removed_item)
	item_dropped.emit(relic_id)
	inventory_changed.emit()
	return removed_item


## Removes item at index WITHOUT emitting item_dropped (used when placing on a pedestal or selling), then applies 3D gravity.
func consume_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}

	var removed_item: Dictionary = items[index]
	items.remove_at(index)
	_recalculate_weight()
	_rebuild_grid_3d()
	apply_backpack_gravity(true)

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
	_next_item_uid = 1
	current_weight = 0.0
	_rebuild_grid_3d()
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
		_rebuild_grid_3d()
		apply_backpack_gravity(true)
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
# Global 3D Volumetric Gravity Crate Inspector UI ([I] / [Tab])
# ==============================================================================

## Interactive 2.5D Isometric Cutaway Crate Renderer & Drag/Drop/Rotate Controller
class CrateViewport3D extends Control:
	const DEPTH_OFFSET: Vector2 = Vector2(14.0, -10.0)

	var bp_ref: Node = null
	var active_z_slice: int = 0
	var hovered_uid: int = -1
	var selected_uid: int = -1

	# Drag & 3D Rotate state
	var dragging_uid: int = -1
	var drag_orig_pos: Vector3i = Vector3i.ZERO
	var drag_orig_size: Vector3i = Vector3i.ONE
	var drag_size: Vector3i = Vector3i.ONE
	var drag_start_mouse: Vector2 = Vector2.ZERO
	var drag_has_moved: bool = false
	var drag_mouse_pos: Vector2 = Vector2.ZERO

	# Smooth falling visual Y coordinates per item uid (animated via bounce Tweens)
	var visual_y_map: Dictionary = {}
	var _active_tweens: Dictionary = {}
	var _tex_cache: Dictionary = {}

	var on_selection_changed: Callable = Callable()
	var on_status_message: Callable = Callable()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = false

	func _get_dims() -> Vector3i:
		if bp_ref != null and bp_ref.has_method("get_grid_dimensions"):
			return bp_ref.get_grid_dimensions()
		return Vector3i(5, 6, 2)

	func _get_cell_px() -> float:
		var dims: Vector3i = _get_dims()
		var avail_w: float = maxf(size.x - float(dims.z) * DEPTH_OFFSET.x - 44.0, 160.0)
		var avail_h: float = maxf(size.y - float(dims.z) * absf(DEPTH_OFFSET.y) - 56.0, 160.0)
		return clampf(minf(avail_w / float(dims.x), avail_h / float(dims.y)), 28.0, 48.0)

	func _get_crate_origin() -> Vector2:
		var dims: Vector3i = _get_dims()
		var cpx: float = _get_cell_px()
		var total_w: float = float(dims.x) * cpx + float(dims.z) * DEPTH_OFFSET.x
		var total_h: float = float(dims.y) * cpx + float(dims.z) * absf(DEPTH_OFFSET.y)
		var ox: float = (size.x - total_w) * 0.5
		var oy: float = (size.y - total_h) * 0.5 + float(dims.z) * absf(DEPTH_OFFSET.y) + 8.0
		return Vector2(ox, oy)

	func project_3d(x: float, y: float, z: float) -> Vector2:
		var cpx: float = _get_cell_px()
		return _get_crate_origin() + Vector2(x * cpx, y * cpx) + z * DEPTH_OFFSET

	func sync_visual_positions() -> void:
		if bp_ref == null:
			return
		var valid_uids: Dictionary = {}
		for it in bp_ref.items:
			var uid: int = int(it.get("uid", -1))
			valid_uids[uid] = true
			if not visual_y_map.has(uid):
				var p: Vector3i = it.get("pos", Vector3i.ZERO)
				visual_y_map[uid] = float(p.y)
		for k in visual_y_map.keys():
			if not valid_uids.has(k):
				visual_y_map.erase(k)
		queue_redraw()

	## Triggers smooth gravity bounce Tweens (EASE_IN + TRANS_BOUNCE) for items that dropped.
	func animate_gravity_drops(moved_items: Dictionary) -> void:
		if bp_ref == null:
			return
		for uid_key in moved_items.keys():
			var uid: int = int(uid_key)
			var info: Dictionary = moved_items[uid_key]
			var from_y: float = float(info.get("from_y", 0))
			var to_y: float = float(info.get("to_y", 0))
			if is_equal_approx(from_y, to_y):
				visual_y_map[uid] = to_y
				continue

			if _active_tweens.has(uid) and is_instance_valid(_active_tweens[uid]):
				(_active_tweens[uid] as Tween).kill()

			visual_y_map[uid] = from_y
			var drop_dist: float = absf(to_y - from_y)
			var dur: float = clampf(0.26 + drop_dist * 0.055, 0.26, 0.55)
			var tw := create_tween()
			tw.tween_method(func(val: float):
				visual_y_map[uid] = val
				queue_redraw()
			, from_y, to_y, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
			_active_tweens[uid] = tw
		queue_redraw()

	func set_active_z(z_val: int) -> void:
		var dims: Vector3i = _get_dims()
		active_z_slice = clampi(z_val, 0, dims.z - 1)
		queue_redraw()

	func rotate_dragged_xy() -> void:
		if dragging_uid == -1:
			return
		drag_size = Vector3i(drag_size.y, drag_size.x, drag_size.z)
		if bp_ref != null and bp_ref.has_method("play_sfx"):
			bp_ref.play_sfx("laser_clean")
		if on_status_message.is_valid():
			on_status_message.call("Rotated 90° (X↔Y): %dx%dx%d" % [drag_size.x, drag_size.y, drag_size.z])
		queue_redraw()

	func flip_dragged_xz() -> void:
		if dragging_uid == -1:
			return
		drag_size = Vector3i(drag_size.z, drag_size.y, drag_size.x)
		if bp_ref != null and bp_ref.has_method("play_sfx"):
			bp_ref.play_sfx("laser_clean")
		if on_status_message.is_valid():
			on_status_message.call("Flipped Thickness (X↔Z): %dx%dx%d" % [drag_size.x, drag_size.y, drag_size.z])
		queue_redraw()

	func cancel_drag() -> void:
		if dragging_uid == -1:
			return
		var uid: int = dragging_uid
		dragging_uid = -1
		drag_has_moved = false
		if bp_ref != null:
			var idx: int = bp_ref.get_item_index_by_uid(uid)
			if idx != -1:
				bp_ref.items[idx]["pos"] = drag_orig_pos
				bp_ref.items[idx]["size"] = drag_orig_size
				visual_y_map[uid] = float(drag_orig_pos.y)
			bp_ref._rebuild_grid_3d()
		queue_redraw()

	func _get_hover_grid_pos(mouse_local: Vector2, item_size: Vector3i) -> Vector3i:
		var dims: Vector3i = _get_dims()
		var cpx: float = _get_cell_px()
		var origin: Vector2 = _get_crate_origin() + float(active_z_slice) * DEPTH_OFFSET
		var rel: Vector2 = mouse_local - origin
		var gx: int = int(floor((rel.x - (float(item_size.x) * cpx * 0.5)) / cpx + 0.5))
		var gy: int = int(floor((rel.y - (float(item_size.y) * cpx * 0.5)) / cpx + 0.5))
		gx = clampi(gx, 0, maxi(dims.x - item_size.x, 0))
		gy = clampi(gy, 0, maxi(dims.y - item_size.y, 0))
		var gz: int = clampi(active_z_slice, 0, maxi(dims.z - item_size.z, 0))
		return Vector3i(gx, gy, gz)

	func _pick_item_at_mouse(mouse_local: Vector2) -> int:
		if bp_ref == null:
			return -1
		var cpx: float = _get_cell_px()
		var sorted: Array = _get_sorted_items()
		# Check front-to-back (reverse of draw order), skipping items faded in front of active_z_slice
		for i in range(sorted.size() - 1, -1, -1):
			var it: Dictionary = sorted[i]
			var uid: int = int(it.get("uid", -1))
			if uid == dragging_uid:
				continue
			var p: Vector3i = it.get("pos", Vector3i.ZERO)
			var s: Vector3i = it.get("size", Vector3i.ONE)
			# Items strictly in front of active_z_slice are faded to 20% and click-through!
			if p.z < active_z_slice:
				continue
			var vy: float = float(visual_y_map.get(uid, float(p.y)))
			var tl: Vector2 = project_3d(float(p.x), vy, float(p.z))
			var front_rect := Rect2(tl, Vector2(float(s.x) * cpx, float(s.y) * cpx))
			if front_rect.has_point(mouse_local):
				return uid
		return -1

	func _gui_input(event: InputEvent) -> void:
		if bp_ref == null:
			return

		if event is InputEventMouseMotion:
			drag_mouse_pos = event.position
			if dragging_uid != -1:
				if event.position.distance_to(drag_start_mouse) > 6.0:
					drag_has_moved = true
				queue_redraw()
			else:
				var hit_uid: int = _pick_item_at_mouse(event.position)
				if hit_uid != hovered_uid:
					hovered_uid = hit_uid
					if on_selection_changed.is_valid():
						on_selection_changed.call(hovered_uid if hovered_uid != -1 else selected_uid)
					queue_redraw()

		elif event is InputEventMouseButton:
			drag_mouse_pos = event.position
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				if dragging_uid != -1:
					cancel_drag()
					if on_status_message.is_valid():
						on_status_message.call("Placement cancelled.")
					accept_event()
				return

			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					if dragging_uid != -1:
						# Click-to-place release
						_attempt_drop_dragged(event.position)
						accept_event()
					else:
						var hit_uid: int = _pick_item_at_mouse(event.position)
						if hit_uid != -1:
							var it: Dictionary = bp_ref.get_item_by_uid(hit_uid)
							if not it.is_empty():
								dragging_uid = hit_uid
								selected_uid = hit_uid
								drag_orig_pos = it.get("pos", Vector3i.ZERO)
								drag_orig_size = it.get("size", Vector3i.ONE)
								drag_size = drag_orig_size
								drag_start_mouse = event.position
								drag_has_moved = false
								if on_selection_changed.is_valid():
									on_selection_changed.call(selected_uid)
								if on_status_message.is_valid():
									on_status_message.call("Dragging! [R] Rotate X↔Y  |  [F] Flip X↔Z  |  [Q/E] Depth Layer")
								queue_redraw()
								accept_event()
				else:
					# Mouse button released: if user dragged, drop immediately
					if dragging_uid != -1 and drag_has_moved:
						_attempt_drop_dragged(event.position)
						accept_event()

	func _attempt_drop_dragged(mouse_local: Vector2) -> void:
		if dragging_uid == -1 or bp_ref == null:
			return
		var uid: int = dragging_uid
		var target_pos: Vector3i = _get_hover_grid_pos(mouse_local, drag_size)

		bp_ref._rebuild_grid_3d(uid)
		var can_fit: bool = bp_ref.can_place_in_grid(target_pos, drag_size, uid)
		if can_fit:
			# Snap visual start Y to release height so bounce tween falls from release slot!
			visual_y_map[uid] = float(target_pos.y)
			dragging_uid = -1
			drag_has_moved = false
			var moved: Dictionary = bp_ref.place_item_at(uid, target_pos, drag_size)
			if not moved.has(uid):
				var final_it: Dictionary = bp_ref.get_item_by_uid(uid)
				var fy: int = (final_it.get("pos", target_pos) as Vector3i).y
				moved[uid] = {"from_y": target_pos.y, "to_y": fy}
			animate_gravity_drops(moved)
			if bp_ref.has_method("play_sfx"):
				bp_ref.play_sfx("pickup")
			if on_status_message.is_valid():
				on_status_message.call("Settled into 3D crate under gravity!")
		else:
			if bp_ref.has_method("play_sfx"):
				bp_ref.play_sfx("hit")
			cancel_drag()
			if on_status_message.is_valid():
				on_status_message.call("Slot blocked! Try [R]/[F] to rotate or [Q]/[E] to change Z layer.")
		queue_redraw()

	func _get_sorted_items() -> Array:
		if bp_ref == null:
			return []
		var arr: Array = bp_ref.items.duplicate()
		arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var pa: Vector3i = a.get("pos", Vector3i.ZERO)
			var pb: Vector3i = b.get("pos", Vector3i.ZERO)
			if pa.z != pb.z:
				return pa.z > pb.z # Deeper Z drawn first
			if pa.y != pb.y:
				return pa.y > pb.y # Lower items drawn first, stacked items on top
			return pa.x < pb.x # Left items drawn first
		)
		return arr

	func _get_item_texture(item: Dictionary) -> Texture2D:
		var path: String = str(item.get("sprite_path", item.get("icon_path", "")))
		if path.is_empty():
			return null
		if _tex_cache.has(path):
			return _tex_cache[path]
		if ResourceLoader.exists(path):
			var t := load(path) as Texture2D
			_tex_cache[path] = t
			return t
		_tex_cache[path] = null
		return null

	func _draw() -> void:
		if bp_ref == null:
			return

		var dims: Vector3i = _get_dims()
		var cpx: float = _get_cell_px()
		var font: Font = ThemeDB.fallback_font

		# 1. Back Wall (z = dims.z)
		var b_tl: Vector2 = project_3d(0.0, 0.0, float(dims.z))
		var b_tr: Vector2 = project_3d(float(dims.x), 0.0, float(dims.z))
		var b_br: Vector2 = project_3d(float(dims.x), float(dims.y), float(dims.z))
		var b_bl: Vector2 = project_3d(0.0, float(dims.y), float(dims.z))
		draw_polygon(PackedVector2Array([b_tl, b_tr, b_br, b_bl]), PackedColorArray([Color(0.03, 0.08, 0.14, 0.92)]))

		# Floor (y = dims.y)
		var f_bl: Vector2 = project_3d(0.0, float(dims.y), 0.0)
		var f_br: Vector2 = project_3d(float(dims.x), float(dims.y), 0.0)
		draw_polygon(PackedVector2Array([f_bl, f_br, b_br, b_bl]), PackedColorArray([Color(0.06, 0.14, 0.22, 0.95)]))

		# Left Interior Wall (x = 0)
		var f_tl: Vector2 = project_3d(0.0, 0.0, 0.0)
		draw_polygon(PackedVector2Array([f_tl, b_tl, b_bl, f_bl]), PackedColorArray([Color(0.04, 0.11, 0.18, 0.85)]))

		# Top Opening Entry Lip Highlight (y = 0)
		var f_tr: Vector2 = project_3d(float(dims.x), 0.0, 0.0)
		draw_polygon(PackedVector2Array([f_tl, f_tr, b_tr, b_tl]), PackedColorArray([Color(0.1, 0.45, 0.65, 0.18)]))
		draw_string(font, b_tl + Vector2(6.0, -6.0), "▼ TOP CARGO HATCH (DROP ENTRY) — %dx%dx%d VOLUME" % [dims.x, dims.y, dims.z], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.9, 1.0, 0.9))

		# Back wall grid lines
		var back_grid_col := Color(0.18, 0.35, 0.5, 0.25)
		for gx in range(dims.x + 1):
			draw_line(project_3d(float(gx), 0.0, float(dims.z)), project_3d(float(gx), float(dims.y), float(dims.z)), back_grid_col, 1.0)
		for gy in range(dims.y + 1):
			draw_line(project_3d(0.0, float(gy), float(dims.z)), project_3d(float(dims.x), float(gy), float(dims.z)), back_grid_col, 1.0)

		# Floor depth slice lines
		for gz in range(dims.z + 1):
			var slice_col := Color(0.25, 0.85, 1.0, 0.65) if gz == active_z_slice else Color(0.2, 0.4, 0.55, 0.3)
			draw_line(project_3d(0.0, float(dims.y), float(gz)), project_3d(float(dims.x), float(dims.y), float(gz)), slice_col, 1.5 if gz == active_z_slice else 1.0)
			draw_line(project_3d(0.0, 0.0, float(gz)), project_3d(0.0, float(dims.y), float(gz)), slice_col, 1.0)

		# Active Z Slice highlighted grid plane (behind items on this layer)
		var slice_z: float = float(active_z_slice)
		var active_grid_col := Color(0.2, 0.9, 1.0, 0.38)
		for gx in range(dims.x + 1):
			draw_line(project_3d(float(gx), 0.0, slice_z), project_3d(float(gx), float(dims.y), slice_z), active_grid_col, 1.0)
		for gy in range(dims.y + 1):
			draw_line(project_3d(0.0, float(gy), slice_z), project_3d(float(dims.x), float(gy), slice_z), active_grid_col, 1.0)

		# 2. Packed 3D Extruded Relic Blocks (Sorted Back-to-Front)
		var sorted: Array = _get_sorted_items()
		for it in sorted:
			var uid: int = int(it.get("uid", -1))
			if uid == dragging_uid:
				continue
			var p: Vector3i = it.get("pos", Vector3i.ZERO)
			var s: Vector3i = it.get("size", Vector3i.ONE)
			var vy: float = float(visual_y_map.get(uid, float(p.y)))

			# Depth Layer Slicer: items in front of active Z slice fade to 20% opacity
			var alpha: float = 1.0
			if p.z < active_z_slice:
				alpha = 0.20
			elif p.z > active_z_slice:
				alpha = 0.72

			var is_sel: bool = (uid == selected_uid or uid == hovered_uid) and alpha > 0.5
			_draw_extruded_item(it, Vector3(float(p.x), vy, float(p.z)), s, alpha, is_sel, Color.WHITE)

		# 3. Translucent Front Crate Wireframe (z = 0)
		var wire_col := Color(0.35, 0.78, 0.95, 0.55)
		draw_polyline(PackedVector2Array([f_tl, f_tr, f_br, f_bl, f_tl]), wire_col, 2.0, true)
		draw_line(f_tl, b_tl, wire_col, 1.5)
		draw_line(f_tr, b_tr, wire_col, 1.5)
		draw_line(f_br, b_br, wire_col, 1.5)
		draw_line(f_bl, b_bl, wire_col, 1.5)
		draw_polyline(PackedVector2Array([b_tl, b_tr, b_br, b_bl, b_tl]), Color(0.25, 0.55, 0.75, 0.4), 1.5, true)

		# Active Z Slice indicator tag
		var z_tag_pos: Vector2 = project_3d(float(dims.x), float(dims.y), slice_z) + Vector2(8.0, -4.0)
		draw_string(font, z_tag_pos, "◀ Z=%d" % active_z_slice, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.25, 1.0, 0.95))

		# 4. Dragged Item & Gravity Landing Preview
		if dragging_uid != -1:
			var drag_item: Dictionary = bp_ref.get_item_by_uid(dragging_uid)
			if not drag_item.is_empty():
				var hover_pos: Vector3i = _get_hover_grid_pos(drag_mouse_pos, drag_size)
				bp_ref._rebuild_grid_3d(dragging_uid)
				var is_valid: bool = bp_ref.can_place_in_grid(hover_pos, drag_size, dragging_uid)

				if is_valid:
					var land_y: int = bp_ref.predict_drop_y(hover_pos, drag_size, dragging_uid)
					if land_y > hover_pos.y:
						# Draw vertical cyan gravity drop guide & landing shadow box
						var drop_from: Vector2 = project_3d(float(hover_pos.x) + float(drag_size.x) * 0.5, float(hover_pos.y + drag_size.y), float(hover_pos.z))
						var drop_to: Vector2 = project_3d(float(hover_pos.x) + float(drag_size.x) * 0.5, float(land_y + drag_size.y), float(hover_pos.z))
						draw_dashed_line(drop_from, drop_to, Color(0.2, 1.0, 0.95, 0.75), 2.0, 5.0)
						var land_tl: Vector2 = project_3d(float(hover_pos.x), float(land_y), float(hover_pos.z))
						var land_rect := Rect2(land_tl, Vector2(float(drag_size.x) * cpx, float(drag_size.y) * cpx))
						draw_rect(land_rect, Color(0.2, 1.0, 0.75, 0.16), true)
						draw_rect(land_rect, Color(0.2, 1.0, 0.75, 0.7), false, 1.5)

				var tint := Color(0.35, 1.0, 0.55, 0.92) if is_valid else Color(1.0, 0.3, 0.3, 0.92)
				_draw_extruded_item(drag_item, Vector3(float(hover_pos.x), float(hover_pos.y), float(hover_pos.z)), drag_size, 0.92, true, tint)

	func _draw_extruded_item(it: Dictionary, p: Vector3, s: Vector3i, alpha: float, is_highlighted: bool, override_tint: Color) -> void:
		var cpx: float = _get_cell_px()
		var font: Font = ThemeDB.fallback_font
		var is_clean: bool = bool(it.get("cleaned", it.get("identified", false)))

		var base_col: Color = Color("#5A4A3C") # Rocky brown when encrusted
		if is_clean:
			base_col = Color.from_string(str(it.get("color_hex", "#00ffff")), Color.CYAN)
			if it.has("color") and it["color"] is Color:
				base_col = it["color"]

		if override_tint != Color.WHITE:
			base_col = override_tint

		var fx: float = p.x
		var fy: float = p.y
		var fz: float = p.z
		var sx: float = float(s.x)
		var sy: float = float(s.y)
		var sz: float = float(s.z)

		# 8 projected vertices of the 3D volume block
		var f_tl: Vector2 = project_3d(fx, fy, fz)
		var f_tr: Vector2 = project_3d(fx + sx, fy, fz)
		var f_br: Vector2 = project_3d(fx + sx, fy + sy, fz)
		var f_bl: Vector2 = project_3d(fx, fy + sy, fz)

		var b_tl: Vector2 = project_3d(fx, fy, fz + sz)
		var b_tr: Vector2 = project_3d(fx + sx, fy, fz + sz)
		var b_br: Vector2 = project_3d(fx + sx, fy + sy, fz + sz)

		# 1. Top Thickness Face (lighter shade)
		var top_col: Color = base_col.lightened(0.22)
		top_col.a = 0.78 * alpha
		draw_polygon(PackedVector2Array([f_tl, f_tr, b_tr, b_tl]), PackedColorArray([top_col]))

		# 2. Right Side Thickness Face (darker shade)
		var side_col: Color = base_col.darkened(0.32)
		side_col.a = 0.85 * alpha
		draw_polygon(PackedVector2Array([f_tr, b_tr, b_br, f_br]), PackedColorArray([side_col]))

		# 3. Front Face Body
		var front_bg: Color = base_col.darkened(0.55)
		front_bg.a = 0.90 * alpha
		var front_rect := Rect2(f_tl, Vector2(sx * cpx, sy * cpx))
		draw_rect(front_rect, front_bg, true)

		# 4. Relic Sprite Texture (or Encrusted Silhouette) inside Front Face
		var pad: float = 4.0
		var inner_w: float = maxf(front_rect.size.x - pad * 2.0, 8.0)
		var inner_h: float = maxf(front_rect.size.y - pad * 2.0, 8.0)
		var tex: Texture2D = _get_item_texture(it) if is_clean else null
		if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
			var sc: float = minf(inner_w / float(tex.get_width()), inner_h / float(tex.get_height()))
			var dw: float = float(tex.get_width()) * sc
			var dh: float = float(tex.get_height()) * sc
			var dst := Rect2(front_rect.position + (front_rect.size - Vector2(dw, dh)) * 0.5, Vector2(dw, dh))
			draw_texture_rect(tex, dst, false, Color(1.0, 1.0, 1.0, alpha))
		else:
			# Encrusted rock lump emblem when uncleaned
			var cx: Vector2 = front_rect.get_center()
			var r_rad: float = minf(inner_w, inner_h) * 0.32
			draw_circle(cx, r_rad, Color(0.36, 0.29, 0.23, alpha))
			draw_string(font, cx + Vector2(-4.0, 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.4, alpha))

		# 5. Crisp Extruded Outlines
		var edge_col: Color = Color(1.0, 1.0, 1.0, alpha) if is_highlighted else Color(base_col.r, base_col.g, base_col.b, 0.95 * alpha)
		var edge_w: float = 2.4 if is_highlighted else 1.5
		draw_polyline(PackedVector2Array([f_tl, f_tr, f_br, f_bl, f_tl]), edge_col, edge_w, true)
		draw_polyline(PackedVector2Array([f_tl, b_tl, b_tr, f_tr]), Color(edge_col.r, edge_col.g, edge_col.b, 0.75 * alpha), 1.2, true)
		draw_polyline(PackedVector2Array([f_tr, b_tr, b_br, f_br]), Color(edge_col.r, edge_col.g, edge_col.b, 0.75 * alpha), 1.2, true)

		# 6. Corner Dimension & Weight Tags
		if alpha >= 0.45:
			var dim_txt: String = "%dx%dx%d" % [s.x, s.y, s.z]
			draw_string(font, f_tl + Vector2(3.0, 11.0), dim_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.98, 1.0, alpha))
			var wt_txt: String = "%dkg" % int(it.get("weight", 1))
			if bool(it.get("fragile", false)):
				wt_txt += " ⚠"
			draw_string(font, f_bl + Vector2(3.0, -3.0), wt_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.88, 0.45, alpha))


## Returns true if the global 3D Volumetric Crate Inspector UI is currently open.
func is_backpack_ui_open() -> bool:
	return _crate_modal != null and _crate_modal.visible


## Toggles the universal 3D Volumetric Gravity Crate Inspector ([I] / [Tab]).
func toggle_backpack_ui() -> void:
	if _crate_layer == null:
		_create_crate_ui()
	if _crate_modal == null:
		return

	_crate_modal.visible = not _crate_modal.visible
	if _crate_modal.visible:
		_refresh_crate_ui()
	elif _crate_viewport != null and _crate_viewport.has_method("cancel_drag"):
		_crate_viewport.cancel_drag()


func close_backpack_ui() -> void:
	if _crate_modal != null and _crate_modal.visible:
		if _crate_viewport != null and _crate_viewport.has_method("cancel_drag"):
			_crate_viewport.cancel_drag()
		_crate_modal.visible = false


func _create_crate_ui() -> void:
	_crate_layer = CanvasLayer.new()
	_crate_layer.name = "VolumetricCrateCanvasLayer"
	_crate_layer.layer = 16
	add_child(_crate_layer)

	_crate_modal = Control.new()
	_crate_modal.name = "VolumetricCrateModal"
	_crate_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_crate_modal.visible = false
	_crate_layer.add_child(_crate_modal)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.03, 0.07, 0.84)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_crate_modal.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920.0, 560.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.14, 0.97)
	style.border_color = Color(0.22, 0.72, 0.95, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# Header Row
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "📦 3D VOLUMETRIC GRAVITY CARGO CRATE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = " ✕ Close [ESC / I / TAB] "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_backpack_ui)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	# Depth Layer Slicer Toolbar
	var slicer_row := HBoxContainer.new()
	slicer_row.add_theme_constant_override("separation", 8)
	var slice_lbl := Label.new()
	slice_lbl.text = "Depth Layer Slicer ([Q] / [E]):"
	slice_lbl.add_theme_font_size_override("font_size", 13)
	slice_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	slicer_row.add_child(slice_lbl)

	_crate_layer_bar = HBoxContainer.new()
	_crate_layer_bar.add_theme_constant_override("separation", 6)
	slicer_row.add_child(_crate_layer_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slicer_row.add_child(spacer)

	_crate_stats_label = Label.new()
	_crate_stats_label.add_theme_font_size_override("font_size", 13)
	_crate_stats_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	slicer_row.add_child(_crate_stats_label)
	main_vbox.add_child(slicer_row)

	main_vbox.add_child(HSeparator.new())

	# Body HBox: Left = 2.5D Isometric Crate Viewport, Right = Inspector & Actions
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(body_hbox)

	var vp_frame := PanelContainer.new()
	vp_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vp_style := StyleBoxFlat.new()
	vp_style.bg_color = Color(0.02, 0.05, 0.09, 0.96)
	vp_style.border_color = Color(0.15, 0.35, 0.5, 0.75)
	vp_style.set_border_width_all(1)
	vp_style.set_corner_radius_all(6)
	vp_frame.add_theme_stylebox_override("panel", vp_style)
	body_hbox.add_child(vp_frame)

	var vp := CrateViewport3D.new()
	vp.name = "CrateViewport3D"
	vp.bp_ref = self
	vp.custom_minimum_size = Vector2(540.0, 410.0)
	vp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp.on_selection_changed = _on_crate_selection_changed
	vp.on_status_message = func(msg: String):
		if _crate_status_label != null:
			_crate_status_label.text = msg
	vp_frame.add_child(vp)
	_crate_viewport = vp

	# Right Inspector Sidebar
	var side_panel := PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(300.0, 0.0)
	var side_style := StyleBoxFlat.new()
	side_style.bg_color = Color(0.05, 0.1, 0.17, 0.92)
	side_style.border_color = Color(0.2, 0.45, 0.65, 0.65)
	side_style.set_border_width_all(1)
	side_style.set_corner_radius_all(6)
	side_style.content_margin_left = 14.0
	side_style.content_margin_right = 14.0
	side_style.content_margin_top = 12.0
	side_style.content_margin_bottom = 12.0
	side_panel.add_theme_stylebox_override("panel", side_style)
	body_hbox.add_child(side_panel)

	var side_vbox := VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 8)
	side_panel.add_child(side_vbox)

	var insp_head := Label.new()
	insp_head.text = "RELIC INSPECTOR"
	insp_head.add_theme_font_size_override("font_size", 14)
	insp_head.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	side_vbox.add_child(insp_head)

	_crate_inspector_title = Label.new()
	_crate_inspector_title.text = "Hover or click a 3D block"
	_crate_inspector_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crate_inspector_title.add_theme_font_size_override("font_size", 14)
	_crate_inspector_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	side_vbox.add_child(_crate_inspector_title)

	_crate_inspector_meta = Label.new()
	_crate_inspector_meta.text = "Click an item to pick up, rotate in 3D, and drop under gravity."
	_crate_inspector_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crate_inspector_meta.add_theme_font_size_override("font_size", 12)
	_crate_inspector_meta.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	side_vbox.add_child(_crate_inspector_meta)

	_crate_inspector_lore = Label.new()
	_crate_inspector_lore.text = ""
	_crate_inspector_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crate_inspector_lore.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crate_inspector_lore.add_theme_font_size_override("font_size", 11)
	_crate_inspector_lore.add_theme_color_override("font_color", Color(0.75, 0.86, 0.95))
	side_vbox.add_child(_crate_inspector_lore)

	side_vbox.add_child(HSeparator.new())

	# Controls Legend
	var controls_lbl := Label.new()
	controls_lbl.text = "CONTROLS:\n• [Click / Drag] Grab & Drop Item\n• [R] Rotate 90° (X ↔ Y)\n• [F] Flip Thickness (X ↔ Z)\n• [Q / E] Slice Depth Layer (Z)\n• [Right-Click] Cancel Drag"
	controls_lbl.add_theme_font_size_override("font_size", 11)
	controls_lbl.add_theme_color_override("font_color", Color(0.65, 0.8, 0.9))
	side_vbox.add_child(controls_lbl)

	# 3D Rotate & Action Buttons
	var rot_row := HBoxContainer.new()
	rot_row.add_theme_constant_override("separation", 6)
	var rot_xy_btn := Button.new()
	rot_xy_btn.text = "↻ Rotate [R]"
	rot_xy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_xy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rot_xy_btn.pressed.connect(func():
		if _crate_viewport != null:
			_crate_viewport.rotate_dragged_xy()
	)
	rot_row.add_child(rot_xy_btn)

	var flip_xz_btn := Button.new()
	flip_xz_btn.text = "⇄ Flip Z [F]"
	flip_xz_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flip_xz_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flip_xz_btn.pressed.connect(func():
		if _crate_viewport != null:
			_crate_viewport.flip_dragged_xz()
	)
	rot_row.add_child(flip_xz_btn)
	side_vbox.add_child(rot_row)

	var autopack_btn := Button.new()
	autopack_btn.text = "⚡ Auto-Pack & Settle Gravity"
	autopack_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	autopack_btn.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75))
	autopack_btn.pressed.connect(func():
		var moved: Dictionary = auto_pack_all()
		if _crate_viewport != null:
			_crate_viewport.animate_gravity_drops(moved)
		play_sfx("pickup")
		if _crate_status_label != null:
			_crate_status_label.text = "Auto-packed all relics under 3D gravity!"
	)
	side_vbox.add_child(autopack_btn)

	_crate_drop_btn = Button.new()
	_crate_drop_btn.text = "🗑 Drop Selected Relic"
	_crate_drop_btn.disabled = true
	_crate_drop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_crate_drop_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_crate_drop_btn.pressed.connect(func():
		if _crate_viewport == null:
			return
		var uid_to_drop: int = _crate_viewport.selected_uid
		if uid_to_drop == -1:
			return
		_crate_viewport.cancel_drag()
		remove_item_by_uid(uid_to_drop, true)
		_crate_viewport.selected_uid = -1
		_crate_viewport.hovered_uid = -1
		_refresh_crate_ui()
		if _crate_status_label != null:
			_crate_status_label.text = "Relic dropped! Stacked items settled under gravity."
	)
	side_vbox.add_child(_crate_drop_btn)

	# Bottom Status Line
	_crate_status_label = Label.new()
	_crate_status_label.text = "Ready — Items in front of the active Z layer fade to 20% so you can reach deeper layers."
	_crate_status_label.add_theme_font_size_override("font_size", 11)
	_crate_status_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	main_vbox.add_child(_crate_status_label)

	# Connect live inventory & gravity signals
	inventory_changed.connect(_on_crate_inventory_changed)
	gravity_settled.connect(_on_crate_gravity_settled)


func _on_crate_inventory_changed() -> void:
	if is_backpack_ui_open():
		_refresh_crate_ui()


func _on_crate_gravity_settled(moved_items: Dictionary) -> void:
	if is_backpack_ui_open() and _crate_viewport != null:
		_crate_viewport.animate_gravity_drops(moved_items)


func _on_crate_selection_changed(uid: int) -> void:
	if _crate_inspector_title == null:
		return
	var it: Dictionary = get_item_by_uid(uid)
	if it.is_empty():
		_crate_inspector_title.text = "Hover or click a 3D block"
		_crate_inspector_meta.text = "Items physically settle under gravity."
		_crate_inspector_lore.text = ""
		if _crate_drop_btn != null:
			_crate_drop_btn.disabled = true
		return

	var is_clean: bool = bool(it.get("cleaned", it.get("identified", false)))
	var s: Vector3i = it.get("size", Vector3i.ONE)
	var p: Vector3i = it.get("pos", Vector3i.ZERO)
	var wt: int = int(it.get("weight", 1))
	var frag_str: String = "  •  ⚠ FRAGILE" if bool(it.get("fragile", false)) else ""

	if is_clean:
		_crate_inspector_title.text = str(it.get("name", "Human Relic"))
		_crate_inspector_meta.text = "Volume: %dx%dx%d  |  Layer Z=%d  |  %d kg%s\nValue: $%d  •  [%s]" % [
			s.x, s.y, s.z, p.z, wt, frag_str, int(it.get("value", 0)), str(it.get("rarity", "Common"))
		]
		_crate_inspector_lore.text = "\"%s\"" % str(it.get("lore", it.get("alien_desc", "")))
	else:
		_crate_inspector_title.text = "Encrusted Relic Lump (%d kg)" % wt
		_crate_inspector_meta.text = "Volume: %dx%dx%d  |  Layer Z=%d  |  %d kg\nValue: ??? (Clean at Home Lab)" % [
			s.x, s.y, s.z, p.z, wt
		]
		_crate_inspector_lore.text = "Covered in deep-sea barnacles. Bring to your Home Cleaning Lab to reveal its identity."

	if _crate_drop_btn != null:
		_crate_drop_btn.disabled = false


func _refresh_crate_ui() -> void:
	if _crate_viewport == null:
		return
	var dims: Vector3i = get_grid_dimensions()
	_crate_viewport.set_active_z(clampi(_crate_viewport.active_z_slice, 0, dims.z - 1))
	_crate_viewport.sync_visual_positions()

	if _crate_stats_label != null:
		_crate_stats_label.text = "Exo Lv.%d (%dx%dx%d)  |  Vol: %d/%d  |  Wt: %.1f/%.1f kg  |  Val: $%d" % [
			exo_level, dims.x, dims.y, dims.z, get_occupied_cells(), get_total_cells(), current_weight, max_weight, get_total_value()
		]

	if _crate_layer_bar != null:
		for c in _crate_layer_bar.get_children():
			c.queue_free()
		for z in range(dims.z):
			var btn := Button.new()
			var label_suffix: String = " (Front)" if z == 0 else (" (Back)" if z == dims.z - 1 else "")
			btn.text = " Z=%d%s " % [z, label_suffix]
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if z == _crate_viewport.active_z_slice:
				btn.add_theme_color_override("font_color", Color(0.25, 1.0, 0.9))
			else:
				btn.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
			btn.pressed.connect(func():
				_crate_viewport.set_active_z(z)
				_refresh_crate_ui()
			)
			_crate_layer_bar.add_child(btn)

	_on_crate_selection_changed(_crate_viewport.selected_uid)


func _input(event: InputEvent) -> void:
	# Intercept keys & mouse while 3D Volumetric Crate Inspector is open so underlying scenes stay paused
	if is_backpack_ui_open():
		if event is InputEventKey and event.pressed and not event.echo:
			var kc: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if kc == KEY_ESCAPE or kc == KEY_I or kc == KEY_TAB:
				close_backpack_ui()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				return
			elif kc == KEY_Q:
				if _crate_viewport != null:
					_crate_viewport.set_active_z(_crate_viewport.active_z_slice - 1)
					_refresh_crate_ui()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				return
			elif kc == KEY_E:
				if _crate_viewport != null:
					_crate_viewport.set_active_z(_crate_viewport.active_z_slice + 1)
					_refresh_crate_ui()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				return
			elif kc == KEY_R:
				if _crate_viewport != null:
					_crate_viewport.rotate_dragged_xy()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				return
			elif kc == KEY_F:
				if _crate_viewport != null:
					_crate_viewport.flip_dragged_xz()
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				return


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
	if is_backpack_ui_open():
		return
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
		var p: Vector3i = it.get("pos", Vector3i.ZERO)
		var s: Vector3i = it.get("size", Vector3i.ONE)
		var is_clean: bool = bool(it.get("cleaned", it.get("identified", false)))
		serialized.append({
			"uid": int(it.get("uid", -1)),
			"id": str(it.get("id", "")),
			"cleaned": is_clean,
			"identified": is_clean,
			"pos": [p.x, p.y, p.z],
			"size": [s.x, s.y, s.z]
		})
	return serialized


func _deserialize_items(loaded_list: Array) -> void:
	items.clear()
	_rebuild_grid_3d()
	var max_uid: int = 0
	var unplaced_legacy: Array[Dictionary] = []

	for entry in loaded_list:
		if not (entry is Dictionary):
			continue
		var rid: String = str(entry.get("id", ""))
		if not RELIC_DB.has(rid):
			continue
		var is_clean: bool = bool(entry.get("cleaned", entry.get("identified", false)))
		var inst: Dictionary = RELIC_DB[rid].duplicate(true)
		inst["identified"] = is_clean
		inst["cleaned"] = is_clean

		var uid: int = int(entry.get("uid", -1))
		if uid <= 0:
			_next_item_uid += 1
			uid = _next_item_uid
		max_uid = maxi(max_uid, uid)
		inst["uid"] = uid

		var pos_arr = entry.get("pos", [])
		var size_arr = entry.get("size", [])
		if pos_arr is Array and pos_arr.size() >= 3 and size_arr is Array and size_arr.size() >= 3:
			var p := Vector3i(int(pos_arr[0]), int(pos_arr[1]), int(pos_arr[2]))
			var s := Vector3i(maxi(int(size_arr[0]), 1), maxi(int(size_arr[1]), 1), maxi(int(size_arr[2]), 1))
			if can_place_in_grid(p, s):
				inst["pos"] = p
				inst["size"] = s
				items.append(inst)
				_stamp_item_in_grid(p, s, uid)
				continue

		unplaced_legacy.append(inst)

	# Auto-place any legacy save items without 3D coordinates via top-entry + gravity
	for inst in unplaced_legacy:
		var base_sz: Vector3i = get_relic_size_3d(str(inst.get("id", "")))
		var slot: Dictionary = find_top_entry_slot(base_sz)
		if bool(slot.get("found", false)):
			var p: Vector3i = slot["pos"]
			var s: Vector3i = slot["size"]
			inst["pos"] = p
			inst["size"] = s
			items.append(inst)
			_stamp_item_in_grid(p, s, int(inst["uid"]))
			apply_backpack_gravity(false)

	_next_item_uid = maxi(_next_item_uid, max_uid + 1)
	_recalculate_weight()
	_rebuild_grid_3d()
	apply_backpack_gravity(false)


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
	_next_item_uid = 1
	current_weight = 0.0
	_rebuild_grid_3d()
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
