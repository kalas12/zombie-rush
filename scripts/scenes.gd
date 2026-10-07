extends RefCounted
# Пути всех сцен игры — в одном месте. Переименовал/переложил сцену → правь только тут.
# Подключение: const Scenes = preload("res://scripts/scenes.gd")

const MAP := "res://scenes/forest_map.tscn"
const START_ARMY := "res://scenes/start_army.tscn"
const SQUADS := "res://scenes/squads.tscn"
const TALENTS := "res://scenes/talents.tscn"
const EVENT := "res://scenes/event.tscn"
const STOP := "res://scenes/node_stop.tscn"     # лагерь / находка
const CITY := "res://scenes/city.tscn"
const REWARD := "res://scenes/reward.tscn"
const DEFEAT := "res://scenes/defeat.tscn"

const BATTLE := "res://scenes/battle/battle.tscn"   # все бои карты; состав людей — из BattleType узла
