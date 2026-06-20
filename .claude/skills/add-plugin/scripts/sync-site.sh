#!/usr/bin/env bash
# sync-site.sh — regenerate site/ from marketplace.json. (writes site/)
#
# Projects .claude-plugin/marketplace.json into:
#   site/index.html   — one card per plugin (or empty-state if plugins:[])
#   site/sitemap.xml  — single <url> for the canonical root
#   site/robots.txt   — User-agent: * Allow: / + Sitemap reference
#   site/assets/favicon.svg is a static committed asset — NOT regenerated.
#
# Deterministic: stable entry order (manifest order), fixed build-date constant
# (SITE_BUILD_DATE below — never `date`), no network, no side effects on import.
#
# All manifest strings are routed through html_esc() before interpolation.
# The JSON-LD block is built with `jq -n` (proper JSON encoding), never string-concat.
#
# With --check: regenerates to a temp dir, diffs against site/, exits 1 on any drift.
# Used by tests/gates/18-pages-in-sync.sh — the gate uses this to prove site/ matches
# the manifest.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

check=false
[ "${1:-}" = "--check" ] && check=true

root="$(mk_repo_root)"
manifest="$root/$MK_MANIFEST"
site_dir="$root/site"

# ── Constants ─────────────────────────────────────────────────────────────────
# Pinned build date — operator bumps this when re-publishing. Never use `date`
# (that would break byte-equality in --check mode).
SITE_BUILD_DATE="2026-06-20"
CANONICAL_URL="https://odere-pro.github.io/claude-software-3-0-marketplace/"
GITHUB_REPO_URL="https://github.com/odere-pro/claude-software-3-0-marketplace"

# ── HTML escape helper ────────────────────────────────────────────────────────
# Escapes &, <, >, ", ' for safe interpolation into HTML attribute values and text.
# Every manifest string that lands in HTML MUST pass through this function.
html_esc() {
  printf '%s' "$1" \
    | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g'
}

# ── Read manifest fields ──────────────────────────────────────────────────────
mp_name="$(jq -r '.name' "$manifest")"
mp_desc="$(jq -r '.description' "$manifest")"
mp_desc_esc="$(html_esc "$mp_desc")"
mp_name_esc="$(html_esc "$mp_name")"
n_plugins="$(jq '.plugins | length' "$manifest")"

# Union of all entry keywords (deduped, sorted), for head <meta name="keywords">.
# mk_each_plugin_ndjson normalizes .keywords (null → []) — shared projection helper (W2.3).
all_keywords="$(mk_each_plugin_ndjson "$manifest" | jq -rs '[.[].keywords | .[]] | unique | join(", ")')"
if [ -z "$all_keywords" ]; then
  all_keywords="claude code plugin, marketplace, agent-operable, software 3.0"
fi
all_keywords_esc="$(html_esc "$all_keywords")"

# ── Generate to temp dir ──────────────────────────────────────────────────────
tmpdir="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$tmpdir'" EXIT

# ── JSON-LD block (built with jq -n — proper JSON, never string-concat) ──────
# Build the plugins ItemList elements array.
# mk_each_plugin_ndjson normalizes .homepage and .license (shared projection helper, W2.3).
plugins_json_ld="$(mk_each_plugin_ndjson "$manifest" | jq -rs '
  to_entries | map(
    .key as $i |
    .value as $p |
    {
      "@type": "ListItem",
      "position": ($i + 1),
      "item": {
        "@type": "SoftwareApplication",
        "name": $p.name,
        "description": $p.description,
        "url": $p.homepage,
        "applicationCategory": "DeveloperApplication",
        "license": ("https://spdx.org/licenses/" + (if $p.license == "—" then "MIT" else $p.license end) + ".html")
      }
    }
  )
')"

n_items="$n_plugins"

