# 保存のテスト(仕様書 §9.12・AC-12・AC-17・E-6・E-7・E-12・E-15・NFR-9)。テストでは user:// の別のファイルを使う。
extends "res://tests/suite.gd"

const Store := preload("res://save/save_store.gd")
const P := "user://test_save.json"

const DONE := {"finished": true, "total_ticks": 7482, "lap_ticks": [2580, 2489, 2413], "best_lap": 2413, "walls": 4, "reason": "goal"}


func _fresh(text: Variant = null) -> Store:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	if text != null:
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return Store.new(P)


static func _run(total: int, lap: int, finished: bool = true) -> Dictionary:
	return {"finished": finished, "total_ticks": total, "lap_ticks": [lap, lap, total - 2 * lap], "best_lap": lap, "walls": 0, "reason": "goal" if finished else "timeout"}


func test_ac17_empty_broken_version() -> bool:
	var st := _fresh()
	eq(st.data, Store.defaults(), "空")
	ok(not st.load_failed, "空は失敗ではない")
	st = _fresh("{not json")
	eq(st.data, Store.defaults(), "壊れた JSON")
	ok(st.load_failed, "壊れた時は知らせる(E-12)")
	st = _fresh('{"version": 2, "intro_done": true}')
	eq(st.data, Store.defaults(), "version が 2")
	ok(st.load_failed, "知らない version も知らせる")
	return true


func test_ac12_physics_change_keeps_times() -> bool:
	var st := _fresh('{"version": 1, "physics": 0, "intro_done": true, "courses": {"8": {"best_ticks": 7482, "best_lap_ticks": 2413, "ghost": "0-2s,20-1k,0-a"}}}')
	ok(st.ghosts_cleared, "幽霊を消したと知らせる")
	eq(st.ghost(8), "", "幽霊が消える")
	eq(int(st.course(8)["best_ticks"]), 7482, "タイムは残る")
	eq(st.data["physics"], B.PHYSICS_VERSION, "今の physics")
	ok(not Store.new(P).ghosts_cleared, "消した物は書き戻した")
	return true


func test_best_and_ghost() -> bool:
	var st := _fresh()
	var a := st.record(3, "pick", 322, _run(8000, 2600), "0-a")
	ok(a["new_best"] and a["ghost_new"] and a["prev_best"] == null, "初めての記録")
	var b := st.record(3, "pick", 322, _run(8200, 2500), "0-b")
	ok(not b["new_best"] and not b["ghost_new"], "遅い走りは記録にしない")
	eq(b["prev_best"], 8000, "前の自己ベスト")
	eq(st.ghost(3), "0-a", "幽霊は速い方のまま")
	eq(int(st.course(3)["best_lap_ticks"]), 2500, "一番速い周は別に残す")
	st.record(3, "pick", 322, _run(7900, 2550), "0-c")
	eq(Store.new(P).ghost(3), "0-c", "速くなったら幽霊を替える(読み直しても)")
	return true


func test_e6_timeout_not_recorded() -> bool:
	var st := _fresh()
	var r := st.record(8, "daily", 322, _run(36000, 9000, false), "0-a")
	ok(not r["first_today"] and not r["new_best"], "時間切れは記録しない")
	eq(st.course(8), null, "コースの記録なし")
	eq(st.daily(322, 8)["first_ticks"], null, "今日の 1 回目にしない")
	return true


func test_daily_first_and_best() -> bool:
	var st := _fresh()
	var a := st.record(8, "daily", 322, _run(7610, 2500), "0-a")
	ok(a["first_today"], "1 回目")
	st.record(8, "daily", 322, _run(7482, 2400), "0-b")
	var d := Store.new(P).daily(322, 8)
	eq(d["first_ticks"], 7610, "1 回目は残る")
	eq(d["best_ticks"], 7482, "今日の最高")
	st.record(8, "pick", 322, _run(7000, 2300), "0-c")
	eq(Store.new(P).daily(322, 8)["best_ticks"], 7482, "コースを選ぶの走りは今日の記録にしない")
	var b := st.record(9, "daily", 323, _run(8000, 2600), "0-d")
	ok(b["first_today"], "日付が変われば作り直す")
	eq(Store.new(P).daily(322, 8)["first_ticks"], null, "前の日の記録は消える")
	return true


func test_e15_old_day_does_not_overwrite() -> bool:
	var st := _fresh()
	st.record(9, "daily", 323, _run(8000, 2600), "0-a")
	var r := st.record(8, "daily", 322, _run(7000, 2300), "0-b")
	ok(not r["first_today"], "古い日の走りは今日の記録にしない")
	eq(Store.new(P).daily(323, 9)["best_ticks"], 8000, "新しい日のまま")
	return true


func test_intro_done_and_e7() -> bool:
	var st := _fresh()
	ok(not st.data["intro_done"], "最初は入門を走り切っていない")
	st.record(0, "intro", 322, _run(4559, 1479, false), "0-a")
	ok(not st.data["intro_done"], "時間切れでは走り切った扱いにしない")
	st.record(0, "intro", 322, _run(4559, 1479), "0-a")
	ok(Store.new(P).data["intro_done"], "走り切ると intro_done")
	st.drop_ghost(0)
	eq(Store.new(P).ghost(0), "", "壊れた幽霊を消す(E-7)")
	eq(int(Store.new(P).course(0)["best_ticks"]), 4559, "タイムは残る")
	return true


func test_settings_and_shape() -> bool:
	var st := _fresh()
	st.set_setting("volume", 25)
	st.set_setting("rotate", false)
	st.set_setting("controls", "wasd")
	eq(Store.new(P).settings(), {"volume": 25, "shake": true, "reduce_flash": false, "rotate": false, "controls": "wasd"}, "設定が残る")
	st.record(8, "daily", 322, DONE, "0-2s,20-1k,0-a")
	var j := JSON.new()
	j.parse(FileAccess.get_file_as_string(P))
	eq(j.data["version"], 1.0, "version 1")
	eq(j.data["physics"], 1.0, "physics 1")
	eq(j.data["courses"]["8"], {"best_ticks": 7482.0, "best_lap_ticks": 2413.0, "ghost": "0-2s,20-1k,0-a"}, "§9.12 の形")
	eq(j.data["daily"], {"day": 322.0, "course": 8.0, "first_ticks": 7482.0, "best_ticks": 7482.0}, "今日のコースの形")
	return true


func test_bad_values() -> bool:
	var st := _fresh('{"version": 1, "physics": 1, "settings": {"volume": 33, "shake": "yes", "controls": "arrows"}, "courses": {"x": {"best_ticks": 5}, "99": {"best_ticks": 5}, "2": {"best_ticks": "x"}}}')
	eq(st.settings(), Store.default_settings(), "おかしな設定は既定値")
	eq(st.data["courses"], {}, "おかしなコースの記録は無し")
	ok(not st.load_failed, "形は読めた")
	return true


func test_web_key() -> bool:
	eq(Store.WEB_KEY, "steer-row/save", "localStorage のキー名(INV-8)")
	return true
