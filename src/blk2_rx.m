function [Hhat, noiseVar] = blk2_rx(Y, cfg)
%BLK2_RX  Block 2 - RX (sync + channel estimation).
%   [Hhat, noiseVar] = blk2_rx(Y, cfg)
%
%   Synchronize ONCE on the reference RX, apply the same timing/CFO to all RX,
%   then estimate the channel and noise per RX from the L-LTF.
%
%   INPUTS
%     Y        : complex matrix, L x nRx (from Block 1)
%     cfg      : uses fs, cbw, syncRx, detThreshold, useFineCFO, timingBackoff
%
%   OUTPUTS
%     Hhat     : complex matrix, nActive x nRx (52 x 4 at 20 MHz).
%                Channel estimate per active subcarrier (rows) per RX (columns).
%     noiseVar : row vector, 1 x nRx, noise power per RX [W]
%
%   TO DO
%     - Packet detection on cfg.syncRx
%     - Coarse + fine CFO and symbol timing on cfg.syncRx
%     - Apply the SAME start index and CFO correction to ALL columns
%     - Demodulate L-LTF, estimate channel and noise per RX
%     - NEVER sync each RX separately (it erases the TDoA)
%
%   USEFUL MATLAB
%   wlanPacketDetect, wlanFieldIndices, wlanCoarseCFOEstimate,
%   wlanFineCFOEstimate, frequencyOffset, wlanSymbolTimingEstimate,
%   wlanLLTFDemodulate, wlanLLTFChannelEstimate, wlanLLTFNoiseEstimate
%
%   Owner : ______________      Status : NOT STARTED
%   See docs/TDoA_Team_Work_Split.pdf, Block 2 page.

% ---- YOUR CODE HERE ---------------------------------------------------

error('blk2_rx:notImplemented', 'Block 2 (RX (sync + channel estimation)) is not implemented yet.');

end
