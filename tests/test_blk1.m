%TEST_BLK1  Standalone test for blk1_txChannel (Block 1).
%   Runs WITHOUT the other blocks: make fake inputs here.
%
%   CHECK
%     - Plot |Y| for each RX and mark truth.tau.
%     - Noise off (cfg.enableNoise = false): shifts between RX columns match distance differences.
%     - checkIO('Y', Y, cfg);

clear; clc; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'src'), fullfile(root,'utils'));
cfg = config();  rng(cfg.seed);

% ---- YOUR TEST HERE ----------------------------------------------------

[Y, truth] = blk1_txChannel(cfg);
checkIO('Y', Y, cfg);
