# S5 一時停止(共通 §6。v0.3.0 で作り直した)。プレイ画面を暗くした上に、上に市松の帯を付けた板を重ねる。続ける・やり直す・設定・タイトルへ。
# Esc で続ける、R でやり直す(板の下に案内を出す)。作りは RootCall の ui/pause.gd。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

const PANEL := Rect2(430, 110, 420, 462)

var menu: Menu


func build() -> void:
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(Kit.C_BG, 0.78)
	add_child(Kit.place(dim, -2000, -2000, 5280, 4720))  # 16:9 でない窓の余りまで暗くする
	var deco := Control.new()  # 板と案内(暗い幕より上に描く)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_panel.bind(deco))
	add_child(deco)
	var head := Kit.label_left(S.PAUSE, 34, Color.WHITE, 800)
	add_child(Kit.place(head, PANEL.position.x + 70, PANEL.position.y + 30, 300, 50))
	var list: Array[Button] = []
	var y := PANEL.position.y + 104
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 24), PANEL.position.x + 60, y, 300, 60)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 72
	menu = Menu.new(list, 0)


func _draw_panel(ci: Control) -> void:
	ci.draw_colored_polygon(Kit.slant(PANEL, 0.04), Kit.C_PANEL)
	var edge := Kit.slant(PANEL, 0.04)
	edge.append(edge[0])
	ci.draw_polyline(edge, Color(Kit.C_WALL, 0.35), 1.0, true)
	Kit.draw_checker(ci, Rect2(PANEL.position + Vector2(24, -8), Vector2(112, 16)), 14, 2)
	Kit.draw_tick(ci, PANEL.position + Vector2(40, 44), 24)
	Kit.draw_hints(ci, [["Esc", S.B_RESUME], ["R", S.B_RESTART], ["updown", S.HINT_SELECT]], PANEL.get_center().x, PANEL.end.y - 50, true)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.pressed and not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)
