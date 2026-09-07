@tool
extends Node2D

# Карта леса (Фаза 2).
# Позиции узлов = дочерние Marker2D в "Nodes" (двигай мышью в редакторе).
# Тип и связи узла — в MAP_NODES ниже (по id).
# Клик по доступному узлу грузит его сцену (бой/событие/стоянка/город).

const NODE_R := 22.0   # зона клика вокруг узла
const ICON := 72.0     # размер иконки узла (px карты)

const START_ZOOM := 0.62   # стартовый зум камеры (больше = крупнее карта)
const ZOOM_MIN := 0.35
const ZOOM_MAX := 1.4

# id → тип, связи вверх, (для боёв) какую сцену грузить.
# Позиция берётся из Marker2D "Nodes/<id>".
const MAP_NODES := [
	{ "id": "n0",  "type": "start",  "next": ["n1", "n2"] },
	{ "id": "n1",  "type": "battle", "next": ["n3", "n4"],  "scene": "res://scenes/battle_a.tscn" },
	{ "id": "n2",  "type": "battle", "next": ["n4", "n5"],  "scene": "res://scenes/battle_b.tscn" },
	{ "id": "n3",  "type": "event",  "next": ["n6"] },
	{ "id": "n4",  "type": "battle", "next": ["n6", "n7"],  "scene": "res://scenes/battle_a.tscn" },
	{ "id": "n5",  "type": "loot",   "next": ["n7"] },
	{ "id": "n6",  "type": "camp",   "next": ["n8", "n9"] },
	{ "id": "n7",  "type": "battle", "next": ["n9", "n10"], "scene": "res://scenes/battle_a.tscn" },
	{ "id": "n8",  "type": "event",  "next": ["n11"] },
	{ "id": "n9",  "type": "battle", "next": ["n11", "n12"], "scene": "res://scenes/battle_a.tscn" },
	{ "id": "n10", "type": "loot",   "next": ["n12"] },
	{ "id": "n11", "type": "event",  "next": ["n13"] },
	{ "id": "n12", "type": "camp",   "next": ["n13"] },
	{ "id": "n13", "type": "city",   "next": [] },
]

const TYPE_COLOR := {
	"start":  Color("8a93a3"),   # серый
	"battle": Color("ff5a5a"),   # красный
	"event":  Color("5bc8ff"),   # голубой
	"camp":   Color("ff8a3d"),   # янтарь
	"loot":   Color("86c541"),   # зелёный
	"city":   Color("a26bff"),   # фиолет
}

var _by_id := {}
var _biomass_label: Label
var _icon_cache := {}   # type -> Texture2D (или null, если файла нет — например start)

@onready var _cam: Camera2D = $Camera2D
var _dragging := false
var _press_pos := Vector2.ZERO

# Иконка узла из assets/ui/node_<type>.png (кэш; null → рисуем кружком)
func _icon(node_type: String) -> Texture2D:
	if _icon_cache.has(node_type):
		return _icon_cache[node_type]
	var path := "res://assets/ui/node_%s.png" % node_type
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[node_type] = tex
	return tex

func _ready() -> void:
	for n in MAP_NODES:
		_by_id[n.id] = n
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if GameState.current_node == "":
		GameState.start_run("n0")
	if _cam != null:
		_cam.zoom = Vector2(START_ZOOM, START_ZOOM)
	_build_hud()
	queue_redraw()

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_biomass_label = Label.new()
	_biomass_label.position = Vector2(16, 12)
	_biomass_label.add_theme_font_size_override("font_size", 20)
	_biomass_label.add_theme_color_override("font_color", Color("86c541"))
	_biomass_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_biomass_label.add_theme_constant_override("outline_size", 4)
	cl.add_child(_biomass_label)

	var squads_btn := Button.new()
	squads_btn.text = "Отряды"
	squads_btn.position = Vector2(16, 44)
	squads_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/squads.tscn"))
	cl.add_child(squads_btn)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if _by_id.is_empty():
			for n in MAP_NODES:
				_by_id[n.id] = n
		queue_redraw()
		return
	if _biomass_label != null:
		_biomass_label.text = "Биомасса: %d" % GameState.biomass

# Позиция узла = позиция его Marker2D
func _node_pos(node_id: String) -> Vector2:
	var m := get_node_or_null("Nodes/" + node_id)
	return m.position if m != null else Vector2.ZERO

# Узел доступен: это next текущего И ещё не пройден
func _is_available(node_id: String) -> bool:
	var cur = _by_id.get(GameState.current_node)
	if cur == null:
		return false
	return cur.next.has(node_id) and not GameState.passed.has(node_id)

func _draw() -> void:
	# --- связи ---
	for n in MAP_NODES:
		for nx_id in n.next:
			if not _by_id.has(nx_id):
				continue
			var lit: bool = n.id == GameState.current_node and _is_available(nx_id)
			var col: Color = Color(1, 1, 1, 0.45) if lit else Color(1, 1, 1, 0.10)
			var width: float = 3.0 if lit else 2.0
			draw_line(_node_pos(n.id), _node_pos(nx_id), col, width)

	# --- узлы ---
	for n in MAP_NODES:
		var p := _node_pos(n.id)
		var is_current: bool = n.id == GameState.current_node

		# кольцо "ты здесь"
		if is_current:
			draw_circle(p, ICON * 0.5 + 6.0, Color(1, 1, 1, 0.9))

		# доступные (next от текущего) и текущий — яркие; остальное затемнено
		var bright: bool = is_current or _is_available(n.id) or Engine.is_editor_hint()
		var mod: Color = Color.WHITE if bright else Color(0.4, 0.4, 0.4)

		var tex := _icon(n.type)
		if tex != null:
			var r := Rect2(p - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))
			draw_texture_rect(tex, r, false, mod)
		else:
			# нет иконки (start) — рисуем кружком в цвет типа
			var col: Color = TYPE_COLOR.get(n.type, Color.WHITE) * mod
			draw_circle(p, NODE_R, col)

func _unhandled_input(event: InputEvent) -> void:
	if _cam == null:
		return

	# Колесо мыши — зум
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.12)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.12)
			return

	# ЛКМ: короткий тап = выбор узла, тащим = двигаем карту
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_press_pos = event.position
		else:
			_dragging = false
			if event.position.distance_to(_press_pos) < 6.0:
				_click_at(get_local_mouse_position())
		return

	if event is InputEventMouseMotion and _dragging:
		_cam.position -= event.relative / _cam.zoom.x
		_cam.position = _cam.position.clamp(Vector2(-520, -1000), Vector2(520, 1000))

func _zoom_by(f: float) -> void:
	var z: float = clampf(_cam.zoom.x * f, ZOOM_MIN, ZOOM_MAX)
	_cam.zoom = Vector2(z, z)

func _click_at(pos: Vector2) -> void:
	for n in MAP_NODES:
		if pos.distance_to(_node_pos(n.id)) <= ICON * 0.5 and _is_available(n.id):
			print("[map] выбран узел ", n.id, " (", n.type, ")")
			_enter_node(n)
			return

func _enter_node(n) -> void:
	GameState.pending_node = n.id
	GameState.pending_type = n.type
	match n.type:
		"battle":
			if n.has("scene"):
				get_tree().change_scene_to_file(n.scene)
		"event":
			get_tree().change_scene_to_file("res://scenes/event.tscn")
		"camp", "loot":
			get_tree().change_scene_to_file("res://scenes/node_stop.tscn")
		"city":
			GameState.go_to(n.id)
			get_tree().change_scene_to_file("res://scenes/city.tscn")
		_:
			GameState.go_to(n.id)
			queue_redraw()
