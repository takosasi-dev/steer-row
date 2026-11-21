# 画面の流れのテスト(AC-18〜AC-20・AC-24・FR-24〜FR-28・E-7・E-10・E-11)。main.tscn を木に置き、キーのイベントを直接渡し、
# フレームは _process を呼んで進める。作りは KeyFlak の tests/test_ui.gd。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Keymap := preload("res://ui/keymap.gd")
const Kit := preload("res://ui/kit.gd")
const Share := preload("res://core/share_text.gd")


static func kev(pk: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = pressed
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


func _main(save_text: String = "") -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	if save_text != "":
		var f := FileAccess.open(Store.PATH, FileAccess.WRITE)
		f.store_string(save_text)
		f.close()
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func press(m: Node, pk: int) -> void:
	m._input(kev(pk))


static func release(m: Node, pk: int) -> void:
	m._input(kev(pk, false))


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current.has_method("_process") and m.current != m.play:
			m.current._process(dt)


# S0 → S1 → 一番上の入口(初めては入門)
func _to_play(m: Node) -> void:
	press(m, KEY_X)
	press(m, KEY_ENTER)


# 数えを飛ばして走りに入る。
static func _go(m: Node) -> void:
	while m.play.sim.phase == Sim.COUNT:
		m.play.sim.step()


static func _finish(m: Node) -> void:
	var bot := Bots.new(Bots.CENTER)
	while not m.play.sim.is_over():
		bot.act(m.play.sim)
		m.play.sim.step()
	m.play.finished.emit(m.play.sim.result(), m.play.sim.record())  # 終わりの 600 ms を待たない


static func _labels(m: Node) -> Array:
	return m.current.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func test_ac18_flow_keyboard_only() -> bool:
	var m := _main()
	eq(m.screen, "gate", "S0 から始まる")
	press(m, KEY_X)
	eq(m.screen, "title", "どれかのキーで S1")
	ok(m.play == null, "S0 のキーはゲームの操作に数えない")
	eq(String(m.current.menu.buttons[0].name), "intro", "入門を走り切るまでは入門が一番上(FR-25)")
	press(m, KEY_ENTER)
	eq(m.screen, "play", "Enter で入門コース")
	eq(int(m.run["course"]), 0, "入門")
	_finish(m)
	eq(m.screen, "result", "ゴールで S3")
	ok(m.current.share.begins_with("SteerRow ") and m.current.share.contains("(入門コース)"), "共有する文字")
	press(m, KEY_ENTER)
	eq(m.screen, "result", "300 ms の前は押せない")
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_ENTER)
	eq(m.screen, "play", "もう1回(Enter)")
	eq(int(m.run["course"]), 0, "同じコース(FR-17)")
	ok(m.play.sim.has_ghost(), "幽霊は保存の一番速い走り")
	press(m, KEY_ESCAPE)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "title", "一時停止からタイトルへ")
	eq(String(m.current.menu.buttons[0].name), "daily", "入門を走り切った後は今日のコースが一番上")
	eq(String(m.current.menu.buttons[2].name), "intro", "入門は 3 番目")
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "pick", "S6 コースを選ぶ")
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "play", "S6 → S2")
	eq(int(m.run["course"]), 2, "↓↓ でコース 2")
	eq(m.run["entry"], "pick", "コースを選ぶの入口")
	_done(m)
	return true


func test_pick_escape_and_today_mark() -> bool:
	var m := _main()
	press(m, KEY_X)
	press(m, KEY_DOWN)
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.screen, "pick", "コースを選ぶ")
	var rows: Array = m.current.menu.buttons
	eq(rows.size(), 17, "16 行と戻る")
	ok(_labels(m).any(func(t: String) -> bool: return t.contains(S.TODAY)), "今日の印")
	press(m, KEY_ESCAPE)
	eq(m.screen, "title", "Esc で戻る")
	_done(m)
	return true


