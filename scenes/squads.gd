extends Control

# Экран формирования отрядов (Фаза 3, Шаг 2).
# Слева резерв армии, справа 5 отрядов (вместимость по весу = 5).
# Клик по резервному зомби → в выбранный отряд. Клик по бойцу отряда → назад в резерв.
# Пока без связи с боем — это Шаг 3. Разметка строится кодом.

const UI = preload("res://scripts/ui.gd")
const Scenes = preload("res://scripts/scenes.gd")

var _selected_squad := 0
var _body: HBoxContainer
var _header_count: Label

func _ready() -> void:
	_autofill_if_empty()

	_header_count = UI.label("", 18, UI.MUTED)
	var vb := UI.page(self, "Отряды", 28, _header_count, get_tree().change_scene_to_file.bind(Scenes.MAP))

	# --- тело: резерв | отряды ---
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 24)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_body)

	_refresh()

# --- перерисовка ---

func _refresh() -> void:
	UI.clear(_body)

	_header_count.text = "В отрядах: %d / %d зомби" % [GameState.deployed_count(), GameState.army.size()]

	# резерв
	var reserve_box := _column("Резерв")
	var res: Array = GameState.reserve()
	if res.is_empty():
		reserve_box.add_child(UI.label("— пусто —", 0, UI.MUTED))
	for z in res:
		reserve_box.add_child(_zombie_button(z, true))

	# 5 отрядов
	var squads_col := VBoxContainer.new()
	squads_col.add_theme_constant_override("separation", 10)
	squads_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(squads_col)

	for i in GameState.squads.size():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		squads_col.add_child(box)

		var hdr := Button.new()
		hdr.text = "Отряд %d   —   вес %d / %d%s" % [
			i + 1, GameState.squad_weight(i), GameState.squad_cap(),
			"   ◄ выбран" if i == _selected_squad else ""
		]
		hdr.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == _selected_squad:
			hdr.add_theme_color_override("font_color", UI.TITLE)
		hdr.pressed.connect(_select_squad.bind(i))
		box.add_child(hdr)

		if GameState.squads[i].is_empty():
			box.add_child(UI.label("    (пусто)", 0, UI.MUTED))
		for zid in GameState.squads[i]:
			var z: Dictionary = GameState.zombie_by_id(zid)
			if not z.is_empty():
				box.add_child(_zombie_button(z, false))

func _column(caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(280, 0)
	_body.add_child(col)
	col.add_child(UI.label(caption, 18))
	return col

func _zombie_button(z: Dictionary, in_reserve: bool) -> Button:
	var b := Button.new()
	b.text = "%s  ·  HP %d/%d  ·  вес %d" % [
		GameState.ztype_name(z.type), z.hp, z.max_hp, GameState.zombie_weight(z.id)
	]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if in_reserve:
		b.pressed.connect(_assign.bind(z.id))
	else:
		b.pressed.connect(_unassign.bind(z.id))
	return b

# --- действия ---

func _select_squad(i: int) -> void:
	_selected_squad = i
	_refresh()

func _assign(zid: int) -> void:
	GameState.add_to_squad(zid, _selected_squad)   # молча игнорит, если не влезло
	_refresh()

func _unassign(zid: int) -> void:
	GameState.remove_from_squad(zid)
	_refresh()

# Если отряды пустые — разложить всю армию по отрядам (по весу до SQUAD_CAP).
# Игрок дальше переставляет как хочет.
func _autofill_if_empty() -> void:
	if GameState.deployed_count() > 0:
		return
	var idx := 0
	var limit := GameState.squad_limit()
	for z in GameState.army:
		while idx < limit and not GameState.add_to_squad(z.id, idx):
			idx += 1
		if idx >= limit:
			break
