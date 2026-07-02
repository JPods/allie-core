#!/bin/bash
# Pull large models for the agent team
# Run: bash ~/Allie/scripts/pull-models.sh

echo "=== Pulling models to default Ollama location ==="
echo "These will be symlinked or moved to 5TB after download"
echo ""

echo "[1/3] qwen2.5:72b (may already be done)..."
ollama pull qwen2.5:72b

echo "[2/3] deepseek-r1:70b..."
ollama pull deepseek-r1:70b

echo "[3/3] llama3.3:70b..."
ollama pull llama3.3:70b

echo ""
echo "=== All models pulled ==="
ollama list
