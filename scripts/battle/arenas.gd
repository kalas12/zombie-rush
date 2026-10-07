extends RefCounted
# Арены боя — ASCII-карты. Новая арена = новый словарь (правка строк).
# Подключение: const Arenas = preload("res://scripts/battle/arenas.gd")
#
# .  земля   s  земля, где можно выставлять зомби   _  пол   #  стена   W  окно
# D  проём (открыт)   F  костёр   t  сосна   p  куст   c  камень
# (препятствия t/p/c: не пройти, закрывают обзор; окно обзор не закрывает)
#
# posts — клетки постов защитников по порядку (BattleType.defenders[i] → posts[i]).
# defenders — кто стоит на постах, если у узла нет BattleType (ключи resources/humans/*.tres).

const CABIN := {
	"rows": [
		"sssssssssssssssss",
		"sssssssssssssssss",
		"ss.............ss",
		"ss..t.......t..ss",
		"ss....#####....ss",
		"ss....#___#....ss",
		"ss....W___W....ss",
		"ss....#___#....ss",
		"ss....##D##....ss",
		"ss.......F.....ss",
		"ss..p.......c..ss",
		"ss.............ss",
		"sssssssssssssssss",
		"sssssssssssssssss",
	],
	# стрелки у окон, ножевик у проёма, часовой справа от костра
	"posts": [Vector2i(7, 6), Vector2i(9, 6), Vector2i(8, 7), Vector2i(10, 9)],
	"defenders": ["shooter", "shooter", "melee", "shotgunner"],
}
