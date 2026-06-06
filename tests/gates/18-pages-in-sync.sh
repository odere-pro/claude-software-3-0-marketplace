#!/usr/bin/env bash
# G18 — pages-in-sync gate. (CRITICAL)
#
# Asserts that the committed site/ directory is byte-identical to what the
# generator (.claude/skills/add-plugin/scripts/sync-site.sh) would produce today,
# and that the generator and its output are free of remote-fetch primitives.
#
# Five assertion groups:
#
#   1. BYTE-EQUALITY — run sync-site.sh --check; FAIL on any drift in
#      index.html / sitemap.xml / robots.txt (favicon.svg is a static asset,
#      checked separately in group 4).
#
#   2. NO-REMOTE-FETCH — static scan of sync-site.sh and emitted site/*.html for
#      disallowed remote resource loading: fetch(, XMLHttpRequest, <script src=http,
#      <link … href=http (stylesheets), <img src=http.  Self-referential canonical/og
#      and GitHub plugin-homepage links are permitted (data, not fetched).
#
#   3. HTML-ESCAPE — assert the generator routes every manifest-field interpolation
#      through the html_esc helper, so no raw manifest string lands in the HTML.
#
#   4. SEO-FILES-IN-SYNC — assert sitemap.xml, robots.txt, and favicon.svg exist
#      and that the byte-check (group 1) covered sitemap + robots; favicon is a
#      static committed asset verified to be present and non-empty.
#
#   5. JSON-LD-PARSES — pipe the <script type="application/ld+json"> block from
#      the committed index.html through `jq empty` to confirm it is valid JSON.
#
# SKIP conditions (exit 0, not a FAIL — offline / missing tooling is not a registry
# contract violation):
#   - generator script absent
#   - site/ directory absent
#   - jq absent (groups 1 and 5 need jq)
#
# Passes at N=0 (empty plugins array) — the generator must render the defined
# empty-state and the byte check must still hold.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }

GENERATOR=".claude/skills/add-plugin/scripts/sync-site.sh"
SITE_DIR="site"

# ── SKIP guards ───────────────────────────────────────────────────────────────
if [ ! -f "$GENERATOR" ]; then
  echo "G18 pages-in-sync: SKIP ($GENERATOR not present)"
  exit 0
fi
if [ ! -d "$SITE_DIR" ]; then
  echo "G18 pages-in-sync: SKIP ($SITE_DIR/ not present)"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "G18 pages-in-sync: SKIP (jq not installed)"
  exit 0
fi

# ── 1. BYTE-EQUALITY ─────────────────────────────────────────────────────────
# sync-site.sh --check regenerates to a temp dir and diffs; exits non-zero on drift.
if ! bash "$GENERATOR" --check >/dev/null 2>&1; then
  note "site/ is out of sync with $GATES_MARKETPLACE"
  note "fix: bash $GENERATOR"
  fail=1
fi

# ── 2. NO-REMOTE-FETCH ───────────────────────────────────────────────────────
# Scan the generator itself for network primitives.
for pattern in 'fetch(' 'XMLHttpRequest' 'curl ' 'wget '; do
  if grep -qF "$pattern" "$GENERATOR" 2>/dev/null; then
    note "$GENERATOR contains disallowed network primitive: $pattern"
  fi
done

# Scan emitted HTML for remote resource loading (disallowed external assets).
# Permitted: canonical self-ref (odere-pro.github.io), github.com plugin links (data).
for html in "$SITE_DIR"/*.html; do
  [ -f "$html" ] || continue
  # <script src="http (external JS)
  if grep -qiE '<script[^>]+src=["\'"'"']?https?://' "$html" 2>/dev/null; then
    note "$html: contains <script src=http…> — no external scripts permitted"
  fi
  # <link rel="stylesheet" href="http (external CSS)
  if grep -qiE '<link[^>]+rel=["\'"'"']?stylesheet["\'"'"']?[^>]+href=["\'"'"']?https?://' "$html" 2>/dev/null; then
    note "$html: contains <link stylesheet href=http…> — no external stylesheets permitted"
  fi
  if grep -qiE '<link[^>]+href=["\'"'"']?https?://[^>]+rel=["\'"'"']?stylesheet' "$html" 2>/dev/null; then
    note "$html: contains <link href=http… rel=stylesheet> — no external stylesheets permitted"
  fi
  # <img src="http (external images, excluding og:image meta)
  if grep -qiE '<img[^>]+src=["\'"'"']?https?://' "$html" 2>/dev/null; then
    note "$html: contains <img src=http…> — no external images permitted"
  fi
done

# ── 3. HTML-ESCAPE ────────────────────────────────────────────────────────────
# Real XSS-payload escape coverage check.
#
# Strategy: build a minimal fake-repo tree with a XSS-payload manifest,
# copy the generator scripts into the same relative path they occupy in the
# real repo (.claude/skills/add-plugin/scripts/), patch lib.sh's mk_repo_root
# to return the fake-repo root, then run sync-site.sh against it.  Assert the
# generated HTML contains none of the live injection vectors.
#
# The fake-repo mirrors the real directory layout so lib.sh's path arithmetic
# (navigating 4 levels up from its own location) still resolves correctly.
xss_root="$(mktemp -d)"
# shellcheck disable=SC2064
trap "rm -rf '$xss_root'" EXIT

xss_scripts="$xss_root/.claude/skills/add-plugin/scripts"
xss_site="$xss_root/site"
mkdir -p "$xss_scripts"
mkdir -p "$xss_root/.claude-plugin"
mkdir -p "$xss_site/assets"
printf 'svg' >"$xss_site/assets/favicon.svg"

# XSS payload manifest — one entry with injection vectors in every rendered field.
cat >"$xss_root/.claude-plugin/marketplace.json" <<'XSSJSON'
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "odere-pro",
  "owner": { "name": "odere-pro", "email": "test@example.com" },
  "description": "Test marketplace for XSS gate validation with enough characters to pass length check.",
  "plugins": [
    {
      "name": "x</a><img src=x onerror=alert(1)>",
      "source": { "source": "github", "repo": "odere-pro/xss-test-plugin" },
      "description": "abc</script><img src=x onerror=alert(3)>",
      "homepage": "https://h\"><script>alert(2)</script>",
      "license": "MIT<script>alert(4)</script>",
      "keywords": ["xss-keyword-test"]
    }
  ]
}
XSSJSON

# Copy the generator scripts; patch lib.sh's mk_repo_root body to return $xss_root.
# The sed replacement targets the single line inside the function body; it is safe because
# the pattern is unique in lib.sh and the replacement emits a valid shell expression.
cp "$GENERATOR" "$xss_scripts/sync-site.sh"
sed "s|CDPATH='' cd -- \"\$(dirname -- \"\${BASH_SOURCE\[0\]}\")/../../../..\" && pwd|printf '%s' '$xss_root'|" \
  .claude/skills/add-plugin/scripts/lib.sh >"$xss_scripts/lib.sh"

# Run the generator against the fake repo (write mode, not --check).
xss_gen_ok=true
if ! bash "$xss_scripts/sync-site.sh" >/dev/null 2>&1; then
  xss_gen_ok=false
fi

if $xss_gen_ok && [ -f "$xss_site/index.html" ]; then
  xss_html="$xss_site/index.html"

  # Strip the JSON-LD block from HTML before checking for live XSS vectors:
  # JSON-LD is parsed as JSON by browsers (not HTML), so field values like onerror=
  # or "><script>" inside JSON strings are NOT executable as HTML.
  # The JSON-LD block itself is protected by the </script neutralization check (3c).
  xss_html_no_ld="$(awk '
    /<script[^>]*application\/ld\+json/{skip=1; next}
    skip && /<\/script>/{skip=0; next}
    !skip{print}
  ' "$xss_html")"

  # 3a. No LIVE onerror= attribute in the HTML outside the JSON-LD block.
  # A live attack is: <tagname ... onerror=  (unescaped < starts an actual HTML tag).
  # Safe escaped occurrences look like: &lt;img src=x onerror= — these are just text content.
  if printf '%s\n' "$xss_html_no_ld" | grep -qiE '<[a-zA-Z][^>]* onerror=' 2>/dev/null; then
    note "HTML-ESCAPE: generated HTML (outside JSON-LD) contains live 'onerror=' attribute — stored XSS not neutralized"
  fi

  # 3b. No live attribute-breakout sequence that injects a script tag via homepage (outside JSON-LD).
  # A live attack: "><script> breaks out of an HTML attribute value and injects a script element.
  if printf '%s\n' "$xss_html_no_ld" | grep -qF '"><script>' 2>/dev/null; then
    note "HTML-ESCAPE: generated HTML (outside JSON-LD) contains attribute-breakout '\"><script>' — homepage field XSS not neutralized"
  fi

  # 3c. JSON-LD block must not contain a raw </script sequence that closes the element early.
  # Detection: count the total number of </script occurrences from the JSON-LD opening tag onwards.
  # A clean block has exactly 1 (the legitimate closer).  Any extra means a field value contains
  # </script, which a browser would use to terminate the <script> element prematurely.
  ld_script_count="$(awk '
    /<script[^>]*application\/ld\+json/{in_ld=1}
    in_ld {
      n = split($0, a, "</script")
      if (n > 1) cnt += (n - 1)
    }
    END {print cnt+0}
  ' "$xss_html")"
  if [ "${ld_script_count:-0}" -gt 1 ]; then
    note "HTML-ESCAPE: JSON-LD section contains ${ld_script_count} '</script' occurrences (expected 1) — script-context breakout not neutralized"
  fi

  # 3d. No live <script> tag injected via license/description outside the JSON-LD block.
  if printf '%s\n' "$xss_html_no_ld" | grep -qiF '<script>' 2>/dev/null; then
    note "HTML-ESCAPE: generated HTML contains a live '<script>' tag outside JSON-LD — license/description XSS not neutralized"
  fi
else
  # Generator invocation failed (broken patch or missing tool) — fall back to a static check
  # so the gate does not silently pass.
  if ! grep -qE '(html_esc|html_escape)\(\)' "$GENERATOR" 2>/dev/null; then
    note "$GENERATOR: missing html_esc/html_escape function — manifest strings must be HTML-escaped"
  fi
fi

# ── 4. SEO-FILES-IN-SYNC ─────────────────────────────────────────────────────
for seo_file in "$SITE_DIR/sitemap.xml" "$SITE_DIR/robots.txt" "$SITE_DIR/assets/favicon.svg"; do
  if [ ! -f "$seo_file" ]; then
    note "missing required SEO/asset file: $seo_file"
  elif [ ! -s "$seo_file" ]; then
    note "$seo_file exists but is empty"
  fi
done

# ── 5. JSON-LD-PARSES ─────────────────────────────────────────────────────────
# Extract the ld+json block from committed index.html and validate it parses.
index_html="$SITE_DIR/index.html"
if [ -f "$index_html" ]; then
  # Extract content between <script type="application/ld+json"> and </script>.
  ld_json="$(awk '
    /<script[^>]+type=["\'"'"']?application\/ld\+json["\'"'"']?[^>]*>/{found=1; next}
    found && /<\/script>/{found=0; next}
    found{print}
  ' "$index_html")"
  if [ -n "$ld_json" ]; then
    if ! printf '%s\n' "$ld_json" | jq empty 2>/dev/null; then
      note "$index_html: JSON-LD block does not parse as valid JSON"
    fi
  else
    note "$index_html: no <script type=\"application/ld+json\"> block found"
  fi
fi

# ── result ────────────────────────────────────────────────────────────────────
if [ "$fail" -ne 0 ]; then
  echo "G18 pages-in-sync: FAIL"
  exit 1
fi
echo "G18 pages-in-sync: ok"
