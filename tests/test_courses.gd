# コース 16 本のテスト(AC-15・§9.7・NFR-7)。JSON が読め、名前が strings.gd と同じで、閉じた輪であり、
# 中心 bot が 3 周を 5 分以内で走り切る。16 本の幽霊を全部入れた保存が 200 KB 以下か。道具の調べ(tools/build_courses.py --check)は CI で回す。
extends "res://tests/suite.gd"

const Share := preload("res://core/share_text.gd")
const Store := preload("res://save/save_store.gd")


func test_courses_load_and_close() -> bool:
	for k in B.COURSES:
		var c := course(k)
		ok(not c.is_empty(), "コース %d を読める" % k)
		if c.is_empty():
			continue
		eq(c["name"], S.COURSE_NAMES[k], "コース %d の名前" % k)
		var pts: Array = c["points"]
		ok(pts.size() >= 375 and pts.size() <= 875, "コース %d の点の数 %d" % [k, pts.size()])
		var gap := Vector2(pts[0][0], pts[0][1]).distance_to(Vector2(pts[-1][0], pts[-1][1]))
		ok(gap < 9.0, "コース %d は閉じた輪(最後の点から始めの点まで %.2f px)" % [k, gap])
		ok(int(c["width"]) >= 160, "コース %d の幅" % k)
	eq(course(0)["points"].size(), 793, "入門は 6342 px・793 点(§9.7 の命令のまま。INV-6)")
	return true


func test_ac15_bot_finishes_every_course() -> bool:
	var data := {}
	for k in B.COURSES:
		var sim := run_bot(k, Bots.CENTER, "", B.COUNTDOWN_TICKS + B.RACE_LIMIT_TICKS + 10)
		var r := sim.result()
		ok(r["finished"], "コース %d を中心 bot が走り切る" % k)
		ok(int(r["total_ticks"]) <= B.RACE_LIMIT_TICKS, "コース %d は 5 分以内" % k)
		print("      コース %2d %s: %s 壁 %d 回 記録 %d 字" % [k, S.COURSE_NAMES[k], Share.time_text(int(r["total_ticks"])), r["walls"], sim.record().length()])
		data[str(k)] = {"best_ticks": r["total_ticks"], "best_lap_ticks": r["best_lap"], "ghost": sim.record()}
	var save := Store.defaults()
	save["courses"] = data
	var size := JSON.stringify(save).to_utf8_buffer().size()
	print("      16 本の幽霊を入れた保存: %d バイト" % size)
	ok(size <= 200 * 1024, "保存は 200 KB 以下(NFR-7): %d" % size)
	return true
