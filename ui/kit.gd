# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)と、10 キーの帯・ハンドルの針・コースの輪郭の絵。画面設計書 §9 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。作りは KeyFlak の ui/kit.gd。
extends RefCounted

const S := preload("res://core/strings.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"

const C_BG := Color("0E1116")
const C_ROAD := Color("1E242D")
const C_WALL := Color("8B95A5")
const C_GATE := Color("3A4250")
const C_START := Color("E6E6E6")
const C_CAR := Color("6BB8FF")
const C_GHOST := Color("E6E6E6")
const C_SKID := Color("3A4250")
const C_NEEDLE := Color("FFB84D")
const C_TEXT := Color("E6E6E6")
const C_DIM := Color("8B95A5")
const C_SEL := Color("6BB8FF")
const C_GOOD := Color("7EE787")
const C_WARN := Color("FFB84D")

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.anti_aliasing = true
	return s


# ボタン。node_name は自動の確認が押す時の目印。キーボードでの選択は ui/menu.gd が見た目を変える。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # 矢印を Godot のフォーカスの移動に使わせない
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	set_selected(b, false)
	b.add_theme_stylebox_override("pressed", box(Color(C_SEL, 0.3), C_SEL, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.02), Color(C_DIM, 0.3), 2))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	return b


static func set_selected(b: Button, on: bool) -> void:
	var edge := C_SEL if on else Color(C_TEXT, 0.55)
	var fill := Color(C_SEL, 0.16) if on else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", box(fill, edge, 3 if on else 2))
	b.add_theme_stylebox_override("hover", box(Color(C_SEL, 0.12), C_SEL, 3))


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# 画面の下の帯(y 640〜700)。lit は光らせる四角の番号の集まり。wasd なら A・S・D の 3 つ(左・ブレーキ・右)。
# ハンドルの針(左端 −1、右端 +1)と目標の小さな印も描く。alpha で薄く描ける(タイトル)。
static func draw_strip(ci: CanvasItem, lit: Dictionary, wasd: bool, wheel: float = 0.0, target: float = 0.0, alpha: float = 1.0) -> void:
	var f := font(700)
	var labels: Array = [["A", S.WASD_LEFT], ["S", S.WASD_BRAKE], ["D", S.WASD_RIGHT]] if wasd else S.KEYS.map(func(k: String) -> Array: return [k, ""])
	var w := 96.0 if wasd else 58.0
	var x0 := 48.0
	for i in labels.size():
		var r := Rect2(x0 + i * (w + 8.0), 640, w, 60)
		var on := lit.has(i)
		ci.draw_rect(r, Color(C_CAR, 0.9 * alpha) if on else Color(1, 1, 1, 0.04 * alpha))
		ci.draw_rect(r, Color(C_CAR if on else C_WALL, alpha), false, 2.0)
		var text: String = labels[i][0] if labels[i][1] == "" else "%s %s" % labels[i]
		ci.draw_string(f, Vector2(r.position.x, r.position.y + 40), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20 if wasd else 24,
			Color(C_BG if on else C_TEXT, alpha))
	var left := 820.0
	var right := 1220.0
	var y := 676.0
	ci.draw_string(f, Vector2(left, 656), S.HANDLE, HORIZONTAL_ALIGNMENT_LEFT, 200, 18, Color(C_DIM, alpha))
	ci.draw_line(Vector2(left, y), Vector2(right, y), Color(C_WALL, alpha), 2.0)
	for k in 11:
		var tx := left + (right - left) * k / 10.0
		var tall := 8.0 if k % 5 == 0 else 4.0
		ci.draw_line(Vector2(tx, y - tall), Vector2(tx, y + tall), Color(C_WALL, alpha), 2.0)
	var mx := left + (right - left) * (target + 1.0) / 2.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(mx, y + 10), Vector2(mx - 6, y + 20), Vector2(mx + 6, y + 20)]), Color(C_TEXT, 0.7 * alpha))
	var nx := left + (right - left) * (wheel + 1.0) / 2.0
	ci.draw_line(Vector2(nx, y - 18), Vector2(nx, y + 10), Color(C_NEEDLE, alpha), 4.0)


# コースの点を rect に収める倍率と原点のずれ [倍率, ずれ](地図・コースを選ぶの小さな地図。北が上)。
static func fit(points: Array, rect: Rect2) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Array in points:
		lo = Vector2(minf(lo.x, p[0]), minf(lo.y, p[1]))
		hi = Vector2(maxf(hi.x, p[0]), maxf(hi.y, p[1]))
	var span := hi - lo
	var k := minf((rect.size.x - 16) / maxf(span.x, 1.0), (rect.size.y - 16) / maxf(span.y, 1.0))
	return [k, rect.position + rect.size / 2 - (lo + span / 2) * k]


static func outline(points: Array, k: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in points:
		out.append(Vector2(p[0], p[1]) * k + off)
	if not out.is_empty():
		out.append(out[0])
	return out
