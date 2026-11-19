# S6 コースを選ぶ(画面設計書 §5)。16 行(番号・名前・自己ベスト・幽霊の有無・今日の印)と、選んでいる行のコースの小さな地図。
# ↑↓ で選び、Enter で走る。Esc か「戻る」でタイトルへ。
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

var menu: Menu
var _map: Minimap
var _shown := -1


func build(store: RefCounted, today: int) -> void:
	size = Vector2(1280, 720)
	var head := Kit.label(S.PICK_TITLE, 36, Kit.C_TEXT, 700)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(head, 60, 16, 600, 56))
	var list: Array[Button] = []
	for k in B.COURSES:
		var b := Kit.button("course_%d" % k, "%d   %s" % [k, S.COURSE_NAMES[k]], 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		Kit.place(b, 60, 84 + k * 38, 760, 34)
		var c: Variant = store.course(k)
		var info := Share.time_text(int(c["best_ticks"])) if c != null else S.REC_NONE
		if c != null and c["ghost"] != "":
			info += "   " + S.HAS_GHOST
		if k == today:
			info += "   " + S.TODAY
		var l := Kit.label(info, 16, Kit.C_DIM, 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_child(Kit.place(l, 330, 0, 420, 34))
		add_child(b)
		var kk := k
		b.pressed.connect(func() -> void: picked.emit(kk))
		list.append(b)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 22), 1040, 20, 180, 52)
	ret.pressed.connect(func() -> void: back.emit())
	add_child(ret)
	list.append(ret)
	_map = Minimap.new()
	_map.position = Vector2(900, 200)
	add_child(_map)
	menu = Menu.new(list, 0)
	_show_map()


func _show_map() -> void:
	var k := mini(menu.sel, B.COURSES - 1)
	if k == _shown:
		return
	_shown = k
	var c := Courses.load_course(k)
	if not c.is_empty():
		_map.setup(c["points"], Vector2(240, 240))


func _process(_delta: float) -> void:
	_show_map()  # マウスで選んだ時も地図を替える


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		back.emit()
		return
	menu.key(ev)
	_show_map()
