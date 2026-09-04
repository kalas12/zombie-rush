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

# --- Персистентная армия зомби (Фаза 3, Шаг 1) ---
# Каждый зомби — словарь: { id, type, hp, max_hp, loot }
# Типы и числа — из «04 — Content» (вес = сколько места в отряде).
const ZTYPE := {
	"normal": { "max_hp": 30, "weight": 1 },   # обычный
	"runner": { "max_hp": 18, "weight": 2 },   # бегун
	"fat":    { "max_hp": 90, "weight": 3 },   # толстяк
}
const START_ARMY := { "normal": 5 }            # стартовый состав забега

var army: Array[Dictionary] = []
var _next_zid := 0                             # счётчик уникальных id зомби

# ── Забег ────────────────────────────────────────────────────────

# Начать забег: старт-узел + свежая армия + биомасса 0.
func start_run(start_id: String) -> void:
	current_node = start_id
	passed = [start_id]
	biomass = 0
	army = []
	_next_zid = 0
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
	army = []
	_next_zid = 0

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
