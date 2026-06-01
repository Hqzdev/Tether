# Loom — Web (Next.js)

The Loom UI rebuilt as a **Next.js** app (App Router + TypeScript). It
reproduces the design in [`../example/`](../example) — a macOS-style, three-pane
Loom inspector (sidebar of calls, center call-tree, right inspector with
prompt / response / metadata tabs, light & dark themes, and "time-travel" mock
editing).

## Stack

- **Next.js 15** (App Router) + **React 19** + **TypeScript**
- **[Hugeicons](https://hugeicons.com)** (`@hugeicons/react`) for all UI icons
- **Font Awesome** is still loaded via CDN (in `app/layout.tsx`) for parity with
  the native app
- Plain CSS ported verbatim from the example into `app/globals.css`

## Run

```bash
cd web
npm install
npm run dev      # http://localhost:3000
```

```bash
npm run build && npm start   # production build
```

## Layout

```
web/
├── app/
│   ├── globals.css   # design tokens + all component styles (ported from example)
│   ├── layout.tsx    # <html>/<body>, metadata, Font Awesome CDN
│   └── page.tsx      # the Loom app shell (client component)
├── components/
│   ├── Icon.tsx      # name -> Hugeicons glyph map
│   ├── CodeBlock.tsx # JSON syntax highlighter
│   ├── Sidebar.tsx   # left pane: call list + proxy status
│   ├── GraphCanvas.tsx # center pane: call tree
│   └── Inspector.tsx # right pane: prompt/response/metadata + time-travel
└── lib/
    └── data.ts       # typed mock session (SESSION + NODES)
```

The previous static landing page that lived here was moved to
[`../archive/old-web/`](../archive/old-web).
