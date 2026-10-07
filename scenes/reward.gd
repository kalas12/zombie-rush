extends Control

# Экран награды после победы (Фаза 3, Шаг 6). Выбор одного варианта.
# Трупы = убитые защитники; сбежавшие трупов не дают.
# Бой (scenes/battle/battle.gd) уже начислил биомассу и уладил потери/раны армии.
# Лут (Шаг 9) добавим сюда же вариантом. Разметка строится кодом.

const UI = preload("res://scripts/ui.gd")

var _choices: VBoxContainer
var _status: Label

func _ready() -> void:
	var vb := UI.card(self, 580, 30, 14)
	vb.add_child(UI.title("Победа!   +%d биомассы" % GameState.last_reward))
	vb.add_child(UI.body("Убито людей (трупов): %d   ·   Сбежало: %d   ·   Своих погибло: %d" % [
		GameState.last_corpses, GameState.last_fled, GameState.last_lost
	], 520))
	_status = UI.label("", 0, UI.MUTED)
	vb.add_child(_status)
	vb.add_child(UI.gap(8))

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	vb.add_child(_choices)

	_show_main()

func _refresh_status() -> void:
	_status.text = "Армия: %d зомби   ·   Биомасса: %d" % [GameState.army.size(), GameState.biomass]

# --- главный список ---

func _show_main() -> void:
	_refresh_status()
	UI.clear(_choices)
	var has_corpses: bool = GameState.last_corpses > 0

	var rb := _btn("Поднять зомби из трупов: +%d обычных в армию" % GameState.last_corpses, _pick_raise)
	rb.disabled = not has_corpses

	_btn("Лечить одного зомби  (+%d HP)" % Config.REWARD_HEAL, _show_heal_pick)

	var cb := _btn("Трупы в биомассу: +%d" % (GameState.last_corpses * Config.REWARD_CORPSE_BIO), _pick_corpses)
	cb.disabled = not has_corpses

	var sb := _btn("Жертва: убрать одного зомби, +%d HP остальным" % Config.REWARD_SACRIFICE_HEAL, _show_sacrifice_pick)
	sb.disabled = GameState.army.size() <= 1

	_btn("Пропустить", _done)

# --- подэкран: выбрать кого лечить ---

func _show_heal_pick() -> void:
	UI.clear(_choices)
	_btn("← назад", _show_main)
	var any := false
	for z in GameState.army:
		var wounded: bool = z.hp < z.max_hp
		var b := _btn("%s   HP %d/%d%s" % [
				GameState.ztype_name(z.type), z.hp, z.max_hp,
				"   → +%d" % mini(Config.REWARD_HEAL, z.max_hp - z.hp) if wounded else "   (полное)"
			],
			_pick_heal.bind(z.id))
		b.disabled = not wounded
		any = any or wounded
	if not any:
		_btn("(все зомби здоровы — назад)", _show_main)

# --- подэкран: выбрать кого принести в жертву ---

func _show_sacrifice_pick() -> void:
	UI.clear(_choices)
	_btn("← назад", _show_main)
	for z in GameState.army:
		_btn("Пожертвовать: %s   HP %d/%d" % [GameState.ztype_name(z.type), z.hp, z.max_hp],
			_pick_sacrifice.bind(z.id))

# --- применение ---

# Каждый труп — новый обычный зомби (полное HP, в резерв)
func _pick_raise() -> void:
	for i in GameState.last_corpses:
		GameState.add_zombie("normal")
	_done()

func _pick_heal(zid: int) -> void:
	GameState.heal_zombie(zid, Config.REWARD_HEAL)
	_done()

func _pick_sacrifice(zid: int) -> void:
	GameState.remove_zombie(zid)
	for z in GameState.army:
		GameState.heal_zombie(z.id, Config.REWARD_SACRIFICE_HEAL)
	_done()

func _pick_corpses() -> void:
	GameState.biomass += GameState.last_corpses * Config.REWARD_CORPSE_BIO
	_done()

func _done() -> void:
	GameState.finish_node()   # узел боя пройден

# Кнопка-вариант в список выбора
func _btn(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_choices.add_child(b)
	return b
