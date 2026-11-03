function results = main(mode)
%MAIN Full Wi-Fi TDoA Capstone integration entry point for MATLAB R2026a.
% Usage: main; main('stationary'); main('moving'); results=main('moving');
% Requires WLAN Toolbox and the included source files on MATLAB path.
% The original team tests and README.md were not supplied; see INTEGRATION_README.md.
if nargin<1 || isempty(mode), mode='stationary'; end
cfg=config();
cfg.experimentMode=char(mode);
if strcmpi(mode,'moving')
    cfg.Npackets=max(cfg.Npackets,20);
elseif ~strcmpi(mode,'stationary')
    error('main:Mode','Mode must be stationary or moving.');
end
fprintf('\nWi-Fi ISAC TDoA | MATLAB R2026a | %s mode\n',cfg.experimentMode);
fprintf('RX count: %d, bandwidth: %.1f MHz, rate: %.1f Msps\n', ...
    cfg.nRx,cfg.B/1e6,cfg.fs/1e6);
results=runCapstoneExperiment(cfg);
last=results.last;
fprintf('\nTrue TX [x y] (m):     [%.4f %.4f]\n',last.truth.P0);
fprintf('Raw estimate [x y] (m): [%.4f %.4f]\n',last.Phat);
fprintf('Track estimate (m):     [%.4f %.4f]\n',last.Ptrk);
fprintf('Last raw error: %.4f m; tracked error: %.4f m\n', ...
    results.rawError(end),results.trackError(end));
fprintf('Raw RMSE: %.4f m; track RMSE: %.4f m\n', ...
    results.rawRMSE,results.trackRMSE);
fprintf('TDoA distance differences (m): %s\n',mat2str(last.deltad.',6));
fprintf('TDoA covariance R (m^2):\n');disp(last.R);
fprintf('Position CRLB (conditional on Block 3 covariance R; m^2):\n');disp(last.Pcov);
fprintf('Local 1-sigma position bound (sqrt(trace(CRLB))): %.4f m\n',sqrt(trace(last.Pcov)));
fprintf('Solver converged=%d, chi2Pass=%d, ambiguous=%d, CRLB valid=%d\n', ...
    last.info4.converged,last.info4.chi2Pass,last.info4.ambiguous,last.info4.crlbValid);
if strcmpi(cfg.experimentMode,'stationary')
    fm=results.state.lastFusion;
    fprintf('Cumulative fusion: status=%s, ready=%d, mismatch=%d\n', ...
        fm.cumulative.status,fm.cumulative.ready,fm.cumulative.modelMismatch);
    fprintf('Window fusion: status=%s, ready=%d, mismatch=%d, used=%d\n', ...
        fm.window.status,fm.window.ready,fm.window.modelMismatch,fm.window.windowCount);
else
    fprintf('Moving mode: fixed-position cumulative/window fusion omitted.\n');
end
if cfg.enablePlots, plotCapstoneReport(results,cfg); end
if cfg.runMonteCarlo
    fprintf('\nRunning %d Monte Carlo trials per power setting (end-to-end)...\n',cfg.Nmc);
    results.mc=runMonteCarlo(cfg);
    if cfg.enablePlots
        figure('Name','End-to-end Monte Carlo','Color','w');
        plot(results.mc.meanSNR_dB,results.mc.rmse,'-o', ...
            'LineWidth',1.5,'DisplayName','Empirical raw RMSE');hold on;
        plot(results.mc.meanSNR_dB,results.mc.crlbRMS,'--s', ...
            'LineWidth',1.5,'DisplayName','Local CRLB RMS');
        xlabel('Mean RX1 SNR (dB)');ylabel('Position error (m)');
        title('Full waveform to location: Monte Carlo');
        grid on;legend('Location','best');
    end
end
fprintf('\nImportant: results are pending execution and tests in MATLAB R2026a.\n');
end
