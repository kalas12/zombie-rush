extends Control

# Экран поражения (Фаза 3). Забег окончен — кнопка «Начать заново».
# GameState ещё не сброшен: показываем итог, сбрасываем по кнопке.

func _ready() -> void:
	var reached: String = GameState.current_node if GameState.current_node != "" else "?"

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1013")
	sb.border_color = Color("4a2630")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Орда разбита"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("ff5a5a"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var body := Label.new()
	body.text = "Забег окончен.\nДошёл до узла %s   ·   было %d зомби   ·   биомасса %d" % [
		reached, GameState.army.size(), GameState.biomass
	]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(460, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color("e7ecf3"))
	vb.add_child(body)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	vb.add_child(gap)

	var b := Button.new()
	b.text = "Начать заново"
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(_on_restart)
	vb.add_child(b)

func _on_restart() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")
