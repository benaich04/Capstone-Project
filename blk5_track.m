function [Ptrk, PtrkCov, Ppred, state] = blk5_track(Phat, Pcov, cfg, state)
%BLK5_TRACK Block 5 compatibility wrapper for tracking and TDoA fusion.
% NEW integration adapter; original blk5_track.m was not supplied.
% Existing signature is unchanged: (Phat,Pcov,cfg,state).
% The optional state.pendingTDOA carries the CURRENT raw measurement:
%   state.pendingTDOA = struct('z',deltad,'R',R,'packetId',k);
% This preserves raw-measurement fusion without changing the block contract.
% Results for cumulative and finite-window fusion are in state.lastFusion.
if nargin<4 || isempty(state), state=struct(); end
validateattributes(Phat,{'double'},{'real','finite','size',[2 1]});
validateattributes(Pcov,{'double'},{'real','finite','size',[2 2]});
if norm(Pcov-Pcov','fro')>1e-7*max(norm(Pcov,'fro'),eps)
    error('blk5:Covariance','Pcov is not symmetric.');
end
if min(eig((Pcov+Pcov')/2))<0
    error('blk5:Covariance','Pcov must be positive semidefinite.');
end
validateattributes(cfg.dt,{'double'},{'scalar','finite','positive'});
if ~isfield(cfg,'trackAccelStd'), cfg.trackAccelStd=0.5; end
if ~isfield(cfg,'trackInitialVelocityStd'), cfg.trackInitialVelocityStd=1.5; end
if ~isfield(cfg,'trackMeasurementInflation'), cfg.trackMeasurementInflation=1; end
if cfg.trackMeasurementInflation<1
    error('blk5:MeasurementInflation','Covariance inflation must be >= 1.');
end
if ~isfield(cfg,'fusionOutput'), cfg.fusionOutput='kalman'; end
if ~isfield(cfg,'experimentMode'), cfg.experimentMode='stationary'; end
h=cfg.dt;
F=[1 0 h 0;0 1 0 h;0 0 1 0;0 0 0 1];
H=[eye(2) zeros(2)];
G=[0.5*h^2 0;0 0.5*h^2;h 0;0 h];
Q=cfg.trackAccelStd^2*(G*G');
V=cfg.trackMeasurementInflation*Pcov;
% Numerical floor is strictly for the Kalman inversion; original Pcov is preserved.
V=V+1e-12*eye(2);
if ~isfield(state,'kf') || isempty(state.kf)
    state.kf.x=[Phat;0;0];
    state.kf.P=blkdiag(V,cfg.trackInitialVelocityStd^2*eye(2));
    state.kf.n=1;
else
    xprior=F*state.kf.x;
    Pprior=F*state.kf.P*F'+Q;
    S=H*Pprior*H'+V;
    K=(Pprior*H')/S;
    xpost=xprior+K*(Phat-H*xprior);
    T=eye(4)-K*H;
    Ppost=T*Pprior*T'+K*V*K'; % Joseph stabilized update
    state.kf.x=xpost;
    state.kf.P=(Ppost+Ppost')/2;
    state.kf.n=state.kf.n+1;
end
Ptrk=state.kf.x(1:2);
PtrkCov=state.kf.P(1:2,1:2);
Ppred=(F*state.kf.x);
Ppred=Ppred(1:2);
state.lastFusion=struct('cumulative',[],'window',[]);
if isfield(state,'pendingTDOA') && ~isempty(state.pendingTDOA)
    packet=state.pendingTDOA;
    if ~all(isfield(packet,{'z','R','packetId'}))
        error('blk5:Payload','pendingTDOA requires z, R, and packetId.');
    end
    if ~isfield(cfg,'fusion'), error('blk5:FusionOptions','cfg.fusion is missing.'); end
    o=tdoaOptions();
    o.minimumPackets=cfg.fusion.minimumPackets;
    o.gateProbability=cfg.fusion.gateProbability;
    o.gateAfter=cfg.fusion.gateAfter;
    o.enableInnovationGate=cfg.fusion.enableInnovationGate;
    o.maxConsecutiveRejected=cfg.fusion.maxConsecutiveRejected;
    o.covarianceScale=cfg.fusion.covarianceScale;
    w=tdoaWindowOptions();
    w.length=cfg.fusion.windowLength;
    w.decay=cfg.fusion.windowDecay;
    % Static-window measurement fusion is valid only when the transmitter
    % remains fixed within the window. Do not use for moving tracks.
    if strcmpi(cfg.experimentMode,'stationary')
        if ~isfield(state,'staticState'), state.staticState=[]; end
        if ~isfield(state,'windowState'), state.windowState=[]; end
        [cOut,state.staticState]=tdoaStaticStep(packet.z,packet.R,cfg.Rx, ...
            cfg.refIdx,double(packet.packetId),state.staticState,o);
        [wOut,state.windowState]=tdoaWindowStep(packet.z,packet.R,cfg.Rx, ...
            cfg.refIdx,double(packet.packetId),state.windowState,o,w);
        state.lastFusion=struct('cumulative',cOut,'window',wOut);
        switch lower(cfg.fusionOutput)
            case 'kalman'
                % KF result already calculated.
            case 'window'
                if wOut.ready
                    Ptrk=wOut.position; PtrkCov=wOut.covariance;
                end
            case 'cumulative'
                if cOut.ready
                    Ptrk=cOut.position; PtrkCov=cOut.covariance;
                end
            otherwise
                error('blk5:FusionMode','Unknown fusionOutput: %s.',cfg.fusionOutput);
        end
    elseif ~strcmpi(cfg.experimentMode,'moving')
        error('blk5:ExperimentMode','experimentMode must be stationary or moving.');
    end
    state=rmfield(state,'pendingTDOA');
end
state.lastTrack=struct('kalmanPosition',state.kf.x(1:2), ...
    'kalmanCovariance',state.kf.P(1:2,1:2), ...
    'velocity',state.kf.x(3:4),'predictedPosition',Ppred);
end
