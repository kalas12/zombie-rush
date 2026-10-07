extends RefCounted
# Свет и видимость: что освещено и что человек видит. Статические функции над картой арены.
# Подключение: const Vision = preload("res://scripts/battle/vision.gd")

const BC = preload("res://scripts/battle/battle_config.gd")

# Пол освещён всегда; окна и проёмы светят на LIGHT_OPENING, костёр — на LIGHT_FIRE.
# Свет стенами не режется.
static func is_lit(map, c: Vector2i) -> bool:
	if map.tile(c) == "_":
		return true
	for o in map.openings:
		if Vector2(c - o).length() <= BC.LIGHT_OPENING:
			return true
	return map.fire_hp > 0 and Vector2(c - map.fire_cell).length() <= BC.LIGHT_FIRE

# Прямая видимость: ни одна клетка МЕЖДУ a и b не закрывает обзор
static func line_of_sight(map, a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(1, steps):
		var p := Vector2(a).lerp(Vector2(b), float(i) / steps).round()
		if map.blocks_sight(Vector2i(p)):
			return false
	return true

# Человек видит клетку: она освещена И есть прямая видимость
static func can_see(map, from: Vector2i, to: Vector2i) -> bool:
	return is_lit(map, to) and line_of_sight(map, from, to)
