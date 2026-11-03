function [Hhat, noiseVar] = blk2_rx(Y, cfg)
% BLK2_RX  Block 2: packet sync on RX1 only, then L-LTF channel + noise estimate for all RX.
%   Input : Y (L x 4 complex, one column per RX, same clock); cfg = config()
%   Output: Hhat (52 x 4 complex, L-LTF channel per active subcarrier per RX, all referenced
%           to ONE common timing), noiseVar (1 x 4, noise power per RX in W, time-domain units)
%   Rule  : detection, CFO and timing are estimated on RX1 only and applied identically to all
%           columns, so the delay differences needed by Block 3 are preserved.
%
% NOTES FOR BLOCK 3 (read this)
%   * The FFT window starts cfg.rxBackoff samples (default 8) BEFORE the estimated L-LTF start,
%     inside the cyclic prefix (GI2). This is harmless for the channel estimate (cyclic shift =
%     linear phase) and guarantees positive effective delays, even for an RX that receives
%     EARLIER than RX1. So the delay seen in Hhat(:,i) is
%         tau_eff_i = (tau_i - tau_1) + rxBackoff/fs + e,
%     where e is one common timing error (same for all RX). The offset cancels in the TDoA.
%     Block 3: do NOT interpret tau_eff_i as an absolute time of flight; only differences matter.
%   * Hhat(:,i) = (received L-LTF symbol) ./ (known L-LTF symbol), no frequency smoothing, then
%     divided by sqrt(alpha), alpha = fixed demodulator noise gain. Reason: this puts Hhat and
%     noiseVar in the same units, so Block 3 gets the per-subcarrier SNR simply as
%         snr_i(k) = |Hhat(k,i)|^2 / noiseVar(i)        (a global scale does not change delays).
%     Rows follow wlanNonHTOFDMInfo('L-LTF',...).ActiveFrequencyIndices (-26:-1, 1:26 for CBW20).
%   * noiseVar(i) is the time-domain white-noise power at RX i in W, directly comparable to the
%     noise power Block 1 adds.
%   * Optional new setting for config.m: cfg.rxBackoff = 8;  (samples, 0 < rxBackoff < 32)
%
% Requires WLAN Toolbox.

% ---------- settings (only from cfg) ----------
cbw = cfg.cbw;
fs  = cfg.fs;
if isfield(cfg, 'rxBackoff'), b = cfg.rxBackoff; else, b = 8; end

nonHT = wlanNonHTConfig('ChannelBandwidth', cbw);
if abs(wlanSampleRate(nonHT) - fs) > 1
    error('blk2_rx:sampleRate', ...
        'cfg.fs (%g Hz) must equal the %s sample rate (%g Hz); oversampling is not supported.', ...
        fs, cbw, wlanSampleRate(nonHT));
end
if b < 0 || b >= 32
    error('blk2_rx:backoff', 'cfg.rxBackoff must be in [0, 32) samples.');
end

[L, Nrx] = size(Y);
ind = wlanFieldIndices(nonHT);          % field index ranges, 1-based, relative to packet start

% ---------- 1) packet detection on RX1 only ----------
off0 = wlanPacketDetect(Y(:,1), cbw);   % 0-based offset of the packet start (coarse)
if isempty(off0)
    error('blk2_rx:noPacket', 'No packet detected on RX1.');
end
checkRange(off0 + ind.LSIG(2), L, 'L-STF/L-SIG');

% ---------- 2) coarse CFO from L-STF (RX1), applied to all RX ----------
stf     = Y(off0 + (ind.LSTF(1):ind.LSTF(2)), 1);
cfoCoarse = wlanCoarseCFOEstimate(stf, cbw);
Y = frequencyOffset(Y, fs, -cfoCoarse);

% ---------- 3) symbol timing on RX1 -> ONE start index for all RX ----------
seg    = Y(off0 + (ind.LSTF(1):ind.LSIG(2)), 1);
symOff = wlanSymbolTimingEstimate(seg, cbw);
pktOff = off0 + symOff;                 % estimated start of L-STF (0-based)
checkRange(pktOff + ind.LLTF(2), L, 'L-LTF');
if pktOff + ind.LLTF(1) - b < 1
    error('blk2_rx:early', 'Packet starts too close to the beginning of Y.');
end

% ---------- 4) fine CFO from L-LTF (RX1), applied to all RX ----------
lltf1     = Y(pktOff + (ind.LLTF(1):ind.LLTF(2)), 1);
cfoFine   = wlanFineCFOEstimate(lltf1, cbw);
Y = frequencyOffset(Y, fs, -cfoFine);

% ---------- 5) cut L-LTF with the SAME index for all RX (window moved b samples early) ----------
lltf = Y(pktOff + (ind.LLTF(1):ind.LLTF(2)) - b, :);    % 160 x Nrx
D    = wlanLLTFDemodulate(lltf, cbw);                   % 52 x 2 x Nrx

% ---------- 6) channel estimate per RX (no smoothing: keeps the delay information sharp) ----------
chEst = wlanLLTFChannelEstimate(D, cbw);
alpha = demodNoiseGain(cbw, ind);                       % demodulator noise gain (see below)
Hhat  = reshape(chEst, size(D,1), Nrx) / sqrt(alpha);   % 52 x Nrx, same units as noiseVar

% ---------- 7) noise power per RX ----------
% The two L-LTF symbols are identical, so their difference is pure noise.
d     = reshape(D(:,1,:) - D(:,2,:), size(D,1), Nrx);
nvF   = mean(abs(d).^2, 1) / 2;                         % noise variance per demodulated bin
noiseVar = nvF / alpha;                                 % back to time-domain noise power (W)
noiseVar = reshape(noiseVar, 1, Nrx);
end

% =====================================================================================
function checkRange(lastIdx, L, what)
if lastIdx > L
    error('blk2_rx:short', 'Y is too short: %s does not fit in the record.', what);
end
end

function alpha = demodNoiseGain(cbw, ind)
% Noise variance of one demodulated bin per unit time-domain noise variance (wlanLLTFDemodulate
% is linear, so measure it on unit-variance white noise; private stream, global rng untouched).
nS  = ind.LLTF(2) - ind.LLTF(1) + 1;
s   = RandStream('twister', 'Seed', 12345);
w   = (randn(s, nS, 400) + 1j*randn(s, nS, 400)) / sqrt(2);
Dw  = wlanLLTFDemodulate(w, cbw);
alpha = mean(abs(Dw(:)).^2);
end
