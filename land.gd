class_name LandHub
extends Node2D

## LandHub: 2.5D Top-Down Coastal Island Hub
## Features coastline & pier, beach, post-apocalyptic grass, 2.5D Y-sorted Player,
## 2.5D Museum building with roof depth-sorting, and scene transitions.

var player: CharacterBody2D
var world_25d: Node2D
var hud_label: Label
var prompt_label: Label
var inventory_modal: Control
var manifest_summary_label: Label
var manifest_items_container: VBoxContainer

# Shop UI modal references
var current_open_shop: String = ""
var shop_modal: Control
var shop_content_vbox: VBoxContainer
var shop_title_label: Label
var shop_gold_label: Label
var shop_feedback_label: Label
var reset_modal: Control

# Alien VIP Quest Board UI references
var vip_quest_modal: Control
var _vip_client_lbl: Label
var _vip_dialogue_lbl: Label
var _vip_target_card: PanelContainer
var _vip_target_name_lbl: Label
var _vip_target_stats_lbl: Label
var _vip_deliver_btn: Button
var _vip_status_lbl: Label

const WALK_SPEED: float = 210.0
const MUSEUM_DOOR_POS: Vector2 = Vector2(750.0, 350.0)
const VIP_BOARD_POS: Vector2 = Vector2(650.0, 360.0)
const GEAR_WORKSHOP_DOOR_POS: Vector2 = Vector2(450.0, 220.0)
const EXO_SHOP_DOOR_POS: Vector2 = Vector2(520.0, 480.0)
const HOME_DOOR_POS: Vector2 = Vector2(820.0, 520.0)


func _ready() -> void:
	_create_terrain_background()
	_create_world_25d()
	_create_decorations()
	_create_museum_building()
	_create_vip_board()
	_create_gear_workshop()
	_create_exo_cargo_building()
	_create_homestead_building()
	_create_player()
	_setup_ui()
	_setup_shop_modal()
	_setup_vip_quest_modal()


func _physics_process(delta: float) -> void:
	_handle_player_movement(delta)
	_update_prompts_and_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# If reset modal is open, ESC closes it and blocks other inputs
		if reset_modal != null and reset_modal.visible:
			if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				reset_modal.visible = false
			return

		# F9: Trigger Save Data Reset Confirmation
		if event.physical_keycode == KEY_F9 or event.keycode == KEY_F9:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			_show_reset_save_modal()
			return

		# If VIP quest modal is open, F or ESC closes it
		if vip_quest_modal != null and vip_quest_modal.visible:
			if event.physical_keycode == KEY_F or event.keycode == KEY_F or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				vip_quest_modal.visible = false
				return

		# If a shop window is currently open, F or ESC closes it
		if current_open_shop != "":
			if event.physical_keycode == KEY_F or event.keycode == KEY_F or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_close_shop()
				return

		# Toggle Human Civilization Codex with C
		if event.physical_keycode == KEY_C or event.keycode == KEY_C:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			var bp = _get_backpack()
			if bp != null and bp.has_method("toggle_codex_ui"):
				bp.toggle_codex_ui()
			return

		# Toggle backpack manifest with TAB or I
		if event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_I or event.keycode == KEY_TAB or event.keycode == KEY_I:
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
			_toggle_inventory()
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

		# Interaction key F
		if event.physical_keycode == KEY_F or event.keycode == KEY_F:
			if player == null:
				return

			# 1. Dive into Ocean at wooden pier
			if player.position.x < 240.0 and player.position.y >= 240.0 and player.position.y <= 420.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				if is_inside_tree():
					get_tree().change_scene_to_file("res://ocean.tscn")
				return

			# 2. Open Diving Gear Workshop
			if player.position.distance_to(GEAR_WORKSHOP_DOOR_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_open_shop("gear")
				return

			# 3. Open Exo-Cargo Shop
			if player.position.distance_to(EXO_SHOP_DOOR_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_open_shop("cargo")
				return

			# 3b. Open Alien VIP Quest Board
			if player.position.distance_to(VIP_BOARD_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				_open_vip_quest_modal()
				return

			# 4. Enter Museum at front door
			if player.position.distance_to(MUSEUM_DOOR_POS) < 70.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				if is_inside_tree():
					get_tree().change_scene_to_file("res://museum.tscn")
				return

			# 5. Enter Survivor's Home & Cleaning Lab
			if player.position.distance_to(HOME_DOOR_POS) < 65.0:
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
				if is_inside_tree():
					get_tree().change_scene_to_file("res://home.tscn")
				return


## Draws the 2D coastal island background (ocean, beach, grass, pier).
func _create_terrain_background() -> void:
	var bg := CanvasGroup.new()
	bg.name = "TerrainBackground"

	# 1. Deep ocean water on the left (x: 0 to 240)
	var ocean_rect := ColorRect.new()
	ocean_rect.color = Color(0.08, 0.24, 0.42)
	ocean_rect.position = Vector2(0.0, 0.0)
	ocean_rect.size = Vector2(250.0, 648.0)
	bg.add_child(ocean_rect)

	# Ocean waves / shoreline foam
	var foam := ColorRect.new()
	foam.color = Color(0.45, 0.75, 0.9, 0.6)
	foam.position = Vector2(240.0, 0.0)
	foam.size = Vector2(16.0, 648.0)
	bg.add_child(foam)

	# 2. Sandy beach in the middle (x: 250 to 520)
	var beach_rect := ColorRect.new()
	beach_rect.color = Color(0.84, 0.76, 0.52)
	beach_rect.position = Vector2(250.0, 0.0)
	beach_rect.size = Vector2(270.0, 648.0)
	bg.add_child(beach_rect)

	# 3. Overgrown post-apocalyptic grass on the right (x: 520 to 1152)
	var grass_rect := ColorRect.new()
	grass_rect.color = Color(0.24, 0.42, 0.22)
	grass_rect.position = Vector2(520.0, 0.0)
	grass_rect.size = Vector2(632.0, 648.0)
	bg.add_child(grass_rect)

	# Dirt pathway leading to the Museum
	var path_poly := Polygon2D.new()
	path_poly.polygon = PackedVector2Array([
		Vector2(220.0, 310.0),
		Vector2(520.0, 320.0),
		Vector2(750.0, 370.0),
		Vector2(750.0, 395.0),
		Vector2(520.0, 345.0),
		Vector2(220.0, 335.0)
	])
	path_poly.color = Color(0.55, 0.48, 0.35, 0.7)
	bg.add_child(path_poly)

	# 4. Wooden Pier extending into the ocean (x: 60 to 250, y: 280 to 360)
	var pier := ColorRect.new()
	pier.name = "WoodenPier"
	pier.color = Color(0.44, 0.28, 0.16)
	pier.position = Vector2(60.0, 290.0)
	pier.size = Vector2(180.0, 60.0)
	bg.add_child(pier)

	# Pier planks details
	for px in range(70, 240, 20):
		var plank_line := ColorRect.new()
		plank_line.color = Color(0.3, 0.18, 0.1)
		plank_line.position = Vector2(float(px), 290.0)
		plank_line.size = Vector2(2.0, 60.0)
		bg.add_child(plank_line)

	var pier_sign := Label.new()
	pier_sign.text = "OCEAN EXPEDITION PIER"
	pier_sign.position = Vector2(65.0, 268.0)
	pier_sign.add_theme_font_size_override("font_size", 12)
	pier_sign.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	bg.add_child(pier_sign)

	add_child(bg)


## Sets up the Y-Sorted 2.5D World container.
func _create_world_25d() -> void:
	world_25d = Node2D.new()
	world_25d.name = "World25D"
	world_25d.y_sort_enabled = true
	add_child(world_25d)


## Spawns 2.5D ruined pillars and overgrown trees to test depth sorting.
func _create_decorations() -> void:
	# Ruined Ancient Pillars
	_spawn_pillar(Vector2(580.0, 230.0))
	_spawn_pillar(Vector2(620.0, 480.0))
	_spawn_pillar(Vector2(960.0, 420.0))

	# Overgrown Trees
	_spawn_tree(Vector2(540.0, 410.0))
	_spawn_tree(Vector2(950.0, 210.0))
	_spawn_tree(Vector2(1040.0, 360.0))


func _spawn_pillar(pos: Vector2) -> void:
	var pillar := StaticBody2D.new()
	pillar.position = pos

	# Footprint collision at base
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	col.shape = circle
	col.position = Vector2(0.0, 0.0)
	pillar.add_child(col)

	# Ground shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(22.0, 10.0)
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	pillar.add_child(shadow)

	# 2.5D Pillar shaft (extends upward to y = -65)
	var shaft := Polygon2D.new()
	shaft.polygon = PackedVector2Array([
		Vector2(-14.0, 0.0),
		Vector2(14.0, 0.0),
		Vector2(14.0, -65.0),
		Vector2(-14.0, -65.0)
	])
	shaft.color = Color(0.68, 0.66, 0.62)
	pillar.add_child(shaft)

	# Pillar Capital / Top
	var cap := Polygon2D.new()
	cap.polygon = PackedVector2Array([
		Vector2(-18.0, -65.0),
		Vector2(18.0, -65.0),
		Vector2(18.0, -75.0),
		Vector2(-18.0, -75.0)
	])
	cap.color = Color(0.8, 0.78, 0.74)
	pillar.add_child(cap)

	# Creeping moss vines
	var moss := Polygon2D.new()
	moss.polygon = PackedVector2Array([
		Vector2(-14.0, -10.0),
		Vector2(6.0, -20.0),
		Vector2(4.0, -38.0),
		Vector2(-14.0, -30.0)
	])
	moss.color = Color(0.25, 0.5, 0.22, 0.8)
	pillar.add_child(moss)

	world_25d.add_child(pillar)


func _spawn_tree(pos: Vector2) -> void:
	var tree_node := StaticBody2D.new()
	tree_node.position = pos

	# Collision at base
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	tree_node.add_child(col)

	# Shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(28.0, 14.0)
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	tree_node.add_child(shadow)

	# Trunk
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-8.0, 0.0),
		Vector2(8.0, 0.0),
		Vector2(6.0, -45.0),
		Vector2(-6.0, -45.0)
	])
	trunk.color = Color(0.38, 0.25, 0.15)
	tree_node.add_child(trunk)

	# Foliage Canopy (extends up to y = -110)
	var foliage := Polygon2D.new()
	foliage.polygon = _make_ellipse(38.0, 36.0, Vector2(0.0, -75.0))
	foliage.color = Color(0.18, 0.45, 0.2)
	tree_node.add_child(foliage)

	world_25d.add_child(tree_node)


