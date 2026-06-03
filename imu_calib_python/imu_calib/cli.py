from __future__ import annotations

import argparse

from imu_calib.pipelines import run_csv_pipeline, run_demo_pipeline


def main() -> None:
    parser = argparse.ArgumentParser(description="IMU calibration CLI.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    demo_parser = subparsers.add_parser("demo", help="Run the synthetic demo pipeline.")
    demo_parser.add_argument("--no-plot", action="store_true", help="Disable plotting.")
    demo_parser.add_argument("--save-dir", default=None, help="Optional directory to save outputs.")

    csv_parser = subparsers.add_parser("run-csv", help="Run the pipeline from a CSV folder, manifest bundle, or supported single CSV.")
    csv_parser.add_argument("csv_dir", help="Path to a dataset folder or to static.csv / acc_poses.csv / gyro_runs.csv / gsens_runs.csv.")
    csv_parser.add_argument("--no-plot", action="store_true", help="Disable plotting.")
    csv_parser.add_argument("--save-dir", default=None, help="Optional directory to save outputs.")

    args = parser.parse_args()
    if args.command == "demo":
        run_demo_pipeline(plot_results=not args.no_plot, save_dir=args.save_dir)
    elif args.command == "run-csv":
        run_csv_pipeline(args.csv_dir, plot_results=not args.no_plot, save_dir=args.save_dir)


if __name__ == "__main__":
    main()
