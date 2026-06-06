#!/bin/bash
# Certbot renewal deploy hook — copies Let's Encrypt certs to a location
# readable by the deploy user, then restarts the Cuttlefish SMTP receiver.
# Installed at: /etc/letsencrypt/renewal-hooks/deploy/refresh-cuttlefish-certs.sh

set -e

CERT_SRC="/etc/letsencrypt/live/mail.pipeproject.info"
CERT_DST="/etc/cuttlefish-certs"

cp "$CERT_SRC/fullchain.pem" "$CERT_DST/fullchain.pem"
cp "$CERT_SRC/privkey.pem"   "$CERT_DST/privkey.pem"

chown deploy:deploy "$CERT_DST/fullchain.pem" "$CERT_DST/privkey.pem"
chmod 640           "$CERT_DST/fullchain.pem" "$CERT_DST/privkey.pem"

systemctl restart cuttlefish-smtp

echo "Cuttlefish certs refreshed and SMTP service restarted."
