extends CharacterBody2D

signal died(army_id)

const Fx = preload("res://scenes/fx.gd")

# arena.gd заполняет ДО add_child: { "id", "type", "hp" } из GameState.army.
# Если пусто — обычный зомби с полным HP.
var setup_data: Dictionary = {}

# --- Статы (из setup_data / GameState.ZTYPE в _ready) ---
var army_id := -1
var ztype := "normal"
var max_hp := 30
var hp := 30
var speed := 90.0
var bite_damage := 8
var bite_cooldown := 0.7
var attack_radius := 32.0

var target = null
var bite_timer = 0.0
var retarget_timer = 0.0
var retarget_interval = Config.ZOMBIE_RETARGET_INTERVAL

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	_apply_setup()
	add_to_group("zombie")
	# Навигации нужен кадр на инициализацию, иначе путь пустой
	await get_tree().physics_frame
	pick_target()

func _apply_setup():
	army_id = setup_data.get("id", -1)
	ztype = setup_data.get("type", "normal")
	var t: Dictionary = GameState.ZTYPE.get(ztype, GameState.ZTYPE["normal"])
	max_hp = t.max_hp
	hp = setup_data.get("hp", t.max_hp)   # текущее HP из армии — раненый входит раненым
	speed = t.speed
	bite_damage = t.bite_damage
	bite_cooldown = t.bite_cooldown
	var path: String = t.get("texture", "")
	if path != "" and ResourceLoader.exists(path):
		sprite.texture = load(path)

func _physics_process(delta):
	if bite_timer > 0.0:
		bite_timer -= delta

	retarget_timer -= delta
	if retarget_timer <= 0.0 or target == null or not is_instance_valid(target):
		pick_target()

	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dist = global_position.distance_to(target.global_position)

	# Дошли до цели — стоим и кусаем
	if dist <= attack_radius:
		velocity = Vector2.ZERO
		move_and_slide()
		_bite(target)
		return

	# Закрытая дверь на пути — ломаем
	var door = _blocking_door()
	if door != null:
		velocity = Vector2.ZERO
		move_and_slide()
		_bite(door)
		return

	# Идём по навигации в обход стен
	var next_point = agent.get_next_path_position()
	var direction = (next_point - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

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

# Ближайшая целая дверь вплотную
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

func take_damage(amount):
	hp -= amount
	queue_redraw()
	if hp <= 0:
		die()

func die():
	died.emit(army_id)
	Fx.burst(get_parent(), global_position, Color(0.42, 0.77, 0.25), 14, 140.0, 0.4)
	queue_free()

# Полоска HP над зомби — только при повреждении
func _draw():
	if hp >= max_hp:
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
