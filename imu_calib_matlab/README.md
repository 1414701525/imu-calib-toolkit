# IMU 标定与补偿工程（MATLAB）

MATLAB 工程与 Python 主线保持功能和结果语义对齐，重点用于 MATLAB 环境运行、算法核对和结果对照。

## 主入口

- 演示：`main_demo`
- 实际数据：`results = run_from_csv('data\example_dataset_bundle');`

如果只想验证静态段、温度模型或部分模块，也可以直接传单个 CSV：

```matlab
results = run_from_csv('data\example_dataset_bundle\static.csv');
```

## 核心能力

- 陀螺零偏与静态噪声统计
- 加速度计静止多姿态标定
- 陀螺 `Cg` 标定与 `Kg / Mg` 拆分
- `Gg` 拟合
- Allan 分析
- 温度模型 `bg(T)` 与 `ba(T)`
- 运行期补偿 `apply_imu_calibration(...)`

## 最小使用流程

1. 进入工程目录并加入 `src/`

```matlab
projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(projectRoot, 'src')));
```

2. 运行演示

```matlab
main_demo
```

3. 运行 CSV / manifest 数据集

```matlab
results = run_from_csv('data\example_dataset_bundle');
```

## 输出结构

`save_calibration_results(...)` 统一输出：

- `calibration_results.mat`
- `calibration_summary.json`
- `calibration_arrays.mat`

摘要与 Python 对齐，按以下层级组织：

- `model`
- `core_outputs`
- `summary`
- `temperature_model`
- `meta`

## 目录说明

- `main_demo.m`、`run_from_csv.m`：入口层
- `src/tasks/`：任务编排层
- `src/calib/`、`src/analysis/`：核心算法层
- `src/io/`：输入与导出
- `src/runtime/`：运行期补偿、结果组装、保存
- `src/validate/`：验证与绘图
- `docs/`：算法、输入、使用与映射说明

## 文档导航

- Python 对照关系：`docs/00_Python到MATLAB映射表.md`
- 算法与参数：`docs/02_IMU误差模型与参数定义.md`
- 加速度计标定：`docs/03_加速度计静止多姿态标定方案.md`
- 运行与补偿：`docs/04_补偿算法与运行流程.md`
- 输入要求：`docs/05_输入文件与数据采集要求.md`
- 使用说明：`docs/06_使用方法.md`
- 温度标定：`docs/温度标定.md`

## 与 Python 的一致性约定

- 主线术语尽量一致
- 结果主字段优先对齐 `snake_case`
- 为兼容现有脚本，MATLAB 结果中继续保留部分 `camelCase` 字段

## Legacy 说明

- `README_CN.md`、`QUICKSTART_CN.md`、`DEV_NOTES_CN.md` 保留为跳转页
- 旧说明以当前 `README.md` 和 `docs/` 为准
