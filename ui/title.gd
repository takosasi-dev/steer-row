# S1 タイトル(画面設計書 §2)。入口 3 つ(入門コース・今日のコース・コースを選ぶ)と設定、今日の記録。下に 10 キーの帯と針を薄く出す。
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

var menu: Menu
var _wasd := false
var _held := {}  # 押されているハンドルのキー(帯を光らせるだけ。走りには使わない)
var _car := Car.new()  # 針を回すためだけの車(動かさない)
var _acc := 0.0


# store は save_store、day は通し日数、course は今日のコースの番号。
func build(store: RefCounted, day: int, course: int) -> void:
	size = Vector2(1280, 720)
	_wasd = store.settings()["controls"] == "wasd"
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 30, 1280, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 128, 1280, 44))
	var note := S.LOAD_FAILED if store.load_failed else (S.GHOSTS_CLEARED if store.ghosts_cleared else "")
	if note != "":
		add_child(Kit.place(Kit.label(note, 18, Kit.C_WARN), 0, 172, 1280, 28))
	var intro := Kit.button("intro", S.B_INTRO, 28)
	var daily := Kit.button("daily", "%s   %s" % [S.B_DAILY, S.COURSE_N % course], 30)
	var pick := Kit.button("pick", S.B_PICK, 28)
	var settings := Kit.button("settings", S.B_SETTINGS, 24)
	var order: Array[Button] = [intro, daily, pick, settings]
	if store.data["intro_done"]:
		order = [daily, pick, intro, settings]
	var y := 214.0
	for b in order:
		var h := 88.0 if b == daily else 72.0
		Kit.place(b, 380, y, 240 if b == settings else 520, h)
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
		y += h + 14.0
	var d: Dictionary = store.daily(day, course)
	var rec := S.REC_NONE
	if d["first_ticks"] != null:
		rec = (S.REC_FIRST % Share.time_text(int(d["first_ticks"]))) + " / " + (S.REC_TODAY_BEST % Share.time_text(int(d["best_ticks"])))
	var l := Kit.label(rec, 18, Kit.C_DIM, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, daily.position.x + daily.size.x + 24, daily.position.y, 360, daily.size.y))
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 600, 200, 32))
	menu = Menu.new(order, 0)


# 帯は押したキーで光り、針も回る(走る前に 10 キーがハンドルだと手で分かるように。磨きで足した)。
# 針は core の車と同じ速さで目標へ回す(ハンドルの決まりを 2 か所に書かない)。
func _draw() -> void:
	var inp := Keymap.input_of(_held, "wasd" if _wasd else "row")
	var lit := Kit.lit_of(inp[0], inp[1], _wasd)
	Kit.draw_strip(self, lit, _wasd, _car.w, Wheel.target(inp[0]), 1.0 if not _held.is_empty() else 0.45)


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
