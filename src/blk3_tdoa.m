function [deltad, R, info3] = blk3_tdoa(Hhat, noiseVar, cfg)
%BLK3_TDOA  Block 3 - TDoA (delay, SNR, R).
%   [deltad, R, info3] = blk3_tdoa(Hhat, noiseVar, cfg)
%
%   Turn each channel estimate into an arrival time, take differences vs the
%   reference RX, and build the trust (covariance) matrix R.
%
%   INPUTS
%     Hhat     : complex matrix, nActive x nRx (from Block 2)
%     noiseVar : row vector, 1 x nRx [W] (from Block 2)
%     cfg      : uses B, fs, c, zpFactor, interp, interpU, firstPath_dB, refIdx
%
%   OUTPUTS
%     deltad   : column vector, nTDoA x 1 [m]. deltad(k) = d(others(k)) - d(refIdx)
%     R        : symmetric matrix, nTDoA x nTDoA [m^2]. Covariance of deltad.
%     info3    : struct, debug only: .tauHat (nRx x 1, s), .snrHat_dB (nRx x 1),
%                .cir (CIR per RX, optional for plots)
%
%   TO DO
%     - Map active subcarriers to correct FFT bins (DC/guards = 0)
%     - Zero-pad by cfg.zpFactor, IFFT -> CIR per RX
%     - First-path peak + sub-sample interpolation (cfg.interp)
%     - deltad = c * (tau(others) - tau(ref))
%     - SNR per RX -> timing variance -> R (include shared ref term)
%
%   USEFUL MATLAB
%   wlanNonHTOFDMInfo, ifft, ifftshift, interpft, max, findpeaks
%
%   Owner : ______________      Status : NOT STARTED
%   See docs/TDoA_Team_Work_Split.pdf, Block 3 page.

% ---- YOUR CODE HERE ---------------------------------------------------

error('blk3_tdoa:notImplemented', 'Block 3 (TDoA (delay, SNR, R)) is not implemented yet.');

end
