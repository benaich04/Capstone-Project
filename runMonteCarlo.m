function mc = runMonteCarlo(cfg)
%RUNMONTECARLO End-to-end packet Monte Carlo: never substitute ideal TDoA.
% Failures are counted, retained, and printed; successful-run RMSE is conditional.
P=cfg.mcPower_dBm(:);
N=cfg.Nmc;
validateattributes(N,{'numeric'},{'scalar','integer','positive'});
mc=struct('power_dBm',P,'rmse',nan(numel(P),1), ...
    'meanSNR_dB',nan(numel(P),1),'crlbRMS',nan(numel(P),1), ...
    'nSuccess',zeros(numel(P),1),'nFailed',zeros(numel(P),1), ...
    'errors',nan(N,numel(P)),'failures',{{}});
for j=1:numel(P)
    snrs=nan(N,1); bound=nan(N,1);
    for k=1:N
        trial=cfg;
        trial.Pt_dBm=P(j);
        trial.Npackets=1;
        trial.experimentMode='stationary';
        trial.enablePlots=false;
        trial.printProgress=false;
        trial.runMonteCarlo=false;
        trial.seed=cfg.seed+10000*j+k;
        try
            out=runCapstoneExperiment(trial);
            mc.errors(k,j)=out.rawError(1);
            snrs(k)=out.truth{1}.SNR_dB(trial.refIdx);
            bound(k)=out.crlbTrace(1);
            mc.nSuccess(j)=mc.nSuccess(j)+1;
        catch ME
            mc.nFailed(j)=mc.nFailed(j)+1;
            mc.failures{end+1}=sprintf('Pt=%g dBm, trial=%d, %s: %s', ...
                P(j),k,ME.identifier,ME.message); %#ok<AGROW>
            warning('runMonteCarlo:TrialFailed', '%s',mc.failures{end});
        end
    end
    ok=isfinite(mc.errors(:,j));
    if any(ok)
        mc.rmse(j)=sqrt(mean(mc.errors(ok,j).^2));
        mc.meanSNR_dB(j)=mean(snrs(ok));
        mc.crlbRMS(j)=sqrt(mean(bound(ok)));
    end
    fprintf('Monte Carlo Pt %+5.1f dBm: success=%d/%d; RMSE=%g m; CRLB RMS=%g m\n', ...
        P(j),mc.nSuccess(j),N,mc.rmse(j),mc.crlbRMS(j));
end
end
