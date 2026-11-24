extends RefCounted
## Missions: templates, progress from game events, rewards once at run end, panels on menu/pause/results.

var runner: Node
const DT := 1.0 / 120.0


func _kinds(list: Array) -> Array:
	var out: Array = []
	for a in list:
		out.append(Missions.get_mission(a.id).kind)
	return out


func _fresh() -> Dictionary:
	var keep := Game.save_data()
	Game.missions = []
	Game.mission_seq = 0
	Game.ensure_missions()
	return keep


func _distinct(list: Array) -> bool:
	var k := _kinds(list)
	for i in k.size():
		if k.find(k[i]) != i:
			return false
	return true


## Replaces the active missions with the given template ids (progress 0).
func _force(ids: Array) -> void:
	Game.missions = []
	for id in ids:
		Game.missions.append({"id": id, "progress": 0})


# ---------------------------------------------------------------- data + Game state (Task 1)

func test_mission_starts_with_three_distinct() -> String:
	var keep := _fresh()
	var r := ""
	if Game.missions.size() != 3:
		r = "missions %s" % [Game.missions]
	elif not _distinct(Game.missions):
		r = "duplicate kinds %s" % [_kinds(Game.missions)]
	else:
		for a in Game.missions:
			if not Missions.available(Missions.get_mission(a.id)):
				r = "unavailable %s" % a.id
		if _kinds(Game.missions) != ["skim", "coins", "pass"]:
			r = "first missions %s, want skim/coins/pass" % [_kinds(Game.missions)]
	Game.apply_save(keep)
	return r


func test_mission_templates_valid() -> String:
	var ids := {}
	for m in Missions.all():
		if ids.has(m.id):
			return "duplicate id %s" % m.id
		ids[m.id] = true
		if int(m.target) <= 0 or int(m.reward) <= 0:
			return "%s target/reward" % m.id
		if not String(m.text).contains("%d"):
			return "%s text has no %%d" % m.id
		if Missions.label(m) != String(m.text) % int(m.target):
			return "%s label" % m.id
	for k in ["skim", "coins", "pass", "pass_ombak", "pass_layangan", "pass_hutan", "stars", "endless_island", "level_clean"]:
		if Missions.all().filter(func(m: Dictionary) -> bool: return m.kind == k).is_empty():
			return "no template for %s" % k
	return ""


func test_mission_event_progress() -> String:
	var keep := _fresh()
	Game.mission_event("skim", 3)
	var r := ""
	for a in Game.missions:
		var want := 3 if Missions.get_mission(a.id).kind == "skim" else 0
		if int(a.progress) != want:
			r = "%s progress %d, want %d" % [a.id, a.progress, want]
	Game.apply_save(keep)
	return r


func test_mission_endless_island_is_max() -> String:
	var keep := Game.save_data()
	_force(["endless_island_3"])
	Game.mission_max("endless_island", 2)
	Game.mission_max("endless_island", 1)
	var p := int(Game.missions[0].progress)
	Game.apply_save(keep)
	return "" if p == 2 else "progress %d, want 2" % p


func test_mission_settle_pays_once() -> String:
	var keep := _fresh()
	var coins0 := Game.coins
	var skim_id: String = Game.missions[0].id
	var m := Missions.get_mission(skim_id)
	Game.mission_event("skim", int(m.target))
	var done := Game.settle_missions()
	var gain := Game.coins - coins0
	var again := Game.settle_missions()
	var r := ""
	if done.size() != 1 or done[0].id != skim_id or int(done[0].reward) != int(m.reward):
		r = "settle %s" % [done]
	elif gain != int(m.reward):
		r = "coins +%d, want +%d" % [gain, m.reward]
	elif not again.is_empty():
		r = "second settle %s" % [again]
	elif Game.missions.size() != 3 or Game.missions.any(func(a: Dictionary) -> bool: return a.id == skim_id):
		r = "not replaced %s" % [Game.missions]
	Game.apply_save(keep)
	return r


func test_mission_replacement_distinct_and_available() -> String:
	var keep := _fresh()
	var r := ""
	for n in 30:
		var a: Dictionary = Game.missions[n % 3]
		var m := Missions.get_mission(a.id)
		if m.kind == "endless_island":
			Game.mission_max(m.kind, int(m.target))
		else:
			Game.mission_event(m.kind, int(m.target))
		if Game.settle_missions().size() != 1:
			r = "round %d: settle did not pay %s" % [n, a.id]
			break
		if Game.missions.size() != 3 or not _distinct(Game.missions):
			r = "round %d: %s" % [n, [_kinds(Game.missions)]]
			break
		for b in Game.missions:
			if not Missions.available(Missions.get_mission(b.id)):
				r = "round %d: unavailable %s" % [n, b.id]
	Game.apply_save(keep)
	return r


func test_mission_locked_island_never_offered() -> String:
	for m in Missions.all():
		var isl: String = m.get("island", "")
		if isl != "" and not Levels.READY_ISLANDS.has(isl) and Missions.available(m):
			return "%s available for locked %s" % [m.id, isl]
	var fake := {"id": "x", "kind": "pass_lava", "target": 3, "reward": 75, "text": "Lolos %d lava", "island": "gunung"}
	return "" if not Missions.available(fake) else "gunung mission available"


func test_mission_old_save() -> String:
	var keep := Game.save_data()
	var old := keep.duplicate(true)
	old.erase("missions")
	old.erase("mission_seq")
	Game.apply_save(old)
	var r := ""
	if Game.missions.size() != 3 or not _distinct(Game.missions):
		r = "old save missions %s" % [Game.missions]
	var saved := Game.save_data()
	Game.apply_save(saved)
	if r == "" and Game.save_data().missions != saved.missions:
		r = "missions did not round-trip"
	Game.apply_save({"missions": [{"id": "nope", "progress": 4}, "junk"]})
	if r == "" and (Game.missions.size() != 3 or Game.missions.any(func(a: Dictionary) -> bool: return a.id == "nope")):
		r = "bad save entries kept %s" % [Game.missions]
	Game.apply_save(keep)
	return r
