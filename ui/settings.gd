# S4 設定(共通 §6・画面設計書 §6。v0.3.0 で作り直した)。音量(5 段)・画面の揺れ・点滅を弱める・画面の回転・操作(10 キー / W A S D)・キーの確かめ。
# デバッグ版だけ「矢印のハンドル」も出す(FR-27。保存しない)。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。← → でも値を変えられる。
# 行の左に項目の名前、右に今の値(音量は 5 つの目盛り、入・切はスイッチ、操作は左右の三角つき)。下に操作の案内。
# キーの確かめ: 中の段の 10 キーと Space を並べ、押されているキーを光らせ、最後に届いたキーの中身を文字で出す(共通 §3 の 22。作りは KeyFlak)。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Menu := preload("res://ui/menu.gd")

const ROW_X := 330.0
const ROW_W := 620.0
const VAL_X := 360.0  # 行の中で値を描き始める x

var menu: Menu
var store: RefCounted
var arrows := false  # 矢印のハンドル(main が持つ値をここで切り替え、戻る時に main が読む)
var keys_view := false
var held := {}  # キーの確かめで押されている物理キー
var last_key := ""  # 最後に届いたキーの中身
var keys_drawn := 0  # キーの確かめの図を描いた回数(自動の確かめが読む)
var _rows := {}  # 項目の名前 → ボタン
var _vals := {}  # 項目の名前 → 値の字
var _list: Control
var _deco: Control
var _keys: Control
var _detail: Label


func build(p_store: RefCounted, p_arrows: bool) -> void:
	store = p_store
	arrows = p_arrows
	size = Vector2(1280, 720)
	_list = Control.new()
	_list.size = size
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	_list.add_child(Kit.place(Kit.label_left(S.SETTINGS, 32, Color.WHITE, 800), ROW_X + 26, 22, 400, 52))
	var names := ["volume", "shake", "reduce_flash", "rotate", "controls"]
	if OS.is_debug_build():
		names.append("arrows")
	names.append_array(["keys", "back"])
	var order: Array[Button] = []
	var y := 96.0
	for nm: String in names:
		var label: String = {"volume": S.SET_VOLUME, "shake": S.SET_SHAKE, "reduce_flash": S.SET_FLASH, "rotate": S.SET_ROTATE,
			"controls": S.SET_CONTROLS, "arrows": S.SET_ARROWS, "keys": S.B_KEYS, "back": S.B_BACK}[nm]
		var b := Kit.place(Kit.button(nm, label, 22), ROW_X, y, ROW_W if nm != "back" else 240.0, 54)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)
		_rows[nm] = b
		order.append(b)
		b.pressed.connect(_press.bind(nm, 1))
		if nm not in ["keys", "back"]:
			var v := Kit.label("", 22, Color.WHITE, 800, true)
			if nm == "controls":  # 左右の三角の間(値の列の左端から)
				b.add_child(Kit.place(v, VAL_X + 14, 0, 118, 54))
			else:  # 目盛り・スイッチのすぐ右
				v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.add_child(Kit.place(v, VAL_X + (118 if nm == "volume" else 76), 0, 100, 54))
			_vals[nm] = v
		y += 64.0 if nm != "keys" else 76.0
	menu = Menu.new(order, 0)
	_deco = Control.new()  # 値の絵と案内(一時停止から開いた時の暗い幕と、ボタンより上に描く)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	_list.add_child(_deco)
	_keys = Control.new()
	_keys.size = size
	_keys.visible = false
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.draw.connect(_draw_keys)  # 一時停止から開いた時の暗い幕より上に描く
	add_child(_keys)
	_keys.add_child(Kit.place(Kit.label_left(S.B_KEYS, 32, Color.WHITE, 800), 116, 52, 600, 52))
	_keys.add_child(Kit.place(Kit.label_left(S.KEYS_HELP, 20, Kit.C_TEXT, 500), 90, 112, 1100, 32))
	_detail = Kit.label("", 16, Kit.C_DIM, 500)
	_keys.add_child(Kit.place(_detail, 0, 574, 1280, 30))
	_paint()


func _paint() -> void:
	var st: Dictionary = store.settings()
	_vals["volume"].text = str(int(st["volume"]))
	for nm: String in ["shake", "reduce_flash", "rotate"]:
		_vals[nm].text = S.ON if st[nm] else S.OFF
	_vals["controls"].text = S.CONTROLS_WASD if st["controls"] == "wasd" else S.CONTROLS_ROW
	if _vals.has("arrows"):
		_vals["arrows"].text = S.ON if arrows else S.OFF
	_deco.queue_redraw()


