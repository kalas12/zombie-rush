extends Control

# Экран события-вопроса (Фаза 2). Текст ситуации + 2-3 кнопки выбора.
# По одному захардкоженному событию на узел карты (id из GameState.pending_node).
# Исходы пока текст-заглушки — реальные эффекты (лут / армия) в Фазе 3.
# Разметка строится кодом.

const EVENTS := {
	"n3": {
		"title": "Брошенный лагерь охотников",
		"text": "Кострище ещё тёплое, вокруг рюкзаки и ящики. Быстрый обыск даст припасы, но охотники ставят капканы.",
		"choices": [
			{ "label": "Обыскать лагерь", "outcome": "Нашёл припасы (+лут в Фазе 3). Один зомби попал в капкан." },
			{ "label": "Пройти мимо", "outcome": "Идёшь дальше, не рискуя." },
		],
	},
	"n8": {
		"title": "Свежий труп",
		"text": "У тропы лежит убитый человек — не твоя работа. Тело целое.",
		"choices": [
			{ "label": "Поднять зомби", "outcome": "Поднял слабого зомби в армию (+юнит в Фазе 3)." },
			{ "label": "Оставить", "outcome": "Оставил труп гнить." },
		],
	},
	"n11": {
		"title": "Костёр-ритуал",
		"text": "Древние камни, чёрное пятно старого огня. Орда чует силу этого места.",
		"choices": [
			{ "label": "Пожертвовать зомби", "outcome": "Один зомби сгорел — остальные усилены (Фаза 3)." },
			{ "label": "Уйти", "outcome": "Не трогаешь камни." },
		],
	},
}

const UI = preload("res://scripts/ui.gd")

const FALLBACK_ID := "n3"   # если сцену открыли не с карты (F6)

func _ready() -> void:
	var eid: String = GameState.pending_node
	if not EVENTS.has(eid):
		eid = FALLBACK_ID
	_build_ui(EVENTS[eid])

func _build_ui(ev) -> void:
	var vb := UI.card(self, 620, 28, 16)
	vb.add_child(UI.title(ev.title))
	vb.add_child(UI.body(ev.text, 560))
	vb.add_child(UI.gap(8))
	for c in ev.choices:
		vb.add_child(UI.button(c.label, _on_choice.bind(c.outcome), 18))

func _on_choice(outcome: String) -> void:
	print("[event] ", outcome)
	GameState.finish_node()
