"use client";

function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Tiny JSON syntax highlighter -> returns an HTML string (ported from the app).
function highlightJSON(line: string): string {
  let s = escapeHtml(line);
  // strings (keys vs values handled by trailing colon)
  s = s.replace(/"(\\.|[^"\\])*"(\s*:)?/g, (m) => {
    if (m.trimEnd().endsWith(":") || /"\s*:$/.test(m)) {
      return (
        '<span class="tk-key">' +
        m.replace(/:\s*$/, "") +
        '</span><span class="tk-punc">:</span>'
      );
    }
    return '<span class="tk-str">' + m + "</span>";
  });
  // numbers
  s = s.replace(
    /(^|[\s[,])(-?\d+\.?\d*)/g,
    (_m, pre: string, num: string) => pre + '<span class="tk-num">' + num + "</span>"
  );
  // booleans / null
  s = s.replace(/\b(true|false)\b/g, '<span class="tk-bool">$1</span>');
  s = s.replace(/\bnull\b/g, '<span class="tk-null">null</span>');
  // punctuation / braces
  s = s.replace(/([{}[\],])/g, '<span class="tk-punc">$1</span>');
  return s;
}

export function CodeBlock({
  text,
  lang,
  broken,
  errorLines,
}: {
  text: string;
  lang: string;
  broken?: boolean;
  errorLines?: number[];
}) {
  const lines = text.split("\n");
  return (
    <div className="code">
      <table>
        <tbody>
          {lines.map((ln, i) => {
            const isErr = errorLines?.includes(i);
            const html = lang === "json" ? highlightJSON(ln) : escapeHtml(ln);
            return (
              <tr key={i}>
                <td className="ln">{i + 1}</td>
                <td
                  className={"cl" + (broken ? " broken" : "")}
                  style={
                    isErr
                      ? {
                          background: "rgba(255,138,164,0.10)",
                          boxShadow: "inset 3px 0 0 var(--pink)",
                        }
                      : undefined
                  }
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
