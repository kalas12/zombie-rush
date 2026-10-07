class_name HumanType
extends Resource

# Данные одного типа защитника (пошаговый бой). Новый тип = новый .tres в resources/humans/.
# Общие правила (паника, натиск, окружение) — в scripts/battle/battle_config.gd.

@export var display_name := "Защитник"
@export var texture: Texture2D
@export var max_hp := 30
@export var reach := 1               # дальность атаки в клетках во все 8 сторон; 1 = соседняя, 0 = не атакует
@export var damage := 3              # урон за удар/выстрел
@export var walks := false           # бить некого → шаг к зомби на освещённой клетке
@export var coward := false          # паникует, как только увидел зомби (мирный)