## Builds the 2.5D Museum building with roof Y-Sort depth effects.
func _create_museum_building() -> void:
	var museum := StaticBody2D.new()
	museum.name = "MuseumBuildingExterior"
	# Base footprint line at y = 350
	museum.position = Vector2(750.0, 350.0)

	# 1. Ground Shadow underneath building
	var b_shadow := Polygon2D.new()
	b_shadow.polygon = PackedVector2Array([
		Vector2(-170.0, 15.0),
		Vector2(170.0, 15.0),
		Vector2(155.0, -15.0),
		Vector2(-155.0, -15.0)
	])
	b_shadow.color = Color(0.0, 0.0, 0.0, 0.4)
	museum.add_child(b_shadow)

	# 2. Collision Box on Lower Footprint Only (allows walking behind the roof and in front of the door)
	# Left wall footprint
	var col_left := CollisionShape2D.new()
	var rect_left := RectangleShape2D.new()
	rect_left.size = Vector2(110.0, 32.0)
	col_left.shape = rect_left
	col_left.position = Vector2(-95.0, -16.0)
	museum.add_child(col_left)

	# Right wall footprint
	var col_right := CollisionShape2D.new()
	var rect_right := RectangleShape2D.new()
	rect_right.size = Vector2(110.0, 32.0)
	col_right.shape = rect_right
	col_right.position = Vector2(95.0, -16.0)
	museum.add_child(col_right)

	# 3. Main Front Wall (Weathered Stone)
	var front_wall := Polygon2D.new()
	front_wall.polygon = PackedVector2Array([
		Vector2(-150.0, 0.0),
		Vector2(150.0, 0.0),
		Vector2(150.0, -110.0),
		Vector2(-150.0, -110.0)
	])
	front_wall.color = Color(0.52, 0.54, 0.55)
	museum.add_child(front_wall)

	# Decorative wall pillars
	for wx in [-140.0, -70.0, 70.0, 140.0]:
		var wall_col := Polygon2D.new()
		wall_col.polygon = PackedVector2Array([
			Vector2(wx - 8.0, 0.0),
			Vector2(wx + 8.0, 0.0),
			Vector2(wx + 8.0, -110.0),
			Vector2(wx - 8.0, -110.0)
		])
		wall_col.color = Color(0.64, 0.66, 0.68)
		museum.add_child(wall_col)

	# 4. Front Doorway (centered at bottom)
	var doorway := Polygon2D.new()
	doorway.polygon = PackedVector2Array([
		Vector2(-28.0, 0.0),
		Vector2(28.0, 0.0),
		Vector2(28.0, -68.0),
		Vector2(-28.0, -68.0)
	])
	doorway.color = Color(0.12, 0.15, 0.18)
	museum.add_child(doorway)

	# Golden warm interior glow from doorway
	var door_glow := Polygon2D.new()
	door_glow.polygon = PackedVector2Array([
		Vector2(-22.0, 0.0),
		Vector2(22.0, 0.0),
		Vector2(22.0, -62.0),
		Vector2(-22.0, -62.0)
	])
	door_glow.color = Color(0.9, 0.7, 0.3, 0.45)
	museum.add_child(door_glow)

	# 5. Grand Pitched Roof (extends up to y = -190)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-165.0, -110.0),
		Vector2(165.0, -110.0),
		Vector2(130.0, -185.0),
		Vector2(-130.0, -185.0)
	])
	roof.color = Color(0.38, 0.22, 0.2) # Weathered terra-cotta/rust
	museum.add_child(roof)

	var roof_trim := ColorRect.new()
	roof_trim.color = Color(0.28, 0.16, 0.14)
	roof_trim.position = Vector2(-168.0, -113.0)
	roof_trim.size = Vector2(336.0, 6.0)
	museum.add_child(roof_trim)

	# 6. Museum Exterior Signboard
	var sign_bg := ColorRect.new()
	sign_bg.color = Color(0.15, 0.22, 0.3, 0.95)
	sign_bg.position = Vector2(-110.0, -96.0)
	sign_bg.size = Vector2(220.0, 24.0)
	museum.add_child(sign_bg)

	var sign_label := Label.new()
	sign_label.text = "HUMAN RELIC MUSEUM"
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.position = Vector2(-110.0, -94.0)
	sign_label.size = Vector2(220.0, 24.0)
	sign_label.add_theme_font_size_override("font_size", 13)
	sign_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	sign_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sign_label.add_theme_constant_override("outline_size", 2)
	museum.add_child(sign_label)

	# Smart Sprite Auto-Loader (Direction 4)
	if Engine.has_singleton("Backpack"):
		Engine.get_singleton("Backpack").load_smart_sprite(museum, "res://assets/buildings/museum.png", Vector2(300.0, 150.0))
	elif get_node_or_null("/root/Backpack") != null:
		get_node("/root/Backpack").load_smart_sprite(museum, "res://assets/buildings/museum.png", Vector2(300.0, 150.0))

	world_25d.add_child(museum)


