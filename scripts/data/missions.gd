class_name Missions
extends RefCounted
## Mission templates. Three are always active (`Game.missions`); a finished one pays its reward at the end of the
## run and is replaced by the next template in this order (`Game.mission_seq`) whose kind is not already active and
## whose island is ready. Missions are data, like biomes, skins and levels.
##
## Kinds: skim, coins, pass (any hazard), pass_<cause> (one hazard), stars (new level stars),
## endless_island (highest island reached in one endless run), level_clean (level finished without Lanjut).

const LIST := [
	{"id": "skim_10", "kind": "skim", "target": 10, "reward": 50, "text": "NYEREMPET %d kali"},
	{"id": "coins_150", "kind": "coins", "target": 150, "reward": 50, "text": "Kumpulkan %d koin"},
	{"id": "pass_5", "kind": "pass", "target": 5, "reward": 75, "text": "Lolos %d rintangan"},
	{"id": "pass_layangan_3", "kind": "pass_layangan", "target": 3, "reward": 75, "text": "Lewati %d layangan", "island": "sawah"},
	{"id": "stars_3", "kind": "stars", "target": 3, "reward": 75, "text": "Dapatkan %d bintang"},
	{"id": "pass_ombak_3", "kind": "pass_ombak", "target": 3, "reward": 75, "text": "Lolos %d ombak", "island": "pantai"},
	{"id": "skim_25", "kind": "skim", "target": 25, "reward": 100, "text": "NYEREMPET %d kali"},
	{"id": "level_clean_1", "kind": "level_clean", "target": 1, "reward": 75, "text": "Selesaikan %d level tanpa Lanjut"},
	{"id": "coins_400", "kind": "coins", "target": 400, "reward": 100, "text": "Kumpulkan %d koin"},
	{"id": "endless_island_3", "kind": "endless_island", "target": 3, "reward": 100, "text": "Sampai pulau ke-%d di Tanpa Batas"},
	{"id": "pass_hutan_2", "kind": "pass_hutan", "target": 2, "reward": 75, "text": "Lolos %d lorong hutan", "island": "hutan"},
	{"id": "pass_15", "kind": "pass", "target": 15, "reward": 150, "text": "Lolos %d rintangan"},
	{"id": "stars_9", "kind": "stars", "target": 9, "reward": 150, "text": "Dapatkan %d bintang"},
	{"id": "skim_50", "kind": "skim", "target": 50, "reward": 150, "text": "NYEREMPET %d kali"},
	{"id": "level_clean_3", "kind": "level_clean", "target": 3, "reward": 150, "text": "Selesaikan %d level tanpa Lanjut"},
	{"id": "coins_1000", "kind": "coins", "target": 1000, "reward": 200, "text": "Kumpulkan %d koin"},
	{"id": "endless_island_5", "kind": "endless_island", "target": 5, "reward": 200, "text": "Sampai pulau ke-%d di Tanpa Batas"},
]


static func all() -> Array:
	return LIST


static func get_mission(id: String) -> Dictionary:
	for m in LIST:
		if m.id == id:
			return m
	return {}


## A mission tied to an island is only offered once that island's hazard exists.
static func available(m: Dictionary) -> bool:
	var isl: String = m.get("island", "")
	return isl == "" or Levels.READY_ISLANDS.has(isl)


static func label(m: Dictionary) -> String:
	return String(m.text) % int(m.target)
