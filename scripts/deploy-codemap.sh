#!/bin/bash
# Deploy CodeMap to Andi (webclerk.com/codemap/)
# Usage: bash scripts/deploy-codemap.sh
#
# Deploys:
#   1. Site page (sites/codemap/) → /var/www/webclerk-static/codemap/
#   2. Enriched SVGs → /var/www/webclerk-static/codemap/flowcharts/
#   3. Nginx location block (if not already present)

set -euo pipefail

ANDI="andi@192.168.1.114"
REMOTE_DIR="/var/www/webclerk-static/codemap"
LOCAL_SITE="$(dirname "$0")/../sites/codemap/"
LOCAL_SVGS="$(dirname "$0")/../readmes/flowcharts/"

echo "=== Deploy CodeMap to Andi ==="

# 1. Create remote directories
echo "1. Creating remote directories..."
ssh "$ANDI" "sudo mkdir -p $REMOTE_DIR/flowcharts $REMOTE_DIR/images && sudo chown -R www-data:www-data $REMOTE_DIR"

# 2. Copy site files
echo "2. Copying site files..."
rsync -avz "$LOCAL_SITE" "$ANDI:/tmp/codemap-site/"
ssh "$ANDI" "sudo cp -r /tmp/codemap-site/* $REMOTE_DIR/ && rm -rf /tmp/codemap-site"

# 3. Copy enriched SVGs (for flowchart library links)
echo "3. Copying enriched SVGs..."
rsync -avz --include='*.enriched.svg' --exclude='*' "$LOCAL_SVGS" "$ANDI:/tmp/codemap-svgs/"
ssh "$ANDI" "sudo cp /tmp/codemap-svgs/*.enriched.svg $REMOTE_DIR/flowcharts/ && rm -rf /tmp/codemap-svgs"

# 4. Fix permissions
echo "4. Fixing permissions..."
ssh "$ANDI" "sudo chown -R www-data:www-data $REMOTE_DIR && sudo chmod -R o+rX $REMOTE_DIR"

# 5. Check nginx config
echo "5. Checking nginx config..."
if ssh "$ANDI" "grep -q 'location /codemap' /etc/nginx/sites-enabled/webclerk3"; then
    echo "   Nginx location already configured."
else
    echo "   Adding nginx location block..."
    ssh "$ANDI" "sudo sed -i '/location \/wc-works/i\\
    location /codemap/ {\\
        alias /var/www/webclerk-static/codemap/;\\
        try_files \$uri \$uri/ =404;\\
    }\\
' /etc/nginx/sites-enabled/webclerk3"
    ssh "$ANDI" "sudo nginx -t && sudo systemctl reload nginx"
    echo "   Nginx reloaded."
fi

echo ""
echo "=== Done. Live at https://webclerk.com/codemap/ ==="
