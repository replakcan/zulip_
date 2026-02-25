#!/bin/bash

URL="https://${ORG_NAME}.zulipchat.com/api/v1/messages"

curl -X POST `URL` \
    -u "${SENDER_EMAIL_ADDRESS}:${SENDER_API_KEY}" \
    --data-urlencode "type=direct" \
    --data-urlencode "to=[${RECEIVER_ID}]" \
    --data-urlencode "content=test test `date`"