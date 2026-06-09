"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Icon } from "@/components/Icon";

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
      <a href={href} rel="noreferrer" target="_blank">
        {label}
      </a>
    );
  }

  return <Link href={href}>{label}</Link>;
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
          <Link href="/features">Features</Link>
          <Link href="/inspector">Inspector</Link>
          <Link href="/how-it-works">How it works</Link>
          <Link href="/download">Download</Link>
        </div>
        <div className="nav-right">
          <Link className="gh-pill" href="/download" aria-label="Get the Tether alpha build">
            <Icon className="ic" name="circle" strokeWidth={1.7} />
            Alpha build
          </Link>
          <Link className="btn btn-primary btn-sm" href="/download">
            <Icon className="ic" name="apple" strokeWidth={1.7} />
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
