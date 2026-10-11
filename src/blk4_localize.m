function [Phat, Pcov] = blk4_localize(deltad, R, cfg, Pinit)
%BLK4_LOCALIZE  Block 4 - Localization + CRLB.
%   [Phat, Pcov] = blk4_localize(deltad, R, cfg, Pinit)
%
%   Weighted non-linear least squares position estimate and its CRLB.
%
%   INPUTS
%     deltad   : column vector, nTDoA x 1 [m] (from Block 3)
%     R        : symmetric matrix, nTDoA x nTDoA [m^2] (from Block 3)
%     cfg      : uses Rx, refIdx, solver, maxIter, tol, mu, Pinit
%     Pinit    : column vector, 2 x 1 [m], OPTIONAL initial guess (from Block 5).
%                Use cfg.Pinit if missing or empty [].
%
%   OUTPUTS
%     Phat     : column vector, 2 x 1 [m], estimated TX position [x; y]
%     Pcov     : symmetric matrix, 2 x 2 [m^2], CRLB = inv(H' * inv(R) * H)
%
%   TO DO
%     - Reuse solveGradient.m / jacobianH.m from Term 1 (put them in src/)
%     - Weight with inv(R) (general R, not equal noise)
%     - Update crlb.m for general R
%     - Warn if the solver does not converge (never return garbage silently)
%
%   USEFUL MATLAB
%   our gradient solver, eig (ellipse), lsqnonlin (optional cross-check)
%
%   Owner : ______________      Status : NOT STARTED
%   See docs/TDoA_Team_Work_Split.pdf, Block 4 page.

% ---- YOUR CODE HERE ---------------------------------------------------

error('blk4_localize:notImplemented', 'Block 4 (Localization + CRLB) is not implemented yet.');

end
