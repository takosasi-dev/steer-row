# 調整値(仕様書 §9.9・INV-7)。ゲームの数値はすべてここに置く。車の動きが変わる値を変えたら PHYSICS_VERSION を 1 上げる。
# 値は仕様の初期値のまま(人が走って決めた値ではない。§8.2 は未記入)。画面の大きさ・色の時間など ui の値もここに置く。
extends RefCounted

# 時間
const TICK_HZ := 120
const DT := 1.0 / 120.0
const MAX_STEPS_PER_FRAME := 8

# ハンドル・車(§9.4)
const WHEEL_RATE := 6.0
const V_MAX := 520.0
const ACCEL := 260.0
const BRAKE := 700.0
const YAW_MAX := 2.6
const TURN_FULL_SPEED := 200.0
const MIN_TURN := 0.3
const GRIP := 6.0
const GRIP_DRIFT := 2.5
const DRIFT_WHEEL := 0.7
const DRIFT_SPEED := 380.0
const WALL_KEEP := 0.6
const CAR_R := 10.0
const EPS := 1e-9  # 目標や上限に届いたとみなす差(足し算の丸めで 1 tick 遅れないように)

# コース(§9.5・§9.6)
const POINT_STEP := 8.0
const SEARCH := 24
const MIN_RADIUS := 120.0
const GATES := 8  # 関門は k × N ÷ 8(k = 1〜7)

# 走り(§9.3)
const COUNTDOWN_TICKS := 180
const LAPS := 3
const RACE_LIMIT_TICKS := 36000
const PHYSICS_VERSION := 1
const COURSES := 16
const INTRO := 0

# 今日のコース(§9.7・共通 §3 の 13)
const EPOCH_YEAR := 2026
const DAY_MUL := 7
const DAY_ADD := 3
const DAY_COURSES := 15

# bot(§9.13)
const BOT_AHEAD := 12
const BOT_GAIN := 3.0
const BOT_LOOK := 40
const BOT_BRAKE_DOT := 0.8  # 今の向きと 40 点先の向きの内積がこれ未満なら「向きの変わり方が大きい」
const BOT_BRAKE_SPEED := 300.0

# 画面(§9.1・画面設計書)
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const CAM_ZOOM := 0.75
const CAM_RATE := 6.0
const CAR_SCREEN_Y := 540.0
const CAR_SCREEN_Y_FIXED := 360.0  # 画面の回転を切った時は車を真ん中に置く(仕様に無いので決めた値)
const CAR_LEN := 28.0
const CAR_WIDTH := 14.0
const SKID_MAX := 400
const WALL_FLASH_MS := 200
const REDUCED_FLASH_ALPHA := 0.2
const SHAKE_SPEED := 200.0
const SHAKE_PX := 5.0
const SHAKE_MS := 120
const COUNT_STEP_TICKS := 60  # 3・2・1 は各 0.5 秒
const GO_MS := 500
const LAP_NOTE_MS := 1000
const OVER_MS := 600
const RETRY_LOCK_MS := 300
const IME_NOTE_MS := 3000
const ENGINE_PITCH_MIN := 0.8
const ENGINE_PITCH_MAX := 1.6
const WALL_SOUND_FULL := 400.0  # この外向きの速さで当たる音が一番大きい

# 設定(共通 §3 の 17)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75
