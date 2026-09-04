extends Node2D

# Ссылка на сцену зомби, которую будем клонировать
@export var zombie_scene: PackedScene

# Типы зомби (из .tres) и запас пачек по каждому
var zombie_types := []       # Array[ZombieType]
var packs_left := []          # сколько пачек осталось, параллельно zombie_types
var type_buttons := []        # кнопки панели, параллельно zombie_types
var selected_index := -1      # какой тип выбран сейчас (-1 = ничего)

# --- Состояние боя ---
var game_over = false
var battle_won = false
var humans_seen = false  # видели ли хоть раз живого человека (защита от мгновенной победы)

var no_spawn_radius = Config.NO_SPAWN_RADIUS # ближе этого к защитникам спавнить нельзя

# Счётчики ведём по сигналам, а не опросом групп каждый кадр
var zombies_alive = 0
var humans_alive = 0

# HUD создаём из кода, узлы в сцену добавлять не нужно
var info_label
var result_label
var hint_label
var hint_timer = 0.0

func _ready():
	# Чтобы менеджер боя реагировал на перезапуск даже при paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	zombie_types = _load_zombie_types()
	for t in zombie_types:
		packs_left.append(t.packs)
	_build_hud()
	_register_defenders()

# Собираем все типы зомби из resources/zombies/ — новый .tres появится сам
func _load_zombie_types() -> Array:
	var out := []
	var dir := DirAccess.open("res://resources/zombies")
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".tres"):
				var res = load("res://resources/zombies/%s" % f)
				if res is ZombieType:
					out.append(res)
	out.sort_custom(func(a, b): return a.cost < b.cost)  # дешёвые слева
	if out.is_empty():
		out.append(load("res://resources/zombies/basic.tres"))
	return out

# Считаем защитников на старте и слушаем их сигналы died / fled
func _register_defenders():
	for h in get_tree().get_nodes_in_group("target"):
		humans_alive += 1
		h.died.connect(_on_defender_gone)
		h.fled.connect(_on_defender_gone)
	humans_seen = humans_alive > 0

func _on_zombie_died():
	zombies_alive -= 1

func _on_defender_gone():
	humans_alive -= 1

func _build_hud():
	var layer = CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	info_label = _make_label(20, Color("e7ecf3"))
	info_label.position = Vector2(20, 16)
	layer.add_child(info_label)

	hint_label = _make_label(20, Color("ff5a5a"))
	hint_label.position = Vector2(20, 46)
	hint_label.visible = false
	layer.add_child(hint_label)

	result_label = _make_label(64, Color("ff8a3d"))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_label.visible = false
	layer.add_child(result_label)

	# Панель выбора типа зомби — прижата к низу экрана
	var vp = get_viewport().get_visible_rect().size

	# Дев-кнопка: мгновенная победа (для прогона кампании без игры в бой)
	var skip = Button.new()
	skip.text = "Скип → победа"
	skip.add_theme_font_size_override("font_size", 14)
	skip.position = Vector2(vp.x - 150, 14)
	skip.pressed.connect(_skip_battle)
	layer.add_child(skip)
	var bg := ButtonGroup.new()   # радио-режим: выбран всегда один
	var btn_w := 96
	var btn_h := 104
	for i in zombie_types.size():
		var t = zombie_types[i]
		var b = Button.new()
		b.toggle_mode = true
		b.button_group = bg
		b.custom_minimum_size = Vector2(btn_w, btn_h)
		b.icon = t.texture
		b.add_theme_constant_override("icon_max_width", 46)
		b.add_theme_font_size_override("font_size", 12)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.position = Vector2(12 + i * (btn_w + 6), vp.y - btn_h - 8)
		b.pressed.connect(_on_type_pressed.bind(i))
		layer.add_child(b)
		type_buttons.append(b)
	_refresh_type_buttons()

	# Первый тип выбран по умолчанию
	if not type_buttons.is_empty():
		type_buttons[0].button_pressed = true
		_on_type_pressed(0)

func _make_label(size, color):
	var l = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# Чёрный контур — читается на любом фоне
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _process(delta):
	if game_over:
		return

	# Гасим подсказку
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.visible = false

	info_label.text = "Зомби на карте: %d    Людей живо: %d" % [zombies_alive, humans_alive]

	# Победа: всех защитников убили или разогнали
	if humans_seen and humans_alive <= 0:
		_end_game("ПОБЕДА")
		return

	# Поражение: пачки всех типов кончились и на карте пусто (таймера-рассвета больше нет)
	if _all_packs_empty() and zombies_alive <= 0:
		_end_game("ЗОМБИ КОНЧИЛИСЬ — ПОРАЖЕНИЕ")

func _end_game(text):
	game_over = true
	battle_won = text == "ПОБЕДА"
	var hint := "\n(R — заново"
	if GameState.pending_node != "":   # бой запущен с карты леса
		hint += "   ·   M — на карту"
	result_label.text = text + hint + ")"
	result_label.visible = true
	get_tree().paused = true

# Дев: мгновенно закончить бой победой
func _skip_battle():
	if game_over:
		return
	_end_game("ПОБЕДА")
	if GameState.pending_node != "":
		_return_to_map()

# Вернуться на карту леса (только если бой запущен оттуда)
func _return_to_map():
	if battle_won:
		GameState.go_to(GameState.pending_node)   # засчитываем узел пройденным
	GameState.pending_node = ""
	GameState.pending_type = ""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/forest_map.tscn")

func _on_type_pressed(i):
	selected_index = i

# Текст кнопок = "Имя\nостаток пачек"; пустые — выключаем; выбор уводим на непустую
func _refresh_type_buttons():
	for i in type_buttons.size():
		type_buttons[i].text = "%s\n%d" % [zombie_types[i].display_name, packs_left[i]]
		type_buttons[i].disabled = packs_left[i] <= 0

	if selected_index >= 0 and packs_left[selected_index] <= 0:
		selected_index = -1
		for i in packs_left.size():
			if packs_left[i] > 0:
				selected_index = i
				type_buttons[i].button_pressed = true
				break

func _all_packs_empty() -> bool:
	for n in packs_left:
		if n > 0:
			return false
	return true

func _show_hint(text):
	hint_label.text = text
	hint_label.visible = true
	hint_timer = 1.2

func _unhandled_input(event):
	# После конца боя: R — заново, M — назад на карту (если пришли с карты)
	if game_over:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_R:
				get_tree().paused = false
				get_tree().reload_current_scene()
			elif event.keycode == KEY_M and GameState.pending_node != "":
				_return_to_map()
		return

	# Левая кнопка мыши по карте — спавн выбранной группы
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_spawn_group(get_global_mouse_position())

func try_spawn_group(pos):
	if selected_index < 0:
		_show_hint("Сначала выбери тип зомби снизу")
		return
	if packs_left[selected_index] <= 0:
		_show_hint("Пачки этого типа кончились")
		return
	if _too_close_to_defenders(pos):
		_show_hint("Слишком близко к дому")
		return

	var t = zombie_types[selected_index]
	packs_left[selected_index] -= 1
	for i in t.pack_size:
		_spawn_one(pos + Vector2(randf_range(-24, 24), randf_range(-24, 24)))
	_refresh_type_buttons()

func _too_close_to_defenders(pos):
	for t in get_tree().get_nodes_in_group("target"):
		if pos.distance_to(t.global_position) < no_spawn_radius:
			return true
	return false

func _spawn_one(pos):
	var z = zombie_scene.instantiate()
	z.type = zombie_types[selected_index]
	z.global_position = pos
	z.died.connect(_on_zombie_died)
	add_child(z)
	zombies_alive += 1