## Builds the interactive Alien VIP Request Board at (650, 360).
func _create_vip_board() -> void:
	var board := StaticBody2D.new()
	board.name = "AlienVIPBoard"
	board.position = VIP_BOARD_POS

	# Ground shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(28.0, 10.0, Vector2(0.0, 4.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	board.add_child(shadow)

	# Footprint collision
	var col := CollisionShape2D.new()
	var col_shape := RectangleShape2D.new()
	col_shape.size = Vector2(44.0, 18.0)
	col.shape = col_shape
	col.position = Vector2(0.0, 0.0)
	board.add_child(col)

	# Twin wooden / alloy mounting posts
	var post_left := ColorRect.new()
	post_left.color = Color(0.28, 0.2, 0.15)
	post_left.position = Vector2(-16.0, -36.0)
	post_left.size = Vector2(5.0, 36.0)
	board.add_child(post_left)

	var post_right := ColorRect.new()
	post_right.color = Color(0.28, 0.2, 0.15)
	post_right.position = Vector2(11.0, -36.0)
	post_right.size = Vector2(5.0, 36.0)
	board.add_child(post_right)

	# Main Notice Board backing
	var backing := Polygon2D.new()
	backing.polygon = PackedVector2Array([
		Vector2(-28.0, -34.0),
		Vector2(28.0, -34.0),
		Vector2(28.0, -74.0),
		Vector2(-28.0, -74.0)
	])
	backing.color = Color(0.1, 0.14, 0.2)
	board.add_child(backing)

	# Neon border / frame
	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2(-28.0, -34.0),
		Vector2(28.0, -34.0),
		Vector2(28.0, -74.0),
		Vector2(-28.0, -74.0),
		Vector2(-28.0, -34.0)
	])
	border.width = 2.0
	border.default_color = Color(0.2, 0.85, 0.75, 0.9)
	board.add_child(border)

	# Holographic beacon light on top
	var beacon := Polygon2D.new()
	beacon.polygon = PackedVector2Array([
		Vector2(0.0, -82.0),
		Vector2(6.0, -74.0),
		Vector2(-6.0, -74.0)
	])
	beacon.color = Color(0.3, 1.0, 0.8, 0.9)
	board.add_child(beacon)

	# Glowing holographic quest bulletins
	var doc1 := ColorRect.new()
	doc1.color = Color(0.95, 0.85, 0.45, 0.88)
	doc1.position = Vector2(-22.0, -68.0)
	doc1.size = Vector2(18.0, 26.0)
	board.add_child(doc1)

	var doc2 := ColorRect.new()
	doc2.color = Color(0.3, 0.9, 1.0, 0.88)
	doc2.position = Vector2(4.0, -66.0)
	doc2.size = Vector2(18.0, 26.0)
	board.add_child(doc2)

	# Board text label
	var b_lbl := Label.new()
	b_lbl.text = "ALIEN VIP BOARD"
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.position = Vector2(-60.0, -96.0)
	b_lbl.size = Vector2(120.0, 16.0)
	b_lbl.add_theme_font_size_override("font_size", 9)
	b_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.85))
	board.add_child(b_lbl)

	world_25d.add_child(board)


## Builds the 2.5D O2 & Thruster Workshop around (450, 220).
func _create_gear_workshop() -> void:
	var shop := StaticBody2D.new()
	shop.name = "DivingGearWorkshopExterior"
	shop.position = GEAR_WORKSHOP_DOOR_POS

	# 1. Ground shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(80.0, 14.0, Vector2(0.0, 4.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.38)
	shop.add_child(shadow)

	# 2. Footprint collision on lower base (allows Y-sorting behind roof and in front of door)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(124.0, 28.0)
	col.shape = rect
	col.position = Vector2(0.0, -14.0)
	shop.add_child(col)

	# 3. Metallic Blue-Grey Front Wall
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(-62.0, 0.0),
		Vector2(62.0, 0.0),
		Vector2(62.0, -78.0),
		Vector2(-62.0, -78.0)
	])
	wall.color = Color(0.36, 0.44, 0.52)
	shop.add_child(wall)

	# Steel panel seam lines
	for wx in [-30.0, 0.0, 30.0]:
		var seam := ColorRect.new()
		seam.color = Color(0.28, 0.34, 0.4, 0.8)
		seam.position = Vector2(wx, -78.0)
		seam.size = Vector2(1.0, 78.0)
		shop.add_child(seam)

	# 4. Sloped Industrial Steel Roof
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-70.0, -78.0),
		Vector2(70.0, -78.0),
		Vector2(52.0, -125.0),
		Vector2(-52.0, -125.0)
	])
	roof.color = Color(0.24, 0.3, 0.38)
	shop.add_child(roof)

	var roof_trim := ColorRect.new()
	roof_trim.color = Color(0.18, 0.22, 0.28)
	roof_trim.position = Vector2(-72.0, -80.0)
	roof_trim.size = Vector2(144.0, 4.0)
	shop.add_child(roof_trim)

	# 5. Decorative Yellow Oxygen Tank Cylinder on side (x = 72)
	var tank := Polygon2D.new()
	tank.polygon = PackedVector2Array([
		Vector2(68.0, 0.0),
		Vector2(84.0, 0.0),
		Vector2(84.0, -56.0),
		Vector2(81.0, -62.0),
		Vector2(71.0, -62.0),
		Vector2(68.0, -56.0)
	])
	tank.color = Color(0.96, 0.82, 0.2)
	shop.add_child(tank)

	# Steel straps on tank
	for ty in [-16.0, -36.0]:
		var strap := ColorRect.new()
		strap.color = Color(0.3, 0.3, 0.3)
		strap.position = Vector2(67.0, ty)
		strap.size = Vector2(18.0, 3.0)
		shop.add_child(strap)

	# Valve nozzle & pressure gauge
	var valve := ColorRect.new()
	valve.color = Color(0.75, 0.75, 0.75)
	valve.position = Vector2(74.0, -68.0)
	valve.size = Vector2(4.0, 7.0)
	shop.add_child(valve)

	var gauge := Polygon2D.new()
	gauge.polygon = _make_ellipse(4.0, 4.0, Vector2(76.0, -70.0))
	gauge.color = Color.WHITE
	shop.add_child(gauge)

	# 6. Front Doorway (centered at bottom)
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([
		Vector2(-18.0, 0.0),
		Vector2(18.0, 0.0),
		Vector2(18.0, -48.0),
		Vector2(-18.0, -48.0)
	])
	door.color = Color(0.14, 0.18, 0.24)
	shop.add_child(door)

	# Cyan interior gear glow
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-14.0, 0.0),
		Vector2(14.0, 0.0),
		Vector2(14.0, -44.0),
		Vector2(-14.0, -44.0)
	])
	glow.color = Color(0.3, 0.75, 0.95, 0.45)
	shop.add_child(glow)

	# Hazard warning header on door
	var hazard := ColorRect.new()
	hazard.color = Color(0.9, 0.8, 0.2)
	hazard.position = Vector2(-20.0, -52.0)
	hazard.size = Vector2(40.0, 4.0)
	shop.add_child(hazard)

	# 7. Signboard
	var sign_bg := ColorRect.new()
	sign_bg.color = Color(0.1, 0.16, 0.24, 0.95)
	sign_bg.position = Vector2(-60.0, -68.0)
	sign_bg.size = Vector2(120.0, 18.0)
	shop.add_child(sign_bg)

	var sign_lbl := Label.new()
	sign_lbl.text = "O2 & THRUSTER WORKSHOP"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.position = Vector2(-60.0, -67.0)
	sign_lbl.size = Vector2(120.0, 18.0)
	sign_lbl.add_theme_font_size_override("font_size", 9)
	sign_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	sign_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	sign_lbl.add_theme_constant_override("outline_size", 2)
	shop.add_child(sign_lbl)

	# Smart Sprite Auto-Loader (Direction 4)
	if Engine.has_singleton("Backpack"):
		Engine.get_singleton("Backpack").load_smart_sprite(shop, "res://assets/buildings/workshop_o2.png", Vector2(180.0, 130.0))
	elif get_node_or_null("/root/Backpack") != null:
		get_node("/root/Backpack").load_smart_sprite(shop, "res://assets/buildings/workshop_o2.png", Vector2(180.0, 130.0))

	world_25d.add_child(shop)


