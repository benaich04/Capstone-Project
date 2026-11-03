function integration_test_blk4()
% Newly authored Block 4 geometry/CRLB test.
cfg=config();
d=vecnorm(cfg.Rx-cfg.P0.',2,2);
z=d(cfg.others)-d(cfg.refIdx);
R=0.02^2*(eye(cfg.nRx-1)+ones(cfg.nRx-1));
[p,C,info]=blk4_localize(z,R,cfg,[]);
checkIO(4,cfg,p,C,info);
assert(norm(p-cfg.P0)<1e-2,'Block 4 did not recover exact synthetic position.');
assert(all(eig(C)>0),'Block 4 CRLB must be positive definite.');
disp('integration_test_blk4: PASS');
end
