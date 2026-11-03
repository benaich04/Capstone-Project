# Wi-Fi TDoA Localization - MATLAB R2026a integration candidate

## Status and integrity of inputs

The user provided **10 MATLAB files**: `blk1_txChannel.m`, `blk2_rx.m`,
`blk3_tdoa.m`, `blk4_localize.m`, `tdoaLocalize.m`, `tdoaModel.m`,
`tdoaOptions.m`, `tdoaValidate.m`, `tdoaWindowOptions.m`, and
`tdoaWindowStep.m`. Copies are kept unchanged under `original/`.

The original `README.md`, `config.m`, `test_blk1.m` ... `test_blk5.m`,
`tdoaStaticStep.m`, `blk5_track.m`, and `checkIO.m` were NOT among the
accessible attachments. A search of available project/library files did not
locate them. This package reconstructs the missing integration contracts
from the team work split document and the code signatures. **Do not treat
this package as verified against the absent original README or tests.**

MATLAB / Octave is NOT installed in the authoring environment, so the
original or new MATLAB tests could not be executed here. All runtime test
results must be established in MATLAB R2026a using the included scripts.

## Quick start in MATLAB R2026a

1. Extract the ZIP into a writable directory. Open MATLAB there and set the
   **current folder** to the project root. You need WLAN Toolbox and any
   other dependencies used by the original team functions.
2. Run `preflight` to confirm WLAN functions, then `run_integration_tests`
   and inspect every failure message. If the original team tests are supplied,
   use `run_all_tests` to run all ten suites and fail on missing originals.
3. Run `main('stationary')` for a stationary transmitter.
4. Run `main('moving')` for moving transmitter tracking. In moving mode,
   static/window TDoA fusion is deliberately suppressed because its fixed-
   position model is not valid for a moving target.
5. Open `main_live.m` in the Live Editor (MATLAB R2026a supports plain-text
   `.m` live code files). To generate a *native* `.mlx` file in MATLAB, run
   `convert_live_to_mlx`. The output is `presentation/main.mlx`, so the
   executable root `main.m` will not be shadowed by a same-basename MLX.
   If the converter is unsupported in your desktop configuration, open
   `main_live.m` as Live Script and use **Save As > MATLAB Live Code File
   (*.mlx)** into the `presentation/` folder.

The package does **not** contain a pre-verified native `main.mlx` because
MATLAB is required to create/verify that proprietary format. It does
include the full R2026a-compatible, rich-markup `main_live.m` source.

## Interface and data flow

| Block | Call | Output | Validation |
|---|---|---|---|
| 1 | `[Y,truth]=blk1_txChannel(cfg)` | `L x nRx` complex waveform and simulation-only truth | `checkIO(1,cfg,Y,truth)` |
| 2 | `[Hhat,noiseVar]=blk2_rx(Y,cfg)` | `nActive x nRx`, `1 x nRx` | `checkIO(2,cfg,Hhat,noiseVar)` |
| 3 | `[deltad,R,info3]=blk3_tdoa(Hhat,noiseVar,cfg)` | `(nRx-1)x1` in m; covariance `(nRx-1)x(nRx-1)` in m^2 | `checkIO(3,cfg,deltad,R,info3)` |
| 4 | `[Phat,Pcov,info4]=blk4_localize(deltad,R,cfg,Pinit)` | `2x1` in m; model CRLB `2x2` in m^2 | `checkIO(4,cfg,Phat,Pcov,info4)` |
| 5 | `[Ptrk,PtrkCov,Ppred,state]=blk5_track(Phat,Pcov,cfg,state)` | tracked position, covariance, next prediction, persistent state | `checkIO(5,cfg,Ptrk,PtrkCov,Ppred,state)` |

`cfg.refIdx=1` by default. TDoA sign convention is **RX2 - RX1, RX3 - RX1,
RX4 - RX1**. In Block 2, one common FFT timing offset is applied to every
receiver; separately synchronizing each receiver would destroy the TDoA.

### Important Block 5 integration detail

The original Block 5 contract only carries `Phat, Pcov`, but **cumulative
measurement fusion and finite-window fusion require raw TDoA measurements**.
These cannot be reconstructed uniquely from a position estimate. To avoid
losing the original raw measurements or changing the prescribed function
signature, the caller sets the transient payload before Block 5:

```matlab
if isempty(state), state=struct(); end
state.pendingTDOA=struct('z',deltad,'R',R,'packetId',double(k));
[Ptrk,PtrkCov,Ppred,state] = blk5_track(Phat,Pcov,cfg,state);
```

The wrapper consumes/removes `pendingTDOA`, calls the available original
`tdoaWindowStep.m`, and calls **newly reconstructed** `tdoaStaticStep.m` for
cumulative fusion. Their diagnostic outputs are stored in
`state.lastFusion.window` and `state.lastFusion.cumulative`. The
original `tdoaLocalize`, `tdoaValidate`, `tdoaModel`, `tdoaOptions`,
`tdoaWindowOptions` and `tdoaWindowStep` remain unchanged. In addition,
`state.lastTrack` keeps KF position, covariance and velocity diagnostics.

Window and cumulative fused estimates assume a fixed transmitter over the
relevant packet set. Their readiness and model-mismatch flags MUST be
checked. `cfg.fusionOutput` can select `kalman`, `window` or `cumulative`
for the reported `Ptrk` when the static estimate is ready; `Ppred` remains
the KF prediction. Moving mode always uses the Kalman filter.

## Functions and original changes

- **Originals preserved as supplied:** `blk1_txChannel.m`, `blk2_rx.m`,
  `blk3_tdoa.m`, and all six original Block 5 helpers.
