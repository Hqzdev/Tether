"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Icon } from "@/components/Icon";
import { trackEvent } from "@/lib/analytics";

const PRODUCT_LINKS = [
  { label: "Features", href: "/features" },
  { label: "Inspector", href: "/inspector" },
  { label: "How it works", href: "/how-it-works" },
  { label: "Download", href: "/download" },
];

const DEVELOPER_LINKS = [
  { label: "Documentation", href: "/documentation" },
  { label: "CLI reference", href: "/cli-reference" },
  { label: "Changelog", href: "/changelog" },
  { label: "GitHub", href: "https://github.com/Hqzdev/Tether", external: true },
];

const COMPANY_LINKS = [
  { label: "Privacy", href: "/privacy" },
  { label: "Security", href: "/security" },
  { label: "Contact", href: "/contact" },
];

function LogoMark() {
  return (
    <img
      alt=""
      aria-hidden="true"
      decoding="async"
      height="28"
      src="/Tether.PNG"
      width="28"
    />
  );
}

function FooterLink({ href, label, external = false }: { href: string; label: string; external?: boolean }) {
  if (external) {
    return (
      <a
        href={href}
        onClick={() => trackEvent("navigation_clicked", { label, location: "footer" })}
        rel="noreferrer"
        target="_blank"
      >
        {label}
      </a>
    );
  }

  return (
    <Link href={href} onClick={() => trackEvent("navigation_clicked", { label, location: "footer" })}>
      {label}
    </Link>
  );
}

export function SiteHeader() {
  const [navStuck, setNavStuck] = useState(false);

  useEffect(() => {
    const onScroll = () => setNavStuck(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <nav className={`nav ${navStuck ? "stuck" : ""}`} id="nav">
      <div className="wrap nav-inner">
        <Link className="brand" href="/">
          <span className="logo">
            <LogoMark />
          </span>
          Tether
        </Link>
        <div className="nav-links">
          <Link href="/features" onClick={() => trackEvent("navigation_clicked", { label: "Features", location: "header" })}>
            Features
          </Link>
          <Link href="/inspector" onClick={() => trackEvent("navigation_clicked", { label: "Inspector", location: "header" })}>
            Inspector
          </Link>
          <Link href="/how-it-works" onClick={() => trackEvent("navigation_clicked", { label: "How it works", location: "header" })}>
            How it works
          </Link>
          <Link href="/download" onClick={() => trackEvent("navigation_clicked", { label: "Download", location: "header" })}>
            Download
          </Link>
        </div>
      </div>
    </nav>
  );
}

export function SiteFooter() {
  return (
    <footer className="footer wrap">
      <div className="foot-grid">
        <div className="foot-brand">
          <Link className="brand" href="/">
            <span className="logo">
              <LogoMark />
            </span>
            Tether
          </Link>
          <p>
            Local-first observability and mocking for LLM agents. Built for developers who refuse to debug in
            the dark.
          </p>
        </div>
        <div className="foot-col">
          <h5>
            <Link href="/product">Product</Link>
          </h5>
          {PRODUCT_LINKS.map((link) => (
            <FooterLink href={link.href} key={link.href} label={link.label} />
          ))}
        </div>
        <div className="foot-col">
          <h5>
            <Link href="/developers">Developers</Link>
          </h5>
          {DEVELOPER_LINKS.map((link) => (
            <FooterLink
              external={link.external}
              href={link.href}
              key={link.href}
              label={link.label}
            />
          ))}
        </div>
        <div className="foot-col">
          <h5>
            <Link href="/company">Company</Link>
          </h5>
          {COMPANY_LINKS.map((link) => (
            <FooterLink href={link.href} key={link.href} label={link.label} />
          ))}
        </div>
      </div>
      <div className="foot-bottom">
        <span>&copy; 2026 Tether - Crafted for the Mac</span>
        <span>
          <Icon className="ic" name="arrow-right" strokeWidth={1.7} /> All systems local
        </span>
      </div>
    </footer>
  );
}
