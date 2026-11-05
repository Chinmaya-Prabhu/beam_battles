extends Control

const ShapeGeneratorScript = preload("res://scripts/shape_generator.gd")
const WavefrontSimScript = preload("res://scripts/wavefront_sim.gd")
const ArenaCanvasScript = preload("res://scripts/arena_canvas.gd")
const TerritoryBarScript = preload("res://scripts/territory_bar.gd")

const SIM_WIDTH: int = 480
const SIM_HEIGHT: int = 340

enum GamePhase {
	PLACING_DOTS = 0,
	SPREADING = 1,
	ROUND_OVER = 2,
}

const PLAYER_PALETTE: Array[Color] = [
	Color(1.00, 0.29, 0.43, 1.0), # Coral Crimson
	Color(0.00, 0.86, 0.98, 1.0), # Electric Cyan
	Color(1.00, 0.78, 0.16, 1.0), # Solar Gold
	Color(0.22, 0.92, 0.53, 1.0), # Emerald Mint
	Color(0.73, 0.42, 1.00, 1.0), # Neon Violet
	Color(1.00, 0.52, 0.18, 1.0), # Tangerine Blaze
]

const PLAYER_DEFAULT_NAMES: Array[String] = [
	"Crimson",
	"Cyan",
	"Gold",
	"Emerald",
	"Violet",
	"Tangerine",
]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var sim: WavefrontSim = WavefrontSim.new()

var num_players: int = 3
var player_is_ai: Array[bool] = [false, false, true, true, true, true]
var ai_difficulty: int = 1 # 0 = Casual, 1 = Smart, 2 = Master
var dots_per_player: int = 1
var secret_mode: bool = false
var selected_shape_type: int = ShapeGenerator.ShapeType.RANDOM
var spread_speed_mult: float = 1.0

var phase: GamePhase = GamePhase.PLACING_DOTS
var current_turn_index: int = 0
var total_turns_needed: int = 3
var placed_dots: Array[Dictionary] = []
var ai_think_timer: float = 0.0
var current_sim_time: float = 0.0
var round_wins: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])

var arena_mask: PackedByteArray
var playable_pixels: int = 1
var base_arena_image: Image
var working_arena_image: Image
var arena_texture: ImageTexture
var last_frontier_indices: PackedInt32Array = PackedInt32Array()

# UI References
var arena_canvas: ArenaCanvas
var territory_bar: TerritoryBar
var status_title_lbl: Label
var status_sub_lbl: Label
var shape_badge_lbl: Label
var player_cards_box: VBoxContainer
var player_card_widgets: Array[Dictionary] = []

var player_count_btn: OptionButton
var shape_option_btn: OptionButton
var mode_option_btn: OptionButton
var dots_option_btn: OptionButton
var ai_diff_btn: OptionButton
var speed_option_btn: OptionButton

var result_panel: PanelContainer
var result_title_lbl: Label
var result_details_lbl: Label


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_generate_new_shape()


