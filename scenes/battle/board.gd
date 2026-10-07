extends Node2D
# Поле боя: тайлы и постройки из арта, свет (ночь + тёплые круги), затемнение тёмных
# клеток, подсветки ходов/целей, фишки юнитов и анимации событий («сок»).
# Правил не знает — рисует то, что лежит в состоянии боя (battle_state.gd).

const BC = preload("res://scripts/battle/battle_config.gd")
const Vision = preload("res://scripts/battle/vision.gd")
const Pathing = preload("res://scripts/battle/pathing.gd")
const UI = preload("res://scripts/ui.gd")
const Token = preload("res://scenes/battle/token.gd")
const BattleState = preload("res://scripts/battle/battle_state.gd")

const GROUND := [
	"res://assets/levels/ground-art/ground_moss.png",
	"res://assets/levels/ground-art/ground_needles.png",
	"res://assets/levels/ground-art/ground_roots.png",
]
const OBSTACLE := {
	"t": "res://assets/levels/trees-art/tree_pine.png",
	"p": "res://assets/levels/trees-art/bush.png",
	"c": "res://assets/levels/trees-art/rock.png",
}
const WALL_H := "res://assets/levels/walls-art/wall_h.png"
const WALL_V := "res://assets/levels/walls-art/wall_v.png"
const WALL_CORNER := "res://assets/levels/walls-art/wall_corner.png"
const WINDOW := "res://assets/levels/walls-art/window.png"
const FLOOR_COLOR := Color(0.93, 0.91, 0.85)        # пол избушки
const WARM := Color(1.0, 0.78, 0.45)                # тёплый свет окон/пола
const FIRE_COLOR := Color(1.0, 0.62, 0.3)
const FIRE_ENERGY := 2.6                            # яркость костра (мерцает ±15 %)
const BROKEN := Color(0.3, 0.27, 0.27)              # разбитое окно — затемнённый спрайт
const DONE := Color(0.45, 0.45, 0.45)               # зомби уже походил — тусклая фишка

var state
var cell := 40.0             # px на клетку — подбирается под окно (поле + нижняя полоса)
var origin := Vector2.ZERO   # левый верхний угол поля на экране
var world: Node2D            # поле под ночью (трясём при смерти человека)
var dark: Node2D             # затемнение неосвещённых клеток
var marks: Node2D            # подсветки — поверх ночи, под фишками
var units: Node2D            # фишки — поверх ночи, всегда читаются
var fx: Node2D               # цифры и трассеры — над всем
var fire_node: Node2D
var fire_light: PointLight2D
var tokens := {}             # id юнита → Token
var window_sprites := {}     # клетка → Sprite2D
# что подсвечивать: { deploy, move, attack, threat: [клетки], selected, inspected: клетка,
#                    label: { cell, text } — подпись над клеткой }
var marks_data := {}

func setup(s) -> void:
	state = s
	_fit_to_screen()
	var night := CanvasModulate.new()
	night.color = BC.NIGHT
	add_child(night)

	world = Node2D.new()
	world.position = origin
	world.light_mask = 2          # пол (рисует world) светит только своя лампа — без пересвета
	world.draw.connect(_draw_floor)
	add_child(world)
	_build_tiles()
	_build_decor()

	dark = Node2D.new()
	dark.z_index = 2
	dark.draw.connect(_draw_dark)
	world.add_child(dark)

	# поверх ночи: подсветки (слой 1), фишки (2), цифры и трассеры (3)
	marks = Node2D.new()
	marks.draw.connect(_draw_marks)
	units = Node2D.new()
	fx = Node2D.new()
	fx.draw.connect(_draw_label)
	for i in 3:
		var n: Node2D = [marks, units, fx][i]
		n.position = origin
		var layer := CanvasLayer.new()
		layer.layer = i + 1
		add_child(layer)
		layer.add_child(n)

# Клетка — под окно над нижней полосой (FIELD_FILL места); поле по центру.
# Окно растягивается целиком (stretch keep), видимая область всегда одна — считаем один раз.
func _fit_to_screen() -> void:
	var avail := get_viewport().get_visible_rect().size - Vector2(0, BC.BAR_HEIGHT)
	cell = floorf(minf(avail.x / state.map.w, avail.y / state.map.h) * BC.FIELD_FILL)
	origin = ((avail - size_px()) / 2.0).floor()

func size_px() -> Vector2:
	return Vector2(state.map.w, state.map.h) * cell

func cell_at(screen_pos: Vector2) -> Vector2i:
	return Vector2i(((screen_pos - origin) / cell).floor())

func center(c: Vector2i) -> Vector2:
	return Vector2(c) * cell + Vector2(cell, cell) / 2.0

# ── Тайлы, постройки, свет ───────────────────────────────────────

