#!/bin/bash
set -ex

echo "=== Downloading GitHub Actions Runner ==="
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-arm64-2.329.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.329.0/actions-runner-linux-arm64-2.329.0.tar.gz
tar xzf ./actions-runner-linux-arm64-2.329.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

echo "=== Getting GitHub App credentials from Secrets Manager ==="
{ set +x; } 2>/dev/null
GITHUB_APP_CREDS=$(aws secretsmanager get-secret-value --secret-id github-pat --region ap-northeast-1 --query 'SecretString' --output text)
APP_ID=$(echo "$GITHUB_APP_CREDS" | jq -r .github_app_id)
INSTALLATION_ID=$(echo "$GITHUB_APP_CREDS" | jq -r .github_app_installation_id)
PRIVATE_KEY_BASE64=$(echo "$GITHUB_APP_CREDS" | jq -r .github_app_private_key_base64)
PRIVATE_KEY=$(echo "$PRIVATE_KEY_BASE64" | base64 -d)
set -x
echo "App ID: $APP_ID, Installation ID: $INSTALLATION_ID"

echo "=== Generating JWT for GitHub App ==="
# JWT Header
HEADER='{"alg":"RS256","typ":"JWT"}'
HEADER_B64=$(echo -n "$HEADER" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# JWT Payload (issued at 60 seconds in the past, expires in 10 minutes)
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))
PAYLOAD=$(cat <<EOF
{
  "iat": $IAT,
  "exp": $EXP,
  "iss": "$APP_ID"
}
EOF
)
PAYLOAD_B64=$(echo -n "$PAYLOAD" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Create signature (using printf to avoid logging private key)
SIGNATURE_B64=$(echo -n "${HEADER_B64}.${PAYLOAD_B64}" | openssl dgst -sha256 -sign <(printf '%s' "$PRIVATE_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

if [ -z "$SIGNATURE_B64" ]; then
  echo "ERROR: Failed to generate JWT signature"
  exit 1
fi

JWT="${HEADER_B64}.${PAYLOAD_B64}.${SIGNATURE_B64}"
echo "JWT generated successfully (length: ${#JWT})"

echo "=== Getting Installation Access Token ==="
INSTALLATION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens)

INSTALLATION_TOKEN=$(echo "$INSTALLATION_RESPONSE" | jq -r .token)

if [ "$INSTALLATION_TOKEN" = "null" ] || [ -z "$INSTALLATION_TOKEN" ]; then
  echo "ERROR: Failed to get Installation Access Token"
  echo "Response: $INSTALLATION_RESPONSE"
  exit 1
fi

echo "Installation Access Token obtained successfully"

echo "=== Getting Runner registration token ==="
REGISTRATION_RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $INSTALLATION_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/kei-kmj/self-runner-works/actions/runners/registration-token)

TOKEN=$(echo "$REGISTRATION_RESPONSE" | jq -r .token)

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get Runner registration token"
  echo "Response: $REGISTRATION_RESPONSE"
  exit 1
fi

echo "Runner registration token obtained successfully"

echo "=== Configuring Runner ==="
cd /home/ubuntu/actions-runner
sudo -u ubuntu ./config.sh --url https://github.com/kei-kmj/self-runner-works --token $TOKEN --unattended --name $(hostname)

echo "=== Starting Runner service ==="
./svc.sh install ubuntu
./svc.sh start

echo "=== Setup Complete ==="