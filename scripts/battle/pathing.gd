extends RefCounted
# Поиск пути по клеткам в 8 сторон (с правилом углов). Статические функции.
# Подключение: const Pathing = preload("res://scripts/battle/pathing.gd")

const DIRS8 := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# Расстояние по Чебышёву: диагональ = 1 клетка
static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

# BFS от start не дальше max_steps по клеткам, где passable(c) == true.
# Возвращает { клетка: откуда пришли } (старт — с null). Останавливаться можно не везде —
# это проверяет вызывающий (например, зомби проходят сквозь своих, но не встают на них).
static func flood(map, start: Vector2i, max_steps: int, passable: Callable) -> Dictionary:
	var prev := { start: null }
	var dist := { start: 0 }
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if dist[c] >= max_steps:
			continue
		for d in DIRS8:
			var n: Vector2i = c + d
			if not prev.has(n) and passable.call(n) and map.can_step(c, d):
				prev[n] = c
				dist[n] = dist[c] + 1
				queue.append(n)
	return prev

static func path_to(prev: Dictionary, cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var c = cell
	while c != null:
		path.push_front(c)
		c = prev[c]
	return path

# Расстояния в шагах от любой из sources по клеткам, где passable(c) == true
static func dist_map(map, sources: Array, passable: Callable) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for s in sources:
		dist[s] = 0
		queue.append(s)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in DIRS8:
			var n: Vector2i = c + d
			if not dist.has(n) and passable.call(n) and map.can_step(c, d):
				dist[n] = dist[c] + 1
				queue.append(n)
	return dist