func _process(delta: float) -> void:
	if arena_canvas != null:
		arena_canvas.is_hover_valid = (
			phase == GamePhase.PLACING_DOTS
			and not _is_current_turn_ai()
			and sim.is_point_playable(arena_canvas.hover_grid_pos)
		)

	match phase:
		GamePhase.PLACING_DOTS:
			if _is_current_turn_ai():
				ai_think_timer -= delta
				if ai_think_timer <= 0.0:
					var p_id: int = _get_active_player_id()
					var ai_pt: Vector2 = sim.choose_ai_point(
						p_id, placed_dots, ai_difficulty, secret_mode, rng
					)
					_place_dot_at(ai_pt)

		GamePhase.SPREADING:
			_advance_spread_step(delta)


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_margin: MarginContainer = MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 18)
	root_margin.add_theme_constant_override("margin_right", 18)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(root_margin)

	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(main_hbox)

	# LEFT SIDEBAR: Controls & Standings
	var sidebar_panel: PanelContainer = _create_styled_panel(Color(0.10, 0.12, 0.16, 1.0), Color(0.22, 0.26, 0.35, 1.0))
	sidebar_panel.custom_minimum_size = Vector2(330, 0)
	main_hbox.add_child(sidebar_panel)

	var sidebar_margin: MarginContainer = MarginContainer.new()
	sidebar_margin.add_theme_constant_override("margin_left", 14)
	sidebar_margin.add_theme_constant_override("margin_right", 14)
	sidebar_margin.add_theme_constant_override("margin_top", 14)
	sidebar_margin.add_theme_constant_override("margin_bottom", 14)
	sidebar_panel.add_child(sidebar_margin)

	var sidebar_vbox: VBoxContainer = VBoxContainer.new()
	sidebar_vbox.add_theme_constant_override("separation", 10)
	sidebar_margin.add_child(sidebar_vbox)

	var header_lbl: Label = Label.new()
	header_lbl.text = "COLOR CLASH"
	header_lbl.add_theme_font_size_override("font_size", 22)
	header_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	sidebar_vbox.add_child(header_lbl)

	var tagline_lbl: Label = Label.new()
	tagline_lbl.text = "Drop a dot inside the irregular boundary & claim the largest territory."
	tagline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline_lbl.add_theme_font_size_override("font_size", 12)
	tagline_lbl.add_theme_color_override("font_color", Color(0.66, 0.72, 0.84))
	sidebar_vbox.add_child(tagline_lbl)

	# Configuration Grid
	var cfg_grid: GridContainer = GridContainer.new()
	cfg_grid.columns = 2
	cfg_grid.add_theme_constant_override("h_separation", 8)
	cfg_grid.add_theme_constant_override("v_separation", 6)
	sidebar_vbox.add_child(cfg_grid)

	player_count_btn = OptionButton.new()
	for p in range(2, 7):
		player_count_btn.add_item("%d Players" % p, p)
	player_count_btn.selected = 1 # 3 players default
	player_count_btn.item_selected.connect(_on_player_count_changed)
	_add_config_row(cfg_grid, "Players:", player_count_btn)

	shape_option_btn = OptionButton.new()
	for shape_id in [
		ShapeGenerator.ShapeType.RANDOM,
		ShapeGenerator.ShapeType.ORGANIC_ISLAND,
		ShapeGenerator.ShapeType.HOURGLASS,
		ShapeGenerator.ShapeType.ARCHIPELAGO,
		ShapeGenerator.ShapeType.DEEP_COVES,
		ShapeGenerator.ShapeType.TWIN_CHAMBERS,
	]:
		shape_option_btn.add_item(ShapeGenerator.SHAPE_NAMES[shape_id], shape_id)
	shape_option_btn.item_selected.connect(_on_shape_type_changed)
	_add_config_row(cfg_grid, "Arena Shape:", shape_option_btn)

	mode_option_btn = OptionButton.new()
	mode_option_btn.add_item("Turn-Based (Visible)", 0)
	mode_option_btn.add_item("Secret Drop (Hidden)", 1)
	mode_option_btn.item_selected.connect(_on_mode_changed)
	_add_config_row(cfg_grid, "Drop Mode:", mode_option_btn)

	dots_option_btn = OptionButton.new()
	dots_option_btn.add_item("1 Dot / Player", 1)
	dots_option_btn.add_item("2 Dots / Player", 2)
	dots_option_btn.add_item("3 Dots / Player", 3)
	dots_option_btn.item_selected.connect(_on_dots_per_player_changed)
	_add_config_row(cfg_grid, "Dots Each:", dots_option_btn)

	ai_diff_btn = OptionButton.new()
	ai_diff_btn.add_item("Casual Bot", 0)
	ai_diff_btn.add_item("Smart Bot", 1)
	ai_diff_btn.add_item("Master Bot", 2)
	ai_diff_btn.selected = 1
	ai_diff_btn.item_selected.connect(func(idx: int) -> void: ai_difficulty = idx)
	_add_config_row(cfg_grid, "Bot Skill:", ai_diff_btn)

	speed_option_btn = OptionButton.new()
	speed_option_btn.add_item("Normal (1x)", 0)
	speed_option_btn.add_item("Fast (2x)", 1)
	speed_option_btn.add_item("Instant Fill", 2)
	speed_option_btn.item_selected.connect(_on_speed_changed)
	_add_config_row(cfg_grid, "Spread Speed:", speed_option_btn)

	# Action Buttons Row
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	sidebar_vbox.add_child(btn_row)

	var new_shape_btn: Button = Button.new()
	new_shape_btn.text = "New Shape"
	new_shape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_shape_btn.pressed.connect(_generate_new_shape)
	btn_row.add_child(new_shape_btn)

	var reset_round_btn: Button = Button.new()
	reset_round_btn.text = "Clear Dots"
	reset_round_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_round_btn.pressed.connect(_restart_same_shape)
	btn_row.add_child(reset_round_btn)

	var players_hdr_row: HBoxContainer = HBoxContainer.new()
	sidebar_vbox.add_child(players_hdr_row)

	var p_hdr_lbl: Label = Label.new()
	p_hdr_lbl.text = "PLAYERS (Click Human/Bot to toggle)"
	p_hdr_lbl.add_theme_font_size_override("font_size", 11)
	p_hdr_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.80))
	players_hdr_row.add_child(p_hdr_lbl)

	player_cards_box = VBoxContainer.new()
	player_cards_box.add_theme_constant_override("separation", 6)
	player_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_vbox.add_child(player_cards_box)

	_rebuild_player_cards()

	# RIGHT MAIN AREA: Top Banner + Territory Bar + Interactive Arena Canvas
	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	main_hbox.add_child(right_vbox)

	var top_bar_panel: PanelContainer = _create_styled_panel(Color(0.10, 0.12, 0.16, 1.0), Color(0.22, 0.26, 0.35, 1.0))
	right_vbox.add_child(top_bar_panel)

	var top_bar_margin: MarginContainer = MarginContainer.new()
	top_bar_margin.add_theme_constant_override("margin_left", 16)
	top_bar_margin.add_theme_constant_override("margin_right", 16)
	top_bar_margin.add_theme_constant_override("margin_top", 10)
	top_bar_margin.add_theme_constant_override("margin_bottom", 10)
	top_bar_panel.add_child(top_bar_margin)

	var top_bar_vbox: VBoxContainer = VBoxContainer.new()
	top_bar_vbox.add_theme_constant_override("separation", 8)
	top_bar_margin.add_child(top_bar_vbox)

	var banner_hbox: HBoxContainer = HBoxContainer.new()
	top_bar_vbox.add_child(banner_hbox)

	var status_vbox: VBoxContainer = VBoxContainer.new()
	status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_hbox.add_child(status_vbox)

	status_title_lbl = Label.new()
	status_title_lbl.text = "Player 1's Turn"
	status_title_lbl.add_theme_font_size_override("font_size", 19)
	status_vbox.add_child(status_title_lbl)

	status_sub_lbl = Label.new()
	status_sub_lbl.text = "Click anywhere inside the shape to drop your origin dot."
	status_sub_lbl.add_theme_font_size_override("font_size", 13)
	status_sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.76, 0.88))
	status_vbox.add_child(status_sub_lbl)

	shape_badge_lbl = Label.new()
	shape_badge_lbl.text = "Organic Island"
	shape_badge_lbl.add_theme_font_size_override("font_size", 13)
	shape_badge_lbl.add_theme_color_override("font_color", Color(0.56, 0.82, 1.0))
	banner_hbox.add_child(shape_badge_lbl)

	territory_bar = TerritoryBar.new()
	territory_bar.custom_minimum_size = Vector2(0, 16)
	top_bar_vbox.add_child(territory_bar)

	# Arena Holder Panel
	var arena_panel: PanelContainer = _create_styled_panel(Color(0.08, 0.09, 0.13, 1.0), Color(0.20, 0.24, 0.33, 1.0))
	arena_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(arena_panel)

	arena_canvas = ArenaCanvas.new()
	arena_canvas.sim_width = SIM_WIDTH
	arena_canvas.sim_height = SIM_HEIGHT
	arena_canvas.player_colors = PLAYER_PALETTE
	arena_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_canvas.point_clicked.connect(_on_arena_point_clicked)
	arena_panel.add_child(arena_canvas)

	# Floating Round Result Overlay at bottom-right of arena
	var overlay_align: MarginContainer = MarginContainer.new()
	overlay_align.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	overlay_align.add_theme_constant_override("margin_left", 24)
	overlay_align.add_theme_constant_override("margin_right", 24)
	overlay_align.add_theme_constant_override("margin_bottom", 18)
	overlay_align.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_panel.add_child(overlay_align)

	result_panel = _create_styled_panel(Color(0.09, 0.11, 0.16, 0.94), Color(0.40, 0.55, 0.82, 0.95))
	result_panel.visible = false
	overlay_align.add_child(result_panel)

	var res_margin: MarginContainer = MarginContainer.new()
	res_margin.add_theme_constant_override("margin_left", 18)
	res_margin.add_theme_constant_override("margin_right", 18)
	res_margin.add_theme_constant_override("margin_top", 12)
	res_margin.add_theme_constant_override("margin_bottom", 12)
	result_panel.add_child(res_margin)

	var res_hbox: HBoxContainer = HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 16)
	res_margin.add_child(res_hbox)

	var res_text_vbox: VBoxContainer = VBoxContainer.new()
	res_text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_hbox.add_child(res_text_vbox)

	result_title_lbl = Label.new()
	result_title_lbl.add_theme_font_size_override("font_size", 18)
	res_text_vbox.add_child(result_title_lbl)

	result_details_lbl = Label.new()
	result_details_lbl.add_theme_font_size_override("font_size", 13)
	result_details_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.94))
	res_text_vbox.add_child(result_details_lbl)

	var replay_same_btn: Button = Button.new()
	replay_same_btn.text = "Rematch (Same Shape)"
	replay_same_btn.pressed.connect(_restart_same_shape)
	res_hbox.add_child(replay_same_btn)

	var next_shape_btn: Button = Button.new()
	next_shape_btn.text = "Next Shape"
	next_shape_btn.pressed.connect(_generate_new_shape)
	res_hbox.add_child(next_shape_btn)