- **One narrow safety fix in the working copy of `blk4_localize.m`:** the
  two local solver functions previously set `conv=true` when a line search
  failed. They now only mark convergence if the weighted gradient meets
  the stopping tolerance. A `crlbValid` diagnostic flag is also added to
  mark singular Fisher information before it enters the tracker. Originals
  are retained in `original/` for diffing.
- **New files:** `config.m`, `checkIO.m`, `blk5_track.m`,
  `tdoaStaticStep.m` (original unavailable), `main.m`, `main_live.m`,
  `convert_live_to_mlx.m`, `preflight.m`, `run_all_tests.m`,
  `runCapstoneExperiment.m`, `runMonteCarlo.m`,
  `plotCapstoneGeometry.m`, `plotCapstoneReport.m`, plus independent
  integration smoke tests and runner.

## Required configuration keys

The source functions use more keys than appeared in the earlier plan:

- Block 1: `walls`, `padSamples`, `Rx`, `P0`, `c`, `fc`, `cbw`, `psduLen`,
  `fs`, `Pt_dBm`, `reflLoss_dB`, `tStartMax`, `cfoMax`, `NF_dB`, `refIdx`;
  optional `rxPhaseOn`.
- Block 2: `cbw`, `fs`; optional `rxBackoff`.
- Block 3: `fs`, `nRx`, `refIdx`, `others`, `zpFactor`, `interp`, `c`,
  `tauFloorVar`, `pfa`, `maxPaths`, `pfaCellFactor`, and when thresholding
  `firstPath_dB`; optional `k`, `Nfft`, `firstPathMethod`, `maxEarly`,
  `lowSnr_dB`, `closeSep`, `closeInflate`.
- Block 4: `Rx` plus optional `refIdx`, `Pinit`, `solver`, `maxIter`,
  `tol`, `mu`, `gridN`, `gridStarts`, `areaMargin`, `chi2Alpha`,
  `rejectOutlier`.
- Block 5: `dt`, `trackAccelStd`, `trackInitialVelocityStd`,
  `trackMeasurementInflation`, `experimentMode`, `fusionOutput` and
  `fusion` options; the original helpers' numerical options remain
  controlled by `tdoaOptions.m` and `tdoaWindowOptions.m`.

All new configuration settings are in `config.m`. Original helper defaults
inside the delivered blocks have not been deleted.

## Interpretation caveats

- The Block 4 `Pcov` output is a **local model CRLB**, not a directly
  measured error covariance. Supplying it to the Kalman filter assumes it
  represents actual measurement uncertainty; this must be checked using
  held-out simulations and experiments, especially when multipath is present.
- Zero-padding the CIR interpolates the delay grid; it does not increase
  the physical Wi-Fi signal bandwidth. Centimetre-level accuracy is not
  guaranteed by zero-padding alone.
- Block 1's original model leaves direct signal energy present even when
  a wall crosses the straight TX-RX path (it emits a warning). This is a
  simplified reflection model, not a full NLoS blocking model.
- Block 3's first-path error and covariance require numerical calibration
  across SNR, bandwidth, multipath and receiver geometry. Its existing
  notes refer to results of an unavailable `test_blk3.m`.
- Repeated packets in the stationary/moving simulations are independent
  channel realizations generated by Block 1. Movement across frames is
  simulated by changing `cfg.P0` for Block 1 only; this does not simulate
  continuous Doppler within a Wi-Fi packet.
- Monte Carlo defaults in `config.m` are intentionally *quick demo*
  sizes. Increase `cfg.Nmc` to hundreds for defensible reported results.
  Failures are explicitly counted; the displayed RMSE is conditional on
  successful trials.

## Validation to perform in MATLAB

1. Run **the five original** team tests once provided; record version and
   actual PASS/FAIL output. They are not included and were NOT run here.
2. Run `run_integration_tests` and resolve all errors. These are NEW
   smoke tests, not substitutes for the originals.
3. Run `main('stationary')`, then `main('moving')`. Inspect each
   `info4` diagnostic, every `state.lastFusion` status and outlier count.
4. Run larger Monte Carlo sweeps with/without multipath, multiple layouts,
   and confidence coverage of the local CRLB ellipse. Document sample
   counts, fail rates, and worst-case errors.
5. In the Live Editor open and run every section of `main_live.m`, then
   call `convert_live_to_mlx` and verify the native file opens.

## Toolboxes

Blocks 1 and 2 require **WLAN Toolbox**. The supplied Block 2 calls
`frequencyOffset` and `RandStream`; these functions and other dependencies
must be checked with `which` in the target R2026a installation. The
optional Block 4 solver `'lsqnonlin'` requires Optimization Toolbox;
`cfg.solver='lm'` uses the team's own LM solver and is the default.

## File tree

```
capstone_integration_R2026a/
  original/                      unchanged supplied MATLAB sources
  blk1_txChannel.m ... blk4_localize.m
  tdoaLocalize.m, tdoaModel.m, tdoaOptions.m,
  tdoaValidate.m, tdoaWindowOptions.m, tdoaWindowStep.m
  config.m, checkIO.m
  blk5_track.m, tdoaStaticStep.m
  main.m, main_live.m, convert_live_to_mlx.m
  runCapstoneExperiment.m, runMonteCarlo.m
  plotCapstoneGeometry.m, plotCapstoneReport.m
  integration_test_blk1.m ... integration_test_blk5.m
  preflight.m, run_integration_tests.m, run_all_tests.m
  validation/ (static inspection and execution status)
  presentation/ (created in MATLAB by converter)
```
