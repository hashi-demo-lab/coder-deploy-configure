#!/bin/bash

# Helper script to create the first Coder user via API

set -e

CODER_URL="${CODER_URL:-http://localhost:8080}"

echo "Creating initial Coder user..."

# Create user via API
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST ${CODER_URL}/api/v2/users/first \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","email":"admin@example.com","password":"CoderAdmin123!","trial":false}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    SESSION_TOKEN=$(echo "$BODY" | grep -o '"session_token":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$SESSION_TOKEN" ]; then
        echo "User created successfully!"
        echo "Username: admin"
        echo "Password: CoderAdmin123!"
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
        echo "You can now use 'coder' commands."
    else
        echo "Error: Could not extract session token"
        echo "Response: $BODY"
        exit 1
    fi
elif echo "$BODY" | grep -q "user already exists"; then
    echo "User already exists. Please login manually:"
    echo "coder login ${CODER_URL}"
    exit 0
else
    echo "Error creating user:"
    echo "$BODY"
    exit 1
fi
