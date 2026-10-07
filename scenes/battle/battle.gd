extends Node2D

# Бой — пошаговый, по клеткам. Узлы боёв карты открывают эту сцену; F6 — тестовый бой.
# Здесь только управление: клики, порядок ходов, проигрывание событий, связь с кампанией.
# Правила — scripts/battle/ (состояние, ИИ людей, карта, свет, путь), числа — battle_config.gd,
# отрисовка — board.gd, кнопки — hud.gd. Правила боя описаны в «02».

const BC = preload("res://scripts/battle/battle_config.gd")
const BattleSetup = preload("res://scripts/battle/battle_setup.gd")
const Scenes = preload("res://scripts/scenes.gd")
const Board = preload("res://scenes/battle/board.gd")
const Hud = preload("res://scenes/battle/hud.gd")

const RESULT_TEXT := {
	"win": "ПОБЕДА — избушка пала",
	"dawn": "РАССВЕТ — орда отступила",
	"wiped": "ОРДА РАЗБИТА",
}

var state                    # battle_state.gd
var board: Board
var hud: Hud
var selected = null          # выбранный зомби
var inspected = null         # человек, чья зона огня подсвечена
var deploy_type := ""        # какой тип сейчас выставляем
var busy := false            # идёт анимация — ввод игнорируем

func _ready() -> void:
	state = BattleSetup.create()

	var bg := ColorRect.new()
	bg.color = Color("0b0e14")
	bg.size = get_viewport_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -10
	add_child(bg)

	board = Board.new()
	add_child(board)
	board.setup(state)

	var types := []
	for t in BC.ZOMBIE:
		if state.reserve_count(t) > 0:
			types.append(t)
	deploy_type = types[0] if not types.is_empty() else ""
	hud = Hud.new()
	add_child(hud)
	hud.build(types)
	hud.action_pressed.connect(_on_action)
	hud.skip_pressed.connect(_skip)
	hud.type_picked.connect(_pick_type)
	hud.continue_pressed.connect(_continue)
	_refresh()

func _campaign() -> bool:
	return GameState.pending_node != ""

# ── Отображение ──────────────────────────────────────────────────

func _refresh() -> void:
	board.sync()
	board.set_marks(_marks())
	hud.set_view(_view())

func _marks() -> Dictionary:
	if busy or state.phase == "over":
		return {}
	if state.phase == "deploy":
		return { "deploy": state.deploy_cells() }
	var d := {}
	if inspected != null:
		d.threat = state.threat_cells(inspected)
		d.inspected = inspected.cell
	if selected != null:
		d.selected = selected.cell
		d.move = state.destinations(selected)
		d.attack = state.attack_targets(selected)
		var rush: int = state.rush(selected)
		d.label = { "cell": selected.cell,
			"text": "укус %d" % selected.bite + (" + натиск %d" % rush if rush > 0 else "") }
	return d

func _view() -> Dictionary:
	var counts := {}
	for t in BC.ZOMBIE:
		counts[t] = state.reserve_count(t)
	var deploying: bool = state.phase == "deploy"
	return {
		"deploying": deploying,
		"counts": counts,
		"picked": deploy_type,
		"busy": busy,
		"action_visible": state.phase != "over",
		"action_enabled": not deploying or state.deployed_count() > 0,
		"action_text": "В бой" if deploying else "Закончить ход  %d/%d" % [state.turn, BC.TURNS],
	}

# ── Ввод ─────────────────────────────────────────────────────────

# Tab — следующий непоходивший зомби (ловим раньше интерфейса)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_select_next()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if busy or state.phase == "over":
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var c: Vector2i = board.cell_at(event.position)
	if not state.map.inside(c):
		return
	if state.phase == "deploy":
		_click_deploy(c)
	else:
		await _click_battle(c)
	_refresh()

func _pick_type(t: String) -> void:
	deploy_type = t
	_refresh()

func _click_deploy(c: Vector2i) -> void:
	var z = state.zombie_at(c)
	if z != null:
		state.undeploy(z)
		deploy_type = z.type
		return
	state.deploy(deploy_type, c)
	if state.reserve_count(deploy_type) == 0:   # тип кончился — сразу следующий, где ещё есть
		for t in BC.ZOMBIE:
			if state.reserve_count(t) > 0:
				deploy_type = t
				break

func _click_battle(c: Vector2i) -> void:
	if selected != null and state.zombies.has(selected):
		if state.attack_targets(selected).has(c):
			await _play(state.attack(selected, c))
			_select_next()
			return
		if state.destinations(selected).has(c):
			await _play(state.move_zombie(selected, c))
			return
	selected = state.zombie_at(c)
	inspected = state.human_at(c) if selected == null else null

# Следующий зомби (по кругу от выбранного), который ещё не походил
func _select_next() -> void:
	if busy or state.phase != "player":
		return
	var list: Array = state.zombies
	var start: int = list.find(selected) + 1
	inspected = null
	selected = null
	for i in list.size():
		var z = list[(start + i) % list.size()]
		if not state.is_done(z):
			selected = z
			break
	_refresh()

func _on_action() -> void:
	if busy:
		return
	selected = null
	inspected = null
	if state.phase == "deploy":
		state.start_battle()
	else:
		busy = true
		_refresh()
		await _play(state.end_player_turn(), true)
	_select_next()
	_refresh()

# ── События и конец боя ──────────────────────────────────────────

# slow — ход людей: пауза перед каждым действием, медленнее шаги и выстрелы
func _play(events: Array, slow := false) -> void:
	busy = true
	board.set_marks({})
	for e in events:
		if slow and e.t in ["move", "hit"]:
			await get_tree().create_timer(BC.HUMAN_GAP).timeout
		await board.play(e, slow)
	board.sync()   # итоговая сверка — после всех анимаций
	busy = false
	if state.phase == "over":
		_finish()

# Конец боя — окно итога; дальше по «Продолжить»
func _finish() -> void:
	_refresh()
	hud.show_result(RESULT_TEXT[state.result], "Ходов: %d\nЛюдей убито: %d  ·  сбежало: %d\nЗомби погибло: %d" % [
		mini(state.turn, BC.TURNS), state.killed, state.fled, state.casualties.size()])

func _continue() -> void:
	if not _campaign():
		get_tree().reload_current_scene()   # тестовый бой (F6) — заново
		return
	if state.result == "win":
		BattleSetup.apply_to_army(state)
		var bio := BattleSetup.win_biomass(state)
		GameState.biomass += bio
		GameState.last_reward = bio
		GameState.last_corpses = state.killed
		GameState.last_fled = state.fled
		GameState.last_lost = state.casualties.size()
		get_tree().change_scene_to_file(Scenes.REWARD)
	else:
		get_tree().change_scene_to_file(Scenes.DEFEAT)

# Дев: мгновенная победа. В кампании — сразу на карту (без награды), как раньше.
func _skip() -> void:
	if busy or state.phase == "over":
		return
	if _campaign():
		GameState.biomass += Config.BIO_WIN_BASE
		GameState.finish_node()
	else:
		state.result = "win"
		state.phase = "over"
		_finish()
