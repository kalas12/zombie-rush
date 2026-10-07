extends RefCounted
# ИИ людей: их ход после игрока. Статические функции над состоянием боя (battle_state.gd).
# - бьют сразу, без предупреждения: ближайшего зомби, которого достают (освещён + видим);
# - укусившего их в этот ход — видят и бьют даже в темноте;
# - walks: бить некого → шаг к зомби на освещённой клетке;
# - coward: увидел зомби → паника;
# - паника: не бьют, бегут к ближайшему краю (подальше от зомби), добежал — сбежал.
# Подключение: const HumanAI = preload("res://scripts/battle/human_ai.gd")

const BC = preload("res://scripts/battle/battle_config.gd")
const Vision = preload("res://scripts/battle/vision.gd")
const Pathing = preload("res://scripts/battle/pathing.gd")

static func take_turn(s) -> Array:
	var ev := []
	for m in s.humans.duplicate():
		ev += _act(s, m)
		if s.phase == "over":
			break
	return ev

# Может ли человек ударить клетку: в радиусе, прямая видимость, вплотную по диагонали —
# не через угол; клетка освещена (или там зомби, который его укусил — lit_ok)
static func _reaches(s, m: Dictionary, c: Vector2i, lit_ok: bool) -> bool:
	var d := Pathing.cheb(m.cell, c)
	if d < 1 or d > m.reach or not Vision.line_of_sight(s.map, m.cell, c):
		return false
	if d == 1 and not s.map.can_step(m.cell, c - m.cell):
		return false
	return lit_ok or Vision.is_lit(s.map, c)

static func can_hit(s, m: Dictionary, z: Dictionary) -> bool:
	return _reaches(s, m, z.cell, m.attackers.has(z.id))

# Клетки, которые человек простреливает (подсветка по клику)
static func threat_cells(s, m: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if m.panicking:
		return out
	for c in s.map.cells():
		if s.map.walkable_or_window(c) and _reaches(s, m, c, false):
			out.append(c)
	return out

static func _act(s, m: Dictionary) -> Array:
	var ev := []
	if not m.panicking and m.coward and _target(s, m, true) != null:
		ev += s.panic(m)
	if m.panicking:
		return ev + _flee(s, m)
	if m.damage <= 0:
		return ev
	var z = _target(s, m, false)
	if z == null and m.walks:
		var far = _target(s, m, true)
		if far != null:
			var step = _step_toward(s, m.cell, far.cell)
			if step != null:
				ev.append({ "t": "move", "id": m.id, "path": [m.cell, step] })
				m.cell = step
				z = _target(s, m, false)
	if z != null:
		ev += _hit(s, m, z)
	return ev

# Ближайший зомби, которого можно ударить (any_range — просто видимый в свете, любая дальность)
static func _target(s, m: Dictionary, any_range: bool):
	var best = null
	var best_d := INF
	for z in s.zombies:
		if not (Vision.can_see(s.map, m.cell, z.cell) if any_range else can_hit(s, m, z)):
			continue
		var d := Pathing.cheb(m.cell, z.cell) + Vector2(z.cell - m.cell).length() * 0.01   # при равенстве — ближе по прямой
		if d < best_d:
			best_d = d
			best = z
	return best

# Шаг на соседнюю свободную клетку, которая ближе (по BFS) к цели
static func _step_toward(s, from: Vector2i, goal: Vector2i):
	var dist := Pathing.dist_map(s.map, [goal], func(c): return s.is_free(c) or c == from)
	if not dist.has(from):
		return null
	for d in Pathing.DIRS8:
		var n: Vector2i = from + d
		if s.is_free(n) and s.map.can_step(from, d) and dist.get(n, 999) < dist[from]:
			return n
	return null

# Паника: до PANIC_MOVE клеток к ближайшему краю, при равенстве — подальше от зомби
static func _flee(s, m: Dictionary) -> Array:
	var free_or_me := func(c): return s.is_free(c) or c == m.cell
	var edges: Array = s.map.cells().filter(func(c): return s.map.on_edge(c) and free_or_me.call(c))
	var to_edge := Pathing.dist_map(s.map, edges, free_or_me)
	var prev := Pathing.flood(s.map, m.cell, BC.PANIC_MOVE, s.is_free)
	var best: Vector2i = m.cell
	var best_score := INF
	for c in prev:
		if not to_edge.has(c):
			continue
		var score: float = to_edge[c] * 100.0 - _nearest_zombie(s, c)
		if score < best_score:
			best_score = score
			best = c
	var ev := []
	if best != m.cell:
		ev.append({ "t": "move", "id": m.id, "path": Pathing.path_to(prev, best) })
		m.cell = best
	if s.map.on_edge(m.cell):
		s.humans.erase(m)
		s.fled += 1
		ev.append({ "t": "fled", "id": m.id })
		s.check_end()
	return ev

static func _nearest_zombie(s, c: Vector2i) -> float:
	var best := 99.0
	for z in s.zombies:
		best = minf(best, Pathing.cheb(c, z.cell))
	return best

static func _hit(s, m: Dictionary, z: Dictionary) -> Array:
	var ev := [{ "t": "hit", "from": m.id, "cell": z.cell, "target": z.id, "dmg": m.damage }]
	z.hp -= m.damage
	if z.hp <= 0:
		s.kill_zombie(z)
		ev.append({ "t": "die", "id": z.id })
		s.check_end()
	return ev
