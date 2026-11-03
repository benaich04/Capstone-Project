function integration_test_blk5()
% Newly authored Block 5 Kalman plus cumulative/window fusion test.
cfg=config(); rng(cfg.seed);
cfg.experimentMode='stationary';
cfg.fusion.minimumPackets=5;
cfg.fusion.windowLength=10;
cfg.fusionOutput='kalman';
d=vecnorm(cfg.Rx-cfg.P0.',2,2);
zt=d(cfg.others)-d(cfg.refIdx);
R=0.06^2*(eye(cfg.nRx-1)+ones(cfg.nRx-1));
state=[]; errorsRaw=zeros(1,20); errorsTrk=zeros(1,20);
for k=1:20
    p=cfg.P0+0.4*randn(2,1); Pcov=0.16*eye(2);
    if isempty(state),state=struct();end
    state.pendingTDOA=struct('z',zt+chol(R,'lower')*randn(3,1), ...
        'R',R,'packetId',double(k));
    [q,C,pred,state]=blk5_track(p,Pcov,cfg,state);
    checkIO(5,cfg,q,C,pred,state);
    errorsRaw(k)=norm(p-cfg.P0);
    errorsTrk(k)=norm(q-cfg.P0);
end
assert(state.kf.n==20);
assert(~isempty(state.lastFusion.window));
assert(~isempty(state.lastFusion.cumulative));
assert(state.lastFusion.window.nAccepted>=cfg.fusion.minimumPackets);
assert(state.lastFusion.cumulative.nAccepted>=cfg.fusion.minimumPackets);
assert(mean(errorsTrk.^2)<mean(errorsRaw.^2), ...
    'Tracking did not improve mean square error on seeded synthetic run.');
disp('integration_test_blk5: PASS');
end
