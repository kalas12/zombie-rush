extends CharacterBody2D

signal died

const Fx = preload("res://scenes/fx.gd")
const DEFAULT_TYPE := preload("res://resources/zombies/basic.tres")

# Тип задаётся при спавне (arena.gd: z.type = ...). Все статы — из него.
var type: ZombieType

# --- Статы (заполняются в _ready() из type) ---
var max_hp := 0
var hp := 0
var speed := 0.0
var bite_damage := 0
var bite_cooldown := 0.7
var attack_radius := 32.0

var target = null
var bite_timer = 0.0         # сколько секунд осталось до следующего укуса
var retarget_timer = 0.0     # когда снова пере-выбрать цель
var retarget_interval = Config.ZOMBIE_RETARGET_INTERVAL

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	# Применяем данные типа (если не задан — базовый)
	if type == null:
		type = DEFAULT_TYPE
	max_hp = type.max_hp
	hp = type.max_hp
	speed = type.speed
	bite_damage = type.bite_damage
	bite_cooldown = type.bite_cooldown
	attack_radius = type.attack_radius
	if type.texture != null:
		sprite.texture = type.texture

	# Чтобы люди могли находить зомби через get_nodes_in_group("zombie")
	add_to_group("zombie")

	# Ждём кадр физики: навигации нужен кадр на инициализацию, иначе путь пустой
	await get_tree().physics_frame

	pick_target()

func _physics_process(delta):
	# Кулдаун укуса тикает всегда
	if bite_timer > 0.0:
		bite_timer -= delta

	# Периодически (и сразу, если цель пропала) выбираем ближайшего защитника
	retarget_timer -= delta
	if retarget_timer <= 0.0 or target == null or not is_instance_valid(target):
		pick_target()

	# Защитников не осталось — стоим
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dist = global_position.distance_to(target.global_position)

	# --- Дошли до цели: стоим и кусаем, внутрь не лезем ---
	if dist <= attack_radius:
		velocity = Vector2.ZERO
		move_and_slide()
		_bite(target)
		return

	# --- Закрытая дверь прямо перед носом: ломаем её ---
	var door = _blocking_door()
	if door != null:
		velocity = Vector2.ZERO
		move_and_slide()
		_bite(door)
		return

	# --- Ещё далеко: идём по навигации в обход стен ---
	var next_point = agent.get_next_path_position()
	var direction = (next_point - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

# Кусаем цель, если кулдаун прошёл
# Выбрать ближайшего живого защитника и направить к нему навигацию
func pick_target():
	retarget_timer = retarget_interval
	var best = null
	var best_dist = INF
	for t in get_tree().get_nodes_in_group("target"):
		if not is_instance_valid(t):
			continue
		var d = global_position.distance_to(t.global_position)
		if d < best_dist:
			best_dist = d
			best = t
	target = best
	if target != null:
		agent.target_position = target.global_position

func _bite(victim):
	if bite_timer > 0.0:
		return
	bite_timer = bite_cooldown
	if victim != null and victim.has_method("take_damage"):
		victim.take_damage(bite_damage)
		Fx.burst(get_parent(), victim.global_position, Color(0.55, 0.06, 0.06), 6, 70.0, 0.22)

# Ближайшая целая дверь вплотную (в неё зомби упёрся по дороге к цели)
func _blocking_door():
	var best = null
	var best_dist = Config.DOOR_REACH
	for d in get_tree().get_nodes_in_group("door"):
		if not is_instance_valid(d):
			continue
		var dist = global_position.distance_to(d.global_position)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best

# Зомби получает урон (позже — от пуль людей)
func take_damage(amount):
	hp -= amount
	queue_redraw()   # перерисовать полоску HP
	if hp <= 0:
		die()

func die():
	died.emit()
	Fx.burst(get_parent(), global_position, Color(0.42, 0.77, 0.25), 14, 140.0, 0.4)
	queue_free()

# Полоска HP над зомби — показываем только когда есть повреждения (из «02»)
func _draw():
	if hp >= max_hp:
		return
	var w = 34.0
	var h = 5.0
	var y = -30.0
	var frac = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, h), Color(0, 0, 0, 0.6))
	var col = Color("6ee06e")          # полное
	if frac < 0.3:
		col = Color("ff5a5a")          # низкое
	elif frac < 0.6:
		col = Color("ffd24a")          # среднее
	draw_rect(Rect2(-w / 2.0, y, w * frac, h), col)
