#!/usr/bin/env bash
set -euo pipefail

# ========== CONFIG ==========
# Kaç kişi gönderilsin?
TOP_N="${TOP_N:-1}"

# Zulip mesajı direct message (DM) olarak atılacak
# Env beklenenler:
# ZULIP_ORGANIZATION_NAME, USER_EMAIL, USER_API_KEY, MESSAGE_RECEIVER_USER_ID

# ========== HELPERS ==========
die() { echo "Error: $*" >&2; exit 1; }

require_env() {
  local v="$1"
  [[ -n "${!v:-}" ]] || die "Missing env var: $v"
}

strip_html_to_text() {
  # Basit HTML -> text temizleme.
  # Wikipedia parse HTML'i nispeten düzenli; bu yeterince iyi çalışır.
  sed -E \
    -e 's/<sup[^>]*>.*<\/sup>//g' \
    -e 's/<span[^>]*class="nowrap"[^>]*>[^<]*<\/span>//g' \
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

# ========== MAIN ==========
# 1) Bugünün sayfa adı (Örn: February_24)
MONTH="$(date -u +%B)"
DAY="$(date -u +%-d)"
PAGE="${MONTH}_${DAY}"
PAGE_HUMAN="${MONTH} ${DAY}"

API="https://en.wikipedia.org/w/api.php"

# 2) Births section index'ini bul
sections_json="$(
  curl -fsS --get "$API" \
    --data-urlencode "action=parse" \
    --data-urlencode "page=$PAGE" \
    --data-urlencode "prop=sections" \
    --data-urlencode "format=json"
)"

birth_lines="$(
  printf '%s' "$births_html" \
    | tr '\n' ' ' \
    | sed -E 's/<li/\n<li/g' \
    | grep -m "$TOP_N" -E '^<li' \
    | strip_html_to_text
)"

[[ -n "$birth_index" && "$birth_index" != "null" ]] || die "Could not find 'Births' section for page: $PAGE"

# 3) Births section HTML'ini çek
births_html="$(
  curl -fsS --get "$API" \
    --data-urlencode "action=parse" \
    --data-urlencode "page=$PAGE" \
    --data-urlencode "prop=text" \
    --data-urlencode "section=$birth_index" \
    --data-urlencode "format=json" \
  | jq -r '.parse.text["*"]'
)"

# 4) <li> satırlarını çek, text'e indir, ilk TOP_N satırı al
# Wikipedia Births listesi genellikle <li> ile geliyor.
birth_lines="$(
  echo "$births_html" \
    | tr '\n' ' ' \
    | sed -E 's/<li/\n<li/g' \
    | grep -E '^<li' \
    | head -n "$TOP_N" \
    | strip_html_to_text
)"

[[ -n "$birth_lines" ]] || die "No birth lines extracted."

# 5) Mesajı hazırla
msg="🎂 Today ($PAGE_HUMAN) — notable births:
$birth_lines
Source: https://en.wikipedia.org/wiki/$PAGE"

# 6) Zulip'e gönder
require_env ZULIP_ORGANIZATION_NAME
require_env USER_EMAIL
require_env USER_API_KEY
require_env MESSAGE_RECEIVER_USER_ID

curl -fsS -X POST "https://${ZULIP_ORGANIZATION_NAME}.zulipchat.com/api/v1/messages" \
  -u "${USER_EMAIL}:${USER_API_KEY}" \
  --data-urlencode "type=direct" \
  --data-urlencode "to=[${MESSAGE_RECEIVER_USER_ID}]" \
  --data-urlencode "content=${msg}"

echo "Sent message with top ${TOP_N} births for ${PAGE_HUMAN}"