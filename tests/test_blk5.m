%TEST_BLK5  Standalone test for blk5_track (Block 5).
%   Runs WITHOUT the other blocks: make fake inputs here.
%
%   CHECK
%     - Make a TX path (cfg.trajType), fake Phat = truth + noise drawn from Pcov.
%     - Plot truth vs raw Phat vs Ptrk.
%     - Tracked RMSE < raw RMSE.
%     - checkIO on outputs.

clear; clc; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'src'), fullfile(root,'utils'));
cfg = config();  rng(cfg.seed);

% ---- YOUR TEST HERE ----------------------------------------------------

state = [];
% TODO: loop over cfg.nSteps packets
% [Ptrk, PtrkCov, Ppred, state] = blk5_track(Phat, Pcov, cfg, state);
% checkIO('Ptrk', Ptrk, cfg);
