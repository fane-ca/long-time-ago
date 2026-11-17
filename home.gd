class_name SurvivorsHome
extends Node2D

## SurvivorsHome: 2.5D Top-Down Expandable Multi-Room Interior
## Features:
## 1. Central Living Quarters (Survivor bed, Exit door, Architect's Drafting Table).
## 2. Relic Cleaning & Restoration Lab (Laser & ultrasonic cleaning workbench with interactive crust-stripping mini-game).
## 3. North Wing: Archive Study (Unlocked via blueprints, boosts Museum visitor payout +50%, Human History Codex Terminal).
## 4. East Wing: Bio-Recycler Wing (Unlocked via blueprints, Barnacle Bio-Synthesizer converts scraped crust into +$50 Gold).
## 5. Physical real-time removal of room barriers upon drafting expansion construction.

var player: CharacterBody2D
var world_25d: Node2D
var hud_label: Label
var prompt_label: Label
var inventory_modal: Control
var manifest_summary_label: Label
var manifest_items_container: VBoxContainer

# Physical barriers for locked wings
var north_barrier: StaticBody2D
var east_barrier: StaticBody2D

# Interactive Modal References
var current_open_modal: String = "" # "", "drafting", "cleaning", "codex", "synth", "sleep"
var drafting_modal: Control
var drafting_funds_label: Label
var drafting_feedback_label: Label
var drafting_items_vbox: VBoxContainer

var cleaning_modal: Control
var cleaning_items_vbox: VBoxContainer
var cleaning_station_panel: PanelContainer
var cleaning_crust_bar: ProgressBar
var cleaning_crust_label: Label
var cleaning_pulse_btn: Button
var cleaning_reveal_panel: PanelContainer
var cleaning_reveal_title: Label
var cleaning_reveal_val: Label
var cleaning_reveal_desc: Label
var cleaning_preview_control: Control

var codex_modal: Control
var synth_modal: Control
var synth_count_label: Label
var synth_feedback_label: Label

# Sleep & Settlement Modal References
var sleep_modal: Control
var sleep_dim: ColorRect
var sleep_day_label: Label
var sleep_exhibits_label: Label
var sleep_earnings_label: Label
var sleep_next_btn: Button
var sleep_calculated_bonus: int = 0

# Cleaning mini-game state
var active_cleaning_inventory_index: int = -1
var active_crust_integrity: float = 100.0
var barnacle_clumps: Array[Control] = []
var barnacle_total_count: int = 7
var barnacle_remaining_count: int = 7
var _chamber_relic_node: Node2D = null
var _chamber_debris_node: Node2D = null

const WALK_SPEED: float = 210.0
const EXIT_DOOR_POS: Vector2 = Vector2(576.0, 580.0)
const BED_POS: Vector2 = Vector2(470.0, 500.0)
const DRAFTING_TABLE_POS: Vector2 = Vector2(650.0, 360.0)
const CLEANING_BENCH_POS: Vector2 = Vector2(240.0, 360.0)
const CODEX_TERMINAL_POS: Vector2 = Vector2(576.0, 130.0)
const BIO_SYNTH_POS: Vector2 = Vector2(900.0, 360.0)


func _ready() -> void:
	_create_interior_architecture()
	_create_world_25d()
	_create_furniture_and_stations()
	_create_room_barriers()
	_create_player()
	_setup_ui()
	_setup_drafting_modal()
	_setup_cleaning_modal()
	_setup_codex_modal()
	_setup_synth_modal()
	_setup_sleep_summary_modal()
	_update_room_barriers()


