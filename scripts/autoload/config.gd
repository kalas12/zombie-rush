extends Node

# Autoload "Config" — единственный источник балансных чисел (стандарт «08», п.4, 7).
# Регистрация: Project Settings → Autoload → путь res://scripts/autoload/config.gd,
# имя "Config", Enable. Доступ из любого скрипта: Config.DAWN_TIME и т.п.
# Числа — из «02 — Геймплей» и «04 — Контент».

# ── Зомби ────────────────────────────────────────────────────────
# Статы типов зомби (hp/speed/урон/…) переехали в resources/zombies/*.tres.
const ZOMBIE_RETARGET_INTERVAL := 0.5 # как часто пере-выбирать ближайшую цель

# ── Защитники: общее поведение (не зависит от типа) ──────────────
const HUMAN_MOVE_SPEED := 70.0
const MELEE_CHASE_RANGE := 340.0      # дальше этого ближник не гонится
const SHOOTER_RETREAT_RANGE := 150.0  # при перезарядке пятится, если зомби ближе
const PANIC_HP_FRAC := 0.3            # ниже этой доли HP — паника и бегство
const PANIC_SPEED := 108.0            # скорость бегства (быстрее зомби)
# Статы типов защитников (hp/урон/дальность/…) — в resources/humans/*.tres

# ── Бой ──────────────────────────────────────────────────────────
const DAWN_TIME := 360.0              # 6:00 до рассвета
const NO_SPAWN_RADIUS := 140.0        # ближе этого к защитникам спавнить нельзя
# Запас пачек по типам зомби (packs / pack_size) — в resources/zombies/*.tres
