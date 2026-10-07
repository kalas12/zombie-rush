extends Node2D
# Фишка юнита на поле: спрайт + полоска HP + значок «!» у человека в панике.
# Создаётся кодом из board.gd: Token.new(), затем setup(...)

var sprite := Sprite2D.new()
var is_human := false
var panic := false
var hp := 1                      # показанное HP: меняется в момент удара, а не раньше
var max_hp := 1
var size := 52.0
var _bar := Color.WHITE

func setup(tex: Texture2D, cell_px: float, human: bool, bar: Color) -> void:
	size = cell_px
	is_human = human
	_bar = bar
	sprite.texture = tex
	var s := size * 0.9 / maxf(tex.get_width(), tex.get_height())
	sprite.scale = Vector2(s, s)
	add_child(sprite)

func set_hp(value: int, maximum: int) -> void:
	hp = value
	max_hp = maxi(maximum, 1)
	queue_redraw()

func hurt(dmg: int) -> void:
	set_hp(hp - dmg, max_hp)

func _draw() -> void:
	var half := size / 2.0
	draw_rect(Rect2(-half * 0.8, half - 7, size * 0.8, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-half * 0.8, half - 7, size * 0.8 * clampf(float(hp) / max_hp, 0.0, 1.0), 4), _bar)
	if panic:
		var p := Vector2(0, -half + 2)
		draw_circle(p, 9, Color(1.0, 0.82, 0.2))
		draw_string(ThemeDB.fallback_font, p + Vector2(-10, 6), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Color.BLACK)
