extends Node2D

# Сцена боя. Используется как arena.tscn (тест, F5) и battle_a/b.tscn (узлы карты).
# Панель = отряды из GameState.squads. Отряд выставляется целиком, один раз.
# После боя: павшие вычёркиваются из армии, выжившие сохраняют раны.

@export var zombie_scene: PackedScene

# --- Отряды этого боя ---
var battle_squads := []        # [{ members: [army_dict...], used: bool }]
var squad_buttons := []        # параллельно battle_squads
var selected_squad := -1

# --- Состояние боя ---
var game_over = false
var battle_won = false
var humans_seen = false

var no_spawn_radius = Config.NO_SPAWN_RADIUS

var zombies_alive = 0
var humans_alive = 0
var defenders_killed = 0       # убитые (не сбежавшие) — для награды биомассой
var last_reward = 0

# трекинг результатов боя
var _spawned := []             # [{ node, army_id }]
var casualties := []           # army_id павших

# HUD
var info_label
var result_label
var hint_label
var hint_timer = 0.0
var _retry_btn

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	battle_squads = _build_battle_squads()
	_build_hud()
	_register_defenders()

# Отряды для боя из GameState.squads. Ничего не сформировано → авто-разбивка армии;
# армии нет (одиночный F5) → тестовый отряд из 4 обычных.
func _build_battle_squads() -> Array:
	var out := []
	for s in GameState.squads:
		var members := []
		for zid in s:
			var z = GameState.zombie_by_id(zid)
			if not z.is_empty():
				members.append(z)
		if not members.is_empty():
			out.append({ "members": members, "used": false })
	if not out.is_empty():
		return out

	var pool: Array = GameState.army.duplicate()
	if pool.is_empty():
		for i in 4:
			pool.append({ "id": -1, "type": "normal", "hp": 30 })
	var cur := []
	for z in pool:
		cur.append(z)
		if cur.size() >= 5:
			out.append({ "members": cur, "used": false })
			cur = []
	if not cur.is_empty():
		out.append({ "members": cur, "used": false })
	return out

func _register_defenders():
	for h in get_tree().get_nodes_in_group("target"):
		humans_alive += 1
		h.died.connect(_on_defender_killed)
		h.fled.connect(_on_defender_fled)
	humans_seen = humans_alive > 0

func _on_defender_killed():
	humans_alive -= 1
	defenders_killed += 1

func _on_defender_fled():
	humans_alive -= 1

func _on_zombie_died(aid):
	zombies_alive -= 1
	if aid >= 0:
		casualties.append(aid)

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

	result_label = _make_label(48, Color("ff8a3d"))
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_label.visible = false
	layer.add_child(result_label)

	# Кнопка "Заново" — только для одиночного боя (F5). В кампании конец боя ведёт
	# на экран награды / поражения.
	_retry_btn = Button.new()
	_retry_btn.text = "Заново"
	_retry_btn.add_theme_font_size_override("font_size", 20)
	_retry_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_retry_btn.position += Vector2(-40, 70)
	_retry_btn.visible = false
	_retry_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	layer.add_child(_retry_btn)

	var vp = get_viewport().get_visible_rect().size

	var skip = Button.new()
	skip.text = "Скип → победа"
	skip.add_theme_font_size_override("font_size", 14)
	skip.position = Vector2(vp.x - 150, 14)
	skip.pressed.connect(_skip_battle)
	layer.add_child(skip)

	# Панель отрядов снизу
	var bg := ButtonGroup.new()
	var btn_w := 128
	var btn_h := 64
	for i in battle_squads.size():
		var b = Button.new()
		b.toggle_mode = true
		b.button_group = bg
		b.custom_minimum_size = Vector2(btn_w, btn_h)
		b.add_theme_font_size_override("font_size", 14)
		b.position = Vector2(12 + i * (btn_w + 6), vp.y - btn_h - 10)
		b.pressed.connect(_select_squad.bind(i))
		layer.add_child(b)
		squad_buttons.append(b)
	_refresh_squad_buttons()
	if not squad_buttons.is_empty():
		squad_buttons[0].button_pressed = true
		_select_squad(0)

