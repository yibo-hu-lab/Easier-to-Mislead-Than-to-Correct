#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"
export PYTHONPATH="${PROJECT_ROOT}${PYTHONPATH:+:${PYTHONPATH}}"

if [ -x "${PROJECT_ROOT}/.venv/bin/python" ]; then
  PYTHON_BIN="${PYTHON_BIN:-${PROJECT_ROOT}/.venv/bin/python}"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

PERTURBATION_SEED="${PERTURBATION_SEED:-0}"
N_PEERS="${N_PEERS:-6}"
OUTPUT_ROOT="${OUTPUT_ROOT:-${PROJECT_ROOT}/perturbed_dataset}"

if [ "$#" -eq 0 ]; then
  echo "Usage: bash data_processing/run_rq2.sh <normalized-jsonl> [<normalized-jsonl> ...]" >&2
  echo "Input rows must contain original_instance_ID, question, options, and answer." >&2
  exit 1
fi

"${PYTHON_BIN}" -m data_processing.generate_perturbations "$@" \
  --output-root "${OUTPUT_ROOT}" \
  --studies rq2a rq2b \
  --n-peers "${N_PEERS}" \
  --seed "${PERTURBATION_SEED}"