func test_ac19_pause_freezes_car_and_ghost() -> bool:
	var m := _main('{"version":1,"physics":1,"intro_done":false,"courses":{"0":{"best_ticks":9999,"best_lap_ticks":3000,"ghost":"0-50,1-9999"}}}')
	_to_play(m)
	ok(m.play.sim.has_ghost(), "幽霊がいる")
	_go(m)
	frames(m, 20)
	press(m, KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	var t: int = m.play.sim.race_tick
	var car := [m.play.sim.car.x, m.play.sim.car.y]
	var ghost := [m.play.sim.ghost_car.x, m.play.sim.ghost_car.y]
	frames(m, 120)
	eq(m.play.sim.race_tick, t, "タイムが進まない")
	eq([m.play.sim.car.x, m.play.sim.car.y], car, "車が動かない")
	eq([m.play.sim.ghost_car.x, m.play.sim.ghost_car.y], ghost, "幽霊も動かない")
	press(m, KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	frames(m, 2)
	ok(m.play.sim.race_tick > t, "続けると進む")
	_done(m)
	return true


func test_e11_held_keys_across_pause() -> bool:
	var m := _main()
	_to_play(m)
	_go(m)
	press(m, KEY_J)
	press(m, KEY_ESCAPE)
	ok(m.play.held.has(KEY_J), "Esc の一時停止では押さえたキーを残す")
	release(m, KEY_J)
	ok(not m.play.held.has(KEY_J), "一時停止の間に離したキーは消える")
	press(m, KEY_ESCAPE)
	frames(m, 2)
	eq(m.play.sim.keys, 0, "離したまま再開")
	press(m, KEY_K)
	frames(m, 2)
	eq(m.play.sim.keys, 1 << 7, "K を押すと組に入る")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "フォーカスが外れると一時停止(E-10)")
	eq(m.play.held.size(), 0, "押されている組を空にする")
	frames(m, 30)
	ok(m.pause_view != null, "戻っても自動では再開しない")
	m._input(kev(KEY_K, true, true))
	press(m, KEY_ESCAPE)
	frames(m, 2)
	eq(m.play.sim.keys, 0, "押さえたままの繰り返しでは押したことにしない(押し直すまで)")
	_done(m)
	return true


func test_fr24_echo_and_modifiers() -> bool:
	var m := _main()
	_to_play(m)
	var e := kev(KEY_G)
	e.ctrl_pressed = true
	m._input(e)
	m._input(kev(KEY_H, true, true))
	frames(m, 2)
	eq(m.play.held.size(), 0, "Ctrl と一緒の押す・押しっぱなしの繰り返しは数えない")
	press(m, KEY_ENTER)
	press(m, KEY_UP)
	press(m, KEY_Q)
	frames(m, 2)
	eq(m.screen, "play", "Enter・↑ は何もしない")
	eq(m.play.sim.keys, 0, "ほかのキーは何もしない(E-1)")
	press(m, KEY_SPACE)
	frames(m, 2)
	ok(m.play.sim.brake, "Space はブレーキ")
	_done(m)
	return true


func test_e9_countdown_preturn_through_ui() -> bool:
	var m := _main()
	_to_play(m)
	press(m, KEY_SEMICOLON)
	frames(m, 100)  # 約 200 tick: 数えを越える
	eq(m.play.sim.car.w, 1.0, "数えの間に押した ; でハンドルを切っておける(FR-10)")
	_done(m)
	return true


func test_ac20_shake_and_rotate_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	m.store.set_setting("rotate", false)
	_to_play(m)
	_go(m)
	m.play._on_event({"type": "wall_hit", "s": 400.0, "side": 1})
	frames(m, 3)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると強く当たっても画面が動かない")
	press(m, KEY_SEMICOLON)
	frames(m, 60)
	eq(m.play.view.cam_r, 0.0, "画面の回転を切ると回らない")
	m.play.shake_on = true
	m.play._on_event({"type": "wall_hit", "s": 400.0, "side": 1})
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "揺れが入なら揺れる")
	m.play._on_event({"type": "wall_hit", "s": 100.0, "side": 1})
	m.play._shake_until = 0
	m.play._on_event({"type": "wall_hit", "s": 100.0, "side": 1})
	frames(m, 1, 0.0)
	eq(m.play.position, Vector2.ZERO, "外向きの速さが 200 未満なら揺らさない")
	_done(m)
	return true


func test_rotate_on_follows_heading() -> bool:
	var m := _main()
	_to_play(m)
	near(m.play.view.cam_r, 0.0, "上向きで始まるので回さない", 1e-6)
	_go(m)
	press(m, KEY_SEMICOLON)
	frames(m, 90)
	ok(m.play.view.cam_r < -0.05, "右へ曲がると画面が回って追う: %s" % m.play.view.cam_r)
	_done(m)
	return true


