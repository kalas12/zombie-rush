extends Control

# Экран древа талантов (Фаза 3, Шаг 8). 4 ветки-колонки, покупка за биомассу.
# Купленные таланты — в GameState.bought_talents (сброс в begin_run).
# Разметка строится кодом. Открывается кнопкой «Таланты» с карты.

const TalentDB = preload("res://scripts/data/talents.gd")
const UI = preload("res://scripts/ui.gd")
const Scenes = preload("res://scripts/scenes.gd")

var _biomass_label: Label
var _body: HBoxContainer

func _ready() -> void:
	_biomass_label = UI.label("", 20, UI.GOOD)
	var vb := UI.page(self, "Таланты", 24, _biomass_label, get_tree().change_scene_to_file.bind(Scenes.MAP))

	# тело: 4 колонки
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(_body)

	_rebuild()

func _rebuild() -> void:
	_biomass_label.text = "Биомасса: %d" % GameState.biomass

	UI.clear(_body)

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
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # иначе картинка встаёт в свой исходный размер (~500 px)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hdr.add_child(tr)
	hdr.add_child(UI.label("%s   (след. %d)" % [
		TalentDB.BRANCH_RU.get(branch, branch), TalentDB.next_cost(GameState._bought_in_branch(branch))
	], 18))
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
		b.add_theme_color_override("font_color", UI.GOOD)
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