# 行ごとの値の絵(字は _vals のラベル)。
func _draw_deco() -> void:
	Kit.draw_tick(_deco, Vector2(ROW_X, 36), 24)
	var st: Dictionary = store.settings()
	for nm: String in _vals:
		var b: Button = _rows[nm]
		var r := Rect2(b.position + Vector2(VAL_X, 0), Vector2(ROW_W - VAL_X - 30, b.size.y))
		var cy := r.get_center().y
		match nm:
			"volume":  # 5 つの目盛り(0 は全部空)
				var lv: int = B.VOLUMES.find(int(st["volume"]))
				for k in B.VOLUMES.size() - 1:
					var seg := Rect2(r.position.x + k * 26.0, cy - 9, 20, 18)
					var on := k < lv
					_deco.draw_colored_polygon(Kit.slant(seg, 0.4), Kit.C_AMBER if on else Color(Kit.C_WALL, 0.25))
			"controls":  # 左右の三角(← → で替えられる)
				Kit._tri_h(_deco, Vector2(r.position.x + 5, cy), -1, Kit.C_AMBER)
				Kit._tri_h(_deco, Vector2(r.position.x + 140, cy), 1, Kit.C_AMBER)
			_:  # 入・切のスイッチ
				var on: bool = arrows if nm == "arrows" else bool(st[nm])
				var pill := Rect2(r.position.x, cy - 13, 60, 26)
				_deco.draw_rect(pill, Kit.C_AMBER if on else Color(Kit.C_PANEL_2, 1.0))
				_deco.draw_rect(pill, Kit.C_AMBER if on else Kit.C_WALL, false, 2.0)
				var knob := Rect2(pill.position + Vector2(36 if on else 4, 4), Vector2(20, 18))
				_deco.draw_rect(knob, Kit.C_BG if on else Kit.C_WALL)
	var kb: Button = _rows["keys"]  # キーの確かめは別の画面へ進む: 右端に右向きの三角を 2 つ
	for k in 2:
		var c := kb.position + Vector2(ROW_W - 60 + k * 14, kb.size.y / 2.0)
		_deco.draw_colored_polygon(PackedVector2Array([c + Vector2(8, 0), c + Vector2(-6, -9), c + Vector2(-6, 9)]), Color(Kit.C_AMBER, 0.55 + k * 0.45))
	Kit.draw_hints(_deco, [["updown", S.HINT_SELECT], ["leftright", S.HINT_CHANGE], ["Enter", S.HINT_OK], ["Esc", S.B_BACK]], 640, 668, true)


# 項目を押した・← → で変えた(d は −1 か 1。音量だけが向きを使う)。
func _press(nm: String, d: int) -> void:
	match nm:
		"volume":
			var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
			var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
			store.set_setting("volume", v)
			Sfx.set_volume(v)
			Sfx.play("lap")
		"shake", "reduce_flash", "rotate":
			store.set_setting(nm, not store.settings()[nm])
		"controls":
			store.set_setting("controls", "row" if store.settings()["controls"] == "wasd" else "wasd")
		"arrows":
			arrows = not arrows
		"keys":
			_show_keys(true)
		"back":
			back.emit()
	_paint()


func _show_keys(on: bool) -> void:
	keys_view = on
	held.clear()
	_list.visible = not on
	_keys.visible = on
	_keys.queue_redraw()


# フォーカスが外れた時は、押されている組を空にする(共通 §3 の 5)。
func release_all() -> void:
	held.clear()
	_keys.queue_redraw()


func key(ev: InputEventKey) -> void:
	if keys_view:
		_keys_key(ev)
		return
	if not ev.pressed or ev.echo:
		return
	var nm := String(menu.buttons[menu.sel].name)
	if ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	elif ev.physical_keycode in [KEY_LEFT, KEY_RIGHT] and nm not in ["keys", "back"]:
		_press(nm, -1 if ev.physical_keycode == KEY_LEFT else 1)
		if nm != "volume":  # 音量はその音量で鳴らす
			Sfx.play("select")
	else:
		menu.key(ev)


func _keys_key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		_show_keys(false)
		return
	last_key = S.KEY_DETAIL % [
		ev.physical_keycode, OS.get_keycode_string(ev.physical_keycode), OS.get_keycode_string(ev.key_label), ev.unicode,
		ev.pressed, ev.echo, ev.ctrl_pressed, ev.alt_pressed, ev.meta_pressed, ev.shift_pressed]
	_detail.text = last_key
	if Keymap.ROW.has(ev.physical_keycode) or ev.physical_keycode == KEY_SPACE:
		if ev.pressed:
			held[int(ev.physical_keycode)] = true
		else:
			held.erase(int(ev.physical_keycode))
	_keys.queue_redraw()


# キーの確かめの図: 10 キーと Space を並べ、押されているキーを光らせる。下に押さえている数。
func _draw_keys() -> void:
	keys_drawn += 1
	Kit.draw_tick(_keys, Vector2(90, 66), 24)
	var f := Kit.font(700)
	for i in 11:
		var r := Rect2(95 + i * 110, 200, 90, 90) if i < 10 else Rect2(420, 310, 440, 64)
		var pk: int = Keymap.ROW[i] if i < 10 else KEY_SPACE
		var on := held.has(pk)
		_keys.draw_rect(r, Color(Kit.C_CAR, 0.95) if on else Color(Kit.C_PANEL_2, 0.95))
		_keys.draw_rect(Rect2(r.position.x, r.end.y - 7, r.size.x, 7), Color(0, 0, 0, 0.35))
		_keys.draw_rect(r, Kit.C_CAR if on else Color(Kit.C_WALL, 0.6), false, 2.0)
		var text: String = S.KEYS[i] if i < 10 else OS.get_keycode_string(KEY_SPACE)
		_keys.draw_string(f, Vector2(r.position.x, r.position.y + r.size.y / 2 + 10), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Kit.C_BG if on else Kit.C_TEXT)
	_keys.draw_string(Kit.font(700), Vector2(0, 422), S.KEYS_HELD, HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Kit.C_TEXT)
	_keys.draw_string(Kit.display(800), Vector2(0, 484), str(held.size()), HORIZONTAL_ALIGNMENT_CENTER, 1280, 56, Color.WHITE if held.size() > 0 else Kit.C_DIM)
	# 最後に届いたキーの中身(共通 §3 の 22)は、見出しを付けて細い線で分け、下へ離す
	_keys.draw_line(Vector2(240, 540), Vector2(1040, 540), Color(Kit.C_WALL, 0.3), 1.0)
	_keys.draw_string(Kit.font(700), Vector2(0, 566), S.KEYS_LAST, HORIZONTAL_ALIGNMENT_CENTER, 1280, 15, Kit.C_DIM)
	Kit.draw_hints(_keys, [["Esc", S.B_BACK]], 640, 668, true)
