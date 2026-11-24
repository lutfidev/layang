extends Node
## Monetisation facade (autoloaded as `Ads`).
##
## Right now every call runs a DEMO flow (a fake ad overlay / instant purchase) so the
## whole game loop is testable. To go live, replace the bodies marked `# INTEGRATE:`:
##   • Rewarded + interstitial ads → AdMob plugin (e.g. "Godot AdMob" by poing-studios)
##   • In-app purchases          → Google Play Billing plugin (godot-google-play-billing)
## The rest of the game only talks to this API, so nothing else has to change.

signal purchase_finished(product_id: String, ok: bool)

const INTERSTITIAL_EVERY_RUNS := 3
const PRODUCTS := {
	"remove_ads": {"title": "Hapus Iklan", "price": "Rp 25.000"},
	"skin_garuda": {"title": "Garuda Emas", "price": "Rp 15.000"},
	"coin_pack": {"title": "1.500 Koin", "price": "Rp 15.000"},
}

var _layer: CanvasLayer
var _runs_since_interstitial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Rewarded video. `on_done(ok: bool)` is called when the user finished (ok) or skipped.
func show_rewarded(placement: String, on_done: Callable) -> void:
	# INTEGRATE: load + show an AdMob rewarded ad here; call on_done(true) on reward.
	_demo_overlay("Iklan berhadiah (demo)\n" + placement, 3, on_done)


## Called after each finished run; shows an interstitial every N runs unless removed.
func on_run_finished() -> void:
	if Game.ads_removed:
		return
	_runs_since_interstitial += 1
	if _runs_since_interstitial >= INTERSTITIAL_EVERY_RUNS:
		_runs_since_interstitial = 0
		# INTEGRATE: show an AdMob interstitial here.
		_demo_overlay("Iklan (demo)", 2, func(_ok): pass)


func purchase(product_id: String) -> void:
	# INTEGRATE: start a Google Play Billing purchase; on success call _grant(product_id).
	_grant(product_id)


func _grant(product_id: String) -> void:
	match product_id:
		"remove_ads":
			Game.ads_removed = true
			Game.save_game()
		"skin_garuda":
			Game.unlock_skin("garuda")
		"coin_pack":
			Game.add_coins(1500)
	purchase_finished.emit(product_id, true)


func _demo_overlay(text: String, seconds: int, on_done: Callable) -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 110
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.1, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
	_layer.add_child(lbl)
	for i in range(seconds, 0, -1):
		lbl.text = "%s\n\n%d" % [text, i]
		await get_tree().create_timer(1.0, true, false, true).timeout
	_layer.queue_free()
	get_tree().paused = false
	on_done.call(true)
