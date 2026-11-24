class_name Levels
extends RefCounted
## The 18 adventure levels: 6 islands x 3 tiers (Pagi, Ramai, Badai). A level is one island with a fixed
## seed, from its start to its candi gate. Levels are data, like biomes and skins.

const TIER_NAMES := ["Pagi", "Ramai", "Badai"]
const TIERS := [
	{"hills": 8, "hazards": 1, "speed": 1.0, "storm": false},
	{"hills": 10, "hazards": 2, "speed": 1.0, "storm": false},
	{"hills": 12, "hazards": 3, "speed": 1.12, "storm": true},
]
## Islands whose signature hazard exists; the others show "Segera hadir" on the map.
const READY_ISLANDS := ["sawah", "pantai", "hutan"]
## Fixed seed per level, in level order (picked so every level is completable and looks distinct).
const SEEDS := [1000, 1007, 1014, 1021, 1028, 1035, 1042, 1049, 1056, 1063, 1070, 1077, 1084, 1091, 1098, 1105, 1112, 1119]

static var _list: Array = []


static func all() -> Array:
	if _list.is_empty():
		for i in 18:
			var biome := Biomes.get_biome(i / 3)
			_list.append({
				"id": "%s-%d" % [biome.id, i % 3 + 1],
				"island": i / 3,
				"tier": i % 3,
				"name": String(biome.id).capitalize() + " " + TIER_NAMES[i % 3],
				"seed": SEEDS[i],
			})
	return _list


static func get_level(id: String) -> Dictionary:
	var i := index_of(id)
	return all()[i] if i >= 0 else {}


static func index_of(id: String) -> int:
	var l := all()
	for i in l.size():
		if l[i].id == id:
			return i
	return -1


static func is_ready(lv: Dictionary) -> bool:
	return READY_ISLANDS.has(Biomes.get_biome(int(lv.island)).id)


static func tier_of(lv: Dictionary) -> Dictionary:
	return TIERS[int(lv.tier)]
