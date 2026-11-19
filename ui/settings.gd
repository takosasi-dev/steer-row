# S4 設定(共通 §6・画面設計書 §6)。音量(5 段)・画面の揺れ・点滅を弱める・画面の回転・操作(10 キー / W A S D)・キーの確かめ。
# デバッグ版だけ「矢印のハンドル」も出す(FR-27。保存しない)。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。← → でも値を変えられる。
# キーの確かめ: 中の段の 10 キーと Space を並べ、押されているキーを光らせ、最後に届いたキーの中身を文字で出す(共通 §3 の 22。作りは KeyFlak)。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Menu := preload("res://ui/menu.gd")

var menu: Menu
var store: RefCounted
var arrows := false  # 矢印のハンドル(main が持つ値をここで切り替え、戻る時に main が読む)
var keys_view := false
var held := {}  # キーの確かめで押されている物理キー
var last_key := ""  # 最後に届いたキーの中身
var keys_drawn := 0  # キーの確かめの図を描いた回数(自動の確かめが読む)
var _rows := {}  # 項目の名前 → ボタン
var _list: Control
var _keys: Control
var _detail: Label


func build(p_store: RefCounted, p_arrows: bool) -> void:
	store = p_store
	arrows = p_arrows
	size = Vector2(1280, 720)
	_list = Control.new()
	_list.size = size
	add_child(_list)
	_list.add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 700), 0, 24, 1280, 60))
	var names := ["volume", "shake", "reduce_flash", "rotate", "controls"]
	if OS.is_debug_build():
		names.append("arrows")
	names.append_array(["keys", "back"])
	var order: Array[Button] = []
	var y := 96.0
	for nm: String in names:
		var b := Kit.place(Kit.button(nm, "", 24), 390 if nm != "back" else 520, y, 500 if nm != "back" else 240, 60)
		_list.add_child(b)
		_rows[nm] = b
		order.append(b)
		b.pressed.connect(_press.bind(nm, 1))
		y += 70.0
	_rows["keys"].text = S.B_KEYS
	_rows["back"].text = S.B_BACK
	menu = Menu.new(order, 0)
	_keys = Control.new()
	_keys.size = size
	_keys.visible = false
	_keys.draw.connect(_draw_keys)  # 一時停止から開いた時の暗い幕より上に描く
	add_child(_keys)
	_keys.add_child(Kit.place(Kit.label(S.B_KEYS, 40, Kit.C_TEXT, 700), 0, 60, 1280, 60))
	_keys.add_child(Kit.place(Kit.label(S.KEYS_HELP, 20, Kit.C_DIM), 0, 130, 1280, 32))
	_detail = Kit.label("", 18, Kit.C_DIM)
	_keys.add_child(Kit.place(_detail, 0, 470, 1280, 32))
	_paint()


func _paint() -> void:
	var st: Dictionary = store.settings()
	_rows["volume"].text = "%s  %d" % [S.SET_VOLUME, int(st["volume"])]
	_rows["shake"].text = "%s  %s" % [S.SET_SHAKE, S.ON if st["shake"] else S.OFF]
	_rows["reduce_flash"].text = "%s  %s" % [S.SET_FLASH, S.ON if st["reduce_flash"] else S.OFF]
	_rows["rotate"].text = "%s  %s" % [S.SET_ROTATE, S.ON if st["rotate"] else S.OFF]
	_rows["controls"].text = "%s  %s" % [S.SET_CONTROLS, S.CONTROLS_WASD if st["controls"] == "wasd" else S.CONTROLS_ROW]
	if _rows.has("arrows"):
		_rows["arrows"].text = "%s  %s" % [S.SET_ARROWS, S.ON if arrows else S.OFF]


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
	var f := Kit.font(700)
	for i in 11:
		var r := Rect2(90 + i * 100, 240, 90, 90) if i < 10 else Rect2(440, 350, 400, 60)
		var pk: int = Keymap.ROW[i] if i < 10 else KEY_SPACE
		var on := held.has(pk)
		_keys.draw_rect(r, Color(Kit.C_CAR, 0.85) if on else Color(1, 1, 1, 0.05))
		_keys.draw_rect(r, Kit.C_CAR if on else Color(Kit.C_TEXT, 0.4), false, 3.0)
		var text: String = S.KEYS[i] if i < 10 else OS.get_keycode_string(KEY_SPACE)
		_keys.draw_string(f, Vector2(r.position.x, r.position.y + r.size.y / 2 + 12), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Kit.C_BG if on else Kit.C_TEXT)
	_keys.draw_string(f, Vector2(0, 450), str(held.size()), HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Kit.C_TEXT)