func _physics_process(_delta: float) -> void:
	_handle_player_movement()
	_update_prompts_and_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# If any modal is open, [F] or [ESC] closes it
		if current_open_modal != "":
			if event.physical_keycode == KEY_F or event.keycode == KEY_F or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_close_all_modals()
				return

			# Space / Enter key starts next day while in sleep summary modal
			if current_open_modal == "sleep" and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER or event.keycode == KEY_ENTER):
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_on_start_next_day_pressed()
				return

			# Space key pulses the cleaning laser while in cleaning bench modal
			if current_open_modal == "cleaning" and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE):
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_pulse_cleaning_laser()
				return

		# Toggle backpack manifest with TAB or I
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

		# Primary Interaction key [E] and Scene Transition key [F]
		if player == null:
			return

		# 1. Exit Door to Island [F]
		if event.physical_keycode == KEY_F or event.keycode == KEY_F:
			if player.position.distance_to(EXIT_DOOR_POS) < 70.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				if is_inside_tree():
					get_tree().change_scene_to_file("res://land.tscn")
				return

		# 2. Station interactions [E]
		if event.physical_keycode == KEY_E or event.keycode == KEY_E:
			# Survivor Bed (Sleep & End Day)
			if player.position.distance_to(BED_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_open_sleep_summary_modal()
				return

			# Drafting Table
			if player.position.distance_to(DRAFTING_TABLE_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_open_drafting_modal()
				return

			# Cleaning Bench
			if player.position.distance_to(CLEANING_BENCH_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_open_cleaning_modal()
				return

			# Codex Terminal (North Wing - only if unlocked)
			var bp = _get_backpack()
			if bp != null and bp.unlocked_rooms.get("archive_study", false):
				if player.position.distance_to(CODEX_TERMINAL_POS) < 65.0:
					if get_viewport() != null:
						get_viewport().set_input_as_handled()
					_open_codex_modal()
					return

			# Bio-Synthesizer (East Wing - only if unlocked)
			if bp != null and bp.unlocked_rooms.get("bio_recycler", false):
				if player.position.distance_to(BIO_SYNTH_POS) < 65.0:
					if get_viewport() != null:
						get_viewport().set_input_as_handled()
					_open_synth_modal()
					return


## Draws the 4-room interior flooring, cozy rugs, north walls, and doorway thresholds.
func _create_interior_architecture() -> void:
	var arch := CanvasGroup.new()
	arch.name = "InteriorArchitecture"

	# Surrounding void / wall perimeter darkness
	var void_bg := ColorRect.new()
	void_bg.color = Color(0.04, 0.05, 0.07)
	void_bg.position = Vector2(0.0, 0.0)
	void_bg.size = Vector2(1152.0, 648.0)
	arch.add_child(void_bg)

	# --- 1. Central Living Quarters (Center Room) ---
	var center_floor := ColorRect.new()
	center_floor.color = Color(0.32, 0.22, 0.14) # Cozy dark wood planks
	center_floor.position = Vector2(420.0, 220.0)
	center_floor.size = Vector2(310.0, 360.0)
	arch.add_child(center_floor)

	# Wood floor plank seams
	for fy in range(230, 580, 24):
		var plank := ColorRect.new()
		plank.color = Color(0.24, 0.16, 0.1, 0.6)
		plank.position = Vector2(420.0, float(fy))
		plank.size = Vector2(310.0, 1.5)
		arch.add_child(plank)

	# Cozy braided woven rug in Living Quarters center
	var rug := Polygon2D.new()
	rug.polygon = _make_ellipse(75.0, 48.0, Vector2(560.0, 420.0))
	rug.color = Color(0.55, 0.22, 0.18, 0.85) # Crimson patterned rug
	arch.add_child(rug)

	var inner_rug := Polygon2D.new()
	inner_rug.polygon = _make_ellipse(58.0, 34.0, Vector2(560.0, 420.0))
	inner_rug.color = Color(0.72, 0.48, 0.25, 0.8)
	arch.add_child(inner_rug)

	# --- 2. West Wing: Relic Cleaning & Restoration Lab ---
	var west_floor := ColorRect.new()
	west_floor.color = Color(0.14, 0.2, 0.24) # Smooth laboratory tiles
	west_floor.position = Vector2(100.0, 240.0)
	west_floor.size = Vector2(320.0, 260.0)
	arch.add_child(west_floor)

	# Lab grid floor lines
	for wx in range(120, 420, 32):
		var l_v := ColorRect.new()
		l_v.color = Color(0.2, 0.3, 0.35, 0.4)
		l_v.position = Vector2(float(wx), 240.0)
		l_v.size = Vector2(1.0, 260.0)
		arch.add_child(l_v)

	# Open archway threshold from Living Quarters to Cleaning Lab
	var west_thresh := ColorRect.new()
	west_thresh.color = Color(0.2, 0.24, 0.28)
	west_thresh.position = Vector2(415.0, 310.0)
	west_thresh.size = Vector2(10.0, 100.0)
	arch.add_child(west_thresh)

	# --- 3. North Wing: Archive Study Floor ---
	var north_floor := ColorRect.new()
	north_floor.color = Color(0.18, 0.14, 0.12) # Dark polished mahogany parquet
	north_floor.position = Vector2(420.0, 60.0)
	north_floor.size = Vector2(310.0, 160.0)
	arch.add_child(north_floor)

	# --- 4. East Wing: Bio-Recycler Wing Floor ---
	var east_floor := ColorRect.new()
	east_floor.color = Color(0.12, 0.18, 0.14) # Industrial bio-resin floor
	east_floor.position = Vector2(730.0, 240.0)
	east_floor.size = Vector2(320.0, 260.0)
	arch.add_child(east_floor)

	# East threshold
	var east_thresh := ColorRect.new()
	east_thresh.color = Color(0.18, 0.24, 0.18)
	east_thresh.position = Vector2(725.0, 310.0)
	east_thresh.size = Vector2(10.0, 100.0)
	arch.add_child(east_thresh)

	# --- Walls & Room Outlines ---
	# North interior wall for Living Quarters & side wings
	var n_wall := ColorRect.new()
	n_wall.color = Color(0.1, 0.14, 0.18)
	n_wall.position = Vector2(100.0, 215.0)
	n_wall.size = Vector2(320.0, 25.0)
	arch.add_child(n_wall)

	var e_wall := ColorRect.new()
	e_wall.color = Color(0.1, 0.14, 0.18)
	e_wall.position = Vector2(730.0, 215.0)
	e_wall.size = Vector2(320.0, 25.0)
	arch.add_child(e_wall)

	# South Exit Doorway
	var exit_mat := ColorRect.new()
	exit_mat.color = Color(0.2, 0.14, 0.08)
	exit_mat.position = Vector2(536.0, 575.0)
	exit_mat.size = Vector2(80.0, 10.0)
	arch.add_child(exit_mat)

	add_child(arch)


## Sets up Y-Sorted 2.5D World container.
func _create_world_25d() -> void:
	world_25d = Node2D.new()
	world_25d.name = "World25D"
	world_25d.y_sort_enabled = true
	add_child(world_25d)


## Spawns furniture, survivor bed, drafting table, cleaning bench, codex terminal, and bio-synthesizer.
func _create_furniture_and_stations() -> void:
	# 1. Survivor Bed (Living Quarters southwest: 480, 480)
	var bed := StaticBody2D.new()
	bed.position = Vector2(470.0, 500.0)

	var b_col := CollisionShape2D.new()
	var b_shape := RectangleShape2D.new()
	b_shape.size = Vector2(54.0, 70.0)
	b_col.shape = b_shape
	b_col.position = Vector2(0.0, -10.0)
	bed.add_child(b_col)

	var b_shadow := Polygon2D.new()
	b_shadow.polygon = _make_ellipse(32.0, 12.0, Vector2(0.0, 8.0))
	b_shadow.color = Color(0, 0, 0, 0.35)
	bed.add_child(b_shadow)

	var mattress := ColorRect.new()
	mattress.color = Color(0.75, 0.72, 0.65)
	mattress.position = Vector2(-25.0, -42.0)
	mattress.size = Vector2(50.0, 68.0)
	bed.add_child(mattress)

	var blanket := ColorRect.new()
	blanket.color = Color(0.22, 0.42, 0.52)
	blanket.position = Vector2(-25.0, -22.0)
	blanket.size = Vector2(50.0, 48.0)
	bed.add_child(blanket)

	var pillow := ColorRect.new()
	pillow.color = Color(0.92, 0.9, 0.85)
	pillow.position = Vector2(-20.0, -38.0)
	pillow.size = Vector2(40.0, 14.0)
	bed.add_child(pillow)

	world_25d.add_child(bed)

	# 2. Architect's Drafting Table (Living Quarters: 650, 360)
	var drafting := StaticBody2D.new()
	drafting.name = "DraftingTable"
	drafting.position = DRAFTING_TABLE_POS

	var d_col := CollisionShape2D.new()
	var d_box := RectangleShape2D.new()
	d_box.size = Vector2(68.0, 34.0)
	d_col.shape = d_box
	d_col.position = Vector2(0.0, -6.0)
	drafting.add_child(d_col)

	var d_shadow := Polygon2D.new()
	d_shadow.polygon = _make_ellipse(42.0, 16.0, Vector2(0.0, 4.0))
	d_shadow.color = Color(0, 0, 0, 0.4)
	drafting.add_child(d_shadow)

	# Wooden Drafting Board
	var table_board := Polygon2D.new()
	table_board.polygon = PackedVector2Array([
		Vector2(-32.0, 0.0),
		Vector2(32.0, 0.0),
		Vector2(30.0, -38.0),
		Vector2(-30.0, -38.0)
	])
	table_board.color = Color(0.48, 0.32, 0.18)
	drafting.add_child(table_board)

	# Blueprint paper sheet on table
	var blueprint_sheet := Polygon2D.new()
	blueprint_sheet.polygon = PackedVector2Array([
		Vector2(-24.0, -6.0),
		Vector2(24.0, -6.0),
		Vector2(22.0, -32.0),
		Vector2(-22.0, -32.0)
	])
	blueprint_sheet.color = Color(0.18, 0.45, 0.75, 0.9)
	drafting.add_child(blueprint_sheet)

	# Brass architect lamp
	var d_lamp := ColorRect.new()
	d_lamp.color = Color(0.85, 0.75, 0.3)
	d_lamp.position = Vector2(-28.0, -42.0)
	d_lamp.size = Vector2(6.0, 12.0)
	drafting.add_child(d_lamp)

	var d_label := Label.new()
	d_label.text = "DRAFTING TABLE\n[E] Expand Home"
	d_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_label.position = Vector2(-70.0, -65.0)
	d_label.size = Vector2(140.0, 28.0)
	d_label.add_theme_font_size_override("font_size", 10)
	d_label.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	drafting.add_child(d_label)

	world_25d.add_child(drafting)

	# 3. Laser & Ultrasonic Cleaning Bench (West Wing: 240, 360)
	var bench := StaticBody2D.new()
	bench.name = "CleaningBench"
	bench.position = CLEANING_BENCH_POS

	var cb_col := CollisionShape2D.new()
	var cb_box := RectangleShape2D.new()
	cb_box.size = Vector2(90.0, 38.0)
	cb_col.shape = cb_box
	cb_col.position = Vector2(0.0, -6.0)
	bench.add_child(cb_col)

	var cb_shadow := Polygon2D.new()
	cb_shadow.polygon = _make_ellipse(54.0, 18.0, Vector2(0.0, 6.0))
	cb_shadow.color = Color(0, 0, 0, 0.42)
	bench.add_child(cb_shadow)

	# Stainless steel workbench top
	var steel_top := ColorRect.new()
	steel_top.color = Color(0.35, 0.38, 0.42)
	steel_top.position = Vector2(-42.0, -32.0)
	steel_top.size = Vector2(84.0, 32.0)
	bench.add_child(steel_top)

	# Glowing ultrasonic cleaning bath (cyan liquid basin)
	var basin := ColorRect.new()
	basin.color = Color(0.15, 0.75, 0.9, 0.8)
	basin.position = Vector2(-34.0, -26.0)
	basin.size = Vector2(36.0, 20.0)
	bench.add_child(basin)

	# Articulated Laser Cleaning Arm
	var laser_arm := Line2D.new()
	laser_arm.points = PackedVector2Array([
		Vector2(25.0, -10.0),
		Vector2(32.0, -38.0),
		Vector2(14.0, -44.0),
		Vector2(-12.0, -22.0)
	])
	laser_arm.default_color = Color(0.2, 0.22, 0.25)
	laser_arm.width = 3.0
	bench.add_child(laser_arm)

	# Glowing laser lens tip
	var laser_tip := Polygon2D.new()
	laser_tip.polygon = _make_ellipse(4.0, 4.0, Vector2(-12.0, -22.0))
	laser_tip.color = Color(1.0, 0.25, 0.25, 0.9)
	bench.add_child(laser_tip)

	var cb_label := Label.new()
	cb_label.text = "CLEANING BENCH\n[E] Restore Relics"
	cb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cb_label.position = Vector2(-75.0, -65.0)
	cb_label.size = Vector2(150.0, 28.0)
	cb_label.add_theme_font_size_override("font_size", 10)
	cb_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.75))
	bench.add_child(cb_label)

	world_25d.add_child(bench)

	# 4. Human History Codex Terminal (North Wing: 576, 130)
	var codex := StaticBody2D.new()
	codex.name = "CodexTerminal"
	codex.position = CODEX_TERMINAL_POS

	var cx_col := CollisionShape2D.new()
	var cx_box := RectangleShape2D.new()
	cx_box.size = Vector2(70.0, 30.0)
	cx_col.shape = cx_box
	cx_col.position = Vector2(0.0, -6.0)
	codex.add_child(cx_col)

	var cx_desk := ColorRect.new()
	cx_desk.color = Color(0.25, 0.18, 0.14)
	cx_desk.position = Vector2(-32.0, -30.0)
	cx_desk.size = Vector2(64.0, 28.0)
	codex.add_child(cx_desk)

	# Glowing Terminal Hologram Screen
	var cx_screen := Polygon2D.new()
	cx_screen.polygon = PackedVector2Array([
		Vector2(-20.0, -32.0),
		Vector2(20.0, -32.0),
		Vector2(16.0, -56.0),
		Vector2(-16.0, -56.0)
	])
	cx_screen.color = Color(0.2, 0.8, 1.0, 0.75)
	codex.add_child(cx_screen)

	var cx_label := Label.new()
	cx_label.text = "HISTORY CODEX\n[E] Old World Lore"
	cx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cx_label.position = Vector2(-70.0, -78.0)
	cx_label.size = Vector2(140.0, 26.0)
	cx_label.add_theme_font_size_override("font_size", 9)
	cx_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	codex.add_child(cx_label)

	world_25d.add_child(codex)

	# 5. Barnacle Bio-Synthesizer (East Wing: 900, 360)
	var synth := StaticBody2D.new()
	synth.name = "BioSynthesizer"
	synth.position = BIO_SYNTH_POS

	var s_col := CollisionShape2D.new()
	var s_box := RectangleShape2D.new()
	s_box.size = Vector2(80.0, 36.0)
	s_col.shape = s_box
	s_col.position = Vector2(0.0, -6.0)
	synth.add_child(s_col)

	var s_base := ColorRect.new()
	s_base.color = Color(0.18, 0.24, 0.18)
	s_base.position = Vector2(-36.0, -34.0)
	s_base.size = Vector2(72.0, 34.0)
	synth.add_child(s_base)

	# Green glowing bio-catalysis tank
	var s_tank := Polygon2D.new()
	s_tank.polygon = PackedVector2Array([
		Vector2(-24.0, -34.0),
		Vector2(24.0, -34.0),
		Vector2(20.0, -62.0),
		Vector2(-20.0, -62.0)
	])
	s_tank.color = Color(0.2, 0.9, 0.4, 0.65)
	synth.add_child(s_tank)

	var s_label := Label.new()
	s_label.text = "BIO-SYNTHESIZER\n[E] Scrap Crust to Gold"
	s_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_label.position = Vector2(-80.0, -82.0)
	s_label.size = Vector2(160.0, 26.0)
	s_label.add_theme_font_size_override("font_size", 9)
	s_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	synth.add_child(s_label)

	world_25d.add_child(synth)


## Creates the physical wall barriers blocking access to locked wings.
func _create_room_barriers() -> void:
	# 1. North Wing Barrier (Archive Study): at x: 576, y: 220
	north_barrier = StaticBody2D.new()
	north_barrier.name = "NorthBarrier"
	north_barrier.position = Vector2(576.0, 220.0)

	var n_col := CollisionShape2D.new()
	var n_box := RectangleShape2D.new()
	n_box.size = Vector2(180.0, 22.0)
	n_col.shape = n_box
	north_barrier.add_child(n_col)

	# Boarded-up wooden planks
	for i in range(-80, 80, 30):
		var plank := ColorRect.new()
		plank.color = Color(0.38, 0.24, 0.14)
		plank.position = Vector2(float(i), -10.0)
		plank.size = Vector2(28.0, 20.0)
		north_barrier.add_child(plank)

	# Yellow hazard caution tape
	var n_tape := Line2D.new()
	n_tape.points = PackedVector2Array([Vector2(-85.0, 0.0), Vector2(85.0, 0.0)])
	n_tape.default_color = Color(1.0, 0.85, 0.15, 0.9)
	n_tape.width = 4.0
	north_barrier.add_child(n_tape)

	var n_sign := Label.new()
	n_sign.text = "LOCKED: ARCHIVE STUDY\n(Drafting Table: $200 + 1 BP)"
	n_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_sign.position = Vector2(-110.0, -36.0)
	n_sign.size = Vector2(220.0, 28.0)
	n_sign.add_theme_font_size_override("font_size", 9)
	n_sign.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	north_barrier.add_child(n_sign)

	world_25d.add_child(north_barrier)

	# 2. East Wing Barrier (Bio-Recycler): at x: 730, y: 360
	east_barrier = StaticBody2D.new()
	east_barrier.name = "EastBarrier"
	east_barrier.position = Vector2(730.0, 360.0)

	var e_col := CollisionShape2D.new()
	var e_box := RectangleShape2D.new()
	e_box.size = Vector2(22.0, 140.0)
	e_col.shape = e_box
	east_barrier.add_child(e_col)

	var shutter := ColorRect.new()
	shutter.color = Color(0.25, 0.28, 0.32)
	shutter.position = Vector2(-10.0, -65.0)
	shutter.size = Vector2(20.0, 130.0)
	east_barrier.add_child(shutter)

	var e_tape := Line2D.new()
	e_tape.points = PackedVector2Array([Vector2(0.0, -60.0), Vector2(0.0, 60.0)])
	e_tape.default_color = Color(1.0, 0.85, 0.15, 0.9)
	e_tape.width = 4.0
	east_barrier.add_child(e_tape)

	var e_sign := Label.new()
	e_sign.text = "LOCKED: BIO-RECYCLER\n(Drafting Table: $400 + 2 BP)"
	e_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e_sign.position = Vector2(-75.0, -84.0)
	e_sign.size = Vector2(150.0, 28.0)
	e_sign.add_theme_font_size_override("font_size", 9)
	e_sign.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	east_barrier.add_child(e_sign)

	world_25d.add_child(east_barrier)


## Synchronizes room barriers with Backpack.unlocked_rooms state.
func _update_room_barriers() -> void:
	var bp = _get_backpack()
	if bp == null:
		return

	var is_archive: bool = bp.unlocked_rooms.get("archive_study", false)
	if north_barrier != null:
		north_barrier.visible = not is_archive
		var col = north_barrier.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null:
			col.disabled = is_archive

	var is_bio: bool = bp.unlocked_rooms.get("bio_recycler", false)
	if east_barrier != null:
		east_barrier.visible = not is_bio
		var col = east_barrier.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col != null:
			col.disabled = is_bio


## Creates the 2.5D Player Survivor inside the Living Quarters.
func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "PlayerSurvivor"
	player.position = Vector2(576.0, 480.0)

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


## Snappy 8-directional walking controls inside the home.
func _handle_player_movement() -> void:
	if player == null:
		return

	# Freeze player movement while any modal is open
	if current_open_modal != "" or (inventory_modal != null and inventory_modal.visible):
		player.velocity = Vector2.ZERO
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

	# Clamp to interior home room bounds
	player.position.x = clampf(player.position.x, 110.0, 1040.0)
	player.position.y = clampf(player.position.y, 70.0, 580.0)

	# Legacy sprite fallback flipping if not using VisualRig
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and absf(player.velocity.x) > 5.0:
		sprite.flip_h = player.velocity.x < 0.0


## Updates top HUD stats and interaction prompt banners.
func _update_prompts_and_hud() -> void:
	if player == null or prompt_label == null:
		return

	if current_open_modal != "":
		prompt_label.visible = false
	elif player.position.distance_to(EXIT_DOOR_POS) < 70.0:
		prompt_label.text = "🚪 Press [F] Exit to Island"
		prompt_label.visible = true
	elif player.position.distance_to(BED_POS) < 65.0:
		prompt_label.text = "🛏️ Press [E] Sleep & End Day"
		prompt_label.visible = true
	elif player.position.distance_to(DRAFTING_TABLE_POS) < 65.0:
		prompt_label.text = "📐 Press [E] Open Drafting Table (Home Expansion)"
		prompt_label.visible = true
	elif player.position.distance_to(CLEANING_BENCH_POS) < 65.0:
		prompt_label.text = "🔬 Press [E] Use Laser Cleaning Bench"
		prompt_label.visible = true
	elif player.position.distance_to(CODEX_TERMINAL_POS) < 65.0:
		var bp = _get_backpack()
		if bp != null and bp.unlocked_rooms.get("archive_study", false):
			prompt_label.text = "📖 Press [E] Access Human History Codex"
			prompt_label.visible = true
		else:
			prompt_label.visible = false
	elif player.position.distance_to(BIO_SYNTH_POS) < 65.0:
		var bp = _get_backpack()
		if bp != null and bp.unlocked_rooms.get("bio_recycler", false):
			prompt_label.text = "♻️ Press [E] Operate Bio-Synthesizer (Scrap Crust)"
			prompt_label.visible = true
		else:
			prompt_label.visible = false
	else:
		prompt_label.visible = false

	# Top HUD
	if hud_label != null:
		var bp = _get_backpack()
		var cur_day: int = int(bp.current_day) if bp != null else 1
		var gold_val: int = int(bp.gold) if bp != null else 0
		var bp_val: int = int(bp.blueprints) if bp != null else 0
		var cur_w: float = float(bp.current_weight) if bp != null else 0.0
		var max_w: float = float(bp.max_weight) if bp != null else 15.0

		hud_label.text = "SURVIVOR'S HOMESTEAD  |  Day %d  |  Gold: $%d  |  Blueprints: %d  |  Cargo: %.1f / %.1f kg  |  [TAB / I] Manifest" % [
			cur_day, gold_val, bp_val, cur_w, max_w
		]


## Sets up HUD layer.
func _setup_ui() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1

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
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(376.0, 560.0)
	prompt_label.size = Vector2(400.0, 36.0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.visible = false
	hud_layer.add_child(prompt_label)

	add_child(hud_layer)

	_setup_inventory_ui()


# ==============================================================================
# MODAL 1: Architect's Drafting Table (Home Expansion)
# ==============================================================================
func _setup_drafting_modal() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DraftingLayer"
	layer.layer = 10

	drafting_modal = Control.new()
	drafting_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	drafting_modal.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	drafting_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	drafting_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 420.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.08, 0.16, 0.96)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.2, 0.6, 0.9, 0.85)
	p_style.content_margin_left = 24.0
	p_style.content_margin_right = 24.0
	p_style.content_margin_top = 18.0
	p_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "ARCHITECT'S DRAFTING TABLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	vbox.add_child(title)

	drafting_funds_label = Label.new()
	drafting_funds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drafting_funds_label.add_theme_font_size_override("font_size", 14)
	drafting_funds_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	vbox.add_child(drafting_funds_label)

	drafting_feedback_label = Label.new()
	drafting_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drafting_feedback_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(drafting_feedback_label)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	drafting_items_vbox = VBoxContainer.new()
	drafting_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drafting_items_vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(drafting_items_vbox)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var footer := HBoxContainer.new()
	var hint := Label.new()
	hint.text = "Press [F] or [ESC] to Exit Drafting Table"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	footer.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80.0, 28.0)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_all_modals)
	footer.add_child(close_btn)
	vbox.add_child(footer)

	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(drafting_modal)
	add_child(layer)


