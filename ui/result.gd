# S3 結果(画面設計書 §4。v0.3.0 で作り直した)。合計のタイム(数え上げ)、自己ベストとの差、周ごとの札(最速の周に印と棒)、壁の回数、共有する文字。
# 自己ベストを縮めた時は、タイムの上下に市松の帯が伸びて「新しい記録」の札が出る(calm なら動かさずに出す)。
# もう1回は 300 ms 後から押せる(Enter・R でも)。コピーは clipboard_set を試し、選べる枠も出す(E-14)。時間切れでは差と枠を出さない。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Share := preload("res://core/share_text.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")

const COUNT_MS := 700  # タイムの数え上げ
const BANNER_MS := 450  # 市松の帯が伸びる

var menu: Menu
var share := ""
var celebrate := false  # 自己ベストを縮めた(祝う)
var calm := false  # 「点滅を弱める」が入: 数え上げと帯の動きを省く
var total := 0
var _shown_at := 0
var _retry: Button
var _copied: Label
var _time: Label
var _laps: Array = []  # [札の Rect2, 周の tick, 最速か]
var _max_lap := 1
var _min_lap := 0
var _after: Array = []  # 数え上げが止まってから出す物(自己ベストとの差の行・共有の枠。途中のタイムと食い違わないように)


# rec は save_store.record() の戻り値。share_text は時間切れなら ""。
func build(result: Dictionary, rec: Dictionary, share_text: String, course_label: String = "", p_calm: bool = false) -> void:
	size = Vector2(1280, 720)
	share = share_text
	calm = p_calm
	_shown_at = Time.get_ticks_msec()
	var done: bool = result["finished"]
	total = int(result["total_ticks"])
	add_child(Kit.place(Kit.label(course_label, 18, Kit.C_DIM, 700), 0, 4, 1280, 28))  # どのコースの結果か
	if done:
		add_child(Kit.place(Kit.label(S.GOAL, 22, Kit.C_AMBER, 800), 0, 40, 1280, 32))
		_time = Kit.label(Share.time_text(total), 96, Color.WHITE, 900, true)
		add_child(Kit.place(_time, 0, 90, 1280, 108))
		_time.pivot_offset = _time.size / 2.0
	else:
		add_child(Kit.place(Kit.label(S.TIMEOUT, 72, Color.WHITE, 900), 0, 84, 1280, 110))
	if done and rec["prev_best"] != null:
		var prev := int(rec["prev_best"])
		var diff := Share.hundredths(total) - Share.hundredths(prev)
		celebrate = diff < 0
		var text: String = S.RES_NEW_BEST % Share.diff_text(diff) if diff < 0 else S.RES_TO_BEST % [Share.diff_text(diff), Share.time_text(prev)]
		var dl := Kit.label(text, 22, Kit.C_GOOD if diff < 0 else Kit.C_TEXT, 700)
		add_child(Kit.place(dl, 0, 226, 1280, 32))
		_after.append(dl)
	var laps: Array = result["lap_ticks"]
	var fast := 1 << 30
	for t: Variant in laps:
		_max_lap = maxi(_max_lap, int(t))
		fast = mini(fast, int(t))
	_min_lap = fast
	var x := 640.0 - (laps.size() * 210.0 - 22.0) / 2.0
	var marked := false
	for i in laps.size():
		var best: bool = not marked and int(laps[i]) == int(result["best_lap"]) and laps.size() > 1  # 同じタイムなら先の周だけ
		marked = marked or best
		var r := Rect2(x + i * 210.0, 270, 188, 80)
		_laps.append([r, int(laps[i]), best])
		add_child(Kit.place(Kit.label_left(S.LAP_N % (i + 1), 16, Kit.C_DIM, 700), r.position.x + 16, r.position.y + 6, 80, 26))
		add_child(Kit.place(Kit.label_left(Share.time_text(int(laps[i])), 30, Color.WHITE if best else Kit.C_TEXT, 800, true),
			r.position.x + 16, r.position.y + 30, 160, 40))
		if best:
			add_child(Kit.place(Kit.label(S.FASTEST, 15, Kit.C_AMBER, 800), r.end.x - 70, r.position.y + 6, 62, 26))
	var walls := int(result["walls"])
	var line := S.RES_WALLS % walls
	add_child(Kit.place(Kit.label(line, 20, Kit.C_GOOD if walls == 0 else Kit.C_TEXT, 700), 0, 360, 1280, 28))
	if rec.get("ghost_new", false):
		add_child(Kit.place(Kit.label(S.GHOST_NEW, 16, Kit.C_GOOD, 500), 0, 386, 1280, 22))
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 28), 490, 418, 300, 60)
	_retry.disabled = true
	add_child(_retry)
	var list: Array[Button] = [_retry]
	var title_at := Vector2(545, 498)
	if share != "":
		var box := TextEdit.new()
		box.name = "share"
		box.text = share
		box.editable = false
		box.context_menu_enabled = true
		box.focus_mode = Control.FOCUS_CLICK
		box.scroll_fit_content_height = true  # 3 行が収まる高さにする(枠に送りの棒を出さない)
		add_child(Kit.place(box, 260, 498, 540, 108))
		_after.append(box)
		var copy := Kit.place(Kit.button("copy", S.B_COPY, 22), 832, 498, 190, 48)  # 2 つで枠と同じ高さ(48 + 12 + 48)
		add_child(copy)
		copy.pressed.connect(_copy)
		list.append(copy)
		title_at = Vector2(832, 558)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 22), title_at.x, title_at.y, 190, 48)
	add_child(title)
	list.append(title)
	_copied = Kit.label("", 16, Kit.C_TEXT, 500)
	add_child(Kit.place(_copied, 0, 612, 1280, 24))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 18, Kit.C_WARN, 700), 0, 634, 1280, 28))
	_retry.pressed.connect(func() -> void: retry.emit())
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new(list, 0)
	if calm:
		_after.clear()
	for c: CanvasItem in _after:
		c.modulate.a = 0.0
	_count(0.0 if not calm else 1.0)


