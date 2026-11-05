class_name TerritoryBar
extends Control

var player_colors: Array[Color] = []
var player_ratios: Array[float] = []


func set_standings(colors: Array[Color], ratios: Array[float]) -> void:
	player_colors = colors
	player_ratios = ratios
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.12, 0.14, 0.19, 1.0), true)

	var x_cursor: float = 0.0
	for i in range(player_ratios.size()):
		var ratio: float = clampf(player_ratios[i], 0.0, 1.0)
		var seg_w: float = ratio * size.x
		if seg_w > 0.5:
			var col: Color = player_colors[i] if i < player_colors.size() else Color.WHITE
			draw_rect(Rect2(Vector2(x_cursor, 0.0), Vector2(seg_w, size.y)), col, true)
			x_cursor += seg_w

	draw_rect(r, Color(0.28, 0.33, 0.44, 0.9), false, 1.5)
