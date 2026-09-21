"""
Metro Grand Mall - Customer Support Chat UI
Flask web app that forwards chat messages to a Strands agent running on
Amazon Bedrock AgentCore Runtime and renders the response.
"""
import json
import logging
import os
import uuid

import boto3
from flask import Flask, jsonify, render_template_string, request, session

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("chat-ui")

AWS_REGION = os.environ.get("AWS_REGION", "us-west-2")
AGENT_RUNTIME_ARN = os.environ["AGENT_RUNTIME_ARN"]
MALL_NAME = os.environ.get("MALL_NAME", "Metro Grand Mall")

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", uuid.uuid4().hex)

_agentcore_client = boto3.client("bedrock-agentcore", region_name=AWS_REGION)

PAGE_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{ mall_name }} - Customer Support</title>
<style>
  :root {
    --brand: #7c3aed;
    --brand-dark: #5b21b6;
    --bg: #f5f3ff;
    --bubble-user: #7c3aed;
    --bubble-agent: #ffffff;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg);
    height: 100vh;
    display: flex;
    flex-direction: column;
  }
  header {
    background: linear-gradient(135deg, var(--brand), var(--brand-dark));
    color: white;
    padding: 18px 24px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
  }
  header h1 { margin: 0; font-size: 1.25rem; }
  header p { margin: 2px 0 0; font-size: 0.85rem; opacity: 0.9; }
  #chat {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    max-width: 820px;
    width: 100%;
    margin: 0 auto;
  }
  .msg { max-width: 75%; padding: 10px 14px; border-radius: 14px; line-height: 1.45; white-space: pre-wrap; }
  .user { align-self: flex-end; background: var(--bubble-user); color: white; border-bottom-right-radius: 4px; }
  .agent { align-self: flex-start; background: var(--bubble-agent); border: 1px solid #e5e0f7; border-bottom-left-radius: 4px; }
  .agent.pending { color: #888; font-style: italic; }
  form#composer {
    display: flex;
    align-items: flex-end;
    gap: 8px;
    padding: 16px;
    background: white;
    border-top: 1px solid #e5e0f7;
    max-width: 820px;
    width: 100%;
    margin: 0 auto;
  }
  #prompt {
    flex: 1;
    padding: 12px 14px;
    border-radius: 10px;
    border: 1px solid #d8d0f5;
    font-size: 1rem;
    font-family: inherit;
    resize: none;
    overflow-y: auto;
    max-height: 160px;
    line-height: 1.4;
  }
  button {
    background: var(--brand);
    color: white;
    border: none;
    padding: 0 20px;
    height: 44px;
    border-radius: 10px;
    font-size: 1rem;
    cursor: pointer;
    flex-shrink: 0;
  }
  button:disabled { opacity: 0.6; cursor: default; }
  .suggestions { display: flex; gap: 8px; flex-wrap: wrap; padding: 0 16px 12px; max-width: 820px; margin: 0 auto; width: 100%; }
  .chip {
    background: white; border: 1px solid #d8d0f5; border-radius: 999px;
    padding: 6px 12px; font-size: 0.85rem; cursor: pointer; color: var(--brand-dark);
  }
</style>
</head>
<body>
<header>
  <h1>{{ mall_name }} - Customer Support Assistant</h1>
  <p>Ask about returns, exchanges, refunds, shipping, or general store policies.</p>
</header>
<div id="chat"></div>
<div class="suggestions">
  <span class="chip" onclick="ask(this)">What is your return policy?</span>
  <span class="chip" onclick="ask(this)">Can I exchange a gift?</span>
  <span class="chip" onclick="ask(this)">How long do refunds take?</span>
  <span class="chip" onclick="ask(this)">Do you offer free shipping?</span>
</div>
<form id="composer" onsubmit="return sendMessage(event)">
  <textarea id="prompt" rows="1" autocomplete="off" placeholder="Type your question... (Enter to send, Shift+Enter for a new line)" required></textarea>
  <button id="sendBtn" type="submit">Send</button>
