%TEST_BLK2  Standalone test for blk2_rx (Block 2).
%   Runs WITHOUT the other blocks: make fake inputs here.
%
%   CHECK
%     - Build your own Y (wlanWaveformGenerator + known delays + noise) OR use Block 1.
%     - Pure delay, no noise: phase of Hhat vs subcarrier is a straight line; steeper = later RX.
%     - noiseVar close to the noise you added.
%     - checkIO on both outputs.

clear; clc; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'src'), fullfile(root,'utils'));
cfg = config();  rng(cfg.seed);

% ---- YOUR TEST HERE ----------------------------------------------------

Y = [];  % TODO: fake input
[Hhat, noiseVar] = blk2_rx(Y, cfg);
checkIO('Hhat', Hhat, cfg);  checkIO('noiseVar', noiseVar, cfg);
