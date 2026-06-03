function [Kg, Mg] = split_KM(Cg)
%SPLIT_KM 按当前工程定义将陀螺总矩阵 Cg 拆分为 Kg 和 Mg。
% 用法：
%   [Kg, Mg] = split_KM(Cg)
%
% 输入：
%   Cg : [3 x 3] 陀螺总矩阵
%
% 输出：
%   Kg : [3 x 3] 仅保留对角项，对应标度因数误差部分
%   Mg : [3 x 3] 仅保留非对角项，对应非正交 / 交叉耦合部分
%
% 工程定义：
%   Cg = I + Kg + Mg
%
% 说明：
% - 这里的拆分不是再次求解，只是对已估计 Cg 的参数解释。
% - Kg 只保留 diag(Cg) - 1。
% - Mg 只保留 Cg 中除单位阵和 Kg 之外的非对角部分。
% - 若 README、报告或后续代码引用 Kg / Mg，应保持同一口径。

validateattributes(Cg, {'numeric'}, {'size', [3, 3], 'finite'}, mfilename, 'Cg', 1);

% 根据当前工程约定：
%   Cg = I + Kg + Mg
% 因此对角项相对 1 的偏离归入 Kg，非对角项归入 Mg。
Kg = diag(diag(Cg) - 1);
Mg = Cg - eye(3) - Kg;
end
