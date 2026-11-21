"""効果音 10 個(仕様書 §9.10 の 9 個と、v0.3.0 で足したメニューの決めた音)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ。
雑音は決まった式の擬似乱数で作る(何度回しても同じバイト列)。16bit PCM・モノラル・22050 Hz。合計 400 KB 以下(NFR-7)。
engine と drift はループで鳴らす(audio/sfx.gd がループに設定する)ので、端がつながる長さにしてある。作りは KeyFlak の tools/gen_sfx.py。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def _pad(buf, n):
    while len(buf) < n:
        buf.append(0.0)


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False, attack=0.001, fade=True):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    _pad(buf, start + n)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        e = gain * math.exp(-decay * t)
        if fade:
            e *= min(1.0, (n - i) / (0.004 * RATE), i / (attack * RATE))
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += e * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def noise(buf, at, dur, gain=1.0, decay=0.0, smooth=0.0, fade=True):
    """雑音を buf に足す(線形合同法。smooth が大きいほど低い音)。"""
    start = int(at * RATE)
    n = int(dur * RATE)
    _pad(buf, start + n)
    x = 12345
    prev = 0.0
    for i in range(n):
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        v = x / 0x3FFFFFFF - 1.0
        prev = prev * smooth + v * (1.0 - smooth)
        t = i / RATE
        e = gain * math.exp(-decay * t)
        if fade:
            e *= min(1.0, (n - i) / (0.004 * RATE))
        buf[start + i] += e * prev


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    # エンジン: 90 Hz の唸り(0.2 秒 = 18 周期でちょうど端がつながる)
    tone(b, 0, 0.2, 90, square=True, fade=False)
    tone(b, 0, 0.2, 180, gain=0.3, fade=False)
    write("engine", b, 0.35)
    b = []
    noise(b, 0, 0.5, smooth=0.75, fade=False)  # 滑る音: こすれる雑音(ループ)
    write("drift", b, 0.3)
    b = []
    tone(b, 0, 0.35, 1320, decay=6)  # スタート: 高い音
    write("go", b, 0.5)
    b = []
    noise(b, 0, 0.18, decay=20, smooth=0.85)
    tone(b, 0, 0.15, 140, 60, gain=0.8, decay=18)  # 壁: 鈍い当たり
    write("wall", b, 0.7)
    b = []
    tone(b, 0, 0.12, 880, decay=10)
    tone(b, 0.1, 0.25, 1175, decay=8)  # 周: 2 音
    write("lap", b, 0.5)
    b = []
    for k, f in enumerate([523, 659, 784, 1047]):
        tone(b, k * 0.09, 0.35, f, decay=6)  # ゴール: 上がる 4 音
    write("goal", b, 0.55)
    b = []
    for k, f in enumerate([523, 659, 784, 1047, 1319, 1568]):
        tone(b, k * 0.08, 0.45, f, decay=5)  # 自己ベストのゴール: もっと上がる 6 音
    write("best", b, 0.55)
    b = []
    tone(b, 0, 0.6, 220, square=True, decay=3)  # 時間切れ: 平らな音
    write("timeout", b, 0.45)
    b = []
    tone(b, 0, 0.04, 1200, 1400, decay=30)  # メニューの選択
    write("select", b, 0.35)
    b = []
    tone(b, 0, 0.05, 900, decay=25)
    tone(b, 0.035, 0.09, 1350, decay=22)  # メニューで決めた: 短い 2 音(v0.3.0)
    write("ok", b, 0.35)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()