func _build_tiles() -> void:
	var map = state.map
	var light_tex := _light_texture()
	var floor_cells: Array[Vector2i] = []
	for c in map.cells():
		var t: String = map.tile(c)
		if t == "_" or t == "D":
			floor_cells.append(c)
		else:
			_sprite(GROUND[(c.x * 7 + c.y * 13) % GROUND.size()], c, 1.0, 0, true)
		match t:
			"#":
				_sprite(_wall_art(c), c, 1.0, 1)
			"W":
				window_sprites[c] = _sprite(WINDOW, c, 0.95, 1)
				_light(light_tex, c, 2.0, WARM, 1.3)
			"D":
				_light(light_tex, c, 2.0, WARM, 1.3)
			"F":
				fire_node = Node2D.new()
				fire_node.position = center(c)
				fire_node.z_index = 1
				fire_node.draw.connect(_draw_fire)
				world.add_child(fire_node)
				fire_light = _light(light_tex, c, BC.LIGHT_FIRE + 0.9, FIRE_COLOR, FIRE_ENERGY)
		if OBSTACLE.has(t):
			_sprite(OBSTACLE[t], c, 1.05, 1).modulate = Color(1.4, 1.4, 1.4)   # читались в ночи
	# пол освещён всегда — своя мягкая лампа из центра пола
	var mid := Vector2.ZERO
	for c in floor_cells:
		mid += Vector2(c)
	if not floor_cells.is_empty():
		_light(light_tex, Vector2i((mid / floor_cells.size()).round()), 2.6, WARM, 0.3).range_item_cull_mask = 2

# Лес за краем поля (не играет): тусклая земля и редкие деревья — чтобы весь экран был полем
func _build_decor() -> void:
	var side := int(ceil(origin.x / cell)) + 1
	var map = state.map
	for y in range(-int(ceil(origin.y / cell)) - 1, map.h + int(ceil(BC.BAR_HEIGHT / cell)) + 1):
		for x in range(-side, map.w + side):
			var c := Vector2i(x, y)
			if map.inside(c):
				continue
			var hsh := absi(x * 73856093 ^ y * 19349663)
			_sprite(GROUND[hsh % GROUND.size()], c, 1.0, 0, true).modulate = Color(0.55, 0.55, 0.6)
			if hsh % 7 == 0:
				_sprite(OBSTACLE["t" if hsh % 2 == 0 else "p"], c, 1.1, 1).modulate = Color(0.8, 0.8, 0.85)

