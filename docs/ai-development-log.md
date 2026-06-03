# AI-Assisted Development Log

This document records the AI-assisted engineering workflows used in developing the IMU Calibration Toolkit.

## Development Approach

The project uses a **human-directed, AI-assisted** development model where:

- **Human** defines requirements, reviews algorithms, validates results, and makes architectural decisions
- **AI agents** assist with code generation, algorithm review, test creation, documentation, and cross-language synchronization

## Key AI-Assisted Workflows

### 1. Algorithm Design & Review

AI agents were used to:
- Review IMU calibration mathematics for correctness and numerical stability
- Analyze edge cases in matrix operations (condition numbers, singular configurations)
- Verify the two-layer temperature model structure (per-point estimation → continuous fitting)
- Cross-check the inverse compensation formula semantics

**Example**: The accelerometer compensation formula `a_corr = Ca * (a_raw - ba)` was reviewed by AI to confirm it correctly handles the scale-misalignment decomposition without introducing small-angle approximation errors.

### 2. Dual-Language Synchronization

Maintaining semantic consistency between Python and MATLAB implementations is a primary challenge. AI assists by:

- Generating MATLAB code from Python algorithm implementations
- Verifying parameter naming, unit conventions, and output structure alignment
- Identifying semantic drift between the two implementations
- Producing mapping tables documenting module-level correspondence

**Artifact**: The [Python ↔ MATLAB Mapping Table](../imu_calib_matlab/docs/00_Python到MATLAB映射表.md) was co-authored with AI to track synchronization status.

### 3. Test Generation

AI generates test cases covering:

- **Calibration accuracy**: verifying fitted matrices against known synthetic ground truth
- **Numerical edge cases**: near-singular configurations, zero-length inputs, NaN propagation
- **Regression scenarios**: ensuring algorithm changes don't break existing behavior
- **Partial data paths**: testing with incomplete datasets (static-only, gyro-only, etc.)

The Python test suite (`tests/`) was largely AI-generated, with human review and validation.

### 4. Documentation Co-Authoring

Technical documentation was co-authored with AI:

- Error model definitions and parameter conventions
- Calibration scheme descriptions (multi-pose gravity constraint)
- API references and usage guides
- Migration documentation (legacy `a_ref` scheme → new multi-pose scheme)

AI helped ensure consistency across 15+ documentation files in two languages.

### 5. Code Migration

The project underwent a significant algorithm migration:

- **From**: Legacy reference-vector approach (`a_ref` required as input)
- **To**: Multi-pose static calibration with gravity magnitude constraint

AI assisted by:
- Analyzing the impact of the migration across all modules
- Generating migration guides documenting field changes and compatibility
- Updating tests to cover both old and new code paths
- Verifying that MATLAB implementation stayed aligned during migration

**Artifact**: [Migration Guide](../imu_calib_python/docs/07_迁移说明_旧参考加速度方案到新方案.md)

### 6. Project Context Management

AI agents maintain project context through structured documents:

- `AGENTS.md` — guidelines for AI agents working on the project
- `docs/` — comprehensive technical documentation serving as knowledge base
- Inline code comments explaining calibration-specific domain concepts

This enables efficient handoff between development sessions and across different AI tools.

## Tools Used

| Tool | Purpose |
|------|---------|
| Claude Code | Primary AI coding assistant for code generation, review, and refactoring |
| Claude (conversation) | Algorithm design discussion, documentation drafting |
| Python pytest | AI-generated test suite for validation |
| MATLAB scripts | AI-assisted MATLAB implementation and cross-checking |

## Development Metrics

- **Languages**: Python (primary), MATLAB (synchronized)
- **Python modules**: ~40 source files across 8 packages
- **MATLAB modules**: ~35 source files across 7 packages
- **Test files**: 14 Python test modules, 13 MATLAB test scripts
- **Documentation**: 20+ markdown files in two languages
- **Synthetic dataset**: deterministic (RNG seed = 42), covering 12 acc poses, 12 gyro runs, 60s static segment

## Lessons Learned

1. **AI excels at cross-language synchronization** — maintaining Python/MATLAB consistency manually is error-prone; AI significantly reduces drift
2. **Domain-specific review is essential** — AI-generated calibration code requires human verification against physical correctness
3. **Structured documentation pays off** — well-documented error models and parameter conventions make AI assistance more effective
4. **Deterministic synthetic data is critical** — using seeded RNG enables reproducible testing across both languages
5. **Migration documentation matters** — AI-generated migration guides help track algorithm evolution and prevent regression
