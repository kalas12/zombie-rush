extends Control

# Узлы-стоянки: находка (loot) и лагерь (camp). Заглушки Фазы 2.
# loot даёт биомассу (реальный счётчик), camp — пока без эффекта (лечить нечего до армии).
# Разметка строится кодом. Полное наполнение (лечение/апгрейд/риск) — Фаза 4.

const LOOT_BIOMASS := 5

func _ready() -> void:
	var kind: String = GameState.pending_type
	var title := "Стоянка"
	var text := "Тихое место у ручья. Орда переводит дух."
	var btn := "Дальше"
	var gain := 0
	if kind == "loot":
		title = "Находка"
		text = "В подлеске — брошенный тайник охотников."
		btn = "Забрать  (+%d биомассы)" % LOOT_BIOMASS
		gain = LOOT_BIOMASS

	_build_ui(title, text, btn, gain)

func _build_ui(title_text: String, body_text: String, btn_text: String, gain: int) -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("141a26")
	sb.border_color = Color("26314a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color("ff8a3d"))
	vb.add_child(t)

	var b := Label.new()
	b.text = body_text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(500, 0)
	b.add_theme_color_override("font_color", Color("e7ecf3"))
	vb.add_child(b)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	vb.add_child(gap)

	var go := Button.new()
	go.text = btn_text
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(_on_go.bind(gain))
	vb.add_child(go)

func _on_go(gain: int) -> void:
	GameState.biomass += gain
	if GameState.pending_node != "":
		GameState.go_to(GameState.pending_node)
		GameState.pending_node = ""
	GameState.pending_type = ""
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")
