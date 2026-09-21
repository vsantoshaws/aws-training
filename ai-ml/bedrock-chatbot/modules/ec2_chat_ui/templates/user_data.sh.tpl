#!/bin/bash
set -euo pipefail

# --- system packages ---------------------------------------------------
dnf update -y
dnf install -y python3 python3-pip

mkdir -p /opt/chat-ui
cd /opt/chat-ui

# --- application code (base64-encoded by Terraform to survive templating) ---
cat <<'REQUIREMENTS_EOF' > /opt/chat-ui/requirements.txt
flask==3.0.3
boto3>=1.35.36
gunicorn==22.0.0
REQUIREMENTS_EOF

echo "${app_py_base64}" | base64 -d > /opt/chat-ui/app.py

python3 -m venv /opt/chat-ui/venv
/opt/chat-ui/venv/bin/pip install --upgrade pip
/opt/chat-ui/venv/bin/pip install -r /opt/chat-ui/requirements.txt

# --- environment for the app -------------------------------------------
cat <<ENV_EOF > /opt/chat-ui/env
AWS_REGION=${aws_region}
AGENT_RUNTIME_ARN=${agent_runtime_arn}
CHAT_UI_PORT=${chat_ui_port}
MALL_NAME=${mall_name}
ENV_EOF

# --- systemd service ------------------------------------------------------
cat <<SERVICE_EOF > /etc/systemd/system/chat-ui.service
[Unit]
Description=Mall Support Chat UI (Flask + Bedrock AgentCore)
After=network.target

[Service]
Type=simple
EnvironmentFile=/opt/chat-ui/env
WorkingDirectory=/opt/chat-ui
ExecStart=/opt/chat-ui/venv/bin/gunicorn -w 2 -b 0.0.0.0:${chat_ui_port} app:app
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable chat-ui.service
systemctl restart chat-ui.service
