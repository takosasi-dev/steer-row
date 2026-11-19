# 押しているキーの組 → ハンドルの目標(仕様書 §9.2・D-1)。A(ビット 0)が −1、;(ビット 9)が +1、等間隔。
# 複数押しは目盛りの平均、何も押していなければ 0。整数の和を 1 回だけ割るので、同じ組なら同じ値になる。
extends RefCounted

const KEYS := 10
const KEY_MASK := (1 << KEYS) - 1
const BRAKE_BIT := 1 << KEYS  # 記録の 11 ビット目(§9.8)


static func target(keys: int) -> float:
	var sum := 0
	var count := 0
	for i in KEYS:
		if keys & (1 << i):
			sum += 2 * i - 9
			count += 1
	if count == 0:
		return 0.0
	return float(sum) / (9.0 * count)


# 目盛り (2i − 9) ÷ 9。
static func scale(i: int) -> float:
	return float(2 * i - 9) / 9.0