## Builds the 2.5D Exo-Cargo Riggers shop around (520, 480).
func _create_exo_cargo_building() -> void:
	var shop := StaticBody2D.new()
	shop.name = "ExoCargoRiggersExterior"
	shop.position = EXO_SHOP_DOOR_POS

	# 1. Ground shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(84.0, 14.0, Vector2(0.0, 4.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.38)
	shop.add_child(shadow)

	# 2. Footprint collision on lower base
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(130.0, 28.0)
	col.shape = rect
	col.position = Vector2(0.0, -14.0)
	shop.add_child(col)

	# 3. Rusty Orange / Industrial Yellow Wall
	var wall := Polygon2D.new()
	wall.polygon = PackedVector2Array([
		Vector2(-65.0, 0.0),
		Vector2(65.0, 0.0),
		Vector2(65.0, -72.0),
		Vector2(-65.0, -72.0)
	])
	wall.color = Color(0.72, 0.46, 0.22)
	shop.add_child(wall)

	# Rust stains / panel details
	for wx in [-32.0, 32.0]:
		var rib := ColorRect.new()
		rib.color = Color(0.55, 0.32, 0.15)
		rib.position = Vector2(wx, -72.0)
		rib.size = Vector2(2.0, 72.0)
		shop.add_child(rib)

	# 4. Flat Corrugated Industrial Roof
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-72.0, -72.0),
		Vector2(72.0, -72.0),
		Vector2(72.0, -94.0),
		Vector2(-72.0, -94.0)
	])
	roof.color = Color(0.32, 0.22, 0.16)
	shop.add_child(roof)

	for rx in range(-68, 70, 8):
		var rib := ColorRect.new()
		rib.color = Color(0.24, 0.16, 0.12)
		rib.position = Vector2(float(rx), -94.0)
		rib.size = Vector2(2.0, 22.0)
		shop.add_child(rib)

	# 5. Decorative Cargo Crates on left (x = -78)
	var crate1 := ColorRect.new()
	crate1.color = Color(0.48, 0.32, 0.18)
	crate1.position = Vector2(-84.0, -20.0)
	crate1.size = Vector2(18.0, 20.0)
	shop.add_child(crate1)

	var crate2 := ColorRect.new()
	crate2.color = Color(0.56, 0.38, 0.22)
	crate2.position = Vector2(-80.0, -36.0)
	crate2.size = Vector2(14.0, 16.0)
	shop.add_child(crate2)

	# Hydraulic Arm strut on right
	var strut := Polygon2D.new()
	strut.polygon = PackedVector2Array([
		Vector2(65.0, -10.0),
		Vector2(74.0, -4.0),
		Vector2(74.0, -50.0),
		Vector2(65.0, -56.0)
	])
	strut.color = Color(0.4, 0.42, 0.44)
	shop.add_child(strut)

	# 6. Heavy Industrial Reinforced Sliding Door
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([
		Vector2(-20.0, 0.0),
		Vector2(20.0, 0.0),
		Vector2(20.0, -48.0),
		Vector2(-20.0, -48.0)
	])
	door.color = Color(0.2, 0.22, 0.24)
	shop.add_child(door)

	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(-16.0, 0.0),
		Vector2(16.0, 0.0),
		Vector2(16.0, -44.0),
		Vector2(-16.0, -44.0)
	])
	glow.color = Color(0.95, 0.65, 0.2, 0.4)
	shop.add_child(glow)

	# 7. Signboard
	var sign_bg := ColorRect.new()
	sign_bg.color = Color(0.2, 0.14, 0.1, 0.95)
	sign_bg.position = Vector2(-60.0, -66.0)
	sign_bg.size = Vector2(120.0, 18.0)
	shop.add_child(sign_bg)

	var sign_lbl := Label.new()
	sign_lbl.text = "EXO-CARGO RIGGERS"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.position = Vector2(-60.0, -65.0)
	sign_lbl.size = Vector2(120.0, 18.0)
	sign_lbl.add_theme_font_size_override("font_size", 9)
	sign_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	sign_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	sign_lbl.add_theme_constant_override("outline_size", 2)
	shop.add_child(sign_lbl)

	# Smart Sprite Auto-Loader (Direction 4)
	if Engine.has_singleton("Backpack"):
		Engine.get_singleton("Backpack").load_smart_sprite(shop, "res://assets/buildings/workshop_exo.png", Vector2(180.0, 130.0))
	elif get_node_or_null("/root/Backpack") != null:
		get_node("/root/Backpack").load_smart_sprite(shop, "res://assets/buildings/workshop_exo.png", Vector2(180.0, 130.0))

	world_25d.add_child(shop)


