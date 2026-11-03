function integration_test_blk2()
% Newly authored Block 2 smoke test, NOT the absent original test_blk2.m.
cfg=config(); rng(cfg.seed);
[Y,~]=blk1_txChannel(cfg);
[Hhat,noiseVar]=blk2_rx(Y,cfg);
checkIO(2,cfg,Hhat,noiseVar);
assert(all(isfinite(unwrap(angle(Hhat(:,cfg.refIdx))))));
assert(all(noiseVar>=0));
disp('integration_test_blk2: PASS');
end
