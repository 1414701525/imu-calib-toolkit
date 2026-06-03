from __future__ import annotations

import json
import re
from pathlib import Path

import numpy as np
import pandas as pd

from imu_calib.models.data_structures import AccPose, GsensRun, GyroRun, ImuDataset, StaticData
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import validate_time_vector


def load_csv_data(csv_dir: str | Path) -> ImuDataset:
    """Load IMU calibration data from a CSV folder, manifest bundle, or supported single CSV.

    MATLAB has moved to a partial-loading strategy:
    - no single CSV is globally mandatory
    - missing unrelated files do not block loading
    - loader returns available blocks plus missing-file metadata

    Python mirrors that behavior here. Task-level wrappers decide which modules
    can run from the loaded subset.
    """

    input_path = Path(csv_dir).expanduser().resolve()
    if not input_path.exists():
        raise ImuCalibError(f"CSV folder or file not found: {input_path}")

    layout = _resolve_dataset_layout(input_path)

    static = _load_static_csv(layout["static"]) if _existing_file(layout["static"]) else None
    acc_poses = _load_acc_poses_csv(layout["acc_poses"]) if _existing_file(layout["acc_poses"]) else []
    gyro_runs = _load_gyro_runs_csv(layout["gyro_runs"]) if _existing_file(layout["gyro_runs"]) else []
    gsens_runs = _load_gsens_runs_csv(layout["gsens_runs"]) if _existing_file(layout["gsens_runs"]) else []

    dataset = ImuDataset(
        static=static,
        acc_poses=acc_poses,
        gyro_runs=gyro_runs,
        gsens_runs=gsens_runs,
        meta=_build_meta(layout, input_path, static, acc_poses, gyro_runs, gsens_runs),
    )

    if not dataset.meta["available_blocks"]:
        raise ImuCalibError(f"No supported IMU calibration CSV blocks were found in: {input_path}")

    return dataset


def _resolve_dataset_layout(path: Path) -> dict[str, Path | str | None]:
    if path.is_file():
        if path.suffix.lower() != ".csv":
            raise ImuCalibError("If a file path is provided, it must point to a supported CSV file.")
        base = path.stem.lower()
        layout = {
            "manifest": None,
            "static": None,
            "acc_poses": None,
            "gyro_runs": None,
            "gsens_runs": None,
            "source": "",
        }
        if base == "static":
            layout["static"] = path
            layout["source"] = "single_static_csv"
        elif base == "acc_poses":
            layout["acc_poses"] = path
            layout["source"] = "single_acc_poses_csv"
        elif base == "gyro_runs":
            layout["gyro_runs"] = path
            layout["source"] = "single_gyro_runs_csv"
        elif base == "gsens_runs":
            layout["gsens_runs"] = path
            layout["source"] = "single_gsens_runs_csv"
        else:
            raise ImuCalibError(
                "Direct file input only supports static.csv, acc_poses.csv, gyro_runs.csv, or gsens_runs.csv."
            )
        return layout

    manifest = path / "dataset_manifest.json"
    layout = {
        "manifest": manifest,
        "static": path / "static.csv",
        "acc_poses": path / "acc_poses.csv",
        "gyro_runs": path / "gyro_runs.csv",
        "gsens_runs": path / "gsens_runs.csv",
        "source": "legacy_csv_folder",
    }

    if not manifest.exists():
        return layout

    payload = json.loads(manifest.read_text(encoding="utf-8"))
    if "files" not in payload or not isinstance(payload["files"], dict):
        raise ImuCalibError(f'Manifest file {manifest} must contain a "files" object.')

    files = payload["files"]
    layout["static"] = path / files["static"] if "static" in files else None
    layout["acc_poses"] = path / files["acc_poses"] if "acc_poses" in files else None
    layout["gyro_runs"] = path / files["gyro_runs"] if "gyro_runs" in files else None
    layout["gsens_runs"] = path / files["gsens_runs"] if "gsens_runs" in files else None
    layout["source"] = "manifest_bundle"
    return layout


