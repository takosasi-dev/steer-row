# 遊び以外の画面の背景(v0.3.0)。夜の舗装の上を横へ流れる速さの線と、上下のうす暗がり。_draw だけで描く(shader は使わない)。
# moving が偽(「点滅を弱める」が入)なら線を止める。16:9 でない窓の余りまで描く(舞台の外 −480〜+480)。
extends Control

const Kit := preload("res://ui/kit.gd")

const LINES := 28
const SPEED := 90.0  # 線の流れる速さ(px/秒。遠い線ほど遅い)

var moving := true
var t := 0.0
var _rows: Array = []  # [y, 長さ, 速さの倍率, x のずれ, 色]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	var seed := 11
	for k in LINES:
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var y := -180.0 + float(seed % 1080)
		seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
		var depth := 0.35 + float(seed % 650) / 1000.0
		var col := Kit.C_FLAG
		if k % 9 == 4:
			col = Kit.C_AMBER
		elif k % 7 == 2:
			col = Kit.C_CAR
		_rows.append([y, 80.0 + 260.0 * depth, depth, float((seed / 7) % 2240), col])


func _process(delta: float) -> void:
	if moving and is_visible_in_tree():
		t += delta
		queue_redraw()


func _draw() -> void:
	var span := 2240.0
	for r: Array in _rows:
		var depth: float = r[2]
		var x := fposmod(float(r[3]) - t * SPEED * depth * 2.0, span) - 480.0
		var col: Color = r[4]
		# 前(左)が濃く、後ろへ消える線(流れる向きが分かるように)
		draw_polyline_colors(PackedVector2Array([Vector2(x, r[0]), Vector2(x + float(r[1]), r[0])]),
			PackedColorArray([Color(col, 0.03 + 0.06 * depth), Color(col, 0.0)]), 2.0 + depth * 3.0)
	# 上と下のうす暗がり(真ん中の字を浮かせる)
	var top := Color(0, 0, 0, 0.45)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(-480, -480), Vector2(1760, -480), Vector2(1760, 110), Vector2(-480, 110)]), PackedColorArray([top, top, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(-480, 560), Vector2(1760, 560), Vector2(1760, 1200), Vector2(-480, 1200)]), PackedColorArray([clear, clear, top, top]))
