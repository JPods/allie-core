#!/usr/bin/env bash
# allie-finetune.sh — Fine-tune a shared Allie/Alice/Natalie/Noelle/Nora model
#
# Pipeline (Apple Silicon / MLX):
#   1. Check corpus — refuse if < MIN_VERIFIED verified entries
#   2. Export corpus in MLX chat format → training/train.jsonl + valid.jsonl
#   3. Install mlx-lm if missing
#   4. Run LoRA fine-tune on base model (llama3.2 default)
#   5. Fuse LoRA adapters into merged model
#   6. Convert to GGUF via llama.cpp (auto-installed if missing)
#   7. Build Modelfile from template, pointing at new GGUF
#   8. Register model in Ollama (allie-v<N>)
#   9. Run smoke test
#  10. Log training run to corpus
#
# Usage:
#   ./allie-finetune.sh                        — train allie-v<next>
#   ./allie-finetune.sh --base deepseek-r1:8b  — use different base model
#   ./allie-finetune.sh --min-verified 200     — raise verified threshold
#   ./allie-finetune.sh --epochs 5             — more training epochs
#   ./allie-finetune.sh --dry-run              — check corpus, print plan, stop
#   ./allie-finetune.sh --domain route-time    — train on one domain only
#
# Output:
#   training/runs/vN/              — all training artifacts
#   training/runs/vN/allie-vN.gguf — the model
#   training/runs/vN/Modelfile     — the Ollama Modelfile
#   Ollama model: allie-vN

set -euo pipefail

ALLIE="$HOME/Allie"
SCRIPTS="$ALLIE/scripts"
TRAINING="$ALLIE/training"
CORPUS="$TRAINING/corpus.jsonl"
MODELFILE_TEMPLATE="$TRAINING/Modelfile.template"

# Defaults
BASE_MODEL="llama3.2"
MIN_VERIFIED=100
EPOCHS=3
ITERS=500        # MLX max iterations (overrides epochs if hit first)
LEARNING_RATE=1e-4
BATCH_SIZE=4
LORA_RANK=8
DRY_RUN=false
DOMAIN_FILTER=""

# ── Argument parsing ───────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)          BASE_MODEL="$2"; shift 2 ;;
    --min-verified)  MIN_VERIFIED="$2"; shift 2 ;;
    --epochs)        EPOCHS="$2"; shift 2 ;;
    --iters)         ITERS="$2"; shift 2 ;;
    --domain)        DOMAIN_FILTER="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# //'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

# ── Step 1: Corpus check ───────────────────────────────────────────────────────

log "Checking corpus: $CORPUS"

[[ -f "$CORPUS" ]] || die "Corpus not found at $CORPUS. Run some sessions first."

