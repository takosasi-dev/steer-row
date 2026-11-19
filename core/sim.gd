# 1 回の走りの全状態と step()(仕様書 §9.3)。入力は毎 tick の 10 キーの組(10 ビット)とブレーキだけ(INV-3)。
# ui は set_input → step → events / snapshot を読むだけ。同じコースと同じ入力の列なら同じ走りになる(INV-4)。
# 幽霊は記録の入力を同じ car.gd・track.gd で動かす(ぶつからない・終わりにしない)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Wheel := preload("res://core/wheel.gd")
const Car := preload("res://core/car.gd")
const Track := preload("res://core/track.gd")
const Ghost := preload("res://core/ghost.gd")

const COUNT := 0
const RUN := 1
const OVER := 2

var track: Track
var car: Car
var ghost_car: Car = null
var phase := COUNT
var tick := 0  # 進めた step の数(数えも含む)
var race_tick := 0  # 走りの tick(go の次の step から数える)
var keys := 0
var brake := false
var lap_ticks: Array[int] = []
var reason := ""  # "goal" / "timeout"
var ghost_laps := 0
var ghost_goal_tick := -1  # 幽霊が 3 周目を数えた走りの tick
var ghost_done := false  # 幽霊の記録が尽きた

var _ghost: Ghost = null
var _record := Ghost.new()
var _lap_end := 0
var _events: Array = []


# course は ui/courses.gd の Dictionary。ghost は §9.8 の記録(無ければ "")。読めない記録は幽霊無し(E-7)。
func _init(course: Dictionary, ghost: String = "") -> void:
	track = Track.new(course)
	car = track.new_car()
	var g: Variant = Ghost.parse(ghost)
	if g != null:
		_ghost = g
		ghost_car = track.new_car()


func has_ghost() -> bool:
	return _ghost != null


# 次の step から使う入力。keys のビット i がキー i。
func set_input(p_keys: int, p_brake: bool) -> void:
	keys = p_keys & Wheel.KEY_MASK
	brake = p_brake


func step() -> void:
	_events.clear()
	if phase == OVER:
		return
	var value := keys | (Wheel.BRAKE_BIT if brake else 0)
	_record.push(value)
	var gv := -1
	if _ghost != null and not ghost_done:
		gv = _ghost.next()
		ghost_done = gv < 0
	if phase == COUNT:
		car.turn_wheel(Wheel.target(keys))
		if gv >= 0:
			ghost_car.turn_wheel(Wheel.target(gv & Wheel.KEY_MASK))
		tick += 1
		if tick >= B.COUNTDOWN_TICKS:
			phase = RUN
			_events.append({"type": "go"})
		return
	_move(car, value, true)
	if gv >= 0:
		_move(ghost_car, gv, false)
	race_tick += 1
	tick += 1
	if phase == RUN and race_tick >= B.RACE_LIMIT_TICKS:
		_finish("timeout")


# 車 1 台を 1 tick 動かす(§9.4 → 壁 §9.5 → 周回 §9.6)。mine なら出来事を出し、周とタイムを数える。
func _move(c: Car, value: int, mine: bool) -> void:
	var prev := c.seg
	var ev := c.step(Wheel.target(value & Wheel.KEY_MASK), (value & Wheel.BRAKE_BIT) != 0)
	var hit := track.collide(c)
	var lapped := track.lap(c, prev)
	if not mine:
		if lapped and c.laps == B.LAPS:
			ghost_goal_tick = race_tick + 1
		return
	if ev != "":
		_events.append({"type": ev})
	if not hit.is_empty():
		_events.append({"type": "wall_hit", "s": hit["s"], "side": hit["side"]})
	if lapped:
		var t := race_tick + 1 - _lap_end
		_lap_end = race_tick + 1
		lap_ticks.append(t)
		_events.append({"type": "lap", "lap": c.laps, "ticks": t, "best": lap_ticks.size() >= 2 and t < lap_ticks.slice(0, -1).min()})
		if c.laps >= B.LAPS:
			_finish("goal")


func _finish(why: String) -> void:
	phase = OVER
	reason = why
	_events.append({"type": "over", "reason": why})


func events() -> Array:
	return _events


func is_over() -> bool:
	return phase == OVER


func best_lap() -> int:
	return lap_ticks.min() if not lap_ticks.is_empty() else -1


# 幽霊が自分より先にいるか(地図の点の色。周 × 点の数 + 進みで比べる)。
func ghost_ahead() -> bool:
	if ghost_car == null:
		return false
	return ghost_car.laps * track.n + ghost_car.seg > car.laps * track.n + car.seg


func snapshot() -> Dictionary:
	return {
		"car": car.to_dict(),
		"target": Wheel.target(keys),
		"ghost": ghost_car.to_dict() if ghost_car != null else null,
		"ghost_ahead": ghost_ahead(),
		"lap": mini(car.laps + 1, B.LAPS),
		"lap_ticks": lap_ticks.duplicate(),
		"best_lap": best_lap(),
		"race_tick": race_tick,
		"count_tick": tick if phase == COUNT else B.COUNTDOWN_TICKS,
		"phase": phase,
		"walls": car.walls,
		"keys": keys,
		"brake": brake,
	}


# 走り切ったか、合計の tick、周ごとの tick、一番速い周、壁の回数、終わった理由。
func result() -> Dictionary:
	return {
		"finished": reason == "goal",
		"total_ticks": race_tick,
		"lap_ticks": lap_ticks.duplicate(),
		"best_lap": best_lap(),
		"walls": car.walls,
		"reason": reason,
	}


func record() -> String:
	return _record.to_text()
