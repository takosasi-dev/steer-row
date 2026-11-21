# プレイ画面の道・車・幽霊・関門・タイヤの跡・壁の光・火花と、画面の下の帯(10 キー・ハンドルの針・速さ)を描く(画面設計書 §3・§9、仕様書 FR-13〜FR-15)。
# 動かない物(地面の点・道・縁石・中央の破線・スタートの帯・壁)は 1 回だけ描いて、毎フレームは置き場所(回転と倍率)だけを替える。
# 画面の回転: 車が上を向くように、車の向きへ毎秒 CAM_RATE の割合で追う(ui の中なので atan2 を使う)。描くだけで、ゲームの決まりは持たない(INV-1)。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

const TOP_BAND := 64.0  # 上の帯の高さ(v0.3.0)

var rotate_on := true
var reduce_flash := false
var wasd := false
var lit := {}  # 帯で光らせる四角
var snap := {}  # 描く時の状態(play が車の位置を tick の間で補間して渡す)
var cam_r := 0.0  # 世界を回す角度(rad)
var skids: Array = []  # [[a, b], ...] 世界の座標の線
var sparks: Array = []  # [[x, y, vx, vy], ...] 世界の座標。壁に当たった時に出す
var flash := {-1: -100000, 1: -100000}  # 壁の側 → 光り始めた時刻(ms)
var draws := 0
var draw_us: Array = []  # 1 回描くのにかかった時間(usec。NFR-1 の測定が読む)

var _static := Node2D.new()  # 動かない物(1 回だけ描く)
var _dyn := Node2D.new()  # 毎フレーム描く物(関門・跡・光・火花・幽霊・車)
var _hud := Control.new()  # 画面の下の帯(回らない)
var _pts := PackedVector2Array()
var _left := PackedVector2Array()
var _right := PackedVector2Array()
var _gates: Array = []  # [[左の端, 右の端], ...] 関門 1〜7
var _width := 200.0
var _rear := []  # 前のフレームの後ろの 2 点
var _spark_born := -100000
var _seed := 7


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_static)
	add_child(_dyn)
	add_child(_hud)
	_static.draw.connect(_draw_static)
	_dyn.draw.connect(_draw_dyn)
	_hud.draw.connect(_draw_hud)


# track は core/track.gd。中心線から壁と関門を作っておく。
func setup(track: RefCounted) -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	_hud.size = size
	_width = track.width
	var n: int = track.n
	var half := _width / 2.0
	_pts.clear()
	_left.clear()
	_right.clear()
	for i in n:
		_pts.append(Vector2(track.xs[i], track.ys[i]))
	for i in n:
		var t := (_pts[(i + 1) % n] - _pts[(i - 1 + n) % n]).normalized()
		var r := Vector2(-t.y, t.x)
		_left.append(_pts[i] - r * half)
		_right.append(_pts[i] + r * half)
	_pts.append(_pts[0])
	_left.append(_left[0])
	_right.append(_right[0])
	_gates.clear()
	for g: int in track.gates:
		_gates.append([_left[g], _right[g]])
	skids.clear()
	sparks.clear()
	_rear = []
	_static.queue_redraw()


static func heading_angle(c: Dictionary) -> float:
	return atan2(float(c["hy"]), float(c["hx"]))


# 1 フレームぶん、回転を追い、滑っていればタイヤの跡を足し、火花を動かす。snap_now は描く時の状態。
func advance(snap_now: Dictionary, dt: float) -> void:
	snap = snap_now
	var c: Dictionary = snap["car"]
	if rotate_on:
		var want := -PI / 2.0 - heading_angle(c)
		cam_r += wrapf(want - cam_r, -PI, PI) * minf(1.0, B.CAM_RATE * dt)
	else:
		cam_r = 0.0
	var rear := _rear_points(c)
	if c["drift"] and _rear.size() == 2:
		skids.append([_rear[0], rear[0]])
		skids.append([_rear[1], rear[1]])
		while skids.size() > B.SKID_MAX:
			skids.pop_front()
	_rear = rear
	if Time.get_ticks_msec() - _spark_born > B.SPARK_MS:
		sparks.clear()
	for p: Array in sparks:
		p[0] += p[2] * dt
		p[1] += p[3] * dt
	_place()


# 回転を今の車の向きにそろえる(走りの始め)。
func snap_camera(snap_now: Dictionary) -> void:
	snap = snap_now
	cam_r = -PI / 2.0 - heading_angle(snap["car"]) if rotate_on else 0.0
	_place()


func _place() -> void:
	var t := world_transform()
	_static.transform = t
	_dyn.transform = t
	_dyn.queue_redraw()
	_hud.queue_redraw()


