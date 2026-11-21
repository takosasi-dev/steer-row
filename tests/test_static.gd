# ソースの決まりのテスト(AC-22・INV-2・INV-7・NFR-15)と、同梱の字体に画面の文字が全部あるか(ブラウザで目で見られない分)。
extends "res://tests/suite.gd"

const Kit := preload("res://ui/kit.gd")


static func _sources(dir: String) -> Array:
	var out: Array = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


static func _code(path: String) -> String:
	# コメントを除いた本文
	var lines: Array = []
	for l: String in FileAccess.get_file_as_string(path).split("\n"):
		var k := l.find("#")
		lines.append(l if k < 0 else l.substr(0, k))
	return "\n".join(lines)


func test_ac22_core_is_pure() -> bool:
	var re := RegEx.create_from_string("\\b(sin|cos|atan2|randf|randi|randf_range|randi_range|Time|FileAccess)\\b|extends\\s+Node")
	for p: String in _sources("res://core"):
		var code := _code(p)
		ok(code.contains("extends RefCounted"), "%s は RefCounted" % p)
		var m := re.search(code)
		ok(m == null, "%s に %s がある" % [p, m.get_string() if m != null else ""])
	return true


func test_ac22_no_text_outside_strings() -> bool:
	# 日本語の文字列リテラルは core/strings.gd の外に無い
	var lit := RegEx.create_from_string("\"([^\"\\\\\\n]|\\\\.)*\"")
	var ja := RegEx.create_from_string("[\\x{3040}-\\x{30FF}\\x{4E00}-\\x{9FFF}]")
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save"]:
		for p: String in _sources(dir):
			if p.ends_with("strings.gd"):
				continue
			for m: RegExMatch in lit.search_all(_code(p)):
				ok(ja.search(m.get_string()) == null, "%s の文言 %s は strings.gd へ" % [p, m.get_string()])
	return true


func test_font_has_all_chars() -> bool:
	var f := load(Kit.SANS) as Font
	ok(f != null, "字体を読める")
	if f == null:
		return true
	var lit := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	var missing := ""
	for m: RegExMatch in lit.search_all(FileAccess.get_file_as_string("res://core/strings.gd")):
		for c in m.get_string(1):
			if c != "%" and not f.has_char(c.unicode_at(0)) and not missing.contains(c):
				missing += c
	eq(missing, "", "字体に無い文字")
	for c in "0123456789,+−×":
		ok(f.has_char(c.unicode_at(0)), "数字と記号 %s" % c)
	return true


func test_ac21_no_network() -> bool:
	# 外へ通信しない(INV-9)。通信の部品と、JavaScript からの通信を使っていない
	var re := RegEx.create_from_string("HTTPRequest|HTTPClient|WebSocket|StreamPeerTCP|PacketPeerUDP|fetch\\(|XMLHttpRequest|sendBeacon")
	for dir: String in ["res://core", "res://ui", "res://audio", "res://save"]:
		for p: String in _sources(dir):
			var m := re.search(_code(p))
			ok(m == null, "%s に %s がある" % [p, m.get_string() if m != null else ""])
	return true


func test_sfx_loaded_and_loops() -> bool:
	eq(Sfx._streams.size(), 10, "効果音 10 個を読める(10 種以内。決めた音は v0.3.0)")
	var e: Variant = Sfx._streams.get("engine")
	ok(e is AudioStreamWAV and e.loop_mode == AudioStreamWAV.LOOP_FORWARD, "エンジンの音はループ")
	var total := 0
	for f: String in DirAccess.get_files_at("res://assets/sfx"):
		if f.ends_with(".wav"):
			total += FileAccess.get_file_as_bytes("res://assets/sfx/" + f).size()
	ok(total <= 400 * 1024, "効果音の合計 400 KB 以下(NFR-7): %d" % total)
	var courses := 0
	for k in B.COURSES:
		courses += FileAccess.get_file_as_bytes("res://courses/%d.json" % k).size()
	ok(courses <= 300 * 1024, "コースの JSON の合計 300 KB 以下(NFR-7): %d" % courses)
	print("      効果音 %d バイト、コースの JSON %d バイト" % [total, courses])
	return true
