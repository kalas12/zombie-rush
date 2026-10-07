extends Control

# Экран древа талантов (Фаза 3, Шаг 8). 4 ветки-колонки, покупка за биомассу.
# Купленные таланты — в GameState.bought_talents (сброс в start_run).
# Разметка строится кодом. Открывается кнопкой «Таланты» с карты.

const TalentDB = preload("res://scripts/data/talents.gd")

var _biomass_label: Label
var _body: HBoxContainer

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 24)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	# шапка
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)

	var title := Label.new()
	title.text = "Таланты"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ff8a3d"))
	head.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	_biomass_label = Label.new()
	_biomass_label.add_theme_font_size_override("font_size", 20)
	_biomass_label.add_theme_color_override("font_color", Color("86c541"))
	head.add_child(_biomass_label)

	var back := Button.new()
	back.text = "← Карта"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/forest_map.tscn"))
	head.add_child(back)

	# тело: 4 колонки
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_body)

	_rebuild()

func _rebuild() -> void:
	_biomass_label.text = "Биомасса: %d" % GameState.biomass

	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()

	for branch in TalentDB.BRANCHES:
		_body.add_child(_branch_column(branch))

func _branch_column(branch: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# заголовок ветки: иконка + имя
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	var icon_path := "res://assets/ui/talent_%s.png" % branch
	if ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.texture = load(icon_path)
		tr.custom_minimum_size = Vector2(40, 40)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr.add_child(tr)
	var name_l := Label.new()
	name_l.text = "%s   (след. %d)" % [TalentDB.BRANCH_RU.get(branch, branch), TalentDB.next_cost(GameState._bought_in_branch(branch))]
	name_l.add_theme_font_size_override("font_size", 18)
	name_l.add_theme_color_override("font_color", Color("e7ecf3"))
	hdr.add_child(name_l)
	col.add_child(hdr)

	for t in TalentDB.in_branch(branch):
		col.add_child(_talent_button(t))
	return col

func _talent_button(t: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 84)
	b.add_theme_font_size_override("font_size", 13)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bought: bool = GameState.has_talent(t.id)
	var cost: int = GameState.talent_cost(t.id)
	var tail := ""
	if bought:
		tail = "✓ куплено"
		b.disabled = true
		b.add_theme_color_override("font_color", Color("86c541"))
	elif GameState.biomass >= cost:
		tail = "Купить за %d" % cost
	else:
		tail = "Нужно %d биомассы" % cost
		b.disabled = true

	b.text = "%s\n%s\n%s" % [t.name, t.desc, tail]
	if not bought:
		b.pressed.connect(func():
			if GameState.buy_talent(t.id):
				_rebuild())
	return b
