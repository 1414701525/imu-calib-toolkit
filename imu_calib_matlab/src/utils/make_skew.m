function S = make_skew(v)
%MAKE_SKEW 由 3x1 向量构造反对称矩阵。
% 用法：
%   S = make_skew(v)
%
% 输入：
%   v : [3 x 1] 向量
%
% 输出：
%   S : [3 x 3] 反对称矩阵

validateattributes(v, {'numeric'}, {'vector', 'numel', 3, 'finite'}, mfilename, 'v', 1);
v = v(:);

S = [  0,   -v(3),  v(2); ...
      v(3),   0,   -v(1); ...
     -v(2), v(1),    0  ];
end
