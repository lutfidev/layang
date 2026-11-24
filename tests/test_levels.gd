extends RefCounted
## Adventure levels: level data, terrain/bird/world following a level, stars, unlocks, level screens, map.

var runner: Node
const DT := 1.0 / 120.0


func _level_world(lv: Dictionary, hazards: bool = true) -> World:
	var w := World.new()
	w.level = lv
	w.hazards = hazards
	w.input_enabled = false
	runner.add_child(w)
	return w


func _free(w: World) -> void:
	runner.remove_child(w)
	w.free()


## Signature hazards on island 0 for the level's biome.
func _hazards_on_first(w: World) -> int:
	var t := w.terrain
	var list: Array = []
	match Biomes.get_biome(t.start_island).id:
		"sawah": list = t.kites
		"pantai": list = t.bays
		"hutan": list = t.canopies
	return list.filter(func(it: Dictionary) -> bool: return int(it.island) == 0).size()


## Number of hills on island 0 = valley keys strictly between the entry keys and the launch ramp
## (bays add 4 keys for one hill, canopies/plain hills add 2).
func _hills_on_first(w: World) -> int:
	var t := w.terrain
	var n := 0
	var first_bay := 0
	for i in t.keys_x.size():
		if t.keys_island[i] != 0:
			break
		n += 1
	for b in t.bays:
		if int(b.island) == 0:
			first_bay += 1
	# island 0 keys: 3 entry + hills (2 keys each, bays 4) + ramp + gate + sea floor
	return (n - 3 - 3 - first_bay * 4) / 2 + first_bay


# ---------------------------------------------------------------- data + world (Task 1)

func test_eighteen_levels() -> String:
	var all := Levels.all()
	if all.size() != 18:
		return "size %d" % all.size()
	var ids := {}
	for i in all.size():
		var lv: Dictionary = all[i]
		var biome := Biomes.get_biome(i / 3)
		if int(lv.island) != i / 3 or int(lv.tier) != i % 3:
			return "level %d: island %d tier %d" % [i, int(lv.island), int(lv.tier)]
		if lv.id != "%s-%d" % [biome.id, i % 3 + 1]:
			return "level %d: id %s" % [i, lv.id]
		var want: String = String(biome.id).capitalize() + " " + Levels.TIER_NAMES[i % 3]
		if lv.name != want:
			return "level %d: name %s, want %s" % [i, lv.name, want]
		ids[lv.id] = true
		if Levels.index_of(lv.id) != i or Levels.get_level(lv.id) != lv:
			return "lookup broken for %s" % lv.id
	return "" if ids.size() == 18 else "ids not unique"


func test_level_hazard_counts() -> String:
	for lv in Levels.all():
		if not Levels.is_ready(lv):
			continue
		var w := _level_world(lv)
		var tier: Dictionary = Levels.TIERS[int(lv.tier)]
		var n := _hazards_on_first(w)
		var hills := _hills_on_first(w)
		var island := w.terrain.start_island
		_free(w)
		if island != int(lv.island):
			return "%s: start island %d" % [lv.id, island]
		if n != int(tier.hazards):
			return "%s: %d hazards, want %d" % [lv.id, n, int(tier.hazards)]
		if hills != int(tier.hills):
			return "%s: %d hills, want %d" % [lv.id, hills, int(tier.hills)]
	return ""


func test_endless_unchanged() -> String:
	# recorded on main before levels existed: island count of keys, last key x, kites, bays, canopies
	var want := ["0:56:30938.545:2:3:0", "1:56:32680.744:0:3:2", "2:50:31895.193:0:0:2"]
	for first in [0, 1, 2]:
		var w := World.new()
		w.run_seed = 4242
		w.start_island = first
		runner.add_child(w)
		var t := w.terrain
		var got := "%d:%d:%.3f:%d:%d:%d" % [first, t.keys_x.size(), t.keys_x[t.keys_x.size() - 1], t.kites.size(), t.bays.size(), t.canopies.size()]
		var speed := w.bird.speed_scale
		_free(w)
		if got != want[first]:
			return "start %d: %s, want %s" % [first, got, want[first]]
		if speed != 1.0:
			return "endless speed_scale %f" % speed
	return ""


func test_badai_speed_and_storm() -> String:
	var w := _level_world(Levels.get_level("sawah-3"))
	var s := w.bird.speed_scale
	var amb: String = w.current_biome().ambient
	_free(w)
	if absf(s - 1.12) > 0.001:
		return "speed_scale %f" % s
	if amb != "rain":
		return "ambient %s" % amb
	var p := _level_world(Levels.get_level("sawah-1"))
	var amb2: String = p.current_biome().ambient
	var s2 := p.bird.speed_scale
	_free(p)
	return "" if amb2 == "seeds" and s2 == 1.0 else "pagi: ambient %s speed %f" % [amb2, s2]
