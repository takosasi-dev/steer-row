# S1 タイトル(画面設計書 §2。v0.3.0 で作り直した)。左に題字と入口 3 つ(入門コース・今日のコース・コースを選ぶ)と設定、
# 右に今日のコースの札(番号・名前・輪郭・今日の記録)。下に 10 キーの帯と針を薄く出し、押したキーで光らせる。
# 入門を走り切るまでは入門コースを一番上に置く(FR-25・D-12)。走り切った後は 3 番目。
extends Control

signal chosen(what: String)  # "intro" / "daily" / "pick" / "settings"

const S := preload("res://core/strings.gd")
const Share := preload("res://core/share_text.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const B := preload("res://core/balance.gd")
const Wheel := preload("res://core/wheel.gd")
const Car := preload("res://core/car.gd")
const Keymap := preload("res://ui/keymap.gd")
const Courses := preload("res://ui/courses.gd")
const Minimap := preload("res://ui/minimap.gd")

const CARD := Rect2(712, 248, 470, 308)  # 今日のコースの札

var menu: Menu
var _wasd := false
var _held := {}  # 押されているハンドルのキー(帯を光らせるだけ。走りには使わない)
var _car := Car.new()  # 針を回すためだけの車(動かさない)
var _acc := 0.0


# store は save_store、day は通し日数、course は今日のコースの番号。
func build(store: RefCounted, day: int, course: int) -> void:
	size = Vector2(1280, 720)
	_wasd = store.settings()["controls"] == "wasd"
	add_child(Kit.place(Kit.label_left(S.TAGLINE, 20, Kit.C_TEXT, 500), 112, 184, 640, 32))
	var note := S.LOAD_FAILED if store.load_failed else (S.GHOSTS_CLEARED if store.ghosts_cleared else "")
	if note != "":
		add_child(Kit.place(Kit.label_left(note, 16, Kit.C_WARN, 500), 112, 214, 640, 24))
	var intro := Kit.button("intro", S.B_INTRO, 26)
	var daily := Kit.button("daily", "%s   %s" % [S.B_DAILY, S.COURSE_N % course], 28)
	var pick := Kit.button("pick", S.B_PICK, 26)
	var settings := Kit.button("settings", S.B_SETTINGS, 22)
	var order: Array[Button] = [intro, daily, pick, settings]
	if store.data["intro_done"]:
		order = [daily, pick, intro, settings]
	var y := 248.0
	for b in order:
		var h := 80.0 if b == daily else 64.0
		Kit.place(b, 118, y, 240 if b == settings else 500, h)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
		y += h + 12.0
	# 今日のコースの札
	add_child(Kit.place(Kit.label_left(S.B_DAILY, 18, Kit.C_DIM, 700), CARD.position.x + 54, CARD.position.y + 18, 200, 28))
	add_child(Kit.place(Kit.label_left(S.COURSE_N % course, 40, Color.WHITE, 800, true), CARD.position.x + 30, CARD.position.y + 46, 260, 56))
	add_child(Kit.place(Kit.label_left(S.COURSE_NAMES[course], 22, Kit.C_TEXT, 700), CARD.position.x + 30, CARD.position.y + 102, 240, 34))
	var c := Courses.load_course(course)
	if not c.is_empty():
		var map := Minimap.new()
		map.framed = false
		map.position = CARD.position + Vector2(250, 54)
		add_child(map)
		map.setup(c["points"], Vector2(196, 196))
	var d: Dictionary = store.daily(day, course)
	if d["first_ticks"] == null:
		add_child(Kit.place(Kit.label_left(S.REC_NONE, 18, Kit.C_DIM, 500), CARD.position.x + 30, CARD.position.y + 170, 220, 30))
	else:
		add_child(Kit.place(Kit.label_left(S.REC_FIRST % Share.time_text(int(d["first_ticks"])), 20, Kit.C_TEXT, 600, true),
			CARD.position.x + 30, CARD.position.y + 164, 230, 32))
		add_child(Kit.place(Kit.label_left(S.REC_TODAY_BEST % Share.time_text(int(d["best_ticks"])), 24, Color.WHITE, 800, true),
			CARD.position.x + 30, CARD.position.y + 200, 230, 40))
	var ver := Kit.label_left(S.VERSION, 16, Kit.C_DIM, 500, true)
	add_child(Kit.place(ver, 48, 600, 200, 26))
	menu = Menu.new(order, 0)


# 題字・今日のコースの札・操作の案内・10 キーの帯。帯は押したキーで光り、針も回る(走る前に 10 キーがハンドルだと手で分かるように)。
# 針は core の車と同じ速さで目標へ回す(ハンドルの決まりを 2 か所に書かない)。
func _draw() -> void:
	Kit.draw_logo(self, Vector2(118, 40), 92)
	draw_colored_polygon(Kit.slant(CARD, 0.06), Color(Kit.C_PANEL, 0.92))
	var edge := Kit.slant(CARD, 0.06)
	edge.append(edge[0])
	draw_polyline(edge, Color(Kit.C_WALL, 0.35), 1.0, true)
	Kit.draw_checker(self, Rect2(CARD.position.x + 18, CARD.position.y - 8, 112, 16), 14, 2)  # 札の上の市松
	Kit.draw_tick(self, CARD.position + Vector2(30, 22), 20)
	draw_line(CARD.position + Vector2(30, 150), CARD.position + Vector2(236, 150), Color(Kit.C_WALL, 0.3), 1.0)
	Kit.draw_hints(self, [["updown", S.HINT_SELECT], ["Enter", S.HINT_OK]], CARD.end.x, 598)
	var inp := Keymap.input_of(_held, "wasd" if _wasd else "row")
	var lit := Kit.lit_of(inp[0], inp[1], _wasd)
	Kit.draw_strip(self, lit, _wasd, _car.w, Wheel.target(inp[0]), 1.0 if not _held.is_empty() else 0.7)


func _process(delta: float) -> void:
	var target := Wheel.target(Keymap.input_of(_held, "wasd" if _wasd else "row")[0])
	_acc += delta * B.TICK_HZ
	var n := mini(int(_acc), B.MAX_STEPS_PER_FRAME)
	_acc -= int(_acc)
	var before := _car.w
	for k in n:
		_car.turn_wheel(target)
	if _car.w != before:
		queue_redraw()


func key(ev: InputEventKey) -> void:
	var pk := int(ev.physical_keycode)
	var ctl := "wasd" if _wasd else "row"
	if Keymap.index_of(pk, ctl) >= 0 or Keymap.is_brake(pk, ctl):
		if ev.pressed and not ev.echo and not Keymap.has_modifier(ev):
			_held[pk] = true
		elif not ev.pressed:
			_held.erase(pk)
		queue_redraw()
	menu.key(ev)


# フォーカスが外れた時(共通 §3 の 5)。
func release_all() -> void:
	_held.clear()
	queue_redraw()
