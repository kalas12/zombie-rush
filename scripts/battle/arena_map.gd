extends RefCounted
# Карта арены: клетки из ASCII, проходимость, окна и костёр с HP, зона выхода.
# Юнитов не знает — это battle_state.gd.

const BC = preload("res://scripts/battle/battle_config.gd")

const NONE := Vector2i(-1, -1)
const SIGHT_BLOCKERS := "#tpc"         # закрывают обзор (окно — нет)

var rows: Array = []
var w := 0
var h := 0
var windows := {}                      # Vector2i → hp (0 = разбито, проходимо)
var openings: Array[Vector2i] = []     # окна и проёмы — источники света
var fire_cell := NONE
var fire_hp := 0

func _init(map_rows: Array) -> void:
	rows = map_rows
	h = rows.size()
	w = rows[0].length()
	for c in cells():
		match tile(c):
			"W":
				windows[c] = BC.WINDOW_HP
				openings.append(c)
			"D":
				openings.append(c)
			"F":
				fire_cell = c
				fire_hp = BC.FIRE_HP

func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			out.append(Vector2i(x, y))
	return out

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

func on_edge(c: Vector2i) -> bool:
	return c.x == 0 or c.y == 0 or c.x == w - 1 or c.y == h - 1

func tile(c: Vector2i) -> String:
	return rows[c.y][c.x] if inside(c) else "#"

# Можно ли стоять на клетке (без учёта юнитов)
func walkable(c: Vector2i) -> bool:
	match tile(c):
		".", "s", "_", "D":
			return true
		"W":
			return windows[c] <= 0
		"F":
			return fire_hp <= 0
	return false

func walkable_or_window(c: Vector2i) -> bool:
	return walkable(c) or tile(c) == "W"

func blocks_sight(c: Vector2i) -> bool:
	return SIGHT_BLOCKERS.contains(tile(c))

# Правило углов: по диагонали нельзя, если обе соседние по стороне клетки непроходимы
func can_step(c: Vector2i, d: Vector2i) -> bool:
	if d.x != 0 and d.y != 0:
		return walkable(c + Vector2i(d.x, 0)) or walkable(c + Vector2i(0, d.y))
	return true

func is_deploy_zone(c: Vector2i) -> bool:
	return tile(c) == "s"

func is_structure(c: Vector2i) -> bool:
	return windows.get(c, 0) > 0 or (c == fire_cell and fire_hp > 0)

# Урон по окну или костру. true — разрушено этим ударом.
func damage_structure(c: Vector2i, dmg: int) -> bool:
	if windows.get(c, 0) > 0:
		windows[c] = maxi(0, windows[c] - dmg)
		return windows[c] == 0
	if c == fire_cell and fire_hp > 0:
		fire_hp = maxi(0, fire_hp - dmg)
		return fire_hp == 0
	return false
