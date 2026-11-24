class_name UIKit
extends RefCounted
## Small helper library for the chunky, friendly UI style used across Layang.

const INK := Color("#2a1b3d")
const CREAM := Color("#fff7e6")
const SUN := Color("#ffb53c")
const SUN_DARK := Color("#d9792a")
const LEAF := Color("#5cc27a")
const LEAF_DARK := Color("#2f8a52")
const SKY := Color("#5aa8ff")
const SKY_DARK := Color("#2f6fd0")
const PLUM := Color("#7a5cff")
const PLUM_DARK := Color("#4e33c4")
const GLASS := Color(0.12, 0.08, 0.22, 0.72)

static var _bold: Font


static func bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/Fredoka-Bold.woff2")
	return _bold


static func box(bg: Color, radius: int = 22, border: Color = Color.TRANSPARENT, bottom: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10 + bottom
	if bottom > 0:
		s.border_width_bottom = bottom
		s.border_color = border
	s.anti_aliasing = true
	return s


static func button(text: String, color: Color = SUN, dark: Color = SUN_DARK, size: int = 30, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", size)
	var fc := INK if color.get_luminance() > 0.55 else Color.WHITE
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.5))
	b.add_theme_stylebox_override("normal", box(color, 22, dark, 7))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.1), 22, dark, 7))
	var pressed := box(color.darkened(0.05), 22, dark, 2)
	pressed.content_margin_top = 15
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", box(color.darkened(0.35), 22, dark.darkened(0.3), 7))
	b.custom_minimum_size = Vector2(min_w, 0)
	b.pressed.connect(func(): Sfx.play("click"))
	b.button_down.connect(func(): _pop(b, 0.94))
	b.button_up.connect(func(): _pop(b, 1.0))
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	return b


static func _pop(c: Control, s: float) -> void:
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(s, s), 0.08)


static func label(text: String, size: int = 28, color: Color = Color.WHITE, use_bold: bool = false, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if use_bold:
		l.add_theme_font_override("font", bold())
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel(bg: Color = GLASS, radius: int = 28) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, radius)
	s.content_margin_left = 30
	s.content_margin_right = 30
	s.content_margin_top = 24
	s.content_margin_bottom = 24
	p.add_theme_stylebox_override("panel", s)
	return p


static func pill(text: String, bg: Color = GLASS) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(bg, 30)
	s.content_margin_left = 16
	s.content_margin_right = 20
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 26, Color.WHITE, true)
	l.name = "Label"
	p.add_child(l)
	return p


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Coin glyph drawn as a control (so we don't need icon images).
class CoinIcon:
	extends Control
	func _init(sz: float = 30.0) -> void:
		custom_minimum_size = Vector2(sz, sz)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		Art.coin(self, size * 0.5, size.x * 0.42, Time.get_ticks_msec() / 1000.0 * 0.3)

