extends RefCounted
# Подключается через: const Fx = preload("res://scenes/fx.gd")

# Короткий одноразовый разлёт частиц в точке мира.
# Узел добавляется к parent и сам удаляется, когда частицы погасли.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 10, speed := 100.0, life := 0.35) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = max(amount, 1)
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2.ZERO
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = color
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
