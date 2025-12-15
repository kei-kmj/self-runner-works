#!/bin/bash
set -ex

echo "=== Downloading GitHub Actions Runner ==="
mkdir -p /home/ubuntu/actions-runner
cd /home/ubuntu/actions-runner
curl -o actions-runner-linux-arm64-2.329.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.329.0/actions-runner-linux-arm64-2.329.0.tar.gz
tar xzf ./actions-runner-linux-arm64-2.329.0.tar.gz
chown -R ubuntu:ubuntu /home/ubuntu/actions-runner

echo "=== Getting GitHub PAT from Secrets Manager ==="
PAT=$(aws secretsmanager get-secret-value --secret-id github-pat --query SecretString --output text --region ap-northeast-1)

echo "=== Getting Runner registration token ==="
TOKEN=$(curl -s -X POST \
  -H "Authorization: token $PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/kei-kmj/self-runner-works/actions/runners/registration-token | jq -r .token)

echo "=== Configuring Runner ==="
cd /home/ubuntu/actions-runner
sudo -u ubuntu ./config.sh --url https://github.com/kei-kmj/self-runner-works --token $TOKEN --unattended --name $(hostname)

echo "=== Starting Runner service ==="
./svc.sh install ubuntu
./svc.sh start

echo "=== Setup Complete ==="