## Procedurally builds the 2.5D Survivor's Homestead & Lab building.
func _create_homestead_building() -> void:
	var home := StaticBody2D.new()
	home.name = "SurvivorsHomestead"
	home.position = Vector2(820.0, 500.0)

	# 1. Base Footprint Collision (Player can walk behind roof and in front of door)
	var col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(170.0, 26.0)
	col.shape = box
	col.position = Vector2(-15.0, -8.0)
	home.add_child(col)

	# 2. Ground Shadow
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(95.0, 22.0, Vector2(-15.0, 0.0))
	shadow.color = Color(0.0, 0.0, 0.0, 0.42)
	home.add_child(shadow)

	# 3. Main Cabin Log Walls (x: -45 to 65, y: -72 to 0)
	var cabin_wall := Polygon2D.new()
	cabin_wall.polygon = PackedVector2Array([
		Vector2(-45.0, 0.0),
		Vector2(65.0, 0.0),
		Vector2(65.0, -70.0),
		Vector2(-45.0, -70.0)
	])
	cabin_wall.color = Color(0.42, 0.26, 0.14)
	home.add_child(cabin_wall)

	# Log horizontal siding details
	for ly in range(-64, 0, 10):
		var log_seam := ColorRect.new()
		log_seam.color = Color(0.3, 0.18, 0.09)
		log_seam.position = Vector2(-45.0, float(ly))
		log_seam.size = Vector2(110.0, 2.0)
		home.add_child(log_seam)

	# 4. Sloped Pitch Cabin Roof
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-50.0, -68.0),
		Vector2(10.0, -100.0),
		Vector2(70.0, -68.0)
	])
	roof.color = Color(0.26, 0.15, 0.08)
	home.add_child(roof)

	# 5. Solar Panel Array on Roof (Right slope)
	var solar := Polygon2D.new()
	solar.polygon = PackedVector2Array([
		Vector2(16.0, -96.0),
		Vector2(60.0, -74.0),
		Vector2(55.0, -70.0),
		Vector2(12.0, -90.0)
	])
	solar.color = Color(0.12, 0.22, 0.38)
	home.add_child(solar)

	# Solar panel grid lines
	var solar_line := Line2D.new()
	solar_line.points = PackedVector2Array([Vector2(36.0, -85.0), Vector2(33.0, -80.0)])
	solar_line.default_color = Color(0.4, 0.6, 0.8, 0.8)
	solar_line.width = 1.5
	home.add_child(solar_line)

	# 6. Attached Glass Lab Dome on Left Wing (x: -45 to -105, y: -54 to 0)
	var dome := Polygon2D.new()
	dome.polygon = PackedVector2Array([
		Vector2(-45.0, 0.0),
		Vector2(-100.0, 0.0),
		Vector2(-105.0, -18.0),
		Vector2(-95.0, -42.0),
		Vector2(-72.0, -56.0),
		Vector2(-45.0, -50.0)
	])
	dome.color = Color(0.18, 0.55, 0.68, 0.45)
	home.add_child(dome)

	# Dome curved steel ribs
	var dome_rib := Line2D.new()
	dome_rib.points = PackedVector2Array([
		Vector2(-100.0, 0.0),
		Vector2(-95.0, -42.0),
		Vector2(-72.0, -56.0),
		Vector2(-45.0, -50.0)
	])
	dome_rib.default_color = Color(0.35, 0.75, 0.88, 0.8)
	dome_rib.width = 2.0
	home.add_child(dome_rib)

	# Glowing ultrasonic cleaning vat silhouette inside dome
	var lab_glow := Polygon2D.new()
	lab_glow.polygon = _make_ellipse(12.0, 8.0, Vector2(-75.0, -16.0))
	lab_glow.color = Color(0.3, 0.9, 1.0, 0.6)
	home.add_child(lab_glow)

	# 7. Warm Glowing Cozy Window on Cabin
	var win := ColorRect.new()
	win.color = Color(1.0, 0.88, 0.38, 0.95)
	win.position = Vector2(25.0, -46.0)
	win.size = Vector2(26.0, 22.0)
	home.add_child(win)

	# Window mullions
	var m_v := ColorRect.new()
	m_v.color = Color(0.24, 0.14, 0.08)
	m_v.position = Vector2(37.0, -46.0)
	m_v.size = Vector2(2.0, 22.0)
	home.add_child(m_v)

	var m_h := ColorRect.new()
	m_h.color = Color(0.24, 0.14, 0.08)
	m_h.position = Vector2(25.0, -36.0)
	m_h.size = Vector2(26.0, 2.0)
	home.add_child(m_h)

	# Warm ground light spill
	var light_spill := Polygon2D.new()
	light_spill.polygon = PackedVector2Array([
		Vector2(20.0, 0.0),
		Vector2(56.0, 0.0),
		Vector2(64.0, 14.0),
		Vector2(12.0, 14.0)
	])
	light_spill.color = Color(1.0, 0.85, 0.35, 0.22)
	home.add_child(light_spill)

	# 8. Front Entrance Door
	var door := Polygon2D.new()
	door.polygon = PackedVector2Array([
		Vector2(-22.0, 0.0),
		Vector2(6.0, 0.0),
		Vector2(6.0, -46.0),
		Vector2(-22.0, -46.0)
	])
	door.color = Color(0.28, 0.16, 0.08)
	home.add_child(door)

	# Brass handle
	var handle := ColorRect.new()
	handle.color = Color(0.9, 0.75, 0.3)
	handle.position = Vector2(0.0, -24.0)
	handle.size = Vector2(3.0, 6.0)
	home.add_child(handle)

	# 9. Signboard
	var sign_bg := ColorRect.new()
	sign_bg.color = Color(0.18, 0.12, 0.08, 0.95)
	sign_bg.position = Vector2(-60.0, -64.0)
	sign_bg.size = Vector2(130.0, 16.0)
	home.add_child(sign_bg)

	var sign_lbl := Label.new()
	sign_lbl.text = "HOMESTEAD & LAB"
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_lbl.position = Vector2(-60.0, -64.0)
	sign_lbl.size = Vector2(130.0, 16.0)
	sign_lbl.add_theme_font_size_override("font_size", 9)
	sign_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	sign_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	sign_lbl.add_theme_constant_override("outline_size", 2)
	home.add_child(sign_lbl)

	# Smart Sprite Auto-Loader (Direction 4)
	if Engine.has_singleton("Backpack"):
		Engine.get_singleton("Backpack").load_smart_sprite(home, "res://assets/buildings/home.png", Vector2(220.0, 140.0))
	elif get_node_or_null("/root/Backpack") != null:
		get_node("/root/Backpack").load_smart_sprite(home, "res://assets/buildings/home.png", Vector2(220.0, 140.0))

	world_25d.add_child(home)


## Creates the 2.5D Player Survivor with foot-centered Y-sorting origin.
func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "PlayerSurvivor"
	# Start on the pier or beach
	player.position = Vector2(320.0, 320.0)

	# Collision around feet
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	col.shape = circle
	col.position = Vector2(0.0, -4.0)
	player.add_child(col)

	# Foot Shadow
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

	# Fallback Player Sprite offset upward so node origin is exactly at character's feet
	if not built_visual:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		if ResourceLoader.exists("res://icon.svg"):
			sprite.texture = load("res://icon.svg")
		sprite.scale = Vector2(0.4, 0.4)
		sprite.position = Vector2(0.0, -26.0)
		player.add_child(sprite)

	world_25d.add_child(player)


## Snappy 8-directional WASD/Arrow walking controls on land.
func _handle_player_movement(_delta: float) -> void:
	if player == null:
		return

	# Freeze player movement while shop modal, inventory, vip quest, or reset confirmation is open
	if current_open_shop != "" or (inventory_modal != null and inventory_modal.visible) or (reset_modal != null and reset_modal.visible) or (vip_quest_modal != null and vip_quest_modal.visible):
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

	# Clamp to land island boundaries
	player.position.x = clampf(player.position.x, 80.0, 1100.0)
	player.position.y = clampf(player.position.y, 80.0, 600.0)

	# Legacy sprite fallback flipping if not using VisualRig
	var sprite: Sprite2D = player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and absf(player.velocity.x) > 5.0:
		sprite.flip_h = player.velocity.x < 0.0


