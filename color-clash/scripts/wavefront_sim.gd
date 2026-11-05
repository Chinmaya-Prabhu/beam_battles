class_name WavefrontSim
extends RefCounted

const BUCKET_SCALE: float = 8.0
const MAX_BUCKETS: int = 8192

const NEIGHBOR_DX: Array[int] = [-1, 1, 0, 0, -1, 1, -1, 1]
const NEIGHBOR_DY: Array[int] = [0, 0, -1, 1, -1, -1, 1, 1]
const NEIGHBOR_STEP_COST: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.41421356, 1.41421356, 1.41421356, 1.41421356]

var width: int = 0
var height: int = 0
var mask: PackedByteArray
var owner_grid: PackedInt32Array
var candidate_owner: PackedInt32Array
var best_time: PackedFloat32Array
var pivot_x: PackedFloat32Array
var pivot_y: PackedFloat32Array
var pivot_base_t: PackedFloat32Array

var buckets: Array[PackedInt32Array] = []
var current_bucket_idx: int = 0
var max_populated_bucket: int = 0
var active_remaining: int = 0

var player_counts: PackedInt32Array
var total_playable: int = 0
var is_running: bool = false
var is_finished: bool = false


func setup_arena(w: int, h: int, arena_mask: PackedByteArray, playable_count: int, num_players: int) -> void:
	width = w
	height = h
	mask = arena_mask
	total_playable = maxi(playable_count, 1)

	var total_cells: int = width * height
	owner_grid = PackedInt32Array()
	owner_grid.resize(total_cells)
	candidate_owner = PackedInt32Array()
	candidate_owner.resize(total_cells)
	best_time = PackedFloat32Array()
	best_time.resize(total_cells)
	pivot_x = PackedFloat32Array()
	pivot_x.resize(total_cells)
	pivot_y = PackedFloat32Array()
	pivot_y.resize(total_cells)
	pivot_base_t = PackedFloat32Array()
	pivot_base_t.resize(total_cells)

	for i in range(total_cells):
		if mask[i] == 1:
			owner_grid[i] = -1
		else:
			owner_grid[i] = -2
		candidate_owner[i] = -1
		best_time[i] = 1e9

	player_counts = PackedInt32Array()
	player_counts.resize(num_players)
	player_counts.fill(0)

	buckets.clear()
	buckets.resize(MAX_BUCKETS)
	for b in range(MAX_BUCKETS):
		buckets[b] = PackedInt32Array()

	current_bucket_idx = 0
	max_populated_bucket = 0
	active_remaining = 0
	is_running = false
	is_finished = false


func start_spread(dots: Array[Dictionary], num_players: int) -> void:
	setup_arena(width, height, mask, total_playable, num_players)

	for dot in dots:
		var p_id: int = int(dot["player"])
		var pos: Vector2 = dot["pos"]
		var seed_idx: int = _find_nearest_playable_index(int(round(pos.x)), int(round(pos.y)))
		if seed_idx < 0:
			continue

		best_time[seed_idx] = 0.0
		candidate_owner[seed_idx] = p_id
		pivot_x[seed_idx] = pos.x
		pivot_y[seed_idx] = pos.y
		pivot_base_t[seed_idx] = 0.0
		buckets[0].append(seed_idx)
		active_remaining += 1

	is_running = true
	is_finished = (active_remaining == 0)


