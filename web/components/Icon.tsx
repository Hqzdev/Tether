"use client";

const ICONS = {
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  settings:
    '<circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M3.6 7l2.6 1.5M17.8 15.5l2.6 1.5M3.6 17l2.6-1.5M17.8 8.5l2.6-1.5"/>',
  key: '<circle cx="7.8" cy="15.7" r="4.3"/><path d="M10.8 12.7 21 2.5M16 7l3 3M14 9l2 2"/>',
  play: '<path d="M7 5l12 7-12 7V5z"/>',
  pause: '<path d="M7 5h3v14H7zM14 5h3v14h-3z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/>',
  moon: '<path d="M20 15.5A8.5 8.5 0 0 1 8.5 4 7 7 0 1 0 20 15.5z"/>',
  layout: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M9 4v16M3 10h18"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  dollar: '<path d="M12 2v20M17 7.5c-1-1-2.6-1.6-4.4-1.6-2.5 0-4.1 1.1-4.1 2.8 0 4.1 8.6 1.8 8.6 6.1 0 1.8-1.7 3.2-4.5 3.2-2.1 0-3.8-.7-4.9-1.8"/>',
  tokens: '<path d="M7 7h10M7 12h10M7 17h10"/><path d="M4 7h.01M4 12h.01M4 17h.01"/>',
  lightbulb:
    '<path d="M9.2 18h5.6M10.3 21h3.4M12 3a6 6 0 0 0-3.8 10.7c.7.6 1.1 1.4 1.2 2.3h5.2c.1-.9.5-1.7 1.2-2.3A6 6 0 0 0 12 3z"/>',
  database:
    '<ellipse cx="12" cy="5.5" rx="7.5" ry="3"/><path d="M4.5 5.5v6c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3v-6M4.5 11.5v6c0 1.66 3.36 3 7.5 3s7.5-1.34 7.5-3v-6"/>',
  link: '<path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/>',
  tool: '<path d="M14.7 6.3a4 4 0 0 0 4.9 4.9l-7.8 7.8a2.1 2.1 0 0 1-3 0l-3.8-3.8a2.1 2.1 0 0 1 0-3l7.8-7.8z"/>',
  error: '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5"/><circle cx="12" cy="16.4" r="0.6" fill="currentColor" stroke="none"/>',
  save: '<path d="M5 3h12l2 2v16H5z"/><path d="M8 3v6h8V3M8 21v-7h8v7"/>',
  timeTravel: '<path d="M3 12a9 9 0 1 0 2.6-6.3M3 4.5v4h4"/><path d="M12 8v4.2l3 1.8"/>',
} as const;

export type IconName = keyof typeof ICONS;

export function Icon({
  name,
  size = 14,
  strokeWidth = 1.8,
  className,
}: {
  name: IconName;
  size?: number;
  strokeWidth?: number;
  className?: string;
}) {
  return (
    <svg
      aria-hidden="true"
      className={className}
      fill="none"
      height={size}
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth={strokeWidth}
      viewBox="0 0 24 24"
      width={size}
      dangerouslySetInnerHTML={{ __html: ICONS[name] }}
    />
  );
}
