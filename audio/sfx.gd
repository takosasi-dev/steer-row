# 効果音の再生(仕様書 §9.10・FR-23)。assets/sfx/*.wav を読み、短い音はプレイヤーを順繰りに使って重ねて鳴らす。
# エンジンと滑る音はループ(engine の高さは速さで 0.8〜1.6)。音量 0 か、unlock() の前(最初のクリック・キーの前)なら鳴らさない。
# 読めないファイルは音なしで続ける。作りは KeyFlak の audio/sfx.gd。
extends Node

const NAMES: Array = ["engine", "drift", "go", "wall", "lap", "goal", "best", "timeout", "select"]
const LOOPS: Array = ["engine", "drift"]
const VOICES := 12

var volume := 75  # 0〜100
var unlocked := false
var played := 0  # 再生を始めた回数(テストが読む)

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _loops := {}  # 名前 → AudioStreamPlayer
var _next := 0
var _db := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound_name: String in NAMES:
		var path := "res://assets/sfx/" + sound_name + ".wav"
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_streams[sound_name] = stream
	for sound_name: String in LOOPS:
		var s: Variant = _streams.get(sound_name)
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		var p := AudioStreamPlayer.new()
		add_child(p)
		_loops[sound_name] = p
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	set_volume(volume)


func unlock() -> void:
	unlocked = true


# 25〜100 は 2 乗で dB に直す(100 → 0 dB、75 → −5 dB、50 → −12 dB、25 → −24 dB)。0 は鳴らさない。
func set_volume(percent: int) -> void:
	volume = clampi(percent, 0, 100)
	_db = linear_to_db(pow(volume / 100.0, 2.0)) if volume > 0 else -80.0
	for voice in _voices:
		voice.volume_db = _db
	if volume <= 0:
		stop_loops()


# 短い音を鳴らす。gain は 0〜1 の大きさ(壁の音を外向きの速さで変える)。
func play(sound_name: String, gain: float = 1.0) -> void:
	if not unlocked or volume <= 0 or not _streams.has(sound_name):
		return
	var voice := _voices[_next]
	_next = (_next + 1) % VOICES
	voice.stream = _streams[sound_name]
	voice.volume_db = _db + linear_to_db(clampf(gain, 0.05, 1.0))
	voice.play()
	played += 1


# ループの音を鳴らし続ける・止める。pitch は高さ。
func loop(sound_name: String, on: bool, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = _loops.get(sound_name)
	if p == null:
		return
	if not on or not unlocked or volume <= 0 or not _streams.has(sound_name):
		if p.playing:
			p.stop()
		return
	p.volume_db = _db - 8.0  # 鳴り続ける音は短い音より小さく
	p.pitch_scale = pitch
	if not p.playing:
		p.stream = _streams[sound_name]
		p.play()
		played += 1


func stop_loops() -> void:
	for p: AudioStreamPlayer in _loops.values():
		p.stop()
