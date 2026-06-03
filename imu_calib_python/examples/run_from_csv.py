from __future__ import annotations

import argparse
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from imu_calib.pipelines import run_csv_pipeline


def run_from_csv(csv_dir: str):
    return run_csv_pipeline(csv_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run IMU calibration from a CSV folder, manifest bundle, or supported single CSV.")
    parser.add_argument("csv_dir", help="Path to a dataset folder or to static.csv / acc_poses.csv / gyro_runs.csv / gsens_runs.csv.")
    args = parser.parse_args()
    run_from_csv(args.csv_dir)


if __name__ == "__main__":
    main()