# 壁に当たった(wall_hit)。当たった側から火花を出す。数は外向きの速さで決める(形と線だけ)。
@warning_ignore("integer_division")
func spark(side: int, s: float) -> void:
	if snap.is_empty():
		return
	var c: Dictionary = snap["car"]
	var h := Vector2(c["hx"], c["hy"])
	var r := Vector2(-h.y, h.x) * float(side)
	var at := Vector2(c["x"], c["y"]) + r * B.CAR_R
	var count := clampi(int(s / B.WALL_SOUND_FULL * B.SPARK_MAX), B.SPARK_MIN, B.SPARK_MAX)
	sparks.clear()
	for k in count:
		_seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF
		var spread := float(_seed % 1000) / 1000.0 - 0.5
		var fast := 0.5 + float((_seed / 1000) % 1000) / 2000.0
		var dir := (r * 0.6 - h * 0.8 + Vector2(-r.y, r.x) * spread).normalized()
		sparks.append([at.x, at.y, dir.x * B.SPARK_SPEED * fast, dir.y * B.SPARK_SPEED * fast])
	_spark_born = Time.get_ticks_msec()


static func _rear_points(c: Dictionary) -> Array:
	var p := Vector2(c["x"], c["y"])
	var h := Vector2(c["hx"], c["hy"])
	var r := Vector2(-h.y, h.x)
	var back := p - h * (B.CAR_LEN * 0.4 / B.CAM_ZOOM)
	return [back - r * (B.CAR_WIDTH * 0.4 / B.CAM_ZOOM), back + r * (B.CAR_WIDTH * 0.4 / B.CAM_ZOOM)]


func world_transform() -> Transform2D:
	var c: Dictionary = snap["car"]
	var screen := Vector2(B.SCREEN_W / 2.0, B.CAR_SCREEN_Y if rotate_on else B.CAR_SCREEN_Y_FIXED)
	return Transform2D().translated(-Vector2(c["x"], c["y"])).rotated(cam_r).scaled(Vector2(B.CAM_ZOOM, B.CAM_ZOOM)).translated(screen)


# 動かない物。世界の座標で 1 回だけ描く(置き場所は _place が替える)。
@warning_ignore("integer_division")
func _draw_static() -> void:
	var n := _pts.size() - 1
	if n < 2:
		return
	var ci := _static
	var px := 1.0 / B.CAM_ZOOM  # 画面の 1 px
	# 地面の点(道の外が流れて見えるように)
	var lo := _pts[0]
	var hi := _pts[0]
	for p in _pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var step := B.GRID_STEP
	var x := floorf((lo.x - B.GRID_MARGIN) / step) * step
	while x <= hi.x + B.GRID_MARGIN:
		var y := floorf((lo.y - B.GRID_MARGIN) / step) * step
		while y <= hi.y + B.GRID_MARGIN:
			ci.draw_rect(Rect2(x - 1.5 * px, y - 1.5 * px, 3.0 * px, 3.0 * px), Kit.C_DOT)
			y += step
		x += step
	ci.draw_polyline(_pts, Kit.C_ROAD, _width)
	# 縁石: 曲がっている所の両端に、赤と白の四角を交互に置く
	for i in n:
		var a := _pts[posmod(i - 2, n)] - _pts[posmod(i - 3, n)]
		var b := _pts[(i + 3) % n] - _pts[(i + 2) % n]
		if absf(a.normalized().cross(b.normalized())) < B.CURB_TURN:
			continue
		var col := Kit.C_CURB if (i / 2) % 2 == 0 else Kit.C_CURB_2
		for side: PackedVector2Array in [_left, _right]:
			var in0 := (_pts[i] - side[i]).normalized() * B.CURB_DEPTH
			var in1 := (_pts[i + 1] - side[i + 1]).normalized() * B.CURB_DEPTH
			ci.draw_colored_polygon(PackedVector2Array([side[i], side[i + 1], side[i + 1] + in1, side[i] + in0]), col)
	# 中央の破線(速さが目に見えるように)
	for i in n:
		if (i / B.DASH_POINTS) % 2 == 0:
			ci.draw_line(_pts[i], _pts[i + 1], Kit.C_DASH, 2.0 * px)
	# スタートの帯(白黒の市松 2 段)
	var t0 := (_pts[1] - _pts[0]).normalized()
	var cells := int(round(_width / B.START_CELL))
	for row in 2:
		for k in cells:
			var p0 := _left[0].lerp(_right[0], float(k) / cells) + t0 * B.START_CELL * (row - 1)
			var p1 := _left[0].lerp(_right[0], float(k + 1) / cells) + t0 * B.START_CELL * (row - 1)
			ci.draw_colored_polygon(PackedVector2Array([p0, p1, p1 + t0 * B.START_CELL, p0 + t0 * B.START_CELL]),
				Kit.C_START if (k + row) % 2 == 0 else Kit.C_ROAD)
	ci.draw_polyline(_left, Kit.C_WALL, 3.0 * px)
	ci.draw_polyline(_right, Kit.C_WALL, 3.0 * px)


# 壁の光と火花の一番明るい不透明度。点滅を弱めると 20% 以下(共通 §3 の 17・NFR-12)。
func flash_alpha() -> float:
	return B.REDUCED_FLASH_ALPHA if reduce_flash else 1.0


