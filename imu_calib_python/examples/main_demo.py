from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from imu_calib.pipelines import run_demo_pipeline


if __name__ == "__main__":
    run_demo_pipeline()
