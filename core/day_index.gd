# 日付から通し日数と「今日のコース」を出す(仕様書 §9.7・D-10・共通 §3 の 13)。整数の計算だけ。乱数も種も使わない。
# 日付は ui が端末から取り、年・月・日の整数で渡す(core は時計を読まない)。通し日数の数え方は ParryDuel の core/day_index.gd と同じ。
extends RefCounted

const B := preload("res://core/balance.gd")


# 1970-01-01 からの通し日数(H. Hinnant の days_from_civil)。
@warning_ignore("integer_division")
static func days_from_civil(y: int, m: int, d: int) -> int:
	if m <= 2:
		y -= 1
	var era := (y if y >= 0 else y - 399) / 400
	var yoe := y - era * 400
	var mp := (m + 9) % 12
	var doy := (153 * mp + 2) / 5 + d - 1
	var doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468


# 2026-01-01 を 0 とする通し日数。それより前は 0(E-16)。
static func day_index(y: int, m: int, d: int) -> int:
	return maxi(days_from_civil(y, m, d) - days_from_civil(B.EPOCH_YEAR, 1, 1), 0)


# 今日のコース = (通し日数 × 7 + 3) % 15 + 1。1〜15(入門の 0 にはならない)。
static func today_course(day: int) -> int:
	return (maxi(day, 0) * B.DAY_MUL + B.DAY_ADD) % B.DAY_COURSES + 1


static func date_string(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]
