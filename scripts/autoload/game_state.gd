@tool
extends Node

# Autoload "GameState" — состояние текущего забега, живёт между сценами.
# Регистрация: Project Settings → вкладка Globals → Autoload →
#   Path: res://scripts/autoload/game_state.gd, Node Name: GameState, Add.

const TalentDB = preload("res://scripts/data/talents.gd")
const Scenes = preload("res://scripts/scenes.gd")

# --- Карта / прогресс (Фаза 2) ---
var current_node := ""              # id узла, где игрок сейчас ("" = забег не начат)
var passed: Array[String] = []      # id пройденных узлов
var pending_node := ""              # узел, ради которого запущена под-сцена (бой/событие/…)
var pending_type := ""              # тип этого узла
var pending_battle := ""            # для боя: путь к BattleType (.tres) этого узла
var biomass := 0                    # опыт-валюта: копится с находок и боёв (тратим позже)
var last_corpses := 0               # убитых защитников в последнем бою (для экрана награды)
var last_reward := 0                # биомасса, начисленная за последнюю победу
var last_fled := 0                  # сбежавших защитников (трупа не дают)
var last_lost := 0                  # своих зомби погибло в последнем бою

# --- Персистентная армия зомби (Фаза 3) ---
# Каждый зомби армии — словарь: { id, type, hp, max_hp, loot }
# Типы зомби армии. Новый тип = новая строка здесь + строка в battle_config.ZOMBIE (клетки).
# max_hp — HP в армии (лечение/награды считают в нём). speed и bite_damage — базы, к которым
# таланты дают прибавку; в бою клеточные шаг/укус растут пропорционально (battle_setup.gd).
# weight — вес при наборе стартовой армии.
const ZTYPE := {
	"normal": { "name": "обычный", "max_hp": 42,  "weight": 1, "speed": 95.0,  "bite_damage": 11, "texture": "res://assets/units/basic.png" },
	"runner": { "name": "бегун",   "max_hp": 24,  "weight": 2, "speed": 160.0, "bite_damage": 7,  "texture": "res://assets/units/fast.png" },
	"fat":    { "name": "толстяк", "max_hp": 120, "weight": 3, "speed": 58.0,  "bite_damage": 20, "texture": "res://assets/units/armored.png" },
}

var army: Array[Dictionary] = []
var _next_zid := 0                             # счётчик уникальных id зомби

# --- Отряды (Фаза 3, Шаг 2) — В БОЮ НЕ ИСПОЛЬЗУЮТСЯ (бой пошаговый, армия выставляется
# поштучно). Экран «Отряды» скрыт с карты; убрать вместе с талантами g_slot/g_squad.
# squads[i] = массив id зомби. Базово 5 отрядов, вместимость по весу = 5.
const MAX_SQUADS := 5
const SQUAD_CAP := 5

# Бюджет веса на набор стартовой армии (Фаза 3, Шаг 4)
const START_WEIGHT := 6

var squads: Array = []

# --- Таланты (Фаза 3, Шаг 8) — трата биомассы, только на забег ---
var bought_talents: Array[String] = []

# ── Забег ────────────────────────────────────────────────────────

# Начать забег с заданным составом армии (типы списком). Обнуляет всё состояние.
func begin_run(start_id: String, picks: Array) -> void:
	_clear_run()
	current_node = start_id
	passed = [start_id]
	for type in picks:
		add_zombie(type)
	clear_squads()
	print("[army] забег начат: %d зомби, вес %d — %s" % [army.size(), get_army_weight(), army])

# Перейти на узел (карта вызывает после клика по доступному)
func go_to(node_id: String) -> void:
	current_node = node_id
	if not passed.has(node_id):
		passed.append(node_id)

# Полный сброс (город / поражение → «заново»); карта потом откроет набор стартовой армии.
func reset() -> void:
	_clear_run()
	current_node = ""
	passed = []
	pending_node = ""
	pending_type = ""
	pending_battle = ""
	clear_squads()

func _clear_run() -> void:
	biomass = 0
	_clear_last_battle()
	bought_talents = []
	army = []
	_next_zid = 0

