#!/bin/bash
set -euo pipefail

echo "ZULIP_ORGANIZATION_NAME='${ZULIP_ORGANIZATION_NAME}'"
echo "USER_EMAIL length=${#USER_EMAIL}"
echo "USER_API_KEY length=${#USER_API_KEY}"
echo "MESSAGE_RECEIVER_USER_ID='${MESSAGE_RECEIVER_USER_ID}'"

: "${ZULIP_ORGANIZATION_NAME:?missing}"
: "${USER_EMAIL:?missing}"
: "${USER_API_KEY:?missing}"
: "${MESSAGE_RECEIVER_USER_ID:?missing}"