class_name ShapeGenerator
extends RefCounted

enum ShapeType {
	RANDOM = 0,
	ORGANIC_ISLAND = 1,
	HOURGLASS = 2,
	ARCHIPELAGO = 3,
	DEEP_COVES = 4,
	TWIN_CHAMBERS = 5,
}

const SHAPE_NAMES: Dictionary = {
	ShapeType.RANDOM: "Random Irregular",
	ShapeType.ORGANIC_ISLAND: "Organic Island",
	ShapeType.HOURGLASS: "Hourglass Choke",
	ShapeType.ARCHIPELAGO: "Hollow Atoll (Holes)",
	ShapeType.DEEP_COVES: "Fjords & Peninsulas",
	ShapeType.TWIN_CHAMBERS: "Twin Chambers",
}


static func generate_arena(width: int, height: int, shape_type: int, rng: RandomNumberGenerator) -> Dictionary:
	var actual_type: int = shape_type
	if actual_type == ShapeType.RANDOM:
		var choices: Array[int] = [
			ShapeType.ORGANIC_ISLAND,
			ShapeType.HOURGLASS,
			ShapeType.ARCHIPELAGO,
			ShapeType.DEEP_COVES,
			ShapeType.TWIN_CHAMBERS,
		]
		actual_type = choices[rng.randi_range(0, choices.size() - 1)]

	var cx: float = width * 0.5
	var cy: float = height * 0.5
	var rx: float = width * 0.43
	var ry: float = height * 0.42

	var outer_control: PackedVector2Array = PackedVector2Array()
	var holes: Array[PackedVector2Array] = []

	match actual_type:
		ShapeType.ORGANIC_ISLAND:
			var num_pts: int = 18
			var p1: float = rng.randf_range(0.0, TAU)
			var p2: float = rng.randf_range(0.0, TAU)
			var p3: float = rng.randf_range(0.0, TAU)
			for i in range(num_pts):
				var angle: float = (TAU * float(i)) / float(num_pts)
				var wave: float = (
					1.0
					+ 0.16 * sin(angle * 2.0 + p1)
					+ 0.12 * cos(angle * 3.0 + p2)
					+ 0.09 * sin(angle * 5.0 + p3)
					+ rng.randf_range(-0.05, 0.05)
				)
				wave = clampf(wave, 0.55, 1.08)
				outer_control.append(Vector2(cx + cos(angle) * rx * wave, cy + sin(angle) * ry * wave))

		ShapeType.HOURGLASS:
			var num_pts: int = 24
			var tilt: float = rng.randf_range(-0.22, 0.22)
			var pinch: float = rng.randf_range(0.30, 0.42)
			for i in range(num_pts):
				var angle: float = (TAU * float(i)) / float(num_pts)
				# Pinch tightly at top/bottom (angle near PI/2 and 3*PI/2)
				var sin_a: float = absf(sin(angle + tilt))
				var factor: float = lerpf(1.05, pinch, pow(sin_a, 1.7))
				factor += rng.randf_range(-0.04, 0.04)
				outer_control.append(Vector2(cx + cos(angle) * rx * factor, cy + sin(angle) * ry * factor))

		ShapeType.ARCHIPELAGO:
			var num_pts: int = 20
			var p1: float = rng.randf_range(0.0, TAU)
			var p2: float = rng.randf_range(0.0, TAU)
			for i in range(num_pts):
				var angle: float = (TAU * float(i)) / float(num_pts)
				var wave: float = 0.94 + 0.12 * sin(angle * 3.0 + p1) + 0.08 * cos(angle * 4.0 + p2)
				outer_control.append(Vector2(cx + cos(angle) * rx * wave, cy + sin(angle) * ry * wave))

			# Add 2 or 3 irregular internal obstacle islands
			var num_holes: int = rng.randi_range(2, 3)
			var base_angle: float = rng.randf_range(0.0, TAU)
			for h in range(num_holes):
				var h_angle: float = base_angle + (TAU * float(h)) / float(num_holes)
				var dist_factor: float = rng.randf_range(0.32, 0.44)
				var hcx: float = cx + cos(h_angle) * rx * dist_factor
				var hcy: float = cy + sin(h_angle) * ry * dist_factor
				var hrx: float = width * rng.randf_range(0.065, 0.095)
				var hry: float = height * rng.randf_range(0.075, 0.11)
				var hole_ctrl: PackedVector2Array = PackedVector2Array()
				var h_pts: int = 10
				var hp: float = rng.randf_range(0.0, TAU)
				for j in range(h_pts):
					var a: float = (TAU * float(j)) / float(h_pts)
					var w: float = 1.0 + 0.18 * sin(a * 2.0 + hp) + rng.randf_range(-0.06, 0.06)
					hole_ctrl.append(Vector2(hcx + cos(a) * hrx * w, hcy + sin(a) * hry * w))
				holes.append(_chaikin_smooth(hole_ctrl, 2))

		ShapeType.DEEP_COVES:
			var lobes: int = rng.randi_range(4, 6)
			var num_pts: int = lobes * 6
			var phase: float = rng.randf_range(0.0, TAU)
			var secondary_phase: float = rng.randf_range(0.0, TAU)
			for i in range(num_pts):
				var angle: float = (TAU * float(i)) / float(num_pts)
				var lobe_wave: float = 0.74 + 0.28 * sin(angle * float(lobes) + phase)
				var asym: float = 0.08 * cos(angle * 2.0 + secondary_phase)
				var r_scale: float = clampf(lobe_wave + asym, 0.42, 1.06)
				outer_control.append(Vector2(cx + cos(angle) * rx * r_scale, cy + sin(angle) * ry * r_scale))

		ShapeType.TWIN_CHAMBERS:
			var num_pts: int = 28
			var bridge_offset: float = rng.randf_range(-0.35, 0.35)
			for i in range(num_pts):
				var angle: float = (TAU * float(i)) / float(num_pts)
				var x_norm: float = cos(angle)
				var y_norm: float = sin(angle)
				var r_x: float = rx * 1.02
				var r_y: float = ry * 0.95
				# Narrow vertical constriction near x = 0
				var choke: float = 1.0 - 0.64 * exp(-pow(x_norm * 3.2, 2.0))
				var y_shift: float = bridge_offset * ry * 0.35 * exp(-pow(x_norm * 2.5, 2.0))
				var px: float = cx + x_norm * r_x * (0.95 + 0.08 * cos(angle * 3.0))
				var py: float = cy + y_shift + y_norm * r_y * choke
				outer_control.append(Vector2(px, py))

	var smooth_outer: PackedVector2Array = _chaikin_smooth(outer_control, 3)
	var mask: PackedByteArray = _rasterize_mask(width, height, smooth_outer, holes)

	var playable_count: int = 0
	for i in range(mask.size()):
		if mask[i] == 1:
			playable_count += 1

	return {
		"outer": smooth_outer,
		"holes": holes,
		"mask": mask,
		"playable_pixels": playable_count,
		"actual_type": actual_type,
	}


