#!/bin/sh

# Discord webhook URL
WEBHOOK_URL="https://discordapp.com/api/webhooks/YOIR_WEBHOOK_ID"

# Get vnstat output for all interfaces
VNSTAT_OUTPUT=$(vnstat | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Format the message
MESSAGE="\uD83D\uDCC8 **Daily Network Usage Report**\n\`\`\`$VNSTAT_OUTPUT\`\`\`"

# Send vnstat output to webhook
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"$MESSAGE\"}" \
     $WEBHOOK_URL