def _build_meta(
    layout: dict[str, Path | str | None],
    input_path: Path,
    static: StaticData | None,
    acc_poses: list[AccPose],
    gyro_runs: list[GyroRun],
    gsens_runs: list[GsensRun],
) -> dict:
    available_blocks: list[str] = []
    if static is not None and static.gyro.size:
        available_blocks.append("static")
    if acc_poses:
        available_blocks.append("acc_poses")
    if gyro_runs:
        available_blocks.append("gyro_runs")
    if gsens_runs:
        available_blocks.append("gsens_runs")

    missing_files: list[str] = []
    if not available_blocks or "static" not in available_blocks:
        missing_files.append("static.csv")
    if "acc_poses" not in available_blocks:
        missing_files.append("acc_poses.csv")
    if "gyro_runs" not in available_blocks:
        missing_files.append("gyro_runs.csv")
    if "gsens_runs" not in available_blocks:
        missing_files.append("gsens_runs.csv")

    messages: list[str] = []
    source = str(layout["source"])
    if source == "single_static_csv":
        messages.append("Loaded static.csv directly. Only static-dependent modules are immediately available.")
    elif source == "single_acc_poses_csv":
        messages.append("Loaded acc_poses.csv directly. Only accelerometer multi-pose calibration is immediately available.")
    elif source == "single_gyro_runs_csv":
        messages.append("Loaded gyro_runs.csv directly. Gyro Cg calibration still requires bg or static.gyro.")
    elif source == "single_gsens_runs_csv":
        messages.append("Loaded gsens_runs.csv directly. Gg fitting still requires bg and Cg.")
    elif not missing_files:
        messages.append("Loaded all standard dataset blocks.")
    else:
        messages.append(f"Loaded partial dataset. Missing files: {', '.join(missing_files)}.")

    available_tasks = _derive_available_tasks(available_blocks)
    return {
        "source": source,
        "input_path": str(input_path),
        "manifest": str(layout["manifest"]) if layout["manifest"] else None,
        "has_static": "static" in available_blocks,
        "has_acc_poses": "acc_poses" in available_blocks,
        "has_gyro_runs": "gyro_runs" in available_blocks,
        "has_gsens_runs": "gsens_runs" in available_blocks,
        "available_blocks": available_blocks,
        "missing_files": missing_files,
        "messages": messages,
        "available_tasks": available_tasks,
    }


def _derive_available_tasks(available_blocks: list[str]) -> list[str]:
    tasks: list[str] = []
    block_set = set(available_blocks)
    if "static" in block_set:
        tasks.extend(["gyro_bias", "noise_stats", "allan_analysis", "temperature_fit", "acc_calibration_from_static"])
    if "acc_poses" in block_set:
        tasks.append("acc_calibration")
    if "gyro_runs" in block_set:
        tasks.append("gyro_calibration_requires_bg")
    if "gsens_runs" in block_set:
        tasks.append("gsens_fit_requires_bg_and_Cg")
    return tasks


def _existing_file(file_path: Path | str | None) -> bool:
    return file_path is not None and Path(file_path).exists()


def _read_csv(file_path: Path) -> pd.DataFrame:
    if not file_path.exists():
        raise ImuCalibError(f"Required file not found: {file_path}")
    try:
        df = pd.read_csv(file_path)
    except Exception as exc:  # noqa: BLE001
        raise ImuCalibError(f"Failed to read CSV file {file_path}: {exc}") from exc
    return _normalize_expected_variable_names(df)


def _normalize_expected_variable_names(df: pd.DataFrame) -> pd.DataFrame:
    normalized: dict[str, str] = {}
    for name in df.columns:
        key = _normalize_column_key(name)
        mapped = _map_column_alias(key)
        normalized[name] = mapped if mapped is not None else str(name)
    return df.rename(columns=normalized)


def _normalize_column_key(name: str) -> str:
    key = str(name).strip().lower()
    key = re.sub(r"\s+", "", key)
    key = re.sub(r"[\(\)\[\]\{\}]", "", key)
    key = key.replace("-", "_")
    return key


