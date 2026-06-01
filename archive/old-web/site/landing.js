/* ============================================================
   AgentTrace — marketing site interactions
   ============================================================ */
(function () {
  "use strict";
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  /* swap all static <i class="fa-..."> for inline SVG */
  if (window.ATIcons) window.ATIcons.replace(document);

  /* ---------- shared node definitions (mirrors app data) ---------- */
  const NODES = [
    { step: "1. Intent Classification", status: "success", model: "gpt-4o",            ic: "lightbulb", lat: "842ms",        tok: "412 ↓ 38 ↑", cost: "$0.0118", stat: "SUCCESS" },
    { step: "2. Vector DB Retrieval",   status: "cached",   model: "text-embedding-3-lg", ic: "database",  lat: "0ms (cached)", tok: "24 ↓ 0 ↑",    cost: "$0.0000", stat: "CACHED"  },
    { step: "3. Context Synthesis",     status: "success", model: "claude-3.5-sonnet",  ic: "link",      lat: "1.21s",       tok: "1840 ↓ 256 ↑",cost: "$0.0241", stat: "SUCCESS" },
    { step: "4. Tool · lookup_order",   status: "success", model: "function-call",      ic: "gear",      lat: "318ms",       tok: "96 ↓ 142 ↑",  cost: "$0.0000", stat: "SUCCESS" },
    { step: "5. Response Generation",   status: "error",    model: "local-llama-3.1-70b",ic: "circle-exclamation", lat: "4.10s (timeout)", tok: "2210 ↓ 0 ↑", cost: "$0.0000", stat: "ERROR" }
  ];

  function latClass(n) {
    if (n.status === "cached") return "cy";
    if (n.status === "error") return "pk";
    return "ok";
  }
  function nodeMarkup(n, depth) {
    return `
      <div class="mini-node ${n.status}" data-depth="${depth}">
        <div class="mhead">
          <span class="mn-ico">${window.ATIcon(n.ic)}</span>
          <span class="mn-name">${n.step}</span>
          <span class="mn-stat">${n.stat}</span>
        </div>
        <div class="mn-foot">
          <span class="${latClass(n)}">${n.lat}</span>
          <span>${n.cost}</span>
          <span>${n.tok}</span>
        </div>
      </div>`;
  }

  /* ---------- NAV scroll state ---------- */
  const nav = $("#nav");
  const onScroll = () => nav.classList.toggle("stuck", window.scrollY > 12);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ---------- robust visibility watcher ----------
     IntersectionObserver does not fire in some sandboxed preview frames,
     so we use scroll/resize + getBoundingClientRect (works everywhere). */
  const _watchers = [];
  function watch(el, cb, ratio) {
    if (el) _watchers.push({ el, cb, ratio: ratio == null ? 0.9 : ratio, done: false });
  }
  function runWatchers() {
    const h = window.innerHeight || document.documentElement.clientHeight;
    for (const w of _watchers) {
      if (w.done) continue;
      const r = w.el.getBoundingClientRect();
      if (r.top < h * w.ratio && r.bottom > 0) { w.done = true; w.cb(); }
    }
  }
  window.addEventListener("scroll", runWatchers, { passive: true });
  window.addEventListener("resize", runWatchers);
  window.addEventListener("load", runWatchers);
  // early polling so above-the-fold + near-fold content triggers without a scroll
  let _polls = 0;
  const _pid = setInterval(() => { runWatchers(); if (++_polls > 24) clearInterval(_pid); }, 220);

  /* ---------- reveal on scroll ---------- */
  $$(".reveal").forEach((el) => watch(el, () => el.classList.add("in"), 0.94));

  /* ============================================================
     HERO DEMO — typing → intercept → mini-tree populate (loops)
     ============================================================ */
  const editorCode = $("#editorCode");
  const miniTree = $("#miniTree");
  const interceptMsg = $("#interceptMsg");
  const runChip = $("#runChip");
  const runStatus = $("#runStatus");

  const CODE_LINES = [
    [{ t: "from", c: "tk-bool" }, { t: " openai " }, { t: "import", c: "tk-bool" }, { t: " OpenAI" }],
    [],
    [{ t: "# route every call through AgentTrace", c: "tk-comment" }],
    [{ t: "client " }, { t: "=", c: "tk-punc" }, { t: " OpenAI(" }],
    [{ t: "    base_url" }, { t: "=", c: "tk-punc" }, { t: '"http://localhost:8080/v1"', c: "tk-str" }],
    [{ t: ")" }],
    [],
    [{ t: "agent" }, { t: ".", c: "tk-punc" }, { t: "run(" }, { t: '"Order #4471 — where is my package?"', c: "tk-str" }, { t: ")" }]
  ];

  function buildLineHTML(tokens) {
    return tokens.map((tk) => `<span class="${tk.c || ""}">${escapeHTML(tk.t)}</span>`).join("");
  }
  function escapeHTML(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

  function renderEditorStatic() {
    editorCode.innerHTML = CODE_LINES.map((toks, i) =>
      `<div class="cline${i === 4 ? " hl" : ""}"><span class="gut">${i + 1}</span><span class="src">${buildLineHTML(toks)}</span></div>`
    ).join("");
  }

  async function typeEditor() {
    editorCode.innerHTML = "";
    for (let i = 0; i < CODE_LINES.length; i++) {
      const line = document.createElement("div");
      line.className = "cline";
      line.innerHTML = `<span class="gut">${i + 1}</span><span class="src"></span>`;
      editorCode.appendChild(line);
      const src = line.querySelector(".src");
      const full = buildLineHTML(CODE_LINES[i]);
      // type character-ish by revealing tokens progressively
      const plain = CODE_LINES[i].map((t) => t.t).join("");
      if (plain.length === 0) { await sleep(60); continue; }
      // reveal whole line quickly with a caret
      src.innerHTML = full + '<span class="caret"></span>';
      await sleep(90 + Math.min(plain.length * 7, 280));
      src.innerHTML = full;
      if (i === 4) line.classList.add("hl");
    }
  }

  function clearTree() { miniTree.innerHTML = ""; interceptMsg.classList.remove("show"); }

  async function fireProxy() {
    runChip.classList.add("firing");
    runStatus.textContent = "POST /v1/chat/completions → intercepted";
    interceptMsg.classList.add("show");
    setTimeout(() => runChip.classList.remove("firing"), 500);
    await sleep(420);
  }

  async function populateTree() {
    for (let i = 0; i < NODES.length; i++) {
      const n = NODES[i];
      const depth = i;
      miniTree.insertAdjacentHTML("beforeend", nodeMarkup(n, Math.min(depth, 4)));
      const el = miniTree.lastElementChild;
      // force reflow then animate in
      void el.offsetWidth;
      await sleep(40);
      el.classList.add("in");
      if (n.status === "error") {
        await sleep(260);
        el.classList.add("shake");
      }
      await sleep(n.status === "error" ? 520 : 360);
    }
  }

  async function heroLoop() {
    if (reduce) {
      renderEditorStatic();
      interceptMsg.classList.add("show");
      NODES.forEach((n, i) => {
        miniTree.insertAdjacentHTML("beforeend", nodeMarkup(n, Math.min(i, 4)));
      });
      $$(".mini-node", miniTree).forEach((el) => el.classList.add("in"));
      runStatus.textContent = "5 calls traced · 1 error";
      return;
    }
    while (true) {
      clearTree();
      runStatus.textContent = "listening on :8080";
      await typeEditor();
      await sleep(450);
      await fireProxy();
      await populateTree();
      runStatus.textContent = "5 calls traced · 1 error · 6.47s";
      await sleep(3600);
    }
  }

  /* start hero loop once visible (saves CPU until scrolled to) */
  let heroStarted = false;
  watch($(".demo-wrap"), () => { if (!heroStarted) { heroStarted = true; heroLoop(); } }, 0.85);

  /* ============================================================
     SCROLL-TRIGGERED TREE (section 2 sticky canvas)
     ============================================================ */
  const treeNodes = $("#treeNodes");
  const treeSvg = $("#treeSvg");
  const treeLines = $$(".tline", treeSvg);

  // prep dashed-line draw animation
  treeLines.forEach((p) => {
    const len = p.getTotalLength();
    p.style.transition = "none";
    p.style.strokeDasharray = "4 4";
    p.dataset.len = len;
  });

  // build the section-2 tree nodes (compact cards positioned over svg)
  const TREE_LAYOUT = [
    { acc: "success", label: "Intent Classification", sub: "gpt-4o", y: 30 },
    { acc: "cached",  label: "Vector DB Retrieval",   sub: "cached · 0ms", y: 130 },
    { acc: "success", label: "Context Synthesis",     sub: "claude-3.5-sonnet", y: 230 },
    { acc: "error",   label: "Response Generation",   sub: "timeout · 4.10s", y: 330 }
  ];
  const ICONS = { success: "check-circle", cached: "bolt", error: "circle-exclamation" };

  treeNodes.innerHTML = TREE_LAYOUT.map((n, i) => `
    <div class="s2node ${n.acc}" data-i="${i}" style="
      position:absolute; left:36px; top:${n.y}px; width:calc(100% - 48px);
      padding:11px 13px; border-radius:11px; border:1px solid var(--border);
      background:linear-gradient(180deg,#1a1a1c,#161618);
      opacity:0; transform:translateY(10px) scale(.95);
      transition:opacity .45s var(--ease-expo), transform .45s var(--ease-expo);
      display:flex; align-items:center; gap:10px;">
      <span style="width:26px;height:26px;border-radius:7px;display:grid;place-items:center;flex:0 0 26px;
        font-size:13px;border:1px solid var(--border);
        color:var(--${accColor(n.acc)});background:var(--${n.acc}-bg);border-color:var(--${n.acc}-dim);">${window.ATIcon(ICONS[n.acc])}</span>
      <span style="min-width:0;flex:1;">
        <span style="display:block;font-size:13px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${n.label}</span>
        <span style="display:block;font-family:var(--font-mono);font-size:10.5px;color:var(--text-4);margin-top:2px;">${n.sub}</span>
      </span>
      <span style="font-size:9px;font-weight:700;letter-spacing:.4px;text-transform:uppercase;padding:3px 7px;border-radius:999px;
        color:var(--${accColor(n.acc)});background:var(--${n.acc}-bg);">${n.acc}</span>
    </div>`).join("");

  function accColor(a) { return a === "success" ? "green" : a === "cached" ? "cyan" : "pink"; }

  // color the svg connectors per status
  const lineColors = ["#2c4a3c", "#2c4248", "#2c4a3c", "#4a2c34"];
  treeLines.forEach((p, i) => { p.setAttribute("stroke", lineColors[i] || "#3a3a3d"); });

  let treeDrawn = false;
  async function drawTree() {
    if (treeDrawn) return; treeDrawn = true;
    const s2 = $$(".s2node", treeNodes);
    const accStroke = ["#74e0a8", "#74cfe0", "#74e0a8", "#ff8aa4"];
    for (let i = 0; i < s2.length; i++) {
      s2[i].style.opacity = "1";
      s2[i].style.transform = "none";
      // draw connector after node appears
      if (treeLines[i]) {
        const p = treeLines[i];
        const len = parseFloat(p.dataset.len);
        p.style.transition = "none";
        p.style.strokeDasharray = `${len}`;
        p.style.strokeDashoffset = `${len}`;
        p.style.stroke = accStroke[i];
        void p.getBoundingClientRect();
        p.style.transition = "stroke-dashoffset .5s ease";
        requestAnimationFrame(() => { p.style.strokeDashoffset = "0"; });
      }
      if (TREE_LAYOUT[i].acc === "error") {
        await sleep(320);
        s2[i].animate(
          [
            { transform: "translateX(0)" }, { transform: "translateX(-4px)" },
            { transform: "translateX(4px)" }, { transform: "translateX(-3px)" },
            { transform: "translateX(3px)" }, { transform: "translateX(0)" }
          ], { duration: 420, easing: "ease" }
        );
      }
      await sleep(reduce ? 0 : 480);
    }
  }
  watch($("#treeStage"), () => drawTree(), 0.7);

  /* ============================================================
     INTERACTIVE INSPECTOR — feature cards sync the right pane
     ============================================================ */
  const flcards = $$(".flcard");
  const views = $$(".insp-view");
  const inspDot = $("#inspDot");
  const inspTitle = $("#inspTitle");
  const inspModel = $("#inspModel");

  const VIEW_META = {
    graph:   { dot: "green",  title: "Customer Support Agent",  model: "5 nodes" },
    cache:   { dot: "cyan",   title: "2. Vector DB Retrieval",  model: "text-embedding-3-lg" },
    time:    { dot: "amber",  title: "1. Intent Classification",model: "gpt-4o" },
    privacy: { dot: "violet", title: "Secrets & Storage",       model: "local" }
  };

  function setView(view) {
    flcards.forEach((c) => c.classList.toggle("on", c.dataset.view === view));
    views.forEach((v) => v.classList.toggle("on", v.dataset.view === view));
    const m = VIEW_META[view];
    inspDot.className = "idot " + m.dot;
    inspTitle.textContent = m.title;
    inspModel.textContent = m.model;
  }
  flcards.forEach((c) => {
    c.addEventListener("click", () => setView(c.dataset.view));
    c.addEventListener("mouseenter", () => { if (!matchMedia("(hover: none)").matches) setView(c.dataset.view); });
  });

  /* graph view content (reuse mini-node markup) */
  $("#graphView").innerHTML = NODES.map((n, i) => nodeMarkup(n, Math.min(i, 4))).join("");
  // graph nodes always visible in inspector
  $$("#graphView .mini-node").forEach((el) => el.classList.add("in"));

  /* time-travel editor content — JSON with one edited line highlighted */
  $("#ttArea").innerHTML = [
    `{`,
    `  <span style="color:#79b8ff">"intent"</span>: <span style="color:#9ad9a0">"order_status"</span>,`,
    `  <span style="color:#79b8ff">"confidence"</span>: <span style="color:#f0b072">0.97</span>,`,
    `  <span style="color:#79b8ff">"entities"</span>: {`,
    `    <span class="editline">    "sentiment": "calm",  ← mocked</span>`,
    `    <span style="color:#79b8ff">"order_id"</span>: <span style="color:#9ad9a0">"4471"</span>`,
    `  }`,
    `}`
  ].join("\n");

  $("#ttBtn").addEventListener("click", function () {
    const b = this;
    const orig = b.innerHTML;
    b.innerHTML = window.ATIcon("rotate", "spin") + " Replaying chain…";
    b.style.pointerEvents = "none";
    setTimeout(() => {
      b.innerHTML = window.ATIcon("check") + " Replayed · 4 nodes re-ran";
      b.style.background = "linear-gradient(180deg,#8af0bc,#5fd49a)";
      b.style.borderColor = "#5fd49a";
      b.style.color = "#06140d";
      setTimeout(() => {
        b.innerHTML = orig;
        b.style.background = ""; b.style.borderColor = ""; b.style.color = "";
        b.style.pointerEvents = "";
      }, 1900);
    }, 1300);
  });

  /* graph view: wrap nodes in IDE-style row hover for the cache code rows handled by CSS */

  /* debug hook — lets a static screenshot harness force animated states
     (observers only fire on real scroll). Harmless in production. */
  window.__AT = {
    reveal: () => $$(".reveal").forEach((e) => e.classList.add("in")),
    hero: heroLoop,
    tree: drawTree,
    view: setView
  };
})();
