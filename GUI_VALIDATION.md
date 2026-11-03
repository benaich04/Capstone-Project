# GUI static validation record

**Execution environment:** container without MATLAB or Octave (verified during authoring).

**Static checks performed:**

- All five block `.m` entry points are present alongside `config.m` and `checkIO.m`.
- `capstoneGuiPacket.m` calls actual Block 1 → 2 → 3 → 4 → 5, validating with `checkIO` after each call.
- 28 named GUI callbacks used as function handles are defined in `capstoneGUI.m`.
- The complete existing integration directory was copied, and the previously-existing integration files were confirmed byte-for-byte unchanged.
- UI controls use MathWorks' documented `uifigure`, `uigridlayout`, `uiaxes`, `uislider` and figure mouse callbacks.
- `gui_pipeline_selftest.m` was added to test two real packets in MATLAB.

**Not yet validated:** opening and laying out the UI in a MATLAB desktop, clicking/dragging markers, R2026a compatibility on the user's Mac, running live Wi-Fi processing, and numerical accuracy. No pass claims are made for those absent runtime tests. The user's earlier screenshot showed 5/5 of the prior standalone integration smoke tests passing; that does **not** validate this new GUI.

**Known model caveats:** walls do not attenuate LoS in the original TX channel; CIR zero-padding is interpolation, not increased bandwidth; CRLB is model-conditional; static fusion must not be applied to moving transmitters.
