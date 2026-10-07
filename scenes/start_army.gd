extends Control

# Экран набора стартовой армии (Фаза 3, Шаг 4).
# Тратишь бюджет веса (GameState.START_WEIGHT) на типы зомби. → "Начать забег".
# Разметка строится кодом. Открывается автоматически из forest_map при новом забеге.

const TYPE_RU := { "normal": "Обычный", "runner": "Бегун", "fat": "Толстяк" }
const PICKABLE := ["normal", "runner", "fat"]

var _picks: Array[String] = []
var _budget_label: Label
var _list: VBoxContainer
var _start_btn: Button

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
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Стартовая армия"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ff8a3d"))
	vb.add_child(title)

	_budget_label = Label.new()
	_budget_label.add_theme_color_override("font_color", Color("8a93a3"))
	vb.add_child(_budget_label)

	# кнопки добавления
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	vb.add_child(add_row)
	for type in PICKABLE:
		var w: int = GameState.ZTYPE[type].weight
		var b := Button.new()
		b.text = "+ %s (вес %d)" % [TYPE_RU[type], w]
		b.pressed.connect(_add.bind(type))
		add_row.add_child(b)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	vb.add_child(gap)

	# список набранных
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vb.add_child(_list)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	vb.add_child(gap2)

	_start_btn = Button.new()
	_start_btn.text = "Начать забег →"
	_start_btn.add_theme_font_size_override("font_size", 18)
	_start_btn.pressed.connect(_begin)
	vb.add_child(_start_btn)

	_refresh()

func _used_weight() -> int:
	var w := 0
	for type in _picks:
		w += int(GameState.ZTYPE[type].weight)
	return w

func _refresh() -> void:
	var used := _used_weight()
	_budget_label.text = "Вес: %d / %d" % [used, GameState.START_WEIGHT]

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	if _picks.is_empty():
		var l := Label.new()
		l.text = "— пусто —  (добавь зомби кнопками выше)"
		l.add_theme_color_override("font_color", Color("8a93a3"))
		_list.add_child(l)
	for i in _picks.size():
		var type: String = _picks[i]
		var b := Button.new()
		b.text = "%s   (вес %d)   ✕ убрать" % [TYPE_RU[type], int(GameState.ZTYPE[type].weight)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_remove.bind(i))
		_list.add_child(b)

	_start_btn.disabled = _picks.is_empty()

func _add(type: String) -> void:
	if _used_weight() + int(GameState.ZTYPE[type].weight) <= GameState.START_WEIGHT:
		_picks.append(type)
		_refresh()

func _remove(idx: int) -> void:
	if idx >= 0 and idx < _picks.size():
		_picks.remove_at(idx)
		_refresh()

func _begin() -> void:
	GameState.begin_run("n0", _picks)
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")
