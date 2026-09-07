extends Control

# Экран награды после победы (Фаза 3, Шаг 6). Выбор одного варианта.
# arena.gd уже начислила базовую биомассу и уладила потери/раны армии.
# Лут (Шаг 9) добавим сюда же вариантом. Разметка строится кодом.

const TYPE_RU := { "normal": "обычный", "runner": "бегун", "fat": "толстяк" }

var _choices: VBoxContainer
var _status: Label

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("141a26")
	sb.border_color = Color("26314a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(30)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(580, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Победа!   +%d биомассы" % GameState.last_reward
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ff8a3d"))
	vb.add_child(title)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("8a93a3"))
	vb.add_child(_status)

	vb.add_child(_gap(8))

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	vb.add_child(_choices)

	_show_main()

func _refresh_status() -> void:
	_status.text = "Армия: %d зомби   ·   Биомасса: %d   ·   Трупов: %d" % [
		GameState.army.size(), GameState.biomass, GameState.last_corpses
	]

func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()

# --- главный список ---

func _show_main() -> void:
	_refresh_status()
	_clear_choices()
	var has_corpses: bool = GameState.last_corpses > 0

	var rb := _btn("Поднять зомби из трупа: +1 обычный в армию", _pick_raise)
	rb.disabled = not has_corpses

	_btn("Лечить одного зомби  (+%d HP)" % Config.REWARD_HEAL, _show_heal_pick)

	var cb := _btn("Трупы в биомассу: +%d" % (GameState.last_corpses * Config.REWARD_CORPSE_BIO), _pick_corpses)
	cb.disabled = not has_corpses

	var sb := _btn("Жертва: убрать одного зомби, +%d HP остальным" % Config.REWARD_SACRIFICE_HEAL, _show_sacrifice_pick)
	sb.disabled = GameState.army.size() <= 1

	_btn("Пропустить", _done)

# --- подэкран: выбрать кого лечить ---

func _show_heal_pick() -> void:
	_clear_choices()
	_btn("← назад", _show_main)
	var any := false
	for z in GameState.army:
		var wounded: bool = z.hp < z.max_hp
		var b := _btn("%s   HP %d/%d%s" % [
				TYPE_RU.get(z.type, z.type), z.hp, z.max_hp,
				"   → +%d" % mini(Config.REWARD_HEAL, z.max_hp - z.hp) if wounded else "   (полное)"
			],
			_pick_heal.bind(z.id))
		b.disabled = not wounded
		any = any or wounded
	if not any:
		_btn("(все зомби здоровы — назад)", _show_main)

# --- подэкран: выбрать кого принести в жертву ---

func _show_sacrifice_pick() -> void:
	_clear_choices()
	_btn("← назад", _show_main)
	for z in GameState.army:
		_btn("Пожертвовать: %s   HP %d/%d" % [TYPE_RU.get(z.type, z.type), z.hp, z.max_hp],
			_pick_sacrifice.bind(z.id))

# --- применение ---

func _pick_raise() -> void:
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
	if GameState.pending_node != "":
		GameState.go_to(GameState.pending_node)   # узел боя пройден
	GameState.pending_node = ""
	GameState.pending_type = ""
	GameState.last_corpses = 0
	GameState.last_reward = 0
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")

# --- утилиты ---

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	_choices.add_child(b)
	return b

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