json_ld="$(jq -n \
  --arg canonical "$CANONICAL_URL" \
  --arg mp_name "$mp_name" \
  --arg mp_desc "$mp_desc" \
  --arg github_url "$GITHUB_REPO_URL" \
  --argjson n_items "$n_items" \
  --argjson items "$plugins_json_ld" \
  '{
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebSite",
        "@id": ($canonical + "#website"),
        "url": $canonical,
        "name": $mp_name,
        "description": $mp_desc,
        "inLanguage": "en",
        "publisher": {
          "@id": "https://github.com/odere-pro#organization"
        }
      },
      {
        "@type": "Organization",
        "@id": "https://github.com/odere-pro#organization",
        "name": "odere-pro",
        "url": "https://github.com/odere-pro",
        "sameAs": [
          "https://github.com/odere-pro",
          $github_url
        ]
      },
      {
        "@type": "CollectionPage",
        "@id": ($canonical + "#plugins"),
        "url": $canonical,
        "name": ($mp_name + " — Claude Code plugin marketplace"),
        "description": $mp_desc,
        "mainEntity": {
          "@type": "ItemList",
          "numberOfItems": $n_items,
          "itemListElement": $items
        }
      },
      {
        "@type": "BreadcrumbList",
        "@id": ($canonical + "#breadcrumbs"),
        "itemListElement": [
          {
            "@type": "ListItem",
            "position": 1,
            "name": "Home",
            "item": $canonical
          },
          {
            "@type": "ListItem",
            "position": 2,
            "name": "Plugins",
            "item": ($canonical + "#plugins")
          }
        ]
      }
    ]
  }')"

# Neutralize script-context breakout in the JSON-LD block.
# jq produces valid JSON but does NOT HTML-escape, so a field containing "</script>"
# would close the enclosing <script> element early when rendered by a browser.
# Replace every "</" with "<\/" — this is valid JSON (forward slashes may be escaped)
# and prevents "</script>" from being recognised as an HTML tag by any parser.
# The resulting block still parses as valid JSON (jq and JSON.parse both accept "\/").
json_ld="$(printf '%s' "$json_ld" | sed 's|</|<\\/|g')"

# ── Plugin cards (or empty-state) ─────────────────────────────────────────────
if [ "$n_plugins" -eq 0 ]; then
  plugin_cards='        <article class="card empty-state">
          <h3>No plugins listed yet</h3>
          <p>The registry is being set up. Add the first plugin by submitting a request or using
          <code>/add-plugin &lt;repo&gt;</code>.</p>
          <p>
            <a href="https://github.com/odere-pro/claude-software-3-0-marketplace/blob/main/docs/adding-plugins.md">How to add a plugin →</a>
          </p>
          <p>
            <a href="https://github.com/odere-pro/claude-software-3-0-marketplace/issues/new?template=submit-plugin.yml">Submit a plugin →</a>
          </p>
        </article>'
