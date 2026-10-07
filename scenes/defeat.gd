extends Control

# Экран поражения (Фаза 3). Забег окончен — кнопка «Начать заново».
# GameState ещё не сброшен: показываем итог, сбрасываем по кнопке.

const UI = preload("res://scripts/ui.gd")

func _ready() -> void:
	var reached: String = GameState.current_node if GameState.current_node != "" else "?"
	var vb := UI.card(self, 520, 32, 16, Color("1a1013"), Color("4a2630"))   # красноватая карточка
	vb.add_child(UI.title("Орда разбита", 30, UI.BAD, true))
	vb.add_child(UI.body("Забег окончен.\nДошёл до узла %s   ·   было %d зомби   ·   биомасса %d" % [
		reached, GameState.army.size(), GameState.biomass
	], 460, true))
	vb.add_child(UI.gap(10))
	vb.add_child(UI.button("Начать заново", GameState.restart_run, 18))
