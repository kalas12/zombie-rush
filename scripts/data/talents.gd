extends RefCounted
# Каталог талантов (Фаза 3, Шаг 8). Подключается: const TalentDB = preload("res://scripts/data/talents.gd")
# Цена в ветке растёт: N-я покупка в ветке стоит 10*N (10 → 20 → 30 …).
# Числа эффектов — черновые, калибруются плейтестом.
# Купленные таланты живут в GameState.bought_talents (сбрасываются в start_run).

const COST_STEP := 10

# effect.kind:
#   "stat" — прибавка к стату зомби типа ztype: key ∈ max_hp/speed/bite_damage, add
#   "rule" — правило: rule ∈ slot / squad / biomass_mult / door_mult / upgrade
const TALENTS := [
	# ── ветка normal ────────────────────────────────
	{ "id": "n_hp",  "branch": "normal", "name": "Крепкие обычные",
	  "desc": "Обычным зомби +10 к макс. HP",
	  "effect": { "kind": "stat", "ztype": "normal", "key": "max_hp", "add": 10 } },
	{ "id": "n_dmg", "branch": "normal", "name": "Злые обычные",
	  "desc": "Обычным зомби +3 к урону укуса",
	  "effect": { "kind": "stat", "ztype": "normal", "key": "bite_damage", "add": 3 } },

	# ── ветка runner ────────────────────────────────
	{ "id": "r_spd", "branch": "runner", "name": "Стремительность",
	  "desc": "Бегунам +30 к скорости",
	  "effect": { "kind": "stat", "ztype": "runner", "key": "speed", "add": 30 } },
	{ "id": "r_dmg", "branch": "runner", "name": "Острые клыки",
	  "desc": "Бегунам +3 к урону укуса",
	  "effect": { "kind": "stat", "ztype": "runner", "key": "bite_damage", "add": 3 } },

	# ── ветка fat ───────────────────────────────────
	{ "id": "f_hp",   "branch": "fat", "name": "Толстая шкура",
	  "desc": "Толстякам +40 к макс. HP",
	  "effect": { "kind": "stat", "ztype": "fat", "key": "max_hp", "add": 40 } },
	{ "id": "f_wall", "branch": "fat", "name": "Таран",
	  "desc": "Толстяки ломают двери в 2 раза быстрее",
	  "effect": { "kind": "rule", "rule": "door_mult" } },

	# ── ветка general ───────────────────────────────
	{ "id": "g_slot",    "branch": "general", "name": "Больше места",
	  "desc": "+1 слот в каждом отряде",
	  "effect": { "kind": "rule", "rule": "slot" } },
	{ "id": "g_squad",   "branch": "general", "name": "Лишний отряд",
	  "desc": "+1 отряд",
	  "effect": { "kind": "rule", "rule": "squad" } },
	{ "id": "g_bio",     "branch": "general", "name": "Пожиратели",
	  "desc": "+25% биомассы за бой",
	  "effect": { "kind": "rule", "rule": "biomass_mult" } },
	{ "id": "g_upgrade", "branch": "general", "name": "Мутаген",
	  "desc": "Разблокирует апгрейд зомби (обычный → бегун / толстяк)",
	  "effect": { "kind": "rule", "rule": "upgrade" } },
]

const BRANCHES := ["normal", "runner", "fat", "general"]
const BRANCH_RU := {
	"normal": "Обычные", "runner": "Бегуны", "fat": "Толстяки", "general": "Общие",
}

static func by_id(id: String) -> Dictionary:
	for t in TALENTS:
		if t.id == id:
			return t
	return {}

static func in_branch(branch: String) -> Array:
	var out := []
	for t in TALENTS:
		if t.branch == branch:
			out.append(t)
	return out

# Цена следующей покупки в ветке (сколько уже куплено в ней)
static func next_cost(bought_in_branch: int) -> int:
	return COST_STEP * (bought_in_branch + 1)
