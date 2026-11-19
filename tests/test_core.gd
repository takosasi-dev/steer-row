# core の決まりのテスト(仕様書 §9.2〜§9.8・§9.11・AC-2〜AC-14・AC-16・E-4〜E-9)。
extends "res://tests/suite.gd"

const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")


func test_ac3_wheel_target() -> bool:
	eq(Wheel.target(1 << 0), -1.0, "A だけで −1")
	eq(Wheel.target(1 << 9), 1.0, "; だけで 1")
	eq(Wheel.target((1 << 4) | (1 << 5)), 0.0, "G と H で 0")
	eq(Wheel.target((1 << 3) | (1 << 4)), -2.0 / 9.0, "F と G で −2/9")
	eq(Wheel.target(0), 0.0, "何も無しで 0")
	eq(Wheel.target((1 << 0) | (1 << 9)), 0.0, "A と ; で 0")
	eq(Wheel.target(Wheel.KEY_MASK), 0.0, "10 キー全部で 0(E-2)")
	eq(Wheel.target(1 << 4), -1.0 / 9.0, "G は −1/9")
	eq(Wheel.target(1 << 5), 1.0 / 9.0, "H は 1/9")
	return true


func test_ac4_wheel_rate() -> bool:
	var c := Car.new()
	for k in 19:
		c.turn_wheel(1.0)
	ok(c.w < 1.0, "19 tick では届かない: %s" % c.w)
	c.turn_wheel(1.0)
	eq(c.w, 1.0, "20 tick で届く")
	return true


func test_ac5_accel_and_brake() -> bool:
	var c := Car.new()
	for k in 239:
		c.step(0.0, false)
	ok(c.speed() < B.V_MAX, "239 tick では 520 に届かない: %s" % c.speed())
	c.step(0.0, false)
	eq(c.speed(), B.V_MAX, "240 tick で 520(241 以内)")
	for k in 89:
		c.step(0.0, true)
	ok(c.speed() > 0.0, "Space 89 tick ではまだ動いている")
	c.step(0.0, true)
	eq(c.speed(), 0.0, "Space 90 tick で 0")
	return true


# 1 tick の向きの変わり方(rad)。
static func _turned(c: Car, w: float, brake: bool) -> float:
	var hx := c.hx
	var hy := c.hy
	c.w = w
	c.step(w, brake)
	return atan2(hx * c.hy - hy * c.hx, hx * c.hx + hy * c.hy)


func test_ac6_turn_rate() -> bool:
	near(Car.yaw_step(1.0, 100.0), 2.6 * 0.5 / 120.0, "速さ 100 の式", 1e-12)
	var c := Car.new()
	c.vy = -(100.0 - B.ACCEL * B.DT)  # 加速した後の前向きの速さがちょうど 100
	near(_turned(c, 1.0, false), 2.6 * 0.5 / 120.0, "速さ 100・ハンドル 1", 1e-6)
	c = Car.new()
	near(_turned(c, 1.0, true), 2.6 * 0.3 / 120.0, "速さ 0 でも MIN_TURN で曲がる(E-3)", 1e-6)
	ok(_turned(Car.new(), -1.0, true) < 0.0, "負のハンドルは左")
	return true


# 前向き f(加速の後)と横 l0 を持つ車を 1 tick 動かし、横の速さが何倍になったか。
static func _lateral_ratio(f: float, w: float) -> Array:
	var c := Car.new()
	c.w = w
	c.vx = 40.0
	c.vy = -(f - B.ACCEL * B.DT)
	var vx := c.vx
	var vy := c.vy
	c.step(w, false)
	var rx := -c.hy
	var ry := c.hx
	var before := vx * rx + vy * ry
	var after := c.vx * rx + c.vy * ry
	return [after / before, c.drift]


func test_ac7_drift_grip() -> bool:
	var a := _lateral_ratio(400.0, 0.8)
	ok(a[1], "速さ 400・ハンドル 0.8 で滑っている")
	near(a[0], 1.0 - 2.5 / 120.0, "滑っている時の横の速さ", 1e-9)
	var b := _lateral_ratio(300.0, 0.8)
	ok(not b[1], "速さ 300 では滑らない")
	near(b[0], 1.0 - 6.0 / 120.0, "滑らない時の横の速さ", 1e-9)
	var c := _lateral_ratio(400.0, 0.6)
	ok(not c[1], "ハンドル 0.6 では滑らない")
	return true