func _add_config_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.94))
	grid.add_child(lbl)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _create_styled_panel(bg_col: Color, border_col: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_col
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _rebuild_player_cards() -> void:
	for child in player_cards_box.get_children():
		child.queue_free()
	player_card_widgets.clear()

	for i in range(num_players):
		var col: Color = PLAYER_PALETTE[i]
		var card: PanelContainer = _create_styled_panel(
			Color(0.13, 0.15, 0.21, 1.0),
			Color(col.r, col.g, col.b, 0.55)
		)
		player_cards_box.add_child(card)

		var m: MarginContainer = MarginContainer.new()
		m.add_theme_constant_override("margin_left", 10)
		m.add_theme_constant_override("margin_right", 10)
		m.add_theme_constant_override("margin_top", 7)
		m.add_theme_constant_override("margin_bottom", 7)
		card.add_child(m)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		m.add_child(row)

		var swatch: ColorRect = ColorRect.new()
		swatch.color = col
		swatch.custom_minimum_size = Vector2(14, 28)
		row.add_child(swatch)

		var info_vbox: VBoxContainer = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_vbox)

		var name_lbl: Label = Label.new()
		name_lbl.text = "P%d %s" % [i + 1, PLAYER_DEFAULT_NAMES[i]]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", col.lightened(0.25))
		info_vbox.add_child(name_lbl)

		var pct_lbl: Label = Label.new()
		pct_lbl.text = "0.0%% area  |  Wins: %d" % round_wins[i]
		pct_lbl.add_theme_font_size_override("font_size", 12)
		pct_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
		info_vbox.add_child(pct_lbl)

		var role_btn: Button = Button.new()
		role_btn.text = "AI Bot" if player_is_ai[i] else "Human"
		role_btn.custom_minimum_size = Vector2(72, 0)
		var player_idx: int = i
		role_btn.pressed.connect(func() -> void: _toggle_player_role(player_idx))
		row.add_child(role_btn)

		player_card_widgets.append({
			"card": card,
			"name_lbl": name_lbl,
			"pct_lbl": pct_lbl,
			"role_btn": role_btn,
		})


