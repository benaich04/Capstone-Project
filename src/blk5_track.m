function [Ptrk, PtrkCov, Ppred, state] = blk5_track(Phat, Pcov, cfg, state)
%BLK5_TRACK  Block 5 - Tracking.
%   [Ptrk, PtrkCov, Ppred, state] = blk5_track(Phat, Pcov, cfg, state)
%
%   Kalman (or particle) filter over successive positions. Called once per packet.
%
%   INPUTS
%     Phat     : column vector, 2 x 1 [m] (from Block 4)
%     Pcov     : symmetric matrix, 2 x 2 [m^2] (from Block 4)
%     cfg      : uses trackMethod, dt, sigmaAcc, nParticles
%     state    : struct with the filter memory. Pass [] on the first call.
%
%   OUTPUTS
%     Ptrk     : column vector, 2 x 1 [m], smoothed position
%     PtrkCov  : symmetric matrix, 2 x 2 [m^2], smoothed covariance
%     Ppred    : column vector, 2 x 1 [m], predicted next position
%                (goes back to Block 4 as Pinit)
%     state    : updated filter memory (pass back in next call)
%
%   TO DO
%     - State = [x; y; vx; vy], constant-velocity model
%     - Measurement = Phat, measurement noise = Pcov
%     - Predict + update each call; initialize from first Phat
%     - Optional: particle filter version and compare
%
%   USEFUL MATLAB
%   own Kalman filter, or trackingKF / trackingPF (Sensor Fusion Toolbox)
%
%   Owner : ______________      Status : NOT STARTED
%   See docs/TDoA_Team_Work_Split.pdf, Block 5 page.

% ---- YOUR CODE HERE ---------------------------------------------------

error('blk5_track:notImplemented', 'Block 5 (Tracking) is not implemented yet.');

end
