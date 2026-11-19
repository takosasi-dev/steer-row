# テストの土台。ok / eq / near で確かめ、失敗は errors にたまる。コースを読み、bot や記録で走らせる道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Car := preload("res://core/car.gd")
const Track := preload("res://core/track.gd")
const Ghost := preload("res://core/ghost.gd")
const Wheel := preload("res://core/wheel.gd")
const Bots := preload("res://core/bots.gd")
const Courses := preload("res://ui/courses.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


func near(got: float, want: float, msg: String, eps: float = 0.001) -> void:
	if absf(got - want) > eps:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


static func course(k: int) -> Dictionary:
	return Courses.load_course(k)


# bot で最後まで(または max_steps で打ち切り)走らせた sim を返す。
static func run_bot(k: int, kind: int = Bots.CENTER, ghost: String = "", max_steps: int = 50000) -> Sim:
	var sim := Sim.new(course(k), ghost)
	var bot := Bots.new(kind)
	var n := 0
	while not sim.is_over() and n < max_steps:
		bot.act(sim)
		sim.step()
		n += 1
	return sim


# 記録の文字どおりに入力を流して走らせる(記録 bot)。ghost を渡すと幽霊も走る。
static func replay(k: int, record: String, ghost: String = "", extra: int = 0) -> Sim:
	var sim := Sim.new(course(k), ghost)
	var bot := Bots.new(Bots.REPLAY, record)
	var n := 0
	while not sim.is_over() and n < 50000:
		bot.act(sim)
		sim.step()
		n += 1
	for i in extra:
		sim.step()
	return sim


# 1 本の直線の試しのコース(幅 200、長さ 4000、点 8 px おき。閉じていないが壁と動きの試しに使う)。
static func strip(width: float = 200.0) -> Dictionary:
	var pts: Array = []
	for i in 500:
		pts.append([0.0, -8.0 * i])
	return {"name": "test", "width": width, "points": pts}


static func types(ev: Array) -> Array:
	return ev.map(func(e: Dictionary) -> String: return e["type"])
