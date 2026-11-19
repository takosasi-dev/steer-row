"""Godot をヘッドレスで回す入口(取り込み・テスト・書き出し・スクリプト実行)。窓を出さず、音も出さない。
Godot の場所は環境変数 GODOT(無ければ PATH の godot)。user:// は build/appdata に分ける(環境変数 SR_APPDATA で変えられる)。

    python tools/gd.py import
    python tools/gd.py test [test_core ...]
    python tools/gd.py export
    python tools/gd.py run res://tools/perf.gd [引数 ...]
    python tools/gd.py smoke [フレーム数] [--auto など]
    python tools/gd.py smoke-pck [フレーム数]   書き出した build/web/index.pck を本体にして --auto で通す
"""

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "godot")
LAST_OUT = [b""]


def godot(args: list[str], timeout: int = 600, path: bool = True) -> int:
    env = dict(os.environ)
    # user:// を手元の本物と分ける(既定は build/appdata)
    appdata = Path(env.get("SR_APPDATA") or ROOT / "build" / "appdata")
    appdata.mkdir(parents=True, exist_ok=True)
    env["APPDATA"] = str(appdata)
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        done = subprocess.run([GODOT, "--headless", *(["--path", str(ROOT)] if path else []), *args], env=env, timeout=timeout, cwd=ROOT if path else ROOT / "build",
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=flags)
    except subprocess.TimeoutExpired as e:
        sys.stdout.buffer.write(e.stdout or b"")
        print(f"\n{timeout} 秒で終わらなかった(スクリプトの構文エラーで本体が立ち上がった時に起きる)")
        return 124
    sys.stdout.buffer.write(done.stdout)
    sys.stdout.flush()
    LAST_OUT[0] = done.stdout
    # テストが呼んだ先のスクリプトエラーは、ランナーからは見えない(その関数が黙って止まる)。出力で拾って失敗にする
    if b"SCRIPT ERROR" in done.stdout and done.returncode == 0:
        print("出力に SCRIPT ERROR がある")
        return 1
    return done.returncode


def smoke_ok(out: str) -> int:
    """--auto の出力を調べる。S0 → 結果を 3 回(3 回目は W A S D・回転なしで滑らせて壁に当てる)通して SMOKE done が出ていること。"""
    wild = re.findall(r"SMOKE view draws (\d+) skids (\d+) walls (\d+) rotate false controls wasd", out)
    problems = []
    if "SMOKE done" not in out or "SMOKE pause back" not in out:
        problems.append("SMOKE done が出ていない(どこかの画面で止まった)")
    if not wild or min(int(v) for v in wild[-1]) <= 0:
        problems.append(f"3 回目の走りで、描いた回数・タイヤの跡・壁の回数のどれかが 0: {wild}")
    for p in problems:
        print(p)
    return 1 if problems else 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    cmd, rest = sys.argv[1], sys.argv[2:]
    if cmd == "import":
        return godot(["--import"])
    if cmd == "test":
        return godot(["--script", "res://tests/run_tests.gd", "--", *rest], timeout=900)
    if cmd == "export":
        (ROOT / "build" / "web").mkdir(parents=True, exist_ok=True)
        return godot(["--export-release", "Web", "build/web/index.html"])
    if cmd in ("smoke", "smoke-pck"):  # 本体を窓なしで frames フレーム動かす。例: smoke 3000000 --auto
        frames = rest[0] if rest else "3000000"
        if cmd == "smoke-pck":  # 書き出した pck を本体にする(pck にコースが入っているかも見る)
            code = godot(["--main-pack", str(ROOT / "build" / "web" / "index.pck"), "--fixed-fps", "60", "--quit-after", frames, "--", "--auto"], path=False)
        else:
            code = godot(["--fixed-fps", "60", "--quit-after", frames, "--", *rest[1:]])
        if code == 0 and (cmd == "smoke-pck" or "--auto" in rest):
            return smoke_ok(LAST_OUT[0].decode("utf-8", errors="replace"))
        return code
    if cmd == "run" and rest:
        return godot(["--script", rest[0], "--", *rest[1:]])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