## Updates interaction prompt banners and top HUD stats.
func _update_prompts_and_hud() -> void:
	if player == null or prompt_label == null:
		return

	if current_open_shop != "" or (vip_quest_modal != null and vip_quest_modal.visible):
		prompt_label.visible = false
	elif player.position.x < 240.0 and player.position.y >= 250.0 and player.position.y <= 400.0:
		prompt_label.text = "🌊 Press [F] to Dive into the Ocean"
		prompt_label.visible = true
	elif player.position.distance_to(VIP_BOARD_POS) < 65.0:
		prompt_label.text = "📜 Press [F] Inspect Alien VIP Quest Board"
		prompt_label.visible = true
	elif player.position.distance_to(GEAR_WORKSHOP_DOOR_POS) < 65.0:
		prompt_label.text = "⚙️ Press [F] Open Diving Gear Workshop"
		prompt_label.visible = true
	elif player.position.distance_to(EXO_SHOP_DOOR_POS) < 65.0:
		prompt_label.text = "📦 Press [F] Open Exo-Cargo Shop"
		prompt_label.visible = true
	elif player.position.distance_to(MUSEUM_DOOR_POS) < 70.0:
		prompt_label.text = "🏛️ Press [F] to Enter Human Relic Museum"
		prompt_label.visible = true
	elif player.position.distance_to(HOME_DOOR_POS) < 65.0:
		prompt_label.text = "🏡 Press [F] Enter Home & Cleaning Lab"
		prompt_label.visible = true
	else:
		prompt_label.visible = false

	# Update Top HUD
	if hud_label != null:
		var bp = _get_backpack()
		var cur_day: int = int(bp.current_day) if bp != null else 1
		var gold_val: int = int(bp.gold) if bp != null else 0
		var bp_count: int = int(bp.blueprints) if bp != null else 0
		var cur_w: float = float(bp.current_weight) if bp != null else 0.0
		var max_w: float = float(bp.max_weight) if bp != null else 15.0
		var o2_lvl: int = int(bp.oxygen_level) if bp != null else 1
		var max_o2: float = float(bp.max_oxygen) if bp != null else 100.0

		hud_label.text = "ISLAND HUB  |  Day %d  |  Gold: $%d  |  Blueprints: %d  |  O2 Tank: %.0f (L%d)  |  Cargo: %.1f / %.1f kg  |  [C] Codex  |  [TAB / I] Manifest  |  [F9] Reset Save" % [
			cur_day, gold_val, bp_count, max_o2, o2_lvl, cur_w, max_w
		]


## Sets up HUD and Backpack inventory overlay.
func _setup_ui() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUDLayer"
	hud_layer.layer = 1

	# Top info bar
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.16, 0.8)
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

	# Centered Action Prompt
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
			desc_lbl.text = "\"[Heavily encrusted with ocean sediment. Clean at Home Lab workbench to reveal.]\""
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


## Sets up the interactive 2.5D Shop upgrade modal dialog.
func _setup_shop_modal() -> void:
	var shop_layer := CanvasLayer.new()
	shop_layer.name = "ShopModalLayer"
	shop_layer.layer = 10

	shop_modal = Control.new()
	shop_modal.name = "ShopModal"
	shop_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_modal.visible = false

	# Dimmed backdrop
	var dim := ColorRect.new()
	dim.name = "DimBackdrop"
	dim.color = Color(0.0, 0.02, 0.05, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_modal.add_child(dim)

	# Centered dialog
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580.0, 380.0)

	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.08, 0.16, 0.96)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(0.3, 0.75, 0.95, 0.85)
	p_style.content_margin_left = 24.0
	p_style.content_margin_right = 24.0
	p_style.content_margin_top = 18.0
	p_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", p_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)

	shop_title_label = Label.new()
	shop_title_label.text = "EQUIPMENT WORKSHOP"
	shop_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title_label.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(shop_title_label)

	shop_gold_label = Label.new()
	shop_gold_label.text = "Available Funds: $0"
	shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_gold_label.add_theme_font_size_override("font_size", 14)
	shop_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	main_vbox.add_child(shop_gold_label)

	shop_feedback_label = Label.new()
	shop_feedback_label.text = ""
	shop_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_feedback_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(shop_feedback_label)

	var sep1 := HSeparator.new()
	main_vbox.add_child(sep1)

	shop_content_vbox = VBoxContainer.new()
	shop_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_content_vbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(shop_content_vbox)

	var sep2 := HSeparator.new()
	main_vbox.add_child(sep2)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var footer_hint := Label.new()
	footer_hint.text = "Press [F] or [ESC] to Return to Island"
	footer_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hint.add_theme_font_size_override("font_size", 12)
	footer_hint.add_theme_color_override("font_color", Color(0.65, 0.75, 0.88))
	footer_hbox.add_child(footer_hint)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(80.0, 28.0)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(_close_shop)
	footer_hbox.add_child(close_btn)

	main_vbox.add_child(footer_hbox)

	panel.add_child(main_vbox)
	center.add_child(panel)
	shop_layer.add_child(shop_modal)
	add_child(shop_layer)


## Opens the specified shop modal ("gear" or "cargo").
func _open_shop(shop_type: String) -> void:
	if shop_modal == null:
		return
	current_open_shop = shop_type
	if inventory_modal != null and inventory_modal.visible:
		inventory_modal.visible = false
	shop_feedback_label.text = ""
	shop_modal.visible = true
	_refresh_shop_ui()


## Closes any open shop modal.
func _close_shop() -> void:
	current_open_shop = ""
	if shop_modal != null:
		shop_modal.visible = false
	_update_prompts_and_hud()


## Shows success or error feedback inside the active shop modal.
func _show_shop_feedback(text: String, success: bool) -> void:
	if shop_feedback_label == null:
		return
	shop_feedback_label.text = text
	if success:
		shop_feedback_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	else:
		shop_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