func _open_drafting_modal() -> void:
	current_open_modal = "drafting"
	drafting_feedback_label.text = ""
	drafting_modal.visible = true
	_refresh_drafting_ui()


func _refresh_drafting_ui() -> void:
	if drafting_items_vbox == null:
		return

	for c in drafting_items_vbox.get_children():
		c.queue_free()

	var bp = _get_backpack()
	var cur_gold: int = int(bp.gold) if bp != null else 0
	var cur_bp: int = int(bp.blueprints) if bp != null else 0
	drafting_funds_label.text = "Available Funds: $%d  |  Modular Blueprints: %d" % [cur_gold, cur_bp]

	# --- Expansion 1: North Wing - Archive Study ---
	var is_archive: bool = bp.unlocked_rooms.get("archive_study", false) if bp != null else false
	_add_drafting_row(
		"NORTH WING: ARCHIVE STUDY",
		"Expands Old World history codex terminal & boosts Alien Museum Admission by +50% ($25/visitor).",
		200, 1, is_archive,
		func():
			if bp != null and bp.unlock_room("archive_study", 200, 1):
				_update_room_barriers()
				drafting_feedback_label.text = "✓ Archive Study constructed! North barrier removed."
				drafting_feedback_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
				_refresh_drafting_ui()
			else:
				drafting_feedback_label.text = "✗ Insufficient Gold or Blueprints ($200 + 1 BP required)!"
				drafting_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	)

	# --- Expansion 2: East Wing - Bio-Recycler Wing ---
	var is_bio: bool = bp.unlocked_rooms.get("bio_recycler", false) if bp != null else false
	_add_drafting_row(
		"EAST WING: BIO-RECYCLER WING",
		"Houses the Barnacle Bio-Synthesizer to convert ocean calcification & rust into pure Gold ($50/batch).",
		400, 2, is_bio,
		func():
			if bp != null and bp.unlock_room("bio_recycler", 400, 2):
				_update_room_barriers()
				drafting_feedback_label.text = "✓ Bio-Recycler constructed! East barrier removed."
				drafting_feedback_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
				_refresh_drafting_ui()
			else:
				drafting_feedback_label.text = "✗ Insufficient Gold or Blueprints ($400 + 2 BP required)!"
				drafting_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	)