func _toggle_player_role(p_idx: int) -> void:
	player_is_ai[p_idx] = not player_is_ai[p_idx]
	if p_idx < player_card_widgets.size():
		var btn: Button = player_card_widgets[p_idx]["role_btn"]
		btn.text = "AI Bot" if player_is_ai[p_idx] else "Human"

	if phase == GamePhase.PLACING_DOTS and _get_active_player_id() == p_idx:
		_update_turn_banner()
		if player_is_ai[p_idx]:
			ai_think_timer = 0.35


func _generate_new_shape() -> void:
	var data: Dictionary = ShapeGenerator.generate_arena(
		SIM_WIDTH, SIM_HEIGHT, selected_shape_type, rng
	)
	arena_mask = data["mask"]
	playable_pixels = maxi(int(data["playable_pixels"]), 1)

	arena_canvas.outer_poly = data["outer"]
	arena_canvas.hole_polys = data["holes"]

	var actual_type: int = int(data["actual_type"])
	shape_badge_lbl.text = "Shape: %s" % ShapeGenerator.SHAPE_NAMES.get(actual_type, "Irregular")

	_build_base_arena_image()
	_restart_same_shape()


func _build_base_arena_image() -> void:
	base_arena_image = Image.create(SIM_WIDTH, SIM_HEIGHT, false, Image.FORMAT_RGBA8)
	var outside_col: Color = Color(0.08, 0.09, 0.13, 1.0)
	var inside_a: Color = Color(0.14, 0.16, 0.22, 1.0)
	var inside_b: Color = Color(0.16, 0.18, 0.25, 1.0)

	for y in range(SIM_HEIGHT):
		var row_off: int = y * SIM_WIDTH
		for x in range(SIM_WIDTH):
			if arena_mask[row_off + x] == 1:
				var is_grid_line: bool = (x % 24 == 0) or (y % 24 == 0)
				base_arena_image.set_pixel(x, y, inside_b if is_grid_line else inside_a)
			else:
				base_arena_image.set_pixel(x, y, outside_col)


