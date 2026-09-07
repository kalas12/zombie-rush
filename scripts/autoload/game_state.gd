@tool
extends Node

# Autoload "GameState" — состояние текущего забега, живёт между сценами.
# Регистрация: Project Settings → вкладка Globals → Autoload →
#   Path: res://scripts/autoload/game_state.gd, Node Name: GameState, Add.

# --- Карта / прогресс (Фаза 2) ---
var current_node := ""              # id узла, где игрок сейчас ("" = забег не начат)
var passed: Array[String] = []      # id пройденных узлов
var pending_node := ""              # узел, ради которого запущена под-сцена (бой/событие/…)
var pending_type := ""              # тип этого узла
var biomass := 0                    # опыт-валюта: копится с находок и боёв (тратим позже)
var last_corpses := 0               # убитых защитников в последнем бою (для экрана награды)
var last_reward := 0                # биомасса, начисленная за последнюю победу

# --- Персистентная армия зомби (Фаза 3) ---
# Каждый зомби армии — словарь: { id, type, hp, max_hp, loot }
# Числа — из «04 — Content». weight = место в отряде. Остальное — статы для боя.
const ZTYPE := {
	"normal": { "max_hp": 42,  "weight": 1, "speed": 95.0,  "bite_damage": 11, "bite_cooldown": 0.6, "texture": "res://assets/units/basic.png" },
	"runner": { "max_hp": 24,  "weight": 2, "speed": 160.0, "bite_damage": 7,  "bite_cooldown": 0.5, "texture": "res://assets/units/fast.png" },
	"fat":    { "max_hp": 120, "weight": 3, "speed": 58.0,  "bite_damage": 20, "bite_cooldown": 0.8, "texture": "res://assets/units/armored.png" },
}
const START_ARMY := { "normal": 5 }            # стартовый состав забега

var army: Array[Dictionary] = []
var _next_zid := 0                             # счётчик уникальных id зомби

# --- Отряды (Фаза 3, Шаг 2) ---
# squads[i] = массив id зомби. До 5 отрядов, вместимость по весу = 5 на отряд.
const MAX_SQUADS := 5
const SQUAD_CAP := 5

var squads: Array = []

# ── Забег ────────────────────────────────────────────────────────

# Начать забег: старт-узел + свежая армия + биомасса 0.
func start_run(start_id: String) -> void:
	current_node = start_id
	passed = [start_id]
	biomass = 0
	last_corpses = 0
	last_reward = 0
	army = []
	_next_zid = 0
	clear_squads()
	for type in START_ARMY:
		for i in START_ARMY[type]:
			add_zombie(type)
	print("[army] забег начат: %d зомби, вес %d — %s" % [army.size(), get_army_weight(), army])

# Перейти на узел (карта вызывает после клика по доступному)
func go_to(node_id: String) -> void:
	current_node = node_id
	if not passed.has(node_id):
		passed.append(node_id)

# Полный сброс (город → «заново»); карта потом сама вызовет start_run().
func reset() -> void:
	current_node = ""
	passed = []
	pending_node = ""
	pending_type = ""
	biomass = 0
	last_corpses = 0
	last_reward = 0
	army = []
	_next_zid = 0
	clear_squads()

# ── Армия ────────────────────────────────────────────────────────

func add_zombie(type: String) -> Dictionary:
	var t: Dictionary = ZTYPE.get(type, ZTYPE["normal"])
	var z := {
		"id": _next_zid,
		"type": type,
		"hp": t.max_hp,
		"max_hp": t.max_hp,
		"loot": [],
	}
	_next_zid += 1
	army.append(z)
	return z

func remove_zombie(id: int) -> void:
	remove_from_squad(id)
	for i in range(army.size() - 1, -1, -1):
		if army[i].id == id:
			army.remove_at(i)
			return

func heal_zombie(id: int, amount: int) -> void:
	for z in army:
		if z.id == id:
			z.hp = mini(z.hp + amount, z.max_hp)
			return

# Суммарный вес армии (места в отрядах): normal 1, runner 2, fat 3.
func get_army_weight() -> int:
	var w := 0
	for z in army:
		var t: Dictionary = ZTYPE.get(z.type, { "weight": 1 })
		w += t.weight
	return w

func get_army() -> Array[Dictionary]:
	return army

# ── Отряды ───────────────────────────────────────────────────────

func clear_squads() -> void:
	squads = []
	for i in MAX_SQUADS:
		squads.append([])

func zombie_by_id(zid: int) -> Dictionary:
	for z in army:
		if z.id == zid:
			return z
	return {}

func zombie_weight(zid: int) -> int:
	var z := zombie_by_id(zid)
	if z.is_empty():
		return 1
	var t: Dictionary = ZTYPE.get(z.type, { "weight": 1 })
	return t.weight

# В каком отряде зомби (-1 = ни в каком, в резерве)
func squad_of(zid: int) -> int:
	for i in squads.size():
		if squads[i].has(zid):
			return i
	return -1

func squad_weight(idx: int) -> int:
	if idx < 0 or idx >= squads.size():
		return 0
	var w := 0
	for zid in squads[idx]:
		w += zombie_weight(zid)
	return w

# Добавить зомби в отряд idx. false, если уже в отряде или не влезает по весу.
func add_to_squad(zid: int, idx: int) -> bool:
	if idx < 0 or idx >= squads.size():
		return false
	if squad_of(zid) != -1:
		return false
	if squad_weight(idx) + zombie_weight(zid) > SQUAD_CAP:
		return false
	squads[idx].append(zid)
	return true

func remove_from_squad(zid: int) -> void:
	var s := squad_of(zid)
	if s != -1:
		squads[s].erase(zid)

# Зомби армии, не приписанные ни к одному отряду
func reserve() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for z in army:
		if squad_of(z.id) == -1:
			out.append(z)
	return out

func deployed_count() -> int:
	var c := 0
	for s in squads:
		c += s.size()
	return c