func _add_drafting_row(room_title: String, desc_text: String, gold_cost: int, bp_cost: int, is_unlocked: bool, on_construct: Callable) -> void:
	var row := PanelContainer.new()
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.06, 0.12, 0.22, 0.85)
	r_style.set_corner_radius_all(8)
	r_style.content_margin_left = 14.0
	r_style.content_margin_right = 14.0
	r_style.content_margin_top = 10.0
	r_style.content_margin_bottom = 10.0
	r_style.border_width_left = 3
	r_style.border_color = Color(0.4, 1.0, 0.6) if is_unlocked else Color(0.3, 0.7, 0.9)
	row.add_theme_stylebox_override("panel", r_style)

	var hbox := HBoxContainer.new()
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var t_lbl := Label.new()
	t_lbl.text = room_title
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	info_vbox.add_child(t_lbl)

	var d_lbl := Label.new()
	d_lbl.text = desc_text
	d_lbl.add_theme_font_size_override("font_size", 12)
	d_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95, 0.85))
	info_vbox.add_child(d_lbl)

	hbox.add_child(info_vbox)

	if is_unlocked:
		var badge := Label.new()
		badge.text = "✓ CONSTRUCTED"
		badge.add_theme_font_size_override("font_size", 13)
		badge.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
		hbox.add_child(badge)
	else:
		var buy_btn := Button.new()
		buy_btn.text = "Construct [$%d + %d BP]" % [gold_cost, bp_cost]
		buy_btn.custom_minimum_size = Vector2(170.0, 34.0)
		buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		buy_btn.add_theme_font_size_override("font_size", 12)
		buy_btn.pressed.connect(on_construct)
		hbox.add_child(buy_btn)

	row.add_child(hbox)
	drafting_items_vbox.add_child(row)


