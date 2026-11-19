# S2 プレイ(画面設計書 §3)。押されている物理キーの組を持ち、毎フレーム 10 キーの組とブレーキを sim に渡して、たまった時間ぶん進める(1 フレーム 8 tick まで)。
# events で演出(§9.10)と音を出し、snapshot から道・車・帯・地図・タイムを描く。ゲームの決まりは持たない(INV-1)。
# 押されている組は一時停止の間も押す・離すで直す(Esc の一時停止では押さえたままのキーを残す。E-11)。フォーカスが外れたら空にする(共通 §3 の 5)。
extends Control

signal finished(result: Dictionary, record: String)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Share := preload("res://core/share_text.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const View := preload("res://ui/view.gd")
const Minimap := preload("res://ui/minimap.gd")

var sim: Sim = null
var paused := false
var shake_on := true
var controls := "row"
var arrows := false  # 矢印のハンドル(デバッグ版だけ。FR-27)
var held := {}  # 押されている物理キー(ハンドルとブレーキに使う物だけ)
var bot: RefCounted = null  # 自動の確かめ(smoke)の時だけ。step ごとに act(sim) を呼ぶ
var view: View
var minimap: Minimap
var cost_us: Array = []  # 1 フレームの _process と描く時間(usec。NFR-1 の測定が読む)

var _acc := 0.0
var _over_at := -1
var _go_at := -100000
var _shake_until := 0
var _shake_seed := 1
var _lap_note := ""
var _lap_until := 0
var _snap := {}
var _bar := {}
var _center: Label
var _ime: Label
var _ime_until := 0
var _prev_best := -1  # このコースの自己ベスト(tick。無ければ −1)


func _ready() -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	view = View.new()
	add_child(view)
	minimap = Minimap.new()
	minimap.position = Vector2(1080, 16)
	add_child(minimap)
	var esc := Kit.place(Kit.button("Esc", S.ESC, 20), 24, 12, 72, 40)
	esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(esc)
	_bar["lap"] = Kit.label("", 26, Kit.C_TEXT, 700)
	_bar["lap"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(_bar["lap"], 124, 8, 200, 48))
	_bar["time"] = Kit.label("", 40, Kit.C_TEXT, 700)
	add_child(Kit.place(_bar["time"], 440, 4, 400, 56))
	_bar["best"] = Kit.label("", 22, Kit.C_DIM, 500)
	_bar["best"].horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(_bar["best"], 820, 12, 250, 40))
	_center = Kit.label("", 64, Kit.C_TEXT, 800)
	add_child(Kit.place(_center, 0, 220, 1280, 100))
	_ime = Kit.label(S.IME, 22, Kit.C_WARN, 700)
	_ime.visible = false
	add_child(Kit.place(_ime, 0, 330, 1280, 40))


# course は ui/courses.gd の Dictionary、ghost は保存の記録(無ければ "")。st は保存の settings。prev_best は自己ベストの tick(無ければ −1)。
func start(course: Dictionary, ghost: String, st: Dictionary, prev_best: int = -1) -> void:
	sim = Sim.new(course, ghost)
	_prev_best = prev_best
	paused = false
	shake_on = st["shake"]
	controls = st["controls"]
	view.rotate_on = st["rotate"]
	view.reduce_flash = st["reduce_flash"]
	view.wasd = controls == "wasd"
	view.setup(sim.track)
	minimap.setup(course["points"], Vector2(180, 180))
	_acc = 0.0
	_over_at = -1
	_go_at = -100000
	_lap_until = 0
	_refresh(0.0)
	view.snap_camera(_snap)


func is_playing() -> bool:
	return sim != null and not sim.is_over()


# 押す・離すで押されている組を直す。一時停止の間も呼ぶ(離したキーを押したまま残さない)。
func track_key(ev: InputEventKey) -> void:
	var pk := int(ev.physical_keycode)
	if Keymap.index_of(pk, controls, arrows) < 0 and not Keymap.is_brake(pk, controls):
		if ev.pressed and pk == 0:
			_ime_until = Time.get_ticks_msec() + B.IME_NOTE_MS  # 共通 §3 の 9
		return
	if not ev.pressed:
		held.erase(pk)
	elif not ev.echo and not Keymap.has_modifier(ev):
		held[pk] = true  # FR-24: 押しっぱなしの繰り返しと Ctrl・Alt・Meta と一緒の押すは数えない


# S2 のキー。Esc は一時停止。ほかは track_key が押されている組を持つだけ(Enter・↑↓ は何もしない。画面設計書 §8)。
func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()


# フォーカスが外れた時(共通 §3 の 5・E-11)。押されている組を空にする。
func release_all() -> void:
	held.clear()
	_refresh(0.0)


