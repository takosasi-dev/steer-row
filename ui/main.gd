# 画面の切り替え(S0〜S6)・入力の振り分け・保存・自動の一時停止を受け持つ。ゲームの決まりは持たない(INV-1)。作りは KeyFlak の ui/main.gd。
# --auto(デバッグ版だけ)で S0 → タイトル → 設定 → 入口 → 一時停止 → 結果 → もう1回 → 結果 を、中心 bot で自動で通して終わる(ヘッドレスの smoke)。
extends Node

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Bots := preload("res://core/bots.gd")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Courses := preload("res://ui/courses.gd")
const Play := preload("res://ui/play.gd")
const Title := preload("res://ui/title.gd")
const CourseList := preload("res://ui/course_list.gd")
const Result := preload("res://ui/result.gd")
const Settings := preload("res://ui/settings.gd")
const Pause := preload("res://ui/pause.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const Gate := preload("res://ui/gate.gd")

# 画面の切り替わり(v0.3.0)。新しい画面はすぐに動かし(入力を飲まない)、古い画面の写しを右へ流れる帯の向こうに残して消す。
const WIPE_MS := 300  # ふつうの切り替わり
const WIPE_FAST_MS := 170  # 結果・一時停止からもう1回(遊びに入るまでを遅くしない)
const FADE_MS := 150  # 「点滅を弱める」が入の時は帯を流さず、新しい画面を薄く出すだけ
const WIPE_BODY := 260.0  # 帯の幅
const WIPE_SKEW := 0.15

var stage: Control
var backdrop: Backdrop
var wipe: Control  # 流れる帯(舞台の一番上)
var wipe_p := 1.0  # 帯の進み(0〜1。1 で終わり)
var _leaving: Control = null  # 古い画面の写しの入れ物(帯より右だけを見せる)
var _leaving_inner: Control = null
var _wipe_tween: Tween = null
var _bg: ColorRect
var store: Store
var screen := "gate"  # gate / title / pick / play / result / settings
var current: Control = null  # 今の画面(play の時は play)
var play: Play = null
var pause_view: Pause = null
var settings_from := "title"
var run := {}  # 今の走り { entry, course, day, date }
var arrows := false  # 矢印のハンドル(デバッグ版だけ。保存しない)
var auto := false
var _touch_note: Label = null
var _visibility_cb: Variant = null
var _auto_results := 0
var _auto_step := 0
var play_view_draws := 0  # smoke が印字する(描いた回数とタイヤの跡の本数)
var play_skids := 0
var _costs: Array = []  # smoke で測った 1 フレームの _process と描く時間(usec。NFR-1)
var debug := false  # ?debug=1: window.srState に状態を出す(Web の自動の確かめが読むだけ)
var last_run := {}  # 直前の走りの記録と最後の位置(R-4 の照らしで読む)
var lat_ms: Array = []  # ハンドルのキーを押してから、それを sim に渡した後の絵を描き終わるまで(NFR-2 の目安)
var frame_ms: Array = []
var _last_frame := 0
var _lat_seen := 0
var rot_dps: Array = []  # 画面の回る速さ(度/秒。フレームごと)
var flow: Array = []  # 道が流れた量 ÷(速さ × フレームの時間)。描く位置
var flow_raw: Array = []  # 同じ物を sim の生の位置で
var _prev_motion := []
var _last_motion := 0


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	_bg = ColorRect.new()
	_bg.color = Kit.C_BG
	stage.add_child(Kit.place(_bg, -2000, -2000, 5280, 4720))
	backdrop = Backdrop.new()
	stage.add_child(backdrop)
	wipe = Control.new()
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.draw.connect(_draw_wipe)
	stage.add_child(wipe)
	get_viewport().size_changed.connect(_layout)
	_layout()
	store = Store.new()
	_apply_settings()
	auto = OS.is_debug_build() and OS.get_cmdline_user_args().has("--auto")  # 公開版では効かせない(bot の記録を保存しない)
	if auto:
		Engine.time_scale = 4.0  # 1 フレーム 8 tick(上限)で進める
	debug = OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("debug=1")
	RenderingServer.frame_post_draw.connect(_after_draw)
	_watch_visibility()
	_show_gate()


# 縦横比が 16:9 でない窓では表示の範囲が広がる(project.godot の aspect=expand)。舞台をその真ん中に置き、余りは背景色にする(共通 §3 の 1)。
func _layout() -> void:
	stage.position = ((get_viewport().get_visible_rect().size - stage.size) / 2.0).floor()


func _apply_settings() -> void:
	Sfx.set_volume(int(store.settings()["volume"]))
	backdrop.moving = not store.settings()["reduce_flash"]


# 今の画面を片付ける。画面は消さずに、帯の向こうに残す入れ物へ移す(動きを止め、マウスも受けない)。消すのは帯が流れ終わった時。
# 「点滅を弱める」が入なら、すぐ消す。
func _clear() -> void:
	pause_view = null
	_drop_leaving()
	var olds: Array = stage.get_children().filter(func(c: Node) -> bool: return c != _bg and c != backdrop and c != wipe)
	if not olds.is_empty() and not store.settings()["reduce_flash"]:
		_leaving = Control.new()
		_leaving.clip_contents = true
		_leaving.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_leaving.process_mode = Node.PROCESS_MODE_DISABLED
		_leaving.position = Vector2(-2000, -2000)
		_leaving.size = Vector2(6000, 6000)
		_leaving_inner = Control.new()
		_leaving_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_leaving_inner.position = Vector2(2000, 2000)
		_leaving.add_child(_leaving_inner)
		var under := ColorRect.new()  # 古い画面の下を塞ぐ(新しい画面が透けて見えないように)
		under.color = Kit.C_BG
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_leaving_inner.add_child(Kit.place(under, -2000, -2000, 5280, 4720))
		stage.add_child(_leaving)
		for c: Node in olds:
			c.reparent(_leaving_inner, false)
			for k: Node in [c] + c.find_children("*", "Control", true, false):
				if k is Control:
					(k as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		for c: Node in olds:
			c.queue_free()
	current = null
	play = null
	Sfx.stop_loops()


func _drop_leaving() -> void:
	if _leaving != null:
		_leaving.queue_free()
		_leaving = null
		_leaving_inner = null


# 新しい画面を置いた後に呼ぶ。帯を左から右へ流し、帯より左に新しい画面、右に古い画面を見せる。入力は新しい画面がすぐに受ける。
func _enter(ms: int = WIPE_MS) -> void:
	backdrop.visible = screen != "play"
	if _wipe_tween != null:
		_wipe_tween.kill()
	if store.settings()["reduce_flash"] or _leaving == null:
		_drop_leaving()
		wipe_p = 1.0
		wipe.queue_redraw()
		if current != null and screen != "gate":
			current.modulate.a = 0.0
			_wipe_tween = create_tween()
			_wipe_tween.tween_property(current, "modulate:a", 1.0, FADE_MS / 1000.0)
		return
	stage.move_child(_leaving, -1)
	stage.move_child(wipe, -1)
	_wipe_step(0.0)
	_wipe_tween = create_tween()
	_wipe_tween.tween_method(_wipe_step, 0.0, 1.0, ms / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_wipe_tween.tween_callback(_drop_leaving)


# 帯の前の端の x(舞台の座標)。帯の幅と傾きのぶん、画面の外から外まで動かす。
func wipe_edge(p: float) -> float:
	var left := -stage.position.x - 300.0
	var right := get_viewport().get_visible_rect().size.x - stage.position.x + WIPE_BODY + 300.0
	return lerpf(left, right, p)


func _wipe_step(p: float) -> void:
	wipe_p = p
	if _leaving != null:
		var cut := wipe_edge(p) - WIPE_BODY / 2.0  # 帯の真ん中で切る(傾いた縁は帯が隠す)
		_leaving.position.x = cut
		_leaving.size.x = 9000.0
		_leaving_inner.position.x = -cut
	wipe.queue_redraw()


# 帯: 暗い板、後ろの縁に市松の列、前の縁に琥珀の線(横に流れる。題材の「市松・速さ」)。
func _draw_wipe() -> void:
	if wipe_p >= 1.0:
		return
	var x := wipe_edge(wipe_p)
	var top := -stage.position.y - 40.0
	var bottom := get_viewport().get_visible_rect().size.y - stage.position.y + 40.0
	var h := bottom - top
	var d := h * WIPE_SKEW / 2.0
	var body := PackedVector2Array([Vector2(x - WIPE_BODY + d, top), Vector2(x + d, top), Vector2(x - d, bottom), Vector2(x - WIPE_BODY - d, bottom)])
	wipe.draw_colored_polygon(body, Kit.C_PANEL)
	wipe.draw_colored_polygon(PackedVector2Array([Vector2(x - 10 + d, top), Vector2(x + d, top), Vector2(x - d, bottom), Vector2(x - 10 - d, bottom)]), Kit.C_AMBER)
	var cell := 22.0
	var rows := int(h / cell) + 1
	for r in rows:
		var y := top + r * cell
		var off := d - (y - top) * WIPE_SKEW
		for c in 2:
			if (r + c) % 2 == 0:
				var x0 := x - WIPE_BODY + off + c * cell
				wipe.draw_rect(Rect2(x0, y, cell, cell), Kit.C_FLAG)


# --- S0 始める ---

func _show_gate() -> void:
	_clear()
	screen = "gate"
	var g := Gate.new()
	g.build(not store.settings()["reduce_flash"])
	_touch_note = g.touch_note
	stage.add_child(g)
	current = g
	_enter()


func _input(event: InputEvent) -> void:
	if screen == "gate":
		if event is InputEventScreenTouch and event.pressed:
			_touch_note.visible = true  # FR-26: タッチで開いた人に伝える
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
			return  # タッチから作られたマウスのイベント
		if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
			Sfx.unlock()  # FR-23: この入力はゲームの操作に数えない
			get_viewport().set_input_as_handled()
			_show_title()
		return
	if not (event is InputEventKey):
		return
	if play != null:
		play.track_key(event)  # 一時停止・設定の間も、押されている組は押す・離すで直す(E-11)
	if screen != "play" and (event.ctrl_pressed or event.meta_pressed or event.alt_pressed):
		return  # 結果の枠の Ctrl+C などは部品に渡す(FR-24: ゲームの操作には数えない)
	get_viewport().set_input_as_handled()  # 矢印・Space を Godot のフォーカスの移動に使わせない
	if screen == "settings":
		current.key(event)
	elif pause_view != null:
		pause_view.key(event)
	elif current != null and current.has_method("key"):
		current.key(event)


# 端末の今日の日付。始めた時の日付でコースを決める(E-15)。
func _today() -> Dictionary:
	var t := Time.get_date_dict_from_system()
	var y := int(t["year"])
	var m := int(t["month"])
	var dd := int(t["day"])
	var day := Day.day_index(y, m, dd)
	return {"day": day, "date": Day.date_string(y, m, dd), "course": Day.today_course(day)}


# --- S1 タイトル・S6 コースを選ぶ ---

func _show_title() -> void:
	_clear()
	screen = "title"
	var d := _today()
	var t := Title.new()
	t.build(store, d["day"], d["course"])
	t.chosen.connect(_on_title)
	stage.add_child(t)
	current = t
	_enter()


func _on_title(what: String) -> void:
	var d := _today()
	match what:
		"settings":
			_show_settings("title")
		"intro":
			_start({"entry": Share.INTRO, "course": B.INTRO, "day": d["day"], "date": d["date"]})
		"daily":
			_start({"entry": Share.DAILY, "course": d["course"], "day": d["day"], "date": d["date"]})
		"pick":
			_show_pick()


func _show_pick() -> void:
	_clear()
	screen = "pick"
	var v := CourseList.new()
	v.build(store, _today()["course"])
	v.picked.connect(func(k: int) -> void:
		var d := _today()
		_start({"entry": Share.PICK, "course": k, "day": d["day"], "date": d["date"]}))
	v.back.connect(_show_title)
	stage.add_child(v)
	current = v
	_enter()


# --- S2 プレイ ---

func _start(r: Dictionary) -> void:
	var fast := screen in ["result", "play"]  # もう1回・やり直す(遊びに入るまでを遅くしない)
	_clear()
	run = r
	screen = "play"
	var k := int(r["course"])
	var course := Courses.load_course(k)
	var ghost := store.ghost(k)
	var c: Variant = store.course(k)
	play = Play.new()
	play.arrows = arrows
	stage.add_child(play)
	play.start(course, ghost, store.settings(), int(c["best_ticks"]) if c != null else -1)
	if ghost != "" and not play.sim.has_ghost():
		store.drop_ghost(k)  # E-7: 壊れた幽霊は出さずに消す
	if auto:
		if _auto_step != 5:  # 3 回目は W A S D で、速くなってから右いっぱいに切って滑らせ、壁に当てる(描く道を通すため)
			play.bot = Bots.new(Bots.CENTER)
	play.finished.connect(_on_finished)
	play.pause_requested.connect(_pause)
	current = play
	_enter(WIPE_FAST_MS if fast else WIPE_MS)


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.paused = true
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)
	_fade_in(pause_view)


func _on_pause(what: String) -> void:
	match what:
		"resume":
			pause_view.queue_free()
			pause_view = null
			play.paused = false  # 押した tick から再開(待ち時間なし)
		"restart":
			_start(run)
		"settings":
			_show_settings("pause")
		"title":
			_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_focus_lost()


# フォーカスが外れた・タブが裏に回った(E-10・E-11)。押されている組を空にし、走っていれば一時停止。戻っても自動では再開しない。
func _focus_lost() -> void:
	if play != null:
		play.release_all()
	if screen in ["settings", "title"] and current != null:
		current.release_all()
	_pause()


# タブが裏に回ったら一時停止にする。Web では通知が来ないことがあるので、ブラウザにも聞く(ParryDuel と同じ)。
func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	_visibility_cb = JavaScriptBridge.create_callback(func(_args: Array) -> void: _focus_lost())
	var doc: Variant = JavaScriptBridge.get_interface("document")
	if doc != null:
		doc.addEventListener("visibilitychange", _visibility_cb)


# --- S3 結果 ---

func _on_finished(result: Dictionary, record: String) -> void:
	var r := run
	var k := int(r["course"])
	play_view_draws = play.view.draws
	play_skids = play.view.skids.size()
	var gc: RefCounted = play.sim.ghost_car
	last_run = {"course": k, "record": record, "ticks": int(result["total_ticks"]), "walls": int(result["walls"]),
		"pos": "%.6f,%.6f" % [play.sim.car.x, play.sim.car.y],
		"ghost_pos": "%.6f,%.6f" % [gc.x, gc.y] if gc != null else "", "ghost_done": play.sim.ghost_done}
	for i in mini(play.cost_us.size(), play.view.draw_us.size()):
		_costs.append(int(play.cost_us[i]) + int(play.view.draw_us[i]))
	var rec: Dictionary
	if arrows:  # FR-27: 矢印のハンドルの走りは記録も幽霊も作らない
		var c: Variant = store.course(k)
		rec = {"prev_best": c["best_ticks"] if c != null else null, "new_best": false, "first_today": false, "ghost_new": false, "saved": true}
	else:
		rec = store.record(k, r["entry"], int(r["day"]), result, record)
	var text := Share.make(r["date"], r["entry"], k, rec["first_today"], result) if result["finished"] else ""
	_clear()
	screen = "result"
	var v := Result.new()
	var label: String = S.SHARE_INTRO if k == B.INTRO else "%s  %s" % [S.COURSE_N % k, S.COURSE_NAMES[k]]
	if r["entry"] == Share.DAILY:
		label = S.B_DAILY + "   " + label
	v.build(result, rec, text, label, store.settings()["reduce_flash"])
	v.retry.connect(func() -> void: _start(run))  # FR-17: 同じコース
	v.to_title.connect(_show_title)
	stage.add_child(v)
	current = v
	_enter()
	if auto:
		_auto_results += 1
		print("SMOKE result %d: %s" % [_auto_results, JSON.stringify(result)])
		print("SMOKE view draws %d skids %d walls %d rotate %s controls %s" % [play_view_draws, play_skids, int(result["walls"]), store.settings()["rotate"], store.settings()["controls"]])
		print(text)


# --- S4 設定 ---

func _show_settings(from: String) -> void:
	settings_from = from
	var s := Settings.new()
	s.build(store, arrows)
	s.back.connect(_settings_back.bind(s))
	if from == "pause":
		pause_view.visible = false
		var dim := ColorRect.new()
		dim.color = Color(Kit.C_BG, 0.96)
		s.add_child(Kit.place(dim, -2000, -2000, 5280, 4720))  # 16:9 でない窓の余りまで覆う
		s.move_child(dim, 0)
		stage.add_child(s)
		current = s
		screen = "settings"
		pause_view.process_mode = Node.PROCESS_MODE_DISABLED
		_fade_in(s)
	else:
		_clear()
		screen = "settings"
		stage.add_child(s)
		current = s
		_enter()


# 重ねる画面(一時停止・一時停止から開いた設定)は帯を流さず、薄く出す(下の遊びの画面が隠れたままにならないように短く)。
func _fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, FADE_MS / 1000.0)


func _settings_back(s: Control) -> void:
	_apply_settings()
	arrows = s.arrows
	if settings_from == "pause" and play != null:
		var st: Dictionary = store.settings()
		play.shake_on = st["shake"]
		play.view.reduce_flash = st["reduce_flash"]
		play.view.rotate_on = st["rotate"]
		play.view.wasd = st["controls"] == "wasd"
		play.controls = st["controls"]
		play.arrows = arrows
		play.held.clear()  # 操作を替えたかもしれないので、押し直すまで押していないものとする
		s.queue_free()
		pause_view.visible = true
		pause_view.process_mode = Node.PROCESS_MODE_INHERIT
		current = play
		screen = "play"
	else:
		_show_title()


# --- 自動の確かめ(smoke) ---

func _process(_delta: float) -> void:
	if not auto:
		return
	match screen:
		"gate":
			print("SMOKE gate")
			_input(_key(KEY_X))
		"title":
			print("SMOKE title")
			if _auto_step == 0:
				_auto_step = 1
				_input(_key(KEY_UP))
				_input(_key(KEY_ENTER))  # 設定(一番下)
			elif _auto_step == 4:
				_auto_step = 5
				_input(_key(KEY_DOWN))
				_input(_key(KEY_ENTER))  # コースを選ぶ(入門の後は 2 番目)
			else:
				_input(_key(KEY_ENTER))  # 一番上の入口
		"settings":
			# 設定 → キーの確かめ → A を押す → 戻る
			if not current.keys_view and current.keys_drawn == 0:
				current.menu.select(current.menu.buttons.size() - 2)
				_input(_key(KEY_ENTER))
				_input(_key(KEY_A))
			elif current.keys_view and current.keys_drawn > 0:
				print("SMOKE keys drawn %d held %d" % [current.keys_drawn, current.held.size()])
				_input(_key(KEY_ESCAPE))
				_input(_key(KEY_ESCAPE))
		"pick":
			_input(_key(KEY_DOWN))
			_input(_key(KEY_ENTER))  # コース 1
		"play":
			if _auto_step == 5 and play.bot == null and play.sim.race_tick > 280 and play.held.is_empty():
				play.held[KEY_D] = true
			if _auto_step == 5 and play.bot == null and play.sim.race_tick > 500:
				play.held.clear()
				play.bot = Bots.new(Bots.CENTER)
			# 1 回目の走りの途中で 1 度、一時停止して続ける
			if _auto_step == 1 and play.sim.race_tick > 600 and pause_view == null:
				_auto_step = 2
				_input(_key(KEY_ESCAPE))
			elif _auto_step == 2 and pause_view != null:
				print("SMOKE pause back")
				_auto_step = 3
				_input(_key(KEY_ESCAPE))
		"result":
			if not current._retry.disabled:
				if _auto_results == 2:
					store.set_setting("controls", "wasd")
					store.set_setting("rotate", false)
					_auto_step = 4
					_input(_key(KEY_UP))
					_input(_key(KEY_ENTER))  # タイトルへ
				elif _auto_results >= 3:
					var c: Array = _costs
					c.sort()
					if not c.is_empty():
						print("SMOKE frame cost p95 %.2f ms (%d frames)" % [c[int(c.size() * 0.95)] / 1000.0, c.size()])
					print("SMOKE done")
					get_tree().quit(0)
					auto = false
				else:
					_input(_key(KEY_ENTER))  # もう1回


# --- デバッグ用の窓口(?debug=1 の Web だけ。読むだけ。作りは KeySwat) ---

func _after_draw() -> void:
	var now := Time.get_ticks_usec()
	if _last_frame > 0 and frame_ms.size() < 20000 and screen == "play":
		frame_ms.append((now - _last_frame) / 1000.0)
	_last_frame = now
	_watch_motion((now - _last_motion) / 1000000.0)
	_last_motion = now
	if play != null and play.stepped_key_at > _lat_seen:
		_lat_seen = play.stepped_key_at
		if lat_ms.size() < 2000:
			lat_ms.append((now - play.stepped_key_at) / 1000.0)
	if debug:
		JavaScriptBridge.eval("window.srState=" + JSON.stringify(JSON.stringify(state())), true)
		if frame_ms.size() % 60 == 0:
			JavaScriptBridge.eval("window.srStats=" + JSON.stringify(JSON.stringify(stats())), true)


# 動きの滑らかさ(磨きの測定): 画面の回る速さ(度/秒)と、1 フレームに道が流れた量 ÷(速さ × フレームの時間)。
# 流れは 1 に近いほど滑らか。描く位置(補間あり)と sim の生の位置(補間なし)の両方を取って比べる。
func _watch_motion(dt: float) -> void:
	if play == null or screen != "play" or play.paused or play.sim == null or play.sim.phase != 1 or play._snap.is_empty() or dt <= 0.0:
		_prev_motion = []
		return
	var c: Dictionary = play._snap["car"]
	var now := [float(c["x"]), float(c["y"]), play.sim.car.x, play.sim.car.y, play.view.cam_r]
	var sp := float(c["speed"])
	if _prev_motion.size() == 5 and rot_dps.size() < 20000:
		rot_dps.append(absf(wrapf(now[4] - _prev_motion[4], -PI, PI)) / dt * 180.0 / PI)
		if sp > 100.0:
			flow.append(Vector2(now[0] - _prev_motion[0], now[1] - _prev_motion[1]).length() / (sp * dt))
			flow_raw.append(Vector2(now[2] - _prev_motion[2], now[3] - _prev_motion[3]).length() / (sp * dt))
	_prev_motion = now


func state() -> Dictionary:
	var out := {"screen": screen, "paused": pause_view != null and pause_view.visible, "buttons": {}, "sfx": Sfx.played, "unlocked": Sfx.unlocked,
		"last_run": last_run, "settings": store.settings()}
	var root: Control = pause_view if pause_view != null and pause_view.visible else current
	if root != null:
		for b in root.find_children("*", "Button", true, false):
			var btn := b as Button
			if btn.is_visible_in_tree() and not btn.disabled:
				var c := btn.global_position - stage.global_position + btn.size / 2  # 舞台の座標(1280×720)
				out["buttons"][String(btn.name)] = [c.x, c.y]
	if play != null and play.sim != null:
		var sn: Dictionary = play.sim.snapshot()
		sn["hint"] = Bots.center_input(play.sim)  # 中心 bot ならこう押す(自動の確かめが本物のキーで押す)
		sn["ghost_done"] = play.sim.ghost_done
		sn["held"] = play.held.size()
		sn["gap"] = play._bar["gap"].text
		sn["shake"] = [play.position.x, play.position.y]
		sn["cam_r"] = play.view.cam_r
		out["play"] = sn
	if screen == "result" and current != null:
		out["share"] = current.share
	return out


func stats() -> Dictionary:
	return {"lat": _pct(lat_ms), "frame": _pct(frame_ms), "rot_dps": _pct(rot_dps), "flow": _pct(flow), "flow_raw": _pct(flow_raw)}


@warning_ignore("integer_division")
static func _pct(list: Array) -> Dictionary:
	if list.is_empty():
		return {"n": 0}
	var s := list.duplicate()
	s.sort()
	return {"n": s.size(), "p5": s[s.size() / 20], "p50": s[s.size() / 2], "p95": s[mini(int(ceil(s.size() * 0.95)) - 1, s.size() - 1)], "max": s[-1]}


static func _key(pk: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	return e
