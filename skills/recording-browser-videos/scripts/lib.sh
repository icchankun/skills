# shellcheck shell=bash
# ブラウザの操作を動画に撮るスクリプトから source する（record-scenes.sh が読み込む）。
# 使い方: media=<置き場所>; session=<セッション名>; source lib.sh
#         場面ごとの steps で zoom・click_on・type_text・expect_text などを並べる

# playwright-cli の出力は $log（既定は $media/record.log）に残す。捨てると、失敗したときに止まった理由が分からない
P() {
  local out="${log:-$media/record.log}"
  playwright-cli -s="$session" "$@" >>"$out" 2>&1 && return
  echo "失敗: playwright-cli $1（詳しくは ${out}）" >&2
  tail -n 20 "$out" >&2
  return 1
}

# カーソル・押した印・見出し・スポットライトは decor.js に置く（どの動画でも見た目を同じにするため）
_DECOR_JS="$(cat "$(dirname "${BASH_SOURCE[0]}")/decor.js")"

# 録画の見せ方をまとめて設定する。playwright の飾り（枠・操作の名前・カーソル）はどれも出さない。
# 押す場所の目印は click_on が、カーソルと同時に1回だけ出す（理由は SKILL.md）
show_actions() {
  P run-code "async page => {
    await page.screencast.showActions({ cursor: 'none', duration: 1, style: { title: 'display: none' } });
    // ページを移っても部品が出るよう、読み込むたびに走らせる
    await page.addInitScript($_DECOR_JS);
    await page.evaluate($_DECOR_JS);
  }"
}

_json() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

# 今の場面の題を、画面の右上にずっと出す。動画の再生バーで隠れないよう、下には置かない。ページを移っても出し直す
heading() {
  P run-code "async page => { await page.evaluate((t) => window.__mcHeading(t), $(_json "$1")); }"
}

# 対象を画面の中央に寄せて拡大する。倍率は、対象が画面の8割に収まる大きさ（2倍まで）にする。
# 画面の外が見えないよう、端では寄せきらない
zoom() {
  P run-code "async page => {
    const r = await page.locator($(_json "$1")).first().boundingBox();
    await page.evaluate(([x, y, rw, rh, given]) => {
      const w = innerWidth, h = innerHeight;
      const s = given || Math.max(1, Math.min(2, 0.8 * w / rw, 0.8 * h / rh));
      const cx = x + rw / 2, cy = y + rh / 2;
      const tx = Math.min(0, Math.max(w - w * s, w / 2 - cx * s));
      const ty = Math.min(0, Math.max(h - h * s, h / 2 - cy * s));
      const b = document.body;
      b.dataset.manualCheckTransform ??= b.style.transform;
      b.style.transformOrigin = '0 0';
      b.style.transition = 'transform .5s cubic-bezier(.65,0,.35,1)';
      b.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + s + ')';
    }, [r.x, r.y, r.width, r.height, ${2:-0}]);
    await page.waitForTimeout(520);
  }"
}

unzoom() {
  P run-code "async page => {
    await page.evaluate(() => { const b = document.body; b.style.transform = b.dataset.manualCheckTransform ?? ''; });
    await page.waitForTimeout(300);
  }"
}

# 結果が見えるまで少し止める
hold() { P run-code "async page => { await page.waitForTimeout(${1:-700}); }"; }

# 次の場面の札（画面をぼかした上に、題と添え書き）を出し、右上の見出しも差し替える。
# 録画を始める前に呼び、動画が札から始まるようにする。番号は出さない。場面の順番が変わったときに食い違うため
card_show() {
  P run-code "async page => {
    await page.evaluate(([t, d]) => {
      let o = document.getElementById('__manual_check_card');
      if (!o) {
        o = document.createElement('div');
        o.id = '__manual_check_card';
        o.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;background:rgba(15,23,42,.35);backdrop-filter:blur(8px) saturate(.9);-webkit-backdrop-filter:blur(8px);font-family:-apple-system,sans-serif;transition:opacity .25s ease;pointer-events:none';
        document.documentElement.appendChild(o);
      }
      o.innerHTML = '';
      const panel = document.createElement('div');
      panel.style.cssText = 'min-width:420px;max-width:70%;padding:28px 36px;border-radius:18px;background:rgba(255,255,255,.92);box-shadow:0 20px 60px rgba(15,23,42,.25);display:flex;flex-direction:column;gap:12px;transform:translateY(14px) scale(.97);opacity:0;transition:transform .4s cubic-bezier(.22,1,.36,1),opacity .3s ease';
      const h = document.createElement('div'); h.style.cssText = 'font:700 28px/1.35 -apple-system,sans-serif;color:#0f172a'; h.textContent = t;
      const e = document.createElement('div'); e.style.cssText = 'font:500 18px/1.5 -apple-system,sans-serif;color:#475569'; e.textContent = d;
      panel.append(h, e);
      o.append(panel);
      o.style.opacity = '1';
      requestAnimationFrame(() => requestAnimationFrame(() => { panel.style.transform = 'none'; panel.style.opacity = '1'; }));
      window.__mcHeading(t);
    }, [$(_json "$1"), $(_json "$2")]);
  }"
}

