# 車 1 台の状態と、1 tick ぶんの動き(仕様書 §9.4)。自分の車も幽霊の車もこれで動かす。
# 位置・速度・向きは float(64 ビット)の x と y を別々に持つ。向き h は長さ 1。sin・cos は使わず、小さい角度の回転の式で回す(D-13)。
# 壁と周回の判定に使う「近い区間」「関門」「周」も持つ(判定そのものは core/track.gd)。
extends RefCounted

const B := preload("res://core/balance.gd")

var x := 0.0
var y := 0.0
var hx := 0.0
var hy := -1.0
var vx := 0.0
var vy := 0.0
var w := 0.0  # ハンドル(−1〜1)
var drift := false
var seg := 0  # 近い区間の番号(進み)
var touching := false  # 前の tick に壁に当たっていたか
var next_gate := 1  # 次に通る関門の k(8 なら 7 つとも通った)
var laps := 0
var walls := 0


func speed() -> float:
	return sqrt(vx * vx + vy * vy)


# ハンドルを目標へ、1 tick に最大 WHEEL_RATE × dt 動かす(§9.4 の 1)。
func turn_wheel(target: float) -> void:
	var rate := B.WHEEL_RATE * B.DT
	var d := target - w
	if absf(d) <= rate + B.EPS:
		w = target
	else:
		w += rate if d > 0.0 else -rate


# 1 tick の向きの変わり方(§9.4 の 3)。
static func yaw_step(wheel: float, f: float) -> float:
	return wheel * B.YAW_MAX * maxf(B.MIN_TURN, minf(1.0, f / B.TURN_FULL_SPEED)) * B.DT


# 1 tick 進める。滑り始めたら "drift_start"、止まったら "drift_end"、変わらなければ "" を返す。
func step(target: float, brake: bool) -> String:
	turn_wheel(target)
	var f := vx * hx + vy * hy
	if brake:
		f = maxf(0.0, f - B.BRAKE * B.DT)
	else:
		f = f + B.ACCEL * B.DT
		if f >= B.V_MAX - B.EPS:
			f = B.V_MAX
	var dth := yaw_step(w, f)
	var nx := hx - hy * dth
	var ny := hy + hx * dth
	var hl := sqrt(nx * nx + ny * ny)
	hx = nx / hl
	hy = ny / hl
	var rx := -hy
	var ry := hx
	var l := vx * rx + vy * ry
	var now_drift := absf(w) >= B.DRIFT_WHEEL and f >= B.DRIFT_SPEED
	var grip := B.GRIP_DRIFT if now_drift else B.GRIP
	l *= maxf(0.0, 1.0 - grip * B.DT)
	vx = f * hx + l * rx
	vy = f * hy + l * ry
	x += vx * B.DT
	y += vy * B.DT
	var ev := ""
	if now_drift != drift:
		ev = "drift_start" if now_drift else "drift_end"
	drift = now_drift
	return ev


func to_dict() -> Dictionary:
	return {"x": x, "y": y, "hx": hx, "hy": hy, "vx": vx, "vy": vy, "speed": speed(), "wheel": w, "drift": drift,
		"seg": seg, "laps": laps, "next_gate": next_gate}
