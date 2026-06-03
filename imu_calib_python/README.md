# IMU 标定与补偿工程（Python）

Python 工程是当前仓库的主线实现。目标不是堆入口，而是把常用路径收敛到少量稳定接口，并保持与 MATLAB 工程在功能、参数语义、结果解释上的一致性。

## 核心能力

- 基础标定：陀螺零偏、静态噪声、加速度计多姿态标定、陀螺 `Cg` 标定、`Gg` 拟合
- 温度标定：`bg(T)` 与 `ba(T)`，其中 `ba(T)` 依赖固定 `Ca`
- 运行期补偿：`apply_imu_calibration(...)`
- 结果验证：静态段、姿态误差、角增量残差、`Gg` 残差、Allan 分析摘要
- 部分数据集运行：允许只提供 `static.csv`、`acc_poses.csv`、`gyro_runs.csv` 或 `gsens_runs.csv`

## 主入口

推荐只记住两个入口：

- 演示：`python -m imu_calib demo`
- 实际数据：`python -m imu_calib run-csv <数据目录或单个 CSV>`

也可以使用安装后的命令行入口：

```bash
imu-calib demo
imu-calib run-csv data/example_dataset_bundle
```

`examples/` 下脚本仍保留，但现在只作为薄封装示例，不再视为主路径。

## 最小使用流程

1. 安装依赖

```bash
pip install -r requirements.txt
```

2. 运行示例数据

```bash
python -m imu_calib run-csv data/example_dataset_bundle
```

3. 只用静态数据跑可用模块

```bash
python -m imu_calib run-csv data/example_dataset_bundle/static.csv
```

4. 运行测试

```bash
pytest -q tests
```

## 结果输出

`save_calibration_results(...)` 统一输出三类文件：

- `calibration_results.pkl`：完整对象，便于 Python 内部复用
- `calibration_summary.json`：核心摘要，便于人工查看和与 MATLAB 对照
- `calibration_arrays.npz`：关键矩阵和向量，便于数值分析

摘要中按以下层级组织：

- `model`
- `core_outputs`
- `summary`
- `temperature_model`
- `meta`

## 目录说明

- `imu_calib/cli.py`：命令行主入口
- `imu_calib/pipelines.py`：演示与 CSV 流程入口
- `imu_calib/tasks/`：任务编排层
- `imu_calib/calib/`：核心标定算法
- `imu_calib/io/`：输入数据加载与导出
- `imu_calib/runtime/`：结果组装、保存、运行期补偿
- `imu_calib/validate/`：验证与绘图
- `docs/`：算法、输入、使用与开发说明

## 文档导航

- 算法与参数：`docs/02_IMU误差模型与参数定义.md`
- 加速度计标定：`docs/03_加速度计静止多姿态标定方案.md`
- 运行与补偿：`docs/04_补偿算法与运行流程.md`
- 输入要求：`docs/05_输入文件与数据采集要求.md`
- 使用说明：`docs/06_使用方法.md`
- 开发补充：`docs/08_开发者补充说明.md`

## 与 MATLAB 的关系

- 代码写法不强求一致
- 入口职责、参数含义、结果摘要结构尽量一致
- 主线字段优先使用 `snake_case`
- 为兼容历史代码，结果结构中仍保留少量 `camelCase` 别名

## Legacy 说明

- `README_CN.md`、`QUICKSTART_CN.md`、`DEV_NOTES_CN.md` 保留为跳转页
- `examples/` 是示例，不是主入口
- 仓库中的示例输出目录仅用于参考样例，不作为主流程依赖
