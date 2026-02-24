#!/bin/bash

curl -X POST "https://${ZULIP_ORGANIZATION_NAME}.zulipchat.com/api/v1/messages" \
    -u "${USER_EMAIL}:${USER_API_KEY}" \
    --data-urlencode "type=direct" \
    --data-urlencode "to=[${MESSAGE_RECEIVER_USER_ID}]" \
    --data-urlencode "content=test test testttttttttttt"
