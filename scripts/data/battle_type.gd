class_name BattleType
extends Resource

# Состав одного боя. Новый бой = новый .tres в resources/battles/, узел карты ссылается на него.
# defenders[i] встаёт на i-й пост арены (scripts/battle/arenas.gd, поле "posts").
# Защитников меньше, чем постов → лишние посты пустые; больше → лишние не выходят.

@export var display_name := "Бой"
@export var defenders: Array[HumanType] = []
@export var strength := 1.0          # множитель HP и урона людей (сложнее выше по карте)