else
  # mk_each_plugin_ndjson provides pre-normalized fields (.homepage, .license, .keywords) — W2.3.
  # ALL manifest-derived strings are HTML-escaped before interpolation (& < > " ').
  # .homepage is additionally validated: only https:// URLs are emitted as href; anything else
  # drops the link entirely (renders the name as plain text) to prevent attribute injection.
  # data-keywords carries the space-joined keyword list (HTML-escaped) for client-side filtering.
  plugin_cards="$(mk_each_plugin_ndjson "$manifest" | jq -r '
    def html_esc: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("'"'"'"; "&#39;");
    def safe_href: if test("^https://") then html_esc else "" end;
    (.homepage | safe_href) as $hp_esc |
    (.name | html_esc) as $name_esc |
    (.description | html_esc) as $desc_esc |
    (.license | html_esc) as $lic_esc |
    (.keywords | map(html_esc) | join(" ")) as $kw_data |
    "        <article class=\"card\" data-keywords=\"" + $kw_data + "\">\n" +
    "          <h3>" +
      (if $hp_esc != "" then "<a href=\"" + $hp_esc + "\">" + $name_esc + "</a>" else $name_esc end) +
    "</h3>\n" +
    "          <p class=\"card-desc\">" + $desc_esc + "</p>\n" +
    "          <pre class=\"install-cmd\"><code>claude plugin install " + $name_esc + "@odere-pro --scope project\nclaude plugin update " + $name_esc + "@odere-pro --scope project</code></pre>\n" +
    "          <div class=\"card-meta\">\n" +
    "            <span class=\"license\">" + $lic_esc + "</span>\n" +
    (if .keywords | length > 0 then
      "            <span class=\"keywords\">" + (.keywords | map("<span class=\"chip\">" + (. | html_esc) + "</span>") | join("")) + "</span>\n"
    else "" end) +
    "          </div>\n" +
    "        </article>"
  ')"
fi

# ── Keyword filter toolbar (non-empty registry only) ──────────────────────────
# Derives keyword buckets from existing keywords[] — no manifest field (D6).
# Stable: unique|sort (matches the all_keywords line above).
# Renders cleanly at N=0: empty filter_toolbar string = no toolbar in the HTML.
filter_toolbar=""
filter_script=""
filter_css=""
if [ "$n_plugins" -gt 0 ]; then
  # Build an array of unique sorted keywords (already computed in all_keywords, rebuild explicitly).
  kw_buttons=""
  while IFS= read -r kw; do
    [ -z "$kw" ] && continue
    kw_esc="$(html_esc "$kw")"
    kw_buttons="${kw_buttons}        <button class=\"filter-btn\" type=\"button\" data-kw=\"${kw_esc}\" aria-pressed=\"false\">${kw_esc}</button>
"
  done <<EOF
$(mk_each_plugin_ndjson "$manifest" | jq -rs '[.[].keywords[]] | unique | sort[]')
EOF

  filter_toolbar="      <div class=\"filter-bar\" role=\"group\" aria-label=\"Filter plugins by keyword\">
        <span class=\"filter-label\">Filter:</span>
${kw_buttons}        <button class=\"filter-btn filter-btn-all\" type=\"button\" data-kw=\"\" aria-pressed=\"true\">All</button>
      </div>"

  # Inline filter script — no remote src (offline, G18 group-2).
  # Toggles aria-pressed on buttons and shows/hides cards by data-keywords match.
  filter_script='    <script>
      (function () {
        var active = "";
        document.querySelectorAll(".filter-btn").forEach(function (btn) {
          btn.addEventListener("click", function () {
            active = btn.dataset.kw;
            document.querySelectorAll(".filter-btn").forEach(function (b) {
              b.setAttribute("aria-pressed", b.dataset.kw === active ? "true" : "false");
            });
            document.querySelectorAll(".grid .card").forEach(function (card) {
              if (!active) {
                card.hidden = false;
              } else {
                var kws = card.dataset.keywords ? card.dataset.keywords.split(" ") : [];
                card.hidden = kws.indexOf(active) === -1;
              }
            });
          });
        });
      })();
    </script>'

  # CSS for the filter bar (inline, no remote link).
  filter_css='
      .filter-bar {
        display: flex;
        flex-wrap: wrap;
        gap: 0.4rem;
        margin-bottom: 1.4rem;
        align-items: center;
      }

      .filter-label {
        font-family: var(--font-mono);
        font-size: 0.8rem;
        color: var(--color-muted);
        margin-right: 0.3rem;
      }

      .filter-btn {
        font-family: var(--font-mono);
        font-size: 0.75rem;
        color: var(--color-text);
        background: var(--color-surface);
        border: 1px solid var(--color-line);
        border-radius: 999px;
        padding: 0.25rem 0.7rem;
        cursor: pointer;
        transition: background var(--ease) 150ms, color var(--ease) 150ms, border-color var(--ease) 150ms;
      }

      .filter-btn:hover {
        border-color: var(--color-accent-line);
        color: var(--color-accent);
      }

      .filter-btn[aria-pressed="true"] {
        background: var(--color-accent-soft);
        border-color: var(--color-accent-line);
        color: var(--color-accent);
      }

      .card[hidden] {
        display: none;
      }'
fi

pills_n="${n_plugins} plugin$([ "$n_plugins" -eq 1 ] || printf 's')"

# ── index.html ────────────────────────────────────────────────────────────────
cat >"$tmpdir/index.html" <<HTMLEOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />

    <title>${mp_name_esc} — Claude Code plugin marketplace</title>
    <meta
      name="description"
      content="${mp_desc_esc}"
    />
    <link rel="canonical" href="${CANONICAL_URL}" />
    <meta name="theme-color" content="#1c1714" />
    <meta name="color-scheme" content="dark light" />
    <meta name="application-name" content="${mp_name_esc}" />
    <meta name="author" content="odere-pro" />
    <meta
      name="keywords"
      content="${all_keywords_esc}"
    />
    <meta
      name="robots"
      content="index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1"
    />

    <link rel="icon" href="assets/favicon.svg" type="image/svg+xml" />

    <!-- Open Graph -->
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="${mp_name_esc}" />
    <meta property="og:locale" content="en_US" />
    <meta
      property="og:title"
      content="${mp_name_esc} — Claude Code plugin marketplace"
    />
    <meta
      property="og:description"
      content="${mp_desc_esc}"
    />
    <meta property="og:url" content="${CANONICAL_URL}" />

    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta
      name="twitter:title"
      content="${mp_name_esc} — Claude Code plugin marketplace"
    />
    <meta
      name="twitter:description"
      content="${mp_desc_esc}"
    />

    <!-- Structured data -->
    <script type="application/ld+json">
      ${json_ld}
    </script>

    <style>
      :root {
        --color-bg: oklch(22% 0.012 50);
        --color-bg-raised: oklch(27% 0.016 52);
        --color-surface: oklch(31% 0.02 54);
        --color-text: oklch(92% 0.012 70);
        --color-muted: oklch(76% 0.022 62);
        --color-accent: oklch(70% 0.13 45);
        --color-accent-soft: oklch(70% 0.13 45 / 0.16);
        --color-accent-line: oklch(70% 0.13 45 / 0.4);
        --color-line: oklch(40% 0.02 55);

        --text-hero: clamp(2.6rem, 1.4rem + 5vw, 5.5rem);
        --text-lead: clamp(1.1rem, 0.96rem + 0.6vw, 1.4rem);
        --text-h2: clamp(1.6rem, 1.2rem + 1.5vw, 2.4rem);
        --space-section: clamp(3.5rem, 2.5rem + 5vw, 7rem);

        --radius: 14px;
        --radius-sm: 9px;
        --ease: cubic-bezier(0.16, 1, 0.3, 1);

        --font-sans:
          ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Helvetica,
          Arial, sans-serif;
        --font-mono:
          ui-monospace, "SF Mono", "JetBrains Mono", "Fira Code", Menlo, Consolas,
          monospace;
      }

      * {
        box-sizing: border-box;
      }

      html {
        scroll-behavior: smooth;
        scroll-padding-top: 5rem;
      }

      body {
        margin: 0;
        background:
          radial-gradient(
            120% 80% at 75% -10%,
            var(--color-accent-soft),
            transparent 60%
          ),
          var(--color-bg);
        color: var(--color-text);
        font-family: var(--font-sans);
        line-height: 1.55;
        -webkit-font-smoothing: antialiased;
      }

      a {
        color: inherit;
      }

      :focus-visible {
        outline: 2px solid var(--color-accent);
        outline-offset: 3px;
        border-radius: 4px;
      }

      .wrap {
        width: min(1100px, 92vw);
        margin-inline: auto;
      }

      .vh {
        position: absolute;
        width: 1px;
        height: 1px;
        padding: 0;
        margin: -1px;
        overflow: hidden;
        clip: rect(0 0 0 0);
        white-space: nowrap;
        border: 0;
      }

      .skip-link {
        position: absolute;
        left: 0.5rem;
        top: 0.5rem;
        z-index: 50;
        transform: translateY(-160%);
        background: var(--color-accent);
        color: oklch(20% 0.02 50);
        padding: 0.6rem 1rem;
        border-radius: var(--radius-sm);
        font-weight: 600;
        text-decoration: none;
        transition: transform var(--ease) 200ms;
      }

      .skip-link:focus {
        transform: translateY(0);
      }

      header {
        position: sticky;
        top: 0;
        z-index: 40;
        background: oklch(22% 0.012 50 / 0.82);
        backdrop-filter: saturate(140%) blur(10px);
        border-bottom: 1px solid var(--color-line);
      }

      nav {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
        gap: 0.4rem 1.2rem;
        padding-block: 0.9rem;
      }

      .brand {
        font-family: var(--font-mono);
        font-weight: 700;
        font-size: 1.15rem;
        letter-spacing: -0.02em;
        text-decoration: none;
      }

      .brand span {
        color: var(--color-accent);
      }

      nav .spacer {
        flex: 1;
      }

      nav a:not(.brand) {
        display: inline-flex;
        align-items: center;
        min-height: 44px;
        padding-inline: 0.35rem;
        text-decoration: none;
        color: var(--color-muted);
        font-size: 0.95rem;
        transition: color var(--ease) 200ms;
      }

      nav a:not(.brand):hover,
      nav a:not(.brand):focus-visible {
        color: var(--color-text);
      }

      .hero {
        padding-block: var(--space-section);
      }

      h1 {
        font-size: var(--text-hero);
        line-height: 0.98;
        letter-spacing: -0.03em;
        margin: 0 0 1.4rem;
        max-width: 18ch;
      }

      .lead {
        font-size: var(--text-lead);
        color: var(--color-muted);
        max-width: 58ch;
        margin: 0 0 1.8rem;
      }

      .pills {
        list-style: none;
        display: flex;
        flex-wrap: wrap;
        gap: 0.6rem;
        margin: 0 0 2rem;
        padding: 0;
      }

      .pills li {
        font-family: var(--font-mono);
        font-size: 0.8rem;
        color: var(--color-text);
        background: var(--color-surface);
        border: 1px solid var(--color-line);
        border-radius: 999px;
        padding: 0.35rem 0.85rem;
      }

      section.band {
        padding-block: var(--space-section);
        border-top: 1px solid var(--color-line);
      }

      .h2 {
        font-size: var(--text-h2);
        letter-spacing: -0.02em;
        margin: 0 0 0.6rem;
      }

      .section-lead {
        color: var(--color-muted);
        max-width: 62ch;
        margin: 0 0 2.6rem;
        font-size: 1.02rem;
      }

      .kicker {
        font-family: var(--font-mono);
        font-size: 0.8rem;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--color-accent);
        margin: 0 0 0.8rem;
      }

      .grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(min(280px, 100%), 1fr));
        gap: 1px;
        background: var(--color-line);
        border: 1px solid var(--color-line);
        border-radius: var(--radius);
        overflow: hidden;
      }

      .card {
        background: var(--color-bg-raised);
        padding: 1.6rem 1.5rem;
      }

      .card h3 {
        margin: 0 0 0.5rem;
        font-size: 1.1rem;
        font-family: var(--font-mono);
        color: var(--color-accent);
      }

      .card h3 a {
        text-decoration: none;
        color: inherit;
      }

      .card h3 a:hover {
        text-decoration: underline;
      }

      .card p,
      .card .card-desc {
        margin: 0 0 0.8rem;
        color: var(--color-muted);
        font-size: 0.96rem;
      }

      .install-cmd {
        margin: 0 0 0.8rem;
        padding: 0.6rem 0.9rem;
        background: oklch(16% 0.01 50);
        border: 1px solid var(--color-line);
        border-radius: var(--radius-sm);
        font-family: var(--font-mono);
        font-size: 0.88rem;
        color: var(--color-text);
        overflow-x: auto;
      }

      .card-meta {
        display: flex;
        flex-wrap: wrap;
        gap: 0.4rem;
        align-items: center;
      }

      .license {
        font-family: var(--font-mono);
        font-size: 0.75rem;
        color: var(--color-muted);
        background: var(--color-surface);
        border: 1px solid var(--color-line);
        border-radius: 999px;
        padding: 0.2rem 0.6rem;
      }

      .keywords {
        display: flex;
        flex-wrap: wrap;
        gap: 0.3rem;
      }

      .chip {
        font-family: var(--font-mono);
        font-size: 0.72rem;
        color: var(--color-text);
        background: var(--color-surface);
        border: 1px solid var(--color-line);
        border-radius: 6px;
        padding: 0.15rem 0.45rem;
      }

      .empty-state {
        grid-column: 1 / -1;
      }

      .empty-state h3 {
        color: var(--color-muted);
      }

      .add-marketplace {
        background: var(--color-bg-raised);
        border: 1px solid var(--color-line);
        border-left: 3px solid var(--color-accent);
        border-radius: var(--radius);
        padding: 1.6rem 1.6rem 1.4rem;
        margin-bottom: 2rem;
      }

      .h3 {
        font-family: var(--font-mono);
        font-size: 1.05rem;
        letter-spacing: -0.01em;
        color: var(--color-text);
        margin: 2.2rem 0 0.4rem;
      }

      .req-list {
        margin: 0;
        padding-left: 1.2rem;
        color: var(--color-muted);
        font-size: 1.02rem;
      }

      .req-list li {
        margin-bottom: 0.6rem;
      }

      .req-list strong {
        color: var(--color-text);
      }

      .faq details {
        background: var(--color-bg-raised);
        border: 1px solid var(--color-line);
        border-radius: var(--radius-sm);
        padding: 0 1.2rem;
        margin-bottom: 0.6rem;
      }

      .faq summary {
        cursor: pointer;
        padding: 0.95rem 0;
        font-weight: 600;
        color: var(--color-text);
      }

      .faq summary:hover {
        color: var(--color-accent);
      }

      .faq details[open] summary {
        color: var(--color-accent);
        border-bottom: 1px solid var(--color-line);
      }

      .faq details > p {
        color: var(--color-muted);
        font-size: 0.96rem;
      }

      .faq details > pre {
        margin-bottom: 1rem;
      }

      pre {
        margin: 0;
        padding: 1.4rem 1.5rem;
        background: oklch(16% 0.01 50);
        border: 1px solid var(--color-line);
        border-radius: var(--radius);
        max-width: 100%;
        overflow-x: auto;
        font-family: var(--font-mono);
        font-size: 0.95rem;
        line-height: 1.7;
        color: var(--color-text);
      }

      footer {
        padding-block: 2.5rem;
        border-top: 1px solid var(--color-line);
        color: var(--color-muted);
        font-size: 0.9rem;
        display: flex;
        flex-wrap: wrap;
        gap: 0.4rem 1rem;
        align-items: center;
      }

      footer .spacer {
        flex: 1;
      }

      footer a {
        display: inline-flex;
        align-items: center;
        min-height: 44px;
        padding-inline: 0.35rem;
        color: var(--color-muted);
        text-decoration: none;
      }

      footer a:hover {
        color: var(--color-text);
      }

      @media (prefers-reduced-motion: reduce) {
        html {
          scroll-behavior: auto;
        }
        *,
        *::before,
        *::after {
          transition: none !important;
          animation: none !important;
        }
      }