func _restart_same_shape() -> void:
	placed_dots.clear()
	last_frontier_indices.clear()
	current_turn_index = 0
	total_turns_needed = num_players * dots_per_player
	phase = GamePhase.PLACING_DOTS
	result_panel.visible = false

	working_arena_image = base_arena_image.duplicate()
	arena_texture = ImageTexture.create_from_image(working_arena_image)
	arena_canvas.arena_texture = arena_texture
	arena_canvas.placed_dots = placed_dots
	arena_canvas.secret_mode = secret_mode
	arena_canvas.reveal_dots = not secret_mode

	sim.setup_arena(SIM_WIDTH, SIM_HEIGHT, arena_mask, playable_pixels, num_players)
	_update_standings_ui()
	_update_turn_banner()

	if _is_current_turn_ai():
		ai_think_timer = 0.42


func _get_active_player_id() -> int:
	return current_turn_index % num_players


func _is_current_turn_ai() -> bool:
	if phase != GamePhase.PLACING_DOTS:
		return false
	return player_is_ai[_get_active_player_id()]


func _on_arena_point_clicked(grid_pos: Vector2) -> void:
	if phase != GamePhase.PLACING_DOTS or _is_current_turn_ai():
		return
	if not sim.is_point_playable(grid_pos):
		status_sub_lbl.text = "Outside boundary! Click inside the irregular closed shape."
		return
	_place_dot_at(grid_pos)


func _place_dot_at(grid_pos: Vector2) -> void:
	var p_id: int = _get_active_player_id()
	placed_dots.append({
		"player": p_id,
		"pos": grid_pos,
	})
	current_turn_index += 1
	arena_canvas.queue_redraw()

	if current_turn_index >= total_turns_needed:
		_begin_spreading_phase()
	else:
		_update_turn_banner()
		if _is_current_turn_ai():
			ai_think_timer = 0.38


