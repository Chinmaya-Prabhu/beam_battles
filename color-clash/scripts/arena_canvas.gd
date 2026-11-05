class_name ArenaCanvas
extends Control

signal point_clicked(grid_pos: Vector2)

var sim_width: int = 480
var sim_height: int = 340
var arena_texture: ImageTexture
var outer_poly: PackedVector2Array = PackedVector2Array()
var hole_polys: Array[PackedVector2Array] = []

var placed_dots: Array[Dictionary] = []
var player_colors: Array[Color] = []
var secret_mode: bool = false
var reveal_dots: bool = true
var active_player_id: int = 0
var can_human_place: bool = false
var is_hover_valid: bool = false
var hover_grid_pos: Vector2 = Vector2.ZERO
var pulse_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m_event: InputEventMouseMotion = event as InputEventMouseMotion
		hover_grid_pos = screen_to_grid(m_event.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		var b_event: InputEventMouseButton = event as InputEventMouseButton
		if b_event.pressed and b_event.button_index == MOUSE_BUTTON_LEFT:
			if can_human_place:
				var g_pos: Vector2 = screen_to_grid(b_event.position)
				point_clicked.emit(g_pos)


func get_arena_rect() -> Rect2:
	var avail: Vector2 = size - Vector2(24.0, 24.0)
	if avail.x <= 10.0 or avail.y <= 10.0:
		return Rect2(Vector2.ZERO, size)
	var aspect: float = float(sim_width) / float(sim_height)
	var w: float = avail.x
	var h: float = w / aspect
	if h > avail.y:
		h = avail.y
		w = h * aspect
	var pos: Vector2 = (size - Vector2(w, h)) * 0.5
	return Rect2(pos, Vector2(w, h))


func screen_to_grid(local_pos: Vector2) -> Vector2:
	var rect: Rect2 = get_arena_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return Vector2.ZERO
	var uv: Vector2 = (local_pos - rect.position) / rect.size
	return Vector2(uv.x * float(sim_width), uv.y * float(sim_height))


func grid_to_screen(grid_pos: Vector2, rect: Rect2) -> Vector2:
	var uv: Vector2 = Vector2(grid_pos.x / float(sim_width), grid_pos.y / float(sim_height))
	return rect.position + uv * rect.size


func _draw() -> void:
	var rect: Rect2 = get_arena_rect()
	if arena_texture != null:
		draw_texture_rect(arena_texture, rect, false)

	# Draw irregular outer perimeter and hole boundaries with subtle glow + crisp stroke
	_draw_polygon_border(outer_poly, rect, Color(0.58, 0.72, 0.98, 0.25), 7.0)
	_draw_polygon_border(outer_poly, rect, Color(0.92, 0.96, 1.0, 0.95), 2.6)

	for hole in hole_polys:
		_draw_polygon_border(hole, rect, Color(0.58, 0.72, 0.98, 0.22), 6.0)
		_draw_polygon_border(hole, rect, Color(0.88, 0.92, 1.0, 0.92), 2.4)

	# Draw placed origin dots
	if reveal_dots or not secret_mode:
		for i in range(placed_dots.size()):
			var dot: Dictionary = placed_dots[i]
			var p_id: int = int(dot["player"])
			var g_pos: Vector2 = dot["pos"]
			var s_pos: Vector2 = grid_to_screen(g_pos, rect)
			var col: Color = player_colors[p_id] if p_id < player_colors.size() else Color.WHITE

			var ring_r: float = 11.0 + 3.0 * sin(pulse_time * 4.5 + float(i) * 1.1)
			draw_arc(s_pos, ring_r, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.65), 2.2, true)
			draw_circle(s_pos, 7.5, Color(0.08, 0.09, 0.12, 0.95))
			draw_circle(s_pos, 5.5, col.lightened(0.22))
			draw_circle(s_pos, 2.5, Color.WHITE)

	# Draw live placement preview reticle for human player
	if can_human_place and is_hover_valid:
		var s_hover: Vector2 = grid_to_screen(hover_grid_pos, rect)
		var p_col: Color = player_colors[active_player_id] if active_player_id < player_colors.size() else Color.WHITE
		var pulse_r: float = 14.0 + 2.5 * sin(pulse_time * 6.0)
		draw_arc(s_hover, pulse_r, 0.0, TAU, 32, Color(p_col.r, p_col.g, p_col.b, 0.85), 2.2, true)
		draw_circle(s_hover, 5.0, p_col)
		draw_circle(s_hover, 2.2, Color.WHITE)


func _draw_polygon_border(poly: PackedVector2Array, rect: Rect2, col: Color, width_px: float) -> void:
	if poly.size() < 3:
		return
	var screen_pts: PackedVector2Array = PackedVector2Array()
	screen_pts.resize(poly.size() + 1)
	for i in range(poly.size()):
		screen_pts[i] = grid_to_screen(poly[i], rect)
	screen_pts[poly.size()] = screen_pts[0]
	draw_polyline(screen_pts, col, width_px, true)
