# Amazon Bedrock AgentCore Runtime requires linux/arm64 images.
# Always build with: docker buildx build --platform linux/arm64 ...
FROM --platform=linux/arm64 python:3.11-slim

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./

# AgentCore Runtime always calls the container on port 8080.
EXPOSE 8080

CMD ["python", "app.py"]
