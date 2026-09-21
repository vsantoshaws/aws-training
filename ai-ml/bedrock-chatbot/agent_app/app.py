"""
Metro Grand Mall - Customer Support Agent
A Strands Agents SDK agent, backed by an Amazon Bedrock Knowledge Base of
shopping-mall support documents (return / exchange / refund / shipping
policy + FAQ), deployed to Amazon Bedrock AgentCore Runtime.
"""
import logging
import os

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.memory import MemoryManager
from strands.models import BedrockModel
from strands.vended_memory_stores import BedrockKnowledgeBaseStore

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger("mall-support-agent")

KNOWLEDGE_BASE_ID = os.environ["KNOWLEDGE_BASE_ID"]
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID", "us.anthropic.claude-sonnet-5"
)
AWS_REGION = os.environ.get("AWS_REGION_NAME") or os.environ.get("AWS_REGION", "us-west-2")

SYSTEM_PROMPT = """You are the customer support assistant for Metro Grand Mall, a
shopping mall with many stores and an online marketplace.

You have access to a knowledge base named "mall_policies" containing the mall's
official Return Policy, Exchange Policy, Refund Policy, Shipping Policy, and a
general FAQ document. ALWAYS search that knowledge base before answering any
question about returns, exchanges, refunds, shipping, or store policies -- do not
rely on general knowledge for these topics.

Guidelines:
- Be concise, warm, and helpful, like a friendly customer service representative.
- Include concrete details from the documents when relevant: timeframes (e.g. "30
  days"), fees, required conditions, and contact information.
- If the knowledge base does not contain an answer, say so honestly and suggest the
  customer contact support at 1-800-555-0199 rather than guessing.
- If a question is unrelated to shopping, returns, or the mall, politely redirect
  the customer back to how you can help with their shopping experience.
"""

app = BedrockAgentCoreApp()

_model = BedrockModel(model_id=BEDROCK_MODEL_ID, region_name=AWS_REGION)

_policy_store = BedrockKnowledgeBaseStore(
    name="mall_policies",
    description=(
        "Metro Grand Mall customer support documents: return policy, exchange "
        "policy, refund policy, shipping policy, and a general FAQ."
    ),
    config={
        "knowledge_base_id": KNOWLEDGE_BASE_ID,
        "knowledge_base_type": "VECTOR",
    },
)

agent = Agent(
    model=_model,
    system_prompt=SYSTEM_PROMPT,
    memory_manager=MemoryManager(stores=[_policy_store]),
)


@app.entrypoint
def invoke(payload):
    """AgentCore Runtime entrypoint. `payload` is the JSON body sent by the
    caller, e.g. {"prompt": "What is your return policy?"}."""
    user_message = payload.get(
        "prompt", "Hello! How can I help you with your Metro Grand Mall purchase today?"
    )
    logger.info("Received prompt: %s", user_message)
    result = agent(user_message)
    return {"result": result.message}


if __name__ == "__main__":
    app.run()
