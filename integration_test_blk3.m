function integration_test_blk3()
% Newly authored Block 3 synthetic-CSI test. No ideal ToA fed to Block 4.
cfg=config();
k=[-26:-1 1:26]';
f=k*cfg.fs/64;
tau=[6 32 55 79]'*1e-9;
H=exp(-1j*2*pi*f*tau.');
noiseVar=ones(1,cfg.nRx)*1e-8;
[dd,R,info]=blk3_tdoa(H,noiseVar,cfg);
checkIO(3,cfg,dd,R,info);
expected=cfg.c*(tau(cfg.others)-tau(cfg.refIdx));
assert(norm(dd-expected)<3,'Synthetic Block 3 TDoA error exceeded 3 metres.');
assert(all(eig(R)>0));
disp('integration_test_blk3: PASS');
end