TOTAL=$(wc -l < "$CORPUS" | tr -d ' ')
VERIFIED=$(python3 -c "
import json, sys
lines = open('$CORPUS').readlines()
print(sum(1 for l in lines if l.strip() and json.loads(l).get('verified')))
")

log "  Total entries: $TOTAL  |  Verified: $VERIFIED  |  Minimum required: $MIN_VERIFIED"

if (( VERIFIED < MIN_VERIFIED )); then
  echo ""
  echo "  Not enough verified entries to fine-tune."
  echo "  Verified: $VERIFIED / $MIN_VERIFIED required."
  echo ""
  echo "  How to add verified entries:"
  echo "    python3 $SCRIPTS/allie_corpus_log.py add \\"
  echo "      --agent allie --domain route-time \\"
  echo "      --prompt 'Why did station S02 show 35 min at near-zero demand?' \\"
  echo "      --response 'Topology bug — direct south guideway missing.' \\"
  echo "      --verified --ground-truth 'diag_grid.py confirmed 1.1× ratio after fix'"
  echo ""
  echo "  By domain and agent:"
  python3 "$SCRIPTS/allie_corpus_log.py" stats 2>/dev/null || true
  exit 1
fi

# Determine next version number
VERSION=1
if ls "$TRAINING/runs/v"* > /dev/null 2>&1; then
  LAST=$(ls -d "$TRAINING/runs/v"* | sort -V | tail -1 | xargs basename)
  VERSION=$(( ${LAST#v} + 1 ))
fi
MODEL_NAME="allie-v${VERSION}"
RUN_DIR="$TRAINING/runs/v${VERSION}"

log "Plan:"
log "  Base model:  $BASE_MODEL"
log "  New model:   $MODEL_NAME"
log "  Verified entries: $VERIFIED"
log "  Domain filter: ${DOMAIN_FILTER:-all}"
log "  Epochs: $EPOCHS  |  Max iters: $ITERS  |  LoRA rank: $LORA_RANK"
log "  Run dir: $RUN_DIR"

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run — stopping here."
  exit 0
fi

mkdir -p "$RUN_DIR"

# ── Step 2: Export corpus in MLX chat format ───────────────────────────────────

log "Exporting corpus..."

TRAIN_JSONL="$RUN_DIR/train.jsonl"
VALID_JSONL="$RUN_DIR/valid.jsonl"

python3 - <<PYEOF
import json, pathlib, random

corpus_path = pathlib.Path("$CORPUS")
domain_filter = "$DOMAIN_FILTER" or None

entries = [json.loads(l) for l in corpus_path.read_text().splitlines() if l.strip()]
entries = [e for e in entries if e.get("verified")]
if domain_filter:
    entries = [e for e in entries if e.get("domain") == domain_filter]

# Shuffle deterministically
random.seed(42)
random.shuffle(entries)

# 90/10 train/validation split
split = max(1, len(entries) * 9 // 10)
train = entries[:split]
valid = entries[split:]

def to_mlx(entry):
    # MLX chat format: Llama3 instruct template
    return json.dumps({
        "messages": [
            {"role": "user",      "content": entry["prompt"]},
            {"role": "assistant", "content": entry["response"]},
        ]
    })

pathlib.Path("$TRAIN_JSONL").write_text("\n".join(to_mlx(e) for e in train))
pathlib.Path("$VALID_JSONL").write_text("\n".join(to_mlx(e) for e in valid))

print(f"  Train: {len(train)}  Valid: {len(valid)}")
PYEOF

# ── Step 3: Ensure mlx-lm is installed ────────────────────────────────────────

log "Checking mlx-lm..."
if ! python3 -c "import mlx_lm" 2>/dev/null; then
  log "  Installing mlx-lm (Apple Silicon GPU fine-tuning)..."
  pip3 install mlx-lm --quiet || die "mlx-lm install failed. Run: pip3 install mlx-lm"
  log "  mlx-lm installed."
else
  log "  mlx-lm already installed."
fi

# Resolve base model HuggingFace ID for MLX
# MLX fine-tuning uses HF model IDs, not Ollama names
declare -A HF_MAP=(
  ["llama3.2"]="meta-llama/Llama-3.2-3B-Instruct"
  ["llama3.2:latest"]="meta-llama/Llama-3.2-3B-Instruct"
  ["llama3:latest"]="meta-llama/Meta-Llama-3-8B-Instruct"
  ["deepseek-r1:8b"]="deepseek-ai/DeepSeek-R1-Distill-Llama-8B"
  ["deepseek-r1:1.5b"]="deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B"
)
HF_MODEL="${HF_MAP[$BASE_MODEL]:-}"
if [[ -z "$HF_MODEL" ]]; then
  echo "WARNING: No HuggingFace mapping for '$BASE_MODEL'."
  echo "  Known mappings:"
  for k in "${!HF_MAP[@]}"; do echo "    $k → ${HF_MAP[$k]}"; done
  echo "  Set HF_MODEL env var to override, or add mapping to this script."
  die "Cannot continue without HuggingFace model ID."
fi
log "  HuggingFace base: $HF_MODEL"

# ── Step 4: LoRA fine-tune ────────────────────────────────────────────────────

ADAPTERS_DIR="$RUN_DIR/adapters"
log "Starting LoRA fine-tune..."
log "  (This may take 30–120 minutes depending on corpus size and hardware.)"

python3 -m mlx_lm.lora \
  --model "$HF_MODEL" \
  --train \
  --data "$RUN_DIR" \
  --adapter-path "$ADAPTERS_DIR" \
  --num-layers "$LORA_RANK" \
  --batch-size "$BATCH_SIZE" \
  --iters "$ITERS" \
  --learning-rate "$LEARNING_RATE" \
  --steps-per-report 50 \
  --steps-per-eval 100 \
  --save-every 200 \
  2>&1 | tee "$RUN_DIR/finetune.log"

log "Fine-tune complete. Adapters: $ADAPTERS_DIR"

# ── Step 5: Fuse LoRA adapters into merged model ──────────────────────────────

MERGED_DIR="$RUN_DIR/merged"
log "Fusing adapters into merged model..."

python3 -m mlx_lm.fuse \
  --model "$HF_MODEL" \
  --adapter-path "$ADAPTERS_DIR" \
  --save-path "$MERGED_DIR" \
  2>&1 | tee -a "$RUN_DIR/finetune.log"

log "Fused model: $MERGED_DIR"

# ── Step 6: Convert to GGUF ───────────────────────────────────────────────────

GGUF_PATH="$RUN_DIR/${MODEL_NAME}.gguf"
log "Converting to GGUF..."

# Check for llama.cpp convert script
LLAMA_CONVERT=""
for candidate in \
  "$(brew --prefix 2>/dev/null)/bin/llama-convert-hf-to-gguf" \
  "$HOME/.local/bin/convert_hf_to_gguf.py" \
  "/usr/local/bin/convert_hf_to_gguf.py"; do
  [[ -f "$candidate" ]] && { LLAMA_CONVERT="$candidate"; break; }
done

if [[ -z "$LLAMA_CONVERT" ]]; then
  log "  llama.cpp not found — installing via brew..."
  brew install llama.cpp 2>/dev/null || {
    log "  brew install failed. Trying pip install llama-cpp-python..."
    pip3 install llama-cpp-python --quiet || true
  }
  # Try again
  LLAMA_CONVERT="$(brew --prefix 2>/dev/null)/bin/llama-convert-hf-to-gguf"
fi

if [[ -f "$LLAMA_CONVERT" ]]; then
  python3 "$LLAMA_CONVERT" "$MERGED_DIR" \
    --outfile "$GGUF_PATH" \
    --outtype q8_0 \
    2>&1 | tee -a "$RUN_DIR/finetune.log"
  log "GGUF: $GGUF_PATH"
else
  # Fallback: MLX can export directly; Ollama can import MLX models in newer versions
  log "  GGUF conversion unavailable — using MLX model path directly."
  GGUF_PATH="$MERGED_DIR"
fi

# ── Step 7: Build Modelfile ───────────────────────────────────────────────────

MODELFILE_PATH="$RUN_DIR/Modelfile"
log "Building Modelfile..."

[[ -f "$MODELFILE_TEMPLATE" ]] || die "Modelfile template not found at $MODELFILE_TEMPLATE"

# Replace the FROM line with the new model path
sed "s|^FROM .*|FROM $GGUF_PATH|" "$MODELFILE_TEMPLATE" > "$MODELFILE_PATH"

# Append training provenance comment
cat >> "$MODELFILE_PATH" <<EOF

# ── Training provenance ────────────────────────────────────────────────────────
# Model:    $MODEL_NAME
# Base:     $BASE_MODEL ($HF_MODEL)
# Trained:  $(date +%Y-%m-%d)
# Corpus:   $VERIFIED verified entries (domain: ${DOMAIN_FILTER:-all})
# Run dir:  $RUN_DIR
# Epochs:   $EPOCHS  |  Iters: $ITERS  |  LoRA rank: $LORA_RANK
EOF

log "Modelfile: $MODELFILE_PATH"

# ── Step 8: Register in Ollama ────────────────────────────────────────────────

log "Registering $MODEL_NAME in Ollama..."
ollama create "$MODEL_NAME" -f "$MODELFILE_PATH" \
  2>&1 | tee -a "$RUN_DIR/finetune.log"

log "Model registered: $MODEL_NAME"

# ── Step 9: Smoke test ────────────────────────────────────────────────────────

log "Smoke test..."
SMOKE_PROMPT="You are Allie. Bill says station S02 is showing 35 minutes travel time at near-zero demand. What do you do first?"

SMOKE_RESPONSE=$(ollama run "$MODEL_NAME" "$SMOKE_PROMPT" 2>/dev/null | head -20)
echo ""
echo "── Smoke test ────────────────────────────────────────────────────"
echo "Prompt: $SMOKE_PROMPT"
echo ""
echo "Response:"
echo "$SMOKE_RESPONSE"
echo "──────────────────────────────────────────────────────────────────"
echo ""

# Save smoke test result
{
  echo "# Smoke test — $MODEL_NAME"
  echo "Date: $(date +%Y-%m-%d)"
  echo ""
  echo "## Prompt"
  echo "$SMOKE_PROMPT"
  echo ""
  echo "## Response"
  echo "$SMOKE_RESPONSE"
} > "$RUN_DIR/smoke-test.md"

# ── Step 10: Log training run to corpus ──────────────────────────────────────

log "Logging training run..."
python3 - <<PYEOF
import sys
sys.path.insert(0, "$SCRIPTS")
from allie_corpus_log import CorpusLog
CorpusLog().add(
    agent="allie",
    domain="universal",
    prompt="Training run: what model was created and from what corpus?",
    response=(
        "Model: $MODEL_NAME | Base: $BASE_MODEL | "
        "Verified entries: $VERIFIED | Domain: ${DOMAIN_FILTER:-all} | "
        "Date: $(date +%Y-%m-%d) | Run dir: $RUN_DIR"
    ),
    verified=True,
    ground_truth="Produced by allie-finetune.sh run on $(date +%Y-%m-%d)",
    tags=["training", "model-creation", "$MODEL_NAME"],
    model="$BASE_MODEL",
    session_ref="$RUN_DIR",
)
print("  Corpus entry logged.")
PYEOF

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
log "══════════════════════════════════════════════════════════"
log "  Fine-tune complete: $MODEL_NAME"
log ""
log "  To use as Allie's reasoner in deliberation:"
log "    python3 $SCRIPTS/allie-deliberate.py \\"
log "      --reasoner $MODEL_NAME \\"
log "      --prompt 'Your question here'"
log ""
log "  To use as Allie's nightly reflection model:"
log "    python3 $SCRIPTS/allie-reflect.py --model $MODEL_NAME"
log ""
log "  To update allie-reflect LaunchAgent to use $MODEL_NAME:"
log "    Edit $HOME/Library/LaunchAgents/com.allie.reflect.plist"
log "    Add: <string>--model</string><string>$MODEL_NAME</string>"
log "    Then: launchctl unload ~/Library/LaunchAgents/com.allie.reflect.plist"
log "           launchctl load   ~/Library/LaunchAgents/com.allie.reflect.plist"
log ""
log "  Run dir: $RUN_DIR"
log "══════════════════════════════════════════════════════════"
