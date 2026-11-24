class_name Biomes
extends RefCounted
## The six islands of Layang. Every colour, layer and particle in a scene comes from here,
## so new islands can be added by appending one dictionary.

static var _list: Array = []


static func all() -> Array:
	if _list.is_empty():
		_list = _build()
	return _list


static func count() -> int:
	return all().size()


static func get_biome(i: int) -> Dictionary:
	var l := all()
	return l[posmod(i, l.size())]


static func _c(h: String) -> Color:
	return Color(h)


static func _build() -> Array:
	return [
		{
			"id": "sawah", "name": "Sawah Fajar", "subtitle": "Terasering hijau menyambut pagi",
			"sky_top": _c("#5867c4"), "sky_mid": _c("#f2a1b8"), "sky_horizon": _c("#ffdca3"),
			"sun": _c("#fff3c4"), "sun_size": 0.085, "sun_x": 0.72, "stars": 0.0,
			"layers": [
				{"kind": "peaks", "y": 0.50, "amp": 150.0, "color": _c("#8f8fd0"), "factor": 0.05, "seed": 11, "obj": "none"},
				{"kind": "ridge", "y": 0.64, "amp": 70.0, "color": _c("#7aa88f"), "factor": 0.14, "seed": 12, "obj": "hut", "obj_scale": 0.55, "obj_every": 520.0},
				{"kind": "ridge", "y": 0.78, "amp": 45.0, "color": _c("#4f8a63"), "factor": 0.3, "seed": 13, "obj": "round", "obj_scale": 0.9, "obj_every": 210.0},
			],
			"hill_a": _c("#93d46b"), "hill_b": _c("#73bd55"), "hill_top": _c("#d6f58a"), "hill_deep": _c("#2c6a3a"),
			"pattern": 1, "stripe_w": 46.0,
			"water": _c("#6fc4d6"), "water_top": _c("#d9f6ff"),
			"prop": "rice", "prop_color": _c("#5aa548"),
			"ambient": "seeds", "ambient_color": _c("#fffbe6"),
			"tint": _c("#ffffff"),
		},
		{
			"id": "pantai", "name": "Pantai Siang", "subtitle": "Pasir hangat & laut tosca",
			"sky_top": _c("#2c86de"), "sky_mid": _c("#78c6f4"), "sky_horizon": _c("#dff6ff"),
			"sun": _c("#ffffff"), "sun_size": 0.07, "sun_x": 0.3, "stars": 0.0,
			"layers": [
				{"kind": "islands", "y": 0.60, "amp": 60.0, "color": _c("#86bcd6"), "factor": 0.04, "seed": 21, "obj": "none"},
				{"kind": "sea", "y": 0.66, "amp": 4.0, "color": _c("#3bb3d0"), "factor": 0.1, "seed": 22, "obj": "boat", "obj_scale": 0.6, "obj_every": 900.0},
				{"kind": "ridge", "y": 0.84, "amp": 26.0, "color": _c("#4aa88f"), "factor": 0.32, "seed": 23, "obj": "palm", "obj_scale": 1.0, "obj_every": 260.0},
			],
			"hill_a": _c("#ffe4a6"), "hill_b": _c("#f6cd7d"), "hill_top": _c("#fff7de"), "hill_deep": _c("#c8894a"),
			"pattern": 0, "stripe_w": 64.0,
			"water": _c("#1fb4c8"), "water_top": _c("#c8fbff"),
			"prop": "shell", "prop_color": _c("#ff9d8a"),
			"ambient": "sparkle", "ambient_color": _c("#ffffff"),
			"tint": _c("#ffffff"),
		},
		{
			"id": "hutan", "name": "Hutan Hujan", "subtitle": "Kabut, lumut, dan rintik hujan",
			"sky_top": _c("#35615f"), "sky_mid": _c("#7ea596"), "sky_horizon": _c("#cfe0d2"),
			"sun": _c("#eef4e4"), "sun_size": 0.06, "sun_x": 0.6, "stars": 0.0,
			"layers": [
				{"kind": "ridge", "y": 0.48, "amp": 110.0, "color": _c("#86a99b"), "factor": 0.05, "seed": 31, "obj": "tall", "obj_scale": 0.55, "obj_every": 120.0},
				{"kind": "ridge", "y": 0.62, "amp": 80.0, "color": _c("#5a8574"), "factor": 0.15, "seed": 32, "obj": "tall", "obj_scale": 0.8, "obj_every": 150.0},
				{"kind": "ridge", "y": 0.80, "amp": 40.0, "color": _c("#264f40"), "factor": 0.32, "seed": 33, "obj": "fern", "obj_scale": 1.0, "obj_every": 140.0},
			],
			"hill_a": _c("#3e8c4e"), "hill_b": _c("#55a75d"), "hill_top": _c("#9be07f"), "hill_deep": _c("#143a28"),
			"pattern": 2, "stripe_w": 54.0,
			"water": _c("#4c8d84"), "water_top": _c("#c6efe0"),
			"prop": "mushroom", "prop_color": _c("#ff7a6b"),
			"ambient": "rain", "ambient_color": _c("#d8f0ff"),
			"tint": _c("#eef6f2"),
		},
		{
			"id": "gunung", "name": "Gunung Api Senja", "subtitle": "Langit jingga & bara melayang",
			"sky_top": _c("#38205e"), "sky_mid": _c("#c4446a"), "sky_horizon": _c("#ffb35c"),
			"sun": _c("#ffd27c"), "sun_size": 0.09, "sun_x": 0.5, "stars": 0.25,
			"layers": [
				{"kind": "volcano", "y": 0.56, "amp": 230.0, "color": _c("#7a3566"), "factor": 0.04, "seed": 41, "obj": "none"},
				{"kind": "peaks", "y": 0.68, "amp": 90.0, "color": _c("#55254f"), "factor": 0.15, "seed": 42, "obj": "none"},
				{"kind": "ridge", "y": 0.82, "amp": 35.0, "color": _c("#2b1532"), "factor": 0.32, "seed": 43, "obj": "dead", "obj_scale": 1.0, "obj_every": 300.0},
			],
			"hill_a": _c("#5a2b42"), "hill_b": _c("#78394a"), "hill_top": _c("#ff9350"), "hill_deep": _c("#1d0c19"),
			"pattern": 0, "stripe_w": 80.0,
			"water": _c("#ff6a2c"), "water_top": _c("#ffe08a"),
			"prop": "rock", "prop_color": _c("#3a1c2e"),
			"ambient": "embers", "ambient_color": _c("#ffb04a"),
			"tint": _c("#fff0e6"),
		},
		{
			"id": "danau", "name": "Danau Kunang-kunang", "subtitle": "Malam berbintang di tepi danau",
			"sky_top": _c("#0a0f31"), "sky_mid": _c("#1d2a64"), "sky_horizon": _c("#45569a"),
			"sun": _c("#eef0ff"), "sun_size": 0.055, "sun_x": 0.78, "stars": 1.0,
			"layers": [
				{"kind": "peaks", "y": 0.54, "amp": 130.0, "color": _c("#2a3574"), "factor": 0.05, "seed": 51, "obj": "none"},
				{"kind": "ridge", "y": 0.66, "amp": 60.0, "color": _c("#1a2352"), "factor": 0.15, "seed": 52, "obj": "round", "obj_scale": 0.7, "obj_every": 170.0},
				{"kind": "ridge", "y": 0.82, "amp": 25.0, "color": _c("#0e1335"), "factor": 0.32, "seed": 53, "obj": "reeds", "obj_scale": 1.0, "obj_every": 120.0},
			],
			"hill_a": _c("#2b4180"), "hill_b": _c("#22346a"), "hill_top": _c("#86e6ff"), "hill_deep": _c("#090e2c"),
			"pattern": 1, "stripe_w": 60.0,
			"water": _c("#1c3d7d"), "water_top": _c("#9fd8ff"),
			"prop": "lantern", "prop_color": _c("#ffcf6b"),
			"ambient": "fireflies", "ambient_color": _c("#d9ff7a"),
			"tint": _c("#dfe6ff"),
		},
		{
			"id": "awan", "name": "Negeri Awan", "subtitle": "Melayang di atas lautan awan",
			"sky_top": _c("#8aa4ff"), "sky_mid": _c("#f2c4ef"), "sky_horizon": _c("#fff1f6"),
			"sun": _c("#fffaf0"), "sun_size": 0.09, "sun_x": 0.4, "stars": 0.15,
			"layers": [
				{"kind": "cloudbank", "y": 0.52, "amp": 90.0, "color": _c("#fde9fb"), "factor": 0.05, "seed": 61, "obj": "none"},
				{"kind": "cloudbank", "y": 0.66, "amp": 70.0, "color": _c("#f3dcff"), "factor": 0.15, "seed": 62, "obj": "none"},
				{"kind": "cloudbank", "y": 0.82, "amp": 50.0, "color": _c("#ffffff"), "factor": 0.32, "seed": 63, "obj": "none"},
			],
			"hill_a": _c("#fbe4f6"), "hill_b": _c("#e7d3ff"), "hill_top": _c("#ffffff"), "hill_deep": _c("#a996e6"),
			"pattern": 2, "stripe_w": 70.0,
			"water": _c("#cfe6ff"), "water_top": _c("#ffffff"),
			"prop": "star", "prop_color": _c("#ffd36b"),
			"ambient": "glitter", "ambient_color": _c("#ffd6f5"),
			"tint": _c("#ffffff"),
		},
	]
