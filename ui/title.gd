# S1 タイトル(画面設計書 §2)。入口 3 つ(入門コース・今日のコース・コースを選ぶ)と設定、今日の記録。下に 10 キーの帯と針を薄く出す。
# 入門を走り切るまでは入門コースを一番上に置く(FR-25・D-12)。走り切った後は 3 番目。
extends Control

signal chosen(what: String)  # "intro" / "daily" / "pick" / "settings"

const S := preload("res://core/strings.gd")
const Share := preload("res://core/share_text.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu
var _wasd := false


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


func _draw() -> void:
	Kit.draw_strip(self, {}, _wasd, 0.0, 0.0, 0.35)


func key(ev: InputEventKey) -> void:
	menu.key(ev)