# 毎フレーム描く物(世界の座標)。
func _draw_dyn() -> void:
	if snap.is_empty():
		return
	draws += 1
	var t0 := Time.get_ticks_usec()
	var ci := _dyn
	var now := Time.get_ticks_msec()
	var px := 1.0 / B.CAM_ZOOM
	var c: Dictionary = snap["car"]
	var passed: int = int(c["next_gate"]) - 1
	for k in _gates.size():
		if k >= passed:
			ci.draw_dashed_line(_gates[k][0], _gates[k][1], Kit.C_GATE, 2.0 * px, 12.0)
	for s: Array in skids:
		ci.draw_line(s[0], s[1], Kit.C_SKID, 2.0 * px)
	var dim := flash_alpha()
	for side: int in [-1, 1]:
		var ft := float(now - int(flash[side])) / B.WALL_FLASH_MS
		if ft < 1.0:
			ci.draw_polyline(_left if side < 0 else _right, Color(1, 1, 1, dim * (1.0 - ft)), 4.0 * px)
	var st := clampf(float(now - _spark_born) / B.SPARK_MS, 0.0, 1.0)
	for p: Array in sparks:
		var at := Vector2(p[0], p[1])
		ci.draw_line(at, at - Vector2(p[2], p[3]) * 0.03, Color(Kit.C_WARN, dim * (1.0 - st)), 2.0 * px)
	var g: Variant = snap["ghost"]
	if g != null:
		var gp := _car_shape(g)
		gp.append(gp[0])
		ci.draw_polyline(gp, Color(Kit.C_GHOST, B.GHOST_ALPHA), 2.5 * px)
	var me := _car_shape(c)
	var out := me.duplicate()
	out.append(me[0])
	ci.draw_colored_polygon(me, Kit.C_CAR)
	ci.draw_polyline(out, Kit.C_BG, 1.5 * px)
	if c["drift"]:
		var h := Vector2(c["hx"], c["hy"])
		ci.draw_circle(Vector2(c["x"], c["y"]) - h * (B.CAR_LEN * 0.7 / B.CAM_ZOOM), 3.0 * px, Kit.C_WARN)
	if draw_us.size() < 100000:
		draw_us.append(Time.get_ticks_usec() - t0)


# 画面の下: 帯の後ろの幕、10 キーの帯、速さ、ハンドルの針(回らない)。
func _draw_hud() -> void:
	if snap.is_empty():
		return
	var c: Dictionary = snap["car"]
	# 帯の幕は 88%。舞台の外(縦に長い窓の上下の余り)は塗りつぶして、帯が宙に浮いて見えないようにする(v0.3.0)
	_hud.draw_rect(Rect2(-2000, B.HUD_TOP, 5280, B.SCREEN_H - B.HUD_TOP), Color(Kit.C_BG, 0.88))
	_hud.draw_rect(Rect2(-2000, B.SCREEN_H, 5280, 2000), Kit.C_BG)
	_hud.draw_line(Vector2(-2000, B.HUD_TOP), Vector2(3280, B.HUD_TOP), Color(Kit.C_WALL, 0.25), 1.0)
	# 上の帯(v0.3.0): 周・タイム・最速の周・幽霊との差の後ろ。下の帯と同じ幕で、どんな道の上でも字が読める
	_hud.draw_rect(Rect2(-2000, 0, 5280, TOP_BAND), Color(Kit.C_BG, 0.88))
	_hud.draw_rect(Rect2(-2000, -2000, 5280, 2000), Kit.C_BG)
	_hud.draw_line(Vector2(-2000, TOP_BAND), Vector2(3280, TOP_BAND), Color(Kit.C_WALL, 0.25), 1.0)
	_hud.draw_rect(Rect2(440, TOP_BAND - 3, 400, 3), Kit.C_AMBER)  # タイムの下の琥珀の線
	# 舞台の上下の縁に細い市松の枠(縦に長い窓でだけ見える。道がぶつっと切れて見えないように、わざと作った枠にする)
	for y: float in [-14.0, B.SCREEN_H + 4.0]:
		Kit.draw_checker(_hud, Rect2(0, y, B.SCREEN_W, 10), 128, 2, Color(Kit.C_FLAG, 0.55), Kit.C_BG)
	_hud.draw_line(Vector2(-2000, -1.5), Vector2(3280, -1.5), Color(Kit.C_WALL, 0.5), 2.0)  # 16:9 の窓では見えない所
	_hud.draw_line(Vector2(-2000, B.SCREEN_H + 1.5), Vector2(3280, B.SCREEN_H + 1.5), Color(Kit.C_WALL, 0.5), 2.0)
	Kit.draw_strip(_hud, lit, wasd, float(c["wheel"]), float(snap["target"]))
	Kit.draw_speed(_hud, float(c["speed"]) / B.V_MAX, bool(snap["brake"]))


# 車の三角(長さ・幅は画面の px。世界の座標に直して描く)。
static func _car_shape(c: Dictionary) -> PackedVector2Array:
	var p := Vector2(c["x"], c["y"])
	var h := Vector2(c["hx"], c["hy"])
	var r := Vector2(-h.y, h.x)
	var hl := B.CAR_LEN / 2.0 / B.CAM_ZOOM
	var hw := B.CAR_WIDTH / 2.0 / B.CAM_ZOOM
	return PackedVector2Array([p + h * hl, p - h * hl + r * hw, p - h * hl - r * hw])