${filter_css}
    </style>
  </head>
  <body>
    <a class="skip-link" href="#main">Skip to content</a>

    <header>
      <nav class="wrap" aria-label="Primary">
        <a class="brand" href="#main">odere<span>-pro</span></a>
        <span class="spacer"></span>
        <a href="#requirements">Requirements</a>
        <a href="#install">Install</a>
        <a href="#plugins">Plugins</a>
        <a href="#faq">FAQ</a>
        <a href="${GITHUB_REPO_URL}">GitHub</a>
      </nav>
    </header>

    <main id="main">
      <section class="hero wrap" aria-labelledby="hero-heading">
        <h1 id="hero-heading">Claude Code plugins, one marketplace.</h1>
        <p class="lead">${mp_desc_esc}</p>
        <ul class="pills" aria-label="At a glance">
          <li>${pills_n}</li>
          <li>agent-operable</li>
          <li>one contract</li>
          <li>gates-not-promises</li>
        </ul>
      </section>

      <section
        class="band wrap"
        id="requirements"
        aria-labelledby="requirements-heading"
      >
        <p class="kicker">Before you start</p>
        <h2 class="h2" id="requirements-heading">Requirements</h2>
        <p class="section-lead">
          A short checklist — the <a href="#faq">FAQ</a> has one-line install pointers for each.
        </p>
        <ul class="req-list">
          <li><strong>Claude Code with a working <code>/plugin</code> command.</strong> It's generally available — if you don't see it, <a href="https://docs.claude.com/en/docs/claude-code/setup">update Claude Code</a>.</li>
          <li><strong><code>git</code></strong> and <strong><code>bash</code></strong> on your <code>PATH</code>.</li>
          <li>A few plugins also need <strong>Node.js / Bun</strong> or <strong><code>jq</code></strong> — each plugin lists its own prerequisites.</li>
        </ul>
      </section>

      <section
        class="band wrap"
        id="install"
        aria-labelledby="install-heading"
      >
        <p class="kicker">Get started</p>
        <h2 class="h2" id="install-heading">Install</h2>
        <p class="section-lead">
          Add the marketplace once, then install any plugin under the <code>@odere-pro</code> scope.
          Every step works from the in-session <code>/plugin</code> command or the
          <code>claude plugin</code> shell CLI.
        </p>

        <h3 class="h3">Global &mdash; per-user (the default)</h3>
        <p class="section-lead">
          Available in every repo you open. In a Claude Code session (one command per line):
        </p>
        <div class="add-marketplace">
          <pre><code>/plugin marketplace add odere-pro/claude-software-3-0-marketplace
