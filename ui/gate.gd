# S0 始める(共通 §6。v0.3.0 で作り直した)。題字・10 キーの列(左から右へ順に光る。ハンドルの目盛りだと伝える)・「クリックかキーで始める」の札。
# moving が偽(「点滅を弱める」が入)なら、列も札も動かさない。
extends Control

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

var touch_note: Label
var moving := true
var t := 0.0


func build(p_moving: bool) -> void:
	moving = p_moving
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(Kit.label(S.S0_START, 28, Color.WHITE, 700), 0, 448, 1280, 56))
	add_child(Kit.place(Kit.label(S.S0_KEYBOARD, 18, Kit.C_DIM, 500), 0, 516, 1280, 30))
	touch_note = Kit.label(S.TOUCH, 22, Kit.C_WARN, 700)
	touch_note.visible = false
	add_child(Kit.place(touch_note, 0, 570, 1280, 40))


func _process(delta: float) -> void:
	if moving:
		t += delta
		queue_redraw()


func _draw() -> void:
	var f := Kit.display(900)
	var size_px := 132
	var w := f.get_string_size(S.NAME, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	Kit.draw_logo(self, Vector2((1280.0 - w) / 2.0 + 20.0, 140), size_px, 1.0, 0.5 + 0.5 * sin(t * 2.4) if moving else 0.5)
	# 10 キーの列。左から右へ 1 つずつ光る(1 周 1.6 秒)
	var lit := int(t / 0.16) % 10 if moving else -1
	var kf := Kit.font(700)
	for i in 10:
		var r := Rect2(640.0 - 5 * 52.0 + i * 52.0 + 4.0, 372, 44, 40)
		var on := i == lit
		draw_rect(r, Color(Kit.C_CAR, 0.9) if on else Color(Kit.C_PANEL_2, 0.9))
		draw_rect(r, Kit.C_CAR if on else Color(Kit.C_WALL, 0.5), false, 1.5)
		draw_string(kf, Vector2(r.position.x, r.position.y + 28), S.KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Kit.C_BG if on else Kit.C_TEXT)
	# 始める札(傾いた板。ゆっくり明るさが揺れる)
	var a := 0.75 + 0.25 * cos(t * 3.0) if moving else 1.0
	var plate := Rect2(440, 452, 400, 48)
	draw_colored_polygon(Kit.slant(plate), Kit.C_PANEL.lerp(Kit.C_AMBER, 0.16 * a))  # 不透明(後ろの線を透かさない)
	var edge := Kit.slant(plate)
	edge.append(edge[0])
	draw_polyline(edge, Color(Kit.C_AMBER, a), 2.0)
