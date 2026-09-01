extends CharacterBody2D

signal died   # убит
signal fled   # сбежал за край поля

const Fx = preload("res://scenes/fx.gd")
const DEFAULT_TYPE := preload("res://resources/humans/shooter.tres")

# Тип защитника задаётся на узле в сцене (arena.tscn). Все статы — из него.
@export var type: HumanType

# Общее поведение (не зависит от типа) — из Config
var move_speed = Config.HUMAN_MOVE_SPEED
var melee_chase_range = Config.MELEE_CHASE_RANGE
var retreat_range = Config.SHOOTER_RETREAT_RANGE
var panic_hp_frac = Config.PANIC_HP_FRAC
var panic_speed = Config.PANIC_SPEED

# Интерьер дома (без стен). Защитник не выходит за эти границы — не влипает в стену.
const ROOM := Rect2(452, 430, 228, 228)

# Всё поле. Выбежал за край (в панике) — исчезает.
const ARENA := Rect2(12, 9, 1108, 1070)

# Точка снаружи двери — в панике защитник сначала бежит сюда, потом к краю поля.
const FLEE_GATE := Vector2(566, 760)

var panicking = false

var hp = 0
var max_hp = 0
var ammo = 0
var fire_timer = 0.0      # секунд до следующего выстрела/удара
var reload_timer = 0.0    # > 0 — идёт перезарядка
var home_pos = Vector2.ZERO   # куда возвращаться, когда угрозы нет

var tracer_timer = 0.0    # сколько ещё рисовать линию выстрела
var tracer_to = Vector2.ZERO  # куда стреляли (в локальных координатах)

func _ready():
	if type == null:
		type = DEFAULT_TYPE
	add_to_group("target")
	home_pos = global_position

	max_hp = type.max_hp
	hp = type.max_hp
	ammo = type.max_ammo
	if type.texture != null:
		$Sprite2D.texture = type.texture

func _physics_process(delta):
	if fire_timer > 0.0:
		fire_timer -= delta

	# Гасим линию выстрела
	if tracer_timer > 0.0:
		tracer_timer -= delta
		queue_redraw()

	# Перезарядка идёт сама по себе и не мешает движению
	if reload_timer > 0.0:
		reload_timer -= delta
		if reload_timer <= 0.0:
			ammo = type.max_ammo

	# Мало здоровья — паника: бросает бой и бежит с поля
	if not panicking and hp <= float(max_hp) * panic_hp_frac:
		_start_panic()
	if panicking:
		_flee()
		return

	var z_near = nearest_zombie()             # ближайший зомби вообще — для движения
	var z_shoot = nearest_zombie_in_range()   # ближайший видимый в радиусе — для атаки

	# --- Движение ---
	if type.melee:
		velocity = _melee_move(z_near)
	else:
		velocity = _shooter_move(z_near)
	move_and_slide()

	# Не выходить за стены дома (иначе стрелок пятится прямо в стену)
	global_position.x = clamp(global_position.x, ROOM.position.x, ROOM.end.x)
	global_position.y = clamp(global_position.y, ROOM.position.y, ROOM.end.y)

	# --- Атака (стоя или на ходу) ---
	if z_shoot != null and fire_timer <= 0.0 and reload_timer <= 0.0:
		shoot(z_shoot)

# Ближник: идёт к ближайшему зомби, пока не подойдёт на удар; иначе — домой
func _melee_move(z):
	if z != null and global_position.distance_to(z.global_position) <= melee_chase_range:
		var d = global_position.distance_to(z.global_position)
		if d > type.attack_range * 0.8:
			return (z.global_position - global_position).normalized() * move_speed
		return Vector2.ZERO
	return _toward_home()

# Стрелок: стоит на месте; при перезарядке отходит от зомби, но в сторону своего поста
func _shooter_move(z):
	if reload_timer > 0.0 and z != null and global_position.distance_to(z.global_position) < retreat_range:
		var away = (global_position - z.global_position).normalized()
		var home = (home_pos - global_position).normalized()
		return (away + home).normalized() * move_speed
	return _toward_home()

func _toward_home():
	var d = global_position.distance_to(home_pos)
	if d < 6.0:
		return Vector2.ZERO
	return (home_pos - global_position).normalized() * move_speed

