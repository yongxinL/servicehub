#!/bin/bash
set -e

# Validate required environment variables
if [ -z "$LLAMA_MODEL" ]; then
    echo "[ERROR] LLAMA_MODEL is required but is empty or unset" >&2
    exit 1
fi

if [ -z "$LLAMA_ARGS" ]; then
    echo "[ERROR] LLAMA_ARGS is required but is empty or unset" >&2
    exit 1
fi

# Extract the quantization suffix
MODEL_QUANT=$(echo "$LLAMA_MODEL" | awk -F: '{print $2}')
if [ -z "$MODEL_QUANT" ]; then
    MODEL_QUANT="model"
fi

# Define the expected local file path
MODEL_FILE="/models/${MODEL_QUANT}.gguf"

if [ -f "$MODEL_FILE" ]; then
    echo "[ENTRYPOINT] Model file found. Loading directly..."
    echo "[ENTRYPOINT] Command executed: ./llama-server \\"
    echo "    --model ${MODEL_FILE} \\"
    echo "    --host 0.0.0.0 \\"
    echo "    --port ${LLAMA_PORT:-8080}"
    echo "${LLAMA_ARGS}" | sed 's/ --/\n    --/g; s/^--/    --/'
    exec ./llama-server --model ${MODEL_FILE} --host 0.0.0.0 --port ${LLAMA_PORT:-8080} ${LLAMA_ARGS}
fi

echo "[ENTRYPOINT] Model missing. Asking llama-server to download and run..."
echo "[ENTRYPOINT] Command executed: ./llama-server \\"
echo "    --hf-repo ${LLAMA_MODEL} \\"
echo "    --host 0.0.0.0 \\"
echo "    --port ${LLAMA_PORT:-8080}"
echo "${LLAMA_ARGS}" | sed 's/ --/\n    --/g; s/^--/    --/'
exec ./llama-server --hf-repo ${LLAMA_MODEL} --host 0.0.0.0 --port ${LLAMA_PORT:-8080} ${LLAMA_ARGS}
