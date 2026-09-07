extends Control

# Экран формирования отрядов (Фаза 3, Шаг 2).
# Слева резерв армии, справа 5 отрядов (вместимость по весу = 5).
# Клик по резервному зомби → в выбранный отряд. Клик по бойцу отряда → назад в резерв.
# Пока без связи с боем — это Шаг 3. Разметка строится кодом.

const TYPE_RU := { "normal": "обычный", "runner": "бегун", "fat": "толстяк" }

var _selected_squad := 0
var _body: HBoxContainer
var _header_count: Label

func _ready() -> void:
	_autofill_if_empty()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	# --- шапка ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)

	var title := Label.new()
	title.text = "Отряды"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ff8a3d"))
	head.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	_header_count = Label.new()
	_header_count.add_theme_font_size_override("font_size", 18)
	_header_count.add_theme_color_override("font_color", Color("8a93a3"))
	head.add_child(_header_count)

	var back := Button.new()
	back.text = "← Карта"
	back.pressed.connect(_on_back)
	head.add_child(back)

	# --- тело: резерв | отряды ---
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 24)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_body)

	_refresh()

# --- перерисовка ---

func _refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	_header_count.text = "В отрядах: %d / %d зомби" % [GameState.deployed_count(), GameState.army.size()]

	# резерв
	var reserve_box := _column("Резерв")
	var res: Array = GameState.reserve()
	if res.is_empty():
		reserve_box.add_child(_muted("— пусто —"))
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
			i + 1, GameState.squad_weight(i), GameState.SQUAD_CAP,
			"   ◄ выбран" if i == _selected_squad else ""
		]
		hdr.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == _selected_squad:
			hdr.add_theme_color_override("font_color", Color("ff8a3d"))
		hdr.pressed.connect(_select_squad.bind(i))
		box.add_child(hdr)

		if GameState.squads[i].is_empty():
			box.add_child(_muted("    (пусто)"))
		for zid in GameState.squads[i]:
			var z: Dictionary = GameState.zombie_by_id(zid)
			if not z.is_empty():
				box.add_child(_zombie_button(z, false))

func _column(caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(280, 0)
	_body.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 18)
	cap.add_theme_color_override("font_color", Color("e7ecf3"))
	col.add_child(cap)
	return col

func _zombie_button(z: Dictionary, in_reserve: bool) -> Button:
	var b := Button.new()
	var name_ru: String = TYPE_RU.get(z.type, z.type)
	b.text = "%s  ·  HP %d/%d  ·  вес %d" % [
		name_ru, z.hp, z.max_hp, GameState.zombie_weight(z.id)
	]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if in_reserve:
		b.pressed.connect(_assign.bind(z.id))
	else:
		b.pressed.connect(_unassign.bind(z.id))
	return b

func _muted(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("8a93a3"))
	return l

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

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")

# Если отряды пустые — разложить всю армию по отрядам (по весу до SQUAD_CAP).
# Игрок дальше переставляет как хочет.
func _autofill_if_empty() -> void:
	if GameState.deployed_count() > 0:
		return
	var idx := 0
	for z in GameState.army:
		while idx < GameState.MAX_SQUADS and not GameState.add_to_squad(z.id, idx):
			idx += 1
		if idx >= GameState.MAX_SQUADS:
			break
