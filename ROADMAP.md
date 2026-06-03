# Roadmap

## Current (v0.1.0)

- [x] Accelerometer multi-pose calibration (gravity magnitude constraint)
- [x] Gyroscope bias, noise statistics, Allan analysis
- [x] Gyroscope Cg calibration with Kg/Mg decomposition
- [x] Gg (g-sensitivity) fitting
- [x] Temperature models: bg(T) and ba(T) with fixed Ca
- [x] Runtime compensation: `apply_imu_calibration(...)`
- [x] CSV / manifest / single-file / in-memory input
- [x] Full and partial dataset task orchestration
- [x] Python CLI (`python -m imu_calib`)
- [x] MATLAB synchronized implementation
- [x] Validation: static segments, pose errors, angular increment residuals
- [x] Deterministic synthetic example dataset

## Near-term (v0.2.0)

- [ ] Real hardware dataset examples (with anonymized/synthetic replacement)
- [ ] Python ↔ MATLAB numerical consistency verification with tolerance thresholds
- [ ] Temperature model confidence improvements for wider temperature spans
- [ ] Package published to PyPI (`pip install imu-calib`)
- [ ] CI pipeline (GitHub Actions) for Python tests and linting

## Mid-term (v0.3.0)

- [ ] Interactive calibration wizard (guided multi-step CLI)
- [ ] Batch calibration for multiple IMU units
- [ ] Extended validation plots (residual distributions, temperature drift visualization)
- [ ] MATLAB toolbox packaging (`.mltbx`)
- [ ] Documentation site (MkDocs / Sphinx)

## Long-term

- [ ] Online / streaming calibration mode
- [ ] Support for 6-axis and 9-axis IMU configurations
- [ ] Integration with ROS/ROS2 calibration nodes
- [ ] Web-based calibration dashboard
- [ ] Multi-language SDK (C/C++, Rust)
