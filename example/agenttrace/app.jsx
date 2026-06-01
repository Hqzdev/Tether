/* ====== AgentTrace app ====== */
function App() {
  const nodes = window.NODES;
  const [selId, setSelId] = React.useState(nodes[0].id);
  const [tab, setTab] = React.useState("prompt");
  const [query, setQuery] = React.useState("");
  const [edits, setEdits] = React.useState({});
  const [theme, setTheme] = React.useState(() => localStorage.getItem("at-theme") || "dark");

  React.useEffect(() => {
    document.body.classList.toggle("light", theme === "light");
    localStorage.setItem("at-theme", theme);
  }, [theme]);

  const sel = nodes.find((n) => n.id === selId) || nodes[0];
  const totalMs = nodes.reduce((a, n) => a + n.latencyMs, 0);
  const setEdit = (id, val) => setEdits((e) => ({ ...e, [id]: val }));

  // keyboard nav
  React.useEffect(() => {
    const onKey = (e) => {
      const i = nodes.findIndex((n) => n.id === selId);
      if (e.key === "ArrowDown" || e.key === "j") {
        e.preventDefault();
        setSelId(nodes[Math.min(i + 1, nodes.length - 1)].id);
      } else if (e.key === "ArrowUp" || e.key === "k") {
        e.preventDefault();
        setSelId(nodes[Math.max(i - 1, 0)].id);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [selId]);

  return (
    <div className="stage">
      <div className="window">
        <div className="titlebar">
          <div className="traffic">
            <span className="light red" />
            <span className="light yellow" />
            <span className="light green" />
          </div>
          <div className="title">
            AgentTrace
            <span className="badge">{window.SESSION.id}</span>
          </div>
          <div className="spacer" />
          <div className="tb-actions">
            <button className="tb-btn" title="Replay session"><Icon g={"\uf04b"} style={{ fontSize: 11 }} /></button>
            <button className="tb-btn" title="Pause capture"><Icon g={"\uf04c"} style={{ fontSize: 11 }} /></button>
            <button
              className="tb-btn theme-toggle"
              title={theme === "dark" ? "Switch to light" : "Switch to dark"}
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            >
              <Icon g={theme === "dark" ? "\uf185" : "\uf186"} style={{ fontSize: 12 }} />
            </button>
            <button className="tb-btn" title="Layout"><Icon g={"\uf0db"} style={{ fontSize: 12 }} /></button>
          </div>
        </div>

        <div className="body">
          <Sidebar
            nodes={nodes}
            selId={selId}
            onSelect={setSelId}
            query={query}
            setQuery={setQuery}
          />
          <GraphCanvas nodes={nodes} selId={selId} onSelect={setSelId} totalMs={totalMs} />
          <Inspector node={sel} tab={tab} setTab={setTab} edits={edits} setEdit={setEdit} />
        </div>
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
