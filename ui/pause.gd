# S5 一時停止(共通 §6)。プレイ画面を暗くした上に重ねる。続ける・やり直す・設定・タイトルへ。Esc で続ける、R でやり直す。
# 作りは RootCall の ui/pause.gd。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu


func build() -> void:
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	add_child(Kit.place(dim, -2000, -2000, 5280, 4720))  # 16:9 でない窓の余りまで暗くする
	add_child(Kit.place(Kit.label(S.PAUSE, 40, Kit.C_TEXT, 700), 0, 110, 1280, 60))
	var list: Array[Button] = []
	var y := 210.0
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 26), 490, y, 300, 68)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 84
	menu = Menu.new(list, 0)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.pressed and not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)
