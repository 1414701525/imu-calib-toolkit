# IMU Calibration Toolkit

A dual-language (Python + MATLAB) IMU calibration and runtime compensation toolkit, developed with AI-assisted engineering workflows.

## Overview

This toolkit provides a complete pipeline for IMU (Inertial Measurement Unit) sensor calibration, covering:

- **Accelerometer calibration** — multi-pose static calibration with gravity magnitude constraint
- **Gyroscope calibration** — bias estimation, noise statistics, Allan deviation analysis
- **Cross-axis compensation** — Cg matrix fitting with Kg/Mg decomposition
- **G-sensitivity** — Gg matrix fitting for gravity-dependent gyro bias
- **Temperature compensation** — bg(T) and ba(T) temperature-dependent bias models
- **Runtime compensation** — single-call `apply_imu_calibration()` for production use

Both Python and MATLAB implementations share the same algorithm semantics, parameter definitions, and output structure.

## Quick Start

### Python

```bash
cd imu_calib_python
pip install -r requirements.txt

# Run with bundled synthetic data
python -m imu_calib demo

# Run with CSV dataset
python -m imu_calib run-csv data/example_dataset_bundle

# Run tests
python -m pytest tests -q
```

### MATLAB

```matlab
cd('imu_calib_matlab');
addpath(genpath(fullfile(pwd, 'src')));

% Run demo
main_demo

% Run with CSV dataset
results = run_from_csv('data/example_dataset_bundle');
```

## Project Structure

```
imu-calib-toolkit/
├── imu_calib_python/          # Python implementation (primary)
│   ├── imu_calib/             # Core library
│   │   ├── calib/             # Calibration algorithms
│   │   ├── io/                # Data loading and export
│   │   ├── models/            # Data structures and options
│   │   ├── runtime/           # Runtime compensation and results
│   │   ├── tasks/             # Task orchestration
│   │   ├── utils/             # Math utilities and segment detection
│   │   └── validate/          # Validation and plotting
│   ├── data/                  # Synthetic example datasets
│   ├── docs/                  # Algorithm and usage documentation
│   ├── examples/              # Usage examples
│   └── tests/                 # pytest test suite
│
├── imu_calib_matlab/          # MATLAB synchronized implementation
│   ├── src/                   # Source code (mirrors Python structure)
│   ├── data/                  # Example datasets
│   ├── docs/                  # Documentation and mapping table
│   ├── scripts/               # Utility scripts
│   ├── tests/                 # MATLAB test scripts
│   ├── main_demo.m            # Demo entry point
│   └── run_from_csv.m         # CSV pipeline entry point
│
├── AGENTS.md                  # AI agent development guidelines
├── ROADMAP.md                 # Project roadmap
└── LICENSE                    # MIT License
```

## Calibration Model

### Accelerometer

```
a_corr = Ca * (a_raw - ba)
```

Where `Ca` is the combined scale/misalignment matrix and `ba` is the bias vector.

### Gyroscope

```
omega_ref = Cg^{-1} * (omega_raw - bg(T) - Gg * f)
```

Where `Cg = I + Kg + Mg` (scale + misalignment), `bg(T)` is temperature-dependent bias, and `Gg * f` is the g-sensitivity term.

### Temperature Models

Both `bg(T)` and `ba(T)` use a two-layer structure:
1. Per-temperature-point bias sample estimation from static segments
2. Continuous polynomial model fitting over the temperature range

## AI-Assisted Development

This project was developed using AI-assisted engineering workflows, including:

- **Algorithm design and review** — AI agents assist in reviewing calibration math, numerical stability, and edge cases
- **Dual-language synchronization** — AI helps maintain semantic consistency between Python and MATLAB implementations
- **Test generation** — AI generates test cases covering calibration accuracy, numerical edge cases, and regression scenarios
- **Documentation** — Technical docs (error models, calibration schemes, API references) are co-authored with AI
- **Code migration** — Legacy algorithm migration (old `a_ref` scheme → new multi-pose scheme) was guided by AI analysis

See [AGENTS.md](AGENTS.md) for the AI agent development guidelines used in this project.

## Documentation

### Python

- [Project Overview](imu_calib_python/docs/01_项目总览.md)
- [Error Model & Parameters](imu_calib_python/docs/02_IMU误差模型与参数定义.md)
- [Accelerometer Calibration](imu_calib_python/docs/03_加速度计静止多姿态标定方案.md)
- [Compensation Algorithm](imu_calib_python/docs/04_补偿算法与运行流程.md)
- [Input Requirements](imu_calib_python/docs/05_输入文件与数据采集要求.md)
- [Usage Guide](imu_calib_python/docs/06_使用方法.md)
- [Developer Notes](imu_calib_python/docs/08_开发者补充说明.md)

### MATLAB

- [Python ↔ MATLAB Mapping](imu_calib_matlab/docs/00_Python到MATLAB映射表.md)
- [Error Model & Parameters](imu_calib_matlab/docs/02_IMU误差模型与参数定义.md)
- [Usage Guide](imu_calib_matlab/docs/06_使用方法.md)
- [Temperature Calibration](imu_calib_matlab/docs/温度标定.md)

## Example Data

The bundled datasets are **deterministic synthetic data** (RNG seed = 42), generated programmatically. They are not real hardware recordings and are safe for testing and demonstration.

To use your own data, prepare CSV files following the format described in the [Input Requirements](imu_calib_python/docs/05_输入文件与数据采集要求.md) documentation.

## Dependencies

### Python

- Python >= 3.10
- numpy >= 1.24
- scipy >= 1.10
- pandas >= 2.0
- matplotlib >= 3.7
- pytest >= 8.0 (dev)

### MATLAB

- MATLAB (tested with R2024b+)
- Optimization Toolbox (for some fitting routines)

## Project Status

**Current release**: [v0.1.0](docs/releases/v0.1.0.md) - Initial public release

See [ROADMAP.md](ROADMAP.md) for planned features and development timeline.

## Public-Safe Notice

This repository contains only **public-safe content**:

- All datasets are synthetic (deterministic RNG seed = 42)
- No private company code, internal logs, or proprietary data
- No API keys, tokens, or credentials
- No internal file paths or project names

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on keeping contributions public-safe.

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening issues or pull requests.

For planned features and future work, see [ROADMAP.md](ROADMAP.md) and the open GitHub Issues.