/plugin install &lt;plugin&gt;@odere-pro</code></pre>
        </div>
        <p class="section-lead">Or from the shell:</p>
        <pre><code>claude plugin marketplace add odere-pro/claude-software-3-0-marketplace
claude plugin install &lt;plugin&gt;@odere-pro</code></pre>

        <h3 class="h3">Project-local &mdash; scoped to one repo, shared with your team</h3>
        <p class="section-lead">
          Commit the marketplace and the plugins you want into a project's
          <code>.claude/settings.json</code>. Anyone who clones the repo gets the same tools:
        </p>
        <pre><code>{
  "extraKnownMarketplaces": {
    "odere-pro": {
      "source": { "source": "github", "repo": "odere-pro/claude-software-3-0-marketplace" }
    }
  },
  "enabledPlugins": {
    "&lt;plugin&gt;@odere-pro": true
  }
}</code></pre>
        <p class="section-lead">Or register the marketplace at project scope from the shell:</p>
        <pre><code>claude plugin marketplace add odere-pro/claude-software-3-0-marketplace --scope project</code></pre>

        <h3 class="h3">Manage what you've installed</h3>
        <pre><code>claude plugin update &lt;plugin&gt;@odere-pro     # pull the latest from the plugin's default branch
claude plugin uninstall &lt;plugin&gt;@odere-pro  # remove it
claude plugin list                          # what's installed / enabled
claude plugin details &lt;plugin&gt;@odere-pro    # component inventory + projected token cost</code></pre>
      </section>

      <section
        class="band wrap"
        id="plugins"
        aria-labelledby="plugins-heading"
      >
        <p class="kicker">The registry</p>
        <h2 class="h2" id="plugins-heading">Available plugins</h2>
        <p class="section-lead">
          Every plugin lives in its own repository and installs individually.
        </p>
