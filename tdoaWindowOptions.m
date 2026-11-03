function w = tdoaWindowOptions()
%TDOAWINDOWOPTIONS Finite memory in packet slots, not waveform samples.
w.length = 30;             % Provisional value; select with held-out experiments.
w.decay = 1;               % 1: uniform; (0,1): exponential age weights.
end