def _map_column_alias(key: str) -> str | None:
    mapping = {
        "t": "t",
        "time": "t",
        "times": "t",
        "gx": "gx",
        "gyrox": "gx",
        "gyro_x": "gx",
        "gyroxrad/s": "gx",
        "gxrad/s": "gx",
        "gy": "gy",
        "gyroy": "gy",
        "gyro_y": "gy",
        "gyroyrad/s": "gy",
        "gyrad/s": "gy",
        "gz": "gz",
        "gyroz": "gz",
        "gyro_z": "gz",
        "gyrozrad/s": "gz",
        "gzrad/s": "gz",
        "ax": "ax",
        "accx": "ax",
        "acc_x": "ax",
        "accelx": "ax",
        "accel_x": "ax",
        "axm/s^2": "ax",
        "ay": "ay",
        "accy": "ay",
        "acc_y": "ay",
        "accely": "ay",
        "accel_y": "ay",
        "aym/s^2": "ay",
        "az": "az",
        "accz": "az",
        "acc_z": "az",
        "accelz": "az",
        "accel_z": "az",
        "azm/s^2": "az",
    }
    passthrough = {
        "temp",
        "axis",
        "dir",
        "run_id",
        "pose_name",
        "acc_x",
        "acc_y",
        "acc_z",
        "ref_x",
        "ref_y",
        "ref_z",
        "theta_ref_x",
        "theta_ref_y",
        "theta_ref_z",
        "acc_ref_x",
        "acc_ref_y",
        "acc_ref_z",
        "omega_ref_x",
        "omega_ref_y",
        "omega_ref_z",
        "idx_ss",
    }
    if key in mapping:
        return mapping[key]
    if key in passthrough:
        return key
    return None


def _require_columns(df: pd.DataFrame, required: list[str], file_path: Path) -> None:
    missing = [col for col in required if col not in df.columns]
    if missing:
        raise ImuCalibError(f"Missing required columns in {file_path}: {', '.join(missing)}")


def _assert_no_missing(df: pd.DataFrame, columns: list[str], file_path: Path) -> None:
    for col in columns:
        if df[col].isna().any():
            raise ImuCalibError(f'Column "{col}" in {file_path} contains missing values.')


def _numeric_column(df: pd.DataFrame, column: str, file_path: Path) -> np.ndarray:
    try:
        values = pd.to_numeric(df[column], errors="raise").to_numpy(dtype=float)
    except Exception as exc:  # noqa: BLE001
        raise ImuCalibError(f'Column "{column}" in {file_path} must be numeric.') from exc
    if not np.all(np.isfinite(values)):
        raise ImuCalibError(f'Column "{column}" in {file_path} must contain finite values.')
    return values


def _load_static_csv(file_path: Path) -> StaticData:
    df = _read_csv(file_path)
    required = ["t", "gx", "gy", "gz", "ax", "ay", "az"]
    _require_columns(df, required, file_path)
    _assert_no_missing(df, required, file_path)

    t = validate_time_vector(_numeric_column(df, "t", file_path), f"{file_path}:t")
    gyro = np.column_stack([_numeric_column(df, c, file_path) for c in ("gx", "gy", "gz")])
    acc = np.column_stack([_numeric_column(df, c, file_path) for c in ("ax", "ay", "az")])
    temp = None
    if "temp" in df.columns:
        _assert_no_missing(df, ["temp"], file_path)
        temp = _numeric_column(df, "temp", file_path)
    return StaticData(t=t, gyro=gyro, acc=acc, temp=temp)


def _load_acc_poses_csv(file_path: Path) -> list[AccPose]:
    df = _read_csv(file_path)
    # The global name normalizer maps some "acc_x/acc_y/acc_z" aliases to
    # static-style "ax/ay/az". For acc_poses.csv we convert them back to the
    # pose-specific names expected by the MATLAB-compatible schema.
    rename_back = {}
    if "acc_x" not in df.columns and "ax" in df.columns:
        rename_back["ax"] = "acc_x"
    if "acc_y" not in df.columns and "ay" in df.columns:
        rename_back["ay"] = "acc_y"
    if "acc_z" not in df.columns and "az" in df.columns:
        rename_back["az"] = "acc_z"
    if rename_back:
        df = df.rename(columns=rename_back)

    required = ["pose_name", "acc_x", "acc_y", "acc_z"]
    _require_columns(df, required, file_path)
    _assert_no_missing(df, required, file_path)
    has_legacy_refs = all(col in df.columns for col in ("ref_x", "ref_y", "ref_z"))
    if any(col in df.columns for col in ("ref_x", "ref_y", "ref_z")) and not has_legacy_refs:
        raise ImuCalibError(
            f"{file_path} must provide ref_x/ref_y/ref_z together if any legacy reference columns are present."
        )
    if has_legacy_refs:
        _assert_no_missing(df, ["ref_x", "ref_y", "ref_z"], file_path)
    poses: list[AccPose] = []
    for _, row in df.iterrows():
        a_ref = None
        if has_legacy_refs:
            a_ref = np.array([row["ref_x"], row["ref_y"], row["ref_z"]], dtype=float)
        poses.append(
            AccPose(
                acc_mean=np.array([row["acc_x"], row["acc_y"], row["acc_z"]], dtype=float),
                pose_name=str(row["pose_name"]),
                a_ref=a_ref,
            )
        )
    return poses


