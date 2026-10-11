function [Y, truth] = blk1_txChannel(cfg)
%BLK1_TXCHANNEL  Block 1 - TX + Channel.
%   [Y, truth] = blk1_txChannel(cfg)
%
%   Generate one Wi-Fi packet and simulate what each of the 4 receivers captures.
%
%   INPUTS
%     cfg      : struct from config.m (uses P0, Rx, fc, B, fs, Pt_dBm, NF_dB,
%                walls, reflLoss_dB, maxT0, guardSamples, cfo_ppm, ...)
%
%   OUTPUTS
%     Y        : complex matrix, L x nRx. Received samples, one column per RX,
%                all on the SAME time axis (shared clock).
%     truth    : struct, TESTING ONLY. Suggested fields:
%                .d (nRx x 1, m)  .tau (nRx x 1, s)  .t0 (s)
%                .SNR_dB (nRx x 1)  .hasBounce (nRx x 1, logical)
%
%   TO DO
%     - Generate non-HT packet (L-STF + L-LTF + L-SIG + data)
%     - Add guard zeros + random TX start t0 (same for all RX)
%     - Per RX: fractional delay d/c, path loss, optional wall bounce
%     - Common CFO, random phase per RX, thermal noise
%     - Fill truth struct
%
%   USEFUL MATLAB
%   wlanNonHTConfig, wlanWaveformGenerator, delayseq, fspl,
%   comm.PhaseFrequencyOffset, awgn / wgn
%
%   Owner : ______________      Status : NOT STARTED
%   See docs/TDoA_Team_Work_Split.pdf, Block 1 page.

% ---- YOUR CODE HERE ---------------------------------------------------

error('blk1_txChannel:notImplemented', 'Block 1 (TX + Channel) is not implemented yet.');

end
