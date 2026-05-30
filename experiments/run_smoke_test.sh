#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

if [ -x "${PROJECT_ROOT}/.venv/bin/python" ]; then
  PYTHON_BIN="${PYTHON_BIN:-${PROJECT_ROOT}/.venv/bin/python}"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi

MODELS=(
  "qwen25_it"
  "mistral_it"
  "gemma2_it"
  "llama31_it"
)

TEST_ROWS="${TEST_ROWS:-5}"
RUN_SEED="${RUN_SEED:-42}"
RESULTS_ROOT="${RESULTS_ROOT:-${PROJECT_ROOT}/results/test_run}"
INPUT_ROOT="${RESULTS_ROOT}/_inputs"

prepare_inputs() {
  local source_dir="$1"
  local target_dir="$2"
  local source_paths=( "${source_dir}/"*.jsonl )

  if [ "${#source_paths[@]}" -eq 0 ]; then
    echo "No input datasets found under ${source_dir}" >&2
    exit 1
  fi

  mkdir -p "${target_dir}"
  for source_path in "${source_paths[@]}"; do
    head -n "${TEST_ROWS}" "${source_path}" > "${target_dir}/$(basename "${source_path}")"
  done
}

run_variant() {
  local label="$1"
  local runner_script="$2"
  local input_dir="$3"
  local results_subdir="$4"
  local batch_size="$5"
  local max_tokens="$6"
  local input_paths=( "${input_dir}/"*.jsonl )

  if [ "${#input_paths[@]}" -eq 0 ]; then
    echo "No smoke-test inputs found under ${input_dir}" >&2
    exit 1
  fi

  for model_id in "${MODELS[@]}"; do
    for input_path in "${input_paths[@]}"; do
      local task_name
      local output_dir
      task_name="$(basename "${input_path}" .jsonl)"
      output_dir="${RESULTS_ROOT}/${results_subdir}/${model_id}/seed_${RUN_SEED}"
      mkdir -p "${output_dir}"

      echo "Running ${label} model=${model_id} dataset=${task_name}"
      "${PYTHON_BIN}" "${runner_script}" \
        --model_id "${model_id}" \
        --input_path "${input_path}" \
        --output_path "${output_dir}/${task_name}.jsonl" \
        --batch_size "${batch_size}" \
        --max_attempts 3 \
        --max_tokens "${max_tokens}" \
        --seed "${RUN_SEED}" \
        --save_every 1
    done
  done
}

prepare_inputs "${PROJECT_ROOT}/perturbed_dataset/rq1_rq3/data" "${INPUT_ROOT}/rq1_rq3"
prepare_inputs "${PROJECT_ROOT}/perturbed_dataset/rq2/rq2a/data" "${INPUT_ROOT}/rq2a"
prepare_inputs "${PROJECT_ROOT}/perturbed_dataset/rq2/rq2b/data" "${INPUT_ROOT}/rq2b"

run_variant "RQ1" "${SCRIPT_DIR}/run_studies_base.py" "${INPUT_ROOT}/rq1_rq3" "rq1" 2 32
run_variant "RQ2a" "${SCRIPT_DIR}/run_studies_base.py" "${INPUT_ROOT}/rq2a" "rq2a" 2 32
run_variant "RQ2b" "${SCRIPT_DIR}/run_studies_base.py" "${INPUT_ROOT}/rq2b" "rq2b" 2 32
run_variant "RQ3a" "${SCRIPT_DIR}/run_studies_cot.py" "${INPUT_ROOT}/rq1_rq3" "rq3a" 2 384
run_variant "RQ3b" "${SCRIPT_DIR}/run_studies_self_reflect.py" "${INPUT_ROOT}/rq1_rq3" "rq3b" 2 128

echo "Smoke-test inputs saved under ${INPUT_ROOT}"
echo "Smoke-test results saved under ${RESULTS_ROOT}"
