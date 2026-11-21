# ui/theme.tres を作る(UI の見た目の決まりを 1 つの Theme にまとめる。v0.3.0)。project.godot の gui/theme/custom で全部の Control に付く。
# 色と傾きは ui/kit.gd から読む。見た目を変えたら回し直して、theme.tres もコミットする。
#     python tools/gd.py run res://tools/make_theme.gd
# ボタンは 5 つの状態(normal / hover / pressed / disabled / focus)を全部作る。キーボードで選んでいる印は type variation の SelButton
# (ui/menu.gd が切り替える。Godot のフォーカスは矢印を取られるので使わない)。共有の枠(TextEdit)・右クリックの窓(PopupMenu)・
# 送りの棒・スライダー・チェック・入力欄・ツールチップも作る(今は使っていない部品も、後から作った時に既定の見た目に戻らないように)。
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var t := Theme.new()
	t.default_font = Kit.font(500)
	t.default_font_size = 20
	var bold := Kit.font(700)

	# --- ボタン ---
	t.set_stylebox("normal", "Button", _box(Kit.C_PANEL, Color(Kit.C_WALL, 0.5), 2))  # 塗りは不透明(後ろの流れる線を透かさない)
	t.set_stylebox("hover", "Button", _sel(0.14))
	t.set_stylebox("pressed", "Button", _sel(0.34))
	t.set_stylebox("disabled", "Button", _box(Kit.C_PANEL.lerp(Kit.C_BG, 0.5), Color(Kit.C_WALL, 0.22), 2))
	var focus := _box(Color(0, 0, 0, 0), Kit.C_AMBER, 3)
	focus.draw_center = false
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	t.set_stylebox("focus", "Button", focus)
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", Kit.C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_DIM, 0.75))
	t.set_color("font_outline_color", "Button", Kit.C_BG)
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("h_separation", "Button", 8)

	# 選んでいる時(キーボードの印): 琥珀の縁と、左の太い琥珀の柱。disabled は「もう1回」の最初の 300 ms(選んだまま押せない)
	t.set_type_variation("SelButton", "Button")
	t.set_stylebox("normal", "SelButton", _sel(0.16))
	t.set_stylebox("hover", "SelButton", _sel(0.2))
	t.set_stylebox("pressed", "SelButton", _sel(0.36))
	var sel_off := _sel(0.06)
	sel_off.border_color = Color(Kit.C_AMBER, 0.5)
	t.set_stylebox("disabled", "SelButton", sel_off)
	t.set_color("font_color", "SelButton", Color.WHITE)
	t.set_color("font_disabled_color", "SelButton", Color(Kit.C_TEXT, 0.6))

	# --- 字 ---
	t.set_color("font_color", "Label", Kit.C_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	# --- 板 ---
	var panel := _box(Color(Kit.C_PANEL, 0.96), Color(Kit.C_WALL, 0.35), 1)
	panel.skew = Vector2.ZERO
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)

	# --- 入力欄・共有の枠 ---
	var field := _flat(Color(Kit.C_PANEL, 0.96), Color(Kit.C_WALL, 0.4), 1, 14)
	var field_focus := _flat(Color(Kit.C_PANEL, 0.96), Kit.C_AMBER, 2, 14)
	for type: String in ["TextEdit", "LineEdit"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("read_only", type, field)
		t.set_stylebox("focus", type, field_focus)
		t.set_font("font", type, Kit.font(400))
		t.set_font_size("font_size", type, 18)
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_readonly_color", type, Kit.C_TEXT)
		t.set_color("font_selected_color", type, Color.WHITE)
		t.set_color("selection_color", type, Color(Kit.C_AMBER, 0.38))
		t.set_color("caret_color", type, Kit.C_AMBER)
		t.set_color("font_placeholder_color", type, Color(Kit.C_DIM, 0.8))
	t.set_constant("line_spacing", "TextEdit", 6)

	# --- 右クリックの窓・ツールチップ ---
	var pop := _flat(Kit.C_PANEL_2, Color(Kit.C_WALL, 0.5), 1, 8)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _flat(Color(Kit.C_AMBER, 0.22), Color(0, 0, 0, 0), 0, 8))
	t.set_stylebox("separator", "PopupMenu", _flat(Color(Kit.C_WALL, 0.3), Color(0, 0, 0, 0), 0, 0))
	t.set_color("font_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(Kit.C_DIM, 0.6))
	t.set_color("font_accelerator_color", "PopupMenu", Kit.C_DIM)
	t.set_font_size("font_size", "PopupMenu", 16)
	t.set_stylebox("panel", "TooltipPanel", pop)
	t.set_color("font_color", "TooltipLabel", Kit.C_TEXT)

	# --- 送りの棒 ---
	for type: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, _flat(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 0))
		t.set_stylebox("grabber", type, _flat(Color(Kit.C_WALL, 0.55), Color(0, 0, 0, 0), 0, 0))
		t.set_stylebox("grabber_highlight", type, _flat(Kit.C_AMBER, Color(0, 0, 0, 0), 0, 0))
		t.set_stylebox("grabber_pressed", type, _flat(Kit.C_AMBER, Color(0, 0, 0, 0), 0, 0))

	# --- スライダー ---
	var track := _flat(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _flat(Kit.C_CAR, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Kit.C_AMBER, Color(0, 0, 0, 0), 0, 0))
	t.set_icon("grabber", "HSlider", _rect_icon(14, 24, Kit.C_TEXT, Color(0, 0, 0, 0)))
	t.set_icon("grabber_highlight", "HSlider", _rect_icon(14, 24, Kit.C_AMBER, Color(0, 0, 0, 0)))
	t.set_icon("grabber_disabled", "HSlider", _rect_icon(14, 24, Color(Kit.C_DIM, 0.5), Color(0, 0, 0, 0)))

	# --- チェック(印は 2 つの型で同じ物を使う) ---
	var checked := _rect_icon(22, 22, Kit.C_AMBER, Kit.C_AMBER, true)
	var unchecked := _rect_icon(22, 22, Color(0, 0, 0, 0), Kit.C_WALL)
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_stylebox("normal", type, _flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
		t.set_stylebox("hover", type, _flat(Color(Kit.C_AMBER, 0.12), Color(0, 0, 0, 0), 0, 6))
		t.set_stylebox("pressed", type, _flat(Color(Kit.C_AMBER, 0.12), Color(0, 0, 0, 0), 0, 6))
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_icon("checked", type, checked)
		t.set_icon("unchecked", type, unchecked)

	var err := ResourceSaver.save(t, OUT)
	print("THEME %s %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


# 傾いた板(ボタン)。左右の余白は傾いたぶん多めに取る。
static func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := _flat(bg, border, width, 24)
	s.skew = Vector2(Kit.SKEW, 0)
	s.content_margin_top = 4  # 字の高さだけでボタンが置いた高さより伸びないように
	s.content_margin_bottom = 4
	s.set_corner_radius_all(0)
	return s


# 選んでいる時の板。琥珀の縁と左の柱(太さ 8)。
static func _sel(fill: float) -> StyleBoxFlat:
	var s := _box(Kit.C_PANEL.lerp(Kit.C_AMBER, fill), Kit.C_AMBER, 2)  # 板の色に琥珀を混ぜた不透明の塗り
	s.border_width_left = 8
	return s


static func _flat(bg: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin / 2.0
	s.content_margin_bottom = margin / 2.0
	s.anti_aliasing = true
	return s


# 四角の印(チェックとスライダーのつまみ)。check なら中に濃い色の小さな四角。
static func _rect_icon(w: int, h: int, fill: Color, edge: Color, check: bool = false) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for x in w:
		for y in h:
			if x < 2 or y < 2 or x >= w - 2 or y >= h - 2:
				img.set_pixel(x, y, edge)
	if check:
		img.fill_rect(Rect2i(6, 6, w - 12, h - 12), Kit.C_BG)
	return ImageTexture.create_from_image(img)