func _sprite(path: String, c: Vector2i, fit: float, z: int, cover := false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	var sz := sp.texture.get_size()
	var s: float = cell * fit / (minf(sz.x, sz.y) if cover else maxf(sz.x, sz.y))
	sp.scale = Vector2(s, s)
	sp.position = center(c)
	sp.z_index = z
	world.add_child(sp)
	return sp

# Сегмент стены: соседи-стены и по горизонтали, и по вертикали → угол
func _wall_art(c: Vector2i) -> String:
	var map = state.map
	var horiz: bool = "#WD".contains(map.tile(c + Vector2i.LEFT)) or "#WD".contains(map.tile(c + Vector2i.RIGHT))
	var vert: bool = "#WD".contains(map.tile(c + Vector2i.UP)) or "#WD".contains(map.tile(c + Vector2i.DOWN))
	if horiz and vert:
		return WALL_CORNER
	return WALL_H if horiz else WALL_V

func _light_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex

func _light(tex: Texture2D, c: Vector2i, radius_cells: float, color: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = radius_cells * cell * 2.0 / 256.0
	l.color = color
	l.energy = energy
	l.position = center(c)
	world.add_child(l)
	return l

# ── Рисование ────────────────────────────────────────────────────

func _cell_rect(c: Vector2i, inset := 0.0) -> Rect2:
	return Rect2(Vector2(c) * cell + Vector2(inset, inset), Vector2(cell, cell) - Vector2(inset, inset) * 2)

func _draw_floor() -> void:
	for c in state.map.cells():
		if state.map.tile(c) in ["_", "D"]:
			world.draw_rect(_cell_rect(c), FLOOR_COLOR)

func _draw_dark() -> void:
	for c in state.map.cells():
		if state.map.walkable_or_window(c) and not Vision.is_lit(state.map, c):
			dark.draw_rect(_cell_rect(c), Color(0, 0, 0, BC.DARK_CELL_ALPHA))
	dark.draw_rect(Rect2(Vector2.ZERO, size_px()), Color(0, 0, 0, 0.7), false, 3.0)   # граница поля

# Заглушка костра: мерцающие круги + полоска HP (или угли, если затоптан)
func _draw_fire() -> void:
	var map = state.map
	var k: float = cell / 52.0   # размеры заглушки — в пропорции к клетке
	if map.fire_hp <= 0:
		fire_node.draw_circle(Vector2.ZERO, 10 * k, Color(0.25, 0.2, 0.18))
		return
	var f := randf_range(0.85, 1.15)
	fire_node.draw_circle(Vector2.ZERO, 15 * k * f, Color(1.0, 0.45, 0.1, 0.9))
	fire_node.draw_circle(Vector2(0, -3 * k), 8 * k * f, Color(1.0, 0.85, 0.3))
	var w: float = cell * 0.75
	fire_node.draw_rect(Rect2(-w / 2, cell * 0.33, w, 4), Color(0, 0, 0, 0.6))
	fire_node.draw_rect(Rect2(-w / 2, cell * 0.33, w * map.fire_hp / BC.FIRE_HP, 4), Color("ff8a3d"))

func set_marks(d: Dictionary) -> void:
	marks_data = d
	marks.queue_redraw()
	fx.queue_redraw()

func _draw_marks() -> void:
	for c in marks_data.get("deploy", []):
		marks.draw_rect(_cell_rect(c, 2), Color(0.5, 0.9, 0.3, 0.22))
	for c in marks_data.get("threat", []):
		marks.draw_rect(_cell_rect(c, 2), Color(1.0, 0.55, 0.15, 0.35))
		marks.draw_rect(_cell_rect(c, 2), Color(1.0, 0.55, 0.15, 0.6), false, 2.0)
	for c in marks_data.get("move", []):
		marks.draw_rect(_cell_rect(c, 2), Color(0.5, 0.9, 0.3, 0.3))
	for c in marks_data.get("attack", []):
		marks.draw_rect(_cell_rect(c, 2), Color(1.0, 0.25, 0.25, 0.42))
	if marks_data.has("inspected"):
		marks.draw_rect(_cell_rect(marks_data.inspected, 2), Color(1.0, 0.55, 0.15), false, 3.0)
	if marks_data.has("selected"):
		marks.draw_rect(_cell_rect(marks_data.selected, 2), Color(1, 1, 1, 0.9), false, 3.0)

# Плашка над клеткой: «укус 6 + натиск 2» — в верхнем слое (над фишками), в пределах поля
func _draw_label() -> void:
	if marks_data.has("label"):
		var font := ThemeDB.fallback_font
		var text: String = marks_data.label.text
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15) + Vector2(10, 4)
		var at: Vector2i = marks_data.label.cell
		var x := clampf(center(at).x - sz.x / 2, 0, size_px().x - sz.x)
		var y: float = at.y * cell - sz.y - 2 if at.y > 0 else (at.y + 1) * cell + 2
		fx.draw_rect(Rect2(x, y, sz.x, sz.y), Color(0, 0, 0, 0.75))
		fx.draw_string(font, Vector2(x + 5, y + sz.y - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.85, 0.4))

func _process(_delta: float) -> void:
	if fire_node != null:
		fire_node.queue_redraw()
		if fire_light.enabled:
			fire_light.energy = lerpf(fire_light.energy, FIRE_ENERGY * randf_range(0.85, 1.15), 0.15)

# ── Синхронизация фишек с состоянием ─────────────────────────────
# Полная сверка — только когда анимации закончились. Во время проигрывания событий
# фишки двигает и ранит сама анимация (иначе юниты «прыгают» на итоговые клетки раньше времени).

func sync() -> void:
	for m in state.humans:
		var t := _token(m.id, m.texture, true)
		t.position = center(m.cell)
		t.set_hp(m.hp, m.max_hp)
		t.panic = m.panicking
	for z in state.zombies:
		var t := _token(z.id, load(GameState.ztype(z.type).texture), false)
		t.visible = z.cell != BattleState.OFF
		t.position = center(z.cell)
		t.set_hp(z.hp, z.max_hp)
		t.modulate = DONE if state.phase == "player" and state.is_done(z) else Color.WHITE
	for id in tokens.keys():   # юнит пропал без анимации (невыставленные после «В бой»)
		if not _alive(id):
			tokens[id].queue_free()
			tokens.erase(id)
	_sync_structures()

# Окна, костёр, тьма — по состоянию
func _sync_structures() -> void:
	for c in window_sprites:
		window_sprites[c].modulate = BROKEN if state.map.windows[c] <= 0 else Color.WHITE
	if fire_light != null:
		fire_light.enabled = state.map.fire_hp > 0
	dark.queue_redraw()

func _alive(id: int) -> bool:
	return state.humans.any(func(m): return m.id == id) or state.zombies.any(func(z): return z.id == id)

func _token(id: int, tex: Texture2D, human: bool) -> Token:
	if not tokens.has(id):
		var t := Token.new()
		t.setup(tex, cell, human, UI.BAD if human else UI.GOOD)
		units.add_child(t)
		tokens[id] = t
	return tokens[id]

# ── Анимации событий ─────────────────────────────────────────────

# slow — ход людей: шаги и паузы длиннее (темп — в battle_config)
func play(e: Dictionary, slow := false) -> void:
	match e.t:
		"move":
			await _anim_move(e, BC.HUMAN_STEP_TIME if slow else BC.STEP_TIME)
		"hit":
			await _anim_hit(e, BC.HUMAN_HIT_PAUSE if slow else BC.HIT_PAUSE)
		"die":
			await _anim_vanish(e.id, true)
		"fled":
			await _anim_vanish(e.id, false)
		"spawn":
			await _anim_spawn(e.id)
		"panic":
			if tokens.has(e.id):
				tokens[e.id].panic = true
				tokens[e.id].queue_redraw()
				_float(tokens[e.id].position, "паника!", Color(1.0, 0.82, 0.2))
		"broken":
			_sync_structures()
			_float(center(e.cell), "разбито!" if state.map.windows.has(e.cell) else "костёр погас", UI.TITLE)

func _anim_move(e: Dictionary, step: float) -> void:
	var t: Token = tokens.get(e.id)
	if t == null or e.path.size() < 2:
		return
	var tw := create_tween()   # ровный шаг по клеткам, мягкая остановка в конце
	for i in range(1, e.path.size()):
		var p := tw.tween_property(t, "position", center(e.path[i]), step)
		if i == e.path.size() - 1:
			p.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

func _anim_hit(e: Dictionary, pause: float) -> void:
	var a: Token = tokens.get(e.from)
	var to := center(e.cell)
	if a != null:
		var home := a.position
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		if Pathing.cheb(Vector2i(home / cell), e.cell) > 1:
			_tracer(home, to)   # выстрел издалека — стоит на месте: трассер + лёгкая «отдача» масштабом
			tw.tween_property(a, "scale", Vector2(1.15, 1.15), 0.08).set_ease(Tween.EASE_OUT)
			tw.tween_property(a, "scale", Vector2.ONE, 0.14).set_ease(Tween.EASE_IN_OUT)
		else:                   # вплотную — мягкий рывок к цели и обратно
			tw.tween_property(a, "position", home.lerp(to, 0.35), 0.09).set_ease(Tween.EASE_OUT)
			tw.tween_property(a, "position", home, 0.14).set_ease(Tween.EASE_IN_OUT)
	var flash: CanvasItem = null   # белая вспышка у цели
	if e.target >= 0 and tokens.has(e.target):
		flash = tokens[e.target].sprite
	elif window_sprites.has(e.cell):
		flash = window_sprites[e.cell]
	elif e.cell == state.map.fire_cell:
		flash = fire_node
	if flash != null:
		var base := flash.modulate
		flash.modulate = Color(3, 3, 3)
		create_tween().tween_property(flash, "modulate", base, 0.18)
	if e.target >= 0 and tokens.has(e.target):
		tokens[e.target].hurt(e.dmg)   # полоска HP падает в момент удара
	var zombie_bit: bool = a != null and not a.is_human
	_float(to, "-%d" % e.dmg, Color(1, 0.35, 0.3) if zombie_bit else Color(1, 0.9, 0.4))
	await get_tree().create_timer(pause).timeout

# Юнит уходит с поля: убит (человек — с тряской) или сбежал
func _anim_vanish(id: int, killed: bool) -> void:
	var t: Token = tokens.get(id)
	if t == null:
		return
	tokens.erase(id)
	if killed and t.is_human:
		_shake()
	var tw := create_tween()
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	await tw.finished
	t.queue_free()

# Заражённый встаёт: фишка появляется на своей клетке с «подскоком»
func _anim_spawn(id: int) -> void:
	var z = null
	for o in state.zombies:
		if o.id == id:
			z = o
	if z == null:
		return
	var t := _token(id, load(GameState.ztype(z.type).texture), false)
	t.position = center(z.cell)
	t.set_hp(z.hp, z.max_hp)
	t.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(t, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

func _shake() -> void:
	var tw := create_tween()
	for i in 6:
		var off := origin + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		tw.tween_property(world, "position", off, 0.035)
		tw.parallel().tween_property(units, "position", off, 0.035)
	tw.tween_property(world, "position", origin, 0.035)
	tw.parallel().tween_property(units, "position", origin, 0.035)

func _tracer(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 2.0
	line.default_color = Color(1.0, 0.85, 0.5)
	fx.add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)

# Всплывающая цифра/надпись над точкой поля
func _float(pos: Vector2, text: String, col: Color) -> void:
	var l := UI.outlined(17, col)
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos + Vector2(-20, -36)
	fx.add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 26, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)
