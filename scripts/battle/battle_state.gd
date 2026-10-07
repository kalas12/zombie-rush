extends RefCounted
# Состояние боя и действия игрока: юниты, выставление, ходы зомби, натиск, окружение,
# заражение, конец боя. Без узлов сцены. Ход людей — human_ai.gd.
# Каждое действие возвращает список событий — сцена их проигрывает (анимации, журнал):
#   { t: "move", id, path }                    юнит прошёл по клеткам
#   { t: "hit", from, cell, target, dmg }      удар/выстрел по клетке (target = id или -1)
#   { t: "die", id }                           юнит убит
#   { t: "spawn", id }                         новый зомби (заражение)
#   { t: "panic", id } / { t: "fled", id }     человек запаниковал / сбежал с поля
#   { t: "broken", cell }                      разбито окно / затоптан костёр
# Подключение: const BattleState = preload("res://scripts/battle/battle_state.gd")

const BC = preload("res://scripts/battle/battle_config.gd")
const ArenaMap = preload("res://scripts/battle/arena_map.gd")
const Pathing = preload("res://scripts/battle/pathing.gd")
const HumanAI = preload("res://scripts/battle/human_ai.gd")

const OFF := Vector2i(-1, -1)          # зомби в резерве (не выставлен)

var map                                # ArenaMap
# человек: { id, cell, texture, hp, max_hp, reach, damage, walks, coward, panicking,
#            attackers: [id укусивших за ход — по ним бьёт и в темноте],
#            hit_by: [id разных зомби, ударивших за ход — для окружения] }
var humans: Array = []
# зомби: { id, army_id (-1 = не из армии), type, cell, hp, hp_start, max_hp, move, bite,
#          struct_mult, moved, attacked }
var zombies: Array = []

var killed := 0                        # людей убито (→ трупы)
var fled := 0                          # людей сбежало (ничего не дают)
var casualties: Array[int] = []        # army_id погибших зомби армии
var turn := 1
var phase := "deploy"                  # deploy → player ⇄ (ход людей) → over
var result := ""                       # "win" | "dawn" | "wiped"
var _next_id := 0

# defenders — HumanType на посты по порядку; army_units — из battle_setup.gd
func _init(map_rows: Array, posts: Array, defenders: Array, strength: float, army_units: Array) -> void:
	map = ArenaMap.new(map_rows)
	for i in mini(posts.size(), defenders.size()):
		var t = defenders[i]
		if t == null:
			continue
		var hp := maxi(1, roundi(t.max_hp * strength))
		humans.append({ "id": _id(), "cell": posts[i], "texture": t.texture,
			"hp": hp, "max_hp": hp, "reach": t.reach, "damage": roundi(t.damage * strength),
			"walks": t.walks, "coward": t.coward, "panicking": false, "attackers": [], "hit_by": [] })
	for u in army_units:
		var z: Dictionary = u.duplicate()
		z.merge({ "id": _id(), "cell": OFF, "hp_start": u.hp, "moved": false, "attacked": false })
		zombies.append(z)

func _id() -> int:
	_next_id += 1
	return _next_id

# ── Юниты на поле ────────────────────────────────────────────────

func human_at(c: Vector2i):
	for m in humans:
		if m.cell == c:
			return m
	return null

func zombie_at(c: Vector2i):
	for z in zombies:
		if z.cell == c:
			return z
	return null

# Клетка, где можно встать
func is_free(c: Vector2i) -> bool:
	return map.walkable(c) and human_at(c) == null and zombie_at(c) == null

# Зомби проходят сквозь своих (но не встают на них), сквозь людей — нет
func zombie_can_pass(c: Vector2i) -> bool:
	return map.walkable(c) and human_at(c) == null

func threat_cells(m: Dictionary) -> Array[Vector2i]:
	return HumanAI.threat_cells(self, m)

# ── Ход зомби ────────────────────────────────────────────────────

