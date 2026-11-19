# 人に見せる結果の文字(仕様書 §9.11・共通 §3 の 12)と、タイムの書き方(FR-11)。
# タイムは tick × 100 ÷ 120 の切り捨てを 1/100 秒とし「分:秒.百分の一」。
extends RefCounted

const S := preload("res://core/strings.gd")
const B := preload("res://core/balance.gd")

const INTRO := "intro"
const DAILY := "daily"
const PICK := "pick"


@warning_ignore("integer_division")
static func hundredths(ticks: int) -> int:
	return ticks * 100 / B.TICK_HZ


@warning_ignore("integer_division")
static func time_text(ticks: int) -> String:
	var h := hundredths(ticks)
	return "%d:%02d.%02d" % [h / 6000, (h / 100) % 60, h % 100]


# 差を「秒.百分の一」で(符号は付けない)。
@warning_ignore("integer_division")
static func diff_text(hundredths_diff: int) -> String:
	var h := absi(hundredths_diff)
	return "%d.%02d" % [h / 100, h % 100]


# entry: intro / daily / pick。first_today は今日のコースの 1 回目か。date は "2026-11-19"。
static func make(date: String, entry: String, course: int, first_today: bool, result: Dictionary) -> String:
	var label := S.COURSE_N % course
	if entry == INTRO:
		label = S.SHARE_INTRO
	elif entry == DAILY:
		label = S.SHARE_DAILY_FIRST % course if first_today else S.SHARE_DAILY % course
	var body := S.SHARE_BODY % [time_text(int(result["total_ticks"])), time_text(int(result["best_lap"])), int(result["walls"])]
	return "\n".join([S.SHARE_HEAD % [S.NAME, date, label], body, S.URL])
