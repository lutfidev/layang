extends Node
## Headless test runner: `godot --headless --path . res://tests/run_tests.tscn [-- --only=name]`
## Collects `test_*` methods from every `tests/test_*.gd` script (each extends RefCounted,
## gets `runner` set to this node, returns "" on success or a failure message).


## Counts script errors so a test that hits a runtime error fails instead of silently passing.
class ErrorCounter:
	extends Logger
	var count := 0
	var last := ""

	func _log_error(_function: String, _file: String, _line: int, _code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT or error_type == ERROR_TYPE_ERROR:
			count += 1
			last = rationale if rationale != "" else _code


func _ready() -> void:
	Game.dev["nosave"] = true
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var passed := 0
	var failed := 0
	var files: Array = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL ", f, ": script failed to load")
			continue
		for m in script.get_script_method_list():
			var mname: String = m.name
			if not mname.begins_with("test_"):
				continue
			if only != "" and not mname.contains(only):
				continue
			var t: Object = script.new()
			t.set("runner", self)
			var errors_before := errors.count
			var res: Variant = t.call(mname)
			if errors.count > errors_before and res is String and res == "":
				res = "script error: " + errors.last
			for c in get_children():
				remove_child(c)
				c.free()
			if res is String and res == "":
				passed += 1
				print("PASS ", mname)
			else:
				failed += 1
				print("FAIL ", mname, ": ", res)
	print("TESTS passed=%d failed=%d" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
