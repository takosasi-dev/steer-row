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
var key_at := 0  # 最後にハンドルかブレーキのキーが押された時(usec。NFR-2 の測定が読む)
var stepped_key_at := 0  # その押下を sim に渡した時の key_at(この後に描き終わるまでを main が測る)

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
var _sub: Label  # 中央の字の下の 1 行(新しい記録)
var _prev_car := []  # 最後の step の前の車の [x, y, hx, hy](描く時に tick の間を補間する)
var _prev_ghost := []
var _my_at := PackedInt32Array()  # 進み(周 × 点の数 + 区間)に初めて届いた走りの tick(幽霊との差)
var _gh_at := PackedInt32Array()


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
	_bar["gap"] = Kit.label("", 22, Kit.C_DIM, 700)
	add_child(Kit.place(_bar["gap"], 440, 56, 400, 30))
	_center = Kit.label("", 64, Kit.C_TEXT, 800)
	var band := Kit.box(Color(0, 0, 0, B.CENTER_BAND_ALPHA), Color(Kit.C_WALL, 0.35), 1)
	band.content_margin_left = 36
	band.content_margin_right = 36
	band.set_corner_radius_all(10)
	_center.add_theme_stylebox_override("normal", band)  # 道や壁の線の上でも字が読めるように
	add_child(Kit.place(_center, 0, 220, 1280, 100))
	_sub = Kit.label("", 26, Kit.C_GOOD, 700)
	add_child(Kit.place(_sub, 0, 326, 1280, 40))
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
	_sub.text = ""
	_prev_car = _pose(sim.car)
	_prev_ghost = _pose(sim.ghost_car)
	_my_at = PackedInt32Array([0])
	_gh_at = PackedInt32Array([0])
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
		key_at = Time.get_ticks_usec()


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
	if n > 0 and key_at > stepped_key_at:
		stepped_key_at = key_at  # 帯は sim の押している組から描くので、この後に描いた絵で光る
	for k in n:
		if bot != null:
			bot.act(sim)
		else:
			var inp := Keymap.input_of(held, controls, arrows)
			sim.set_input(inp[0], inp[1])
		_prev_car = _pose(sim.car)
		_prev_ghost = _pose(sim.ghost_car)
		sim.step()
		_mark(_my_at, sim.car)
		_mark(_gh_at, sim.ghost_car)
		for e: Dictionary in sim.events():
			_on_event(e)
		if sim.is_over():
			break
	_refresh(delta)
	_sound()
	cost_us.append(Time.get_ticks_usec() - t0)


# 車の [x, y, hx, hy](無ければ [])。
static func _pose(c: RefCounted) -> Array:
	return [] if c == null else [c.x, c.y, c.hx, c.hy]


# 描く車の位置と向きを、前の tick の pose から今へ a(0〜1)だけ進めた所にする。向きは長さ 1 に直す。
static func lerp_pose(c: Dictionary, prev: Array, a: float) -> void:
	if prev.size() != 4:
		return
	c["x"] = lerpf(prev[0], float(c["x"]), a)
	c["y"] = lerpf(prev[1], float(c["y"]), a)
	var h := Vector2(lerpf(prev[2], float(c["hx"]), a), lerpf(prev[3], float(c["hy"]), a)).normalized()
	c["hx"] = h.x
	c["hy"] = h.y


# 進み(周 × 点の数 + 区間)に初めて届いた走りの tick を足す。後ろへ戻った時と、輪の継ぎ目で飛んだ時は足さない。
func _mark(at: PackedInt32Array, c: RefCounted) -> void:
	if c == null:
		return
	var p: int = c.laps * sim.track.n + c.seg
	if p >= at.size() and p - at.size() < B.SEARCH:
		while at.size() <= p:
			at.append(sim.race_tick)


# 幽霊との差(tick。+ は幽霊より遅い)。2 台とも届いた一番先の進みで、届いた tick を比べる。幽霊が無い・数えの間は null。
func ghost_gap() -> Variant:
	if sim == null or not sim.has_ghost() or sim.race_tick == 0:
		return null
	var q := mini(_my_at.size(), _gh_at.size()) - 1
	return _my_at[q] - _gh_at[q]


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
			view.spark(int(e["side"]), s)
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
				var best := _prev_best < 0 or sim.race_tick < _prev_best
				Sfx.play("best" if best else "goal")
				_sub.text = S.GOAL_NEW_BEST if best and _prev_best >= 0 else ""  # 初めての走りは比べる物が無いので出さない


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
	if _center.text != text:
		_center.text = text
		_center.add_theme_font_size_override("font_size", 44 if text == _lap_note else 64)
		_center.visible = text != ""
		_center.reset_size()  # 幕を字の幅に合わせて真ん中に置く
		_center.position.x = (B.SCREEN_W - _center.size.x) / 2.0
	_sub.visible = _over_at >= 0
	var gap: Variant = ghost_gap()
	_bar["gap"].text = "" if gap == null else S.GHOST_GAP % ["+" if gap > 0 else ("−" if gap < 0 else ""), Share.diff_text(Share.hundredths(absi(gap)))]
	_bar["gap"].add_theme_color_override("font_color", Kit.C_GOOD if gap != null and gap < 0 else Kit.C_WARN)
	view.lit = Kit.lit_of(_snap["keys"], _snap["brake"], controls == "wasd")
	lerp_pose(_snap["car"], _prev_car, _acc)  # 描く位置だけを tick の間で補間する(sim と記録は生の値のまま)
	if _snap["ghost"] != null:
		lerp_pose(_snap["ghost"], _prev_ghost, _acc)
	view.advance(_snap, delta)
	minimap.snap = _snap
	minimap.queue_redraw()
