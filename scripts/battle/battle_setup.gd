extends RefCounted
# Связь боя с кампанией: собрать бой из GameState (армия, BattleType узла) и вернуть
# итог в армию. Статические функции.
# Подключение: const BattleSetup = preload("res://scripts/battle/battle_setup.gd")

const BC = preload("res://scripts/battle/battle_config.gd")
const Arenas = preload("res://scripts/battle/arenas.gd")
const BattleState = preload("res://scripts/battle/battle_state.gd")

# Новый бой: арена (пока одна), защитники из BattleType узла (или арены), армия поштучно
static func create() -> RefCounted:
	var arena: Dictionary = Arenas.CABIN
	var defenders := []
	var strength := 1.0
	if GameState.pending_battle != "":
		var bt = load(GameState.pending_battle)
		defenders = bt.defenders
		strength = bt.strength
	else:
		for key in arena.defenders:
			defenders.append(load("res://resources/humans/%s.tres" % key))
	return BattleState.new(arena.rows, arena.posts, defenders, strength, army_units())

# Армия → клеточные фишки. HP — в пропорции к HP армии; таланты на скорость/укус дают
# ту же прибавку в процентах. Нет армии (F6) — тестовая из конфига (army_id = -1).
static func army_units() -> Array:
	var out := []
	for z in GameState.army:
		var t: Dictionary = GameState.ztype(z.type)
		var g: Dictionary = BC.ZOMBIE.get(z.type, BC.ZOMBIE["normal"])
		var speed: float = (t.speed + GameState.talent_stat_add(z.type, "speed")) / t.speed
		var bite: float = float(t.bite_damage + GameState.talent_stat_add(z.type, "bite_damage")) / t.bite_damage
		out.append({ "army_id": z.id, "type": z.type,
			"hp": maxi(1, roundi(float(z.hp) * g.hp / t.max_hp)),
			"max_hp": maxi(1, roundi(float(z.max_hp) * g.hp / t.max_hp)),
			"move": maxi(1, roundi(g.move * speed)),
			"bite": maxi(1, roundi(g.bite * bite)),
			"struct_mult": roundi((BC.FAT_STRUCT_MULT if z.type == "fat" else 1) * GameState.door_mult(z.type)) })
	if out.is_empty():
		for type in BC.TEST_ARMY:
			var g: Dictionary = BC.ZOMBIE[type]
			for i in BC.TEST_ARMY[type]:
				out.append({ "army_id": -1, "type": type, "hp": g.hp, "max_hp": g.hp, "move": g.move,
					"bite": g.bite, "struct_mult": BC.FAT_STRUCT_MULT if type == "fat" else 1 })
	return out

# Итог боя → армия: погибшие вычёркиваются, раненые сохраняют раны (обратно в HP армии).
# Заражённые (army_id -1) в армию не идут — они только на этот бой.
static func apply_to_army(s) -> void:
	for aid in s.casualties:
		GameState.remove_zombie(aid)
	for z in s.zombies:
		if z.army_id < 0 or z.hp == z.hp_start:
			continue
		var az: Dictionary = GameState.zombie_by_id(z.army_id)
		if az.is_empty():
			continue
		var g: Dictionary = BC.ZOMBIE.get(z.type, BC.ZOMBIE["normal"])
		var t: Dictionary = GameState.ztype(z.type)
		az.hp = clampi(roundi(float(z.hp) * t.max_hp / g.hp), 1, az.max_hp)

# Биомасса за победу (старая формула): (база + за каждого убитого) × талант «Пожиратели»
static func win_biomass(s) -> int:
	return int(round((Config.BIO_WIN_BASE + Config.BIO_PER_KILL * s.killed) * GameState.biomass_mult()))