# ==============================================================================
# MODAL 2: Interactive Relic Cleaning & Restoration Bench
# ==============================================================================
func _setup_cleaning_modal() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CleaningLayer"
	layer.layer = 10

	cleaning_modal = Control.new()
	cleaning_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	cleaning_modal.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	cleaning_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cleaning_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660.0, 460.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.08, 0.16, 0.96)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.2, 0.85, 0.7, 0.85)
	p_style.content_margin_left = 24.0
	p_style.content_margin_right = 24.0
	p_style.content_margin_top = 18.0
	p_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "LASER & ULTRASONIC RELIC RESTORATION BENCH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.95, 0.75))
	vbox.add_child(title)

	var subhead := Label.new()
	subhead.text = "Strip calcified ocean sediment and barnacles to discover preserved human artifacts."
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_font_size_override("font_size", 12)
	subhead.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95, 0.8))
	vbox.add_child(subhead)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Main Body: Left Side (Encrusted Relics list) & Right Side (Active Laser Rig)
	var main_hbox := HBoxContainer.new()
	main_hbox.custom_minimum_size = Vector2(610.0, 280.0)
	main_hbox.add_theme_constant_override("separation", 14)

	# Left: Scrollable List of Encrusted Relics
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250.0, 270.0)
	cleaning_items_vbox = VBoxContainer.new()
	cleaning_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cleaning_items_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(cleaning_items_vbox)
	main_hbox.add_child(scroll)

	# Right: Interactive Laser Station Panel
	cleaning_station_panel = PanelContainer.new()
	cleaning_station_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cs_style := StyleBoxFlat.new()
	cs_style.bg_color = Color(0.06, 0.12, 0.22, 0.9)
	cs_style.set_corner_radius_all(8)
	cs_style.content_margin_left = 16.0
	cs_style.content_margin_right = 16.0
	cs_style.content_margin_top = 16.0
	cs_style.content_margin_bottom = 16.0
	cleaning_station_panel.add_theme_stylebox_override("panel", cs_style)

	var cs_vbox := VBoxContainer.new()
	cs_vbox.add_theme_constant_override("separation", 10)
	cs_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	cleaning_preview_control = Control.new()
	cleaning_preview_control.custom_minimum_size = Vector2(280.0, 150.0)
	cleaning_preview_control.clip_contents = true
	cs_vbox.add_child(cleaning_preview_control)

	var hint_lbl := Label.new()
	hint_lbl.text = "Click or drag mouse across barnacles to chip them off!"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.8))
	cs_vbox.add_child(hint_lbl)

	cleaning_crust_label = Label.new()
	cleaning_crust_label.text = "Barnacle & Rust Crust: 100%"
	cleaning_crust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cleaning_crust_label.add_theme_font_size_override("font_size", 14)
	cleaning_crust_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	cs_vbox.add_child(cleaning_crust_label)

	cleaning_crust_bar = ProgressBar.new()
	cleaning_crust_bar.custom_minimum_size = Vector2(280.0, 24.0)
	cleaning_crust_bar.max_value = 100.0
	cleaning_crust_bar.value = 100.0
	cleaning_crust_bar.show_percentage = false
	cs_vbox.add_child(cleaning_crust_bar)

	cleaning_pulse_btn = Button.new()
	cleaning_pulse_btn.text = "⚡ FIRE CLEANING LASER (Space or Click)"
	cleaning_pulse_btn.custom_minimum_size = Vector2(280.0, 42.0)
	cleaning_pulse_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cleaning_pulse_btn.add_theme_font_size_override("font_size", 13)
	cleaning_pulse_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8))
	cleaning_pulse_btn.pressed.connect(_pulse_cleaning_laser)
	cs_vbox.add_child(cleaning_pulse_btn)

	# Celebratory Reveal Popup Panel inside station
	cleaning_reveal_panel = PanelContainer.new()
	cleaning_reveal_panel.visible = false
	var rev_style := StyleBoxFlat.new()
	rev_style.bg_color = Color(0.04, 0.16, 0.12, 0.95)
	rev_style.set_corner_radius_all(6)
	rev_style.border_width_left = 2
	rev_style.border_color = Color(0.2, 1.0, 0.5)
	rev_style.content_margin_left = 12.0
	rev_style.content_margin_right = 12.0
	rev_style.content_margin_top = 8.0
	rev_style.content_margin_bottom = 8.0
	cleaning_reveal_panel.add_theme_stylebox_override("panel", rev_style)

	var rev_vbox := VBoxContainer.new()
	cleaning_reveal_title = Label.new()
	cleaning_reveal_title.add_theme_font_size_override("font_size", 14)
	cleaning_reveal_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	rev_vbox.add_child(cleaning_reveal_title)

	cleaning_reveal_val = Label.new()
	cleaning_reveal_val.add_theme_font_size_override("font_size", 12)
	cleaning_reveal_val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	rev_vbox.add_child(cleaning_reveal_val)

	cleaning_reveal_desc = Label.new()
	cleaning_reveal_desc.add_theme_font_size_override("font_size", 11)
	cleaning_reveal_desc.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95, 0.85))
	cleaning_reveal_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rev_vbox.add_child(cleaning_reveal_desc)

	cleaning_reveal_panel.add_child(rev_vbox)
	cs_vbox.add_child(cleaning_reveal_panel)

	cleaning_station_panel.add_child(cs_vbox)
	main_hbox.add_child(cleaning_station_panel)
	vbox.add_child(main_hbox)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var footer := HBoxContainer.new()
	var hint := Label.new()
	hint.text = "Press [F] or [ESC] to Exit Workbench"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	footer.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80.0, 28.0)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_all_modals)
	footer.add_child(close_btn)
	vbox.add_child(footer)

	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(cleaning_modal)
	add_child(layer)


