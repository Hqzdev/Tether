/** Marketing page data rendered by the generic footer-page route. */
export type SitePage = {
  slug: string;
  title: string;
  eyebrow: string;
  description: string;
  sections: {
    title: string;
    body: string;
    bullets?: string[];
  }[];
  reviewRows?: {
    control: string;
    evidence: string;
    proof: string;
  }[];
  securityMetrics?: {
    label: string;
    value: string;
    detail: string;
    percent: number;
    tone: "local" | "external" | "audit";
  }[];
  securityFlow?: {
    label: string;
    detail: string;
  }[];
  securityMatrix?: {
    asset: string;
    location: string;
    leavesDevice: string;
    control: string;
  }[];
  securityRisks?: {
    area: string;
    status: string;
    owner: string;
    nextStep: string;
  }[];
  cta?: {
    label: string;
    href: string;
  };
};

/** Static marketing and company pages exposed by /[slug]. */
export const SITE_PAGES: SitePage[] = [
  {
    slug: "product",
    title: "Product",
    eyebrow: "Local-first execution debugging",
    description:
      "Tether gives AI builders a single Mac-native workspace for execution traces, file impact, failures, and recovery replay.",
    sections: [
      {
        title: "Built around the real shape of agent work",
        body:
          "Agent runs are not linear logs. They branch, retry, call tools, hit caches, fail in strange places, and recover in ways that are hard to see from a terminal. Tether turns those runs into a readable execution-debugging surface.",
        bullets: ["Execution nodes", "Provider metadata", "Prompt/action inspection", "Recovery-ready traces"],
      },
      {
        title: "Private by default",
        body:
          "The product is designed for sensitive workflows where prompts, customer data, and API keys should stay local. Tether keeps traces on your machine and puts secrets in macOS Keychain.",
      },
    ],
    cta: { label: "Download the alpha", href: "/download" },
  },
  {
    slug: "features",
    title: "Features",
    eyebrow: "Everything needed to recover broken AI code runs",
    description:
      "A complete loop for local AI execution debugging: capture actions, inspect files and failures, replay branches, and recover quickly.",
    sections: [
      {
        title: "Execution capture",
        body:
          "Route provider calls through the local proxy and see every prompt, command, and file-change in a structured execution graph.",
        bullets: ["Request and response bodies", "Command output and exit status", "Model metadata", "Nested tool-call context"],
      },
      {
        title: "Recovery actions",
        body:
          "Edit a failed step, replay from that node, and test downstream behavior without burning tokens on every upstream call.",
        bullets: ["Patch action output", "Replay selected branches", "Cache-aware development", "Deterministic iteration"],
      },
    ],
    cta: { label: "Open inspector page", href: "/inspector" },
  },
  {
    slug: "inspector",
    title: "Inspector",
    eyebrow: "The right pane for every agent decision",
    description:
      "Inspect prompts, responses, metadata, timing, cache state, failures, and replay controls from one focused panel.",
    sections: [
      {
        title: "Prompt and response clarity",
        body:
          "Read exactly what went into a model and what came back out, formatted for scanning instead of buried in raw terminal output.",
      },
      {
        title: "Operational context",
        body:
          "See whether a call was cached, how long it took, what it cost, and where it sits in the larger agent tree.",
        bullets: ["Status chips", "Cache metadata", "Token counts", "Provider and model details"],
      },
    ],
    cta: { label: "See how it works", href: "/how-it-works" },
  },
  {
    slug: "how-it-works",
    title: "How it works",
    eyebrow: "One proxy, full execution context",
    description:
      "Tether runs a local HTTP proxy. Point your SDK at localhost, run your agent, and inspect the execution context.",
    sections: [
      {
        title: "1. Route calls through Tether",
        body:
          "Change the SDK base URL to the local Tether endpoint. Your application keeps using the same request shape.",
      },
      {
        title: "2. Capture the run",
        body:
          "The proxy forwards requests to your configured provider while recording prompt/action order, file diffs, failures, and responses locally.",
      },
      {
        title: "3. Replay the recovery point",
        body:
          "Select a failed node, edit or override the action, then rerun downstream logic from that point forward.",
      },
    ],
    cta: { label: "Read documentation", href: "/documentation" },
  },
  {
    slug: "download",
    title: "Download",
    eyebrow: "Alpha for macOS",
    description:
      "Get the Mac build, connect the local proxy, and inspect your first execution debugger workflow in minutes.",
    sections: [
      {
        title: "macOS-first",
        body:
          "Tether is crafted for local development on the Mac, with Keychain-aware secrets, a native-feeling interface, and local execution records.",
        bullets: ["macOS 13+", "Local proxy included", "No account required for local tracing", "Free during alpha"],
      },
      {
        title: "What you get",
        body:
          "The alpha includes the web landing, local proxy, trace capture, cache metadata, and the evolving Mac interface.",
      },
    ],
    cta: { label: "Join the waitlist", href: "/#download" },
  },
  {
    slug: "developers",
    title: "Developers",
    eyebrow: "For people shipping AI coding agents",
    description:
      "Tether is designed for engineers building AI products, internal tools, copilots, autonomous workflows, and agent infrastructure.",
    sections: [
      {
        title: "Use it with your existing stack",
        body:
          "Keep your SDKs, models, and frameworks. Tether sits in front of provider calls and gives you execution recovery context.",
        bullets: ["OpenAI-compatible clients", "LangChain", "LangGraph", "LlamaIndex", "Ollama and LM Studio"],
      },
      {
        title: "Debug before production",
        body:
          "Find broken branches, file-impacting steps, and confusing model behavior while you can still recover locally.",
      },
    ],
    cta: { label: "View CLI reference", href: "/cli-reference" },
  },
  {
    slug: "documentation",
    title: "Documentation",
    eyebrow: "Setup and operating guide",
    description:
      "A practical guide to installing Tether, routing provider calls, reading execution paths, using cache, and recovery replay.",
    sections: [
      {
        title: "Quick setup",
        body:
          "Install dependencies, start the web app, run the local proxy, then point your SDK base URL at Tether.",
        bullets: ["Clone the repo", "Run npm install", "Start the web app", "Configure the local proxy"],
      },
      {
        title: "Architecture pages",
        body:
          "The generated docs section now covers the system overview, Rust proxy modules, macOS app modules, CI/CD, releases, local privacy, commands, and API boundaries.",
        bullets: ["System overview", "Rust proxy", "macOS app", "CI/CD and releases"],
      },
    ],
    cta: { label: "Open docs", href: "/docs" },
  },
  {
    slug: "cli-reference",
    title: "CLI reference",
    eyebrow: "Commands for local workflows",
    description:
      "Reference material for running the proxy, packaging the app, validating builds, and debugging local execution paths.",
    sections: [
      {
        title: "Common commands",
        body:
          "The CLI surface is evolving with the proxy. These commands document the local development workflow.",
        bullets: ["npm run dev", "npm run build", "npm run package:dmg", "npm run smoke:e2e"],
      },
      {
        title: "Proxy operations",
        body:
          "Future CLI commands will expose provider setup, cache inspection, trace export, and replay utilities.",
      },
    ],
    cta: { label: "Read changelog", href: "/changelog" },
  },
  {
    slug: "changelog",
    title: "Changelog",
    eyebrow: "Product progress",
    description:
      "A running record of Tether releases, proxy improvements, UI updates, and developer workflow changes.",
    sections: [
      {
        title: "Current alpha",
        body:
          "The current build focuses on the landing experience, waitlist flow, trace UI direction, local proxy skeleton, and response caching.",
        bullets: ["Next.js product site", "macOS app structure", "Rust proxy foundation", "Local cache and trace models"],
      },
      {
        title: "Next releases",
        body:
          "Upcoming entries will track signed downloads, provider adapters, recovery replay, and documentation updates.",
      },
    ],
    cta: { label: "Download alpha", href: "/download" },
  },
  {
    slug: "company",
    title: "Company",
    eyebrow: "Built by Hqz.dev",
    description:
      "Tether is created for developers who need AI systems to feel inspectable, reliable, and worthy of user trust.",
    sections: [
      {
        title: "Our belief",
        body:
          "AI tools should not ask teams to accept mystery as part of the workflow. Great agent products need great debugging surfaces.",
      },
      {
        title: "Our standard",
        body:
          "We care about product craft, local privacy, fast iteration, and interfaces that make complex systems feel understandable.",
      },
    ],
    cta: { label: "Contact us", href: "/contact" },
  },
  {
    slug: "privacy",
    title: "Privacy",
    eyebrow: "Local-first by design",
    description:
      "Tether is built around the principle that prompts, responses, execution traces, and API keys should stay close to the developer.",
    sections: [
      {
        title: "Local trace storage",
        body:
          "Captured agent data is designed to live locally, so sensitive prompts and responses are not uploaded to a third-party dashboard by default.",
      },
      {
        title: "Key handling",
        body:
          "API credentials are handled with macOS Keychain-aware storage patterns instead of plain text project files.",
      },
    ],
    cta: { label: "Read security", href: "/security" },
  },
  {
    slug: "security",
    title: "Security",
    eyebrow: "Trust starts at the machine",
    description:
      "Tether reduces debugging risk by keeping the recovery loop local, explicit, and inspectable.",
    sections: [
      {
        title: "Local evidence, not hosted dashboards",
        body:
          "Tether is built for debugging sensitive agent runs without turning every prompt into another SaaS data copy. The core security claim is narrow: local traces, explicit provider calls, Keychain-backed secrets, and inspectable replay state.",
        bullets: ["Trace database stays on the developer machine", "Provider traffic follows your configured endpoints", "No hosted Tether workspace is required for local debugging"],
      },
      {
        title: "Threat model for the alpha",
        body:
          "The alpha should be evaluated as a local debugging tool, not as a compliance platform. The important questions are whether prompts are copied elsewhere, whether secrets sit in project files, and whether replay changes can be traced back to a concrete node.",
        bullets: ["No claim of SOC 2 or enterprise audit coverage yet", "Local machine compromise remains out of scope", "Provider-side data handling is governed by the provider you choose"],
      },
    ],
    securityMetrics: [
      {
        label: "Local trace artifacts",
        value: "100%",
        detail: "Prompt, response, cache, replay, and metadata records are designed for local SQLite storage.",
        percent: 100,
        tone: "local",
      },
      {
        label: "Required hosted Tether services",
        value: "0",
        detail: "Local debugging does not require a Tether account, cloud dashboard, or remote project sync.",
        percent: 4,
        tone: "local",
      },
      {
        label: "External provider boundary",
        value: "Explicit",
        detail: "Only model-provider requests leave the device, and they follow the provider endpoints you configure.",
        percent: 64,
        tone: "external",
      },
      {
        label: "Compliance posture",
        value: "Alpha",
        detail: "Security posture is architecture-led today; formal certifications are not claimed.",
        percent: 38,
        tone: "audit",
      },
    ],
    securityFlow: [
      {
        label: "Your app",
        detail: "Sends OpenAI-compatible requests to localhost.",
      },
      {
        label: "Local proxy",
        detail: "Captures request metadata and forwards the call.",
      },
      {
        label: "Provider",
        detail: "Receives only the configured model request.",
      },
      {
        label: "Local SQLite",
        detail: "Stores trace, cache, replay, and failure evidence.",
      },
      {
        label: "Inspector",
        detail: "Reads local records for debugging and replay.",
      },
    ],
    securityMatrix: [
      {
        asset: "Prompts",
        location: "Local trace database",
        leavesDevice: "Only inside configured provider requests",
        control: "Request-level inspection",
      },
      {
        asset: "Model responses",
        location: "Local trace database",
        leavesDevice: "No Tether-hosted upload",
        control: "Replay diff and node history",
      },
      {
        asset: "API keys",
        location: "macOS Keychain",
        leavesDevice: "Used only to call chosen providers",
        control: "Keychain-backed secret storage",
      },
      {
        asset: "Cache entries",
        location: "Local cache store",
        leavesDevice: "No remote cache sync",
        control: "Cache hit metadata",
      },
      {
        asset: "Replay edits",
        location: "Local replay state",
        leavesDevice: "No background telemetry path",
        control: "Invalidation and downstream scope",
      },
    ],
    securityRisks: [
      {
        area: "Local data at rest",
        status: "Owned by user machine",
        owner: "Developer",
        nextStep: "Use OS disk encryption and keep workspace access tight.",
      },
      {
        area: "Provider retention",
        status: "Provider-dependent",
        owner: "Configured provider",
        nextStep: "Choose provider settings and contracts that match the data sensitivity.",
      },
      {
        area: "Formal compliance",
        status: "Not claimed",
        owner: "Tether roadmap",
        nextStep: "Add published audit artifacts only when the product surface is stable.",
      },
      {
        area: "Trace export",
        status: "Requires deliberate action",
        owner: "Developer",
        nextStep: "Review exported files before sharing them outside the machine.",
      },
    ],
    reviewRows: [
      {
        control: "Prompt and response storage",
        evidence: "Trace data is written to local SQLite on the developer machine.",
        proof: "~/.Tether/traces.sqlite",
      },
      {
        control: "API key handling",
        evidence: "Provider secrets are stored through macOS Keychain, not in plaintext project files.",
        proof: "macOS Keychain",
      },
      {
        control: "Telemetry posture",
        evidence: "The app does not require a hosted Tether account for local debugging.",
        proof: "No cloud workspace",
      },
      {
        control: "Reproducible failures",
        evidence: "Failed runs can be replayed from a selected node with mocked outputs.",
        proof: "Replay chain",
      },
    ],
    cta: { label: "Contact security", href: "/contact" },
  },
  {
    slug: "contact",
    title: "Contact",
    eyebrow: "Talk to the builder",
    description:
      "Reach out for alpha access, product feedback, security notes, partnerships, or developer workflow questions.",
    sections: [
      {
        title: "Alpha access",
        body:
          "Join through the download page and share what kind of agent system you are building so the product can prioritize the right workflows.",
      },
      {
        title: "Direct feedback",
        body:
          "For now, GitHub is the best place to open issues, track changes, and follow the product as it moves toward a public alpha.",
      },
    ],
    cta: { label: "Open GitHub", href: "https://github.com/Hqzdev/Tether" },
  },
];

/** Lookup map used by the generic static page route. */
export const SITE_PAGE_MAP = new Map(SITE_PAGES.map((page) => [page.slug, page]));
