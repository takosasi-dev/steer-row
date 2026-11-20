# 記録(§9.8 の文字)をヘッドレスで再生し、最後の位置を印字する(R-4 の照らし。tests/web/check.mjs がブラウザの値と比べる)。
# 実行: python tools/gd.py run res://tools/replay.gd course=0 file=<記録の文字を入れたファイルの絶対パス>
# 印字: REPLAY <合計の tick> / <x>,<y> / <壁の回数>(小数 6 桁。記録が尽きるまで回す)
extends SceneTree

const Sim := preload("res://core/sim.gd")
const Bots := preload("res://core/bots.gd")
const Courses := preload("res://ui/courses.gd")


func _initialize() -> void:
	var args := {}
	for a: String in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var record := FileAccess.get_file_as_string(args.get("file", "")).strip_edges()
	var sim := Sim.new(Courses.load_course(int(args.get("course", "0"))))
	var bot := Bots.new(Bots.REPLAY, record)
	var steps := 0
	var total: int = bot._replay.total() if bot._replay != null else 0
	while not sim.is_over() and steps < total:
		bot.act(sim)
		sim.step()
		steps += 1
	print("REPLAY %d / %.6f,%.6f / %d" % [sim.race_tick, sim.car.x, sim.car.y, sim.car.walls])
	quit(0)