# Куда зомби может пройти в этот ход
func destinations(z: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if z.moved or z.attacked:
		return out
	for c in Pathing.flood(map, z.cell, z.move, zombie_can_pass):
		if c != z.cell and is_free(c):
			out.append(c)
	return out

func move_zombie(z: Dictionary, cell: Vector2i) -> Array:
	if not destinations(z).has(cell):
		return []
	var path := Pathing.path_to(Pathing.flood(map, z.cell, z.move, zombie_can_pass), cell)
	z.cell = cell
	z.moved = true
	return [{ "t": "move", "id": z.id, "path": path }]

# НАТИСК: +1 за каждого своего зомби вплотную к атакующему, не больше RUSH_MAX
func rush(z: Dictionary) -> int:
	var n := 0
	for o in zombies:
		if o != z and o.cell != OFF and Pathing.cheb(o.cell, z.cell) == 1:
			n += 1
	return mini(n * BC.RUSH_PER_ALLY, BC.RUSH_MAX)

# Итоговый укус по человеку или по постройке (окно/костёр)
func bite_vs(z: Dictionary, structure: bool) -> int:
	return (z.bite + rush(z)) * (z.struct_mult if structure else 1)

# Соседние (8 сторон, правило углов) клетки, которые зомби может укусить
func attack_targets(z: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if z.attacked:
		return out
	for d in Pathing.DIRS8:
		var c: Vector2i = z.cell + d
		if map.can_step(z.cell, d) and (human_at(c) != null or map.is_structure(c)):
			out.append(c)
	return out

# Зомби уже всё сделал в этом ходу (для «следующего» и тусклых фишек)
func is_done(z: Dictionary) -> bool:
	return z.attacked or (z.moved and attack_targets(z).is_empty())

func attack(z: Dictionary, cell: Vector2i) -> Array:
	if not attack_targets(z).has(cell):
		return []
	z.attacked = true
	z.moved = true
	var ev := []
	var m = human_at(cell)
	if m != null:
		var dmg := bite_vs(z, false)
		m.hp -= dmg
		ev.append({ "t": "hit", "from": z.id, "cell": cell, "target": m.id, "dmg": dmg })
		if not m.attackers.has(z.id):
			m.attackers.append(z.id)
		if m.hp <= 0:
			ev += _kill_human(m)
		else:
			if not m.panicking and (m.coward or m.hp <= m.max_hp * BC.PANIC_HP_FRAC):
				ev += panic(m)   # трус — от первого же укуса
			ev += _surround(m, z)
	else:
		var dmg := bite_vs(z, true)
		ev.append({ "t": "hit", "from": z.id, "cell": cell, "target": -1, "dmg": dmg })
		if map.damage_structure(cell, dmg):
			ev.append({ "t": "broken", "cell": cell })
	check_end()
	return ev

func panic(m: Dictionary) -> Array:
	m.panicking = true
	return [{ "t": "panic", "id": m.id }]

# ОКРУЖЕНИЕ: второй разный зомби за ход ударил → человек отступает на 1 клетку от нападающих
func _surround(m: Dictionary, z: Dictionary) -> Array:
	if not m.hit_by.has(z.id):
		m.hit_by.append(z.id)
	if m.hit_by.size() != BC.SURROUND_HITS:
		return []
	var foes: Array = zombies.filter(func(o): return m.hit_by.has(o.id))
	var score := func(c: Vector2i) -> float:
		var near := 99
		var total := 0
		for o in foes:
			var d := Pathing.cheb(c, o.cell)
			near = mini(near, d)
			total += d
		return near * 10.0 + total
	var best: Vector2i = m.cell
	var best_score: float = score.call(m.cell)
	for d in Pathing.DIRS8:
		var n: Vector2i = m.cell + d
		if is_free(n) and map.can_step(m.cell, d) and score.call(n) > best_score:
			best = n
			best_score = score.call(n)
	if best == m.cell:
		return []   # отступать некуда
	var from: Vector2i = m.cell
	m.cell = best
	return [{ "t": "move", "id": m.id, "path": [from, best] }]

# ЗАРАЖЕНИЕ: убитый человек сразу встаёт зомби (до конца боя), ходит со следующего хода
func _kill_human(m: Dictionary) -> Array:
	humans.erase(m)
	killed += 1
	var g: Dictionary = BC.ZOMBIE[BC.INFECTED]
	var z := { "id": _id(), "army_id": -1, "type": BC.INFECTED, "cell": m.cell, "hp": g.hp, "hp_start": g.hp,
		"max_hp": g.hp, "move": g.move, "bite": g.bite, "struct_mult": 1, "moved": true, "attacked": true }
	zombies.append(z)
	return [{ "t": "die", "id": m.id }, { "t": "spawn", "id": z.id }]

# Зомби убит (вызывает ИИ людей)
func kill_zombie(z: Dictionary) -> void:
	zombies.erase(z)
	if z.army_id >= 0:
		casualties.append(z.army_id)

# ── Выставление ──────────────────────────────────────────────────

func deploy_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in map.cells():
		if map.is_deploy_zone(c) and is_free(c):
			out.append(c)
	return out

func reserve_count(type: String) -> int:
	return zombies.filter(func(z): return z.cell == OFF and z.type == type).size()

func deployed_count() -> int:
	return zombies.filter(func(z): return z.cell != OFF).size()

# Выставить из резерва зомби типа type (самого здорового) на клетку c
func deploy(type: String, c: Vector2i) -> bool:
	if phase != "deploy" or not deploy_cells().has(c):
		return false
	var best = null
	for z in zombies:
		if z.cell == OFF and z.type == type and (best == null or z.hp > best.hp):
			best = z
	if best == null:
		return false
	best.cell = c
	return true

func undeploy(z: Dictionary) -> void:
	if phase == "deploy":
		z.cell = OFF

# Невыставленные в этом бою не участвуют (в армии остаются как были)
func start_battle() -> void:
	zombies = zombies.filter(func(z): return z.cell != OFF)
	phase = "player"

# ── Ход людей и смена хода ───────────────────────────────────────

func end_player_turn() -> Array:
	var ev := HumanAI.take_turn(self)
	if phase == "over":
		return ev
	for m in humans:
		m.attackers.clear()
		m.hit_by.clear()
	turn += 1
	for z in zombies:
		z.moved = false
		z.attacked = false
	check_end()
	return ev

func check_end() -> void:
	if phase == "deploy" or phase == "over":
		return
	if humans.is_empty():
		result = "win"
	elif zombies.is_empty():
		result = "wiped"
	elif turn > BC.TURNS:
		result = "dawn"
	if result != "":
		phase = "over"
