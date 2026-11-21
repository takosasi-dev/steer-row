# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・題字・操作の案内)と、10 キーの帯・ハンドルの針・コースの輪郭の絵。画面設計書 §9 の色はここに置く。
# 文言は持たない(題字の SteerRow と、帯のキーの印字は strings.gd から読む)。ボタン・枠の見た目は ui/theme.tres(tools/make_theme.gd が作る)。
extends RefCounted

const S := preload("res://core/strings.gd")

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/SairaItalic-Subset.ttf"  # 題字とタイム(v0.3.0)。日本語は SANS へ落ちる

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
const C_SEL := Color("FFB84D")  # 選んでいる物(v0.3.0 で青から計器の琥珀に。青は自分の車とキーの色)
const C_GOOD := Color("7EE787")
const C_WARN := Color("FFB84D")
# 磨きで足した色(v0.2.0)
const C_DOT := Color(1, 1, 1, 0.07)  # 地面の点
const C_DASH := Color(1, 1, 1, 0.13)  # 道の中央の破線
const C_CURB := Color("B8483E")  # 縁石の赤
const C_CURB_2 := Color("C9CDD4")  # 縁石の白
# UI の作り直しで足した色(v0.3.0。モータースポーツの計器: 夜の舗装・計器の琥珀・旗の白・縁石の赤)
const C_PANEL := Color("161B23")  # 板の地
const C_PANEL_2 := Color("1D232D")  # 板の地(明るい方)
const C_AMBER := Color("FFB84D")  # 計器の琥珀
const C_FLAG := Color("F2F3F5")  # 市松の白・題字
const C_RED := Color("D9463B")  # 題字の下の縁石

const SKEW := 0.22  # ボタン・板の傾き(横 ÷ 縦)。題字の斜めと揃える

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 題字とタイムの字(Saira Italic)。字体に無い字(日本語)は Noto Sans JP の同じ太さで出す。
static func display(weight: int = 800) -> Font:
	var key := -weight
	if not _fonts.has(key):
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		fv.fallbacks = [font(weight)]
		_fonts[key] = fv
	return _fonts[key]


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400, disp: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", display(weight) if disp else font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func label_left(text: String, size: int, color: Color = C_TEXT, weight: int = 400, disp: bool = false) -> Label:
	var l := label(text, size, color, weight, disp)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


# ボタン。見た目は theme.tres の Button(選んでいる時は SelButton)。node_name は自動の確認が押す時の目印。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # 矢印を Godot のフォーカスの移動に使わせない(選ぶのは ui/menu.gd)
	b.add_theme_font_size_override("font_size", size)
	return b


# 選んでいる印(キーボードで選ぶ時の目印)。theme.tres の SelButton に切り替える。
static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"SelButton" if on else &""


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# 傾いた平行四辺形(r の上の辺を右へ、下の辺を左へ skew × 高さ / 2 ずらす)。
static func slant(r: Rect2, skew: float = SKEW) -> PackedVector2Array:
	var d := r.size.y * skew / 2.0
	return PackedVector2Array([r.position + Vector2(d, 0), Vector2(r.end.x + d, r.position.y), r.end - Vector2(d, 0), Vector2(r.position.x - d, r.end.y)])


# 市松(cols × rows のます。左上が c1)。
static func draw_checker(ci: CanvasItem, r: Rect2, cols: int, rows: int, c1: Color = C_FLAG, c2: Color = C_BG) -> void:
	var w := r.size.x / cols
	var h := r.size.y / rows
	ci.draw_rect(r, c2)
	for y in rows:
		for x in cols:
			if (x + y) % 2 == 0:
				ci.draw_rect(Rect2(r.position + Vector2(x * w, y * h), Vector2(w, h)), c1)


