extends Node

# Autoload "Config" — балансные числа кампании (награды, биомасса).
# Регистрация: Project Settings → Autoload → путь res://scripts/autoload/config.gd,
# имя "Config", Enable. Доступ из любого скрипта: Config.BIO_WIN_BASE и т.п.
# Числа боя (клетки, свет, натиск, паника…) — в scripts/battle/battle_config.gd.
# Статы типов зомби для армии — в GameState.ZTYPE, людей — в resources/humans/*.tres.

# Биомасса за победу (черновик, калибруется плейтестом):
# base + per_kill * (убито защитников, не сбежавших)
const BIO_WIN_BASE := 8
const BIO_PER_KILL := 4

# Экран награды после боя (выбор 1 из вариантов)
const REWARD_HEAL := 30              # фикс. хил ОДНОМУ выбранному зомби
const REWARD_CORPSE_BIO := 5         # биомассы за каждый труп защитника
const REWARD_SACRIFICE_HEAL := 15    # хил остальным при жертве своего зомби

# Узлы карты без боя
const LOOT_BIOMASS := 5              # находка: биомассы
