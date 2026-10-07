extends CanvasLayer
# HUD боя: нижняя чёрная полоса на всю ширину — слева выбор, кого ставить («тип × сколько»,
# только при выставлении), справа «Скип → победа» (только отладочная сборка) и «В бой» /
# «Закончить ход N/12». В конце боя — окно итога с кнопкой «Продолжить».
# Только показывает (set_view) и шлёт сигналы — решает battle.gd.

signal action_pressed            # «В бой» / «Закончить ход»
signal skip_pressed              # дев-кнопка «Скип → победа»
signal type_picked(type: String) # выбран тип зомби для выставления
signal continue_pressed          # «Продолжить» в окне итога

const UI = preload("res://scripts/ui.gd")
const BC = preload("res://scripts/battle/battle_config.gd")

var _deploy_row: HBoxContainer
var _deploy_btns := {}           # тип → Button
var _action: Button
var _skip: Button
var _result: Control

func _init() -> void:
	layer = 4

# types — типы зомби, которые есть в резерве (кнопки выставления)
func build(types: Array) -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("07090d")
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BC.BAR_HEIGHT

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	_deploy_row = HBoxContainer.new()
	_deploy_row.add_theme_constant_override("separation", 8)
	_deploy_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_deploy_row)
	var group := ButtonGroup.new()
	for type in types:
		var b := _button("", type_picked.emit.bind(type), 20)
		b.toggle_mode = true
		b.button_group = group
		b.icon = load(GameState.ztype(type).texture)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(200, 0)
		_deploy_row.add_child(b)
		_deploy_btns[type] = b

	_skip = _button("Скип → победа", skip_pressed.emit, 16)   # видимость — в set_view
	row.add_child(_skip)
	_action = _button("В бой", action_pressed.emit, 22)
	_action.custom_minimum_size = Vector2(260, 0)
	row.add_child(_action)

	_result = Control.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	add_child(_result)

# Кнопки без фокуса — чтобы Tab не уходил в переключение фокуса интерфейса
func _button(text: String, cb: Callable, font := 0) -> Button:
	var b := UI.button(text, cb, font)
	b.focus_mode = Control.FOCUS_NONE
	return b

# v: deploying, busy, action_visible, action_enabled (bool); action_text;
#    counts { тип: сколько в резерве }; picked (тип)
func set_view(v: Dictionary) -> void:
	_deploy_row.modulate.a = 1.0 if v.deploying else 0.0   # место в полосе остаётся, кнопки прячем
	for type in _deploy_btns:
		var n: int = v.counts.get(type, 0)
		_deploy_btns[type].text = "%s × %d" % [GameState.ztype_name(type).capitalize(), n]
		_deploy_btns[type].disabled = n == 0 or not v.deploying
		_deploy_btns[type].set_pressed_no_signal(type == v.picked)
	_action.visible = v.action_visible
	_skip.visible = v.action_visible and OS.is_debug_build()
	_action.disabled = v.busy or not v.action_enabled
	_action.text = v.action_text

# Окно итога боя
func show_result(title: String, body: String) -> void:
	_result.visible = true
	var vb := UI.card(_result, 440, 28, 14)
	vb.add_child(UI.title(title, 26, UI.TITLE, true))
	vb.add_child(UI.body(body, 380, true))
	vb.add_child(_button("Продолжить", continue_pressed.emit, 20))
