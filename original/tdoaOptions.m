function o = tdoaOptions()
%TDOAOPTIONS Defaults for 2-D localization and independent-packet static fusion.
% Numerical tolerances are in metres or dimensionless as indicated.
% Override returned fields; configuration is locked while fusion state is live.
o.maxIterations = 100;
o.maxDampingTrials = 20;
o.gradientTolerance = 1e-7;
o.initialDamping = 1e-3;
o.minInformationRcond = 1e-10;
o.multistart = true;
o.ambiguityCostGap = 2;
o.gateProbability = 0.999;
o.gateAfter = 10;
o.enableInnovationGate = true;
o.maxConsecutiveRejected = 5;
o.minimumPackets = 10;
o.covarianceScale = 1; % >=1, independently justified correction to supplied R.
end