func test_ac24_wasd() -> bool:
	eq(Keymap.input_of({KEY_A: true}, "wasd"), [1, false], "A で番号 0")
	eq(Wheel.target(1), -1.0, "目標 −1")
	eq(Keymap.input_of({KEY_D: true}, "wasd"), [1 << 9, false], "D で番号 9(目標 +1)")
	eq(Wheel.target(Keymap.input_of({KEY_A: true, KEY_D: true}, "wasd")[0]), 0.0, "A と D で 0")
	eq(Keymap.input_of({KEY_S: true}, "wasd"), [0, true], "S でブレーキ")
	eq(Keymap.input_of({KEY_SPACE: true}, "wasd"), [0, true], "Space でもブレーキ")
	eq(Keymap.input_of({KEY_F: true, KEY_J: true, KEY_SEMICOLON: true, KEY_W: true}, "wasd"), [0, false], "W・F〜; は何もしない")
	eq(Keymap.input_of({KEY_S: true}, "row"), [2, false], "10 キーでは S は番号 1")
	# W A S D の走り(番号 0・9 とブレーキだけ)の記録を幽霊にすると、同じ tick にゴールする
	var a := Sim.new(course(0))
	var bot := Bots.new(Bots.CENTER)
	while not a.is_over() and a.tick < 50000:
		bot.act(a)
		var tw := Wheel.target(a.keys)
		a.set_input(1 if tw < -0.3 else (1 << 9 if tw > 0.3 else 0), a.brake)
		a.step()
	ok(a.result()["finished"], "W A S D の走りが走り切る")
	var g := Sim.new(course(0), a.record())
	while not g.ghost_done:
		g.step()
	eq(g.ghost_goal_tick, a.race_tick, "W A S D の記録の幽霊が同じ tick にゴール")
	return true


func test_ac24_wasd_through_ui() -> bool:
	var m := _main()
	m.store.set_setting("controls", "wasd")
	_to_play(m)
	_go(m)
	press(m, KEY_A)
	press(m, KEY_F)
	frames(m, 2)
	eq(m.play.sim.keys, 1, "A で左いっぱい、F は何もしない")
	press(m, KEY_S)
	frames(m, 2)
	ok(m.play.sim.brake, "S でブレーキ")
	eq(m.play.view.lit, {0: true, 1: true}, "帯は A と S(ブレーキ)が光る")
	_done(m)
	return true


func test_settings_items() -> bool:
	var m := _main()
	press(m, KEY_X)
	m._on_title("settings")
	eq(m.screen, "settings", "設定")
	var names: Array = m.current.menu.buttons.map(func(b: Button) -> String: return String(b.name))
	eq(names, ["volume", "shake", "reduce_flash", "rotate", "controls", "arrows", "keys", "back"], "項目(デバッグ版は矢印のハンドルも)")
	press(m, KEY_RIGHT)
	eq(m.store.settings()["volume"], 100, "音量は 5 段(75 → 100)")
	for k in 3:
		press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	eq(m.store.settings()["rotate"], false, "画面の回転を切る")
	press(m, KEY_DOWN)
	press(m, KEY_RIGHT)
	eq(m.store.settings()["controls"], "wasd", "操作を W A S D に")
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	ok(m.current.arrows, "矢印のハンドルを入れる")
	press(m, KEY_DOWN)
	press(m, KEY_ENTER)
	ok(m.current.keys_view, "キーの確かめ")
	press(m, KEY_A)
	press(m, KEY_SPACE)
	eq(m.current.held.size(), 2, "押されているキーを数える")
	ok(m.current.last_key.contains("echo"), "キーの中身を文字で出す")
	press(m, KEY_ESCAPE)
	press(m, KEY_ESCAPE)
	eq(m.screen, "title", "戻る")
	ok(m.arrows, "矢印のハンドルが main に届く")
	_done(m)
	return true


func test_fr27_arrows_no_record() -> bool:
	var m := _main()
	m.arrows = true
	_to_play(m)
	_go(m)
	press(m, KEY_RIGHT)
	frames(m, 2)
	eq(m.play.sim.keys, 1 << 9, "→ で目標 +1")
	press(m, KEY_LEFT)
	frames(m, 2)
	eq(Wheel.target(m.play.sim.keys), 0.0, "両方で 0")
	_finish(m)
	eq(m.store.course(0), null, "矢印のハンドルの走りは記録も幽霊も作らない")
	_done(m)
	return true


