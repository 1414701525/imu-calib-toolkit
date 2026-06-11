# GitHub Issues Drafts

This file contains draft GitHub issues for the IMU Calibration Toolkit project.
These are planned issues to be created on GitHub when ready.

---

## Issue 1: Improve quick-start examples for Python calibration workflow

**Title**: Improve quick-start examples for Python calibration workflow

**Type/Label**: `enhancement`, `documentation`

**Background**:

The current quick-start section in README.md covers basic CLI usage but lacks step-by-step examples showing the complete calibration workflow. New users may struggle to understand:
- How to prepare their own dataset
- How to interpret calibration results
- How to use runtime compensation in their own code

**Planned work**:

1. Create `imu_calib_python/examples/quickstart_acc_calibration.py` — step-by-step accelerometer calibration with inline comments
2. Create `imu_calib_python/examples/quickstart_gyro_calibration.py` — gyroscope bias and noise analysis example
3. Create `imu_calib_python/examples/quickstart_runtime_comp.py` — runtime compensation integration example
4. Update `imu_calib_python/README.md` with links to new examples
5. Add expected output descriptions for each example

**Acceptance criteria**:

- [ ] Each example runs successfully with bundled synthetic data
- [ ] Each example has clear inline comments explaining each step
- [ ] README.md links to all examples with brief descriptions
- [ ] Examples demonstrate both CLI and Python API usage
- [ ] No private data or internal paths in examples

---

## Issue 2: Add MATLAB/Python result consistency checks

**Title**: Add MATLAB/Python result consistency checks

**Type/Label**: `enhancement`, `testing`

**Background**:

Python and MATLAB implementations should produce numerically consistent results given the same input data. Currently, there is no automated verification that both implementations match within acceptable tolerances. This makes it difficult to detect semantic drift between the two implementations.

**Planned work**:

1. Create `tests/test_cross_language_consistency.py` that:
   - Loads calibration results from both Python and MATLAB (saved as JSON/CSV)
   - Compares key matrices (Ca, Cg, ba, bg, Gg) within tolerance
   - Reports pass/fail for each comparison
2. Create `imu_calib_matlab/tests/test_python_matlab_consistency.m` for MATLAB side
3. Define tolerance thresholds for each calibration parameter
4. Add documentation explaining expected differences and acceptable tolerances
5. Create a shared reference dataset that both languages can use

**Acceptance criteria**:

- [ ] Test script compares all major calibration outputs
- [ ] Tolerance thresholds are documented and justified
- [ ] Tests pass with current bundled synthetic data
- [ ] Clear error messages when consistency check fails
- [ ] Documentation explains how to run cross-language verification

---

## Issue 3: Expand documentation for IMU calibration model assumptions

**Title**: Expand documentation for IMU calibration model assumptions

**Type/Label**: `documentation`

**Background**:

The current documentation describes the calibration formulas but does not clearly explain the underlying assumptions and limitations of each model. Users working with different IMU types or operating conditions may not understand when the models are applicable.

**Planned work**:

1. Expand `imu_calib_python/docs/02_IMU误差模型与参数定义.md` with:
   - Assumptions for accelerometer model (small angle, gravity magnitude, etc.)
   - Assumptions for gyroscope model (constant bias, temperature linearity, etc.)
   - Assumptions for cross-axis model (symmetry, small misalignment, etc.)
   - When each assumption breaks down
2. Create `docs/calibration_model_assumptions.md` (English version) with:
   - Mathematical derivations with cited references
   - Physical intuition for each assumption
   - Practical guidance on when to use each model
3. Add "Assumptions" section to each calibration scheme documentation
4. Include a decision tree for selecting appropriate calibration models

**Acceptance criteria**:

- [ ] Each calibration model has documented assumptions
- [ ] Assumptions include physical justification
- [ ] Limitations and breakdown conditions are clearly stated
- [ ] Decision tree helps users select appropriate models
- [ ] Both Chinese and English documentation are updated

---

## Issue 4: Add more unit tests for calibration edge cases

**Title**: Add more unit tests for calibration edge cases

**Type/Label**: `testing`, `enhancement`

**Background**:

The current test suite covers basic calibration accuracy but may not adequately test edge cases that can occur with real-world data. Improving test coverage for edge cases will make the toolkit more robust.

**Planned work**:

1. Add tests for **numerical edge cases**:
   - Near-singular configurations (all poses in same plane)
   - Very small datasets (minimum required poses)
   - Large condition numbers in calibration matrices
   - NaN/Inf propagation in input data
2. Add tests for **data quality edge cases**:
   - Non-static segments detected as static
   - Temperature drift during static segments
   - Outlier measurements in calibration data
3. Add tests for **partial dataset paths**:
   - Static-only dataset (no gyro data)
   - Gyro-only dataset (no accelerometer poses)
   - Missing temperature data
4. Add tests for **result validation**:
   - Calibration matrices with unreasonable values
   - Bias estimates outside physical range
   - Scale factors outside expected bounds

**Acceptance criteria**:

- [ ] Test coverage increases for all calibration modules
- [ ] Each edge case has clear test description
- [ ] Tests use deterministic synthetic data (no random failures)
- [ ] Edge cases are documented in test comments
- [ ] All existing tests continue to pass

---

## Issue 5: Prepare v0.2.0 roadmap

**Title**: Prepare v0.2.0 roadmap

**Type/Label**: `roadmap`, `planning`

**Background**:

v0.1.0 establishes the foundation with core calibration capabilities. v0.2.0 should focus on improving usability, adding CI/CD, and preparing for broader distribution. A clear roadmap helps prioritize work and attract contributors.

**Planned work**:

1. Review and refine ROADMAP.md Near-term (v0.2.0) section
2. Create `docs/roadmap/v0.2.0-plan.md` with detailed plans for:
   - **PyPI packaging** — `pip install imu-calib` workflow
   - **CI/CD pipeline** — GitHub Actions for tests, linting, type checking
   - **Real hardware examples** — anonymized datasets from actual IMU units
   - **Cross-language verification** — automated Python/MATLAB consistency checks
   - **Documentation improvements** — expanded examples, model assumptions
3. Prioritize items based on:
   - Community value (what users need most)
   - Maintenance burden (what reduces ongoing effort)
   - Visibility (what demonstrates project quality)
4. Define acceptance criteria for v0.2.0 release
5. Create GitHub milestones for tracking

**Acceptance criteria**:

- [ ] ROADMAP.md v0.2.0 section is detailed and actionable
- [ ] v0.2.0 plan document exists with implementation details
- [ ] Priorities are justified with clear rationale
- [ ] GitHub milestones are created for tracking
- [ ] Each planned feature has defined acceptance criteria

---

## Notes

- These drafts are templates; refine before creating actual GitHub issues
- Add screenshots or diagrams where helpful
- Link issues to relevant documentation and code
- Use GitHub labels consistently: `enhancement`, `documentation`, `testing`, `roadmap`
- Consider creating a GitHub Project board for v0.2.0 tracking
