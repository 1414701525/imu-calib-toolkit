from __future__ import annotations

import shutil
import uuid
from pathlib import Path

import pytest


@pytest.fixture
def tmp_path() -> Path:
    """Workspace-local replacement for pytest's built-in tmp_path fixture.

    The current Windows environment denies access to pytest's default temporary
    directory roots. For this project we only need a writable per-test folder
    inside the repository workspace, so we override tmp_path locally.
    """

    root = Path(__file__).resolve().parent / ".tmp_test_runtime"
    root.mkdir(parents=True, exist_ok=True)
    path = root / f"case_{uuid.uuid4().hex}"
    path.mkdir(parents=True, exist_ok=False)
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)
