extends Control

# Экран события-вопроса (Фаза 2). Текст ситуации + 2-3 кнопки выбора.
# По одному захардкоженному событию на узел карты (id из GameState.pending_node).
# Исходы пока текст-заглушки — реальные эффекты (лут / армия) в Фазе 3.
# Разметка строится кодом.

const EVENTS := {
	"n3": {
		"title": "Брошенный лагерь охотников",
		"text": "Кострище ещё тёплое, вокруг рюкзаки и ящики. Быстрый обыск даст припасы, но охотники ставят капканы.",
		"choices": [
			{ "label": "Обыскать лагерь", "outcome": "Нашёл припасы (+лут в Фазе 3). Один зомби попал в капкан." },
			{ "label": "Пройти мимо", "outcome": "Идёшь дальше, не рискуя." },
		],
	},
	"n8": {
		"title": "Свежий труп",
		"text": "У тропы лежит убитый человек — не твоя работа. Тело целое.",
		"choices": [
			{ "label": "Поднять зомби", "outcome": "Поднял слабого зомби в армию (+юнит в Фазе 3)." },
			{ "label": "Оставить", "outcome": "Оставил труп гнить." },
		],
	},
	"n11": {
		"title": "Костёр-ритуал",
		"text": "Древние камни, чёрное пятно старого огня. Орда чует силу этого места.",
		"choices": [
			{ "label": "Пожертвовать зомби", "outcome": "Один зомби сгорел — остальные усилены (Фаза 3)." },
			{ "label": "Уйти", "outcome": "Не трогаешь камни." },
		],
	},
}

const FALLBACK_ID := "n3"   # если сцену открыли не с карты (F6)

func _ready() -> void:
	var eid: String = GameState.pending_node
	if not EVENTS.has(eid):
		eid = FALLBACK_ID
	_build_ui(EVENTS[eid])

func _build_ui(ev) -> void:
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
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var title := Label.new()
	title.text = ev.title
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ff8a3d"))
	vb.add_child(title)

	var body := Label.new()
	body.text = ev.text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_color_override("font_color", Color("e7ecf3"))
	vb.add_child(body)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	vb.add_child(gap)

	for c in ev.choices:
		var b := Button.new()
		b.text = c.label
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_on_choice.bind(c.outcome))
		vb.add_child(b)

func _on_choice(outcome: String) -> void:
	print("[event] ", outcome)
	if GameState.pending_node != "":
		GameState.go_to(GameState.pending_node)
		GameState.pending_node = ""
	GameState.pending_type = ""
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")