func _open_cleaning_modal() -> void:
	current_open_modal = "cleaning"
	cleaning_modal.visible = true
	cleaning_reveal_panel.visible = false
	active_cleaning_inventory_index = -1
	active_crust_integrity = 100.0
	_refresh_cleaning_list()


func _refresh_cleaning_list() -> void:
	if cleaning_items_vbox == null:
		return

	for c in cleaning_items_vbox.get_children():
		c.queue_free()

	var bp = _get_backpack()
	var items_list: Array = bp.items if bp != null else []
	var encrusted_indices: Array[int] = []

	for i in range(items_list.size()):
		if not bool(items_list[i].get("identified", true)):
			encrusted_indices.append(i)

	if encrusted_indices.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "All relics in pack cleaned!\nReady to exhibit in the Museum."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		cleaning_items_vbox.add_child(empty_lbl)

		if not cleaning_reveal_panel.visible:
			cleaning_crust_bar.visible = false
			cleaning_crust_label.text = "Workbench Idle"
			cleaning_pulse_btn.visible = false
		return

	cleaning_station_panel.visible = true
	cleaning_crust_bar.visible = true
	cleaning_pulse_btn.visible = true

	# Select first encrusted item by default if none active
	if active_cleaning_inventory_index == -1 or not encrusted_indices.has(active_cleaning_inventory_index):
		active_cleaning_inventory_index = encrusted_indices[0]
		cleaning_reveal_panel.visible = false
		_setup_barnacle_chamber()

	for idx in encrusted_indices:
		var item: Dictionary = items_list[idx]
		var btn := Button.new()
		btn.text = "Encrusted Lump (%.1f kg)" % float(item.get("weight", 0.0))
		btn.custom_minimum_size = Vector2(230.0, 34.0)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 12)
		if idx == active_cleaning_inventory_index:
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
		else:
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

		btn.pressed.connect(func():
			active_cleaning_inventory_index = idx
			cleaning_reveal_panel.visible = false
			_setup_barnacle_chamber()
			_refresh_cleaning_list()
		)
		cleaning_items_vbox.add_child(btn)

	_update_cleaning_progress_display()


## Prepares the interactive scraping chamber: displays clean relic underneath and 7 randomized Barnacle Clumps
func _setup_barnacle_chamber() -> void:
	if cleaning_preview_control == null:
		return

	for c in cleaning_preview_control.get_children():
		c.queue_free()

	barnacle_clumps.clear()

	var bp = _get_backpack()
	if bp == null or active_cleaning_inventory_index < 0 or active_cleaning_inventory_index >= bp.items.size():
		return

	var item: Dictionary = bp.items[active_cleaning_inventory_index]
	var rid: String = str(item.get("id", ""))

	# 1. Inspection Chamber Background Panel
	var bg_panel := Panel.new()
	bg_panel.custom_minimum_size = Vector2(280.0, 150.0)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.06, 0.12, 0.96)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.15, 0.5, 0.65, 0.75)
	bg_style.set_corner_radius_all(6)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	cleaning_preview_control.add_child(bg_panel)

	# 2. Relic Anchor at Center (140, 75)
	var relic_anchor := Node2D.new()
	relic_anchor.name = "RelicAnchor"
	relic_anchor.position = Vector2(140.0, 75.0)
	cleaning_preview_control.add_child(relic_anchor)
	_chamber_relic_node = relic_anchor

	if bp.has_method("build_relic_visual"):
		var r_vis: Node2D = bp.build_relic_visual(rid, "clean_icon")
		if r_vis != null:
			r_vis.scale = Vector2(1.5, 1.5)
			relic_anchor.add_child(r_vis)

	# 3. Rock Debris Layer
	var debris_node := Node2D.new()
	debris_node.name = "DebrisLayer"
	debris_node.position = Vector2(140.0, 75.0)
	cleaning_preview_control.add_child(debris_node)
	_chamber_debris_node = debris_node

	# 4. Spawn 7 Randomized Barnacle Clumps covering the relic
	barnacle_total_count = 7
	barnacle_remaining_count = 7
	active_crust_integrity = 100.0

	var offsets = [
		Vector2(0.0, 0.0),
		Vector2(-26.0, -18.0),
		Vector2(24.0, -16.0),
		Vector2(-28.0, 14.0),
		Vector2(26.0, 16.0),
		Vector2(-4.0, -28.0),
		Vector2(6.0, 26.0)
	]

	for i in range(barnacle_total_count):
		var clump := Control.new()
		clump.name = "BarnacleClump_%d" % i
		clump.custom_minimum_size = Vector2(42.0, 38.0)
		clump.mouse_default_cursor_shape = Control.CURSOR_CROSS
		clump.position = Vector2(140.0, 75.0) + offsets[i] - Vector2(21.0, 19.0)

		# Rocky jagged polygon
		var poly := Polygon2D.new()
		poly.position = Vector2(21.0, 19.0)
		var rock_pts := PackedVector2Array()
		var n_verts: int = 8
		var base_rad: float = 18.0 + randf_range(-2.0, 2.0)
		for v in range(n_verts):
			var a: float = (float(v) / float(n_verts)) * TAU
			var r: float = base_rad + randf_range(-4.0, 4.0)
			rock_pts.append(Vector2(cos(a) * r, sin(a) * (r * 0.85)))
		poly.polygon = rock_pts
		var rock_colors = [Color("#3D3228"), Color("#4E3F33"), Color("#5A4A3C"), Color("#352A21")]
		poly.color = rock_colors[i % rock_colors.size()]
		clump.add_child(poly)

		# Dark inner crater / suction pore
		var crater := Polygon2D.new()
		crater.position = Vector2(21.0, 19.0)
		var c_pts := PackedVector2Array()
		for v in range(6):
			var a: float = (float(v) / 6.0) * TAU
			c_pts.append(Vector2(cos(a) * 5.0, sin(a) * 4.0))
		crater.polygon = c_pts
		crater.color = Color("#17120E")
		clump.add_child(crater)

		# Click or drag scraping
		clump.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_chip_barnacle_clump(clump)
		)
		clump.mouse_entered.connect(func():
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_chip_barnacle_clump(clump)
		)

		cleaning_preview_control.add_child(clump)
		barnacle_clumps.append(clump)

	_update_cleaning_progress_display()


## Chips off an individual barnacle clump with particle burst, screen shake, and laser audio
func _chip_barnacle_clump(clump: Control) -> void:
	if not barnacle_clumps.has(clump):
		return
	barnacle_clumps.erase(clump)
	barnacle_remaining_count = barnacle_clumps.size()

	var bp = _get_backpack()
	if bp != null and bp.has_method("play_sfx"):
		bp.play_sfx("laser_clean")

	# Spawn rock debris fragments
	if _chamber_debris_node != null and is_instance_valid(_chamber_debris_node):
		var clump_rel_pos = clump.position + Vector2(21.0, 19.0) - Vector2(140.0, 75.0)
		for f in range(5):
			var frag := Polygon2D.new()
			var frag_pts := PackedVector2Array([
				Vector2(-3.0, -3.0), Vector2(3.0, -2.0),
				Vector2(2.0, 4.0), Vector2(-3.0, 2.0)
			])
			frag.polygon = frag_pts
			frag.color = Color("#6E5D4E")
			frag.position = clump_rel_pos
			_chamber_debris_node.add_child(frag)

			var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			var dist: float = randf_range(25.0, 60.0)
			var ft := frag.create_tween().set_parallel(true)
			ft.tween_property(frag, "position", clump_rel_pos + dir * dist, 0.3).set_ease(Tween.EASE_OUT)
			ft.tween_property(frag, "rotation", randf_range(-3.0, 3.0), 0.3)
			ft.tween_property(frag, "modulate:a", 0.0, 0.3)
			ft.chain().tween_callback(frag.queue_free)

	# Inspection chamber shake
	if cleaning_preview_control != null:
		var orig_x = cleaning_preview_control.position.x
		var shake := cleaning_preview_control.create_tween()
		shake.tween_property(cleaning_preview_control, "position:x", orig_x + randf_range(-4.0, 4.0), 0.03)
		shake.tween_property(cleaning_preview_control, "position:x", orig_x, 0.03)

	# Clump destruction tween
	var ct := clump.create_tween().set_parallel(true)
	ct.tween_property(clump, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK)
	ct.tween_property(clump, "modulate:a", 0.0, 0.12)
	ct.chain().tween_callback(clump.queue_free)

	_update_cleaning_progress_display()

	# If all cleared: reveal and identify relic!
	if barnacle_remaining_count <= 0:
		_on_relic_fully_cleaned()


