// ブラウザの操作を撮る動画で、ページに足す部品。lib.sh の show_actions が、ページを読み込むたびに走るよう登録する。
// ページを移っても、カーソル・右上の見出しは前の状態のまま出し直す（sessionStorage に残す）。
// - カーソル: playwright のカーソルは見た目を変えられないので、白く縁取った矢印をマウスの動きに合わせて動かす
// - 押した印: 押した点から細い輪が広がり、押した要素とカーソルが少し沈む
// - 見出し: window.__mcHeading(文) で右上に出す
// - スポットライト: window.__mcSpot(x, y, w, h) で押す場所のまわりを暗くし、window.__mcSpotOff() で消す
() => {
  if (window.__mcInstalled) return;
  window.__mcInstalled = true;
  const store = window.sessionStorage;
  const mount = (el) => (document.documentElement || document).appendChild(el);
  const ready = (fn) => (document.documentElement ? fn() : requestAnimationFrame(() => ready(fn)));

  ready(() => {
    const st = document.createElement("style");
    st.textContent = "@keyframes __mc_ring { from { transform: translate(-50%,-50%) scale(.4); opacity: .8 } to { transform: translate(-50%,-50%) scale(1.4); opacity: 0 } }";
    mount(st);

    const last = JSON.parse(store.getItem("__mc_cursor") || "[640,400]");
    const c = document.createElement("div");
    c.id = "__manual_check_cursor";
    c.style.cssText = "position:fixed;left:" + last[0] + "px;top:" + last[1] + "px;width:28px;height:28px;z-index:2147483647;pointer-events:none;transition:left .3s cubic-bezier(.2,.8,.2,1),top .3s cubic-bezier(.2,.8,.2,1);filter:drop-shadow(0 1px 3px rgba(0,0,0,.45))";
    c.innerHTML = "<svg width=\"28\" height=\"28\" viewBox=\"0 0 24 24\"><path d=\"M3 2 L3 19 L8 14.5 L11.5 22 L14.5 20.6 L11 13.3 L17.5 13.3 Z\" fill=\"#111\" stroke=\"#fff\" stroke-width=\"1.8\" stroke-linejoin=\"round\"/></svg>";
    mount(c);
    addEventListener("mousemove", (e) => {
      const p = [e.clientX - 3, e.clientY - 2];
      c.style.left = p[0] + "px"; c.style.top = p[1] + "px";
      store.setItem("__mc_cursor", JSON.stringify(p));
    }, true);
    addEventListener("mousedown", (e) => {
      const ring = document.createElement("div");
      ring.style.cssText = "position:fixed;left:" + e.clientX + "px;top:" + e.clientY + "px;border-radius:50%;z-index:2147483646;pointer-events:none;width:52px;height:52px;border:2.5px solid rgba(17,17,17,.7);box-shadow:0 0 0 1px rgba(255,255,255,.8);animation:__mc_ring .45s ease-out forwards";
      mount(ring);
      setTimeout(() => ring.remove(), 600);
      c.animate([{ transform: "scale(1)" }, { transform: "scale(.82)" }, { transform: "scale(1)" }], { duration: 220, easing: "ease-out" });
      const t = e.target.closest("button, a, label, select, [role=button], [role=checkbox], input") || e.target;
      t.animate([{ transform: "scale(1)" }, { transform: "scale(.94)" }, { transform: "scale(1)" }], { duration: 250, easing: "ease-out" });
    }, true);

    window.__mcHeading = (text) => {
      store.setItem("__mc_heading", text);
      let b = document.getElementById("__manual_check");
      if (!b) {
        b = document.createElement("div");
        b.id = "__manual_check";
        b.style.cssText = "position:fixed;top:16px;right:16px;max-width:50%;z-index:2147483647;padding:10px 16px;border-radius:8px;background:rgba(20,20,20,.85);color:#fff;font:600 18px/1.4 -apple-system,sans-serif;pointer-events:none;box-shadow:0 2px 8px rgba(0,0,0,.3)";
        mount(b);
      }
      b.textContent = text;
    };
    const h = store.getItem("__mc_heading");
    if (h) window.__mcHeading(h);

    window.__mcSpot = (x, y, w, h) => {
      document.getElementById("__manual_check_spot")?.remove();
      const pad = 6;
      const f = document.createElement("div");
      f.id = "__manual_check_spot";
      f.style.cssText = "position:fixed;left:" + (x - pad) + "px;top:" + (y - pad) + "px;width:" + (w + pad * 2) + "px;height:" + (h + pad * 2) + "px;border-radius:12px;z-index:2147483645;pointer-events:none;"
        + "box-shadow:0 0 0 2px rgba(99,102,241,.95),0 0 16px 3px rgba(99,102,241,.35),0 0 0 9999px rgba(15,23,42,.28);"
        + "opacity:0;transform:scale(1.25);transition:opacity .3s ease,transform .4s cubic-bezier(.22,1,.36,1)";
      mount(f);
      f.getBoundingClientRect();
      f.style.opacity = "1"; f.style.transform = "scale(1)";
    };
    window.__mcSpotOff = () => {
      const f = document.getElementById("__manual_check_spot");
      if (!f) return;
      f.style.opacity = "0";
      setTimeout(() => f.remove(), 450);
    };
  });
}
