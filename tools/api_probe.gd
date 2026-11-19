# 仕様書 §9 と ui で使う Godot の API 名(SteerRow の分。作りは KeyFlak)が、この版の ClassDB に実在するかを確かめて印字する(§8.1「API 名の確認」)。
# 実行: python tools/gd.py run res://tools/api_probe.gd
extends SceneTree

const PROPS := {
	"InputEventKey": ["pressed", "echo", "keycode", "physical_keycode", "key_label", "unicode", "location"],
	"InputEventWithModifiers": ["shift_pressed", "ctrl_pressed", "alt_pressed", "meta_pressed"],
	"InputEventScreenTouch": ["pressed"],
	"AudioStreamPlayer": ["stream", "volume_db", "pitch_scale", "playing"],
	"AudioStreamWAV": ["loop_mode", "loop_begin", "loop_end", "mix_rate"],
	"Button": ["alignment", "disabled"],
	"Engine": ["time_scale"],
	"FontVariation": ["base_font", "variation_opentype"],
	"TextEdit": ["text", "editable", "context_menu_enabled"],
	"Label": ["text", "horizontal_alignment", "vertical_alignment"],
	"BoxContainer": ["alignment"],
	"Control": ["focus_mode", "mouse_filter", "custom_minimum_size"],
	"Node": ["process_mode"],
}
const METHODS := {
	"Time": ["get_ticks_usec", "get_ticks_msec", "get_date_dict_from_system"],
	"JavaScriptBridge": ["eval", "get_interface", "create_callback"],
	"DisplayServer": ["clipboard_set"],
	"CanvasItem": ["draw_line", "draw_dashed_line", "draw_colored_polygon", "draw_polygon", "draw_polyline", "draw_circle", "draw_arc", "draw_rect", "draw_string", "queue_redraw", "draw_set_transform_matrix"],
	"AudioStreamPlayer": ["play", "stop"],
	"AudioStream": ["get_length"],
	"Font": ["get_string_size", "has_char"],
	"RegEx": ["create_from_string", "search", "search_all"],
	"FileAccess": ["open", "file_exists", "get_file_as_string", "store_string"],
	"JSON": ["parse", "stringify"],
	"Viewport": ["set_input_as_handled"],
	"OS": ["has_feature", "get_cmdline_user_args", "get_keycode_string", "is_debug_build"],
	"Node": ["find_children", "queue_free", "set_process"],
	"TextServer": ["name_to_tag"],
}
const SIGNALS := {
	"BaseButton": ["pressed"],
}
const CONSTS := {
	"Node": ["NOTIFICATION_APPLICATION_FOCUS_OUT", "NOTIFICATION_WM_WINDOW_FOCUS_OUT", "NOTIFICATION_APPLICATION_PAUSED", "PROCESS_MODE_ALWAYS", "PROCESS_MODE_DISABLED"],
	"BoxContainer": ["ALIGNMENT_CENTER"],
	"Control": ["FOCUS_NONE", "FOCUS_CLICK", "MOUSE_FILTER_IGNORE"],
	"AudioStreamWAV": ["LOOP_FORWARD"],
}


func _initialize() -> void:
	var ng := 0
	for c: String in PROPS:
		var have := ClassDB.class_get_property_list(c).map(func(p: Dictionary) -> String: return p["name"])
		for p: String in PROPS[c]:
			ng += _say(c + "." + p, have.has(p))
	for c: String in METHODS:
		for m: String in METHODS[c]:
			ng += _say(c + "." + m + "()", ClassDB.class_has_method(c, m))
	for c: String in SIGNALS:
		for sg: String in SIGNALS[c]:
			ng += _say(c + "." + sg + "(シグナル)", ClassDB.class_has_signal(c, sg))
	for c: String in CONSTS:
		for k: String in CONSTS[c]:
			ng += _say(c + "." + k + " = " + str(ClassDB.class_get_integer_constant(c, k)), ClassDB.class_has_integer_constant(c, k))
	# 前提 7: 入力イベントが時刻を持つか。InputEvent とその子の項目名から time・stamp を探す。
	for c: String in ["InputEvent", "InputEventKey", "InputEventMouseButton", "InputEventScreenTouch", "InputEventWithModifiers", "InputEventFromWindow", "InputEventMouse"]:
		var names := ClassDB.class_get_property_list(c).map(func(p: Dictionary) -> String: return p["name"])
		var timed := names.filter(func(n: String) -> bool: return n.contains("time") or n.contains("stamp"))
		print("  %s の項目: %s / 時刻らしい項目: %s" % [c, ", ".join(names.filter(func(n: String) -> bool: return not n.contains(" ") and n != "script")), timed])
	print("KeyLocation: ", ClassDB.class_get_enum_constants("InputEventKey", "KeyLocation") if ClassDB.class_has_enum("InputEventKey", "KeyLocation") else "(InputEventKey には無い。@GlobalScope の KEY_LOCATION_LEFT = %d)" % KEY_LOCATION_LEFT)
	print("版: ", Engine.get_version_info()["string"])
	print("確かめられなかった物: %d 件" % ng)
	quit(1 if ng > 0 else 0)


func _say(what: String, ok: bool) -> int:
	print(("OK  " if ok else "NG  ") + what)
	return 0 if ok else 1