## Refreshes the content of the active shop modal with up-to-date stats, costs, and afford buttons.
func _refresh_shop_ui() -> void:
	if shop_content_vbox == null:
		return

	for child in shop_content_vbox.get_children():
		child.queue_free()

	var bp = _get_backpack()
	var current_gold: int = int(bp.gold) if bp != null else 0
	if shop_gold_label != null:
		shop_gold_label.text = "Available Funds: $%d" % current_gold

	if current_open_shop == "gear":
		if shop_title_label != null:
			shop_title_label.text = "O2 & THRUSTER WORKSHOP"
			shop_title_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))

		# 1. Oxygen Tank Upgrade
		var o2_lvl: int = int(bp.oxygen_level) if bp != null else 1
		var cur_o2: float = float(bp.max_oxygen) if bp != null else 100.0
		var next_o2: float = cur_o2 + 25.0
		var o2_cost: int = bp.get_oxygen_upgrade_cost() if bp != null else 100

		var o2_title: String = "Compressed Oxygen Tank (Level %d)" % o2_lvl
		var o2_desc: String = "Max O2: %.0f -> %.0f (+25 O2) | Allows longer deep-sea dives" % [cur_o2, next_o2]
		var o2_btn_text: String = "Upgrade [$%d]" % o2_cost
		var can_afford_o2: bool = current_gold >= o2_cost

		_add_upgrade_row(
			o2_title,
			o2_desc,
			Color(0.2, 0.8, 1.0),
			o2_btn_text,
			can_afford_o2,
			func():
				if bp != null and bp.upgrade_oxygen():
					_show_shop_feedback("✓ Oxygen tank upgraded to Level %d (%.0f O2)!" % [bp.oxygen_level, bp.max_oxygen], true)
					_refresh_shop_ui()
					_update_prompts_and_hud()
				else:
					_show_shop_feedback("✗ Insufficient gold! Need $%d." % o2_cost, false)
		)

		# 2. Hydro-Fins Upgrade
		var fins_lvl: int = int(bp.fins_level) if bp != null else 1
		var cur_spd: float = float(bp.swim_speed) if bp != null else 200.0
		var next_spd: float = cur_spd + 35.0
		var fins_cost: int = bp.get_fins_upgrade_cost() if bp != null else 120

		var fins_title: String = "Hydrodynamic Propulsion Fins (Level %d)" % fins_lvl
		var fins_desc: String = "Swim Speed: %.0f -> %.0f px/s (+35 px/s) | Move faster underwater" % [cur_spd, next_spd]
		var fins_btn_text: String = "Upgrade [$%d]" % fins_cost
		var can_afford_fins: bool = current_gold >= fins_cost

		_add_upgrade_row(
			fins_title,
			fins_desc,
			Color(0.3, 0.95, 0.7),
			fins_btn_text,
			can_afford_fins,
			func():
				if bp != null and bp.upgrade_fins():
					_show_shop_feedback("✓ Hydro-fins upgraded to Level %d (%.0f px/s)!" % [bp.fins_level, bp.swim_speed], true)
					_refresh_shop_ui()
					_update_prompts_and_hud()
				else:
					_show_shop_feedback("✗ Insufficient gold! Need $%d." % fins_cost, false)
		)

	elif current_open_shop == "cargo":
		if shop_title_label != null:
			shop_title_label.text = "EXO-CARGO RIGGERS"
			shop_title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))

		# Exo-Cargo Frame Upgrade
		var exo_lvl: int = int(bp.exo_level) if bp != null else 1
		var cur_cap: float = float(bp.max_weight) if bp != null else 15.0
		var next_cap: float = cur_cap + 7.5
		var exo_cost: int = bp.get_exo_upgrade_cost() if bp != null else 150

		var exo_title: String = "Titanium Exo-Cargo Rig (Level %d)" % exo_lvl
		var exo_desc: String = "Weight Capacity: %.1f -> %.1f kg (+7.5 kg) | Haul more relics without encumbrance" % [cur_cap, next_cap]
		var exo_btn_text: String = "Upgrade [$%d]" % exo_cost
		var can_afford_exo: bool = current_gold >= exo_cost

		_add_upgrade_row(
			exo_title,
			exo_desc,
			Color(1.0, 0.75, 0.3),
			exo_btn_text,
			can_afford_exo,
			func():
				if bp != null and bp.upgrade_exo():
					_show_shop_feedback("✓ Exo-frame upgraded to Level %d (%.1f kg capacity)!" % [bp.exo_level, bp.max_weight], true)
					_refresh_shop_ui()
					_update_prompts_and_hud()
				else:
					_show_shop_feedback("✗ Insufficient gold! Need $%d." % exo_cost, false)
		)


## Adds an upgrade product row inside the shop content container.
func _add_upgrade_row(
	title_text: String,
	desc_text: String,
	accent_color: Color,
	btn_text: String,
	can_afford: bool,
	on_click: Callable
) -> void:
	var row := PanelContainer.new()
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.06, 0.12, 0.22, 0.85)
	r_style.set_corner_radius_all(8)
	r_style.content_margin_left = 14.0
	r_style.content_margin_right = 14.0
	r_style.content_margin_top = 10.0
	r_style.content_margin_bottom = 10.0
	r_style.border_width_left = 3
	r_style.border_color = accent_color
	row.add_theme_stylebox_override("panel", r_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", accent_color)
	info_vbox.add_child(t_lbl)

	var d_lbl := Label.new()
	d_lbl.text = desc_text
	d_lbl.add_theme_font_size_override("font_size", 12)
	d_lbl.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95, 0.85))
	info_vbox.add_child(d_lbl)

	hbox.add_child(info_vbox)

	var buy_btn := Button.new()
	buy_btn.text = btn_text
	buy_btn.custom_minimum_size = Vector2(130.0, 36.0)
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	buy_btn.add_theme_font_size_override("font_size", 13)
	if can_afford:
		buy_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		buy_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	buy_btn.pressed.connect(on_click)
	hbox.add_child(buy_btn)

	row.add_child(hbox)
	shop_content_vbox.add_child(row)


