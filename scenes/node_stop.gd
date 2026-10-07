extends Control

# Узлы-стоянки: находка (loot) и лагерь (camp). Заглушки Фазы 2.
# loot даёт биомассу (реальный счётчик), camp — пока без эффекта (лечить нечего до армии).
# Разметка строится кодом. Полное наполнение (лечение/апгрейд/риск) — Фаза 4.

const UI = preload("res://scripts/ui.gd")

func _ready() -> void:
	var title := "Стоянка"
	var text := "Тихое место у ручья. Орда переводит дух."
	var btn := "Дальше"
	var gain := 0
	if GameState.pending_type == "loot":
		title = "Находка"
		text = "В подлеске — брошенный тайник охотников."
		btn = "Забрать  (+%d биомассы)" % Config.LOOT_BIOMASS
		gain = Config.LOOT_BIOMASS

	var vb := UI.card(self, 560, 28, 16)
	vb.add_child(UI.title(title))
	vb.add_child(UI.body(text, 500))
	vb.add_child(UI.gap(8))
	vb.add_child(UI.button(btn, _on_go.bind(gain), 18))

func _on_go(gain: int) -> void:
	GameState.biomass += gain
	GameState.finish_node()