func step_to_time(
	target_time: float,
	img: Image,
	player_colors: Array[Color]
) -> PackedInt32Array:
	var newly_claimed: PackedInt32Array = PackedInt32Array()
	if not is_running or is_finished:
		return newly_claimed

	var target_bucket: int = clampi(int(floor(target_time * BUCKET_SCALE)), 0, MAX_BUCKETS - 1)

	while current_bucket_idx <= target_bucket and current_bucket_idx <= max_populated_bucket:
		var bucket: PackedInt32Array = buckets[current_bucket_idx]
		var b_size: int = bucket.size()
		for i in range(b_size):
			var idx: int = bucket[i]
			if owner_grid[idx] != -1:
				continue

			var p_id: int = candidate_owner[idx]
			if p_id < 0:
				continue

			var arrival_t: float = best_time[idx]
			owner_grid[idx] = p_id
			player_counts[p_id] += 1
			newly_claimed.append(idx)

			var px: int = idx % width
			var py: int = idx / width

			# Check if adjacent to a different player's already-claimed pixel (collision boundary)
			var touches_rival: bool = false
			for n_dir in range(8):
				var nx: int = px + NEIGHBOR_DX[n_dir]
				var ny: int = py + NEIGHBOR_DY[n_dir]
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					var n_owner: int = owner_grid[ny * width + nx]
					if n_owner >= 0 and n_owner != p_id:
						touches_rival = true
						break

			var base_col: Color = player_colors[p_id]
			if touches_rival:
				# Crisp dark-tinted boundary seam where two colors collide
				img.set_pixel(px, py, base_col.darkened(0.42))
			else:
				# Subtle concentric wave texture so circular spread from origin is visually clear
				var ripple: float = 0.94 + 0.06 * sin(arrival_t * 0.38)
				img.set_pixel(
					px,
					py,
					Color(
						clampf(base_col.r * ripple, 0.0, 1.0),
						clampf(base_col.g * ripple, 0.0, 1.0),
						clampf(base_col.b * ripple, 0.0, 1.0),
						1.0
					)
				)

			# Relax 8 neighbors using exact Euclidean pivot propagation + Huygens corner diffraction
			var cur_piv_x: float = pivot_x[idx]
			var cur_piv_y: float = pivot_y[idx]
			var cur_piv_base: float = pivot_base_t[idx]

			for n_dir in range(8):
				var qx: int = px + NEIGHBOR_DX[n_dir]
				var qy: int = py + NEIGHBOR_DY[n_dir]
				if qx < 0 or qx >= width or qy < 0 or qy >= height:
					continue
				var q_idx: int = qy * width + qx
				if owner_grid[q_idx] != -1:
					continue

				var dx: float = float(qx) - cur_piv_x
				var dy: float = float(qy) - cur_piv_y
				var visible_from_pivot: bool = _is_visible_from_pivot(
					qx, qy, dx, dy, p_id, cur_piv_x, cur_piv_y
				)

				var cand_t: float
				var cand_piv_x: float
				var cand_piv_y: float
				var cand_piv_base: float

				if visible_from_pivot:
					cand_t = cur_piv_base + sqrt(dx * dx + dy * dy)
					cand_piv_x = cur_piv_x
					cand_piv_y = cur_piv_y
					cand_piv_base = cur_piv_base
				else:
					# Obstacle or rival color blocked direct ray -> diffract around (px, py)
					cand_t = arrival_t + NEIGHBOR_STEP_COST[n_dir]
					cand_piv_x = float(px)
					cand_piv_y = float(py)
					cand_piv_base = arrival_t

				if cand_t < best_time[q_idx]:
					best_time[q_idx] = cand_t
					candidate_owner[q_idx] = p_id
					pivot_x[q_idx] = cand_piv_x
					pivot_y[q_idx] = cand_piv_y
					pivot_base_t[q_idx] = cand_piv_base

					var b_idx: int = clampi(int(floor(cand_t * BUCKET_SCALE)), current_bucket_idx, MAX_BUCKETS - 1)
					buckets[b_idx].append(q_idx)
					if b_idx > max_populated_bucket:
						max_populated_bucket = b_idx

		buckets[current_bucket_idx].clear()
		current_bucket_idx += 1

	if current_bucket_idx > max_populated_bucket:
		is_finished = true
		is_running = false

	return newly_claimed


