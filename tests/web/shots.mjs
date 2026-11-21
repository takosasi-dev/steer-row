// 全部の画面を 5 つの大きさで撮る(UI の作り直しの前と後を比べる用)。画像は build/web_shots/<SR_SHOTS>/<画面>_<幅>x<高さ>.png。
// S0 → タイトル → 設定 → キーの確かめ → コースを選ぶ → 入門(ゆっくり。数え・走り・一時停止)→ 結果 → もう1回(速く。新しい記録)→ 結果。
//     SR_SHOTS=before node tests/web/shots.mjs     (既定は after)
import { mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { DESKTOP, OUT, driveWith, expect, failureCount, open, serve, sleep } from './lib.mjs';

const DIR = path.join(OUT, process.env.SR_SHOTS || 'after');
mkdirSync(DIR, { recursive: true });
const SIZES = [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]]; // 最後はスマホ(記録だけ)
const site = serve();
const page = await open(site.url + '?debug=1', { ...DESKTOP, width: 1280, height: 720 });

async function shootAll(name, wait = 250) {
	for (const [w, h] of SIZES) {
		await page.resize({ ...DESKTOP, width: w, height: h });
		await sleep(wait);
		const r = await page.cdp.send('Page.captureScreenshot', { format: 'png' });
		writeFileSync(path.join(DIR, `${name}_${w}x${h}.png`), Buffer.from(r.data, 'base64'));
	}
	await page.resize({ ...DESKTOP, width: 1280, height: 720 });
	await sleep(100);
}

try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	expect(!!(await page.waitState((s) => s.screen === 'gate', 30000)), 'S0');
	console.log(`    S0 が出るまで: ${Date.now() - page.t0} ms`);
	await sleep(400);
	await shootAll('s0_gate');
	await page.key('x');
	await sleep(110);
	await page.shot(path.join(path.basename(DIR), 'x_wipe_mid'));  // 切り替わりの帯の途中(1280×720 だけ)
	expect(!!(await page.waitState((s) => s.screen === 'title', 5000)), 'タイトル');
	await sleep(600);
	await shootAll('s1_title');
	// ボタンの状態: マウスを乗せる(選んだ印になる)・押したまま(pressed)
	const t = await page.state();
	const [px, py] = await page.gameCss(...t.buttons.pick);
	await page.cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: px, y: py });
	await sleep(200);
	await page.shot(path.join(path.basename(DIR), 'x_hover'));
	await page.cdp.send('Input.dispatchMouseEvent', { type: 'mousePressed', x: px, y: py, button: 'left', clickCount: 1 });
	await sleep(150);
	await page.shot(path.join(path.basename(DIR), 'x_pressed'));
	await page.cdp.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x: 5, y: 5, button: 'left' });
	await page.cdp.send('Input.dispatchMouseEvent', { type: 'mouseReleased', x: 5, y: 5, button: 'left', clickCount: 1 });
	await sleep(200);
	expect((await page.state()).screen === 'title', '外で離すと押さない');
	await page.key('ArrowUp'); await page.key('ArrowUp');  // 選んでいるのを一番上へ戻す(下の手順のため)
	await page.key('ArrowUp');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings', 3000)), '設定');
	await sleep(500);
	await shootAll('s4_settings');
	await page.key('ArrowUp');
	await page.key('ArrowUp');
	await page.key('Enter');
	await sleep(400);
	await page.down('f'); await page.down('g'); await page.down(' ');
	await shootAll('s4_keys');
	await page.up('f'); await page.up('g'); await page.up(' ');
	await page.key('Escape');
	await sleep(400);
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), '戻る');
	await sleep(500);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'pick', 3000)), 'コースを選ぶ');
	await sleep(500);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await sleep(300);
	await shootAll('s6_pick');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title', 3000);
	await sleep(500);
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'play', 4000)), '入門');
	await sleep(500);
	await shootAll('s2_count', 120);
	const want = { run: true, pause: true };
	await driveWith(page, {
		slow: 330,
		onState: async (s) => {
			const p = s.play;
			if (want.run && p.race_tick > 700) { want.run = false; await shootAll('s2_play', 120); }
			if (want.pause && p.race_tick > 1400) {
				want.pause = false;
				await page.key('Escape');
				await page.waitState((x) => x.paused, 2000);
				await sleep(500);
				await shootAll('s5_pause');
				await page.key('Escape');
				await page.waitState((x) => !x.paused, 2000);
			}
		},
	});
	expect(!!(await page.waitState((s) => s.screen === 'result', 8000)), '結果');
	await sleep(60);
	await page.shot(path.join(path.basename(DIR), 'x_result_disabled'));  // もう1回は 300 ms まで押せない(選んだまま)
	await sleep(2500);
	await shootAll('s3_result');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'play', 4000)), 'もう1回');
	let gap = false;
	await driveWith(page, {
		onState: async (s) => {
			if (!gap && s.play.race_tick > 430 && s.play.ghost !== null) { gap = true; await shootAll('s2_ghost', 80); }
		},
	});
	await page.waitState((s) => s.screen === 'play' && s.play.phase === 2, 2000);
	await sleep(200);
	await shootAll('s2_goal', 60);
	expect(!!(await page.waitState((s) => s.screen === 'result', 8000)), '結果(2 回目)');
	await sleep(2500);
	await shootAll('s3_result_best');
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? 'ALL OK' : `NG ${failureCount()} 件`);
process.exit(failureCount() === 0 ? 0 : 1);