# 経った時間の割合(0〜1)。
func progress(ms: int) -> float:
	return 1.0 if calm else clampf(float(Time.get_ticks_msec() - _shown_at) / ms, 0.0, 1.0)


# タイムの数え上げ(字だけを動かす。share と記録は最初から最後の値)。
func _count(p: float) -> void:
	if _time == null:
		return
	var e := 1.0 - pow(1.0 - p, 3.0)
	_time.text = Share.time_text(int(round(total * e)))
	if p >= 1.0 and not calm and _time.scale == Vector2.ONE and _time.has_meta("counting"):
		_time.remove_meta("counting")
		_time.scale = Vector2(1.08, 1.08)  # 止まった所で 1 回はねる
		create_tween().tween_property(_time, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif p < 1.0:
		_time.set_meta("counting", true)


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


func _process(_delta: float) -> void:
	if _retry.disabled:
		queue_redraw()  # 押せるまでの棒
		if Time.get_ticks_msec() - _shown_at >= B.RETRY_LOCK_MS:
			_retry.disabled = false
	if (_time != null and _time.text != Share.time_text(total)) or progress(BANNER_MS) < 1.0:
		_count(progress(COUNT_MS))
		queue_redraw()
	if not _after.is_empty() and progress(COUNT_MS) >= 1.0:
		for c: CanvasItem in _after:
			create_tween().tween_property(c, "modulate:a", 1.0, 0.2)
		_after.clear()


func _draw() -> void:
	# 周の札: 板、最速なら琥珀の縁、下に速さの棒(一番速い周がいっぱい、一番遅い周が 4 割。差が見えるように)
	for l: Array in _laps:
		var r: Rect2 = l[0]
		var best: bool = l[2]
		draw_colored_polygon(Kit.slant(r, 0.08), Kit.C_PANEL)
		var edge := Kit.slant(r, 0.08)
		edge.append(edge[0])
		draw_polyline(edge, Kit.C_AMBER if best else Color(Kit.C_WALL, 0.35), 2.0 if best else 1.0, true)
		var k := 1.0 if _max_lap == _min_lap else 1.0 - 0.3 * float(int(l[1]) - _min_lap) / float(_max_lap - _min_lap)
		draw_rect(Rect2(r.position.x + 16, r.end.y - 12, (r.size.x - 32) * k, 4), Kit.C_AMBER if best else Color(Kit.C_WALL, 0.7))
	if celebrate:
		var p := progress(BANNER_MS)
		var e := 1.0 - pow(1.0 - p, 3.0)
		var w := 720.0 * e
		Kit.draw_checker(self, Rect2(640.0 - w / 2.0, 88, w, 12), maxi(1, int(w / 12.0)), 2, Kit.C_FLAG, Kit.C_BG)
		Kit.draw_checker(self, Rect2(640.0 - w / 2.0, 202, w, 12), maxi(1, int(w / 12.0)), 2, Kit.C_FLAG, Kit.C_BG)
		if p >= 1.0:  # 上の市松の帯の右端に「新しい記録」の札(右の角を帯の右端に揃える)
			var plate := Rect2(0, 70, 168, 32)
			plate.position.x = 640.0 + 360.0 - plate.size.x - plate.size.y * Kit.SKEW / 2.0
			draw_colored_polygon(Kit.slant(plate), Kit.C_AMBER)
			draw_string(Kit.font(800), Vector2(plate.position.x, plate.position.y + 23), S.GOAL_NEW_BEST, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 18, Kit.C_BG)
	var locked := _retry.disabled
	if locked:  # 押せるまでの 300 ms: ボタンの下の縁に琥珀の棒が左から伸びる
		var r := _retry.get_rect()
		var k := clampf(float(Time.get_ticks_msec() - _shown_at) / B.RETRY_LOCK_MS, 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 12, r.end.y + 4, (r.size.x - 24) * k, 3), Kit.C_AMBER)
	Kit.draw_hints(self, [["R", S.B_RETRY], ["updown", S.HINT_SELECT], ["Enter", S.HINT_OK]], 640, 668, true, 0.45 if locked else 1.0)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled and not (ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed):
		retry.emit()
		return
	menu.key(ev)
