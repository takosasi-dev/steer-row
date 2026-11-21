// Web 版をまとめて確かめて、画面を撮る(Chrome 1 回の起動で済ませる)。全部の画像は build/web_shots/。
// S0 → タイトル → 設定 → キーの確かめ → 入門を本物のキーで走る(中心 bot の押し方を ?debug=1 の状態から読み、CDP で押さえる・離す)
// → 一時停止 → 結果 → もう1回(ゆっくり走り、幽霊を先に行かせる。幽霊の最後の位置を見る)→ コースを選ぶ → W A S D・回転なしで壁に当てる
// → 開き直して保存を読む → 読み込みの後の通信 0 件。R-4: 1 回目の記録をヘッドレスで再生した最後の位置と、ブラウザの位置・幽霊の位置を比べる。
//     node tests/web/check.mjs                       手元の build/web を配って確かめる(先に python tools/gd.py export)
//     SR_URL=https://…/steer-row/ node tests/web/check.mjs   公開した物を確かめる
//     SR_QUICK=1 …                                    3 分の通信の見張りを短くする(撮り直しの時)
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { DESKTOP, ROOT, driveWith, expect, failureCount, open, serve, sleep } from './lib.mjs';

const ROW = 'asdfghjkl;';
const site = serve();
const page = await open(site.url + '?debug=1', DESKTOP);

const drive = (opts) => driveWith(page, opts);

// 画面の回転の滑らかさ: 1 回の走りの見本から、カメラの回る速さの最大(度/秒)と、車の向きとの遅れの最大(度)
function rotation(samples) {
	let maxRate = 0, maxLag = 0;
	const wrap = (a) => Math.atan2(Math.sin(a), Math.cos(a));
	for (let k = 1; k < samples.length; k++) {
		const a = samples[k - 1], b = samples[k];
		const dt = (b.t - a.t) / 1000;
		if (dt > 0.005) maxRate = Math.max(maxRate, Math.abs(wrap(b.cam - a.cam)) / dt);
		maxLag = Math.max(maxLag, Math.abs(wrap(-Math.PI / 2 - b.head - b.cam)));
	}
	return { maxRate: Math.round(maxRate * 180 / Math.PI), maxLag: Math.round(maxLag * 180 / Math.PI) };
}

function replayHeadless(course, record) {
	const dir = mkdtempSync(path.join(tmpdir(), 'sr-rec-'));
	const file = path.join(dir, 'record.txt');
	writeFileSync(file, record);
	const py = process.env.SR_PYTHON || 'python';
	const out = execFileSync(py, [path.join(ROOT, 'tools', 'gd.py'), 'run', 'res://tools/replay.gd', `course=${course}`, `file=${file}`],
		{ encoding: 'utf8', env: { ...process.env, PYTHONIOENCODING: 'utf-8' } });
	rmSync(dir, { recursive: true, force: true });
	const m = out.match(/REPLAY (\d+) \/ (\S+) \/ (\d+)/);
	return m ? { ticks: Number(m[1]), pos: m[2], walls: Number(m[3]) } : { out };
}

const dist = (a, b) => { const [ax, ay] = a.split(',').map(Number); const [bx, by] = b.split(',').map(Number); return Math.hypot(ax - bx, ay - by); };