func _update_cleaning_progress_display() -> void:
	if barnacle_total_count > 0:
		active_crust_integrity = (float(barnacle_remaining_count) / float(barnacle_total_count)) * 100.0
	else:
		active_crust_integrity = 0.0

	if cleaning_crust_bar != null:
		cleaning_crust_bar.value = active_crust_integrity
	if cleaning_crust_label != null:
		if barnacle_remaining_count > 0:
			cleaning_crust_label.text = "Barnacle & Rust Crust: %d%% (%d clumps remaining)" % [int(active_crust_integrity), barnacle_remaining_count]
		else:
			cleaning_crust_label.text = "Barnacle & Rust Crust: 0% (Fully Restored!)"
	if cleaning_pulse_btn != null:
		cleaning_pulse_btn.disabled = barnacle_remaining_count <= 0


func _on_relic_fully_cleaned() -> void:
	var bp = _get_backpack()
	if bp == null or active_cleaning_inventory_index < 0:
		return

	# Celebratory scale bounce on clean relic
	if _chamber_relic_node != null and is_instance_valid(_chamber_relic_node):
		var rt := _chamber_relic_node.create_tween()
		rt.tween_property(_chamber_relic_node, "scale", Vector2(1.7, 1.7), 0.2).set_trans(Tween.TRANS_BACK)
		rt.tween_property(_chamber_relic_node, "scale", Vector2(1.5, 1.5), 0.2)

	if bp.has_method("play_sfx"):
		bp.play_sfx("pickup")

	var revealed: Dictionary = bp.clean_item_at(active_cleaning_inventory_index)

	cleaning_reveal_panel.visible = true
	cleaning_reveal_title.text = "✨ RELIC IDENTIFIED: %s" % revealed.get("name", "Human Relic")
	cleaning_reveal_val.text = "Salvage Value: $%d Gold  •  Weight: %.1f kg  •  Rarity: %s" % [
		int(revealed.get("value", 0)), float(revealed.get("weight", 0.0)), str(revealed.get("rarity", "Common"))
	]
	cleaning_reveal_desc.text = "\"%s\"" % str(revealed.get("alien_desc", ""))

	_refresh_cleaning_list()
	_update_prompts_and_hud()


## Pulses the cleaning laser arm (chips 1 barnacle clump if any remain)
func _pulse_cleaning_laser() -> void:
	if active_cleaning_inventory_index < 0:
		return
	if not barnacle_clumps.is_empty():
		_chip_barnacle_clump(barnacle_clumps[0])


# ==============================================================================
# MODAL 3: Human History Codex Terminal (Archive Study)
# ==============================================================================
func _setup_codex_modal() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CodexLayer"
	layer.layer = 10

	codex_modal = Control.new()
	codex_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	codex_modal.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	codex_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	codex_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600.0, 420.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.08, 0.16, 0.96)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.3, 0.75, 1.0, 0.85)
	p_style.content_margin_left = 24.0
	p_style.content_margin_right = 24.0
	p_style.content_margin_top = 18.0
	p_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "HUMAN HISTORY ARCHIVES & CODEX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(title)

	var perk_lbl := Label.new()
	perk_lbl.text = "★ ARCHIVE STUDY PERK ACTIVE: +50% Museum Alien Admission ($25/visitor) ★"
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	perk_lbl.add_theme_font_size_override("font_size", 12)
	perk_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	vbox.add_child(perk_lbl)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var lore := Label.new()
	lore.text = "CODEX ENTRY: THE RESOURCE WARS & THE FLOOD\n\nBefore the oceans rose, humanity built towering silicon monuments across continents now submerged under 200 meters of brine. Late-stage nuclear conflicts ruptured geothermal trenches and accelerated polar melt.\n\nToday, extraterrestrial species visit this world to marvel at our mundane remnants—caffeinated mugs, mechanical switches, and sealed server cores holding fragmented pre-war thoughts."
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.add_theme_font_size_override("font_size", 13)
	lore.add_theme_color_override("font_color", Color(0.85, 0.92, 0.98))
	vbox.add_child(lore)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var footer := HBoxContainer.new()
	var hint := Label.new()
	hint.text = "Press [F] or [ESC] to Exit Codex"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	footer.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80.0, 28.0)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_all_modals)
	footer.add_child(close_btn)
	vbox.add_child(footer)

	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(codex_modal)
	add_child(layer)


func _open_codex_modal() -> void:
	var bp = _get_backpack()
	if bp != null and bp.has_method("toggle_codex_ui"):
		bp.toggle_codex_ui()
	else:
		current_open_modal = "codex"
		codex_modal.visible = true


# ==============================================================================
# MODAL 4: Barnacle Bio-Synthesizer (Bio-Recycler Wing)
# ==============================================================================
func _setup_synth_modal() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SynthLayer"
	layer.layer = 10

	synth_modal = Control.new()
	synth_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	synth_modal.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	synth_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	synth_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580.0, 380.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.08, 0.16, 0.96)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.3, 0.9, 0.5, 0.85)
	p_style.content_margin_left = 24.0
	p_style.content_margin_right = 24.0
	p_style.content_margin_top = 18.0
	p_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "BARNACLE BIO-SYNTHESIZER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	vbox.add_child(title)

	var subhead := Label.new()
	subhead.text = "Refines scraped ocean barnacle biomass and rust slag into pure Gold scrap."
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_font_size_override("font_size", 12)
	subhead.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95, 0.8))
	vbox.add_child(subhead)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	synth_count_label = Label.new()
	synth_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synth_count_label.add_theme_font_size_override("font_size", 15)
	synth_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(synth_count_label)

	synth_feedback_label = Label.new()
	synth_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	synth_feedback_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(synth_feedback_label)

	var synth_btn := Button.new()
	synth_btn.text = "♻️ Refine 1 Bio-Slag Unit into +$50 Gold"
	synth_btn.custom_minimum_size = Vector2(300.0, 44.0)
	synth_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	synth_btn.add_theme_font_size_override("font_size", 13)
	synth_btn.pressed.connect(func():
		var bp = _get_backpack()
		if bp != null and bp.cleaned_crust_units > 0:
			bp.cleaned_crust_units -= 1
			bp.gold += 50
			if bp.has_method("play_sfx"):
				bp.play_sfx("cash")
			synth_feedback_label.text = "✓ Synthesized +$50 Gold from barnacle slag!"
			synth_feedback_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
			_refresh_synth_ui()
			_update_prompts_and_hud()
		else:
			synth_feedback_label.text = "✗ No bio-slag available. Clean encrusted relics at the workbench first!"
			synth_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	)
	vbox.add_child(synth_btn)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var footer := HBoxContainer.new()
	var hint := Label.new()
	hint.text = "Press [F] or [ESC] to Exit Synthesizer"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	footer.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80.0, 28.0)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_all_modals)
	footer.add_child(close_btn)
	vbox.add_child(footer)

	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(synth_modal)
	add_child(layer)


