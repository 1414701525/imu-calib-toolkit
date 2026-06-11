# Contributing to IMU Calibration Toolkit

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Welcome Contributions

We welcome the following types of contributions:

- **Documentation improvements** — fix typos, clarify explanations, add examples
- **Bug reports** — report issues with calibration algorithms, CLI, or documentation
- **Synthetic/public-safe example datasets** — add deterministic datasets for testing
- **Python implementation improvements** — performance, code quality, new features
- **MATLAB implementation improvements** — keep synchronized with Python implementation
- **Unit tests and validation scripts** — improve test coverage and edge case handling
- **Calibration workflow examples** — demonstrate real-world usage patterns
- **Embedded/runtime compensation examples** — show integration patterns

## Prohibited Content

**Do NOT submit** any of the following:

- ❌ Private company code or internal implementations
- ❌ Internal logs, test data, or debug outputs
- ❌ API keys, tokens, passwords, or credentials
- ❌ Proprietary datasets or confidential hardware parameters
- ❌ Internal file paths, project names, or organizational references
- ❌ Real hardware recordings without proper anonymization

All contributions must be **public-safe**. When in doubt, ask in an issue first.

## Contribution Process

1. **Open an issue** — describe the bug or feature request
2. **Fork the repository** — create your own copy
3. **Create a feature branch** — `git checkout -b feature/your-feature-name`
4. **Make focused changes** — keep changes small and atomic
5. **Add/update tests** — ensure your changes are covered by tests
6. **Open a pull request** — link to the original issue

## Development Guidelines

### Dual-Language Consistency

- Python and MATLAB implementations must share **same algorithm semantics**
- Parameter names, units, and output structures should align
- Use the [Python ↔ MATLAB Mapping Table](imu_calib_matlab/docs/00_Python到MATLAB映射表.md) to track synchronization

### Documentation Requirements

When modifying any of the following, **update documentation simultaneously**:

- Calibration formulas or mathematical models
- Compensation logic or algorithms
- Data formats or input/output structures
- CLI arguments or API changes

### Testing

```bash
# Python tests
cd imu_calib_python
python -m pytest tests -q

# Python demo (verify no regressions)
python -m imu_calib demo --no-plot
```

### Code Style

- Python: follow existing code conventions in `imu_calib_python/`
- MATLAB: follow existing code conventions in `imu_calib_matlab/`
- Use meaningful variable names that reflect IMU domain concepts

## Reporting Bugs

When reporting bugs, please include:

1. **Description** — what happened vs. what you expected
2. **Reproduction steps** — minimal steps to reproduce
3. **Environment** — Python/MATLAB version, OS
4. **Dataset** — which dataset (bundled synthetic or your own)
5. **Error output** — full traceback or error message

## Questions?

- Open an issue for questions about usage or contribution
- See [ROADMAP.md](ROADMAP.md) for planned features and areas where help is needed
- See [docs/](docs/) for project documentation index

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
