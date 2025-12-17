#!/bin/bash
set -ex

echo "=== Downloading GitHub Actions Runner ==="
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-arm64-2.329.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.329.0/actions-runner-linux-arm64-2.329.0.tar.gz
tar xzf ./actions-runner-linux-arm64-2.329.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

echo "=== Getting GitHub App credentials from Secrets Manager ==="
GITHUB_APP_CREDS=$(aws secretsmanager get-secret-value --secret-id github-pat --query SecretString --output text --region ap-northeast-1)
APP_ID=$(echo $GITHUB_APP_CREDS | jq -r .github_app_id)
INSTALLATION_ID=$(echo $GITHUB_APP_CREDS | jq -r .github_app_installation_id)
PRIVATE_KEY=$(echo $GITHUB_APP_CREDS | jq -r .github_app_private_key)

echo "=== Generating JWT for GitHub App ==="
# JWT Header
HEADER='{"alg":"RS256","typ":"JWT"}'
HEADER_B64=$(echo -n $HEADER | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

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
PAYLOAD_B64=$(echo -n $PAYLOAD | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Create signature
SIGNATURE_B64=$(echo -n "${HEADER_B64}.${PAYLOAD_B64}" | openssl dgst -sha256 -sign <(echo "$PRIVATE_KEY") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

JWT="${HEADER_B64}.${PAYLOAD_B64}.${SIGNATURE_B64}"

echo "=== Getting Installation Access Token ==="
INSTALLATION_TOKEN=$(curl -s -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens | jq -r .token)

echo "=== Getting Runner registration token ==="
TOKEN=$(curl -s -X POST \
  -H "Authorization: token $INSTALLATION_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/kei-kmj/self-runner-works/actions/runners/registration-token | jq -r .token)

echo "=== Configuring Runner ==="
cd /home/ubuntu/actions-runner
sudo -u ubuntu ./config.sh --url https://github.com/kei-kmj/self-runner-works --token $TOKEN --unattended --name $(hostname)

echo "=== Starting Runner service ==="
./svc.sh install ubuntu
./svc.sh start

echo "=== Setup Complete ==="