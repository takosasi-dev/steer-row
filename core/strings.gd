# 文言(INV-7・画面設計書 §7)。画面に出す文字とコースの名前はすべてここに置く。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "SteerRow"
const VERSION := "v0.1.0"
const URL := "https://takosasi-dev.github.io/steer-row/"

# 10 キーの印字(§9.2。左から 0〜9)
const KEYS := ["A", "S", "D", "F", "G", "H", "J", "K", "L", ";"]

# コースの名前(0 が入門。courses/src の name と同じ)
const COURSE_NAMES := ["入門", "長い S 字", "ヘアピン", "大きな輪", "鍵の形", "稲妻", "二つの峠", "三日月", "階段", "波打ち際",
	"ひょうたん", "折り返し", "風車", "大回り", "細道", "総まとめ"]

# S0
const S0_START := "クリックかキーで始める"
const S0_KEYBOARD := "キーボードで遊ぶゲーム"
const TOUCH := "このゲームはキーボードで遊ぶ。PC で開いてほしい"
const IME := "日本語入力を切って(半角英数で)遊んでほしい"

# S1
const TAGLINE := "A が左いっぱい、; が右いっぱい。Space でブレーキ"
const B_INTRO := "入門コース"
const B_DAILY := "今日のコース"
const B_PICK := "コースを選ぶ"
const B_SETTINGS := "設定"
const COURSE_N := "コース %d"
const REC_FIRST := "1回目 %s"
const REC_TODAY_BEST := "今日の最高 %s"
const REC_NONE := "まだ走っていない"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"
const GHOSTS_CLEARED := "車の動きを直したので、幽霊を消した(タイムは残した)"

# S2
const ESC := "Esc"
const BAR_LAP := "周 %d/3"
const BAR_BEST_LAP := "最速の周 %s"
const GO := "スタート"
const LAP_NOTE := "%d 周 %s"
const FASTEST := "最速"
const GOAL := "ゴール"
const TIMEOUT := "時間切れ"
const HANDLE := "ハンドル"
const WASD_LEFT := "左"
const WASD_RIGHT := "右"
const WASD_BRAKE := "ブレーキ"

# S3
const RES_GOAL := "ゴール  %s"
const RES_NEW_BEST := "自己ベスト −%s(新しい記録)"
const RES_TO_BEST := "自己ベストまで +%s(自己ベスト %s)"
const RES_LAP := "%d 周 %s"
const RES_FASTEST := "(最速)"
const RES_WALLS := "壁 %d 回"
const GHOST_NEW := "幽霊を新しくした"
const B_RETRY := "もう1回"
const B_COPY := "コピー"
const B_TITLE := "タイトルへ"
const COPIED := "コピーを試した。貼れない時は枠から写す"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# 共有する文字(§9.11)
const SHARE_HEAD := "%s %s(%s)"
const SHARE_DAILY_FIRST := "今日のコース %d・1回目"
const SHARE_DAILY := "今日のコース %d"
const SHARE_INTRO := "入門コース"
const SHARE_BODY := "3 周 %s / 最速の周 %s / 壁 %d 回"

# S4
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const SET_ROTATE := "画面の回転"
const SET_CONTROLS := "操作"
const CONTROLS_ROW := "10 キー"
const CONTROLS_WASD := "W A S D"
const SET_ARROWS := "矢印のハンドル(デバッグ)"
const ON := "入"
const OFF := "切"
const B_KEYS := "キーの確かめ"
const B_BACK := "戻る"
const KEYS_HELP := "押されているキーが光る。Esc で戻る"
const KEY_DETAIL := "physical_keycode %d (%s) / key_label %s / unicode %d / pressed %s / echo %s / ctrl %s alt %s meta %s shift %s"

# S5
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"

# S6
const PICK_TITLE := "コースを選ぶ"
const TODAY := "今日"
const HAS_GHOST := "幽霊あり"