# 題字(ロゴ)。at は字の左上、size は字の大きさ。斜めの Saira の一番太い字に琥珀の影、左から流れる速さの線、下に縁石の帯と市松の旗。
# streak(0〜1)で速さの線が少し伸び縮みする。描いた範囲を返す。
static func draw_logo(ci: CanvasItem, at: Vector2, size: int, alpha: float = 1.0, streak: float = 0.0) -> Rect2:
	var f := display(900)
	var w := f.get_string_size(S.NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := at + Vector2(0, f.get_ascent(size))
	var u := size / 96.0
	for k in 3:
		var y := at.y + size * (0.42 + k * 0.16)
		var ln := (96.0 - k * 26.0 + streak * 20.0) * u
		var x1 := at.x - (10.0 + k * 8.0) * u
		ci.draw_line(Vector2(x1 - ln, y), Vector2(x1, y), Color(C_AMBER if k == 1 else C_CAR, alpha * (0.95 - k * 0.2)), maxf(4.0 * u, 2.0))
	ci.draw_string(f, base + Vector2(5, 4) * u, S.NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(C_AMBER, 0.9 * alpha))
	ci.draw_string(f, base, S.NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(C_FLAG, alpha))
	var y0 := base.y + 14.0 * u
	var h := 12.0 * u
	var cell := 28.0 * u
	var n := int((w - 40.0 * u) / cell)
	for k in n:
		ci.draw_colored_polygon(slant(Rect2(at.x - 4.0 * u + k * cell, y0, cell, h), 1.6), Color(C_RED if k % 2 == 0 else C_FLAG, alpha))
	var flag := Rect2(at.x + n * cell + 6.0 * u, y0 - 6.0 * u, 36.0 * u, 18.0 * u)
	draw_checker(ci, flag, 6, 3, Color(C_FLAG, alpha), Color(C_BG, alpha))
	return Rect2(at, Vector2(maxf(w, flag.end.x - at.x), flag.end.y - at.y))


# 操作の案内の 1 行。items は [[キー, 文言], ...]。キーは文字か "updown"(↑↓)・"leftright"(← →)で、矢印は三角で描く(字体の豆腐を避ける)。
# center が真なら x を真ん中に、偽なら右端を x に揃える。
static func draw_hints(ci: CanvasItem, items: Array, x: float, y: float, center: bool = false, alpha: float = 1.0) -> void:
	var f := font(700)
	var sz := 16
	var widths: Array = []
	var total := 0.0
	for it: Array in items:
		var cap := _cap_width(f, it[0], sz)
		var tw := f.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		widths.append([cap, tw])
		total += cap + 8.0 + tw + 24.0
	total -= 24.0
	var px := x - (total / 2.0 if center else total)
	for i in items.size():
		var cap: float = widths[i][0]
		var r := Rect2(px, y, cap, 26)
		ci.draw_rect(r, Color(C_PANEL_2, alpha))
		ci.draw_rect(r, Color(C_DIM, 0.6 * alpha), false, 1.0)
		ci.draw_line(Vector2(r.position.x + 1, r.end.y - 1), Vector2(r.end.x - 1, r.end.y - 1), Color(C_DIM, alpha), 2.0)
		var key: String = items[i][0]
		var c := r.get_center() - Vector2(0, 1)
		match key:
			"updown":
				_tri(ci, c + Vector2(-6, 0), -1, Color(C_TEXT, alpha))
				_tri(ci, c + Vector2(6, 0), 1, Color(C_TEXT, alpha))
			"leftright":
				_tri_h(ci, c + Vector2(-6, 0), -1, Color(C_TEXT, alpha))
				_tri_h(ci, c + Vector2(6, 0), 1, Color(C_TEXT, alpha))
			_:
				ci.draw_string(f, Vector2(r.position.x, r.position.y + 19), key, HORIZONTAL_ALIGNMENT_CENTER, cap, sz - 2, Color(C_TEXT, alpha))
		px += cap + 8.0
		ci.draw_string(f, Vector2(px, y + 19), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(C_DIM, alpha))
		px += float(widths[i][1]) + 24.0


static func _cap_width(f: Font, key: String, sz: int) -> float:
	if key == "updown" or key == "leftright":
		return 34.0
	return maxf(26.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, sz - 2).x + 14.0)