func test_e7_broken_ghost_dropped() -> bool:
	var m := _main('{"version":1,"physics":1,"intro_done":false,"courses":{"0":{"best_ticks":9999,"best_lap_ticks":3000,"ghost":"zz-?"}}}')
	_to_play(m)
	ok(not m.play.sim.has_ghost(), "壊れた幽霊は出さない")
	eq(m.store.ghost(0), "", "保存の幽霊を消す")
	_done(m)
	return true


func test_title_notes_and_records() -> bool:
	var m := _main('{"version":1,"physics":0,"intro_done":true,"courses":{"0":{"best_ticks":4600,"best_lap_ticks":1500,"ghost":"0-a"}}}')
	press(m, KEY_X)
	ok(_labels(m).has(S.GHOSTS_CLEARED), "古い幽霊を消した知らせ")
	ok(_labels(m).has(S.REC_NONE), "今日はまだ走っていない")
	_done(m)
	m = _main("{broken")
	press(m, KEY_X)
	ok(_labels(m).has(S.LOAD_FAILED), "保存を読めなかった知らせ(E-12)")
	_done(m)
	return true


func test_result_best_diff_and_today_record() -> bool:
	var m := _main()
	_to_play(m)
	_finish(m)
	var first: int = m.store.course(0)["best_ticks"]
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_R)
	_go(m)
	for k in 30:
		m.play.sim.set_input(1, false)  # 左へ切ってわざと遅くする
		m.play.sim.step()
	_finish(m)
	var labels := _labels(m)
	ok(labels.any(func(t: String) -> bool: return t.begins_with("自己ベストまで +")), "自己ベストまで +… が出る: %s" % [labels])
	ok(not labels.has(S.GHOST_NEW), "遅い走りでは幽霊を替えない")
	eq(m.store.course(0)["best_ticks"], first, "自己ベストはそのまま")
	_done(m)
	return true


func test_gate_ignores_touch_mouse() -> bool:
	var m := _main()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	m._input(t)
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.device = InputEvent.DEVICE_ID_EMULATION
	m._input(mb)
	eq(m.screen, "gate", "タッチと、そこから作られたマウスでは進まない(FR-26)")
	ok(m._touch_note.visible, "キーボードで遊ぶ案内が出る")
	_done(m)
	return true


func test_ime_note_on_zero_keycode() -> bool:
	var m := _main()
	_to_play(m)
	m._input(kev(0))
	frames(m, 1)
	ok(m.play._ime.visible, "physical_keycode が 0 の押すで日本語入力の案内(共通 §3 の 9)")
	_done(m)
	return true


func test_e6_timeout_result_screen() -> bool:
	var m := _main()
	_to_play(m)
	_go(m)
	m.play.sim.race_tick = B.RACE_LIMIT_TICKS - 1
	frames(m, 1)
	ok(m.play.sim.is_over(), "5 分で終わる")
	eq(m.play._center.text, S.TIMEOUT, "「時間切れ」を出す")
	m.play._over_at -= 1000
	frames(m, 1)
	eq(m.screen, "result", "600 ms 後に S3")
	ok(_labels(m).has(S.TIMEOUT), "見出しは時間切れ")
	eq(m.current.share, "", "共有する文字の枠を出さない")
	ok(m.current.find_children("share", "TextEdit", true, false).is_empty(), "枠が無い")
	eq(m.store.course(0), null, "記録しない")
	_done(m)
	return true


func test_engine_and_drift_sound() -> bool:
	var m := _main()
	_to_play(m)  # S0 のキーで音が鳴らせるようになる(FR-23)
	ok(Sfx.unlocked, "最初のキーの後")
	_go(m)
	for k in 300:
		m.play.sim.step()
	frames(m, 1)
	var engine: AudioStreamPlayer = Sfx._loops["engine"]
	near(engine.pitch_scale, B.ENGINE_PITCH_MAX, "最高の速さでエンジンの高さ 1.6", 1e-6)
	m.play.sim.car.drift = true
	frames(m, 1, 0.0)
	ok(Sfx._loops["drift"].stream != null, "滑っている間は滑る音")
	press(m, KEY_ESCAPE)
	frames(m, 1)
	ok(not engine.playing and not Sfx._loops["drift"].playing, "一時停止で止める")
	_done(m)
	return true


