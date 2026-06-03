from __future__ import annotations

from pathlib import Path

from imu_calib.io.load_csv_data import load_csv_data
from imu_calib.io.load_example_data import load_example_data
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.runtime.print_calibration_summary import print_calibration_summary
from imu_calib.runtime.save_calibration_results import save_calibration_results
from imu_calib.tasks.run_full_calibration import run_full_calibration
from imu_calib.validate.plot_validation_results import plot_validation_results


def run_demo_pipeline(*, plot_results: bool = True, save_dir: str | Path | None = None):
    """Run the synthetic demonstration pipeline and return unified results.

    The public API stays stable, but the implementation now follows the
    MATLAB-style task layer so partial/full behavior stays aligned.
    """
    options = default_calib_options()
    options["pipeline"]["plot_results"] = bool(plot_results)
    data, truth, meta = load_example_data()
    task = run_full_calibration(data, options=options)
    results = task["result"]["results"]
    results.truth = truth
    results.meta = {**meta, **results.meta}

    print("\nPython IMU calibration demo completed.")
    print_calibration_summary(results)
    if truth:
        print("\nReference truth comparison:")
        print(f"max|bg - bg_true| = {abs(results.calib['bg'] - truth['bg_true']).max():.6g}")
        print(f"max|Ca - Ca_true| = {abs(results.calib['acc']['Ca'] - truth['Ca_true']).max():.6g}")
        print(f"max|ba - ba_true| = {abs(results.calib['acc']['ba'] - truth['ba_true']).max():.6g}")
        print(f"max|Cg - Cg_true| = {abs(results.calib['gyr']['Cg'] - truth['Cg_true']).max():.6g}")
    _finalize_outputs(results, plot_results=plot_results, save_dir=save_dir)
    return results


def run_csv_pipeline(csv_dir: str | Path, *, plot_results: bool = True, save_dir: str | Path | None = None):
    """Run the CSV/manifest-based pipeline and return unified results."""
    options = default_calib_options()
    options["pipeline"]["plot_results"] = bool(plot_results)
    data = load_csv_data(csv_dir)
    task = run_full_calibration(data, options=options)
    results = task["result"]["results"]
    if task["warnings"]:
        print("Warnings:")
        for item in task["warnings"]:
            print(f"  - {item}")
    print_calibration_summary(results)
    _finalize_outputs(results, plot_results=plot_results, save_dir=save_dir)
    return results


def _finalize_outputs(results, *, plot_results: bool, save_dir: str | Path | None) -> None:
    if save_dir is not None:
        written = save_calibration_results(results, save_dir)
        print("\nSaved outputs:")
        for key, value in written.items():
            print(f"  {key}: {value}")

    if plot_results:
        plot_validation_results(results.data, results.compat["flat_calib"], results.validation)
        import matplotlib.pyplot as plt

        backend = plt.get_backend().lower()
        if backend != "agg":
            plt.show()
