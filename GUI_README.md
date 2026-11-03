# Interactive Wi-Fi ISAC Capstone GUI — MATLAB R2026a

This folder contains the **existing integration project plus a native MATLAB user interface**. The app is a `.m` function using `uifigure`, `uigridlayout`, `uiaxes` and callbacks. It is **not an `.mlx` notebook** and **not an `.mlapp` App Designer file**. You can run it as a fully interactive MATLAB desktop window.

## Start it

1. Extract `capstone_GUI_R2026a.zip`.
2. In MATLAB R2026a, set **Current Folder** to `capstone_GUI_R2026a`.
3. Optional test: run `run_integration_tests` (the team previously reported all five new smoke tests passing), then run `gui_pipeline_selftest` for a real two-packet integration check.
4. In the Command Window, run:

   ```matlab
   capstoneGUI
   ```

   Or equivalently `launchGUI`. For a handle, use `fig = capstoneGUI;`.

## What you can do

**2D scene editor**

- **Drag the gold transmitter** marker with the mouse to any valid location (at least 0.25 m from an RX).
- **Drag any blue RX** triangle to reposition a receiver. The receiver coordinate table is editable, too.
- Under **Scene Editor**, click **Add wall: 2 clicks**, then click two empty locations on the map to create a reflecting wall.
- **Drag a purple wall** near an endpoint to reposition that endpoint, or near the middle to translate the whole segment.
- **Clear/Remove walls**, **Fit map**, **Zoom +/-**, **Restore default scene**.
- After processing a packet, toggle measured **TDoA hyperbola overlays**. The map also shows direct and modeled reflected paths, raw estimate, tracked estimate, and local 95% CRLB ellipse.

**Live simulation**

- Use **Run > STEP ONE PACKET** to run and display the actual original Blocks 1→2→3→4→5 once.
- Use **RUN FULL SEQUENCE** to process many packets with animated updates. **PAUSE / RESUME** and **STOP** work between packets; the **Animate** slider controls the *UI display pause*, not the physical packet interval `cfg.dt`.
- Choose **stationary/moving**, packet count, and fusion mode. Movement uses `cfg.P0 + cfg.velocity*t + cfg.motionAmplitude*sin(2*pi*cfg.motionFrequency*t)`.
- Under **RF + Tracking**, adjust Wi-Fi bandwidth, transmit power, noise figure, CIR zero padding, wall reflection loss, velocity, tracker acceleration model, static window/decay, and Monte Carlo trial count. New sample rate is kept equal to the Wi-Fi sample rate.
- Changing the experiment settings or moving a geometry item **resets old tracking history**, avoiding mixing results from incompatible scenes. It does not change the five-block functions.

**Analysis**

- **Signals tab:** Received Wi-Fi packet, L-LTF CSI magnitude, and CIR.
- **Localization tab:** True/estimated TDoAs, raw/tracked error, and 2×2 local CRLB covariance.
- **Diagnostics tab:** Per-RX distances, relative CIR timing, first-path SNR, the correlated TDoA covariance matrix R, and warnings/errors.
- **Monte Carlo tab:** Run multiple complete five-block single-packet experiments at each configured power. Failed trials are counted instead of hidden. See RMSE and conditional local CRLB RMS versus SNR.
- **Save session (.mat)** includes complete last packet, configuration, state and history. **Export history (.csv)** contains packet positions/errors, and **Export scene (.png)** saves the scene.

## Files added by this GUI

- `capstoneGUI.m`: builds the UI and handles dragging/sliders/plots/runs/exports.
- `capstoneGuiPacket.m`: runs one packet through the **unchanged full five-block** sequence and checks every block with `checkIO`.
- `launchGUI.m`: convenience one-command launcher.
- `gui_pipeline_selftest.m`: two-packet regression executable inside MATLAB.
- `GUI_README.md`: these instructions.

All original project files remain in this folder; original user uploads are also preserved under `original/`. The one previously documented narrow working-copy fix in `blk4_localize.m` remains unchanged.

## Limitations and interpretation

- **MATLAB R2026a / WLAN Toolbox** and a local interactive desktop session are required. A MATLAB runtime is not available in the authoring environment, so **the GUI's opening, mouse dragging, and full simulation have not been executed/visually verified here**. Run `gui_pipeline_selftest` and `capstoneGUI` in your MATLAB installation. Report exact errors with screenshots for adjustment.
- Block 1's wall model creates specular reflections **but does not block/attenuate direct LoS**, even if the direct line intersects a wall. The visualizer reflects this simplified physics.
- Block 3's CIR timing is relative to Block 2's common FFT timing origin. Only differences yield physical TDoA. Zero padding interpolates CIR sampling and **does not** increase physical bandwidth.
- Block 4 `Pcov` is a **local, conditional CRLB** based on Block 3's model covariance; it is not guaranteed to equal empirical covariance under multipath.
- Cumulative and finite/decaying-window fusion require a transmitter stationary during the fusion interval. In **moving mode**, Block 5 intentionally uses Kalman tracking and suppresses static fusion.
- Do not interpret the GUI's single/low-count trial results as capstone-grade performance validation; increase `Nmc` substantially and report failures/coverage before final presentation.
- The original team's README and `test_blk1.m`…`test_blk5.m` were not uploaded. The new integration smoke tests are distinct and are not substitutes.

## Recommended test order

```matlab
preflight
run_integration_tests
gui_pipeline_selftest
capstoneGUI
```

Click **STEP ONE PACKET** first. Then try **RUN FULL SEQUENCE** and **moving** mode. If the full pipeline fails, inspect **Diagnostics**: the error message identifies the first failing block and is not ignored.