func test_ac8_wall() -> bool:
	var t := Track.new(strip())
	var c := Car.new()
	c.x = 95.0
	c.y = -1000.0
	c.seg = 125
	c.vy = -300.0
	var hit := t.collide(c)
	ok(not hit.is_empty(), "壁に触れた")
	eq(hit.get("side"), 1, "右の壁")
	near(c.speed(), 180.0, "触れた tick に 0.6 倍", 1e-9)
	near(c.x, 90.0, "幅 ÷ 2 − 10 の内に戻る", 1e-9)
	eq(c.walls, 1, "壁の回数")
	c.x = 95.0
	hit = t.collide(c)
	ok(hit.is_empty(), "触れ続けた次の tick は出来事なし")
	near(c.speed(), 180.0, "触れ続けた次の tick は 0.6 倍にならない(E-4)", 1e-9)
	eq(c.walls, 1, "壁の回数は 1 のまま")
	c.x = 0.0
	t.collide(c)
	ok(not c.touching, "離れた")
	c.x = -100.0
	c.vx = -100.0
	c.vy = -300.0
	hit = t.collide(c)
	eq(hit.get("side"), -1, "左の壁")
	near(hit.get("s", 0.0), 100.0, "外向きの速さ", 1e-9)
	near(c.vx, 0.0, "外向きの速さを消す", 1e-9)
	near(c.vy, -180.0, "残りを 0.6 倍", 1e-9)
	return true


# 進みを seq の順に動かし、周を数えた回数を返す。
static func _walk(t: Track, c: Car, seq: Array) -> int:
	var laps := 0
	for s: int in seq:
		var prev := c.seg
		c.seg = s
		if t.lap(c, prev):
			laps += 1
	return laps


func test_ac9_gates() -> bool:
	var t := Track.new(course(0))
	var n := t.n
	var g3: int = t.gates[2]
	var seq: Array = []
	var s := 0
	while s < n:  # 関門 3 を 1 歩(30 点)で飛び越える
		seq.append(s)
		s += 30 if s > g3 - 40 and s < g3 + 10 else 10
	seq.append(5)
	var c := t.new_car()
	eq(_walk(t, c, seq), 0, "関門を 1 つ飛ばすと数えない")
	c = t.new_car()
	eq(_walk(t, c, range(n - 5, 0, -10) + [n - 3, n - 13, n - 23, 3]), 0, "逆向きに越えても数えない")
	c = t.new_car()
	var full: Array = range(10, n, 10) + [3]
	eq(_walk(t, c, full), 1, "順に通ってスタートを越えると 1 周")
	eq(c.next_gate, 1, "関門の記録を消す")
	eq(_walk(t, c, [n - 3, 4]), 0, "関門を通らずに戻って越えても数えない(E-5)")
	return true


func test_ac10_ac14_intro_bot() -> bool:
	var sim := run_bot(0)
	var r := sim.result()
	ok(r["finished"], "中心 bot が入門を走り切る")
	var total: int = r["total_ticks"]
	var sum := 0
	for t: int in r["lap_ticks"]:
		sum += t
	eq(r["lap_ticks"].size(), 3, "3 周")
	eq(sum, total, "合計の tick = 周の和(AC-10)")
	ok(total <= 90 * B.TICK_HZ, "90 秒以内(AC-14): %s" % Share.time_text(total))
	ok(int(r["walls"]) <= 2, "壁 2 回以下(AC-14): %d" % r["walls"])
	eq(r["reason"], "goal", "理由はゴール")
	print("      入門 中心 bot: %s(周 %s)壁 %d 回" % [Share.time_text(total), r["lap_ticks"].map(Share.time_text), r["walls"]])
	return true


func test_ac10_ends_on_third_lap_step() -> bool:
	var sim := Sim.new(course(0))
	var bot := Bots.new(Bots.CENTER)
	var laps := 0
	while not sim.is_over() and sim.tick < 50000:
		bot.act(sim)
		sim.step()
		var ev := sim.events()
		for e: Dictionary in ev:
			if e["type"] == "lap":
				laps += 1
				eq(e["lap"], laps, "周の番号")
		if laps == 3:
			ok(sim.is_over(), "3 周目を数えた step で終わる")
			ok(types(ev).has("over"), "同じ step に over")
			break
	eq(laps, 3, "3 周")
	return true


func test_ac2_same_input_same_run() -> bool:
	var first := run_bot(0)
	var rec := first.record()
	var want := [first.race_tick, "%.6f,%.6f" % [first.car.x, first.car.y], first.car.walls]
	var same := 0
	for k in 100:
		var s := replay(0, rec)
		if [s.race_tick, "%.6f,%.6f" % [s.car.x, s.car.y], s.car.walls] == want:
			same += 1
	eq(same, 100, "100 回とも合計の tick・最後の位置・壁の回数が同じ")
	eq(first.record(), replay(0, rec).record(), "記録も同じ")
	return true