${filter_toolbar}
        <div class="grid">
${plugin_cards}
        </div>
      </section>

      <section class="band wrap" id="faq" aria-labelledby="faq-heading">
        <p class="kicker">Help</p>
        <h2 class="h2" id="faq-heading">FAQ</h2>
        <div class="faq">
          <details>
            <summary>I don't have Claude Code / the <code>/plugin</code> command</summary>
            <p>Install or update Claude Code from the
            <a href="https://docs.claude.com/en/docs/claude-code/setup">official setup guide</a>;
            <code>/plugin</code> ships in current versions.</p>
          </details>
          <details>
            <summary>How do I install Git?</summary>
            <p>Get it from <a href="https://git-scm.com/downloads">git-scm.com/downloads</a>. On
            macOS, <code>xcode-select --install</code> also provides it; most Linux distros ship it
            via their package manager.</p>
          </details>
          <details>
            <summary>How do I install Node.js?</summary>
            <p>Download the LTS build from
            <a href="https://nodejs.org/en/download">nodejs.org</a>; that includes <code>npm</code>.</p>
          </details>
          <details>
            <summary>How do I manage Node versions (NVM)?</summary>
            <p>Use <a href="https://github.com/nvm-sh/nvm#installing-and-updating">nvm</a>
            (macOS/Linux) &mdash; <code>nvm install --lts</code>, then <code>nvm use --lts</code>. On
            Windows, use <a href="https://github.com/coreybutler/nvm-windows">nvm-windows</a>.</p>
          </details>
          <details>
            <summary><code>URL rejected: Malformed input…</code> when adding the marketplace</summary>
            <p>Two commands were submitted on one line, so <code>marketplace add</code> swallowed the
            next as part of the repo argument. Run each command on its own line,
            <code>marketplace add</code> first.</p>
          </details>
          <details>
            <summary><code>already installed</code>, or the plugin loads from a local path</summary>
            <p>A prior local/dev install (e.g. <code>--plugin-dir</code>, or the plugin's repo added
            as its own marketplace) shadows the marketplace copy. Uninstall, then reinstall:</p>
            <pre><code>claude plugin uninstall &lt;plugin&gt;@odere-pro
