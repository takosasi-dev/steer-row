# 保存の読み書き(仕様書 §9.12・FR-20・E-7・E-12・E-13・E-15)。コースごとの自己ベストと幽霊、今日のコースの 1 回目と最高、設定を持つ。
# 置き場: Web はブラウザの localStorage の steer-row/save(共通 §3 の 10。user:// は同じサイトのゲーム全部で 1 つなので使わない)、
# それ以外は user://save.json。読めない・壊れている・version が違う時は既定値で始め、書けなくても止めない。作りは KeyFlak・ParryDuel の save_store。
extends RefCounted

const B := preload("res://core/balance.gd")

const PATH := "user://save.json"
const VERSION := 1
const WEB_KEY := "steer-row/save"
# 使えない時は投げずに null / "no" を返す。書けたかは文字の 'ok' で返す(JS の true は 4.7.2 の Web で bool として届かない。ParryDuel v0.1.2)
const JS_READ := "(() => { try { return localStorage.getItem('%s'); } catch (e) { return null; } })()"
const JS_WRITE := "(() => { try { localStorage.setItem('%s', %s); return 'ok'; } catch (e) { return 'no'; } })()"
const CONTROLS := ["row", "wasd"]

var path: String
var data: Dictionary = {}
var load_failed := false  # 保存があったのに読めなかった(E-12)
var ghosts_cleared := false  # physics が違ったので幽霊を消した(§9.12)
var write_failed := false  # 直前の書き込みが失敗した(E-13)
var _web := OS.has_feature("web")


func _init(p_path: String = PATH) -> void:
	path = p_path
	load_data()


static func default_settings() -> Dictionary:
	return {"volume": B.DEFAULT_VOLUME, "shake": true, "reduce_flash": false, "rotate": true, "controls": "row"}


static func defaults() -> Dictionary:
	return {"version": VERSION, "physics": B.PHYSICS_VERSION, "intro_done": false, "courses": {}, "daily": null, "settings": default_settings()}


func load_data() -> void:
	data = defaults()
	load_failed = false
	ghosts_cleared = false
	var text: Variant = _read_text()
	if text == null:
		return
	var read: Variant = parse(text)
	if read == null:
		load_failed = true
		return
	data = read["data"]
	ghosts_cleared = read["ghosts_cleared"]
	if ghosts_cleared:
		save_data()


func _read_text() -> Variant:
	if _web:
		var v: Variant = JavaScriptBridge.eval(JS_READ % WEB_KEY, true)
		return v if v is String else null
	if not FileAccess.file_exists(path):
		return null
	return FileAccess.get_file_as_string(path)


func _write_text(text: String) -> bool:
	if _web:
		var ok: Variant = JavaScriptBridge.eval(JS_WRITE % [WEB_KEY, JSON.stringify(text)], true)
		return ok is String and ok == "ok"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# 保存の文字を決まった形に直す。読めない・辞書でない・version が 1 でない時は null(既定値で始める)。
# { data, ghosts_cleared } を返す。physics が今の PHYSICS_VERSION と違えば、タイムを残して幽霊だけを消す。
static func parse(text: String) -> Variant:
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return null
	var v: Dictionary = j.data
	if not _is_num(v.get("version")) or float(v["version"]) != float(VERSION):
		return null
	var out := defaults()
	var same_physics: bool = _is_num(v.get("physics")) and int(v["physics"]) == B.PHYSICS_VERSION
	var cleared := false
	if v.get("intro_done") is bool:
		out["intro_done"] = v["intro_done"]
	var cs: Variant = v.get("courses")
	if cs is Dictionary:
		for k: Variant in cs:
			var e: Variant = cs[k]
			if not (k is String) or not String(k).is_valid_int() or int(k) < 0 or int(k) >= B.COURSES:
				continue
			if not (e is Dictionary) or not _is_num(e.get("best_ticks")):
				continue
			var ghost: String = e["ghost"] if e.get("ghost") is String else ""
			if not same_physics and ghost != "":
				ghost = ""
				cleared = true
			out["courses"][str(int(k))] = {"best_ticks": int(e["best_ticks"]),
				"best_lap_ticks": int(e["best_lap_ticks"]) if _is_num(e.get("best_lap_ticks")) else int(e["best_ticks"]), "ghost": ghost}
	var d: Variant = v.get("daily")
	if d is Dictionary and _is_num(d.get("day")) and _is_num(d.get("course")):
		out["daily"] = {"day": int(d["day"]), "course": int(d["course"]),
			"first_ticks": int(d["first_ticks"]) if _is_num(d.get("first_ticks")) else null,
			"best_ticks": int(d["best_ticks"]) if _is_num(d.get("best_ticks")) else null}
	var st: Variant = v.get("settings")
	if st is Dictionary:
		if _is_num(st.get("volume")) and int(st["volume"]) in B.VOLUMES:
			out["settings"]["volume"] = int(st["volume"])
		for k: String in ["shake", "reduce_flash", "rotate"]:
			if st.get(k) is bool:
				out["settings"][k] = st[k]
		if st.get("controls") in CONTROLS:
			out["settings"]["controls"] = st["controls"]
	return {"data": out, "ghosts_cleared": cleared}


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