# 記録を幽霊として、何も押さない車と一緒に流し、幽霊の記録が尽きるまで回す。
static func _ghost_run(k: int, rec: String) -> Sim:
	var sim := Sim.new(course(k), rec)
	while not sim.ghost_done and not sim.is_over():
		sim.set_input(0, true)
		sim.step()
	return sim


func test_ac11_ghost_replay() -> bool:
	var a := run_bot(0)
	var g := _ghost_run(0, a.record())
	ok(g.has_ghost(), "幽霊がある")
	near(g.ghost_car.x, a.car.x, "幽霊の最後の x", 0.001)
	near(g.ghost_car.y, a.car.y, "幽霊の最後の y", 0.001)
	eq(g.ghost_goal_tick, a.race_tick, "同じ tick にゴール")
	eq(g.ghost_car.laps, 3, "幽霊も 3 周")
	return true


func test_ac11_ghost_keeps_countdown_wheel() -> bool:
	# 数えの間に ; を押さえた走り(E-9)。記録が数えから始まるので、幽霊も同じハンドルで go を迎える
	var a := Sim.new(course(0))
	var bot := Bots.new(Bots.CENTER)
	while not a.is_over() and a.tick < 50000:
		if a.phase == Sim.COUNT:
			a.set_input(1 << 9, false)
		else:
			bot.act(a)
		a.step()
	ok(a.result()["finished"], "走り切る")
	var g := _ghost_run(0, a.record())
	near(g.ghost_car.x, a.car.x, "幽霊の最後の x", 0.001)
	near(g.ghost_car.y, a.car.y, "幽霊の最後の y", 0.001)
	eq(g.ghost_goal_tick, a.race_tick, "同じ tick にゴール")
	return true


func test_e9_countdown_turns_wheel_only() -> bool:
	var sim := Sim.new(course(0))
	var x := sim.car.x
	var y := sim.car.y
	var go := 0
	for k in B.COUNTDOWN_TICKS:
		sim.set_input(1 << 9, false)
		sim.step()
		if types(sim.events()).has("go"):
			go = k + 1
	eq(go, B.COUNTDOWN_TICKS, "数え終わった step に go")
	eq([sim.car.x, sim.car.y], [x, y], "数えの間は車が動かない")
	eq(sim.car.w, 1.0, "ハンドルは目標へ回っている")
	eq(sim.race_tick, 0, "走りの tick は 0 のまま")
	sim.step()
	eq(sim.race_tick, 1, "go の次の step から数える")
	ok(sim.car.y < y, "走り出す")
	return true


func test_e8_ghost_stops_when_record_ends() -> bool:
	var sim := Sim.new(course(0), "0-50,sg-a")  # 数え 180 tick と、ブレーキで 10 tick
	for k in 400:
		sim.set_input(0, false)
		sim.step()
	ok(sim.ghost_done, "記録が尽きた")
	var gx := sim.ghost_car.x
	var gy := sim.ghost_car.y
	sim.step()
	eq([sim.ghost_car.x, sim.ghost_car.y], [gx, gy], "幽霊はその場で止まる")
	return true


func test_e7_broken_ghost() -> bool:
	for bad: String in ["zz", "1-0", "a-", "-3", "1-2,x", "1000-1", "0-2s;20-1k", "A-1"]:
		ok(not Sim.new(course(0), bad).has_ghost(), "壊れた記録 %s は幽霊にしない" % bad)
	ok(not Sim.new(course(0), "").has_ghost(), "空は幽霊なし")
	ok(Sim.new(course(0), "0-2s,20-1k,0-a").has_ghost(), "正しい記録は幽霊あり")
	return true


func test_ghost_text_round_trip() -> bool:
	var g: Ghost = Ghost.parse("0-2s,20-1k,0-a")
	eq(g.total(), 100 + 56 + 10, "36 進の回数")
	eq(g.values, PackedInt32Array([0, 72, 0]), "36 進の値")
	eq(g.to_text(), "0-2s,20-1k,0-a", "文字に戻すと同じ")
	var r := Ghost.new()
	for v: int in [0, 0, 0, 5, 5, 2047]:
		r.push(v)
	eq(r.to_text(), "0-3,5-2,1kv-1", "同じ値が続いた回数の対")
	return true


