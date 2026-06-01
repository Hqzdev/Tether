/* ====== AgentTrace components ====== */
const { useState, useRef, useEffect } = React;

/* --- tiny JSON syntax highlighter --> returns HTML string --- */
function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function highlightJSON(line) {
  let s = escapeHtml(line);
  // strings (keys vs values handled by trailing colon)
  s = s.replace(/"(\\.|[^"\\])*"(\s*:)?/g, (m, _g, colon) => {
    if (m.trimEnd().endsWith(":") || /"\s*:$/.test(m)) {
      return '<span class="tk-key">' + m.replace(/:\s*$/, "") + '</span><span class="tk-punc">:</span>';
    }
    return '<span class="tk-str">' + m + "</span>";
  });
  // numbers
  s = s.replace(/(^|[\s\[,])(-?\d+\.?\d*)/g, (m, pre, num) => pre + '<span class="tk-num">' + num + "</span>");
  // booleans / null
  s = s.replace(/\b(true|false)\b/g, '<span class="tk-bool">$1</span>');
  s = s.replace(/\bnull\b/g, '<span class="tk-null">null</span>');
  // punctuation braces
  s = s.replace(/([{}\[\],])/g, '<span class="tk-punc">$1</span>');
  return s;
}

function CodeBlock({ text, lang, broken, errorLines }) {
  const lines = text.split("\n");
  return (
    <div className="code">
      <table>
        <tbody>
          {lines.map((ln, i) => {
            const isErr = errorLines && errorLines.includes(i);
            const html = lang === "json" ? highlightJSON(ln) : escapeHtml(ln);
            return (
              <tr key={i}>
                <td className="ln">{i + 1}</td>
                <td
                  className={"cl" + (broken ? " broken" : "")}
                  style={isErr ? { background: "rgba(255,138,164,0.10)", boxShadow: "inset 3px 0 0 var(--pink)" } : null}
                  dangerouslySetInnerHTML={{ __html: html || "&nbsp;" }}
                />
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

/* ---------- Sidebar ---------- */
function Sidebar({ nodes, selId, onSelect, query, setQuery }) {
  const filtered = nodes.filter(
    (n) =>
      n.step.toLowerCase().includes(query.toLowerCase()) ||
      n.model.toLowerCase().includes(query.toLowerCase())
  );
  return (
    <div className="pane left">
      <div className="sb-top">
        <div className="search">
          <Icon g={"\uf002"} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Filter calls…"
          />
          <span className="kbd">⌘F</span>
        </div>
        <div className="proxy">
          <span className="dot" />
          <span className="ptext">
            Local Proxy: <b>Running</b> on port <span className="mono">8080</span>
          </span>
        </div>
      </div>

      <div className="sb-sectionhead">
        <span>Recent Calls</span>
        <span className="count">{filtered.length}/{nodes.length}</span>
      </div>

      <div className="calllist">
        {filtered.map((n) => (
          <div
            key={n.id}
            className={"call " + n.status + (n.id === selId ? " sel" : "")}
            onClick={() => onSelect(n.id)}
          >
            <div className="statwrap"><span className={"sdot " + n.status} /></div>
            <div className="main">
              <div className="step">{n.step}</div>
              <div className="meta">
                <span className="tag model">{n.model}</span>
                <span className="ts">{n.timestamp}</span>
              </div>
            </div>
            <div className="cost">
              <div className={"amt" + (n.cost === "$0.0000" ? " zero" : "")}>{n.cost}</div>
              <div className={"lat" + (n.status === "cached" ? " cached" : "")}>
                {n.status === "cached" ? "0ms" : n.latency.replace(/\s*\(.*\)/, "")}
              </div>
            </div>
          </div>
        ))}
      </div>

      <div className="sb-bottom">
        <button className="btn" onClick={() => alert("Settings · proxy config")}>
          <Icon g={"\uf013"} /> Settings
        </button>
        <button className="btn danger" onClick={() => alert("API key reset · session cleared")}>
          <Icon g={"\uf084"} /> Reset Key
        </button>
      </div>
    </div>
  );
}

/* ---------- Center graph ---------- */
function Icon({ g, style }) {
  return <span style={{ fontFamily: '"Font Awesome 6 Free"', fontWeight: 900, ...style }}>{g}</span>;
}

function GraphCanvas({ nodes, selId, onSelect, totalMs }) {
  const sel = nodes.find((n) => n.id === selId) || nodes[0];
  const fmt = (ms) => (ms >= 1000 ? (ms / 1000).toFixed(2) + "s" : ms + "ms");
  const hasError = nodes.some((n) => n.status === "error");
  return (
    <div className="pane center">
      <div className="graph-head">
        <div className="gh-main">
          <div className="crumb">
            <b>{window.SESSION.title}</b> &nbsp;›&nbsp; {sel.step}
          </div>
          <h2>{sel.step}</h2>
        </div>
        <div className="gh-stats">
          <div className="stat">
            <div className="l">Total Time</div>
            <div className="v">{fmt(totalMs)}</div>
          </div>
          <div className="stat">
            <div className="l">Steps</div>
            <div className="v">{nodes.length}</div>
          </div>
          <div className="stat">
            <div className="l">Status</div>
            <div className={"v " + (hasError ? "pink" : "green")}>{hasError ? "FAILED" : "OK"}</div>
          </div>
        </div>
      </div>

      <div className="canvas">
        <div className="tree">
          {nodes.map((n, i) => (
            <TreeNode
              key={n.id}
              node={n}
              first={i === 0}
              last={i === nodes.length - 1}
              selected={n.id === selId}
              onSelect={onSelect}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

function TreeNode({ node, first, last, selected, onSelect }) {
  const indent = node.depth * 26;
  return (
    <div className="tnode-row" style={{ marginLeft: indent }}>
      {!first && (
        <div className="rail">
          <div className="vline" />
          <div className="elbow" />
          <div className="knob" />
        </div>
      )}
      <div
        className={"node " + node.status + (selected ? " sel" : "")}
        onClick={() => onSelect(node.id)}
      >
        <div className="nhead">
          <div className="nicon"><Icon g={node.icon} /></div>
          <div className="ntitle">
            <div className="nm">{node.step}</div>
            <div className="nsub">{node.model} · {node.requestId}</div>
          </div>
          <span className="nstat">{node.status}</span>
        </div>
        <div className="nbar"><i style={{ width: node.barPct + "%" }} /></div>
        <div className="nfoot">
          <span className="nf"><Icon g={"\uf017"} style={{ fontSize: 9 }} /> <b>{node.latency}</b></span>
          <span className="nf"><Icon g={"\uf155"} style={{ fontSize: 9 }} /> <b>{node.cost}</b></span>
          <span className="nf grow">{node.tokensIn}↓ {node.tokensOut}↑ tok</span>
        </div>
      </div>
    </div>
  );
}

/* ---------- Right inspector ---------- */
function Inspector({ node, tab, setTab, edits, setEdit }) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  useEffect(() => { setEditing(false); }, [node.id, tab]);

  const isError = node.status === "error";
  const editedResp = edits[node.id];
  const respText = editedResp != null ? editedResp : node.response.text;
  const respLang = editedResp != null ? "json" : node.response.lang;

  const startEdit = () => {
    setDraft(respText);
    setEditing(true);
    setTab("response");
  };
  const saveEdit = () => {
    setEdit(node.id, draft);
    setEditing(false);
  };

  return (
    <div className="pane right">
      <div className="insp-head">
        <div className="insp-title">
          <span className={"idot " + node.status} />
          <span className="it">{node.step}</span>
          <span className="imodel">{node.model}</span>
        </div>
        <div className="segmented">
          {["prompt", "response", "metadata"].map((t) => (
            <button key={t} className={"seg" + (tab === t ? " on" : "")} onClick={() => setTab(t)}>
              {t[0].toUpperCase() + t.slice(1)}
            </button>
          ))}
        </div>
      </div>

      <div className="insp-body">
        {tab === "prompt" && (
          <React.Fragment>
            <div className="editor-toolbar">
              <span>request.prompt</span>
              <span className="grow" />
              <span className="chip">temp {node.temperature == null ? "—" : node.temperature.toFixed(1)}</span>
              <span className="chip">{node.tokensIn} tok</span>
            </div>
            <div className="code">
              <table><tbody>
                <PromptRows role="system" body={node.prompt.system} start={1} />
                <PromptRows role="user" body={node.prompt.user} start={node.prompt.system.split("\n").length + 2} />
              </tbody></table>
            </div>
          </React.Fragment>
        )}

        {tab === "response" && (
          <React.Fragment>
            <div className="editor-toolbar">
              <span>response.{respLang === "json" ? "json" : "txt"}</span>
              <span className="grow" />
              {editedResp != null && <span className="chip" style={{ color: "var(--amber)", borderColor: "#5a4a24" }}>edited</span>}
              <span className={"chip " + (isError ? "err" : "ok")}>{isError ? "✗ " + node.error.code : "✓ 200 OK"}</span>
            </div>
            {isError && !editing && (
              <div className="err-banner">
                <span className="x">✗</span>
                <span><b>{node.error.code}</b> — {node.error.message}<br /><span style={{ color: "var(--text-4)" }}>{node.error.detail}</span></span>
              </div>
            )}
            {editing ? (
              <textarea className="edit-area" value={draft} onChange={(e) => setDraft(e.target.value)} spellCheck={false} autoFocus />
            ) : (
              <CodeBlock text={respText} lang={respLang} broken={isError && editedResp == null} />
            )}
          </React.Fragment>
        )}

        {tab === "metadata" && <Metadata node={node} edited={editedResp != null} />}
      </div>

      <div className="insp-foot">
        {editing ? (
          <React.Fragment>
            <button className="tt-btn active" onClick={saveEdit}>
              <Icon g={"\uf0c7"} /> Save Mocked Response &amp; Replay
            </button>
            <div className="tt-sub">downstream steps will re-run against your edit · <b onClick={() => setEditing(false)} style={{ cursor: "pointer" }}>cancel</b></div>
          </React.Fragment>
        ) : (
          <React.Fragment>
            <button className="tt-btn" onClick={startEdit}>
              <Icon g={"\uf2f1"} /> Time-Travel · Edit Response
            </button>
            <div className="tt-sub">intercept &amp; rewrite this node's output, then replay the chain</div>
          </React.Fragment>
        )}
      </div>
    </div>
  );
}

function PromptRows({ role, body, start }) {
  const lines = body.split("\n");
  return (
    <React.Fragment>
      <tr>
        <td className="ln">{start - 1}</td>
        <td className="cl"><span className="role">{role}</span></td>
      </tr>
      {lines.map((ln, i) => (
        <tr key={i}>
          <td className="ln">{start + i}</td>
          <td className="cl">{ln || "\u00a0"}</td>
        </tr>
      ))}
    </React.Fragment>
  );
}

function Metadata({ node, edited }) {
  const rows = [
    ["Request ID", node.requestId, ""],
    ["Status", node.status === "error" ? node.error.code : node.status.toUpperCase(),
      node.status === "error" ? "pink" : node.status === "cached" ? "cyan" : "green"],
    ["Model", node.model, ""],
    ["Exact Latency", node.latency, node.status === "cached" ? "cyan" : node.status === "error" ? "pink" : ""],
    ["Tokens In", node.tokensIn.toLocaleString(), ""],
    ["Tokens Out", node.tokensOut.toLocaleString(), node.tokensOut === 0 ? "" : ""],
    ["Cost", node.cost, node.cost === "$0.0000" ? "" : ""],
    ["Cache Status", node.cacheStatus, node.cacheStatus === "HIT" ? "cyan" : ""],
    ["Temperature", node.temperature == null ? "n/a" : node.temperature.toFixed(2), ""],
    ["Timestamp", node.timestamp + ".184", ""],
    ["Mock Override", edited ? "ACTIVE" : "none", edited ? "pink" : ""],
  ];
  return (
    <div className="meta-table">
      {rows.map(([k, v, cls]) => (
        <div className="kv" key={k}>
          <div className="k">{k}</div>
          <div className={"v " + cls}>{v}</div>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { Sidebar, GraphCanvas, Inspector, Icon, CodeBlock });
