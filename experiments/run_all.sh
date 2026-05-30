#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

bash "${SCRIPT_DIR}/run_rq1.sh"
bash "${SCRIPT_DIR}/run_rq2.sh"
bash "${SCRIPT_DIR}/run_rq3_cot.sh"
bash "${SCRIPT_DIR}/run_rq3_self_reflect.sh"
