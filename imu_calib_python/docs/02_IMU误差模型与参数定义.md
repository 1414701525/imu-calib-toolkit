# 02 IMU 误差模型与参数定义

## 1. 文档范围

本文只描述当前 `imu_calib_python/` 中真实使用到的误差模型和参数，不引入尚未落地的扩展模型。

## 2. 加速度计模型

### 2.1 运行期补偿模型

当前工程运行期统一使用：

$$
a_{corr} = C_a (a_{raw} - b_a(T))
$$

其中：

- $a_{raw} \in \mathbb{R}^3$：原始加速度测量
- $a_{corr} \in \mathbb{R}^3$：补偿后加速度
- $b_a(T) \in \mathbb{R}^3$：加速度零偏，允许随温度变化
- $C_a \in \mathbb{R}^{3 \times 3}$：固定补偿矩阵

### 2.2 当前阶段的建模边界

本阶段只拟合：

- 固定矩阵 `Ca`
- 温度相关 bias `ba(T)`

本阶段不拟合：

- `Ca(T)`
- `Ka(T)`
- `Ma(T)`

### 2.3 `Ca` 的参数化

当前加速度计标定默认采用：

$$
C_a = S_a M_a
$$

其中：

$$
S_a = \mathrm{diag}(s_x, s_y, s_z)
$$

$$
M_a =
\begin{bmatrix}
1 & m_{xy} & m_{xz} \\
0 & 1 & m_{yz} \\
0 & 0 & 1
\end{bmatrix}
$$

说明：

- `Sa` 表示比例因子
- `Ma` 表示非正交 / 交叉耦合
- 标定输出对外统一暴露为总矩阵 `Ca`

## 3. 加速度计静止标定约束

对每个静止姿态均值样本 $a_{raw,i}$，当前工程采用重力模长约束：

$$
\|C_a (a_{raw,i} - b_a)\| = g
$$

对应目标函数为：

$$
\min_{\theta} \sum_i \left(\|C_a(a_{raw,i} - b_a)\| - g\right)^2
$$

其中：

- $\theta = \{b_a, C_a\}$ 或其参数化形式
- $g$ 为重力模长，默认来自 `options["acc_calibration"]["gravity_magnitude"]`

## 4. 陀螺仪模型

### 4.1 正向测量模型

当前工程文档与代码统一的正向模型为：

$$
\omega_m = C_g \omega_{ref} + b_g(T) + G_g f_{term} + n_g
$$

其中：

- $\omega_m$：陀螺原始测量
- $\omega_{ref}$：参考角速度
- $C_g$：陀螺总矩阵
- $b_g(T)$：陀螺零偏，允许随温度变化
- $G_g$：g-敏感度矩阵
- $f_{term}$：当前运行期使用的比力输入项

### 4.2 运行期逆补偿

当前代码实际执行的是：

$$
\hat{\omega}_{ref} = \mathrm{solve}\left(C_g,\ \omega_m - b_g(T) - G_g f_{term}\right)
$$

说明：

- 工程中使用 `np.linalg.solve(Cg, ...)`
- 不使用右乘近似

## 5. `Cg = I + Kg + Mg`

当前拆分规则固定为：

$$
K_g = \mathrm{diag}(\mathrm{diag}(C_g) - 1)
$$

$$
M_g = C_g - I - K_g
$$

其中：

- `Kg` 只保留对角标度因子误差
- `Mg` 只保留非对角交叉耦合 / 非正交项

## 6. 温度模型

### 6.1 陀螺零偏温漂

当前实现支持：

$$
b_g(T) = [b_{gx}(T), b_{gy}(T), b_{gz}(T)]^T
$$

### 6.2 加速度零偏温漂

当前实现新增支持：

$$
b_a(T) = [b_{ax}(T), b_{ay}(T), b_{az}(T)]^T
$$

### 6.3 支持的模型类型

两类温度模型统一支持：

- `poly1`
- `poly2`
- `poly3`
- `piecewise_linear`

默认模型：

- `poly2`

### 6.4 温度中心化变量

多项式模型统一采用中心化温度变量：

$$
\Delta T = T - T_{ref}
$$

例如 `poly2`：

$$
b_x(T) = c_0 + c_1 \Delta T + c_2 \Delta T^2
$$

当前 `T_ref` 由 `options["temperature"]["reference_temperature_mode"]` 决定，默认取温度均值。

### 6.5 温区外策略

当前运行期支持：

- `clamp`
- `extrapolate`
- `warn_and_clamp`

默认：

- `warn_and_clamp`

## 7. Allan 与静态噪声

当前工程同时输出两类噪声信息：

- 静态 `std / var`
- Allan deviation

Allan 模块输出中常见字段：

- `tau`
- `adev`
- `estimate.noise_density`
- `estimate.bias_instability`
- `estimate.random_walk`
- `estimate.confidence`

## 8. 参数、单位与求解顺序

| 参数 | 维度 | 单位 | 作用 | 主要来源 |
| --- | --- | --- | --- | --- |
| `bg` | 3 | rad/s | 常温固定陀螺 bias | `estimate_gyro_bias.py` |
| `bg_model` | 模型对象 | rad/s | 陀螺温度 bias | `fit_temperature_bias_model.py` |
| `ba` | 3 | m/s² | 常温固定加速度 bias | `fit_acc_multi_pose.py` |
| `ba_model` | 模型对象 | m/s² | 加速度温度 bias | `fit_temperature_bias_model.py` |
| `Ca` | 3x3 | 无量纲 | 固定加速度补偿矩阵 | `fit_acc_multi_pose.py` |
| `Sa` | 3x3 | 无量纲 | 加速度 scale 分量 | `fit_acc_multi_pose.py` |
| `Ma` | 3x3 | 无量纲 | 加速度非正交分量 | `fit_acc_multi_pose.py` |
| `Cg` | 3x3 | 无量纲 | 陀螺总矩阵 | `fit_gyro_C_from_angle_increment.py` |
| `Kg` | 3x3 | 无量纲 | `Cg` 对角解释项 | `split_km.py` |
| `Mg` | 3x3 | 无量纲 | `Cg` 非对角解释项 | `split_km.py` |
| `Gg` | 3x3 | 依比力单位而定 | g-敏感度矩阵 | `fit_gyro_g_sensitivity.py` |

## 9. 待确认项

- `Gg` 拟合阶段当前使用 `gsens_runs.acc_ref`，运行期 `f_term` 使用补偿后的 `a_corr`。这种定义在真实系统中的完全物理一致性仍需结合采集链路确认。
- MATLAB 版本当前尚未同步到新的 `ba(T)` 实现，温度模块以 Python 主线为准。
