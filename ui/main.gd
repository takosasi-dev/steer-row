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

var stage: Control
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


func _ready() -> void:
	stage = Control.new()
	stage.size = Vector2(1280, 720)
	add_child(stage)
	var bg := ColorRect.new()
	bg.color = Kit.C_BG
	stage.add_child(Kit.place(bg, -2000, -2000, 5280, 4720))
	store = Store.new()
	_apply_settings()
	auto = OS.is_debug_build() and OS.get_cmdline_user_args().has("--auto")  # 公開版では効かせない(bot の記録を保存しない)
	if auto:
		Engine.time_scale = 4.0  # 1 フレーム 8 tick(上限)で進める
	_watch_visibility()
	_show_gate()


func _apply_settings() -> void:
	Sfx.set_volume(int(store.settings()["volume"]))


func _clear() -> void:
	if pause_view != null:
		pause_view.queue_free()
		pause_view = null
	for c in stage.get_children():
		if c is ColorRect and c.get_index() == 0:
			continue
		c.queue_free()
	current = null
	play = null
	Sfx.stop_loops()


# --- S0 始める ---

func _show_gate() -> void:
	_clear()
	screen = "gate"
	var g := Control.new()
	g.size = Vector2(1280, 720)
	g.add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 220, 1280, 100))
	g.add_child(Kit.place(Kit.label(S.S0_START, 28, Kit.C_TEXT, 500), 0, 360, 1280, 44))
	g.add_child(Kit.place(Kit.label(S.S0_KEYBOARD, 18, Kit.C_DIM), 0, 410, 1280, 30))
	_touch_note = Kit.label(S.TOUCH, 22, Kit.C_WARN, 700)
	_touch_note.visible = false
	g.add_child(Kit.place(_touch_note, 0, 470, 1280, 40))
	stage.add_child(g)
	current = g


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


# --- S2 プレイ ---

func _start(r: Dictionary) -> void:
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


func _pause() -> void:
	if play == null or pause_view != null or not play.is_playing():
		return
	play.paused = true
	pause_view = Pause.new()
	pause_view.build()
	pause_view.picked.connect(_on_pause)
	stage.add_child(pause_view)


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
	if screen == "settings" and current != null:
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
	v.build(result, rec, text)
	v.retry.connect(func() -> void: _start(run))  # FR-17: 同じコース
	v.to_title.connect(_show_title)
	stage.add_child(v)
	current = v
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
		s.add_child(Kit.place(dim, 0, 0, 1280, 720))
		s.move_child(dim, 0)
		stage.add_child(s)
		current = s
		screen = "settings"
		pause_view.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		_clear()
		screen = "settings"
		stage.add_child(s)
		current = s


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


static func _key(pk: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	return e