static func _chaikin_smooth(poly: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var current: PackedVector2Array = poly
	for _iter in range(iterations):
		var next_poly: PackedVector2Array = PackedVector2Array()
		var n: int = current.size()
		for i in range(n):
			var p0: Vector2 = current[i]
			var p1: Vector2 = current[(i + 1) % n]
			next_poly.append(p0.lerp(p1, 0.25))
			next_poly.append(p0.lerp(p1, 0.75))
		current = next_poly
	return current


static func _rasterize_mask(
	width: int,
	height: int,
	outer: PackedVector2Array,
	holes: Array[PackedVector2Array]
) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(width * height)
	mask.fill(0)

	_scanline_fill(mask, width, height, outer, 1)
	for hole in holes:
		_scanline_fill(mask, width, height, hole, 0)

	return mask


static func _scanline_fill(
	mask: PackedByteArray,
	width: int,
	height: int,
	poly: PackedVector2Array,
	fill_val: int
) -> void:
	var n: int = poly.size()
	if n < 3:
		return

	for y in range(height):
		var scan_y: float = float(y) + 0.5
		var nodes: Array[float] = []
		var j: int = n - 1
		for i in range(n):
			var pi: Vector2 = poly[i]
			var pj: Vector2 = poly[j]
			if (pi.y < scan_y and pj.y >= scan_y) or (pj.y < scan_y and pi.y >= scan_y):
				var x_intersect: float = pi.x + (scan_y - pi.y) / (pj.y - pi.y) * (pj.x - pi.x)
				nodes.append(x_intersect)
			j = i

		nodes.sort()
		var row_offset: int = y * width
		var k: int = 0
		while k + 1 < nodes.size():
			var x_start: int = clampi( int(ceil(nodes[k] - 0.5)), 0, width - 1 )
			var x_end: int = clampi( int(floor(nodes[k + 1] - 0.5)), 0, width - 1 )
			for x in range(x_start, x_end + 1):
				mask[row_offset + x] = fill_val
			k += 2
