extends RefCounted
# Общие кирпичики UI: палитра и сборка типовых элементов. Все экраны строят разметку кодом.
# Подключение: const UI = preload("res://scripts/ui.gd")

# --- Палитра («05») ---
const PANEL := Color("141a26")
const BORDER := Color("26314a")
const TITLE := Color("ff8a3d")     # заголовки, акцент
const TEXT := Color("e7ecf3")
const MUTED := Color("8a93a3")
const GOOD := Color("86c541")      # биомасса, «куплено»
const BAD := Color("ff5a5a")

# Карточка по центру экрана: Center → Panel → VBox. Возвращает VBox для содержимого.
static func card(parent: Control, width: float, margin: int, sep: int, bg := PANEL, border := BORDER) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(margin)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	panel.add_child(vb)
	return vb

# Полноэкранная страница с шапкой: «Заголовок ……… info  [← Карта]». Возвращает VBox под шапкой.
static func page(parent: Control, title_text: String, margin: int, info: Label, on_back: Callable) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, margin)
	parent.add_child(m)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	m.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	head.add_child(title(title_text, 30))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(info)
	head.add_child(button("← Карта", on_back))
	return vb

# Надпись. size 0 = размер шрифта по умолчанию.
static func label(text := "", size := 0, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func title(text: String, size := 28, color := TITLE, centered := false) -> Label:
	var l := label(text, size, color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# Абзац с переносом по словам
static func body(text: String, width: float, centered := false) -> Label:
	var l := title(text, 0, TEXT, centered)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l

# Надпись с чёрной обводкой — поверх игрового поля / карты (HUD)
static func outlined(size: int, color: Color) -> Label:
	var l := label("", size, color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

static func button(text: String, on_press: Callable, size := 0) -> Button:
	var b := Button.new()
	b.text = text
	if size > 0:
		b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_press)
	return b

# Пустой отступ по вертикали
static func gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

# Убрать всех детей контейнера (перед перерисовкой списка)
static func clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