func test_record_has_brake_bit() -> bool:
	var sim := Sim.new(course(0))
	sim.set_input((1 << 0) | (1 << 9), true)
	sim.step()
	eq(sim.record(), "%s-1" % Ghost.b36(1 | 512 | 1024), "キーの組とブレーキ(ビット 10)")
	sim.set_input(0xFFFF, false)
	sim.step()
	ok(sim.record().ends_with(Ghost.b36(1023) + "-1"), "10 ビットより上は捨てる(INV-3)")
	return true


func test_e6_timeout() -> bool:
	var sim := Sim.new(course(0))
	for k in B.COUNTDOWN_TICKS:
		sim.step()
	sim.race_tick = B.RACE_LIMIT_TICKS - 2
	sim.step()
	ok(not sim.is_over(), "まだ")
	sim.step()
	ok(sim.is_over(), "5 分で終わる")
	eq(sim.result()["reason"], "timeout", "時間切れ")
	eq(sim.result()["finished"], false, "走り切っていない")
	ok(types(sim.events()).has("over"), "over を出す")
	var t := sim.race_tick
	sim.step()
	eq(sim.race_tick, t, "終わったら何もしない")
	return true


func test_events_wall_and_drift() -> bool:
	# 何も押さないと最初のカーブで外の壁に当たる
	var sim := Sim.new(course(0))
	var seen := []
	for k in 2000:
		sim.set_input(0, false)
		sim.step()
		seen.append_array(types(sim.events()))
	ok(seen.has("go"), "go")
	ok(seen.has("wall_hit"), "壁に当たる")
	eq(seen.count("wall_hit"), sim.car.walls, "壁の回数と出来事の数")
	# ; を押さえたまま速く走ると滑る
	sim = Sim.new(course(0))
	seen = []
	for k in 600:
		sim.set_input(1 << 9 if k > 420 else 0, false)
		sim.step()
		seen.append_array(types(sim.events()))
	ok(seen.has("drift_start"), "速いまま強く切ると滑る(FR-7)")
	return true


func test_ac13_today_course() -> bool:
	eq(Day.day_index(2026, 11, 19), 322, "2026-11-19 は 322")
	eq(Day.today_course(322), 8, "322 はコース 8")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01 は 365")
	eq(Day.day_index(2025, 12, 31), 0, "2026 より前は 0(E-16)")
	var seen := {}
	for d in 400:
		var c := Day.today_course(d)
		ok(c >= 1 and c <= 15, "1〜15: %d" % c)
		seen[c] = true
	eq(seen.size(), 15, "15 本を巡る")
	eq(Day.today_course(0), 4, "通し日数 0 は (0 + 3) % 15 + 1")
	return true


func test_ac16_share_text() -> bool:
	var r := {"total_ticks": 7482, "lap_ticks": [2580, 2489, 2413], "best_lap": 2413, "walls": 4, "finished": true}
	eq(Share.time_text(7482), "1:02.35", "7482 tick は 1:02.35")
	eq(Share.time_text(2413), "0:20.10", "2413 tick")
	eq(Share.make("2026-11-19", Share.DAILY, 8, true, r),
		"SteerRow 2026-11-19(今日のコース 8・1回目)\n3 周 1:02.35 / 最速の周 0:20.10 / 壁 4 回\nhttps://takosasi-dev.github.io/steer-row/", "§9.11 の形")
	ok(Share.make("2026-11-19", Share.DAILY, 8, false, r).begins_with("SteerRow 2026-11-19(今日のコース 8)\n"), "2 回目以降")
	ok(Share.make("2026-11-19", Share.PICK, 3, false, r).begins_with("SteerRow 2026-11-19(コース 3)\n"), "コースを選ぶ")
	ok(Share.make("2026-11-19", Share.INTRO, 0, false, r).begins_with("SteerRow 2026-11-19(入門コース)\n"), "入門")
	eq(Share.time_text(36000), "5:00.00", "5 分")
	eq(Share.diff_text(-55), "0.55", "差")
	return true


# Windows と CI(Linux)で同じ走りになるか(NFR-4・§8.2 の決定性の照らし)。固定値は Windows で回した値。Actions で同じなら一致している。
func test_nfr4_fixed_values() -> bool:
	var sim := run_bot(0)
	var got := "%d / %.6f,%.6f / %d" % [sim.race_tick, sim.car.x, sim.car.y, sim.car.walls]
	print("      入門 中心 bot の照らしの値: ", got)
	eq(got, "4559 / -1.359871,-0.284159 / 0", "入門の中心 bot: 合計の tick / 最後の位置 / 壁の回数")
	return true
