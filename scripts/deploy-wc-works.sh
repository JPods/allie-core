#!/bin/bash
# Deploy wc-works (How WebClerk Works) to Andi
# Usage: bash scripts/deploy-wc-works.sh
#
# Deploys:
#   1. Index page (sites/wc-works/index.html) → /var/www/webclerk-static/wc-works/
#   2. Enriched SVGs (readmes/flowcharts/*.enriched.svg) → /var/www/webclerk-static/wc-works/flowcharts/
#   3. Seed fixture → already in WC3 codebase (loaddata separately)
#   4. Nginx location block (if not already present)

set -euo pipefail

ANDI="andi@192.168.1.114"
REMOTE_DIR="/var/www/webclerk-static/wc-works"
LOCAL_PAGE="$(dirname "$0")/../sites/wc-works/"
LOCAL_SVGS="$(dirname "$0")/../readmes/flowcharts/"

echo "=== Deploy wc-works to Andi ==="

# 1. Create remote directory
echo "1. Creating remote directories..."
ssh "$ANDI" "sudo mkdir -p $REMOTE_DIR/flowcharts && sudo chown -R www-data:www-data $REMOTE_DIR"

# 2. Copy index page
echo "2. Copying index page..."
rsync -avz "$LOCAL_PAGE" "$ANDI:/tmp/wc-works-page/"
ssh "$ANDI" "sudo cp /tmp/wc-works-page/* $REMOTE_DIR/ && rm -rf /tmp/wc-works-page"

# 3. Copy enriched SVGs
echo "3. Copying enriched SVGs..."
rsync -avz --include='*.enriched.svg' --exclude='*' "$LOCAL_SVGS" "$ANDI:/tmp/wc-works-svgs/"
ssh "$ANDI" "sudo cp /tmp/wc-works-svgs/*.enriched.svg $REMOTE_DIR/flowcharts/ && rm -rf /tmp/wc-works-svgs"

# 4. Fix permissions
echo "4. Fixing permissions..."
ssh "$ANDI" "sudo chown -R www-data:www-data $REMOTE_DIR && sudo chmod -R o+rX $REMOTE_DIR"

# 5. Check nginx config
echo "5. Checking nginx config..."
if ssh "$ANDI" "grep -q 'wc-works' /etc/nginx/sites-enabled/webclerk3"; then
    echo "   Nginx location already configured."
else
    echo "   Adding nginx location block..."
    ssh "$ANDI" "sudo sed -i '/location \/liferequiresenergy/i\\
    location /wc-works/ {\\
        alias /var/www/webclerk-static/wc-works/;\\
        try_files \$uri \$uri/ =404;\\
    }\\
' /etc/nginx/sites-enabled/webclerk3"
    ssh "$ANDI" "sudo nginx -t && sudo systemctl reload nginx"
    echo "   Nginx reloaded."
fi

# 6. Load fixture (optional — uncomment if DB sync needed)
# echo "6. Loading seed fixture..."
# ssh "$ANDI" "cd /opt/andi/apps/webclerk3 && source venv/bin/activate && \
#   python manage.py loaddata apps/docs/fixtures/wc_works_seed.json"

echo ""
echo "=== Done. Live at https://webclerk.com/wc-works/ ==="
