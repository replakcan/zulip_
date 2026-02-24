#!/bin/bash

curl -X POST "https://${{ vars.ZULIP_ORGANIZATION_NAME }}/api/v1/messages" \
    -u "${{ secrets.USER_EMAIL }}:${{ secrets.USER_API_KEY }}" \
    --data-urlencode "type=direct" \
    --data-urlencode "to=[${{ secrets.MESSAGE_RECEIVER_USER_ID }}]" \
    --data-urlencode "content=test test testttttttttttt"