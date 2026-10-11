%MAIN  Full Wi-Fi TDoA localization chain (integration script).
%   Runs Block 1 -> 2 -> 3 -> 4 -> 5 in a row.
%   Owner: integrator. Block owners: don't edit, test with tests/test_blkN.m.
%
%   Works only once every block is implemented (stubs throw "notImplemented").

clear; clc; close all;
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root,'src'), fullfile(root,'utils'));

cfg = config();
rng(cfg.seed);

%% ---- Single packet: full chain -----------------------------------------
% TODO (integrator): uncomment block by block as they get delivered.

% [Y, truth]         = blk1_txChannel(cfg);              checkIO('Y', Y, cfg);
% [Hhat, noiseVar]   = blk2_rx(Y, cfg);                  checkIO('Hhat', Hhat, cfg); checkIO('noiseVar', noiseVar, cfg);
% [deltad, R, info3] = blk3_tdoa(Hhat, noiseVar, cfg);   checkIO('deltad', deltad, cfg); checkIO('R', R, cfg);
% [Phat, Pcov]       = blk4_localize(deltad, R, cfg, []); checkIO('Phat', Phat, cfg); checkIO('Pcov', Pcov, cfg);
%
% err = norm(Phat - cfg.P0);                % evaluation only
% fprintf('Position error: %.2f cm\n', 100*err);
% plotScene(cfg, Phat, Pcov);

%% ---- Tracking: many packets ---------------------------------------------
% TODO (integrator): moving TX over cfg.nSteps packets.
%
% state = [];  Ppred = [];
% for t = 1:cfg.nSteps
%     cfg.P0 = trajectory(:, t);                       % move the TX
%     [Y, truth]       = blk1_txChannel(cfg);
%     [Hhat, noiseVar] = blk2_rx(Y, cfg);
%     [deltad, R]      = blk3_tdoa(Hhat, noiseVar, cfg);
%     [Phat, Pcov]     = blk4_localize(deltad, R, cfg, Ppred);
%     [Ptrk, PtrkCov, Ppred, state] = blk5_track(Phat, Pcov, cfg, state);
% end

%% ---- Monte Carlo / sweeps -----------------------------------------------
% TODO (integrator): RMSE vs CRLB over cfg.sweep.B, cfg.sweep.Pt_dBm,
%                    cfg.sweep.interp, RX layouts, bounce on/off.
