# S6 コースを選ぶ(画面設計書 §5。v0.3.0 で作り直した)。16 行(番号・名前・自己ベスト・幽霊の有無・今日の印)と、
# 右の札に選んでいる行のコースの番号・名前・輪郭・自己ベスト。↑↓ で選び、Enter で走る。Esc か「戻る」でタイトルへ。
extends Control

signal picked(course: int)
signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Share := preload("res://core/share_text.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Courses := preload("res://ui/courses.gd")
const Minimap := preload("res://ui/minimap.gd")

const CARD := Rect2(872, 84, 352, 572)
const NO_TIME := "-:--.--"

var menu: Menu
var _map: Minimap
var _shown := -1
var _name: Label
var _num: Label
var _best: Label
var _bests: Array = []  # 番号 → 自己ベストの文字(無ければ "")


func build(store: RefCounted, today: int) -> void:
	size = Vector2(1280, 720)
	add_child(Kit.place(Kit.label_left(S.PICK_TITLE, 32, Color.WHITE, 800), 84, 18, 600, 52))
	var list: Array[Button] = []
	for k in B.COURSES:
		var b := Kit.button("course_%d" % k, "", 18)
		Kit.place(b, 64, 84 + k * 36, 760, 32)
		b.add_child(Kit.place(Kit.label("%d" % k, 20, Kit.C_TEXT, 800, true), 6, 0, 44, 32))
		b.add_child(Kit.place(Kit.label_left(S.COURSE_NAMES[k], 18, Kit.C_TEXT, 700), 62, 0, 240, 32))
		var c: Variant = store.course(k)
		var best := Share.time_text(int(c["best_ticks"])) if c != null else ""
		_bests.append(best)
		# 走っていない行は空のタイムの形(16 行に同じ文が並ぶと読みにくい。「まだ走っていない」は右の札に出す)
		b.add_child(Kit.place(Kit.label_left(best if best != "" else NO_TIME, 20, Kit.C_TEXT if best != "" else Kit.C_DIM, 700, true), 300, 0, 180, 32))
		if c != null and c["ghost"] != "":
			b.add_child(Kit.place(Kit.label_left(S.HAS_GHOST, 15, Kit.C_DIM, 500), 516, 0, 100, 32))
		if k == today:
			var chip := Kit.label(S.TODAY, 15, Kit.C_BG, 800)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Kit.C_AMBER
			sb.skew = Vector2(Kit.SKEW, 0)
			chip.add_theme_stylebox_override("normal", sb)
			b.add_child(Kit.place(chip, 760 - 8 - 64 - 4, 6, 64, 20))
		add_child(b)
		var kk := k
		b.pressed.connect(func() -> void: picked.emit(kk))
		list.append(b)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 20), 1044, 22, 180, 48)
	ret.pressed.connect(func() -> void: back.emit())
	add_child(ret)
	list.append(ret)
	_num = Kit.label_left("", 36, Color.WHITE, 800, true)
	add_child(Kit.place(_num, CARD.position.x + 28, CARD.position.y + 18, 300, 50))
	_name = Kit.label_left("", 22, Kit.C_TEXT, 700)
	add_child(Kit.place(_name, CARD.position.x + 28, CARD.position.y + 66, 300, 34))
	_map = Minimap.new()
	_map.framed = false
	_map.position = CARD.position + Vector2(16, 104)
	add_child(_map)
	_best = Kit.label_left("", 24, Color.WHITE, 800, true)
	add_child(Kit.place(_best, CARD.position.x + 28, CARD.position.y + 452, 300, 40))
	menu = Menu.new(list, 0)
	_show_map()


func _show_map() -> void:
	var k := mini(menu.sel, B.COURSES - 1)
	if k == _shown:
		return
	_shown = k
	_num.text = S.COURSE_N % k
	_name.text = S.COURSE_NAMES[k]  # 地図の上に選んでいるコースの名前(磨きで足した)
	_best.text = _bests[k] if _bests[k] != "" else S.REC_NONE
	_best.add_theme_font_size_override("font_size", 24 if _bests[k] != "" else 16)
	_best.add_theme_color_override("font_color", Color.WHITE if _bests[k] != "" else Kit.C_DIM)
	var c := Courses.load_course(k)
	if not c.is_empty():
		_map.setup(c["points"], Vector2(320, 340))


func _draw() -> void:
	Kit.draw_tick(self, Vector2(60, 32), 26)
	draw_colored_polygon(Kit.slant(CARD, 0.04), Color(Kit.C_PANEL, 0.92))
	var edge := Kit.slant(CARD, 0.04)
	edge.append(edge[0])
	draw_polyline(edge, Color(Kit.C_WALL, 0.35), 1.0, true)
	Kit.draw_checker(self, Rect2(CARD.position.x + 20, CARD.position.y - 8, 112, 16), 14, 2)
	Kit.draw_hints(self, [["updown", S.HINT_SELECT], ["Enter", S.HINT_RUN], ["Esc", S.B_BACK]], CARD.end.x, 666)


func _process(_delta: float) -> void:
	_show_map()  # マウスで選んだ時も地図を替える


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		back.emit()
		return
	menu.key(ev)
	_show_map()
