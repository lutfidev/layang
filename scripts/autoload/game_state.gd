extends Node
## Global game state: save data, economy, settings, scene transitions and dev flags.
## Autoloaded as `Game`.

signal coins_changed(value: int)
signal skin_changed(skin_id: String)
signal settings_changed

const SAVE_PATH := "user://layang_save.json"
const DAILY_REWARDS := [50, 75, 100, 150, 200, 300, 500]

var coins: int = 0
var best_score: int = 0
var best_distance: int = 0
var best_island: int = 0
var total_runs: int = 0
var owned_skins: Array = ["pipit"]
var equipped_skin: String = "pipit"
var sound_on: bool = true
var music_on: bool = true
var ads_removed: bool = false
var tutorial_done: bool = false
var last_daily: String = ""
var daily_streak: int = 0

## Dev / test flags parsed from command line (after `--`).
var dev := {}

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_setup_input()
	load_game()
	_build_fade()
	if dev.has("shot"):
		_schedule_screenshot()


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	if not InputMap.has_action("fly"):
		InputMap.add_action("fly")
		for key in [KEY_SPACE, KEY_UP, KEY_W]:
			var k := InputEventKey.new()
			k.physical_keycode = key
			InputMap.action_add_event("fly", k)
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var p := InputEventKey.new()
		p.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", p)


# ---------------------------------------------------------------- economy

func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)
	coins_changed.emit(coins)
	save_game()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	save_game()
	return true


func owns(skin_id: String) -> bool:
	return owned_skins.has(skin_id)


func unlock_skin(skin_id: String) -> void:
	if not owned_skins.has(skin_id):
		owned_skins.append(skin_id)
	save_game()


func equip_skin(skin_id: String) -> void:
	if owns(skin_id):
		equipped_skin = skin_id
		skin_changed.emit(skin_id)
		save_game()


func submit_run(score: int, distance: int, island: int) -> bool:
	total_runs += 1
	var is_record := score > best_score
	best_score = max(best_score, score)
	best_distance = max(best_distance, distance)
	best_island = max(best_island, island)
	save_game()
	return is_record


# ---------------------------------------------------------------- daily reward

func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func can_claim_daily() -> bool:
	return last_daily != _today()


func next_daily_amount() -> int:
	var streak := daily_streak
	if not _claimed_yesterday():
		streak = 0
	return DAILY_REWARDS[min(streak, DAILY_REWARDS.size() - 1)]


func _claimed_yesterday() -> bool:
	if last_daily == "":
		return false
	var now := Time.get_unix_time_from_system()
	var y := Time.get_date_dict_from_unix_time(int(now) - 86400)
	return last_daily == "%04d-%02d-%02d" % [y.year, y.month, y.day]


func claim_daily() -> int:
	if not can_claim_daily():
		return 0
	if not _claimed_yesterday():
		daily_streak = 0
	var amount: int = DAILY_REWARDS[min(daily_streak, DAILY_REWARDS.size() - 1)]
	daily_streak += 1
	last_daily = _today()
	add_coins(amount)
	return amount


# ---------------------------------------------------------------- settings

func toggle_sound() -> void:
	sound_on = not sound_on
	settings_changed.emit()
	save_game()


func toggle_music() -> void:
	music_on = not music_on
	settings_changed.emit()
	save_game()


# ---------------------------------------------------------------- save / load

func save_game() -> void:
	if dev.has("nosave"):   # tests / balance sims must not touch the player's save
		return
	var data := {
		"coins": coins, "best_score": best_score, "best_distance": best_distance,
		"best_island": best_island, "total_runs": total_runs,
		"owned_skins": owned_skins, "equipped_skin": equipped_skin,
		"sound_on": sound_on, "music_on": music_on, "ads_removed": ads_removed,
		"tutorial_done": tutorial_done, "last_daily": last_daily, "daily_streak": daily_streak,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if dev.has("fresh") or not FileAccess.file_exists(SAVE_PATH):
		if dev.has("coins"):
			coins = int(dev["coins"])
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", 0))
	best_score = int(parsed.get("best_score", 0))
	best_distance = int(parsed.get("best_distance", 0))
	best_island = int(parsed.get("best_island", 0))
	total_runs = int(parsed.get("total_runs", 0))
	owned_skins = parsed.get("owned_skins", ["pipit"])
	equipped_skin = str(parsed.get("equipped_skin", "pipit"))
	sound_on = bool(parsed.get("sound_on", true))
	music_on = bool(parsed.get("music_on", true))
	ads_removed = bool(parsed.get("ads_removed", false))
	tutorial_done = bool(parsed.get("tutorial_done", false))
	last_daily = str(parsed.get("last_daily", ""))
	daily_streak = int(parsed.get("daily_streak", 0))
	if dev.has("coins"):
		coins = int(dev["coins"])


# ---------------------------------------------------------------- scene transitions

func _build_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 120
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.09, 0.07, 0.16, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


func goto(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade_rect, "color:a", 1.0, 0.28)
	await t.finished
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade_rect, "color:a", 0.0, 0.35)
	await t2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


# ---------------------------------------------------------------- dev flags

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		if s.contains("="):
			var kv := s.split("=", true, 1)
			dev[kv[0]] = kv[1]
		else:
			dev[s] = true


func dev_int(key: String, default_value: int) -> int:
	return int(dev[key]) if dev.has(key) else default_value


func _schedule_screenshot() -> void:
	var delay := float(dev.get("shot-delay", "3.0"))
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(str(dev["shot"]))
	print("SHOT saved ", dev["shot"])
	if not dev.has("keep"):
		get_tree().quit()
