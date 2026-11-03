function [packet, state, Ppred] = capstoneGuiPacket(cfg, state, Ppred, packetId)
%CAPSTONEGUIPACKET Process one simulated Wi-Fi packet through Blocks 1-5.
% Full original algorithms: no synthetic TDoA or simplified localization.
% The caller controls TX motion by assigning cfg.P0 for this packet.
% `state` and `Ppred` must persist across calls for tracking/fusion.
if nargin < 2 || isempty(state), state = struct(); end
if nargin < 3, Ppred = []; end
if nargin < 4, packetId = 1; end
validateattributes(packetId, {'numeric'}, {'scalar','integer','positive','finite'});

[Y, truth] = blk1_txChannel(cfg);
checkIO(1, cfg, Y, truth);
[Hhat, noiseVar] = blk2_rx(Y, cfg);
checkIO(2, cfg, Hhat, noiseVar);
[deltad, R, info3] = blk3_tdoa(Hhat, noiseVar, cfg);
checkIO(3, cfg, deltad, R, info3);
[Phat, Pcov, info4] = blk4_localize(deltad, R, cfg, Ppred);
checkIO(4, cfg, Phat, Pcov, info4);
if isfield(info4, 'crlbValid') && ~info4.crlbValid
    error('capstoneGUI:InvalidCRLB', ...
        'Block 4 reported a singular Fisher information matrix.');
end
state.pendingTDOA = struct('z', deltad, 'R', R, 'packetId', double(packetId));
[Ptrk, PtrkCov, Ppred, state] = blk5_track(Phat, Pcov, cfg, state);
checkIO(5, cfg, Ptrk, PtrkCov, Ppred, state);

packet = struct('Y',Y, 'truth',truth, 'Hhat',Hhat, ...
    'noiseVar',noiseVar, 'deltad',deltad, 'R',R, 'info3',info3, ...
    'Phat',Phat, 'Pcov',Pcov, 'info4',info4, ...
    'Ptrk',Ptrk, 'PtrkCov',PtrkCov, 'Ppred',Ppred, ...
    'fusion',state.lastFusion, ...
    'rawError',norm(Phat - truth.P0), ...
    'trackError',norm(Ptrk - truth.P0));
end
