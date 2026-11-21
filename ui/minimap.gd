# 全体の小さな地図(画面設計書 §3。右上 180×180、北が上で回らない)。コースの輪郭、自分の点(三角)、幽霊の点(丸)。
# 幽霊が自分より前にいる間は、幽霊の点の色を変える(§9.10)。コースを選ぶ(S6)とタイトルの今日のコースの札にも使う(車なし)。
# framed が偽なら箱を描かない(札の中に置く時。v0.3.0)。
extends Control

const Kit := preload("res://ui/kit.gd")

var snap := {}
var framed := true
var _line := PackedVector2Array()
var _k := 1.0
var _off := Vector2.ZERO


func setup(points: Array, box_size: Vector2) -> void:
	size = box_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := Kit.fit(points, Rect2(Vector2.ZERO, box_size))
	_k = f[0]
	_off = f[1]
	_line = Kit.outline(points, _k, _off)
	queue_redraw()


func _draw() -> void:
	if framed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Kit.C_BG, 0.92))  # 下の道と幽霊が透けて見えないように
		draw_rect(Rect2(Vector2.ZERO, size), Color(Kit.C_WALL, 0.45), false, 1.0)
		for c: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), size]:  # 角の印(計器の枠)
			var dx := 12.0 if c.x == 0 else -12.0
			var dy := 12.0 if c.y == 0 else -12.0
			draw_line(c, c + Vector2(dx, 0), Kit.C_AMBER, 2.0)
			draw_line(c, c + Vector2(0, dy), Kit.C_AMBER, 2.0)
	if _line.size() > 1:
		draw_polyline(_line, Color(Kit.C_ROAD, 1.0), 7.0)
		draw_polyline(_line, Kit.C_WALL, 2.0)
	if snap.is_empty():
		if _line.size() > 4:  # コースを選ぶ・タイトルの地図: スタートの位置(市松)と走る向き
			var d := (_line[3] - _line[0]).normalized()
			var n := Vector2(-d.y, d.x)
			draw_line(_line[0] - n * 7.0, _line[0] + n * 7.0, Kit.C_FLAG, 3.0)
			draw_colored_polygon(PackedVector2Array([_line[0] + d * 14.0, _line[0] + d * 3.0 + n * 6.0, _line[0] + d * 3.0 - n * 6.0]), Kit.C_CAR)
		return
	var g: Variant = snap["ghost"]
	if g != null:
		var gp := Vector2(g["x"], g["y"]) * _k + _off
		draw_circle(gp, 6.5, Kit.C_BG)
		draw_circle(gp, 5.0, Kit.C_WARN if snap["ghost_ahead"] else Kit.C_GHOST)
	var c: Dictionary = snap["car"]
	var p := Vector2(c["x"], c["y"]) * _k + _off
	var h := Vector2(c["hx"], c["hy"])
	var r := Vector2(-h.y, h.x)
	var tri := PackedVector2Array([p + h * 10.0, p - h * 7.0 + r * 6.0, p - h * 7.0 - r * 6.0])
	draw_colored_polygon(tri, Kit.C_CAR)
	tri.append(tri[0])
	draw_polyline(tri, Kit.C_BG, 1.5)