func _is_visible_from_pivot(
	qx: int,
	qy: int,
	dx: float,
	dy: float,
	p_id: int,
	piv_x: float,
	piv_y: float
) -> bool:
	var adx: float = absf(dx)
	var ady: float = absf(dy)
	if adx <= 1.6 and ady <= 1.6:
		return true

	var sx: int = -1 if dx > 0.0 else (1 if dx < 0.0 else 0)
	var sy: int = -1 if dy > 0.0 else (1 if dy < 0.0 else 0)

	var n1x: int = qx + sx
	var n1y: int = qy + sy
	var n2x: int = qx
	var n2y: int = qy

	if adx > ady + 0.5:
		n2x = qx + sx
		n2y = qy
	elif ady > adx + 0.5:
		n2x = qx
		n2y = qy + sy
	else:
		n2x = n1x
		n2y = n1y

	if n1x < 0 or n1x >= width or n1y < 0 or n1y >= height:
		return false
	if n2x < 0 or n2x >= width or n2y < 0 or n2y >= height:
		return false

	var idx1: int = n1y * width + n1x
	var idx2: int = n2y * width + n2x

	if owner_grid[idx1] != p_id or owner_grid[idx2] != p_id:
		return false

	if absf(pivot_x[idx1] - piv_x) > 0.5 or absf(pivot_y[idx1] - piv_y) > 0.5:
		return false
	if absf(pivot_x[idx2] - piv_x) > 0.5 or absf(pivot_y[idx2] - piv_y) > 0.5:
		return false

	return true


func _find_nearest_playable_index(start_x: int, start_y: int) -> int:
	var cx: int = clampi(start_x, 0, width - 1)
	var cy: int = clampi(start_y, 0, height - 1)
	if mask[cy * width + cx] == 1:
		return cy * width + cx

	for r in range(1, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var nx: int = clampi(cx + dx, 0, width - 1)
				var ny: int = clampi(cy + dy, 0, height - 1)
				if mask[ny * width + nx] == 1:
					return ny * width + nx
	return -1


func is_point_playable(pos: Vector2) -> bool:
	var ix: int = int(round(pos.x))
	var iy: int = int(round(pos.y))
	if ix < 0 or ix >= width or iy < 0 or iy >= height:
		return false
	return mask[iy * width + ix] == 1


func choose_ai_point(
	player_id: int,
	existing_dots: Array[Dictionary],
	difficulty: int,
	secret_mode: bool,
	rng: RandomNumberGenerator
) -> Vector2:
	# Gather coarse sample points inside mask for fast area estimation
	var samples: PackedVector2Array = PackedVector2Array()
	var step: int = 10
	for y in range(step / 2, height, step):
		var row_off: int = y * width
		for x in range(step / 2, width, step):
			if mask[row_off + x] == 1:
				samples.append(Vector2(float(x), float(y)))

	if samples.is_empty():
		return Vector2(width * 0.5, height * 0.5)

	# In secret placement mode, AI only knows its own previously placed dots
	var visible_dots: Array[Dictionary] = []
	for d in existing_dots:
		if not secret_mode or int(d["player"]) == player_id:
			visible_dots.append(d)

	var num_candidates: int = 14 if difficulty == 0 else (42 if difficulty == 1 else 88)
	var best_pos: Vector2 = samples[rng.randi_range(0, samples.size() - 1)]
	var best_score: float = -1e9

	for _c in range(num_candidates):
		var cand: Vector2 = samples[rng.randi_range(0, samples.size() - 1)]
		cand += Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
		if not is_point_playable(cand):
			continue

		var too_close: bool = false
		for d in visible_dots:
			if cand.distance_to(d["pos"]) < 10.0:
				too_close = true
				break
		if too_close:
			continue

		var my_area: int = 0
		for s in samples:
			var my_dist: float = s.distance_squared_to(cand)
			var min_other_dist: float = 1e12
			for d in visible_dots:
				var dist_sq: float = s.distance_squared_to(d["pos"])
				if int(d["player"]) == player_id:
					if dist_sq < my_dist:
						my_dist = dist_sq
				else:
					if dist_sq < min_other_dist:
						min_other_dist = dist_sq

			if my_dist < min_other_dist:
				my_area += 1

		var noise: float = rng.randf_range(-8.0, 8.0) if difficulty == 0 else (rng.randf_range(-2.0, 2.0) if difficulty == 1 else 0.0)
		var score: float = float(my_area) + noise
		if score > best_score:
			best_score = score
			best_pos = cand

	return best_pos
