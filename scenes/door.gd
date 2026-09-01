extends StaticBody2D

# Ломаемая дверь в проёме дома.
# Пока цела — физически перекрывает вход, зомби бьют по ней.
# HP кончилось — картинка меняется на сломанную, коллизия выключается, проход открыт.

var max_hp = 60
var hp = 60
var broken = false

# Картинку сломанной двери задаём в инспекторе на узле Door
@export var texture_broken: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("door")   # зомби ищут дверь по этой группе

func take_damage(amount):
	if broken:
		return
	hp -= amount
	queue_redraw()
	if hp <= 0:
		_break_door()

func _break_door():
	broken = true
	hp = 0
	if texture_broken != null:
		sprite.texture = texture_broken
	# Выключаем коллизию в безопасный момент (не внутри обработки физики)
	col.set_deferred("disabled", true)
	remove_from_group("door")   # зомби перестают её замечать и идут дальше
	queue_redraw()

# Полоска прочности над дверью, пока она цела и повреждена
func _draw():
	if broken or hp >= max_hp:
		return
	var w = 70.0
	var h = 5.0
	var y = -26.0
	var frac = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	draw_rect(Rect2(-w / 2.0, y, w, h), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2.0, y, w * frac, h), Color("ff8a3d"))
