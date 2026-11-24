class_name Skins
extends RefCounted
## Bird skins (the main coin sink + IAP hook). Each skin = colours + an optional feature
## (crest / casque / plume / crown) + a trail style.

static var _list: Array = []


static func all() -> Array:
	if _list.is_empty():
		_list = [
			{"id": "pipit", "name": "Pipit", "desc": "Kecil, lincah, selalu semangat.", "price": 0,
				"body": Color("#f7b538"), "belly": Color("#fff2d2"), "wing": Color("#d9822b"), "beak": Color("#ff7a3d"),
				"feature": "none", "feature_color": Color.WHITE,
				"trail_a": Color(1, 1, 1, 0.55), "trail_b": Color(1, 1, 1, 0.0), "glow": false},
			{"id": "jalak", "name": "Jalak Bali", "desc": "Putih bersih dengan topeng biru langka.", "price": 300,
				"body": Color("#f4f6fb"), "belly": Color("#ffffff"), "wing": Color("#d7dcea"), "beak": Color("#c9c08f"),
				"feature": "mask", "feature_color": Color("#2b7bff"),
				"trail_a": Color("#8fd0ff"), "trail_b": Color(0.56, 0.82, 1.0, 0.0), "glow": false},
			{"id": "kakatua", "name": "Kakatua Jambul", "desc": "Jambul kuningnya berkibar saat menukik.", "price": 650,
				"body": Color("#fbfbf5"), "belly": Color("#ffffff"), "wing": Color("#e9ead8"), "beak": Color("#3a3a46"),
				"feature": "crest", "feature_color": Color("#ffd23a"),
				"trail_a": Color("#ffe27a"), "trail_b": Color(1.0, 0.89, 0.48, 0.0), "glow": false},
			{"id": "rangkong", "name": "Rangkong", "desc": "Cula oranye, penjaga hutan Kalimantan.", "price": 1100,
				"body": Color("#2a2733"), "belly": Color("#f2efe6"), "wing": Color("#17151d"), "beak": Color("#f4d35e"),
				"feature": "casque", "feature_color": Color("#ff7b2e"),
				"trail_a": Color("#ff9a4a"), "trail_b": Color(1.0, 0.6, 0.29, 0.0), "glow": false},
			{"id": "cendrawasih", "name": "Cendrawasih", "desc": "Burung surga dengan ekor emas menjuntai.", "price": 1900,
				"body": Color("#7a3b1f"), "belly": Color("#ffe066"), "wing": Color("#5a2a14"), "beak": Color("#a7c4d6"),
				"feature": "plume", "feature_color": Color("#ffcf3a"),
				"trail_a": Color("#ffd94a"), "trail_b": Color(1.0, 0.45, 0.2, 0.0), "glow": true},
			{"id": "garuda", "name": "Garuda Emas", "desc": "Legenda Nusantara. Jejak cahaya keemasan.", "price": 3500, "iap": "skin_garuda",
				"body": Color("#e9a92a"), "belly": Color("#fff0b8"), "wing": Color("#b86e12"), "beak": Color("#fff2c4"),
				"feature": "crown", "feature_color": Color("#fff6a8"),
				"trail_a": Color("#fff3a0"), "trail_b": Color(1.0, 0.6, 0.15, 0.0), "glow": true},
		]
	return _list


static func get_skin(id: String) -> Dictionary:
	for s in all():
		if s.id == id:
			return s
	return all()[0]


static func index_of(id: String) -> int:
	var l := all()
	for i in l.size():
		if l[i].id == id:
			return i
	return 0
