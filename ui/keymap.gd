# 物理キーをハンドルの番号(0〜9)とブレーキへ直す(仕様書 FR-2・§9.2・FR-27・FR-28)。配列の印字が違っても位置で決まる(physical_keycode)。
# 10 キー: A〜; が 0〜9、Space がブレーキ。W A S D: A が 0、D が 9、S と Space がブレーキ(W・F〜; は何もしない)。
# 矢印のハンドル(デバッグ版だけ): ← が 0、→ が 9。押されている組は ui/play.gd が押す・離すから持つ(共通 §3 の 5)。
extends RefCounted

const ROW := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON]


# ハンドルの番号(0〜9)。ほかは −1(E-1)。
static func index_of(pk: int, controls: String, arrows: bool = false) -> int:
	if arrows and pk == KEY_LEFT:
		return 0
	if arrows and pk == KEY_RIGHT:
		return 9
	if controls == "wasd":
		return 0 if pk == KEY_A else (9 if pk == KEY_D else -1)
	return ROW.find(pk)


static func is_brake(pk: int, controls: String) -> bool:
	return pk == KEY_SPACE or (controls == "wasd" and pk == KEY_S)


# 押されている物理キーの集まり → [10 キーの組(ビット), ブレーキ]。
static func input_of(held: Dictionary, controls: String, arrows: bool = false) -> Array:
	var bits := 0
	var brake := false
	for pk: int in held:
		var i := index_of(pk, controls, arrows)
		if i >= 0:
			bits |= 1 << i
		elif is_brake(pk, controls):
			brake = true
	return [bits, brake]


static func has_modifier(ev: InputEventKey) -> bool:
	return ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed
