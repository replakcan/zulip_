#!/usr/bin/env bash
set -euo pipefail

# =======================
# CONFIG
# =======================
TOP_N="${TOP_N:-5}"                   # Kaç kişi gönderilsin
WIKI_LANG="${WIKI_LANG:-en}"          # en, tr vs (en önerilir)
WIKI_TZ="${WIKI_TZ:-UTC}"             # UTC önerilir; TR istersen Europe/Istanbul yap
MAX_RETRIES="${MAX_RETRIES:-3}"       # Wikipedia rate limit vs için
RETRY_SLEEP_BASE="${RETRY_SLEEP_BASE:-2}"

# Zulip env vars:
# ZULIP_ORGANIZATION_NAME, USER_EMAIL, USER_API_KEY, MESSAGE_RECEIVER_USER_ID

# =======================
# HELPERS
# =======================
die() { echo "Error: $*" >&2; exit 1; }

require_env() {
  local v="$1"
  [[ -n "${!v:-}" ]] || die "Missing env var: $v"
}

urlencode_get() {
  # curl --get wrapper (args already passed as --data-urlencode pairs in caller)
  curl -fsS --get "$@"
}

fetch_json_retry() {
  # Usage: fetch_json_retry <url> <curl args...>
  local url="$1"; shift
  local out=""
  local i=1
  while (( i <= MAX_RETRIES )); do
    if out="$(urlencode_get "$url" "$@" 2>/dev/null)" && [[ -n "$out" ]]; then
      printf '%s' "$out"
      return 0
    fi
    sleep $(( RETRY_SLEEP_BASE * i ))
    i=$(( i + 1 ))
  done
  return 1
}

strip_html_to_text() {
  # Minimal HTML -> text cleanup for Wikipedia list items
  sed -E \
    -e 's/<sup[^>]*>.*<\/sup>//g' \
    -e 's/<span[^>]*class="nowrap"[^>]*>[^<]*<\/span>//g' \
    -e 's/<style[^>]*>.*<\/style>//g' \
    -e 's/<script[^>]*>.*<\/script>//g' \
    -e 's/<[^>]+>/ /g' \
    -e 's/&nbsp;/ /g' \
    -e 's/&amp;/\&/g' \
    -e 's/&quot;/"/g' \
    -e "s/&#39;/'/g" \
    -e 's/&lt;/</g' \
    -e 's/&gt;/>/g' \
    -e 's/[[:space:]]+/ /g' \
    -e 's/^ +| +$//g'
}

send_zulip_dm() {
  local content="$1"

  require_env ZULIP_ORGANIZATION_NAME
  require_env USER_EMAIL
  require_env USER_API_KEY
  require_env MESSAGE_RECEIVER_USER_ID

  curl -fsS -X POST "https://${ZULIP_ORGANIZATION_NAME}.zulipchat.com/api/v1/messages" \
    -u "${USER_EMAIL}:${USER_API_KEY}" \
    --data-urlencode "type=direct" \
    --data-urlencode "to=[${MESSAGE_RECEIVER_USER_ID}]" \
    --data-urlencode "content=${content}" >/dev/null
}

# =======================
# MAIN
# =======================
# Date -> Wikipedia page title (English months required for enwiki)
# WIKI_TZ controls which "today" you mean.
MONTH="$(TZ="$WIKI_TZ" date +%B)"
DAY="$(TZ="$WIKI_TZ" date +%-d)"
PAGE="${MONTH}_${DAY}"           # e.g., February_24
PAGE_HUMAN="${MONTH} ${DAY}"     # e.g., February 24

API="https://${WIKI_LANG}.wikipedia.org/w/api.php"
PAGE_URL="https://${WIKI_LANG}.wikipedia.org/wiki/${PAGE}"

# 1) Get sections to locate "Births" section index
sections_json="$(
  fetch_json_retry "$API" \
    --data-urlencode "action=parse" \
    --data-urlencode "page=${PAGE}" \
    --data-urlencode "prop=sections" \
    --data-urlencode "format=json"
)" || die "Failed to fetch sections for page: ${PAGE}"

birth_index="$(
  printf '%s' "$sections_json" | jq -r '
    .parse.sections[]
    | select(.line=="Births")
    | .index
  ' 2>/dev/null | head -n1
)"

[[ -n "${birth_index:-}" && "${birth_index:-}" != "null" ]] || die "Could not find 'Births' section on: ${PAGE_URL}"

# 2) Fetch Births section HTML
births_html="$(
  fetch_json_retry "$API" \
    --data-urlencode "action=parse" \
    --data-urlencode "page=${PAGE}" \
    --data-urlencode "prop=text" \
    --data-urlencode "section=${birth_index}" \
    --data-urlencode "format=json" \
  | jq -r '.parse.text["*"] // empty' 2>/dev/null
)" || die "Failed to fetch births HTML (page=${PAGE}, section=${birth_index})."

[[ -n "${births_html:-}" ]] || die "Births HTML empty (page=${PAGE}, section=${birth_index})."

# 3) Extract first TOP_N <li> items without broken pipe
birth_lines="$(
  printf '%s' "$births_html" \
    | tr '\n' ' ' \
    | sed -E 's/<li/\n<li/g' \
    | grep -m "$TOP_N" -E '^<li' \
    | strip_html_to_text
)"

[[ -n "${birth_lines:-}" ]] || die "No birth lines extracted from ${PAGE_URL}"

# 4) Build message (plain, clean)
msg="Today (${PAGE_HUMAN}) — notable births:
${birth_lines}

Source: ${PAGE_URL}"

# 5) Send to Zulip
send_zulip_dm "$msg"

echo "OK: Sent top ${TOP_N} births for ${PAGE_HUMAN}"