class_name ZombieType
extends Resource

# Данные одного типа зомби. Новый тип = новый .tres в resources/zombies/,
# БЕЗ веток if по коду (стандарт «08», п.2, 4).

@export var display_name := "Зомби"
@export var texture: Texture2D
@export var max_hp := 30
@export var speed := 90.0
@export var bite_damage := 8
@export var bite_cooldown := 0.7   # секунд между укусами
@export var attack_radius := 32.0  # с этого расстояния до цели уже кусает
@export var cost := 3              # для сортировки кнопок (дешёвые слева)
@export var packs := 4            # сколько пачек этого типа доступно игроку
@export var pack_size := 4        # зомби в одной пачке (один клик)