# 札を見せてから消す。録画を始めた直後に呼ぶ
card_hide() {
  P run-code "async page => {
    await page.waitForTimeout(${1:-900});
    await page.evaluate(() => {
      const o = document.getElementById('__manual_check_card');
      const panel = o.firstElementChild;
      panel.style.transform = 'translateY(-10px) scale(.98)'; panel.style.opacity = '0';
      o.style.opacity = '0';
    });
    await page.waitForTimeout(280);
  }"
}

# 対象を（必要ならスクロールして）見える所に出し、スポットライトを当ててカーソルを動かす。操作の前に呼ぶ部品
_FOCUS='const r0 = await l.boundingBox();
    if (!r0 || r0.y < 0 || r0.y + r0.height > page.viewportSize().height) {
      await l.evaluate((el) => el.scrollIntoView({ behavior: `smooth`, block: `center` }));
      await page.waitForTimeout(500);
    }
    const r = await l.boundingBox();
    await page.evaluate(([x, y, w, h]) => window.__mcSpot(x, y, w, h), [r.x, r.y, r.width, r.height]);
    await page.mouse.move(r.x + r.width / 2, r.y + r.height / 2);
    await page.waitForTimeout(420);'

# 押す場所にスポットライトを当て、同時にカーソルを動かしてから押す。押すとスポットライトは消え、結果が暗くならずに見える。
# 押した点の輪と、押した要素・カーソルが沈む動きは decor.js が出す。
# 呼び出しは1回あたり約0.7秒かかるので、どの部品も1回の呼び出しにまとめる
click_on() {
  P run-code "async page => {
    const l = page.locator($(_json "$1")).first();
    $_FOCUS
    await l.click();
    await page.evaluate(() => window.__mcSpotOff());
  }"
}

# 名前の付いた入力欄にスポットライトを当て、照らしたまま1文字ずつ打ち、打ち終えたら消す。引用符を気にせず日本語を渡せる
type_text() {
  P run-code "async page => {
    const l = page.getByRole('textbox', { name: $(_json "$1"), exact: true }).first();
    $_FOCUS
    await l.click();
    await l.pressSequentially($(_json "$2"), { delay: 40 });
    await page.evaluate(() => window.__mcSpotOff());
  }"
}

# セレクトボックスにスポットライトを当て、値を選ぶ。値は表示されている文（ラベル）で渡す
select_option() {
  P run-code "async page => {
    const l = page.locator($(_json "$1")).first();
    $_FOCUS
    await l.selectOption({ label: $(_json "$2") });
    await page.evaluate(() => window.__mcSpotOff());
  }"
}

# 対象までなめらかにスクロールする。押す・打つ部品は見えていなければ自分でスクロールするので、見せるだけのときに使う
scroll_to() {
  P run-code "async page => {
    await page.locator($(_json "$1")).first().evaluate((el) => el.scrollIntoView({ behavior: 'smooth', block: 'center' }));
    await page.waitForTimeout(600);
  }"
}

# ページを移る。カーソルと右上の見出しは、移った先でも出し直される
goto() {
  P run-code "async page => { await page.goto($(_json "$1")); await page.waitForLoadState('networkidle').catch(() => {}); }"
}

# 見てほしい場所にスポットライトを当てて、少し見せる（既定は900ミリ秒）。次に押す・打つ場所が出るまで当てたままにする
_SPOT_ON='const r = await l.boundingBox();
    await page.evaluate(([x, y, w, h]) => window.__mcSpot(x, y, w, h), [r.x, r.y, r.width, r.height]);'

spot() {
  P run-code "async page => {
    const l = page.locator($(_json "$1")).first();
    await l.waitFor({ state: 'visible' });
    $_SPOT_ON
    await page.waitForTimeout(${2:-900});
  }"
}

# 期待する文が画面に出るまで待ち（既定は5秒）、出たらその文にスポットライトを当てて見せる。出なければ止まる。
# 不具合のまま撮らないために、結果を見せるところで呼ぶ
expect_text() {
  P run-code "async page => {
    const l = page.getByText($(_json "$1")).first();
    try {
      await l.waitFor({ state: 'visible', timeout: ${2:-5000} });
    } catch {
      throw new Error('期待した表示が出ない: ' + $(_json "$1"));
    }
    // 文の要素は横幅いっぱいのことがあるので、文字の幅に合わせて囲む
    await l.evaluate((el) => {
      const range = document.createRange();
      range.selectNodeContents(el);
      const b = range.getBoundingClientRect();
      window.__mcSpot(b.x, b.y, b.width, b.height);
    });
    await page.waitForTimeout(900);
  }" || { echo "不具合の疑い: 「${1}」が画面に出ない" >&2; return 1; }
}

# 名前の付いた入力欄に、一度に入れる（録画しない前準備）
fill_text() {
  P run-code "async page => { await page.getByRole('textbox', { name: $(_json "$1"), exact: true }).fill($(_json "$2")); }"
}