# 上(d = −1)か下(d = 1)を向いた小さな三角。
static func _tri(ci: CanvasItem, c: Vector2, d: int, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 5 * d), c + Vector2(-4.5, -4 * d), c + Vector2(4.5, -4 * d)]), col)


# 左(d = −1)か右(d = 1)を向いた小さな三角。
static func _tri_h(ci: CanvasItem, c: Vector2, d: int, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(5 * d, 0), c + Vector2(-4 * d, -4.5), c + Vector2(-4 * d, 4.5)]), col)


# 見出しの前の小さな印(琥珀の斜めの棒 2 本)。
static func draw_tick(ci: CanvasItem, at: Vector2, h: float = 22.0, alpha: float = 1.0) -> void:
	for k in 2:
		ci.draw_colored_polygon(slant(Rect2(at + Vector2(k * 9.0, 0), Vector2(5, h)), 0.6), Color(C_AMBER, alpha * (1.0 - k * 0.45)))


# 画面の下の帯(y 640〜700)。lit は光らせる四角の番号の集まり。wasd なら A・S・D の 3 つ(左・ブレーキ・右)。
# ハンドルの針(左端 −1、右端 +1)と目標の小さな印も描く。alpha で薄く描ける(タイトル)。
static func draw_strip(ci: CanvasItem, lit: Dictionary, wasd: bool, wheel: float = 0.0, target: float = 0.0, alpha: float = 1.0) -> void:
	var f := font(700)
	var labels: Array = [["A", S.WASD_LEFT], ["S", S.WASD_BRAKE], ["D", S.WASD_RIGHT]] if wasd else S.KEYS.map(func(k: String) -> Array: return [k, ""])
	var w := 132.0 if wasd else 58.0  # W A S D の「S ブレーキ」が収まる幅
	var x0 := 48.0
	for i in labels.size():
		var r := Rect2(x0 + i * (w + 8.0), 640, w, 60)
		var on := lit.has(i)
		ci.draw_rect(r, Color(C_CAR, 0.95 * alpha) if on else Color(C_PANEL_2, 0.9 * alpha))
		ci.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), Color(0, 0, 0, 0.35 * alpha))  # キーの下の縁(押せる物に見えるように)
		ci.draw_rect(r, Color(C_CAR if on else C_WALL, (1.0 if on else 0.6) * alpha), false, 2.0)
		var text: String = labels[i][0] if labels[i][1] == "" else "%s %s" % labels[i]
		ci.draw_string(f, Vector2(r.position.x, r.position.y + 39), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20 if wasd else 24,
			Color(C_BG if on else C_TEXT, alpha))
	var left := 900.0
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


# 速さの棒(帯と針の間)。k は 0〜1(V_MAX で 1)。ブレーキの間は棒を橙に、いっぱいの時は明るく。
static func draw_speed(ci: CanvasItem, k: float, braking: bool) -> void:
	var f := font(700)
	var r := Rect2(740, 670, 130, 14)
	ci.draw_string(f, Vector2(r.position.x, 656), S.SPEED, HORIZONTAL_ALIGNMENT_LEFT, 120, 18, C_DIM)
	ci.draw_rect(r, Color(1, 1, 1, 0.05))
	var fill := C_WARN if braking else (C_TEXT if k >= 0.999 else C_CAR)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), fill)
	for i in range(1, 5):
		var tx := r.position.x + r.size.x * i / 5.0
		ci.draw_line(Vector2(tx, r.position.y), Vector2(tx, r.end.y), C_BG, 2.0)
	ci.draw_rect(r, Color(C_WALL, 0.8), false, 1.5)


# 帯で光らせる四角(10 キーは番号 0〜9。W A S D は 0 = A、1 = S(ブレーキ)、2 = D)。
static func lit_of(keys: int, brake: bool, wasd: bool) -> Dictionary:
	var lit := {}
	if wasd:
		if keys & 1:
			lit[0] = true
		if brake:
			lit[1] = true
		if keys & (1 << 9):
			lit[2] = true
	else:
		for i in 10:
			if keys & (1 << i):
				lit[i] = true
	return lit


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