# --- 磨きで足した演出(v0.2.0) ---

func test_polish_ghost_gap() -> bool:
	var a := run_bot(0)
	var m := _main()
	m.store.data["courses"]["0"] = {"best_ticks": a.race_tick, "best_lap_ticks": a.best_lap(), "ghost": a.record()}
	_to_play(m)
	ok(m.play.sim.has_ghost(), "幽霊がある")
	eq(m.play.ghost_gap(), null, "数えの間は差を出さない")
	m.play.bot = Bots.new(Bots.CENTER)  # 幽霊と同じ押し方
	frames(m, 200)
	eq(m.play.ghost_gap(), 0, "同じ走りなら差 0")
	eq(m.play._bar["gap"].text, S.GHOST_GAP % ["", "0.00"], "幽霊 0.00")
	m.play.bot = null
	press(m, KEY_SPACE)
	frames(m, 60)
	ok(m.play.ghost_gap() > 0, "ブレーキで遅れると + になる: %s" % m.play.ghost_gap())
	ok(m.play._bar["gap"].text.begins_with(S.GHOST_GAP % ["+", ""]), "文字は「幽霊 +…」: %s" % m.play._bar["gap"].text)
	_done(m)
	return true


func test_polish_lerp_pose() -> bool:
	var Play := preload("res://ui/play.gd")
	var c := {"x": 10.0, "y": 4.0, "hx": 0.0, "hy": -1.0}
	Play.lerp_pose(c, [0.0, 0.0, 1.0, 0.0], 0.5)
	near(c["x"], 5.0, "x は前の tick と今の真ん中")
	near(c["y"], 2.0, "y も")
	near(Vector2(c["hx"], c["hy"]).length(), 1.0, "向きは長さ 1 に直す(Vector2 は 32 ビット)", 1e-6)
	var d := {"x": 10.0, "y": 4.0, "hx": 0.6, "hy": 0.8}
	Play.lerp_pose(d, [0.0, 0.0, 1.0, 0.0], 1.0)
	eq([d["x"], d["y"]], [10.0, 4.0], "a = 1 なら今の位置")
	var m := _main()
	_to_play(m)
	_go(m)
	frames(m, 30)
	frames(m, 1, 1.0 / 144.0)  # 144 Hz の画面: tick の途中で描く
	var drawn := Vector2(m.play._snap["car"]["x"], m.play._snap["car"]["y"])
	var now := Vector2(m.play.sim.car.x, m.play.sim.car.y)
	var prev := Vector2(m.play._prev_car[0], m.play._prev_car[1])
	near(drawn.distance_to(prev) + drawn.distance_to(now), prev.distance_to(now), "描く位置は前の tick と今の間", 1e-6)
	ok(m.play._acc > 0.0 and m.play._acc < 1.0 and drawn != now, "tick の途中なら今の位置より手前に描く")
	_done(m)
	return true


func test_polish_flash_and_sparks_follow_settings() -> bool:
	var m := _main()
	m.store.set_setting("reduce_flash", true)
	_to_play(m)
	_go(m)
	frames(m, 2)
	ok(m.play.view.flash_alpha() <= B.REDUCED_FLASH_ALPHA, "点滅を弱めると壁の光と火花は 20% 以下")
	m.play._on_event({"type": "wall_hit", "s": 400.0, "side": 1})
	eq(m.play.view.sparks.size(), B.SPARK_MAX, "強く当たると火花はいちばん多く")
	m.play._on_event({"type": "wall_hit", "s": 1.0, "side": -1})
	eq(m.play.view.sparks.size(), B.SPARK_MIN, "弱く当たっても少しは出す")
	m.play.view._spark_born -= B.SPARK_MS + 1
	frames(m, 1)
	eq(m.play.view.sparks.size(), 0, "時間が過ぎたら消える")
	m.play.view.reduce_flash = false
	eq(m.play.view.flash_alpha(), 1.0, "弱めないなら 100%")
	_done(m)
	return true


func test_polish_strip_and_center() -> bool:
	var f := Kit.font(700)
	ok(f.get_string_size(S.KEYS[1] + " " + S.WASD_BRAKE, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x < 132.0, "W A S D の帯に「S ブレーキ」が収まる")
	var lit := Kit.lit_of(1 | (1 << 9), true, true)
	eq(lit, {0: true, 1: true, 2: true}, "W A S D の帯: A・S(ブレーキ)・D")
	eq(Kit.lit_of((1 << 3) | (1 << 4), false, false), {3: true, 4: true}, "10 キーの帯: F と G")
	var m := _main()
	press(m, KEY_X)
	press(m, KEY_J)
	ok(m.current._held.has(KEY_J), "タイトルの帯も押したキーで光る")
	m.current._process(0.5)
	ok(m.current._car.w > 0.0, "タイトルの針も回る")
	m._focus_lost()
	ok(m.current._held.is_empty(), "フォーカスが外れたら離したことにする")
	release(m, KEY_J)
	press(m, KEY_ENTER)
	ok(m.play._center.visible and m.play._center.text == "3", "数えの字を幕つきで出す")
	_go(m)
	m.play._go_at = -100000
	frames(m, 1)
	ok(not m.play._center.visible, "字が無い時は幕も出さない")
	_finish(m)
	ok(_labels(m).has(S.SHARE_INTRO), "結果にコースの名前を出す")
	_done(m)
	return true


func test_polish_new_best_and_ahead_of_ghost() -> bool:
	var m := _main()
	_to_play(m)
	m.play._on_event({"type": "over", "reason": "goal"})
	frames(m, 1, 0.0)
	eq(m.play._sub.text, "", "初めての走り(自己ベストが無い)は「新しい記録」を出さない")
	m.play._prev_best = m.play.sim.race_tick + 100
	m.play._on_event({"type": "over", "reason": "goal"})
	m.play._refresh(0.0)  # 本物は over を受けたフレームの終わりに描き直す
	ok(m.play._sub.visible and m.play._sub.text == S.GOAL_NEW_BEST, "自己ベストを縮めたら「新しい記録」")
	m.play._prev_best = m.play.sim.race_tick  # 同じタイムは縮めていない
	m.play._on_event({"type": "over", "reason": "goal"})
	eq(m.play._sub.text, "", "縮めなければ出さない")
	_done(m)
	# 幽霊より前: 遅い走りの記録を幽霊にして、中心 bot で走る
	var slow := Sim.new(course(0))
	while not slow.is_over() and slow.tick < 60000:
		slow.set_input(0, slow.car.speed() > 200.0)  # 真っすぐ・200 を超えたらブレーキ(壁で遅くなる)
		slow.step()
		if slow.race_tick > 1200:
			break
	var m2 := _main()
	m2.store.data["courses"]["0"] = {"best_ticks": 99999, "best_lap_ticks": 99999, "ghost": slow.record()}
	_to_play(m2)
	m2.play.bot = Bots.new(Bots.CENTER)
	frames(m2, 400)
	ok(m2.play.ghost_gap() < 0, "幽霊より前なら − : %s" % m2.play.ghost_gap())
	ok(m2.play._bar["gap"].text.begins_with(S.GHOST_GAP % ["−", ""]), "文字は「幽霊 −…」: %s" % m2.play._bar["gap"].text)
	eq(m2.play._bar["gap"].get_theme_color("font_color"), Kit.C_GOOD, "前なら緑")
	_done(m2)
	return true


# --- UI の作り直し(v0.3.0) ---

func test_ui3_theme_on_project() -> bool:
	eq(ProjectSettings.get_setting("gui/theme/custom"), "res://ui/theme.tres", "Theme は project の設定で付ける(後から作る部品も同じ見た目)")
	var t := load("res://ui/theme.tres") as Theme
	ok(t != null, "theme.tres を読める")
	for type: String in ["Button", "SelButton"]:
		for st: String in ["normal", "hover", "pressed", "disabled", "focus"] if type == "Button" else ["normal", "hover", "pressed", "disabled"]:
			ok(t.has_stylebox(st, type), "%s の %s" % [type, st])
	eq(t.get_type_variation_base("SelButton"), &"Button", "選んでいる印は Button の型の変わり")
	for type: String in ["TextEdit", "LineEdit", "VScrollBar", "HSlider", "CheckBox", "PopupMenu"]:
		ok(not t.get_stylebox_list(type).is_empty(), "%s も作ってある" % type)
	var m := _main()
	press(m, KEY_X)
	var b: Button = m.current.menu.buttons[0]
	eq(b.theme_type_variation, &"SelButton", "選んでいるボタンは SelButton")
	eq(m.current.menu.buttons[1].theme_type_variation, &"", "ほかは Button")
	press(m, KEY_DOWN)
	eq(b.theme_type_variation, &"", "↓ で印が移る")
	ok(Kit.display(800).fallbacks.size() == 1, "表示用の字体は日本語を Noto Sans JP へ落とす")
	ok(load(Kit.DISPLAY).has_char("0".unicode_at(0)) and load(Kit.DISPLAY).has_char("−".unicode_at(0)), "表示用の字体に数字と −")
	_done(m)
	return true


func test_ui3_wipe_keeps_input_and_old_screen() -> bool:
	var m := _main()
	press(m, KEY_X)
	ok(m._leaving != null, "切り替わりの間は古い画面(S0)を帯の向こうに残す")
	ok(m._leaving.process_mode == Node.PROCESS_MODE_DISABLED, "古い画面は止める")
	ok(m.wipe_p < 1.0, "帯が流れ始める")
	press(m, KEY_ENTER)
	eq(m.screen, "play", "帯が流れている間のキーも新しい画面が受ける(飲まない)")
	var old_play: Node = m.play
	var leaving_buttons: Array = m._leaving.find_children("*", "Button", true, false)
	ok(leaving_buttons.all(func(x: Button) -> bool: return x.mouse_filter == Control.MOUSE_FILTER_IGNORE), "古い画面のボタンはマウスを受けない")
	_finish(m)
	m.current._shown_at -= 1000
	frames(m, 1)
	ok(old_play.get_parent() != null and not old_play.can_process(), "終わった走りの画面は止めたまま帯の向こうに残る")
	press(m, KEY_R)
	var p: Node = m.play
	eq(m.screen, "play", "R でもう1回")
	press(m, KEY_R)
	frames(m, 1)
	ok(m.play == p, "R の連打で 2 回始まらない")
	m._wipe_step(1.0)
	m._drop_leaving()
	ok(m._leaving == null, "流れ終わったら古い画面を消す")
	_done(m)
	return true


func test_ui3_reduce_motion() -> bool:
	var m := _main()
	m.store.set_setting("reduce_flash", true)
	m._apply_settings()
	ok(not m.backdrop.moving, "点滅を弱めると背景の線を止める")
	press(m, KEY_X)
	ok(m._leaving == null and m.wipe_p >= 1.0, "点滅を弱めると帯を流さない")
	ok(m.current.modulate.a < 1.0, "代わりに新しい画面を薄く出す")
	press(m, KEY_ENTER)
	_go(m)
	m.play._on_event({"type": "lap", "lap": 1, "ticks": 1500, "best": false})
	frames(m, 1)
	eq(m.play._center.scale, Vector2.ONE, "点滅を弱めると字をはねさせない")
	_finish(m)
	ok(m.current.calm and m.current.progress(10000) == 1.0, "結果の数え上げも省く")
	eq(m.current._time.text, Share.time_text(m.current.total), "タイムは最初から最後の値")
	_done(m)
	return true


func test_ui3_result_count_and_celebrate() -> bool:
	var m := _main()
	_to_play(m)
	_finish(m)
	ok(not m.current.celebrate, "初めての走りは祝わない(比べる物が無い)")
	ok(m.current._time.text == Share.time_text(0), "タイムは 0 から数え上げる")
	m.current._shown_at -= 1000
	frames(m, 1)
	eq(m.current._time.text, Share.time_text(m.current.total), "数え上げの後は合計のタイム")
	eq(m.current.menu.sel, 0, "もう1回を最初から選んでいる")
	press(m, KEY_R)
	_go(m)
	for k in 30:
		m.play.sim.set_input(1, false)  # 遅くする
		m.play.sim.step()
	_finish(m)
	ok(not m.current.celebrate, "遅ければ祝わない")
	var best: int = m.store.course(0)["best_ticks"]
	m.current._shown_at -= 1000
	frames(m, 1)
	press(m, KEY_R)
	m.play._prev_best = best
	var res: Dictionary = m.play.sim.result()
	res["total_ticks"] = best - 120
	res["finished"] = true
	m._on_finished(res, m.play.sim.record())
	ok(m.current.celebrate, "自己ベストを縮めたら祝う(市松の帯と新しい記録の札)")
	_done(m)
	return true