func _begin_spreading_phase() -> void:
	phase = GamePhase.SPREADING
	arena_canvas.can_human_place = false
	arena_canvas.reveal_dots = true
	current_sim_time = 0.0
	last_frontier_indices.clear()

	sim.start_spread(placed_dots, num_players)
	status_title_lbl.text = "Colors Spreading..."
	status_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	status_sub_lbl.text = "Expanding equally in all directions until hitting the perimeter or another color!"

	if spread_speed_mult >= 50.0:
		# Instant fill mode
		sim.step_to_time(float(SIM_WIDTH + SIM_HEIGHT) * 2.0, working_arena_image, PLAYER_PALETTE)
		arena_texture.update(working_arena_image)
		_update_standings_ui()
		_finish_round()


func _advance_spread_step(delta: float) -> void:
	# Restore previous frame's glowing wavefront pixels to their settled player colors
	for i in range(last_frontier_indices.size()):
		var f_idx: int = last_frontier_indices[i]
		var owner_id: int = sim.owner_grid[f_idx]
		if owner_id >= 0:
			var fx: int = f_idx % SIM_WIDTH
			var fy: int = f_idx / SIM_WIDTH
			var arrival_t: float = sim.best_time[f_idx]
			var ripple: float = 0.94 + 0.06 * sin(arrival_t * 0.38)
			var base_col: Color = PLAYER_PALETTE[owner_id]
			working_arena_image.set_pixel(
				fx,
				fy,
				Color(base_col.r * ripple, base_col.g * ripple, base_col.b * ripple, 1.0)
			)

	var base_speed_px_per_sec: float = 135.0
	current_sim_time += base_speed_px_per_sec * spread_speed_mult * delta

	var newly_claimed: PackedInt32Array = sim.step_to_time(
		current_sim_time, working_arena_image, PLAYER_PALETTE
	)

	# Highlight active wavefront edge so players see the circular wave expanding
	var frontier: PackedInt32Array = PackedInt32Array()
	for i in range(newly_claimed.size()):
		var idx: int = newly_claimed[i]
		var arrival_t: float = sim.best_time[idx]
		if current_sim_time - arrival_t <= 2.4:
			var p_id: int = sim.owner_grid[idx]
			var fx: int = idx % SIM_WIDTH
			var fy: int = idx / SIM_WIDTH
			working_arena_image.set_pixel(fx, fy, PLAYER_PALETTE[p_id].lightened(0.48))
			frontier.append(idx)
	last_frontier_indices = frontier

	arena_texture.update(working_arena_image)
	_update_standings_ui()

	if sim.is_finished:
		# Clear wavefront highlight on final frame
		for i in range(last_frontier_indices.size()):
			var f_idx: int = last_frontier_indices[i]
			var owner_id: int = sim.owner_grid[f_idx]
			if owner_id >= 0:
				var fx: int = f_idx % SIM_WIDTH
				var fy: int = f_idx / SIM_WIDTH
				working_arena_image.set_pixel(fx, fy, PLAYER_PALETTE[owner_id])
		arena_texture.update(working_arena_image)
		_finish_round()


