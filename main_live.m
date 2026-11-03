%[text] # Wi-Fi TDoA Localization | Capstone 2026-2027
%[text] A presentation-ready, end-to-end MATLAB R2026a Live Editor script using the supplied Block 1-4 code and the new Block 5 integration adapter. The sampled waveform is processed through every stage; ideal TDoA values are used only for evaluation, never as algorithm inputs.
%[text:tableOfContents]{"heading":"Presentation sections"}
%%
%[text] ## System configuration
%[text] Four receivers measure one common transmitted Wi-Fi packet. RX1 defines the time reference. The central configuration controls geometry, channel, estimation and tracking.
cfg=config();
cfg.experimentMode='stationary';
rng(cfg.seed,'twister');
disp(struct('SampleRate_Hz',cfg.fs,'Bandwidth_Hz',cfg.B,'Carrier_Hz',cfg.fc, ...
    'ReceiverCoordinates_m',cfg.Rx,'InitialTX_m',cfg.P0));
%%
%[text] ## Block 1 - Transmitter and channel
%[text] Generate a complete legacy Wi-Fi packet, apply geometry-based fractional delays, attenuation, optional wall reflections and thermal noise. All received signals share the same clock.
[Y,truth]=blk1_txChannel(cfg);
checkIO(1,cfg,Y,truth);
disp(struct('SignalDimensions',size(Y),'DirectDistances_m',truth.d, ...
    'SNR_dB',truth.SNR_dB,'BouncePerRX',truth.hasBounce));