claude plugin install &lt;plugin&gt;@odere-pro</code></pre>
            <p>Install everything through the one <code>odere-pro</code> marketplace &mdash; don't
            also register an individual plugin's repo as a separate marketplace, or same-name entries
            collide.</p>
          </details>
          <details>
            <summary>I want to contribute or add a plugin</summary>
            <p>See
            <a href="${GITHUB_REPO_URL}/blob/main/CONTRIBUTING.md">CONTRIBUTING.md</a> and
            <a href="${GITHUB_REPO_URL}/blob/main/docs/adding-plugins.md">docs/adding-plugins.md</a>.</p>
          </details>
        </div>
      </section>
    </main>

    <footer class="wrap">
      <span>MIT-licensed &middot; <a href="${GITHUB_REPO_URL}">odere-pro/claude-software-3-0-marketplace</a></span>
      <span class="spacer"></span>
      <a href="${GITHUB_REPO_URL}#readme">Docs</a>
      <a href="${GITHUB_REPO_URL}/blob/main/SOFTWARE-3-0.md">Software 3.0</a>
      <a href="${GITHUB_REPO_URL}/issues">Issues</a>
    </footer>
${filter_script}
  </body>
</html>
HTMLEOF

# ── sitemap.xml ───────────────────────────────────────────────────────────────
cat >"$tmpdir/sitemap.xml" <<SITEMAPEOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${CANONICAL_URL}</loc>
    <lastmod>${SITE_BUILD_DATE}</lastmod>
    <changefreq>monthly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
