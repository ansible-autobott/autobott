#!/bin/bash

# Directory where Caddy stores certs (adjust if yours differs)
CERT_DIR="/var/lib/caddy/.local/share/caddy/certificates/"

# Get active domains from Caddy API
domains=$(curl -s {{ caddy_config.admin }}/config/ | jq -r '.apps.http.servers[].routes[]?.match[]? | select(.host != null) | .host[]' | sort -u)

echo -e "Domain\t\t\tExpires"
echo -e "-------\t\t\t-------"

for domain in $domains; do
    found_expiry=""

    # Find all cert files under CERT_DIR
    while IFS= read -r certfile; do
        # Extract subject CN and SANs
        subject_cn=$(openssl x509 -in "$certfile" -noout -subject | sed -n 's/^subject=.*CN=\([^,\/]*\).*$/\1/p')
        san=$(openssl x509 -in "$certfile" -noout -text | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/ //g' | tr ',' '\n' | sed 's/DNS://g')

        # Check if domain matches subject CN or any SAN
        if [[ "$domain" == "$subject_cn" ]] || echo "$san" | grep -qx "$domain"; then
            expiry=$(openssl x509 -in "$certfile" -noout -enddate | sed 's/notAfter=//')
            found_expiry="$expiry"
            break
        fi
    done < <(find "$CERT_DIR" -type f -name "*.crt")

    if [ -n "$found_expiry" ]; then
        echo -e "$domain\t\t$found_expiry"
    else
        echo -e "$domain\t\t(no cert info)"
    fi
done