# Узел, ради которого открыта под-сцена (бой/событие/стоянка), пройден → назад на карту.
func finish_node() -> void:
	if pending_node != "":
		go_to(pending_node)
	pending_node = ""
	pending_type = ""
	pending_battle = ""
	_clear_last_battle()
	get_tree().change_scene_to_file(Scenes.MAP)

func _clear_last_battle() -> void:
	last_corpses = 0
	last_reward = 0
	last_fled = 0
	last_lost = 0

# «Начать заново» с экранов финала/поражения
func restart_run() -> void:
	reset()
	get_tree().change_scene_to_file(Scenes.MAP)

# ── Армия ────────────────────────────────────────────────────────

# Данные типа зомби (неизвестный тип → обычный)
func ztype(type: String) -> Dictionary:
	return ZTYPE.get(type, ZTYPE["normal"])

# Имя типа по-русски, строчными («обычный»)
func ztype_name(type: String) -> String:
	return ZTYPE[type].name if ZTYPE.has(type) else type

func add_zombie(type: String) -> Dictionary:
	var t := ztype(type)
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

# Суммарный вес армии (бюджет стартовой армии): normal 1, runner 2, fat 3.
func get_army_weight() -> int:
	var w := 0
	for z in army:
		w += int(ztype(z.type).weight)
	return w

# ── Отряды ───────────────────────────────────────────────────────

func clear_squads() -> void:
	squads = []
	for i in squad_limit():
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
	return int(ztype(z.type).weight)

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
	if squad_weight(idx) + zombie_weight(zid) > squad_cap():
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

# ── Таланты ──────────────────────────────────────────────────────

func has_talent(id: String) -> bool:
	return bought_talents.has(id)

func _bought_in_branch(branch: String) -> int:
	var n := 0
	for tid in bought_talents:
		if TalentDB.by_id(tid).get("branch", "") == branch:
			n += 1
	return n

# Цена таланта = цена следующей покупки в его ветке (10 → 20 → 30 …)
func talent_cost(id: String) -> int:
	var t := TalentDB.by_id(id)
	if t.is_empty():
		return 999999
	return TalentDB.next_cost(_bought_in_branch(t.branch))

func can_buy_talent(id: String) -> bool:
	return not has_talent(id) and not TalentDB.by_id(id).is_empty() and biomass >= talent_cost(id)

func buy_talent(id: String) -> bool:
	if not can_buy_talent(id):
		return false
	biomass -= talent_cost(id)
	bought_talents.append(id)
	_recompute_army_max_hp()
	return true

# --- эффекты талантов ---

# Прибавка к стату (max_hp / speed / bite_damage) для типа зомби
func talent_stat_add(ztype: String, key: String) -> int:
	var total := 0
	for tid in bought_talents:
		var e = TalentDB.by_id(tid).get("effect", {})
		if e.get("kind") == "stat" and e.get("ztype") == ztype and e.get("key") == key:
			total += int(e.get("add", 0))
	return total

func _has_rule(rule: String) -> bool:
	for tid in bought_talents:
		if TalentDB.by_id(tid).get("effect", {}).get("rule", "") == rule:
			return true
	return false

func squad_cap() -> int:
	return SQUAD_CAP + (1 if _has_rule("slot") else 0)

func squad_limit() -> int:
	return MAX_SQUADS + (1 if _has_rule("squad") else 0)

func biomass_mult() -> float:
	return 1.25 if _has_rule("biomass_mult") else 1.0

# Множитель урона по окнам и костру в бою для типа (талант «Таран» у толстяков)
func door_mult(ztype: String) -> float:
	return 2.0 if ztype == "fat" and _has_rule("door_mult") else 1.0

func upgrades_unlocked() -> bool:
	return _has_rule("upgrade")

# Купили талант на +max_hp — сразу поднимаем максимум и текущее HP в армии
func _recompute_army_max_hp() -> void:
	for z in army:
		var base_max: int = ztype(z.type).max_hp
		var new_max: int = base_max + talent_stat_add(z.type, "max_hp")
		var delta: int = new_max - z.max_hp
		z.max_hp = new_max
		if delta > 0:
			z.hp += delta
