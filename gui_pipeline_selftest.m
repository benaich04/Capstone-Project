function out = gui_pipeline_selftest()
%GUI_PIPELINE_SELFTEST Real two-packet five-block regression (run in MATLAB).
% This is separate from the original tests, which were not supplied.
cfg=config();
cfg.experimentMode='stationary';
cfg.runMonteCarlo=false;
cfg.enablePlots=false;
cfg.printProgress=false;
rng(cfg.seed,'twister');
state=[];Ppred=[];
[p1,state,Ppred]=capstoneGuiPacket(cfg,state,Ppred,1);
assert(isequal(size(p1.Y,2),4),'Expected four common-clock receivers.');
assert(isequal(size(p1.deltad),[3 1]),'TDoA shape mismatch.');
assert(isequal(size(p1.R),[3 3]),'R shape mismatch.');
assert(isequal(size(p1.Phat),[2 1]),'Raw position shape mismatch.');
assert(isequal(size(p1.Ptrk),[2 1]),'Tracked position shape mismatch.');
assert(all(isfinite([p1.rawError p1.trackError])),'Non-finite error.');
[p2,state,Ppred]=capstoneGuiPacket(cfg,state,Ppred,2);
assert(state.kf.n==2,'Kalman state failed to persist to packet 2.');
assert(all(isfinite(p2.Ptrk)),'Nonfinite tracking state.');
out=struct('passed',true,'packet1_rawError_m',p1.rawError, ...
    'packet1_trackedError_m',p1.trackError,'packet2_rawError_m',p2.rawError, ...
    'packet2_trackedError_m',p2.trackError,'lastTDoA_m',p2.deltad, ...
    'solverInfo',p2.info4);
fprintf('GUI pipeline selftest: PASS (2 packets, all 5 original blocks invoked).\n');
disp(out);
end
