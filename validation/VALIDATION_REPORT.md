# Integration inspection and validation report

**Scope:** 10 supplied MATLAB source files, the 5-block interface contract
from the uploaded team work-split PDF, and newly authored integration files.
**Target:** MATLAB R2026a.
**Execution status:** NOT executed in MATLAB/Octave; neither runtime is
installed in this environment. Do not describe any MATLAB tests as passed.

## Availability audit

| Requested item | Found? | Action |
|---|---|---|
| `blk1_txChannel.m` | Yes | Included verbatim |
| `blk2_rx.m` | Yes | Included verbatim |
| `blk3_tdoa.m` | Yes | Included verbatim |
| `blk4_localize.m` | Yes | Working copy has narrow convergence/CRLB diagnostics fix; original retained |
| `tdoaLocalize.m` | Yes | Included verbatim |
| `tdoaModel.m` | Yes | Included verbatim |
| `tdoaOptions.m` | Yes | Included verbatim |
| `tdoaValidate.m` | Yes | Included verbatim |
| `tdoaWindowOptions.m` | Yes | Included verbatim |
| `tdoaWindowStep.m` | Yes | Included verbatim |
| `tdoaStaticStep.m` | No | NEW reconstruction, not claimed original |
| `blk5_track.m` | No | NEW adapter to original Block 5 helper functions |
| `README.md` | No | Documented inferred contract from work split and function signatures |
| `config.m` | No | NEW central configuration |
| `test_blk1.m` ... `test_blk5.m` | No | NEW, separately named integration smoke tests; originals not run |
| `checkIO.m` | No | NEW strict output contract checks |
| MATLAB R2026a runtime | No | MATLAB execution and native .mlx verification remain pending |

## Per-block findings and tests

| Block | Source-level findings | Runtime test |
|---|---|---|
| 1: TX/channel | Produces common-clock complex waveform and simulation truth. Requires additional `cfg.psduLen`, `padSamples`, `tStartMax`, `cfoMax`. Wall crossings warn but direct path is not blocked. | Original unavailable; new integration smoke test NOT RUN |
| 2: receiver | One common packet start/CFO estimated on RX1. Produces L-LTF CSI and noise power, depends on `frequencyOffset` and WLAN Toolbox. | Original unavailable; new integration smoke test NOT RUN |
| 3: TDoA | Subcarrier-to-CIR mapping, first-path SIC/threshold, correlated covariance with reference RX. Requires `cfg.nRx`, `cfg.others`, `pfa`, `maxPaths`, `tauFloorVar` etc. `interp='fft'` is NOT supported (parabola only). | Original unavailable; new synthetic-CSI smoke test NOT RUN |
| 4: localization | WNLS multi-start LM, CRLB, chi-square and ambiguity diagnostics. Original `solveLM`/`solveGrad` reported convergence after failed line search; working copy corrects that. Adds `crlbValid` flag. | Original unavailable; new geometry/CRLB test NOT RUN |
| 5: tracking/fusion | Supplied nonlinear localization and finite/decaying-window fusion. Missing cumulative step, tracker entry point, and original tests. Adapter and cumulative step newly implemented and awaiting numerical review. | Original unavailable; new tracker/fusion smoke test NOT RUN |

## Contract checks performed statically

- The callable signatures required by the work-split PDF are present in the
  new project (Blocks 1-4 retained, Block 5 added).
- The integration loop calls all five blocks in sequence, passes actual
  outputs forward, and invokes `checkIO` immediately after each block.
- `cfg.others` is the ordered list of receiver indices omitting `cfg.refIdx`.
- The shared covariance from Block 3 is passed without replacement to
  Block 4; the same raw `deltad,R` is passed through `state.pendingTDOA`
  for Block 5 stationary measurement fusion.
- Block 5 retains the provided original helper functions and uses
  `tdoaWindowStep` for both uniform and decayed windows; the new
  `tdoaStaticStep` uses cumulative information fusion.
- The original source snapshot is preserved for comparisons in `original/`.
- Source-level static audit is in `static_audit.json` and its generating
  script `static_audit.py`.

## Outstanding validation gates

1. Upload and run the original README's exact contract checks and all five
   original tests, which were not accessible for inspection.
2. In MATLAB R2026a, run `run_integration_tests`, record each error,
   resolve toolbox or numeric differences, and rerun without suppressing
   failures.
3. Validate Monte Carlo RMSE, CRLB confidence coverage, and the SNR-
   bandwidth trade-off. The code has not produced any real numeric results.
4. Verify the model-based CRLB covariance is calibrated before treating it
   as a Kalman observation covariance. Inspect four-channel common-clock
   timing under multipath and for receivers arriving earlier than RX1.
5. Convert `main_live.m` in MATLAB desktop using `convert_live_to_mlx`
   and verify `presentation/main.mlx` opens and runs. This format is not
   available as a verified file from the current environment.

No native `.mlx`, output plots, PASS labels, or localization accuracy values
have been fabricated for this package.