# Переход в панику: бросает бой. Из группы target НЕ выходит —
# зомби продолжают гнаться за ним как за ближайшей живой целью.
func _start_panic():
	panicking = true

# Бегство: сначала к проёму двери, потом к ближайшему краю поля. За краем — исчезаем.
func _flee():
	var dir
	if global_position.y < 700.0:
		dir = (FLEE_GATE - global_position).normalized()   # ещё в доме — к двери
	else:
		dir = _dir_to_nearest_edge()                       # вышел — прочь с поля
	velocity = dir * panic_speed
	move_and_slide()
	if not ARENA.grow(30.0).has_point(global_position):
		fled.emit()
		queue_free()

func _dir_to_nearest_edge():
	var to_left = global_position.x - ARENA.position.x
	var to_right = ARENA.end.x - global_position.x
	var to_top = global_position.y - ARENA.position.y
	var to_bottom = ARENA.end.y - global_position.y
	var m = min(min(to_left, to_right), min(to_top, to_bottom))
	if m == to_left:
		return Vector2.LEFT
	if m == to_right:
		return Vector2.RIGHT
	if m == to_top:
		return Vector2.UP
	return Vector2.DOWN

# Ближайший живой зомби без учёта стен и дальности
func nearest_zombie():
	var best = null
	var best_dist = INF
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var d = global_position.distance_to(z.global_position)
		if d < best_dist:
			best_dist = d
			best = z
	return best

# Ближайший зомби, который И в радиусе оружия, И виден (не за стеной). Иначе null.
func nearest_zombie_in_range():
	var max_range = type.attack_range

	var candidates = []
	for z in get_tree().get_nodes_in_group("zombie"):
		if not is_instance_valid(z):
			continue
		var d = global_position.distance_to(z.global_position)
		if d <= max_range:
			candidates.append({ "z": z, "d": d })
	candidates.sort_custom(func(a, b): return a.d < b.d)

	for c in candidates:
		if has_line_of_sight(c.z):
			return c.z
	return null

# Пускаем луч от стрелка к зомби: если первым задели стену — цель за стеной
func has_line_of_sight(z):
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, z.global_position)
	query.exclude = [get_rid()]        # не задевать самого себя
	query.collide_with_bodies = true
	query.collision_mask = 1           # только слой 1: стены/двери. Окна (слой 2) луч не видит
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.collider == z

func shoot(z):
	fire_timer = type.fire_rate

	# Пока попадание мгновенное (hitscan). Настоящие пули и окна-бойницы — дальше.
	if z.has_method("take_damage"):
		z.take_damage(type.damage)

	# Искра в точке попадания (стрелок — оранжевая, нож — кровь)
	var spark = Color(0.55, 0.06, 0.06) if type.melee else Color(1.0, 0.7, 0.3)
	Fx.burst(get_parent(), z.global_position, spark, 5, 60.0, 0.18)

	# Короткая линия-трассер + вспышка у ствола
	tracer_to = to_local(z.global_position)
	tracer_timer = 0.06
	queue_redraw()

	# Патроны (у ближнего max_ammo = -1 — пропускаем)
	if type.max_ammo > 0:
		ammo -= 1
		if ammo <= 0:
			reload_timer = type.reload_time

# Защитник получает урон от укуса зомби
func take_damage(amount):
	hp -= amount
	queue_redraw()   # обновить полоску HP
	if hp <= 0:
		die()

func die():
	died.emit()
	queue_free()

func _draw():
	# Линия выстрела (трассер) + вспышка у ствола
	if tracer_timer > 0.0:
		draw_line(Vector2.ZERO, tracer_to, Color("ff8a3d"), 2.0)
		if not type.melee:
			draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.86, 0.45))

	# Полоска HP над защитником — видна всегда (из «02»)
	if max_hp <= 0:
		return
	var w = 34.0
	var h = 5.0
	var y = -30.0
	var frac = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, h), Color(0, 0, 0, 0.6))
	var col = Color("6ee06e")
	if frac < 0.3:
		col = Color("ff5a5a")
	elif frac < 0.6:
		col = Color("ffd24a")
	draw_rect(Rect2(-w / 2.0, y, w * frac, h), col)
