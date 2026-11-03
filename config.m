function cfg = config()
%CONFIG Central settings for the R2026a Wi-Fi TDoA integration candidate.
% This file is NEW. The original config.m was not supplied for review.
% Distances in m, time in s, frequency in Hz, power in W unless named dBm.
cfg.c = 299792458;
cfg.fc = 5.18e9;
cfg.cbw = 'CBW20';
cfg.B = 20e6;
cfg.fs = 20e6;
cfg.Rx = [0 0; 12 0; 12 12; 0 12];
cfg.nRx = size(cfg.Rx,1);
cfg.refIdx = 1;
cfg.others = setdiff(1:cfg.nRx,cfg.refIdx).';
cfg.P0 = [4; 7];
cfg.Pt_dBm = 0;
cfg.NF_dB = 7;
cfg.walls = zeros(0,4);
cfg.reflLoss_dB = 6;
cfg.psduLen = 100;              % PSDU bytes for non-HT packet
cfg.padSamples = 512;          % pre- and post-padding
cfg.tStartMax = 0.5e-6;        % shared unknown TX start-time jitter
cfg.cfoMax = 100;              % max magnitude of common CFO (Hz)
cfg.rxPhaseOn = true;
cfg.rxBackoff = 8;             % shared L-LTF FFT timing backoff (samples)
cfg.zpFactor = 16;
cfg.interp = 'parabola';
cfg.firstPathMethod = 'sic';
cfg.maxEarly = 300e-9;
cfg.pfa = 1e-3;
cfg.pfaCellFactor = 3.5;
cfg.maxPaths = 3;
cfg.tauFloorVar = (0.2e-9)^2;
cfg.lowSnr_dB = -3;
cfg.closeSep = 1.5/cfg.fs;
cfg.closeInflate = 10;
cfg.firstPath_dB = -12;
cfg.solver = 'lm';
cfg.maxIter = 300;
cfg.tol = 1e-6;
cfg.mu = 1;
cfg.gridN = 41;
cfg.gridStarts = 4;
cfg.areaMargin = 0.5;
cfg.chi2Alpha = 1e-3;
cfg.rejectOutlier = true;
cfg.Pinit = mean(cfg.Rx,1).';
cfg.seed = 42;
cfg.dt = 0.1;                  % time between independent packets
cfg.experimentMode = 'stationary';  % stationary | moving
cfg.Npackets = 12;
cfg.velocity = [0.30; 0.20];  % m/s in moving experiment
cfg.motionAmplitude = [0; 0];  % optional sinusoidal displacement (m)
cfg.motionFrequency = 0.1;     % Hz
cfg.enablePlots = true;
cfg.printProgress = true;
cfg.runMonteCarlo = true;
cfg.Nmc = 10;                 % quick demonstration only; increase for final study
cfg.mcPower_dBm = [-12 -4 4];
cfg.trackAccelStd = 0.5;      % process acceleration std (m/s^2)
cfg.trackInitialVelocityStd = 1.5; % prior velocity uncertainty (m/s)
cfg.trackMeasurementInflation = 1; % >=1; calibrate from actual residuals
cfg.fusionOutput = 'kalman';  % kalman | window | cumulative (static only)
cfg.fusion = struct('minimumPackets',5,'gateProbability',0.999, ...
    'gateAfter',10,'enableInnovationGate',true, ...
    'maxConsecutiveRejected',5,'covarianceScale',1, ...
    'windowLength',10,'windowDecay',0.96);
end