try {
	expect(page.booted, `起動した(${page.bootMs} ms)`);
	const g = await page.waitState((s) => s.screen === 'gate', 30000);
	expect(!!g, 'S0 が出る');
	console.log(`    S0 が出るまで: ${Date.now() - page.t0} ms(ページを開いてから)`);
	await sleep(300);
	await page.shot('s0_gate');
	await page.key('x');
	const t = await page.waitState((s) => s.screen === 'title', 5000);
	expect(!!t && t.unlocked, 'キーで S1 タイトルへ(音の鍵が開く)');
	const loadedAt = Date.now();
	await sleep(300);
	await page.shot('s1_title_first');

	// 設定 → キーの確かめ(隣り合う 2 キーと Space を同時に押さえる)
	expect(await page.clickButton('settings'), '設定を押す');
	expect(!!(await page.waitState((s) => s.screen === 'settings')), 'S4 設定');
	await sleep(200);
	await page.shot('s4_settings');
	await page.clickButton('keys');
	await sleep(200);
	await page.down('f'); await page.down('g'); await page.down(' ');
	await sleep(200);
	await page.shot('s4_keys_fg_space');
	await page.up('f'); await page.up('g'); await page.up(' ');
	await page.key('Escape');
	await sleep(100);
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), '設定から戻る');

	// 入門(1 回目): 本物のキーで走る
	await page.key('Enter');
	const p0 = await page.waitState((s) => s.screen === 'play', 3000);
	expect(!!p0, 'Enter で入門コース(一番上)');
	await sleep(250);
	await page.shot('s2_count_3');
	// 数えの間に、隣り合う 2 キー(F と G)と Space を本物のキーで押さえる: 目標は平均の −2/9、ブレーキは真(E-9 で数えの間もハンドルは回る)
	await page.down('f'); await page.down('g'); await page.down(' ');
	const fg = await page.waitState((s) => s.play.keys === ((1 << 3) | (1 << 4)) && s.play.brake, 2000);
	expect(fg && Math.abs(fg.play.target - (-2 / 9)) < 1e-9, `F と G で目標 −2/9・Space でブレーキ: ${fg?.play.target} / ${fg?.play.brake}`);
	await sleep(150);
	await page.shot('s2_count_fg_space');
	await page.up('f'); await page.up('g'); await page.up(' ');
	const want = { go: true, mid: true, lap: true, pause: true, curve: true, drift: true, wall: true };
	let lapSeen = 0;
	const r1 = await drive({
		jolt: 3500,
		onState: async (s) => {
			const p = s.play;
			if (want.drift && p.car.drift && p.race_tick > 400) { want.drift = false; await sleep(80); await page.shot('s2_drift'); }
			if (want.wall && p.walls > 0) { want.wall = false; await page.shot('s2_wall_hit'); }
			if (want.go && p.phase === 1 && p.race_tick > 5) { want.go = false; await page.shot('s2_go'); }
			if (want.mid && p.race_tick > 300 && p.car.speed > 400) { want.mid = false; await page.shot('s2_straight_fast'); }
			if (want.curve && p.race_tick > 900 && Math.abs(p.car.wheel) > 0.3) { want.curve = false; await page.shot('s2_curve'); }
			if (p.lap > 1 && lapSeen < p.lap - 1) { lapSeen = p.lap - 1; if (want.lap) { want.lap = false; await sleep(120); await page.shot('s2_lap_note'); } }
			if (want.pause && p.race_tick > 1500) {
				want.pause = false;
				await page.key('Escape');
				const ps = await page.waitState((x) => x.paused, 2000);
				expect(!!ps, 'Esc で一時停止');
				const tk = ps.play.race_tick;
				await sleep(500);
				await page.shot('s5_pause');
				expect((await page.state()).play.race_tick === tk, '一時停止の間は進まない');
				await page.key('Escape');
				expect(!!(await page.waitState((x) => !x.paused, 2000)), 'Esc で続ける');
			}
		},
	});
	const rot1 = rotation(r1.samples);
	console.log(`    画面の回転(入): カメラの回る速さの最大 ${rot1.maxRate} 度/秒、車の向きとの遅れの最大 ${rot1.maxLag} 度`);
	await page.shot('s2_goal');
	const res1 = await page.waitState((s) => s.screen === 'result', 5000);
	expect(!!res1, 'S3 結果');
	await sleep(400);
	await page.shot('s3_result_first');
	const run1 = res1.last_run;
	expect(run1.ticks > 0 && run1.walls > 0 && !want.drift, `1 回目(ときどき ; を押し込む): ${run1.ticks} tick / 壁 ${run1.walls} 回 / 滑った ${!want.drift} / 最後の位置 ${run1.pos}`);
	const saved = await page.saved();
	expect(saved?.courses?.['0']?.ghost === run1.record, '保存の幽霊がこの走りの記録になる(steer-row/save)');

	// R-4: 同じ記録をヘッドレスで再生
	const h = replayHeadless(0, run1.record);
	console.log(`    R-4 ヘッドレスの再生: ${JSON.stringify(h)}`);
	expect(h.pos && dist(h.pos, run1.pos) < 1 && h.ticks === run1.ticks && h.walls === run1.walls,
		`R-4 ブラウザの走りとヘッドレスの再生の最後の位置の差 ${h.pos ? dist(h.pos, run1.pos).toFixed(6) : '?'} px(1 px 未満で合格)`);

	// もう1回: ゆっくり走って幽霊を先に行かせる
	await page.key('Enter');
	const p2 = await page.waitState((s) => s.screen === 'play', 3000);
	expect(!!p2 && p2.play.ghost !== null, 'もう1回(Enter)。幽霊が出る');
	const want2 = { ghost: true, ahead: true, hide: true };
	const r2 = await drive({
		slow: 330,
		onState: async (s) => {
			const p = s.play;
			if (want2.hide && p.race_tick > 1500) {
				// タブが裏に回ると一時停止(E-10)。戻っても自動では再開しない。押していたキーは離したことになる(E-11)
				want2.hide = false;
				await page.hide();
				await sleep(600);
				await page.show();
				const hid = await page.waitState((x) => x.paused, 5000);
				expect(!!hid && hid.play.held === 0, `タブが裏に回ると一時停止し、押していたキーは離したことになる: held ${hid?.play.held}`);
				const tk = (await page.state()).play.race_tick;
				await sleep(600);
				expect((await page.state()).play.race_tick === tk, '戻っても止まったまま');
				for (const k of ROW + ' ') await page.up(k);
				await page.key('Escape');
				expect(!!(await page.waitState((x) => !x.paused, 3000)), 'Esc で続ける');
				return 'reset';
			}
			if (want2.ghost && p.race_tick > 200 && p.race_tick < 400) { want2.ghost = false; await page.shot('s2_ghost_near'); }
			if (want2.ahead && p.ghost_ahead && p.race_tick > 900) { want2.ahead = false; await page.shot('s2_ghost_ahead'); }
		},
	});
	const res2 = await page.waitState((s) => s.screen === 'result', 5000);
	await sleep(400);
	await page.shot('s3_result_second');
	const run2 = res2?.last_run ?? {};
	expect(run2.ghost_done === true && dist(run2.ghost_pos, run1.pos) < 1,
		`R-4 ブラウザの幽霊の最後の位置 ${run2.ghost_pos} と 1 回目の位置 ${run1.pos} の差 ${run2.ghost_pos ? dist(run2.ghost_pos, run1.pos).toFixed(6) : '?'} px`);

	// コピー
	await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
	await page.key('ArrowDown');
	await page.key('Enter');  // コピー(結果の並びは もう1回・コピー・タイトルへ)
	await sleep(400);
	const c1 = await page.clipboard();
	expect(c1.startsWith('SteerRow '), `コピーのボタン: ${JSON.stringify(c1).slice(0, 90)}`);
	await page.shot('s3_copied');

	// 3 回目: 押し込みも減速も無しで走る。1 回目(押し込みあり)の幽霊より速いので、緑の「幽霊 −…」と「新しい記録」が出る
	await page.key('ArrowUp');
	await page.key('Enter');  // もう1回
	expect(!!(await page.waitState((s) => s.screen === 'play', 3000)), '↑ Enter でもう1回');
	const want3 = { ahead: true, goal: true };
	await drive({
		onState: async (s) => {
			const p = s.play;
			if (want3.ahead && p.race_tick > 2400 && p.gap.startsWith('幽霊 −')) { want3.ahead = false; await page.shot('s2_ghost_behind_me'); }
		},
	});
	const g3 = await page.waitState((s) => s.screen === 'play' && s.play.phase === 2, 2000);
	await page.shot('s2_goal_new_best');
	expect(!want3.ahead, '幽霊より前を走ると「幽霊 −…」が出る');
	const res3 = await page.waitState((s) => s.screen === 'result', 5000);
	await sleep(400);
	await page.shot('s3_result_new_best');
	expect(!!res3 && res3.last_run.ticks < run1.ticks, `3 回目は 1 回目より速い: ${res3?.last_run.ticks} < ${run1.ticks}(${g3 ? 'ゴールの字を撮った' : ''})`);

	// ここからはキーボードだけ(AC-18 の S1 → S6 → S2): タイトルへ → コースを選ぶ → 各コース → 今日のコース → 設定 → コース 2
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), '↓↓ Enter でタイトルへ');
	await sleep(300);
	await page.shot('s1_title_after_intro');
	await page.down('j'); await page.down('k');
	await sleep(400);
	await page.shot('s1_title_keys');
	await page.up('j'); await page.up('k');
	// コース 1〜14 を S6 から順に開き、走り始めて 1 枚撮る(道の飾りが全部のコースで描けるか)
	for (let k = 1; k <= 14; k++) {
		await page.key('ArrowDown');
		await page.key('Enter');
		await page.waitState((s) => s.screen === 'pick', 3000);
		for (let d = 0; d < k; d++) await page.key('ArrowDown');
		await page.key('Enter');
		const pk = await page.waitState((s) => s.screen === 'play' && s.play.race_tick > 150, 8000);
		expect(!!pk, `コース ${k} を開いて走り始める`);
		await page.shot(`s2_course_${String(k).padStart(2, '0')}`);
		await page.key('Escape');
		await page.waitState((s) => s.paused, 2000);
		for (let d = 0; d < 3; d++) await page.key('ArrowDown');
		await page.key('Enter');
		await page.waitState((s) => s.screen === 'title', 3000);
	}
	// 今日のコース(タイトルの一番上)を走り切る
	await page.key('Enter');
	const dl = await page.waitState((s) => s.screen === 'play', 3000);
	expect(!!dl, 'Enter で今日のコース');
	await sleep(300);
	await page.shot('s2_daily_start');
	await drive({ timeoutMs: 180000 });
	const resd = await page.waitState((s) => s.screen === 'result', 8000);
	await sleep(400);
	await page.shot('s3_result_daily');
	expect(!!resd && resd.share.includes('今日のコース') && resd.share.includes('1回目'), `今日のコースの共有の文字: ${JSON.stringify(resd?.share).slice(0, 80)}`);
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'title', 3000);
	await sleep(300);
	await page.shot('s1_title_daily_record');
	// 設定: 揺れ=切・点滅を弱める=入・画面の回転=切・操作=W A S D(NFR-12 の画像)
	await page.key('ArrowUp');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings', 3000)), '↑ Enter で設定');
	for (let k = 0; k < 4; k++) { await page.key('ArrowDown'); await page.key('Enter'); }
	const st = (await page.waitState((x) => x.settings.controls === 'wasd', 2000) ?? await page.state()).settings;  // 状態は次の描画で書き直される
	expect(st.shake === false && st.reduce_flash === true && st.rotate === false && st.controls === 'wasd', `キーで設定を変える: ${JSON.stringify(st)}`);
	await sleep(200);
	await page.shot('s4_settings_changed');
	await page.key('Escape');
	await page.waitState((s) => s.screen === 'title', 3000);
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'pick', 3000)), '↓ Enter でコースを選ぶ');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await sleep(200);
	await page.shot('s6_pick');
	await page.key('Enter');
	const c2 = await page.waitState((s) => s.screen === 'play', 3000);
	expect(!!c2 && c2.last_run !== undefined, 'Enter でコース 2 を走る(キーボードだけで S1 → S6 → S2)');
	await page.waitState((s) => s.play.race_tick > 360, 10000);
	await page.down('d');
	const hit = await page.waitState((s) => s.play.walls > 0, 8000);
	expect(!!hit, 'W A S D の D で右いっぱい → 壁に当たる');
	await page.shot('s2_wall_reduced');
	let still = true;
	for (let k = 0; k < 6; k++) { const x = await page.state(); still = still && x.play.shake[0] === 0 && x.play.shake[1] === 0; await sleep(20); }
	expect(still, '揺れを切ると、壁に当たっても画面の位置が動かない');
	await page.up('d');
	await page.key('Escape');
	await page.waitState((s) => s.paused, 2000);
	await page.key('ArrowDown'); await page.key('ArrowDown'); await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), '一時停止からタイトルへ(キーボード)');

	// 読み込みの後 3 分の通信(AC-21)
	const watch = process.env.SR_QUICK ? 5000 : 180000;
	const left = loadedAt + watch - Date.now();
	if (left > 0) await sleep(left);
	const after = page.requests.filter((r) => r.at > loadedAt);
	expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));
	console.log('    押してから帯を描き終わるまで・1 フレーム(ms): ' + JSON.stringify(await page.stats()));

	// 開き直す(同じプロフィール): 保存を読み戻す
	await page.evaluate(`localStorage.setItem('parry-duel/save', '{"keep":1}')`);
	expect(await page.goto(page.url0), '同じプロフィールで開き直す');
	await page.waitState((s) => s.screen === 'gate', 30000);
	await page.key('x');
	const t2 = await page.waitState((s) => s.screen === 'title', 5000);
	expect(t2?.settings?.controls === 'wasd' && t2?.settings?.rotate === false, `設定が残る: ${JSON.stringify(t2?.settings)}`);
	expect(!!t2?.buttons?.daily && (await page.saved())?.intro_done === true, '入門を走り切った後は今日のコースが一番上');
	expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"keep":1}', 'ParryDuel の保存を消さない');
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).join(' | ').slice(0, 400) : ''));
} finally {
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? 'ALL OK' : `NG ${failureCount()} 件`);
process.exit(failureCount() === 0 ? 0 : 1);
