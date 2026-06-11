# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please send an email to the maintainers with:

1. A description of the vulnerability
2. Steps to reproduce the issue
3. Potential impact assessment
4. Suggested fix (if available)

## Response Timeline

- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix or mitigation**: depends on severity and complexity

## Scope

This is a calibration toolkit that processes sensor data. The main security considerations are:

- **No network communication** — all processing is local
- **No authentication** — no credentials or tokens involved
- **No external dependencies with known vulnerabilities** — see `requirements.txt`
- **Synthetic data only** — bundled datasets contain no real hardware recordings

## Best Practices

When using this toolkit:

- Validate your own input data before processing
- Do not expose calibration results containing sensitive hardware parameters
- Keep dependencies updated (`pip install -U -r requirements.txt`)

## Security-Related Configuration

This repository has the following GitHub security features enabled:

- Dependabot alerts (recommended)
- Code scanning (recommended)
- Secret scanning (recommended)

See [GitHub Security documentation](https://docs.github.com/en/code-security) for more information.
