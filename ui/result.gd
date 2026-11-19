# S3 結果(画面設計書 §4)。合計のタイム、自己ベストとの差、周ごとのタイム(最速の周に印)、壁の回数、共有する文字。
# もう1回は 300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も出す(E-14)。時間切れでは差と枠を出さない。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Share := preload("res://core/share_text.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu
var share := ""
var _shown_at := 0
var _retry: Button
var _copied: Label


# rec は save_store.record() の戻り値。share_text は時間切れなら ""。
func build(result: Dictionary, rec: Dictionary, share_text: String) -> void:
	size = Vector2(1280, 720)
	share = share_text
	_shown_at = Time.get_ticks_msec()
	var done: bool = result["finished"]
	var total := int(result["total_ticks"])
	add_child(Kit.place(Kit.label(S.RES_GOAL % Share.time_text(total) if done else S.TIMEOUT, 56, Kit.C_TEXT, 800), 0, 20, 1280, 84))
	if done and rec["prev_best"] != null:
		var prev := int(rec["prev_best"])
		var diff := Share.hundredths(total) - Share.hundredths(prev)
		var text: String = S.RES_NEW_BEST % Share.diff_text(diff) if diff < 0 else S.RES_TO_BEST % [Share.diff_text(diff), Share.time_text(prev)]
		add_child(Kit.place(Kit.label(text, 24, Kit.C_GOOD if diff < 0 else Kit.C_DIM, 700), 0, 104, 1280, 36))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	var laps: Array = result["lap_ticks"]
	for i in laps.size():
		var best: bool = int(laps[i]) == int(result["best_lap"])
		var s: String = S.RES_LAP % [i + 1, Share.time_text(int(laps[i]))] + (S.RES_FASTEST if best and laps.size() > 1 else "")
		row.add_child(Kit.label(s, 24, Kit.C_TEXT if best else Kit.C_DIM, 500))
	add_child(Kit.place(row, 0, 148, 1280, 40))
	var walls := int(result["walls"])
	add_child(Kit.place(Kit.label(S.RES_WALLS % walls, 24, Kit.C_GOOD if walls == 0 else Kit.C_TEXT, 700), 0, 192, 1280, 36))
	if rec.get("ghost_new", false):
		add_child(Kit.place(Kit.label(S.GHOST_NEW, 20, Kit.C_GOOD), 0, 228, 1280, 30))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 490, 268, 300, 68)
	_retry.disabled = true
	add_child(_retry)
	var list: Array[Button] = [_retry]
	if share != "":
		var box := TextEdit.new()
		box.name = "share"
		box.text = share
		box.editable = false
		box.context_menu_enabled = true
		box.focus_mode = Control.FOCUS_CLICK
		box.add_theme_font_override("font", Kit.font(400))
		box.add_theme_font_size_override("font_size", 18)
		box.add_theme_color_override("font_readonly_color", Kit.C_TEXT)
		add_child(Kit.place(box, 290, 360, 700, 100))
		var copy := Kit.place(Kit.button("copy", S.B_COPY, 24), 420, 476, 200, 56)
		add_child(copy)
		copy.pressed.connect(_copy)
		list.append(copy)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 24), 660 if share != "" else 540, 476, 200, 56)
	add_child(title)
	list.append(title)
	_copied = Kit.label("", 18, Kit.C_DIM)
	add_child(Kit.place(_copied, 0, 540, 1280, 28))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN), 0, 600, 1280, 40))
	_retry.pressed.connect(func() -> void: retry.emit())
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new(list, 0)


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


func _process(_delta: float) -> void:
	if _retry.disabled and Time.get_ticks_msec() - _shown_at >= B.RETRY_LOCK_MS:
		_retry.disabled = false


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled and not (ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed):
		retry.emit()
		return
	menu.key(ev)
