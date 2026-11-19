# 入力の記録と再生(仕様書 §9.8)。毎 tick の入力(10 キーの組 + ブレーキのビット 10)を「値と、何 tick 続いたか」の対で持つ。
# 文字は「値-回数」を 36 進の小文字で書き、対を「,」でつなぐ(例: 0-2s,20-1k,0-a)。
# 記録は数えの間の tick から始める(数えの間に切ったハンドルも同じに再生するため。仕様の解釈)。
extends RefCounted

const MAX_VALUE := 2047
const DIGITS := "0123456789abcdefghijklmnopqrstuvwxyz"

var values := PackedInt32Array()
var counts := PackedInt32Array()
var _i := 0  # 再生の位置
var _used := 0  # 今の対で使った tick


func push(v: int) -> void:
	if not values.is_empty() and values[-1] == v:
		counts[-1] += 1
	else:
		values.append(v)
		counts.append(1)


func total() -> int:
	var t := 0
	for c in counts:
		t += c
	return t


# 次の tick の入力。尽きたら −1。
func next() -> int:
	if _i >= values.size():
		return -1
	var v := values[_i]
	_used += 1
	if _used >= counts[_i]:
		_i += 1
		_used = 0
	return v


func to_text() -> String:
	var parts := PackedStringArray()
	for k in values.size():
		parts.append(b36(values[k]) + "-" + b36(counts[k]))
	return ",".join(parts)


# 文字から読む。空・壊れている時は null(E-7)。
static func parse(text: String) -> Variant:
	if text.is_empty():
		return null
	var g := new()
	for part in text.split(","):
		var pair := part.split("-")
		if pair.size() != 2:
			return null
		var v := from_b36(pair[0])
		var c := from_b36(pair[1])
		if v < 0 or v > MAX_VALUE or c < 1:
			return null
		g.values.append(v)
		g.counts.append(c)
	return g


@warning_ignore("integer_division")
static func b36(v: int) -> String:
	if v == 0:
		return "0"
	var s := ""
	while v > 0:
		s = DIGITS[v % 36] + s
		v /= 36
	return s


# 36 進の小文字を整数に。読めなければ −1。
static func from_b36(s: String) -> int:
	if s.is_empty() or s.length() > 6:
		return -1
	var v := 0
	for ch in s:
		var d := DIGITS.find(ch)
		if d < 0:
			return -1
		v = v * 36 + d
	return v