@warning_ignore("integer_division")
func _process(delta: float) -> void:
	if sim == null:
		return
	var t0 := Time.get_ticks_usec()
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		_shake_seed = (_shake_seed * 1103515245 + 12345) & 0x7FFFFFFF
		position = Vector2(float(_shake_seed % 11) - 5.0, float((_shake_seed / 11) % 11) - 5.0) * (B.SHAKE_PX / 5.0)
	_ime.visible = now < _ime_until
	if _over_at >= 0:
		if now - _over_at >= B.OVER_MS:
			_over_at = -2
			Sfx.stop_loops()
			finished.emit(sim.result(), sim.record())
		return
	if paused or _over_at == -2:
		Sfx.stop_loops()
		return
	_acc += delta * B.TICK_HZ
	var n := int(_acc)
	_acc -= n
	if n > B.MAX_STEPS_PER_FRAME:
		n = B.MAX_STEPS_PER_FRAME  # E-20: 超えた分は捨てる
		_acc = 0.0
	for k in n:
		if bot != null:
			bot.act(sim)
		else:
			var inp := Keymap.input_of(held, controls, arrows)
			sim.set_input(inp[0], inp[1])
		sim.step()
		for e: Dictionary in sim.events():
			_on_event(e)
		if sim.is_over():
			break
	_refresh(delta)
	_sound()
	cost_us.append(Time.get_ticks_usec() - t0)


# 鳴り続ける音(§9.10 の毎フレームの行)。エンジンの高さを速さで 0.8〜1.6 に、滑っている間は滑る音。
# 滑る音は drift_start / drift_end の出来事ではなく毎フレームの状態で決める(一時停止から戻った時も鳴り直す)。
func _sound() -> void:
	var c: Dictionary = _snap["car"]
	var k := clampf(float(c["speed"]) / B.V_MAX, 0.0, 1.0)
	if sim.is_over():
		Sfx.stop_loops()
		return
	Sfx.loop("engine", true, lerpf(B.ENGINE_PITCH_MIN, B.ENGINE_PITCH_MAX, k))
	Sfx.loop("drift", c["drift"])


# 演出の表(§9.10)。events を受けたフレームに始める(FR-15)。
func _on_event(e: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	match e["type"]:
		"go":
			_go_at = now
			Sfx.play("go")
		"wall_hit":
			var s: float = e["s"]
			view.flash[int(e["side"])] = now
			Sfx.play("wall", s / B.WALL_SOUND_FULL)
			if s >= B.SHAKE_SPEED:
				_shake_until = now + B.SHAKE_MS
		"lap":
			_lap_note = S.LAP_NOTE % [int(e["lap"]), Share.time_text(int(e["ticks"]))] + ("  " + S.FASTEST if e["best"] else "")
			_lap_until = now + B.LAP_NOTE_MS
			if int(e["lap"]) < B.LAPS:
				Sfx.play("lap")
		"over":
			_over_at = now
			Sfx.stop_loops()
			if e["reason"] == "timeout":
				Sfx.play("timeout")
			else:
				Sfx.play("best" if _prev_best < 0 or sim.race_tick < _prev_best else "goal")


@warning_ignore("integer_division")
func _refresh(delta: float) -> void:
	_snap = sim.snapshot()
	var now := Time.get_ticks_msec()
	var lap: int = _snap["lap"]
	_bar["lap"].text = S.BAR_LAP % lap
	_bar["lap"].add_theme_color_override("font_color", Kit.C_TEXT if lap == B.LAPS else Kit.C_DIM)
	_bar["time"].text = Share.time_text(int(_snap["race_tick"]))
	_bar["best"].text = S.BAR_BEST_LAP % Share.time_text(int(_snap["best_lap"])) if int(_snap["best_lap"]) >= 0 else ""
	var text := ""
	if int(_snap["phase"]) == Sim.COUNT:
		text = str(3 - int(_snap["count_tick"]) / B.COUNT_STEP_TICKS)
	elif _over_at >= 0:
		text = S.GOAL + "  " + Share.time_text(int(_snap["race_tick"])) if sim.reason == "goal" else S.TIMEOUT
	elif now - _go_at < B.GO_MS:
		text = S.GO
	elif now < _lap_until:
		text = _lap_note
	_center.text = text
	_center.add_theme_font_size_override("font_size", 40 if text == _lap_note else 64)
	var lit := {}
	var keys: int = _snap["keys"]
	if controls == "wasd":
		if keys & 1:
			lit[0] = true
		if _snap["brake"]:
			lit[1] = true
		if keys & (1 << 9):
			lit[2] = true
	else:
		for i in 10:
			if keys & (1 << i):
				lit[i] = true
	view.lit = lit
	view.advance(_snap, delta)
	minimap.snap = _snap
	minimap.queue_redraw()
