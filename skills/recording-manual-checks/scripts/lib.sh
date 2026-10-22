# shellcheck shell=bash
# 動作確認の動画を撮るスクリプトから source する。
# 使い方: media=<置き場所>; session=<セッション名>; source lib.sh
#         next_check "1. …" "期待: …"; zoom '<ロケーター>'; P click '<ロケーター>'; hold; unzoom

# playwright-cli の出力は $log（既定は $media/record.log）に残す。捨てると、失敗したときに止まった理由が分からない
P() {
  local out="${log:-$media/record.log}"
  playwright-cli -s="$session" "$@" >>"$out" 2>&1 && return
  echo "失敗: playwright-cli $1（詳しくは $out）" >&2
  tail -n 20 "$out" >&2
  return 1
}

_HEADING_STYLE="'position:fixed;top:16px;right:16px;max-width:50%;z-index:2147483647;padding:10px 16px;border-radius:8px;background:rgba(20,20,20,.85);color:#fff;font:600 18px/1.4 -apple-system,sans-serif;pointer-events:none;box-shadow:0 2px 8px rgba(0,0,0,.3)'"

_json() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

# 今の項目を、画面の右上にずっと出す。動画の再生バーで隠れないよう、下には置かない。ページの外側（html 直下）に置くので、拡大しても動かない
heading() {
  P run-code "async page => { await page.evaluate((t) => {
    let b = document.getElementById('__manual_check');
    if (!b) {
      b = document.createElement('div');
      b.id = '__manual_check';
      b.style.cssText = $_HEADING_STYLE;
      document.documentElement.appendChild(b);
    }
    b.textContent = t;
  }, $(_json "$1")); }"
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
      b.style.transition = 'transform .3s cubic-bezier(.2,.8,.2,1)';
      b.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + s + ')';
    }, [r.x, r.y, r.width, r.height, ${2:-0}]);
    await page.waitForTimeout(350);
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

# 次の項目の札（画面を暗くして項目と期待する結果）を出す。録画を始める前に呼び、動画が札から始まるようにする
card_show() {
  P run-code "async page => {
    await page.evaluate(([t, d]) => {
      let o = document.getElementById('__manual_check_card');
      if (!o) {
        o = document.createElement('div');
        o.id = '__manual_check_card';
        o.style.cssText = 'position:fixed;inset:0;z-index:2147483647;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:12px;background:rgba(15,15,15,.82);color:#fff;font-family:-apple-system,sans-serif;transition:opacity .2s ease;pointer-events:none';
        document.documentElement.appendChild(o);
      }
      o.innerHTML = '';
      const h = document.createElement('div'); h.style.cssText = 'font-size:34px;font-weight:700;max-width:80%;text-align:center'; h.textContent = t;
      const e = document.createElement('div'); e.style.cssText = 'font-size:20px;opacity:.85;max-width:80%;text-align:center'; e.textContent = d;
      o.append(h, e);
      o.style.opacity = '1';
      let b = document.getElementById('__manual_check');
      if (!b) { b = document.createElement('div'); b.id = '__manual_check'; b.style.cssText = $_HEADING_STYLE; document.documentElement.appendChild(b); }
      b.textContent = t;
    }, [$(_json "$1"), $(_json "$2")]);
  }"
}

# 札を見せてから消す。録画を始めた直後に呼ぶ
card_hide() {
  P run-code "async page => {
    await page.waitForTimeout(${1:-900});
    await page.evaluate(() => { document.getElementById('__manual_check_card').style.opacity = '0'; });
    await page.waitForTimeout(200);
  }"
}

# 名前の付いた入力欄に、1文字ずつ打つ（録画する操作）。引用符を気にせず日本語を渡せる
type_text() {
  P run-code "async page => { await page.getByRole('textbox', { name: $(_json "$1"), exact: true }).pressSequentially($(_json "$2"), { delay: 40 }); }"
}

# 名前の付いた入力欄に、一度に入れる（録画しない前準備）
fill_text() {
  P run-code "async page => { await page.getByRole('textbox', { name: $(_json "$1"), exact: true }).fill($(_json "$2")); }"
}
