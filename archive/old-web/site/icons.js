/* ============================================================
   AgentTrace — self-contained inline SVG icon set
   Replaces <i class="fa-... fa-NAME"> with crisp inline SVG.
   No icon-font CDN dependency.
   ============================================================ */
(function () {
  "use strict";
  // filled icons render with fill=currentColor; others are 1.7px strokes
  const FILLED = new Set(["github", "star", "apple", "play", "pause", "bolt", "dot"]);

  const P = {
    "diagram-project": '<rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="13" width="8" height="8" rx="2"/><path d="M7 11v3a2 2 0 0 0 2 2h4"/>',
    "workflow":        '<rect x="3" y="3" width="8" height="8" rx="2"/><rect x="13" y="13" width="8" height="8" rx="2"/><path d="M7 11v3a2 2 0 0 0 2 2h4"/>',
    "bolt":            '<path d="M11 2 3 14h7l-1 8 9-12h-7l1-8z"/>',
    "shield-halved":   '<path d="M12 3 5 6v5c0 4 3 7.6 7 9 4-1.4 7-5 7-9V6l-7-3z"/><path d="M12 3v18"/>',
    "clock-rotate-left":'<path d="M3 12a9 9 0 1 0 2.6-6.3M3 4.5v4h4"/><path d="M12 8v4.2l3 1.8"/>',
    "play":            '<path d="M7 5l12 7-12 7V5z"/>',
    "pause":           '<path d="M7 5h3v14H7zM14 5h3v14h-3z"/>',
    "table-columns":   '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M12 4v16"/>',
    "code":            '<path d="M16 18l5-6-5-6M8 6l-5 6 5 6"/>',
    "file-lines":      '<path d="M14 3v5h5"/><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M8 13h8M8 17h8M8 9h2"/>',
    "arrow-down-long": '<path d="M12 4v15M7 14l5 5 5-5"/>',
    "circle-nodes":    '<circle cx="6" cy="6" r="2.2"/><circle cx="18" cy="7" r="2.2"/><circle cx="12" cy="17.5" r="2.2"/><path d="M7.8 7.2 10.6 15.6M16.2 8.6 13.2 15.8M8.1 6.4 15.9 6.9"/>',
    "spark":           '<path d="M12 3v18M3 12h18M5.8 5.8l12.4 12.4M18.2 5.8 5.8 18.2"/>',
    "flask":           '<path d="M9 3h6M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4a2 2 0 0 0 1.8-3l-5-9V3"/><path d="M7.2 15h9.6"/>',
    "link":            '<path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/>',
    "cube":            '<path d="M12 2 3 7v10l9 5 9-5V7l-9-5z"/><path d="M3 7l9 5 9-5M12 12v10"/>',
    "cubes":           '<path d="M12 2 3 7v10l9 5 9-5V7l-9-5z"/><path d="M3 7l9 5 9-5M12 12v10"/>',
    "microchip":       '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx="1"/><path d="M9 2v3M15 2v3M9 19v3M15 19v3M2 9h3M2 15h3M19 9h3M19 15h3"/>',
    "feather":         '<path d="M20 4a6 6 0 0 0-8.5 0L5 10.5V19h8.5L20 12.5a6 6 0 0 0 0-8.5z"/><path d="M5 19 14 10M15 8l1.5 1.5"/>',
    "lock":            '<rect x="4.5" y="10.5" width="15" height="10.5" rx="2"/><path d="M8 10.5V7a4 4 0 0 1 8 0v3.5"/>',
    "database":        '<ellipse cx="12" cy="5.5" rx="7.5" ry="3"/><path d="M4.5 5.5v6c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3v-6M4.5 11.5v6c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3v-6"/>',
    "key":             '<circle cx="7.8" cy="15.7" r="4.3"/><path d="M10.8 12.7 21 2.5M16 7l3 3M14 9l2 2"/>',
    "tower-broadcast": '<circle cx="12" cy="8.5" r="1.6"/><path d="M12 10.2V21M9 21h6M8.6 5.1a5 5 0 0 0 0 6.8M15.4 5.1a5 5 0 0 1 0 6.8M6 3a8.5 8.5 0 0 0 0 11M18 3a8.5 8.5 0 0 1 0 11"/>',
    "check":           '<path d="M5 12.5l4.5 4.5L19 7"/>',
    "check-circle":    '<circle cx="12" cy="12" r="9"/><path d="M8.2 12.4l2.6 2.6 5-5.4"/>',
    "dot":             '<circle cx="12" cy="12" r="6"/>',
    "circle":          '<circle cx="12" cy="12" r="8"/>',
    "rotate":          '<path d="M21 12a9 9 0 1 1-2.64-6.36M21 4.5V9h-4.5"/>',
    "lightbulb":       '<path d="M9.2 18h5.6M10.3 21h3.4M12 3a6 6 0 0 0-3.8 10.7c.7.6 1.1 1.4 1.2 2.3h5.2c.1-.9.5-1.7 1.2-2.3A6 6 0 0 0 12 3z"/>',
    "gear":            '<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M3.6 7l2.6 1.5M17.8 15.5l2.6 1.5M3.6 17l2.6-1.5M17.8 8.5l2.6-1.5"/>',
    "circle-exclamation":'<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5"/><circle cx="12" cy="16.4" r="0.6" fill="currentColor" stroke="none"/>',
    "github":          '<path d="M12 2C6.48 2 2 6.48 2 12c0 4.42 2.87 8.17 6.84 9.5.5.09.68-.22.68-.48 0-.24-.01-.87-.01-1.7-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.61.07-.61 1 .07 1.53 1.03 1.53 1.03.89 1.52 2.34 1.08 2.91.83.09-.65.35-1.08.63-1.33-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.65 0 0 .84-.27 2.75 1.02.8-.22 1.65-.33 2.5-.34.85.01 1.7.12 2.5.34 1.91-1.29 2.75-1.02 2.75-1.02.55 1.38.2 2.4.1 2.65.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.69-4.57 4.94.36.31.68.92.68 1.85 0 1.34-.01 2.42-.01 2.75 0 .27.18.58.69.48A10.01 10.01 0 0 0 22 12c0-5.52-4.48-10-10-10z"/>',
    "star":            '<path d="M12 2l2.9 6.26L22 9.27l-5.2 4.87 1.3 6.86L12 17.77l-6.1 3.23 1.3-6.86L2 9.27l7.1-1.01L12 2z"/>',
    "apple":           '<path d="M16.37 12.78c-.02-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.71-3.19-1.73-1.36-.14-2.65.8-3.34.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.19-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.6 2.25 2.74 2.21 1.1-.04 1.51-.71 2.84-.71 1.32 0 1.7.71 2.86.69 1.18-.02 1.93-1.08 2.65-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.29-.88-2.31-3.49zM14.4 6.24c.61-.74 1.02-1.77.91-2.8-.88.04-1.95.59-2.58 1.33-.56.65-1.06 1.7-.93 2.7.98.08 1.99-.5 2.6-1.23z"/>',
    "python":          '<path d="M12 2c-2 0-3.5.6-3.5 2.6V7H12v.8H6.5C4.5 7.8 3.5 9 3.5 11.5S4.4 15 6.5 15h1.3v-2.2c0-1.8 1.4-3.1 3.2-3.1h3.5c1.6 0 2.5-1 2.5-2.6V4.6C20.5 2.8 19 2 17 2h-5zm-1.7 1.4a.9.9 0 1 1 0 1.8.9.9 0 0 1 0-1.8z"/><path d="M12 22c2 0 3.5-.6 3.5-2.6V17H12v-.8h5.5c2 0 3-1.2 3-3.7S19.6 9 17.5 9h-1.3v2.2c0 1.8-1.4 3.1-3.2 3.1H9.5c-1.6 0-2.5 1-2.5 2.6v2.5C7 21.2 8.5 22 10.5 22H12zm1.7-1.4a.9.9 0 1 1 0-1.8.9.9 0 0 1 0 1.8z"/>'
  };
  // aliases (fa names that map to a shared glyph)
  const ALIAS = { "mountain-sun": "spark", "circle-dot": "dot" };

  function svg(name, cls) {
    const key = ALIAS[name] || name;
    const inner = P[key];
    if (!inner) return "";
    const filled = FILLED.has(key);
    const attrs = filled
      ? 'fill="currentColor" stroke="none"'
      : 'fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"';
    return `<svg class="ic${cls ? " " + cls : ""}" viewBox="0 0 24 24" ${attrs} aria-hidden="true">${inner}</svg>`;
  }

  function nameFromClasses(el) {
    const skip = new Set(["fa-solid", "fas", "fa-brands", "fab", "fa-regular", "far", "fa-spin", "fa-fw"]);
    for (const c of el.classList) {
      if (c.startsWith("fa-") && !skip.has(c)) return c.slice(3);
    }
    return null;
  }

  function replace(root) {
    (root || document).querySelectorAll("i[class*='fa-']").forEach((el) => {
      const name = nameFromClasses(el);
      if (!name) return;
      const spin = el.classList.contains("fa-spin");
      const html = svg(name, spin ? "spin" : "");
      if (!html) return;
      const tmp = document.createElement("span");
      tmp.innerHTML = html;
      const node = tmp.firstChild;
      // preserve inline color set on the <i>
      if (el.style.color) node.style.color = el.style.color;
      el.replaceWith(node);
    });
  }

  window.ATIcon = svg;            // build an svg string by name
  window.ATIcons = { replace };   // sweep the DOM
})();
