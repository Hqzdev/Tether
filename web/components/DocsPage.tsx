"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Icon } from "@/components/Icon";
import {
  DOCS_NAV_GROUPS,
  DOCS_ORDER,
  DOCS_PAGE_MAP,
  type DocsBlock,
  type DocsPage as DocsPageData,
} from "@/lib/docs-pages";
import styles from "./DocsPage.module.css";

const GITHUB_HREF = "https://github.com/Hqzdev/Tether";
const RELEASE_HREF = "https://github.com/Hqzdev/Tether/releases/latest";

function docsHref(slug: string) {
  return slug === "overview" ? "/docs" : `/docs/${slug}`;
}

function sectionId(title: string) {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

function blockSearchText(block: DocsBlock) {
  switch (block.kind) {
    case "paragraph":
      return block.text;
    case "list":
      return block.items.join(" ");
    case "code":
      return `${block.language} ${block.code}`;
    case "table":
      return `${block.headers.join(" ")} ${block.rows.flat().join(" ")}`;
    case "cards":
      return block.cards.map((card) => `${card.title} ${card.text}`).join(" ");
  }
}

function pageSearchText(page?: DocsPageData) {
  if (!page) {
    return "";
  }

  return [
    page.title,
    page.category,
    page.description,
    ...page.sections.flatMap((section) => [
      section.title,
      ...section.blocks.map((block) => blockSearchText(block)),
    ]),
  ].join(" ");
}

async function copyToClipboard(value: string) {
  if (navigator.clipboard?.writeText) {
    try {
      await navigator.clipboard.writeText(value);
      return;
    } catch {
      // Fall back to the selection API below when clipboard permissions are blocked.
    }
  }

  const textArea = document.createElement("textarea");
  textArea.value = value;
  textArea.setAttribute("readonly", "");
  textArea.style.position = "fixed";
  textArea.style.opacity = "0";
  document.body.appendChild(textArea);
  textArea.select();
  document.execCommand("copy");
  document.body.removeChild(textArea);
}

function DocsLogo() {
  return (
    <span className={styles.logoMark} aria-hidden="true">
      <img alt="" height="28" src="/icon-1024.png" width="28" />
    </span>
  );
}

function DocsTopNav() {
  return (
    <header className={styles.topNav}>
      <Link className={styles.brand} href="/">
        <DocsLogo />
        <span>Tether</span>
      </Link>
      <nav className={styles.topLinks} aria-label="Primary">
        <Link className={styles.activeTopLink} href="/docs">
          Docs
        </Link>
        <Link href="/#demo">Demo</Link>
        <Link href="/download">Download</Link>
        <a href={GITHUB_HREF} rel="noreferrer" target="_blank">
          GitHub
        </a>
      </nav>
      <a className={styles.topInstall} href={RELEASE_HREF} rel="noreferrer" target="_blank">
        <Icon name="apple-finder" />
        Install v1.2
      </a>
    </header>
  );
}

function DocsSidebar({
  activeSlug,
  searchQuery,
  onClearSearch,
  onSearchChange,
}: {
  activeSlug: string;
  searchQuery: string;
  onClearSearch: () => void;
  onSearchChange: (value: string) => void;
}) {
  const filteredGroups = useMemo(() => {
    const normalizedQuery = searchQuery.trim().toLowerCase();

    return DOCS_NAV_GROUPS.map((group) => {
      const links = group.links.filter((link) => {
        if (!normalizedQuery) {
          return true;
        }

        const page = DOCS_PAGE_MAP.get(link.slug);
        const haystack = `${group.title} ${link.label} ${pageSearchText(page)}`.toLowerCase();
        return haystack.includes(normalizedQuery);
      });

      return { ...group, links };
    }).filter((group) => group.links.length > 0);
  }, [searchQuery]);

  const resultCount = filteredGroups.reduce((total, group) => total + group.links.length, 0);

  return (
    <aside className={styles.sidebar}>
      <div className={styles.sidebarIntro}>
        <span>Documentation</span>
        <strong>{DOCS_ORDER.length} guides</strong>
      </div>
      <search className={styles.searchBox}>
        <label htmlFor="docs-search">Search docs</label>
        <div className={styles.searchControl}>
          <Icon name="search" />
          <input
            id="docs-search"
            onChange={(event) => onSearchChange(event.target.value)}
            placeholder="Search guides, routes, commands"
            type="search"
            value={searchQuery}
          />
          {searchQuery ? (
            <button type="button" onClick={onClearSearch}>
              Clear
            </button>
          ) : null}
        </div>
      </search>
      <nav className={styles.sidebarNav} aria-label="Documentation">
        {filteredGroups.map((group) => (
          <section className={styles.navGroup} key={group.title}>
            <h2>{group.title}</h2>
            <ul>
              {group.links.map((link) => {
                const active = link.slug === activeSlug;

                return (
                  <li key={link.slug}>
                    <Link
                      aria-current={active ? "page" : undefined}
                      className={active ? styles.activeLink : undefined}
                      href={docsHref(link.slug)}
                    >
                      <span>{link.label}</span>
                      {active ? <Icon name="arrow-right" /> : null}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </section>
        ))}
        {resultCount === 0 ? (
          <p className={styles.emptySearch}>No matching docs. Clear search to see every guide.</p>
        ) : null}
      </nav>
    </aside>
  );
}

function CodeBlock({
  block,
  copiedKey,
  copyKey,
  onCopy,
}: {
  block: Extract<DocsBlock, { kind: "code" }>;
  copiedKey: string | null;
  copyKey: string;
  onCopy: (value: string, key: string) => void;
}) {
  const copied = copiedKey === copyKey;

  return (
    <figure className={styles.codeBlock}>
      <figcaption className={styles.codeHeader}>
        <span>{block.language}</span>
        <button type="button" onClick={() => onCopy(block.code, copyKey)}>
          <Icon name={copied ? "check" : "file-lines"} />
          {copied ? "Copied" : "Copy"}
        </button>
      </figcaption>
      <pre tabIndex={0}>
        <code>{block.code}</code>
      </pre>
    </figure>
  );
}

function DocsTable({ block }: { block: Extract<DocsBlock, { kind: "table" }> }) {
  return (
    <div className={styles.tableWrap}>
      <table>
        <thead>
          <tr>
            {block.headers.map((header) => (
              <th key={header}>{header}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {block.rows.map((row) => (
            <tr key={row.join("|")}>
              {row.map((cell) => (
                <td key={cell}>{cell}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function DocsCards({ block }: { block: Extract<DocsBlock, { kind: "cards" }> }) {
  return (
    <div className={styles.cardGrid}>
      {block.cards.map((card) => (
        <Link className={styles.docCard} href={card.href} key={card.href}>
          <strong>{card.title}</strong>
          <span>{card.text}</span>
          <small>
            Open guide
            <Icon name="arrow-right" />
          </small>
        </Link>
      ))}
    </div>
  );
}

function renderBlock(
  block: DocsBlock,
  key: string,
  copiedKey: string | null,
  onCopy: (value: string, copyKey: string) => void,
) {
  switch (block.kind) {
    case "paragraph":
      return <p key={key}>{block.text}</p>;
    case "list":
      return (
        <ul className={styles.bullets} key={key}>
          {block.items.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ul>
      );
    case "code":
      return <CodeBlock block={block} copiedKey={copiedKey} copyKey={key} key={key} onCopy={onCopy} />;
    case "table":
      return <DocsTable block={block} key={key} />;
    case "cards":
      return <DocsCards block={block} key={key} />;
  }
}

function AdjacentDocs({ page }: { page: DocsPageData }) {
  const index = DOCS_ORDER.indexOf(page.slug);
  const previous = index > 0 ? DOCS_PAGE_MAP.get(DOCS_ORDER[index - 1]) : undefined;
  const next = index >= 0 && index < DOCS_ORDER.length - 1 ? DOCS_PAGE_MAP.get(DOCS_ORDER[index + 1]) : undefined;

  return (
    <nav className={styles.adjacent} aria-label="Adjacent documentation pages">
      {previous ? (
        <Link href={docsHref(previous.slug)}>
          <span>Previous</span>
          <strong>{previous.title}</strong>
        </Link>
      ) : (
        <span />
      )}
      {next ? (
        <Link href={docsHref(next.slug)}>
          <span>Next</span>
          <strong>{next.title}</strong>
        </Link>
      ) : (
        <span />
      )}
    </nav>
  );
}

function PageToc({
  copiedKey,
  onCopy,
  page,
}: {
  copiedKey: string | null;
  onCopy: (value: string, copyKey: string) => void;
  page: DocsPageData;
}) {
  const copyPageLink = () => {
    const href = new URL(docsHref(page.slug), window.location.origin).toString();
    onCopy(href, `page-link-${page.slug}`);
  };

  return (
    <aside className={styles.toc}>
      <nav aria-label="On this page">
        <h2>On this page</h2>
        <ul>
          {page.sections.map((section) => (
            <li key={section.title}>
              <a href={`#${sectionId(section.title)}`}>{section.title}</a>
            </li>
          ))}
        </ul>
      </nav>
      <div className={styles.resourcePanel}>
        <span>Resources</span>
        <a href={RELEASE_HREF} rel="noreferrer" target="_blank">
          <Icon name="apple-finder" />
          Install v1.2
        </a>
        <Link href="/docs/api-reference">
          <Icon name="file-lines" />
          API reference
        </Link>
        <a href={GITHUB_HREF} rel="noreferrer" target="_blank">
          <Icon name="github" />
          GitHub repository
        </a>
        <button type="button" onClick={copyPageLink}>
          <Icon name={copiedKey === `page-link-${page.slug}` ? "check" : "link"} />
          {copiedKey === `page-link-${page.slug}` ? "Copied page link" : "Copy page link"}
        </button>
      </div>
    </aside>
  );
}

export function DocsPage({ page }: { page: DocsPageData }) {
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  const handleCopy = async (value: string, key: string) => {
    await copyToClipboard(value);
    setCopiedKey(key);
    window.setTimeout(() => {
      setCopiedKey((currentKey) => (currentKey === key ? null : currentKey));
    }, 1600);
  };

  const copyPageLink = () => {
    const href = new URL(docsHref(page.slug), window.location.origin).toString();
    handleCopy(href, `hero-page-link-${page.slug}`);
  };

  return (
    <div className={styles.docsShell}>
      <DocsTopNav />
      <div className={styles.layout}>
        <DocsSidebar
          activeSlug={page.slug}
          onClearSearch={() => setSearchQuery("")}
          onSearchChange={setSearchQuery}
          searchQuery={searchQuery}
        />
        <main className={styles.article}>
          <div className={styles.breadcrumb}>
            <Link href="/">Home</Link>
            <span>/</span>
            <Link href="/docs">Docs</Link>
            <span>/</span>
            <span>{page.title}</span>
          </div>
          <header className={styles.hero}>
            <span className={styles.category}>{page.category}</span>
            <h1>{page.title}</h1>
            <p>{page.description}</p>
            <div className={styles.heroActions}>
              <a className={styles.primaryAction} href={RELEASE_HREF} rel="noreferrer" target="_blank">
                <Icon name="apple-finder" />
                Install v1.2
              </a>
              <Link className={styles.secondaryAction} href="/docs/install">
                Setup steps
              </Link>
              <button className={styles.secondaryAction} type="button" onClick={copyPageLink}>
                <Icon name={copiedKey === `hero-page-link-${page.slug}` ? "check" : "link"} />
                {copiedKey === `hero-page-link-${page.slug}` ? "Copied" : "Copy link"}
              </button>
            </div>
            <dl className={styles.metaStrip}>
              <div>
                <dt>Version</dt>
                <dd>v1.2 alpha</dd>
              </div>
              <div>
                <dt>Runtime</dt>
                <dd>macOS + local proxy</dd>
              </div>
              <div>
                <dt>Docs</dt>
                <dd>{DOCS_ORDER.length} guides</dd>
              </div>
            </dl>
          </header>
          <div className={styles.sections}>
            {page.sections.map((section, sectionIndex) => {
              const id = sectionId(section.title);

              return (
                <section className={styles.section} id={id} key={section.title}>
                  <h2>
                    <a href={`#${id}`}>{section.title}</a>
                  </h2>
                  {section.blocks.map((block, blockIndex) =>
                    renderBlock(block, `${page.slug}-${sectionIndex}-${blockIndex}`, copiedKey, handleCopy),
                  )}
                </section>
              );
            })}
          </div>
          <AdjacentDocs page={page} />
        </main>
        <PageToc copiedKey={copiedKey} onCopy={handleCopy} page={page} />
      </div>
    </div>
  );
}
