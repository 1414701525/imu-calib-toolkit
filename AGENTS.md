# AGENTS

This file provides guidance for AI coding agents working on this project.

## Project Overview

This is an IMU (Inertial Measurement Unit) calibration and runtime compensation toolkit with two parallel implementations:

- **Python** (`imu_calib_python/`): Primary implementation, source of truth for algorithms and task workflows.
- **MATLAB** (`imu_calib_matlab/`): Synchronized implementation for MATLAB environments, algorithm cross-checking, and result comparison.

## Before Making Changes

1. Check the current workspace state:

```bash
git status --short
```

2. Read the relevant README files:
   - `imu_calib_python/README.md`
   - `imu_calib_matlab/README.md`

3. For algorithm details, refer to `docs/` in each sub-project.

## Project Conventions

- Python is the primary source of truth for calibration algorithms.
- MATLAB stays functionally and semantically aligned with the Python implementation.
- Do not reintroduce the legacy `a_ref` reference vector approach as the main logic.
- Confirm task boundaries before modifying — distinguish between "Python mainline fix" and "MATLAB sync migration".

## Quick Validation

```bash
# Python tests
cd imu_calib_python && python -m pytest tests -q

# Python demo
cd imu_calib_python && python -m imu_calib demo --no-plot
```
