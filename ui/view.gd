# プレイ画面の道・車・幽霊・関門・タイヤの跡・壁の光と、画面の下の 10 キーの帯を描く(画面設計書 §3・§9、仕様書 FR-13〜FR-15)。
# 画面の回転: 車が上を向くように、車の向きへ毎秒 CAM_RATE の割合で追う(ui の中なので atan2 を使う)。切ると北が上のまま車を追う。
# 描くだけで、ゲームの決まりは持たない(INV-1)。snapshot は ui/play.gd が毎フレーム渡す。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var rotate_on := true
var reduce_flash := false
var wasd := false
var lit := {}  # 帯で光らせる四角
var snap := {}
var cam_r := 0.0  # 世界を回す角度(rad)
var skids: Array = []  # [[a, b], ...] 世界の座標の線
var flash := {-1: -100000, 1: -100000}  # 壁の側 → 光り始めた時刻(ms)
var draws := 0
var draw_us: Array = []  # 1 回描くのにかかった時間(usec。NFR-1 の測定が読む)

var _pts := PackedVector2Array()
var _left := PackedVector2Array()
var _right := PackedVector2Array()
var _gates: Array = []  # [[左の端, 右の端], ...] 関門 1〜7
var _start: Array = []  # 市松の四角 [[4 つの角], 色の番号]
var _width := 200.0
var _rear := []  # 前のフレームの後ろの 2 点


# track は core/track.gd。中心線から壁と関門とスタートの帯を作っておく。
func setup(track: RefCounted) -> void:
	size = Vector2(B.SCREEN_W, B.SCREEN_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_start.clear()
	var t0 := (_pts[1] - _pts[0]).normalized()
	var cells := 10
	for row in 2:
		for k in cells:
			var a := _left[0].lerp(_right[0], float(k) / cells) + t0 * (8.0 * row - 8.0)
			var b := _left[0].lerp(_right[0], float(k + 1) / cells) + t0 * (8.0 * row - 8.0)
			_start.append([PackedVector2Array([a, b, b + t0 * 8.0, a + t0 * 8.0]), (k + row) % 2])
	skids.clear()
	_rear = []


static func heading_angle(c: Dictionary) -> float:
	return atan2(float(c["hy"]), float(c["hx"]))


# 1 フレームぶん、回転を追い、滑っていればタイヤの跡を足す。snap_now は sim.snapshot()。
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
	queue_redraw()


# 回転を今の車の向きにそろえる(走りの始め)。
func snap_camera(snap_now: Dictionary) -> void:
	snap = snap_now
	cam_r = -PI / 2.0 - heading_angle(snap["car"]) if rotate_on else 0.0
	queue_redraw()


static func _rear_points(c: Dictionary) -> Array:
	var p := Vector2(c["x"], c["y"])
	var h := Vector2(c["hx"], c["hy"])
	var r := Vector2(-h.y, h.x)
	var back := p - h * (B.CAR_LEN * 0.4)
	return [back - r * (B.CAR_WIDTH * 0.4), back + r * (B.CAR_WIDTH * 0.4)]


func world_transform() -> Transform2D:
	var c: Dictionary = snap["car"]
	var screen := Vector2(B.SCREEN_W / 2.0, B.CAR_SCREEN_Y if rotate_on else B.CAR_SCREEN_Y_FIXED)
	return Transform2D().translated(-Vector2(c["x"], c["y"])).rotated(cam_r).scaled(Vector2(B.CAM_ZOOM, B.CAM_ZOOM)).translated(screen)


func _draw() -> void:
	if snap.is_empty():
		return
	draws += 1
	var t0 := Time.get_ticks_usec()
	var now := Time.get_ticks_msec()
	draw_set_transform_matrix(world_transform())
	var px := 1.0 / B.CAM_ZOOM  # 画面の 1 px
	draw_polyline(_pts, Kit.C_ROAD, _width)
	for q: Array in _start:
		draw_colored_polygon(q[0], Kit.C_START if q[1] == 0 else Kit.C_ROAD)
	var c: Dictionary = snap["car"]
	var passed: int = int(c["next_gate"]) - 1
	for k in _gates.size():
		if k >= passed:
			draw_dashed_line(_gates[k][0], _gates[k][1], Kit.C_GATE, 2.0 * px, 12.0)
	for s: Array in skids:
		draw_line(s[0], s[1], Kit.C_SKID, 2.0 * px)
	for side: int in [-1, 1]:
		var line := _left if side < 0 else _right
		draw_polyline(line, Kit.C_WALL, 3.0 * px)
		var ft := float(now - int(flash[side])) / B.WALL_FLASH_MS
		if ft < 1.0:
			var a := B.REDUCED_FLASH_ALPHA if reduce_flash else 1.0
			draw_polyline(line, Color(1, 1, 1, a * (1.0 - ft)), 3.0 * px)
	var g: Variant = snap["ghost"]
	if g != null:
		var gp := _car_shape(g)
		gp.append(gp[0])
		draw_polyline(gp, Color(Kit.C_GHOST, 0.4), 2.0 * px)
	var me := _car_shape(c)
	draw_colored_polygon(me, Kit.C_CAR)
	if c["drift"]:
		var h := Vector2(c["hx"], c["hy"])
		draw_circle(Vector2(c["x"], c["y"]) - h * (B.CAR_LEN * 0.75), 3.0 * px, Kit.C_WARN)
	draw_set_transform_matrix(Transform2D())
	Kit.draw_strip(self, lit, wasd, float(c["wheel"]), float(snap["target"]))
	if draw_us.size() < 100000:
		draw_us.append(Time.get_ticks_usec() - t0)


static func _car_shape(c: Dictionary) -> PackedVector2Array:
	var p := Vector2(c["x"], c["y"])
	var h := Vector2(c["hx"], c["hy"])
	var r := Vector2(-h.y, h.x)
	return PackedVector2Array([p + h * (B.CAR_LEN / 2.0), p - h * (B.CAR_LEN / 2.0) + r * (B.CAR_WIDTH / 2.0), p - h * (B.CAR_LEN / 2.0) - r * (B.CAR_WIDTH / 2.0)])
