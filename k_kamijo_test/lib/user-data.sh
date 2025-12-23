echo "=== UserData Start ===" | tee /var/log/userdata.log

echo "=== Installing Docker ===" | tee -a /var/log/userdata.log
apt-get update
apt-get install -y docker.io docker-compose-v2 git pip unzip jq python3-venv
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu
echo "Docker installed: $(docker --version)" | tee -a /var/log/userdata.log

echo "=== Installing AWS CLI ===" | tee -a /var/log/userdata.log
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
echo "AWS CLI installed: $(aws --version)" | tee -a /var/log/userdata.log

echo "=== Setting up CodeCommit credential helper ===" | tee -a /var/log/userdata.log
python3 -m venv /opt/codecommit-env
/opt/codecommit-env/bin/pip install git-remote-codecommit
ln -s /opt/codecommit-env/bin/git-remote-codecommit /usr/local/bin/git-remote-codecommit
echo "git-remote-codecommit installed" | tee -a /var/log/userdata.log

echo "=== Cloning setup repo ===" | tee -a /var/log/userdata.log
git clone codecommit::ap-northeast-1://github-runner-setup /home/ubuntu/setup
chown -R ubuntu:ubuntu /home/ubuntu/setup
echo "Repo cloned" | tee -a /var/log/userdata.log

echo "=== Running setup.sh ===" | tee -a /var/log/userdata.log
cd /home/ubuntu/setup && chmod +x setup.sh && ./setup.sh 2>&1 | tee -a /var/log/userdata.log


echo "=== UserData Complete ===" | tee -a /var/log/userdata.log