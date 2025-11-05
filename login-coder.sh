#!/bin/bash

# Login to Coder and configure CLI

set -e

CODER_URL="${CODER_URL:-http://localhost:8080}"

echo "Logging in to Coder..."

# Try different password variations
for PASSWORD in "Admin123!" "CoderAdmin123!" "Admin123\$%^"; do
    echo "Attempting login..."
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${CODER_URL}/api/v2/users/login \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"admin@example.com\",\"password\":\"${PASSWORD}\"}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        SESSION_TOKEN=$(echo "$BODY" | grep -o '"session_token":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$SESSION_TOKEN" ]; then
            echo "Login successful!"
            echo ""
            echo "Configuring Coder CLI..."

            # Configure coder CLI with the session token
            mkdir -p ~/.config/coderv2
            cat > ~/.config/coderv2/session <<EOF
{
  "url": "${CODER_URL}",
  "token": "${SESSION_TOKEN}"
}
EOF
            echo "Coder CLI configured!"
            exit 0
        fi
    fi
done

echo "Error: Could not login with any known password"
echo "Please open http://localhost:8080 in your browser to set up the admin user manually"
exit 1