## Displays a confirmation dialog before wiping savegame.json and restarting stats.
func _show_reset_save_modal() -> void:
	if reset_modal != null:
		reset_modal.visible = true
		return

	var layer := CanvasLayer.new()
	layer.name = "ResetSaveLayer"
	layer.layer = 25

	reset_modal = Control.new()
	reset_modal.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	reset_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	reset_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500.0, 260.0)
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.04, 0.05, 0.98)
	p_style.set_corner_radius_all(10)
	p_style.border_width_left = 2
	p_style.border_width_top = 2
	p_style.border_width_right = 2
	p_style.border_width_bottom = 2
	p_style.border_color = Color(1.0, 0.4, 0.4, 0.9)
	p_style.content_margin_left = 24.0
	p_style.content_margin_right = 24.0
	p_style.content_margin_top = 20.0
	p_style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", p_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)

	var title := Label.new()
	title.text = "⚠️ RESET SAVE DATA?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "This will permanently erase user://savegame.json and restore\nDay 1 starting stats ($300 Gold, 1 Blueprint, Level 1 Equipment).\n\nAre you sure you want to wipe your save file?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(desc)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)

	var wipe_btn := Button.new()
	wipe_btn.text = "⚠️ YES - WIPE SAVE"
	wipe_btn.custom_minimum_size = Vector2(170.0, 38.0)
	wipe_btn.add_theme_font_size_override("font_size", 14)
	wipe_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	wipe_btn.pressed.connect(func():
		var bp = _get_backpack()
		if bp != null:
			bp.reset_save_data()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
	)
	btn_hbox.add_child(wipe_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(120.0, 38.0)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.pressed.connect(func():
		reset_modal.visible = false
	)
	btn_hbox.add_child(cancel_btn)

	vbox.add_child(btn_hbox)
	panel.add_child(vbox)
	center.add_child(panel)
	layer.add_child(reset_modal)
	add_child(layer)


# ==============================================================================
# Alien VIP Request Board UI & Delivery Logic
# ==============================================================================

func _setup_vip_quest_modal() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "VIPQuestCanvas"
	canvas.layer = 12

	vip_quest_modal = Control.new()
	vip_quest_modal.name = "VIPQuestModal"
	vip_quest_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	vip_quest_modal.visible = false
	canvas.add_child(vip_quest_modal)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.08, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	vip_quest_modal.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	vip_quest_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640.0, 440.0)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.16, 0.98)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.25, 0.85, 0.7)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "ALIEN VIP SALVAGE REQUEST BOARD"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.85))
	header.add_child(title)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	var close_btn := Button.new()
	close_btn.text = " [X] Close (ESC) "
	close_btn.pressed.connect(func(): vip_quest_modal.visible = false)
	header.add_child(close_btn)

	# Client banner
	_vip_client_lbl = Label.new()
	_vip_client_lbl.text = "Client: Unknown Envoy"
	_vip_client_lbl.add_theme_font_size_override("font_size", 15)
	_vip_client_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	vbox.add_child(_vip_client_lbl)

	# Speech bubble / flavor
	var speech_panel := PanelContainer.new()
	var sp_sb := StyleBoxFlat.new()
	sp_sb.bg_color = Color(0.04, 0.07, 0.12, 0.9)
	sp_sb.set_corner_radius_all(6)
	speech_panel.add_theme_stylebox_override("panel", sp_sb)
	vbox.add_child(speech_panel)

	var sp_margin := MarginContainer.new()
	sp_margin.add_theme_constant_override("margin_left", 14)
	sp_margin.add_theme_constant_override("margin_right", 14)
	sp_margin.add_theme_constant_override("margin_top", 10)
	sp_margin.add_theme_constant_override("margin_bottom", 10)
	speech_panel.add_child(sp_margin)

	_vip_dialogue_lbl = Label.new()
	_vip_dialogue_lbl.text = "\"Loading transmission...\""
	_vip_dialogue_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vip_dialogue_lbl.add_theme_font_size_override("font_size", 13)
	_vip_dialogue_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	sp_margin.add_child(_vip_dialogue_lbl)

	# Target Relic Display Card
	_vip_target_card = PanelContainer.new()
	var tc_sb := StyleBoxFlat.new()
	tc_sb.bg_color = Color(0.08, 0.13, 0.22, 0.9)
	tc_sb.border_width_left = 2
	tc_sb.border_width_right = 2
	tc_sb.border_width_top = 2
	tc_sb.border_width_bottom = 2
	tc_sb.border_color = Color(0.3, 0.75, 1.0)
	tc_sb.set_corner_radius_all(8)
	_vip_target_card.add_theme_stylebox_override("panel", tc_sb)
	vbox.add_child(_vip_target_card)

	var tc_margin := MarginContainer.new()
	tc_margin.add_theme_constant_override("margin_left", 16)
	tc_margin.add_theme_constant_override("margin_right", 16)
	tc_margin.add_theme_constant_override("margin_top", 12)
	tc_margin.add_theme_constant_override("margin_bottom", 12)
	_vip_target_card.add_child(tc_margin)

	var tc_vbox := VBoxContainer.new()
	tc_vbox.add_theme_constant_override("separation", 6)
	tc_margin.add_child(tc_vbox)

	_vip_target_name_lbl = Label.new()
	_vip_target_name_lbl.text = "Target Relic: ..."
	_vip_target_name_lbl.add_theme_font_size_override("font_size", 16)
	_vip_target_name_lbl.add_theme_color_override("font_color", Color.CYAN)
	tc_vbox.add_child(_vip_target_name_lbl)

	_vip_target_stats_lbl = Label.new()
	_vip_target_stats_lbl.text = "Scrap Value: $0  -->  VIP Bounty: $0 (2.5x Scrap Value!)"
	_vip_target_stats_lbl.add_theme_font_size_override("font_size", 14)
	_vip_target_stats_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	tc_vbox.add_child(_vip_target_stats_lbl)

	# Action row & status
	_vip_status_lbl = Label.new()
	_vip_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vip_status_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_vip_status_lbl)

	var act_hbox := HBoxContainer.new()
	act_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(act_hbox)

	_vip_deliver_btn = Button.new()
	_vip_deliver_btn.text = " [Deliver Cleaned Relic] "
	_vip_deliver_btn.custom_minimum_size = Vector2(300.0, 42.0)
	_vip_deliver_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_vip_deliver_btn.pressed.connect(_on_vip_deliver_pressed)
	act_hbox.add_child(_vip_deliver_btn)

	add_child(canvas)


func _open_vip_quest_modal() -> void:
	if vip_quest_modal == null:
		return

	var bp = _get_backpack()
	if bp == null:
		return

	var quest: Dictionary = bp.active_vip_quest
	if quest.is_empty():
		bp.generate_daily_vip_quest()
		quest = bp.active_vip_quest

	_vip_client_lbl.text = "Client: " + str(quest.get("client_name", "Alien Envoy"))
	_vip_dialogue_lbl.text = "\"%s\"" % str(quest.get("dialogue", "Deliver the requested item."))

	var r_name: String = str(quest.get("relic_name", "Relic"))
	var r_rarity: String = str(quest.get("rarity", "Common"))
	var r_set: String = str(quest.get("set_name", ""))
	var base_v: int = int(quest.get("base_value", 0))
	var reward_g: int = int(quest.get("reward_gold", 0))
	var is_completed: bool = bool(quest.get("completed", false))

	_vip_target_name_lbl.text = "Target Relic: %s  [%s  •  Set: %s]" % [r_name, r_rarity, r_set]
	_vip_target_stats_lbl.text = "Standard Value: $%d  -->  VIP Bounty Reward: +$%d Gold (2.5x Scrap Value!)" % [base_v, reward_g]

	if is_completed:
		_vip_deliver_btn.disabled = true
		_vip_deliver_btn.text = " [Quest Fulfilled Today] "
		_vip_status_lbl.text = "★ Commission fulfilled! The alien delegation thanks you. New VIP arrives tomorrow."
		_vip_status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
	else:
		var has_cleaned: bool = bp.has_vip_quest_item()
		if has_cleaned:
			_vip_deliver_btn.disabled = false
			_vip_deliver_btn.text = " [Deliver Relic: Claim +$%d Gold] " % reward_g
			_vip_status_lbl.text = "✓ You possess a cleaned %s in your inventory!" % r_name
			_vip_status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
		else:
			var has_encrusted: bool = false
			var t_id: String = str(quest.get("relic_id", ""))
			for it in bp.items:
				if str(it.get("id", "")) == t_id and not bool(it.get("identified", false)):
					has_encrusted = true
					break

			_vip_deliver_btn.disabled = true
			if has_encrusted:
				_vip_deliver_btn.text = " [Item Encrusted - Clean at Home Lab!] "
				_vip_status_lbl.text = "⚠ You possess this relic, but it must be cleaned at your Home Lab workbench first!"
				_vip_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
			else:
				_vip_deliver_btn.text = " [Missing Target Relic] "
				_vip_status_lbl.text = "✗ Need: 1x Cleaned %s (Dive into the ocean to salvage)." % r_name
				_vip_status_lbl.add_theme_color_override("font_color", Color(0.8, 0.45, 0.45))

	vip_quest_modal.visible = true


func _on_vip_deliver_pressed() -> void:
	var bp = _get_backpack()
	if bp == null:
		return

	var reward: int = int(bp.active_vip_quest.get("reward_gold", 0))
	if bp.fulfill_vip_quest():
		if bp.has_method("play_sfx"):
			bp.play_sfx("cash")
		_spawn_floating_cash_text(player.position + Vector2(0.0, -35.0), "+$%d VIP Bounty!" % reward)
		_open_vip_quest_modal()
		_update_prompts_and_hud()