def _load_gyro_runs_csv(file_path: Path) -> list[GyroRun]:
    df = _read_csv(file_path)
    required = [
        "run_id",
        "axis",
        "dir",
        "t",
        "gx",
        "gy",
        "gz",
        "idx_ss",
        "theta_ref_x",
        "theta_ref_y",
        "theta_ref_z",
    ]
    _require_columns(df, required, file_path)
    _assert_no_missing(df, required, file_path)

    runs: list[GyroRun] = []
    for run_id, group in df.groupby("run_id", sort=False):
        axis = str(group["axis"].iloc[0]).lower()
        if axis not in {"x", "y", "z"}:
            raise ImuCalibError(f'Invalid axis value "{axis}" in {file_path}. Expected x/y/z.')
        dir_value = int(group["dir"].iloc[0])
        if dir_value not in (-1, 1):
            raise ImuCalibError(f"Invalid dir value {dir_value} in {file_path}. Expected +1 or -1.")
        theta_cols = ["theta_ref_x", "theta_ref_y", "theta_ref_z"]
        theta_ref = np.array([group[c].iloc[0] for c in theta_cols], dtype=float)
        for col in theta_cols:
            values = pd.to_numeric(group[col], errors="raise").to_numpy(dtype=float)
            if np.max(np.abs(values - values[0])) > 1e-12:
                raise ImuCalibError(f'Column "{col}" in {file_path} must stay constant within each run.')

        t = validate_time_vector(_numeric_column(group, "t", file_path), f"{file_path}:run[{run_id}].t")
        gyro = np.column_stack([_numeric_column(group, c, file_path) for c in ("gx", "gy", "gz")])
        idx_ss = _numeric_column(group, "idx_ss", file_path).astype(int)
        if not np.all(np.isin(idx_ss, [0, 1])):
            raise ImuCalibError(f'Column "idx_ss" in {file_path} must contain only 0/1 values.')
        runs.append(
            GyroRun(
                axis=axis,
                dir=dir_value,
                gyro=gyro,
                t=t,
                theta_ref=theta_ref,
                idx_ss=idx_ss.astype(bool),
            )
        )
    return runs


def _load_gsens_runs_csv(file_path: Path) -> list[GsensRun]:
    df = _read_csv(file_path)
    required = ["run_id", "t", "gx", "gy", "gz", "acc_ref_x", "acc_ref_y", "acc_ref_z"]
    _require_columns(df, required, file_path)
    _assert_no_missing(df, required, file_path)
    omega_cols = ["omega_ref_x", "omega_ref_y", "omega_ref_z"]
    has_any_omega = any(col in df.columns for col in omega_cols)
    has_all_omega = all(col in df.columns for col in omega_cols)
    if has_any_omega and not has_all_omega:
        raise ImuCalibError(f"If omega_ref columns are provided in {file_path}, all 3 columns must exist.")
    if has_all_omega:
        _assert_no_missing(df, omega_cols, file_path)

    runs: list[GsensRun] = []
    for run_id, group in df.groupby("run_id", sort=False):
        t = validate_time_vector(_numeric_column(group, "t", file_path), f"{file_path}:run[{run_id}].t")
        gyro = np.column_stack([_numeric_column(group, c, file_path) for c in ("gx", "gy", "gz")])
        acc_ref = np.column_stack([_numeric_column(group, c, file_path) for c in ("acc_ref_x", "acc_ref_y", "acc_ref_z")])
        omega_ref = None
        if has_all_omega:
            omega_ref = np.column_stack([_numeric_column(group, c, file_path) for c in omega_cols])
        runs.append(GsensRun(gyro=gyro, acc_ref=acc_ref, t=t, omega_ref=omega_ref))
    return runs
