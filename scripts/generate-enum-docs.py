#!/usr/bin/env python3
"""Generate standalone HTML documentation for CreditTimeline enum definitions."""
import json
import sys
from datetime import datetime, timezone
from html import escape
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        print("Usage: generate-enum-docs.py <enums.json> <output.html>", file=sys.stderr)
        raise SystemExit(2)

    enums_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    if not enums_path.exists():
        print(f"Error: Enums file not found: {enums_path}", file=sys.stderr)
        raise SystemExit(1)

    try:
        schema = json.loads(enums_path.read_text())
    except json.JSONDecodeError as e:
        print(f"Error: Failed to parse JSON: {e}", file=sys.stderr)
        raise SystemExit(1)

    defs = schema.get("$defs", {})
    title = schema.get("title", "Enumerations")

    if not defs:
        print(f"Warning: No definitions found in $defs", file=sys.stderr)

    # Sort alphabetically by key name
    sorted_names = sorted(defs.keys())
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # Build table of contents
    toc_links = []
    for name in sorted_names:
        toc_links.append(f'<a href="#{escape(name)}">{escape(name)}</a>')
    toc_html = " &middot;\n        ".join(toc_links)

    # Build entry cards
    cards = []
    for name in sorted_names:
        defn = defs[name]
        desc = escape(defn.get("description", ""))

        if "enum" in defn:
            # Render enum values as pill-styled chips
            values_html = "\n".join(
                f'        <li>{escape(str(v))}</li>' for v in defn["enum"]
            )
            body = f'<ul class="enum-values">\n{values_html}\n      </ul>'
        elif "pattern" in defn:
            # Render regex pattern as monospace code span
            body = f'<p>Pattern: <span class="pattern-value">{escape(defn["pattern"])}</span></p>'
        else:
            # Fallback for unknown definition types
            body = f'<p class="enum-description">Type: {escape(defn.get("type", "unknown"))}</p>'

        cards.append(f"""    <div class="card" id="{escape(name)}">
      <h2>{escape(name)}</h2>
      <p class="enum-description">{desc}</p>
      {body}
    </div>""")

    cards_html = "\n\n".join(cards)

    # Generate full HTML using project's design tokens
    html = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{escape(title)}</title>
    <style>
      :root {{
        --bg: #f6f8fb;
        --fg: #10243e;
        --muted: #4a617f;
        --card: #ffffff;
        --accent: #0054a6;
      }}
      body {{
        margin: 0;
        padding: 2rem;
        background: var(--bg);
        color: var(--fg);
        font-family: "Avenir Next", "Segoe UI", sans-serif;
      }}
      main {{
        max-width: 900px;
        margin: 0 auto;
      }}
      .card {{
        background: var(--card);
        border-radius: 14px;
        padding: 1.25rem 1.5rem;
        box-shadow: 0 10px 30px rgba(16, 36, 62, 0.08);
        margin-bottom: 1.5rem;
      }}
      h1 {{
        margin-top: 0;
      }}
      h2 {{
        margin-top: 0;
        color: var(--fg);
        font-size: 1.1rem;
      }}
      .meta {{
        color: var(--muted);
        margin-bottom: 1rem;
      }}
      a {{
        color: var(--accent);
      }}
      .enum-description {{
        color: var(--muted);
        margin: 0.5rem 0 0.75rem;
      }}
      .enum-values {{
        display: flex;
        flex-wrap: wrap;
        gap: 0.4rem;
        padding: 0;
        list-style: none;
        margin: 0;
      }}
      .enum-values li {{
        background: var(--bg);
        border-radius: 6px;
        padding: 0.25rem 0.6rem;
        font-family: "SF Mono", "Fira Code", monospace;
        font-size: 0.85rem;
      }}
      .pattern-value {{
        font-family: "SF Mono", "Fira Code", monospace;
        font-size: 0.85rem;
        background: var(--bg);
        border-radius: 6px;
        padding: 0.25rem 0.6rem;
        display: inline-block;
      }}
      .toc {{
        line-height: 1.8;
      }}
      .toc a {{
        text-decoration: none;
      }}
      .toc a:hover {{
        text-decoration: underline;
      }}
    </style>
  </head>
  <body>
    <main>
      <div class="card">
        <h1>{escape(title)}</h1>
        <p class="meta">{len(sorted_names)} definitions &middot; Generated at {generated_at}</p>
        <p class="meta"><a href="./credittimeline-file.v1.schema.html">&larr; Back to Transport Schema</a></p>
        <div class="toc">
        {toc_html}
        </div>
      </div>

{cards_html}
    </main>
  </body>
</html>
"""

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html)
    print(f"Enum documentation written to: {output_path}")


if __name__ == "__main__":
    main()
