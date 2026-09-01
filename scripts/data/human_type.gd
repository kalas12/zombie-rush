class_name HumanType
extends Resource

# Данные одного типа защитника. Новый тип = новый .tres в resources/humans/.
# Общее поведение (скорость, паника, дистанции преследования) — в Config.

@export var display_name := "Защитник"
@export var texture: Texture2D
@export var melee := false          # true = бьёт вплотную, false = стрелок
@export var max_hp := 50
@export var damage := 10
@export var fire_rate := 0.5         # секунд между выстрелами/ударами
@export var attack_range := 220.0
@export var max_ammo := 10           # -1 = без патронов (ближний бой)
@export var reload_time := 2.0
