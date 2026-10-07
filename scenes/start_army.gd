extends Control

# Экран набора стартовой армии (Фаза 3, Шаг 4).
# Тратишь бюджет веса (GameState.START_WEIGHT) на типы зомби. → "Начать забег".
# Разметка строится кодом. Открывается автоматически из forest_map при новом забеге.

const UI = preload("res://scripts/ui.gd")
const Scenes = preload("res://scripts/scenes.gd")

const PICKABLE := ["normal", "runner", "fat"]

var _picks: Array[String] = []
var _budget_label: Label
var _list: VBoxContainer
var _start_btn: Button

func _ready() -> void:
	var vb := UI.card(self, 560, 30, 12)
	vb.add_child(UI.title("Стартовая армия"))
	_budget_label = UI.label("", 0, UI.MUTED)
	vb.add_child(_budget_label)

	# кнопки добавления
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 8)
	vb.add_child(add_row)
	for type in PICKABLE:
		add_row.add_child(UI.button("+ %s (вес %d)" % [_name(type), _weight(type)], _add.bind(type)))

	vb.add_child(UI.gap(6))

	# список набранных
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vb.add_child(_list)

	vb.add_child(UI.gap(8))

	_start_btn = UI.button("Начать забег →", _begin, 18)
	vb.add_child(_start_btn)

	_refresh()

func _name(type: String) -> String:
	return GameState.ztype_name(type).capitalize()   # «Обычный»

func _weight(type: String) -> int:
	return int(GameState.ztype(type).weight)

func _used_weight() -> int:
	var w := 0
	for type in _picks:
		w += _weight(type)
	return w

func _refresh() -> void:
	var used := _used_weight()
	_budget_label.text = "Вес: %d / %d" % [used, GameState.START_WEIGHT]

	UI.clear(_list)
	if _picks.is_empty():
		_list.add_child(UI.label("— пусто —  (добавь зомби кнопками выше)", 0, UI.MUTED))
	for i in _picks.size():
		var type: String = _picks[i]
		var b := UI.button("%s   (вес %d)   ✕ убрать" % [_name(type), _weight(type)], _remove.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)

	_start_btn.disabled = _picks.is_empty()

func _add(type: String) -> void:
	if _used_weight() + _weight(type) <= GameState.START_WEIGHT:
		_picks.append(type)
		_refresh()

func _remove(idx: int) -> void:
	if idx >= 0 and idx < _picks.size():
		_picks.remove_at(idx)
		_refresh()

func _begin() -> void:
	GameState.begin_run("n0", _picks)
	get_tree().change_scene_to_file(Scenes.MAP)