func _finish_round() -> void:
	phase = GamePhase.ROUND_OVER
	arena_canvas.can_human_place = false

	var best_player: int = 0
	var max_pixels: int = -1
	var is_tie: bool = false

	for i in range(num_players):
		var c: int = sim.player_counts[i]
		if c > max_pixels:
			max_pixels = c
			best_player = i
			is_tie = false
		elif c == max_pixels:
			is_tie = true

	if not is_tie and max_pixels > 0:
		round_wins[best_player] += 1

	_update_standings_ui()

	var win_pct: float = (float(max_pixels) * 100.0) / float(playable_pixels)
	if is_tie:
		status_title_lbl.text = "Round Tied!"
		status_title_lbl.add_theme_color_override("font_color", Color.WHITE)
		result_title_lbl.text = "It's a Tie at %.1f%%!" % win_pct
	else:
		var win_col: Color = PLAYER_PALETTE[best_player]
		var role_str: String = "Bot" if player_is_ai[best_player] else "Human"
		status_title_lbl.text = "P%d %s Wins the Space! (%.1f%%)" % [
			best_player + 1,
			PLAYER_DEFAULT_NAMES[best_player],
			win_pct,
		]
		status_title_lbl.add_theme_color_override("font_color", win_col.lightened(0.25))
		result_title_lbl.text = "Winner: Player %d (%s - %s) with %.1f%% of the Arena!" % [
			best_player + 1,
			PLAYER_DEFAULT_NAMES[best_player],
			role_str,
			win_pct,
		]
		result_title_lbl.add_theme_color_override("font_color", win_col.lightened(0.25))

	var breakdown: PackedStringArray = PackedStringArray()
	for i in range(num_players):
		var pct: float = (float(sim.player_counts[i]) * 100.0) / float(playable_pixels)
		breakdown.append("P%d %s: %.1f%%" % [i + 1, PLAYER_DEFAULT_NAMES[i], pct])
	result_details_lbl.text = "   •   ".join(breakdown)
	status_sub_lbl.text = "All playable area inside the perimeter has been claimed."
	result_panel.visible = true


func _update_turn_banner() -> void:
	if phase != GamePhase.PLACING_DOTS:
		return
	var p_id: int = _get_active_player_id()
	var col: Color = PLAYER_PALETTE[p_id]
	var dot_num: int = (current_turn_index / num_players) + 1
	var dot_str: String = (
		" (Dot %d of %d)" % [dot_num, dots_per_player] if dots_per_player > 1 else ""
	)

	arena_canvas.active_player_id = p_id
	arena_canvas.can_human_place = not player_is_ai[p_id]

	status_title_lbl.add_theme_color_override("font_color", col.lightened(0.22))
	if player_is_ai[p_id]:
		status_title_lbl.text = "P%d %s (AI Bot) is choosing a spot...%s" % [
			p_id + 1,
			PLAYER_DEFAULT_NAMES[p_id],
			dot_str,
		]
		status_sub_lbl.text = "AI is analyzing the irregular shape to maximize territory."
	else:
		status_title_lbl.text = "Player %d (%s)'s Turn%s" % [
			p_id + 1,
			PLAYER_DEFAULT_NAMES[p_id],
			dot_str,
		]
		if secret_mode:
			status_sub_lbl.text = "SECRET MODE: Click inside the shape to place your hidden dot!"
		else:
			status_sub_lbl.text = "Click inside the irregular shape to drop your origin dot."


func _update_standings_ui() -> void:
	var ratios: Array[float] = []
	var colors: Array[Color] = []

	for i in range(num_players):
		var count: int = sim.player_counts[i] if i < sim.player_counts.size() else 0
		var ratio: float = float(count) / float(playable_pixels)
		ratios.append(ratio)
		colors.append(PLAYER_PALETTE[i])

		if i < player_card_widgets.size():
			var pct_lbl: Label = player_card_widgets[i]["pct_lbl"]
			pct_lbl.text = "%.1f%% area  |  Wins: %d" % [ratio * 100.0, round_wins[i]]

	territory_bar.set_standings(colors, ratios)


func _on_player_count_changed(idx: int) -> void:
	num_players = player_count_btn.get_item_id(idx)
	_rebuild_player_cards()
	_restart_same_shape()


func _on_shape_type_changed(idx: int) -> void:
	selected_shape_type = shape_option_btn.get_item_id(idx)
	_generate_new_shape()


func _on_mode_changed(idx: int) -> void:
	secret_mode = (mode_option_btn.get_item_id(idx) == 1)
	_restart_same_shape()


func _on_dots_per_player_changed(idx: int) -> void:
	dots_per_player = dots_option_btn.get_item_id(idx)
	_restart_same_shape()


func _on_speed_changed(idx: int) -> void:
	var speed_id: int = speed_option_btn.get_item_id(idx)
	if speed_id == 0:
		spread_speed_mult = 1.0
	elif speed_id == 1:
		spread_speed_mult = 2.2
	else:
		spread_speed_mult = 100.0
