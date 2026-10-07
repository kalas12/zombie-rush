extends Control

# Экран финала этапа (узел "city", n13). Пока: итог + рестарт забега.
# Позже — концовка Этапа 1 и переход к Этапу 2 «Город». Разметка строится кодом.

const UI = preload("res://scripts/ui.gd")

func _ready() -> void:
	var vb := UI.card(self, 560, 32, 18)
	vb.add_child(UI.title("Граница города", 30, UI.TITLE, true))
	vb.add_child(UI.body("Этап 1 «Лес» пройден — орда вышла из леса к городу.\n\n(Этап 2 «Город» — позже.)", 500, true))
	vb.add_child(UI.gap(10))
	vb.add_child(UI.button("Начать забег заново", GameState.restart_run, 18))