figure('Color','w');
plot((0:size(Y,1)-1)'/cfg.fs*1e6,abs(Y));
xlabel('Capture time (microseconds)');ylabel('|Received baseband sample|');
title('Block 1: four noisy receiver waveforms');legend('RX1','RX2','RX3','RX4');grid on;
%%
%[text] ## Block 2 - Receiver processing
%[text] Detect the packet and correct timing and carrier offset with RX1, then apply the same synchronization to all four channels. The output is L-LTF channel state information (CSI) with a common timing reference.
[Hhat,noiseVar]=blk2_rx(Y,cfg);
checkIO(2,cfg,Hhat,noiseVar);
disp(struct('ChannelDimensions',size(Hhat),'NoisePower_W',noiseVar));
figure('Color','w');
plot(unwrap(angle(Hhat)),'LineWidth',1.2);
xlabel('Active L-LTF subcarrier index');ylabel('Unwrapped channel phase (rad)');
title('Block 2: phase slopes contain relative propagation delays');
legend('RX1','RX2','RX3','RX4');grid on;
%%
%[text] ## Block 3 - TDoA estimation
%[text] Transform CSI into a zero-padded channel impulse response (CIR), estimate each earliest physical path, then subtract the common RX1 timing offset. The output covariance R includes the correlation caused by sharing RX1.
[deltad,R,info3]=blk3_tdoa(Hhat,noiseVar,cfg);
checkIO(3,cfg,deltad,R,info3);
disp(struct('RangeDifference_m',deltad,'ArrivalTimeRelative_s',info3.tauHat, ...
    'FirstPathSNR_dB',info3.snrFirst_dB,'TDoACovariance_m2',R));
N=size(info3.cir,1);
delay_ns=((0:N-1)'-N/2)/(cfg.fs*cfg.zpFactor)*1e9;
figure('Color','w');
plot(delay_ns,abs(fftshift(info3.cir,1)));
xlabel('Delay relative to shared FFT window (ns)');ylabel('|CIR|');
title('Block 3: oversampled channel impulse responses');
legend('RX1','RX2','RX3','RX4');grid on;
%%
%[text] ## Block 4 - Position localization
%[text] Estimate 2-D position with weighted nonlinear least squares using R. The reported Cramer-Rao lower bound (CRLB) is local and conditional on the measurement model and geometry.
[Phat,Pcov,info4]=blk4_localize(deltad,R,cfg,[]);
checkIO(4,cfg,Phat,Pcov,info4);
disp(struct('RawPosition_m',Phat,'CRLB_m2',Pcov,'Converged',info4.converged, ...
    'ChiSquarePass',info4.chi2Pass,'Ambiguous',info4.ambiguous));
plotCapstoneGeometry(cfg,truth,Phat,[],Pcov);
%%
%[text] ## Block 5 - Tracking and measurement fusion
%[text] The Kalman filter smooths a sequence of position estimates and predicts the next position. For stationary experiments, Block 5 also retains cumulative TDoA fusion and finite/decaying-window fusion, with readiness and model-consistency diagnostics.
state=struct();
state.pendingTDOA=struct('z',deltad,'R',R,'packetId',1);
[Ptrk,PtrkCov,Ppred,state]=blk5_track(Phat,Pcov,cfg,state);
checkIO(5,cfg,Ptrk,PtrkCov,Ppred,state);
rawHistory=nan(2,cfg.Npackets); trackHistory=nan(2,cfg.Npackets);
trueHistory=nan(2,cfg.Npackets); errRaw=nan(1,cfg.Npackets); errTrack=nan(1,cfg.Npackets);
rawHistory(:,1)=Phat; trackHistory(:,1)=Ptrk; trueHistory(:,1)=truth.P0;
errRaw(1)=norm(Phat-truth.P0);errTrack(1)=norm(Ptrk-truth.P0);
pk=Phat;Ck=Pcov;tk=truth;
for packetId=2:cfg.Npackets
    [Yk,tk]=blk1_txChannel(cfg);checkIO(1,cfg,Yk,tk);
    [Hk,nk]=blk2_rx(Yk,cfg);checkIO(2,cfg,Hk,nk);
    [zk,Rk,ik]=blk3_tdoa(Hk,nk,cfg);checkIO(3,cfg,zk,Rk,ik);
    [pk,Ck,dk]=blk4_localize(zk,Rk,cfg,Ppred);checkIO(4,cfg,pk,Ck,dk);
    state.pendingTDOA=struct('z',zk,'R',Rk,'packetId',double(packetId));
    [Ptrk,PtrkCov,Ppred,state]=blk5_track(pk,Ck,cfg,state);
    checkIO(5,cfg,Ptrk,PtrkCov,Ppred,state);
    rawHistory(:,packetId)=pk;trackHistory(:,packetId)=Ptrk;
    trueHistory(:,packetId)=tk.P0;
    errRaw(packetId)=norm(pk-tk.P0);errTrack(packetId)=norm(Ptrk-tk.P0);
end
disp(state.lastFusion);
figure('Color','w');
plot(1:cfg.Npackets,errRaw,'o-',1:cfg.Npackets,errTrack,'s-','LineWidth',1.3);
xlabel('Wi-Fi packet');ylabel('Position error (m)');title('Block 5: raw versus tracked positions');
legend('Single-packet NLS','Kalman-filtered output');grid on;
%%
%[text] ## Final position estimate and error
%[text] Compare the final raw and tracked localization outputs to the known simulated transmitter. Ground truth is never supplied to the localization or fusion solvers.
rawRMSE=sqrt(mean(errRaw.^2));
trackRMSE=sqrt(mean(errTrack.^2));
comparison=table([rawHistory(1,end);trackHistory(1,end)], ...
    [rawHistory(2,end);trackHistory(2,end)], ...
    [errRaw(end);errTrack(end)], ...
    'VariableNames',{'X_m','Y_m','LastError_m'}, ...
    'RowNames',{'Raw_NLS','Tracker'});
disp(comparison);
disp(struct('TruePosition_m',trueHistory(:,end), ...
    'RawRMSE_m',rawRMSE,'TrackedRMSE_m',trackRMSE, ...
    'LastCRLB_m2',Ck));
plotCapstoneGeometry(cfg,tk,pk,Ptrk,Ck);
%%
%[text] ## Monte Carlo evaluation
%[text] Each trial regenerates Wi-Fi samples and reruns Blocks 1 through 5. Failed trials are counted, not ignored. The quick demo uses cfg.Nmc trials per power; increase the trial count for final capstone figures.
mc=runMonteCarlo(cfg);
disp(table(mc.power_dBm,mc.meanSNR_dB,mc.rmse,mc.crlbRMS, ...
    mc.nSuccess,mc.nFailed, ...
    'VariableNames',{'TXPower_dBm','RX1SNR_dB','EmpiricalRMSE_m', ...
    'LocalCRLB_RMS_m','Successful','Failed'}));
figure('Color','w');
plot(mc.meanSNR_dB,mc.rmse,'o-','LineWidth',1.5);hold on;
plot(mc.meanSNR_dB,mc.crlbRMS,'s--','LineWidth',1.5);
xlabel('RX1 SNR (dB)');ylabel('2-D position error (m)');
title('End-to-end Monte Carlo: empirical RMSE vs local CRLB');
legend('Empirical raw RMSE','Model-based local CRLB RMS');grid on;
%%
%[text] ## Performance comparisons and conclusions
%[text] The end-to-end simulation connects actual waveform generation, common-clock Wi-Fi CSI, fractional-delay TDoA, weighted localization, and temporal tracking. A 95% ellipse assumes local Gaussian errors; it is not a guarantee under multipath, false paths, ambiguous geometry, or inaccurate covariance calibration.
%[text] **Validation checklist:** run the supplied teams' original test scripts once available; run `run_integration_tests`; inspect Block 4 warnings, Block 5 readiness/consistency, and Monte Carlo failure counts. The native binary `main.mlx` can be generated within the MATLAB desktop by calling `convert_live_to_mlx`.
disp(struct('TotalPackets',cfg.Npackets,'RawRMSE_m',rawRMSE, ...
    'TrackedRMSE_m',trackRMSE,'MCSuccesses',mc.nSuccess, ...
    'MCFailures',mc.nFailed));

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
