#!/usr/bin/env python3
"""Generate social-pressure perturbations from normalized MCQA JSONL files.

Input rows must already use the normalized schema expected by the experiment
runners: at minimum `original_instance_ID`, `question`, `options`, and `answer`.
This compact artifact intentionally excludes source-dataset sampling code.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from data_processing.common.io_utils import load_jsonl, write_jsonl
from data_processing.common.perturbations import (
    RQ1_RQ3_CONDITIONS,
    RQ2A_CONDITIONS,
    RQ2B_CONDITIONS,
    generate_rq1_rq3_rows,
    generate_rq2a_rows,
    generate_rq2b_rows,
    write_metadata,
)


REQUIRED_KEYS = {"original_instance_ID", "question", "options", "answer"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate RQ1/RQ3, RQ2a, and RQ2b social-pressure perturbations."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        help="Normalized JSONL files with original_instance_ID/question/options/answer.",
    )
    parser.add_argument(
        "--output-root",
        default="perturbed_dataset",
        help="Root directory for perturbed outputs.",
    )
    parser.add_argument(
        "--studies",
        nargs="+",
        choices=("rq1_rq3", "rq2a", "rq2b", "all"),
        default=("all",),
        help="Study perturbation sets to generate.",
    )
    parser.add_argument("--n-peers", type=int, default=6)
    parser.add_argument("--seed", type=int, default=0)
    return parser.parse_args()


def selected_studies(raw_studies: list[str]) -> set[str]:
    if "all" in raw_studies:
        return {"rq1_rq3", "rq2a", "rq2b"}
    return set(raw_studies)


def infer_dataset_name(path: Path, rows: list[dict[str, Any]]) -> str:
    if rows:
        dataset_name = rows[0].get("dataset_name")
        if isinstance(dataset_name, str) and dataset_name.strip():
            return dataset_name.strip()
    return path.stem


def validate_rows(path: Path, rows: list[dict[str, Any]]) -> None:
    for index, row in enumerate(rows, start=1):
        missing = REQUIRED_KEYS - set(row)
        if missing:
            missing_text = ", ".join(sorted(missing))
            raise ValueError(f"{path}:{index} missing required keys: {missing_text}")


def write_study_outputs(
    *,
    output_path: Path,
    metadata_path: Path,
    rows: list[dict[str, Any]],
    metadata: dict[str, Any],
) -> None:
    write_jsonl(rows, output_path)
    metadata.update(
        {
            "output_path": str(output_path),
            "n_output_rows": len(rows),
        }
    )
    write_metadata(metadata, metadata_path)
    print(f"Generated {output_path}")


def main() -> None:
    args = parse_args()
    output_root = Path(args.output_root)
    studies = selected_studies(list(args.studies))

    for raw_input in args.inputs:
        input_path = Path(raw_input)
        normalized_rows = load_jsonl(input_path)
        validate_rows(input_path, normalized_rows)
        dataset_name = infer_dataset_name(input_path, normalized_rows)

        base_metadata = {
            "dataset_name": dataset_name,
            "input_path": str(input_path),
            "generation_source": "normalized_jsonl",
            "sampling_seed": None,
            "perturbation_seed": args.seed,
            "n_input_rows": len(normalized_rows),
            "n_peers": args.n_peers,
        }

        if "rq1_rq3" in studies:
            rows = generate_rq1_rq3_rows(
                normalized_rows,
                n_peers=args.n_peers,
                seed=args.seed,
            )
            write_study_outputs(
                output_path=output_root / "rq1_rq3" / "data" / input_path.name,
                metadata_path=(
                    output_root
                    / "rq1_rq3"
                    / "metadata"
                    / f"{input_path.stem}.metadata.json"
                ),
                rows=rows,
                metadata={
                    **base_metadata,
                    "study_id": "rq1_rq3",
                    "conditions": [
                        condition["condition_id"] for condition in RQ1_RQ3_CONDITIONS
                    ],
                },
            )

        if "rq2a" in studies:
            rows = generate_rq2a_rows(
                normalized_rows,
                n_peers=args.n_peers,
                seed=args.seed,
            )
            write_study_outputs(
                output_path=output_root / "rq2" / "rq2a" / "data" / input_path.name,
                metadata_path=(
                    output_root
                    / "rq2"
                    / "rq2a"
                    / "metadata"
                    / f"{input_path.stem}.metadata.json"
                ),
                rows=rows,
                metadata={
                    **base_metadata,
                    "study_id": "rq2a",
                    "conditions": [
                        condition["condition_id"] for condition in RQ2A_CONDITIONS
                    ],
                    "note": (
                        "rq2a_commit6 reuses the mixed consensus + authority absent "
                        "construction from the RQ1/RQ3 pipeline."
                    ),
                },
            )

        if "rq2b" in studies:
            rows = generate_rq2b_rows(
                normalized_rows,
                n_peers=args.n_peers,
                seed=args.seed,
            )
            write_study_outputs(
                output_path=output_root / "rq2" / "rq2b" / "data" / input_path.name,
                metadata_path=(
                    output_root
                    / "rq2"
                    / "rq2b"
                    / "metadata"
                    / f"{input_path.stem}.metadata.json"
                ),
                rows=rows,
                metadata={
                    **base_metadata,
                    "study_id": "rq2b",
                    "conditions": [
                        condition["condition_id"] for condition in RQ2B_CONDITIONS
                    ],
                },
            )


if __name__ == "__main__":
    main()
