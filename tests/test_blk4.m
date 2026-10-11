%TEST_BLK4  Standalone test for blk4_localize (Block 4).
%   Runs WITHOUT the other blocks: make fake inputs here.
%
%   CHECK
%     - Fake deltad from geometry (+ Gaussian noise with covariance R).
%     - No noise: exact recovery of cfg.P0.
%     - Monte Carlo: RMSE ~ sqrt(trace(Pcov)); points inside ellipse.
%     - checkIO on both outputs.

clear; clc; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'src'), fullfile(root,'utils'));
cfg = config();  rng(cfg.seed);

% ---- YOUR TEST HERE ----------------------------------------------------

deltad = []; R = [];  % TODO: fake inputs
[Phat, Pcov] = blk4_localize(deltad, R, cfg, []);
checkIO('Phat', Phat, cfg);  checkIO('Pcov', Pcov, cfg);
