function integration_test_blk1()
% Newly authored Block 1 smoke test, NOT the absent original test_blk1.m.
cfg=config(); rng(cfg.seed);
[Y,t]=blk1_txChannel(cfg);
checkIO(1,cfg,Y,t);
d=vecnorm(cfg.Rx-cfg.P0.',2,2);
assert(max(abs(d-t.d))<1e-10,'Block 1 geometry differs from truth.');
assert(max(abs(t.deltad-(d(cfg.others)-d(cfg.refIdx))))<1e-10);
assert(numel(t.tArrival)==cfg.nRx);
disp('integration_test_blk1: PASS');
end