func _make_label(size, color):
	var l = Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _process(delta):
	if game_over:
		return

	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.visible = false

	var left := _squads_left()
	info_label.text = "Зомби на карте: %d    Отрядов в запасе: %d    Людей живо: %d" % [zombies_alive, left, humans_alive]

	if humans_seen and humans_alive <= 0:
		_end_game("ПОБЕДА")
		return

	if left <= 0 and zombies_alive <= 0:
		_end_game("ОРДА РАЗБИТА — ПОРАЖЕНИЕ")

func _squads_left() -> int:
	var n := 0
	for s in battle_squads:
		if not s.used:
			n += 1
	return n

func _end_game(text):
	if game_over:
		return
	game_over = true
	battle_won = text == "ПОБЕДА"

	if battle_won:
		last_reward = Config.BIO_WIN_BASE + Config.BIO_PER_KILL * defenders_killed
		GameState.biomass += last_reward

	# Бой из кампании → сразу на нужный экран
	if GameState.pending_node != "":
		if battle_won:
			_apply_battle_results()
			GameState.last_corpses = defenders_killed
			GameState.last_reward = last_reward
			get_tree().change_scene_to_file("res://scenes/reward.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/defeat.tscn")
		return

	# Одиночный бой (F5) — оверлей + кнопка "Заново"
	result_label.text = text
	result_label.visible = true
	_retry_btn.visible = true
	get_tree().paused = true

# Дев: мгновенная победа. В кампании — сразу на карту (без экрана награды).
func _skip_battle():
	if game_over:
		return
	game_over = true
	battle_won = true
	if GameState.pending_node != "":
		_apply_battle_results()
		GameState.biomass += Config.BIO_WIN_BASE
		GameState.go_to(GameState.pending_node)
		GameState.pending_node = ""
		GameState.pending_type = ""
		get_tree().change_scene_to_file("res://scenes/forest_map.tscn")
	else:
		result_label.text = "ПОБЕДА (скип)"
		result_label.visible = true
		_retry_btn.visible = true
		get_tree().paused = true

# Павших → из армии; выживших → текущее HP; отряды переформируем перед след. боем.
func _apply_battle_results():
	for aid in casualties:
		GameState.remove_zombie(aid)
	for e in _spawned:
		if is_instance_valid(e.node) and e.army_id >= 0:
			var z = GameState.zombie_by_id(e.army_id)
			if not z.is_empty():
				z.hp = maxi(int(e.node.hp), 1)
	GameState.clear_squads()

func _select_squad(i):
	selected_squad = i

func _refresh_squad_buttons():
	for i in squad_buttons.size():
		var s = battle_squads[i]
		if s.used:
			squad_buttons[i].text = "Отряд %d\n(в бою)" % (i + 1)
			squad_buttons[i].disabled = true
		else:
			squad_buttons[i].text = "Отряд %d\n%d зомби" % [i + 1, s.members.size()]

func _show_hint(text):
	hint_label.text = text
	hint_label.visible = true
	hint_timer = 1.2

func _unhandled_input(event):
	if game_over:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_deploy_squad(get_global_mouse_position())

func try_deploy_squad(pos):
	if selected_squad < 0 or selected_squad >= battle_squads.size():
		_show_hint("Выбери отряд снизу")
		return
	var s = battle_squads[selected_squad]
	if s.used:
		_show_hint("Этот отряд уже выставлен")
		return
	if _too_close_to_defenders(pos):
		_show_hint("Слишком близко к дому")
		return

	s.used = true
	for m in s.members:
		_spawn_zombie(m, pos + Vector2(randf_range(-30, 30), randf_range(-30, 30)))
	_refresh_squad_buttons()

	# перевести выбор на следующий неиспользованный отряд
	for i in battle_squads.size():
		if not battle_squads[i].used:
			squad_buttons[i].button_pressed = true
			_select_squad(i)
			return
	selected_squad = -1

func _too_close_to_defenders(pos):
	for t in get_tree().get_nodes_in_group("target"):
		if pos.distance_to(t.global_position) < no_spawn_radius:
			return true
	return false

func _spawn_zombie(member: Dictionary, pos: Vector2):
	var z = zombie_scene.instantiate()
	z.setup_data = {
		"id": member.get("id", -1),
		"type": member.get("type", "normal"),
		"hp": member.get("hp", 30),
	}
	z.global_position = pos
	z.died.connect(_on_zombie_died)
	add_child(z)
	zombies_alive += 1
	_spawned.append({ "node": z, "army_id": member.get("id", -1) })
