%TEST_BLK3  Standalone test for blk3_tdoa (Block 3).
%   Runs WITHOUT the other blocks: make fake inputs here.
%
%   CHECK
%     - Fake Hhat = pure delay per RX (linear phase) + noise.
%     - No noise: delay error << 1 sample, with vs without interpolation.
%     - Monte Carlo: cov(deltad) ~ R.
%     - Add a bounce: first-path detection still picks the direct path.
%     - checkIO on both outputs.

clear; clc; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'src'), fullfile(root,'utils'));
cfg = config();  rng(cfg.seed);

% ---- YOUR TEST HERE ----------------------------------------------------

Hhat = []; noiseVar = [];  % TODO: fake inputs
[deltad, R, info3] = blk3_tdoa(Hhat, noiseVar, cfg);
checkIO('deltad', deltad, cfg);  checkIO('R', R, cfg);
