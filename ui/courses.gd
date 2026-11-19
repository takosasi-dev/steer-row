# コースの JSON(courses/<番号>.json、tools/build_courses.py が作る)を読んで Dictionary にする。core はファイルを読まないので ui が読む。
# 書き出しでは export_presets.cfg の include_filter で courses/*.json を pck に入れている。
extends RefCounted

static var _cache := {}


# { name, width, points: [[x, y], ...], length }。読めなければ空の Dictionary。
static func load_course(k: int) -> Dictionary:
	if _cache.has(k):
		return _cache[k]
	var text := FileAccess.get_file_as_string("res://courses/%d.json" % k)
	var v: Variant = JSON.parse_string(text) if text != "" else null
	var c: Dictionary = v if v is Dictionary else {}
	_cache[k] = c
	return c