</form>
<script>
const chat = document.getElementById('chat');
const promptInput = document.getElementById('prompt');
const sendBtn = document.getElementById('sendBtn');

function resizePrompt() {
  promptInput.style.height = 'auto';
  promptInput.style.height = Math.min(promptInput.scrollHeight, 160) + 'px';
}
promptInput.addEventListener('input', resizePrompt);
promptInput.addEventListener('keydown', (evt) => {
  if (evt.key === 'Enter' && !evt.shiftKey) {
    evt.preventDefault();
    sendMessage(evt);
  }
});

function addMessage(text, cls) {
  const div = document.createElement('div');
  div.className = 'msg ' + cls;
  div.textContent = text;
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
  return div;
}

function ask(el) {
  promptInput.value = el.textContent;
  sendMessage(new Event('submit'));
}

async function sendMessage(evt) {
  evt.preventDefault();
  const text = promptInput.value.trim();
  if (!text) return false;
  addMessage(text, 'user');
  promptInput.value = '';
  resizePrompt();
  sendBtn.disabled = true;
  const pending = addMessage('Thinking...', 'agent pending');
  try {
    const res = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: text })
    });
    const data = await res.json();
    pending.classList.remove('pending');
    pending.textContent = data.reply || data.error || 'Sorry, something went wrong.';
  } catch (e) {
    pending.classList.remove('pending');
    pending.textContent = 'Network error contacting the assistant.';
  } finally {
    sendBtn.disabled = false;
    promptInput.focus();
  }
  return false;
}

addMessage("Hi! I'm the " + document.title.split(' - ')[0] + " assistant. How can I help with returns, exchanges, refunds, or shipping today?", 'agent');
</script>
</body>
</html>
"""


def _extract_reply_text(response_data):
    """Best-effort extraction of the assistant's reply text from the
    AgentCore/Strands response payload, which may take a couple of shapes
    depending on how the agent entrypoint formats its return value."""
    try:
        output = response_data.get("result", response_data.get("output", response_data))
        message = output.get("message", output) if isinstance(output, dict) else output
        if isinstance(message, dict):
            content = message.get("content")
            if isinstance(content, list) and content:
                parts = [c.get("text", "") for c in content if isinstance(c, dict) and "text" in c]
                if parts:
                    return "\n".join(parts)
            if "text" in message:
                return message["text"]
        if isinstance(response_data, str):
            return response_data
    except Exception:  # noqa: BLE001
        pass
    return json.dumps(response_data)


@app.route("/")
def index():
    return render_template_string(PAGE_TEMPLATE, mall_name=MALL_NAME)


@app.route("/healthz")
def healthz():
    return jsonify(status="ok")


@app.route("/api/chat", methods=["POST"])
def chat():
    body = request.get_json(force=True, silent=True) or {}
    user_message = (body.get("message") or "").strip()
    if not user_message:
        return jsonify(error="Message cannot be empty."), 400

    if "session_id" not in session:
        session["session_id"] = str(uuid.uuid4())  # >= 33 chars, required by AgentCore
    runtime_session_id = session["session_id"]

    payload = json.dumps({"prompt": user_message}).encode("utf-8")

    try:
        response = _agentcore_client.invoke_agent_runtime(
            agentRuntimeArn=AGENT_RUNTIME_ARN,
            runtimeSessionId=runtime_session_id,
            payload=payload,
            qualifier="DEFAULT",
        )
        raw_body = response["response"].read()
        response_data = json.loads(raw_body)
        reply = _extract_reply_text(response_data)
        return jsonify(reply=reply)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Failed to invoke agent runtime")
        return jsonify(error=f"Assistant is unavailable right now ({exc.__class__.__name__})."), 502


if __name__ == "__main__":
    port = int(os.environ.get("CHAT_UI_PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