func _open_synth_modal() -> void:
	current_open_modal = "synth"
	synth_feedback_label.text = ""
	synth_modal.visible = true
	_refresh_synth_ui()


func _refresh_synth_ui() -> void:
	var bp = _get_backpack()
	var units: int = int(bp.cleaned_crust_units) if bp != null else 0
	if synth_count_label != null:
		synth_count_label.text = "Harvested Crust Slag: %d Units  |  Total Gold: $%d" % [units, int(bp.gold) if bp != null else 0]


# ==============================================================================
# MODAL 5: Survivor Bed (End-of-Day Settlement Overlay)
# ==============================================================================
func _setup_sleep_summary_modal() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SleepLayer"
	layer.layer = 20

	sleep_modal = Control.new()
	sleep_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	sleep_modal.visible = false

	sleep_dim = ColorRect.new()
	sleep_dim.color = Color(0.02, 0.04, 0.09, 0.95)
	sleep_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sleep_modal.add_child(sleep_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	sleep_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 360.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.05, 0.09, 0.18, 0.98)
	p_style.set_corner_radius_all(12)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.3, 0.75, 1.0, 0.85)
	p_style.content_margin_left = 32.0
	p_style.content_margin_right = 32.0
	p_style.content_margin_top = 28.0
	p_style.content_margin_bottom = 28.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	sleep_day_label = Label.new()
	sleep_day_label.text = "=== DAY 1 COMPLETED ==="
	sleep_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_day_label.add_theme_font_size_override("font_size", 22)
	sleep_day_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(sleep_day_label)

	var sub := Label.new()
	sub.text = "The sunken ruins fall quiet as you rest in your survivor quarters."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(sub)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 8)

	sleep_exhibits_label = Label.new()
	sleep_exhibits_label.text = "Exhibited Relics in Museum: 0 / 6"
	sleep_exhibits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_exhibits_label.add_theme_font_size_override("font_size", 15)
	sleep_exhibits_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	stats_box.add_child(sleep_exhibits_label)

	sleep_earnings_label = Label.new()
	sleep_earnings_label.text = "Daily Museum Patron Bonus: +$0 Gold"
	sleep_earnings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_earnings_label.add_theme_font_size_override("font_size", 16)
	sleep_earnings_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	stats_box.add_child(sleep_earnings_label)

	var save_note := Label.new()
	save_note.text = "✓ Game Saved Automatically."
	save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_note.add_theme_font_size_override("font_size", 13)
	save_note.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	stats_box.add_child(save_note)

	vbox.add_child(stats_box)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var btn_center := CenterContainer.new()
	sleep_next_btn = Button.new()
	sleep_next_btn.text = "☀️ Start Day 2 (Space / Click)"
	sleep_next_btn.custom_minimum_size = Vector2(280.0, 44.0)
	sleep_next_btn.add_theme_font_size_override("font_size", 15)
	sleep_next_btn.pressed.connect(_on_start_next_day_pressed)
	btn_center.add_child(sleep_next_btn)
	vbox.add_child(btn_center)

	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(sleep_modal)
	add_child(layer)


func _open_sleep_summary_modal() -> void:
	current_open_modal = "sleep"
	var bp = _get_backpack()
	var day: int = int(bp.current_day) if bp != null else 1
	var exhibits_count: int = bp.exhibited_relics.size() if bp != null else 0

	var bonus_per_relic: int = 40
	var is_archive: bool = bp != null and bp.unlocked_rooms.get("archive_study", false)
	if is_archive:
		bonus_per_relic = 60 # +50% Archive Study boost

	sleep_calculated_bonus = exhibits_count * bonus_per_relic

	if sleep_day_label != null:
		sleep_day_label.text = "=== DAY %d COMPLETED ===" % day
	if sleep_exhibits_label != null:
		sleep_exhibits_label.text = "Exhibited Relics in Museum: %d / 6" % exhibits_count
	if sleep_earnings_label != null:
		if is_archive and exhibits_count > 0:
			sleep_earnings_label.text = "Daily Museum Patron Bonus: +$%d Gold  (+50%% Archive Boost!)" % sleep_calculated_bonus
		else:
			sleep_earnings_label.text = "Daily Museum Patron Bonus: +$%d Gold" % sleep_calculated_bonus
	if sleep_next_btn != null:
		sleep_next_btn.text = "☀️ Start Day %d (Space or Click)" % (day + 1)

	# Auto-save immediately upon initiating sleep
	if bp != null:
		bp.save_game()

	sleep_modal.visible = true
	# Smooth fade-in
	if sleep_dim != null:
		sleep_dim.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(sleep_dim, "modulate:a", 1.0, 0.35)


func _on_start_next_day_pressed() -> void:
	var bp = _get_backpack()
	if bp != null:
		bp.current_day += 1
		bp.gold += sleep_calculated_bonus
		bp.daily_museum_earnings = sleep_calculated_bonus
		if sleep_calculated_bonus > 0 and bp.has_method("play_sfx"):
			bp.play_sfx("cash")
		if bp.has_method("generate_daily_vip_quest"):
			bp.generate_daily_vip_quest()
		bp.save_game()

	_close_all_modals()
	_update_prompts_and_hud()

	var new_day: int = int(bp.current_day) if bp != null else 2
	_spawn_floating_cash_text(player.position + Vector2(0.0, -40.0), "Day %d Begun! +$%d Bonus" % [new_day, sleep_calculated_bonus])


## Displays floating green cash/status feedback text that drifts up and fades.
func _spawn_floating_cash_text(pos: Vector2, text: String) -> void:
	if world_25d == null:
		return
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


func _close_all_modals() -> void:
	current_open_modal = ""
	if drafting_modal != null: drafting_modal.visible = false
	if cleaning_modal != null: cleaning_modal.visible = false
	if codex_modal != null: codex_modal.visible = false
	if synth_modal != null: synth_modal.visible = false
	if sleep_modal != null: sleep_modal.visible = false
	_update_prompts_and_hud()


# ==============================================================================
# Backpack Inventory Manifest Overlay
# ==============================================================================
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
	footer.text = "[TAB] or [I] Close  |  Click [Drop] or Press [1-9] to Discard"
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
		var is_id: bool = bool(item.get("identified", true))
		var item_color: Color = item.get("color", Color.CYAN) if is_id else Color(0.72, 0.68, 0.58)

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
		if is_id:
			name_lbl.text = "%s%s  •  %.1f kg  •  %d cr" % [slot_p, item.get("name", ""), item.get("weight", 0.0), item.get("value", 0)]
		else:
			name_lbl.text = "%sEncrusted Relic Lump (%.1f kg)  •  ??? cr" % [slot_p, float(item.get("weight", 0.0))]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", item_color)
		info_vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		if is_id:
			desc_lbl.text = "\"%s\"" % str(item.get("alien_desc", ""))
		else:
			desc_lbl.text = "\"[Heavily encrusted with ocean calcification. Clean at Home Lab workbench to reveal.]\""
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
		var ang: float = (float(i) / float(segs)) * TAU
		pts.append(offset + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


func _get_backpack() -> Node:
	if Engine.has_singleton("Backpack"):
		return Engine.get_singleton("Backpack")
	if get_node_or_null("/root/Backpack") != null:
		return get_node("/root/Backpack")
	return null