static func _min_ticks(a: Variant, b: Variant) -> Variant:
	if a == null:
		return b
	if b == null:
		return a
	return mini(int(a), int(b))


# 書く直前に今ある保存を読み直して合わせる(同じブラウザの別のタブが先に書いた記録を消さない)。
func _merge_from_disk() -> void:
	var text: Variant = _read_text()
	var read: Variant = parse(text) if text != null else null
	if read == null:
		return
	var disk: Dictionary = read["data"]
	data["intro_done"] = data["intro_done"] or disk["intro_done"]
	for k: String in disk["courses"]:
		var theirs: Dictionary = disk["courses"][k]
		var mine: Variant = data["courses"].get(k)
		if mine == null or int(theirs["best_ticks"]) < int(mine["best_ticks"]):
			data["courses"][k] = theirs
	var mine_d: Variant = data["daily"]
	var theirs_d: Variant = disk["daily"]
	if theirs_d is Dictionary:
		if not (mine_d is Dictionary) or int(theirs_d["day"]) > int(mine_d["day"]):
			data["daily"] = theirs_d
		elif int(theirs_d["day"]) == int(mine_d["day"]):
			if theirs_d["first_ticks"] != null:
				mine_d["first_ticks"] = theirs_d["first_ticks"]
			mine_d["best_ticks"] = _min_ticks(mine_d["best_ticks"], theirs_d["best_ticks"])


func save_data() -> bool:
	_merge_from_disk()
	write_failed = not _write_text(JSON.stringify(data, "", false))
	return not write_failed


# コース k の記録 { best_ticks, best_lap_ticks, ghost } か null。
func course(k: int) -> Variant:
	return data["courses"].get(str(k))


func ghost(k: int) -> String:
	var c: Variant = course(k)
	return c["ghost"] if c != null else ""


# 壊れていて使えなかった幽霊を消す(E-7)。
func drop_ghost(k: int) -> void:
	var c: Variant = course(k)
	if c != null and c["ghost"] != "":
		c["ghost"] = ""
		save_data()


# 今日の記録 { day, course, first_ticks, best_ticks }。日付が違えば空の物(保存はまだ書き換えない)。
func daily(day: int, course_no: int) -> Dictionary:
	var d: Variant = data["daily"]
	if d is Dictionary and int(d["day"]) == day:
		return d
	return {"day": day, "course": course_no, "first_ticks": null, "best_ticks": null}


# 結果画面に入った時に呼ぶ(FR-20)。entry は "intro" / "daily" / "pick"。走り切っていない走りは記録しない(E-6)。
# { prev_best, new_best, first_today, ghost_new, saved } を返す。
func record(k: int, entry: String, day: int, result: Dictionary, record_text: String) -> Dictionary:
	var out := {"prev_best": null, "new_best": false, "first_today": false, "ghost_new": false, "saved": true}
	var c: Variant = course(k)
	out["prev_best"] = c["best_ticks"] if c != null else null
	if not result["finished"]:
		return out
	var total := int(result["total_ticks"])
	var lap := int(result["best_lap"])
	if c == null:
		c = {"best_ticks": total, "best_lap_ticks": lap, "ghost": record_text}
		data["courses"][str(k)] = c
		out["new_best"] = true
		out["ghost_new"] = true
	else:
		c["best_lap_ticks"] = mini(int(c["best_lap_ticks"]), lap)
		if total < int(c["best_ticks"]):
			c["best_ticks"] = total
			c["ghost"] = record_text
			out["new_best"] = true
			out["ghost_new"] = true
	if k == B.INTRO:
		data["intro_done"] = true
	if entry == "daily":
		var stored: Variant = data["daily"]
		if not (stored is Dictionary and int(stored["day"]) > day):  # 日付をまたいだ古い日の走りは今日の記録にしない(E-15)
			var today := daily(day, k)
			if today["first_ticks"] == null:
				today["first_ticks"] = total
				out["first_today"] = true
			today["best_ticks"] = _min_ticks(today["best_ticks"], total)
			data["daily"] = today
	out["saved"] = save_data()
	return out


func settings() -> Dictionary:
	return data["settings"]


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_data()