SITEMAPEOF

# ── robots.txt ────────────────────────────────────────────────────────────────
cat >"$tmpdir/robots.txt" <<ROBOTSEOF
User-agent: *
Allow: /

Sitemap: ${CANONICAL_URL}sitemap.xml
ROBOTSEOF

# ── --check mode: diff tmpdir vs committed site/ ──────────────────────────────
if $check; then
  drift=0
  for f in index.html sitemap.xml robots.txt; do
    if [ ! -f "$site_dir/$f" ]; then
      echo "  MISSING: site/$f (not committed)" >&2
      drift=1
    elif ! cmp -s "$tmpdir/$f" "$site_dir/$f"; then
      echo "  DRIFT: site/$f differs from generated output" >&2
      drift=1
    fi
  done
  if [ "$drift" -eq 0 ]; then
    echo "site/ is in sync with $MK_MANIFEST" >&2
    exit 0
  else
    echo "site/ is OUT OF SYNC — run: bash $0" >&2
    exit 1
  fi
fi

# ── write mode: copy generated files to site/ ────────────────────────────────
# favicon.svg is a static committed asset — never overwritten by the generator.
for f in index.html sitemap.xml robots.txt; do
  if cmp -s "$tmpdir/$f" "$site_dir/$f" 2>/dev/null; then
    echo "site/$f already in sync" >&2
  else
    cp "$tmpdir/$f" "$site_dir/$f"
    echo "site/$f regenerated" >&2
  fi
done
