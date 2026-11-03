function result = runCapstoneExperiment(cfg)
%RUNCAPSTONEEXPERIMENT Execute the real supplied Blocks 1-4 and Block 5 adapter.
% Every output is passed downstream; no ideal/TDoA shortcuts are inserted.
% block 5 raw-fusion inputs travel via state.pendingTDOA, preserving signature.
if ~all(isfield(cfg,{'Npackets','experimentMode','dt','P0','Rx','seed'}))
    error('runCapstoneExperiment:Config','Missing experiment configuration.');
end
rng(cfg.seed,'twister');
K=cfg.Npackets;
validateattributes(K,{'numeric'},{'scalar','integer','positive'});
result=struct();
result.time=(0:K-1)*cfg.dt;
result.truePosition=zeros(2,K);
result.rawPosition=nan(2,K);
result.trackPosition=nan(2,K);
result.crlbTrace=nan(1,K);
result.rawError=nan(1,K);
result.trackError=nan(1,K);
result.deltad=nan(size(cfg.Rx,1)-1,K);
result.R=nan(size(cfg.Rx,1)-1,size(cfg.Rx,1)-1,K);
result.cumulativePosition=nan(2,K);
result.windowPosition=nan(2,K);
result.cumulativeReady=false(1,K);
result.windowReady=false(1,K);
result.info4=cell(1,K);
result.fusion=cell(1,K);
result.truth=cell(1,K);
state=[]; Ppred=[];
for k=1:K
    frameCfg=cfg;
    t=result.time(k);
    if strcmpi(cfg.experimentMode,'moving')
        frameCfg.P0=cfg.P0 + cfg.velocity*t + ...
            cfg.motionAmplitude.*sin(2*pi*cfg.motionFrequency*t);
    elseif ~strcmpi(cfg.experimentMode,'stationary')
        error('runCapstoneExperiment:Mode','Use stationary or moving.');
    end
    % Block 1: physical waveform and channel.
    [Y,truth]=blk1_txChannel(frameCfg);
    checkIO(1,frameCfg,Y,truth);
    % Block 2: shared receiver synchronization and L-LTF estimation.
    [Hhat,noiseVar]=blk2_rx(Y,frameCfg);
    checkIO(2,frameCfg,Hhat,noiseVar);
    % Block 3: CIR timing, range differences, correlated covariance.
    [deltad,R,info3]=blk3_tdoa(Hhat,noiseVar,frameCfg);
    checkIO(3,frameCfg,deltad,R,info3);
    % Block 4: weighted nonlinear TDoA localization and local CRLB.
    [Phat,Pcov,info4]=blk4_localize(deltad,R,frameCfg,Ppred);
    checkIO(4,frameCfg,Phat,Pcov,info4);
    if ~info4.converged
        warning('runCapstoneExperiment:NonConvergence', ...
            'Packet %d: Block 4 reported non-convergence; result flagged.',k);
    end
    if isfield(info4,'crlbValid') && ~info4.crlbValid
        error('runCapstoneExperiment:SingularGeometry', ...
            'Packet %d: Block 4 Fisher information is near singular; CRLB invalid.',k);
    end
    % Block 5: Kalman tracking plus original finite/decaying-window fusion,
    % and the reconstructed cumulative fusion for static experiments.
    if isempty(state), state=struct(); end
    state.pendingTDOA=struct('z',deltad,'R',R,'packetId',double(k));
    [Ptrk,PtrkCov,Ppred,state]=blk5_track(Phat,Pcov,frameCfg,state);
    checkIO(5,frameCfg,Ptrk,PtrkCov,Ppred,state);
    result.truePosition(:,k)=truth.P0;
    result.rawPosition(:,k)=Phat;
    result.trackPosition(:,k)=Ptrk;
    result.crlbTrace(k)=trace(Pcov);
    result.rawError(k)=norm(Phat-truth.P0);
    result.trackError(k)=norm(Ptrk-truth.P0);
    result.deltad(:,k)=deltad;
    result.R(:,:,k)=R;
    result.info4{k}=info4;
    result.truth{k}=truth;
    result.fusion{k}=state.lastFusion;
    if ~isempty(state.lastFusion.cumulative) && state.lastFusion.cumulative.hasEstimate
        result.cumulativePosition(:,k)=state.lastFusion.cumulative.position;
        result.cumulativeReady(k)=state.lastFusion.cumulative.ready;
    end
    if ~isempty(state.lastFusion.window) && state.lastFusion.window.hasEstimate
        result.windowPosition(:,k)=state.lastFusion.window.position;
        result.windowReady(k)=state.lastFusion.window.ready;
    end
    if k==1
        result.first=struct('Y',Y,'Hhat',Hhat,'noiseVar',noiseVar, ...
            'info3',info3,'Phat',Phat,'Pcov',Pcov,'truth',truth, ...
            'deltad',deltad,'R',R);
    end
    result.last=struct('Y',Y,'Hhat',Hhat,'noiseVar',noiseVar, ...
        'info3',info3,'Phat',Phat,'Pcov',Pcov, ...
        'Ptrk',Ptrk,'PtrkCov',PtrkCov,'Ppred',Ppred, ...
        'truth',truth,'deltad',deltad,'R',R,'info4',info4);
    if isfield(cfg,'printProgress') && cfg.printProgress
        fprintf('Frame %3d/%d | TDoA [m] %s | raw [%.2f %.2f] | track [%.2f %.2f] | err %.3f m\n', ...
            k,K,mat2str(deltad.',3),Phat(1),Phat(2),Ptrk(1),Ptrk(2),result.trackError(k));
    end
end
result.state=state;
result.rawRMSE=sqrt(mean(result.rawError.^2));
result.trackRMSE=sqrt(mean(result.trackError.^2));
end
