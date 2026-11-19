# コース 1 本の中心線(閉じた輪)と幅、壁の判定(仕様書 §9.5)と周回の判定(§9.6)。
# course は ui/courses.gd が JSON から作った Dictionary { name, width, points: [[x, y], ...] }。core はファイルを読まない。
extends RefCounted

const B := preload("res://core/balance.gd")
const Car := preload("res://core/car.gd")

var xs := PackedFloat64Array()
var ys := PackedFloat64Array()
var n := 0
var width := 0.0
var limit := 0.0  # 中心線から車の中心までの上限(幅 ÷ 2 − CAR_R)
var gates := PackedInt32Array()  # 関門 k(1〜7)の点の番号。gates[k - 1]


@warning_ignore("integer_division")
func _init(course: Dictionary) -> void:
	for p: Array in course["points"]:
		xs.append(float(p[0]))
		ys.append(float(p[1]))
	n = xs.size()
	width = float(course["width"])
	limit = width / 2.0 - B.CAR_R
	for k in range(1, B.GATES):
		gates.append(k * n / B.GATES)


# 始めの位置(点 0)に、点 1 へ向けて置いた車。
func new_car() -> Car:
	var c := Car.new()
	c.x = xs[0]
	c.y = ys[0]
	var dx := xs[1] - xs[0]
	var dy := ys[1] - ys[0]
	var d := sqrt(dx * dx + dy * dy)
	c.hx = dx / d
	c.hy = dy / d
	return c


# 前の tick の区間 ±SEARCH の中で一番近い区間(区間 i は点 i → 点 i + 1)を car.seg にし、
# その上の一番近い点 [qx, qy] を返す(§9.5)。同じ近さなら番号の小さい側(−SEARCH から順に見て最初の物)。
func locate(car: Car) -> Array:
	var px := car.x
	var py := car.y
	var best := -1
	var bd := 0.0
	var bx := 0.0
	var by := 0.0
	for k in range(-B.SEARCH, B.SEARCH + 1):
		var i := posmod(car.seg + k, n)
		var j := i + 1 if i + 1 < n else 0
		var ax := xs[i]
		var ay := ys[i]
		var ex := xs[j] - ax
		var ey := ys[j] - ay
		var t := clampf(((px - ax) * ex + (py - ay) * ey) / (ex * ex + ey * ey), 0.0, 1.0)
		var qx := ax + ex * t
		var qy := ay + ey * t
		var d := (px - qx) * (px - qx) + (py - qy) * (py - qy)
		if best < 0 or d < bd:
			best = i
			bd = d
			bx = qx
			by = qy
	car.seg = best
	return [bx, by]


# 壁(§9.5)。触れ始めた tick だけ { s, side } を返す(side は −1 = 左の壁、1 = 右の壁)。それ以外は空。
func collide(car: Car) -> Dictionary:
	var q := locate(car)
	var qx: float = q[0]
	var qy: float = q[1]
	var dx := car.x - qx
	var dy := car.y - qy
	var d := sqrt(dx * dx + dy * dy)
	if d <= limit:
		car.touching = false
		return {}
	var ux := dx / d
	var uy := dy / d
	var s := car.vx * ux + car.vy * uy
	car.x = qx + ux * limit
	car.y = qy + uy * limit
	if s > 0.0:
		car.vx -= s * ux
		car.vy -= s * uy
	if car.touching:
		return {}
	car.touching = true
	car.vx *= B.WALL_KEEP
	car.vy *= B.WALL_KEEP
	car.walls += 1
	var j := (car.seg + 1) % n
	var cross := (xs[j] - xs[car.seg]) * uy - (ys[j] - ys[car.seg]) * ux
	return {"s": maxf(s, 0.0), "side": 1 if cross > 0.0 else -1}


# 周回(§9.6)。prev は動く前の進み。1 周を数えた時に真。
func lap(car: Car, prev: int) -> bool:
	var now := car.seg
	while car.next_gate < B.GATES:
		var g := gates[car.next_gate - 1]
		if prev < g and g <= now and now - prev <= B.SEARCH:
			car.next_gate += 1
		else:
			break
	if prev >= n - B.SEARCH and now < B.SEARCH:
		if car.next_gate == B.GATES:
			car.laps += 1
			car.next_gate = 1
			return true
	return false
