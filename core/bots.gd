# テスト用の bot(仕様書 §9.13)。sim を読んで、次の step の入力を sim.set_input で入れる。外積・内積・平方根だけで決める。
# 中心 bot: 中心線の 12 点先へ向かう。外積 c から目標 clamp(3c, −1, 1) に一番近い目盛りのキーを 1 つ押す(点が後ろなら端)。
# 40 点先までの向きの変わり方が大きく(向きの内積が BOT_BRAKE_DOT 未満)、速さが 300 を超えていれば Space。
extends RefCounted

const B := preload("res://core/balance.gd")
const Ghost := preload("res://core/ghost.gd")
const Wheel := preload("res://core/wheel.gd")
const Track := preload("res://core/track.gd")
const Car := preload("res://core/car.gd")

const NONE := 0
const CENTER := 1
const REPLAY := 2

var kind := CENTER
var _replay: Ghost = null


# REPLAY の時は record に記録の文字を渡す。
func _init(p_kind: int = CENTER, record: String = "") -> void:
	kind = p_kind
	if kind == REPLAY:
		_replay = Ghost.parse(record)


func act(sim: RefCounted) -> void:
	match kind:
		NONE:
			sim.set_input(0, false)
		REPLAY:
			var v: int = _replay.next() if _replay != null else -1
			sim.set_input(maxi(v, 0) & Wheel.KEY_MASK, v >= 0 and (v & Wheel.BRAKE_BIT) != 0)
		_:
			_center(sim)


func _center(sim: RefCounted) -> void:
	var t: Track = sim.track
	var c: Car = sim.car
	var j := (c.seg + B.BOT_AHEAD) % t.n
	var dx := t.xs[j] - c.x
	var dy := t.ys[j] - c.y
	var d := sqrt(dx * dx + dy * dy)
	var cross: float = (c.hx * dy - c.hy * dx) / d if d > 0.0 else 0.0
	var dot: float = (c.hx * dx + c.hy * dy) / d if d > 0.0 else 1.0
	var aim := clampf(B.BOT_GAIN * cross, -1.0, 1.0)
	if dot < 0.0:
		aim = 1.0 if cross >= 0.0 else -1.0
	var key := clampi(int(floor((aim * 9.0 + 9.0) / 2.0 + 0.5)), 0, Wheel.KEYS - 1)
	var brake := c.speed() > B.BOT_BRAKE_SPEED and _bend(t, c.seg) < B.BOT_BRAKE_DOT
	sim.set_input(1 << key, brake)


# 点 i の向きと、8・16・…・40 点先の向きの内積の一番小さい値。
static func _bend(t: Track, i: int) -> float:
	var a := _dir(t, i)
	var low := 1.0
	for k in range(8, B.BOT_LOOK + 1, 8):
		var b := _dir(t, i + k)
		low = minf(low, a[0] * b[0] + a[1] * b[1])
	return low


static func _dir(t: Track, i: int) -> Array:
	var p := posmod(i, t.n)
	var q := (p + 1) % t.n
	var dx := t.xs[q] - t.xs[p]
	var dy := t.ys[q] - t.ys[p]
	var d := sqrt(dx * dx + dy * dy)
	return [dx / d, dy / d]
