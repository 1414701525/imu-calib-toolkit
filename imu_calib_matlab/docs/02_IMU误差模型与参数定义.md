# IMU 误差模型与参数定义

本文只描述当前 `imu_calib_matlab/` 中已经实际落地的模型。

## 1. 加速度计

运行期补偿模型：

$$
a_{corr} = C_a (a_{raw} - b_a(T))
$$

其中：

- $a_{raw}$：原始加速度测量
- $a_{corr}$：补偿后加速度
- $b_a(T)$：加速度零偏，允许随温度变化
- $C_a$：固定补偿矩阵

当前阶段只拟合：

- 固定矩阵 `Ca`
- 温度相关 bias `ba(T)`

当前阶段不拟合：

- `Ca(T)`
- `Sa(T)`
- `Ma(T)`

### `Ca = Sa * Ma`

MATLAB 当前与 Python 主线保持一致，默认参数化为：

$$
C_a = S_a M_a
$$

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

输出对外统一暴露为总矩阵 `Ca`，同时在结果结构里保留 `Sa` 与 `Ma`。

## 2. 加速度计静止标定约束

对每个静止姿态均值 $a_{raw,i}$，当前使用：

$$
\|C_a(a_{raw,i} - b_a)\| = g
$$

对应目标函数：

$$
\min_{\theta}\sum_i \left(\|C_a(a_{raw,i}-b_a)\| - g\right)^2
$$

其中：

- $\theta = \{b_a, C_a\}$ 的参数化形式
- $g$ 默认来自 `options.acc_calibration.gravity_magnitude`

## 3. 陀螺仪

正向模型：

$$
\omega_m = C_g \omega_{ref} + b_g(T) + G_g f_{term} + n_g
$$

运行期逆补偿：

$$
\hat{\omega}_{ref} = \mathrm{solve}\left(C_g,\ \omega_m - b_g(T) - G_g f_{term}\right)
$$

在 MATLAB 中对应为：

```matlab
gyroCalibrated = (Cg \ gyroModelRemoved.').';
```

## 4. `Cg = I + Kg + Mg`

保持与 Python 一致：

$$
K_g = \mathrm{diag}(\mathrm{diag}(C_g) - 1)
$$

$$
M_g = C_g - I - K_g
$$

## 5. 温度模型

当前同时支持：

- `bg(T)`：陀螺零偏温漂
- `ba(T)`：加速度零偏温漂

支持模型类型：

- `poly1`
- `poly2`
- `poly3`
- `piecewise_linear`

默认：

- `poly2`

多项式模型统一使用中心化温度变量：

$$
\Delta T = T - T_{ref}
$$

温区外策略：

- `clamp`
- `extrapolate`
- `warn_and_clamp`

默认：

- `warn_and_clamp`
