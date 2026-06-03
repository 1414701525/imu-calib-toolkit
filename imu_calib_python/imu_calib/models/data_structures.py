from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import numpy as np


ArrayLike = np.ndarray


@dataclass(slots=True)
class StaticData:
    """Static IMU data used for bias/noise analysis.

    Units:
    - t: seconds, shape (N,)
    - gyro: rad/s, shape (N, 3)
    - acc: m/s^2, shape (N, 3)
    - temp: optional, shape (N,)
    """

    t: ArrayLike
    gyro: ArrayLike
    acc: ArrayLike
    temp: ArrayLike | None = None


@dataclass(slots=True)
class AccPose:
    """Mean accelerometer measurement under one static pose.

    Current primary schema:
    - acc_mean: measured static mean, shape (3,)
    - pose_name: user-friendly label

    Legacy compatibility:
    - a_ref is optional and deprecated
    - the new accelerometer calibration does not depend on a_ref
    - if present, it is only used as an initialization aid when explicitly
      enabled in options
    """

    acc_mean: ArrayLike
    pose_name: str
    a_ref: ArrayLike | None = None


@dataclass(slots=True)
class GyroRun:
    """Single rotation experiment used for Cg fitting."""

    axis: str
    dir: int
    gyro: ArrayLike
    t: ArrayLike
    theta_ref: ArrayLike
    idx_ss: ArrayLike


@dataclass(slots=True)
class GsensRun:
    """Residual-fitting experiment for gyroscope g-sensitivity."""

    gyro: ArrayLike
    acc_ref: ArrayLike
    t: ArrayLike
    omega_ref: ArrayLike | None = None


@dataclass(slots=True)
class ImuDataset:
    """Top-level dataset container aligned with the MATLAB project semantics.

    The MATLAB reference project now supports partial datasets:
    - static-only
    - acc_poses-only
    - gyro_runs-only
    - gsens_runs-only

    Python keeps the same semantics by making every block optional at the
    container level. Task runners, not the loader, decide which modules can run.
    """

    static: StaticData | None = None
    acc_poses: list[AccPose] = field(default_factory=list)
    gyro_runs: list[GyroRun] = field(default_factory=list)
    gsens_runs: list[GsensRun] = field(default_factory=list)
    meta: dict[str, Any] = field(default_factory=dict)

    @property
    def has_static(self) -> bool:
        return self.static is not None and self.static.gyro.size != 0

    @property
    def has_acc_poses(self) -> bool:
        return bool(self.acc_poses)

    @property
    def has_gyro_runs(self) -> bool:
        return bool(self.gyro_runs)

    @property
    def has_gsens_runs(self) -> bool:
        return bool(self.gsens_runs)
