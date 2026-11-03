function [Phat, Pcov, info4] = blk4_localize(deltad, R, cfg, Pinit)
%BLK4_LOCALIZE  Block 4 - Localization + CRLB.
%   [Phat, Pcov]        = blk4_localize(deltad, R, cfg, Pinit)
%   [Phat, Pcov, info4] = blk4_localize(...)          % + diagnostics
%
%   Weighted non-linear least squares (WNLS) position estimate, solved with
%   Levenberg-Marquardt, plus its Cramer-Rao lower bound (CRLB).
%   Works for any number of receivers N_rx >= 3 (no hard-coded sizes).
%
%   INPUTS
%     deltad : column vector, N_TDoA x 1 [m], N_TDoA = N_rx - 1 (from Block 3)
%              deltad(k) = d(others(k)) - d(refIdx), others = all RX except ref
%     R      : symmetric matrix, N_TDoA x N_TDoA [m^2], covariance of deltad
%     cfg    : uses Rx, refIdx, solver, maxIter, tol, mu, Pinit,
%              chi2Alpha, rejectOutlier, gridN, gridStarts, areaMargin
%     Pinit  : column vector, 2 x 1 [m], OPTIONAL initial guess (from Tracking).
%              Missing or [] -> cfg.Pinit (RX centre).
%
%   OUTPUTS
%     Phat   : column vector, 2 x 1 [m], estimated TX position [x; y]
%     Pcov   : symmetric matrix, 2 x 2 [m^2], CRLB = inv(H' * inv(R) * H)
%     info4  : struct (debug): converged, iterations, cost, chi2Pass,
%              ambiguous, rejectedRx, nUsed, method, start, Rregularized,
%              warnings
%
%   STEPS
%     1. Check inputs (sizes from cfg, no NaN, R symmetric positive definite).
%     2. Whiten with chol(R): cost = (deltad - h(P))' inv(R) (deltad - h(P)).
%     3. Several starts: closed-form, Pinit, RX centre, best grid points.
%     4. Levenberg-Marquardt from each start; keep the lowest cost.
%     5. Ambiguity check: two different positions that fit equally well.
%     6. Consistency (chi-square) check; with N_rx >= 5, find and drop one
%        corrupted TDoA (e.g. NLoS / multipath).
%     7. CRLB at the final position.
%
%   cfg.solver : 'lm' (recommended) | 'gradient' (Term 1) | 'lsqnonlin'
%
%   Owner : Mohamed Benaich      Status : IMPLEMENTED
%   See docs/TDoA_Team_Work_Split.pdf, Block 4 page.

% =========================================================================
% 0. Settings (all sizes come from cfg)
% =========================================================================
Rx     = cfg.Rx;
nRx    = size(Rx, 1);
ref    = getf(cfg, 'refIdx', 1);
others = setdiff(1:nRx, ref);
nT     = numel(others);

opt.solver  = lower(getf(cfg, 'solver',     'lm'));
opt.maxIter = getf(cfg, 'maxIter',    500);
opt.tol     = getf(cfg, 'tol',        1e-6);
opt.mu      = getf(cfg, 'mu',         1);
opt.gridN   = getf(cfg, 'gridN',      41);    % grid points per axis
opt.gridK   = getf(cfg, 'gridStarts', 4);     % distinct grid minima used as starts
opt.margin  = getf(cfg, 'areaMargin', 0.5);   % search area = RX box +/- 50%
alpha       = getf(cfg, 'chi2Alpha',  1e-3);  % false-alarm rate of consistency test
doReject    = getf(cfg, 'rejectOutlier', true);

warns = {};

% =========================================================================
% 1. Check inputs
% =========================================================================
if nRx < 3
    error('blk4_localize:tooFewRx', '2D TDoA needs at least 3 receivers (cfg.Rx has %d).', nRx);
end

% --- deltad ---
if isrow(deltad) && numel(deltad) == nT
    deltad = deltad(:);
    warns = addWarn(warns, 'rowInput', 'deltad was a row vector; transposed to a column.');
end
if ~isequal(size(deltad), [nT 1])
    error('blk4_localize:badInput', 'deltad must be %d x 1 (N_rx - 1), got %s.', nT, mat2str(size(deltad)));
end
if ~isreal(deltad) || any(~isfinite(deltad))
    error('blk4_localize:badInput', 'deltad must be real and finite (no NaN/Inf).');
end
baseline = vecnorm(Rx(others,:) - Rx(ref,:), 2, 2);   % |TDoA| can never exceed this
if any(abs(deltad) > baseline)
    warns = addWarn(warns, 'impossibleTDoA', ...
        'Some |deltad| exceed the receiver spacing (physically impossible). Check Block 3 sign/units.');
end

% --- R ---
if ~isequal(size(R), [nT nT])
    error('blk4_localize:badInput', 'R must be %d x %d, got %s.', nT, nT, mat2str(size(R)));
end
if ~isreal(R) || any(~isfinite(R(:)))
    error('blk4_localize:badInput', 'R must be real and finite (no NaN/Inf).');
end
R = (R + R.') / 2;
[~, Rreg, R] = safeChol(R);
if Rreg
    warns = addWarn(warns, 'Rregularized', 'R was not positive definite; added a small value to its diagonal.');
end

% --- Pinit ---
if nargin < 4 || isempty(Pinit)
    Pinit = getf(cfg, 'Pinit', mean(Rx, 1).');
end
Pinit = Pinit(:);
if numel(Pinit) ~= 2 || any(~isfinite(Pinit))
    warns = addWarn(warns, 'badPinit', 'Pinit invalid; using RX centre instead.');
    Pinit = mean(Rx, 1).';
end

% =========================================================================
% 2-4. Fit with all TDoAs (multi-start)
% =========================================================================
starts = {Pinit, mean(Rx, 1).'};  names = {'Pinit', 'RX centre'};
fit = fitTDoA(deltad, R, Rx, ref, others, starts, names, opt);
if isempty(fit.P)
    error('blk4_localize:allFailed', 'All solver runs failed (no finite solution).');
end
used     = 1:nT;                      % TDoAs used in the final solution
rejected = [];

% =========================================================================
% 5. Ambiguity check (two positions fit equally well, e.g. 3 RX outside hull)
% =========================================================================
PcovFull  = crlbAt(fit.P, fit.L, Rx, ref, others);
ambiguous = isAmbiguous(fit, PcovFull);
if ambiguous
    warns = addWarn(warns, 'ambiguous', ...
        'Two different positions fit the TDoAs equally well. Add receivers or use tracking (Pinit).');
end

% =========================================================================
% 6. Consistency (chi-square) check + optional outlier rejection
% =========================================================================
[chi2Pass, chi2Thresh] = chi2Test(fit.cost, nT, alpha);
if ~chi2Pass
    if doReject && nT - 1 >= 3                       % need spare TDoA after dropping one
        bestK = [];  bestFit = [];
        for k = 1:nT
            idx = setdiff(1:nT, k);
            fk  = fitTDoA(deltad(idx), R(idx,idx), Rx, ref, others(idx), ...
                          {fit.P}, {'full solution'}, opt);
            if ~isempty(fk.P) && (isempty(bestFit) || fk.cost < bestFit.cost)
                bestFit = fk;  bestK = k;
            end
        end
        passK = ~isempty(bestFit) && chi2Test(bestFit.cost, nT - 1, alpha);
        if passK
            fit      = bestFit;
            used     = setdiff(1:nT, bestK);
            rejected = others(bestK);
            chi2Pass = true;
            warns = addWarn(warns, 'outlierRejected', ...
                sprintf('TDoA of RX%d was inconsistent (NLoS?) and was dropped.', rejected));
        else
            warns = addWarn(warns, 'inconsistent', ...
                'TDoAs do not agree and no single bad TDoA explains it. Result unreliable.');
        end
    else
        warns = addWarn(warns, 'inconsistent', sprintf(['TDoAs do not agree (cost %.1f > %.1f). ' ...
            'One may be corrupted (NLoS). Need N_rx >= 5 to identify which.'], fit.cost, chi2Thresh));
    end
end

if ~fit.conv
    warns = addWarn(warns, 'notConverged', ...
        sprintf('Solver did not converge in %d iterations (best start: %s).', opt.maxIter, fit.start));
end
Phat = fit.P;

% =========================================================================
% 7. CRLB at the final position (with the TDoAs actually used)
% =========================================================================
[Pcov, badGeom] = crlbAt(Phat, fit.L, Rx, ref, others(used));
if badGeom
    warns = addWarn(warns, 'badGeometry', 'Geometry is nearly singular here (CRLB huge). Position unreliable.');
end

[lo, hi] = searchBox(Rx, opt.margin);
if any(Phat < lo - (hi - lo)) || any(Phat > hi + (hi - lo))
    warns = addWarn(warns, 'farAway', 'Estimate is far outside the receiver area.');
end

info4 = struct('converged', fit.conv, 'iterations', fit.iter, 'cost', fit.cost, ...
               'chi2Pass', chi2Pass, 'chi2Thresh', chi2Thresh, 'ambiguous', ambiguous, ...
               'rejectedRx', rejected, 'nUsed', numel(used), 'method', opt.solver, ...
               'start', fit.start, 'Rregularized', Rreg, 'warnings', {warns});
end

% =========================================================================
% =========================== LOCAL FUNCTIONS =============================
% =========================================================================

function fit = fitTDoA(deltad, R, Rx, ref, others, starts, names, opt)
% Multi-start weighted fit. Returns best solution + every run (for ambiguity).
L = safeChol(R);

Pcf = closedForm(deltad, R, Rx, ref, others);
if ~isempty(Pcf), starts = [{Pcf} starts]; names = [{'closed-form'} names]; end

[lo, hi] = searchBox(Rx, opt.margin);
G = gridStarts(deltad, L, Rx, ref, others, lo, hi, opt.gridN, opt.gridK);
for g = 1:size(G, 2), starts{end+1} = G(:, g); names{end+1} = 'grid'; end %#ok<AGROW>

nS  = numel(starts);
allP = nan(2, nS);  allC = inf(1, nS);
fit = struct('P', [], 'cost', inf, 'conv', false, 'iter', 0, 'start', '', ...
             'L', L, 'allP', [], 'allC', []);
for s = 1:nS
    switch opt.solver
        case 'lm',        [P, c, cv, it] = solveLM(starts{s}, deltad, L, Rx, ref, others, opt);
        case 'gradient',  [P, c, cv, it] = solveGrad(starts{s}, deltad, L, Rx, ref, others, opt);
        case 'lsqnonlin', [P, c, cv, it] = solveLsq(starts{s}, deltad, L, Rx, ref, others, opt);
        otherwise
            error('blk4_localize:badSolver', 'Unknown cfg.solver "%s" (lm | gradient | lsqnonlin).', opt.solver);
    end
    if all(isfinite(P)) && isfinite(c)
        allP(:, s) = P;  allC(s) = c;
        if c < fit.cost
            fit.P = P; fit.cost = c; fit.conv = cv; fit.iter = it; fit.start = names{s};
        end
    end
end
fit.allP = allP;  fit.allC = allC;
end

function h = hModel(P, Rx, ref, others)
% Predicted TDoAs [m] at position P.
d = vecnorm(Rx - P.', 2, 2);
h = d(others) - d(ref);
end

function J = jacobianModel(P, Rx, ref, others)
% dh/dP, size N_TDoA x 2. Safe when P sits exactly on a receiver.
D = P.' - Rx;
d = max(vecnorm(D, 2, 2), 1e-9);
U = D ./ d;                                          % unit vectors RX -> P
J = U(others, :) - U(ref, :);
end

function P = closedForm(deltad, R, Rx, ref, others)
% Linear solution in [x; y; d_ref] (spherical intersection). [] if singular.
r0 = Rx(ref, :);
A  = [2*(Rx(others,:) - r0), 2*deltad];
b  = sum(Rx(others,:).^2, 2) - sum(r0.^2) - deltad.^2;
if size(A, 1) < 3 || rank(A) < 3
    P = [];  return;
end
s = (A.' * (R \ A)) \ (A.' * (R \ b));
P = s(1:2);
if any(~isfinite(P)), P = []; end
end

function [lo, hi] = searchBox(Rx, margin)
lo = min(Rx, [], 1).';  hi = max(Rx, [], 1).';
span = max(hi - lo, 1);
lo = lo - margin * span;  hi = hi + margin * span;
end

function G = gridStarts(deltad, L, Rx, ref, others, lo, hi, n, K)
% The K lowest-cost grid points that are far apart (one per valley).
% Vectorized: evaluates the whole grid at once.
[X, Y] = meshgrid(linspace(lo(1), hi(1), n), linspace(lo(2), hi(2), n));
pts = [X(:) Y(:)].';                                 % 2 x M
D   = sqrt((Rx(:,1) - pts(1,:)).^2 + (Rx(:,2) - pts(2,:)).^2);   % N_rx x M
res = L \ (deltad - (D(others,:) - D(ref,:)));      % whitened residuals
c   = sum(res.^2, 1);
[~, order] = sort(c);
minSep = 0.3 * max(hi - lo);
G = zeros(2, 0);
for i = order
    if isempty(G) || all(vecnorm(G - pts(:, i), 2, 1) > minSep)
        G(:, end+1) = pts(:, i); %#ok<AGROW>
        if size(G, 2) == K, break; end
    end
end
end

function [P, cost, conv, it] = solveLM(P, deltad, L, Rx, ref, others, opt)
% Levenberg-Marquardt on the whitened problem. Only accepts improving steps.
lambda = 1e-3;
r    = L \ (deltad - hModel(P, Rx, ref, others));
cost = r.' * r;
conv = false;  it = 0;
for it = 1:opt.maxIter
    J = L \ jacobianModel(P, Rx, ref, others);
    A = J.' * J;  g = J.' * r;
    accepted = false;
    while lambda < 1e12
        step = (A + lambda * diag(diag(A) + 1e-12)) \ g;
        rnew = L \ (deltad - hModel(P + step, Rx, ref, others));
        cnew = rnew.' * rnew;
        if cnew < cost
            P = P + step;  r = rnew;  cost = cnew;
            lambda = max(lambda / 3, 1e-12);
            accepted = true;  break;
        end
        lambda = lambda * 4;
    end
    if ~accepted || norm(step) < opt.tol || cost < 1e-24
        conv = true;  return;
    end
end
end

function [P, cost, conv, it] = solveGrad(P, deltad, L, Rx, ref, others, opt)
% Term 1 normalized gradient, with backtracking so the cost never increases.
r    = L \ (deltad - hModel(P, Rx, ref, others));
cost = r.' * r;
conv = false;  it = 0;
for it = 1:opt.maxIter
    J    = L \ jacobianModel(P, Rx, ref, others);
    step = opt.mu * (J.' * r) / max(trace(J.' * J), eps);
    a = 1;  accepted = false;
    for k = 1:30
        rnew = L \ (deltad - hModel(P + a*step, Rx, ref, others));
        cnew = rnew.' * rnew;
        if cnew < cost, accepted = true; break; end
        a = a / 2;
    end
    if ~accepted, conv = true; return; end
    P = P + a*step;  r = rnew;  cost = cnew;
    if norm(a*step) < opt.tol, conv = true; return; end
end
end

function [P, cost, conv, it] = solveLsq(P, deltad, L, Rx, ref, others, opt)
% Cross-check with lsqnonlin (Optimization Toolbox).
if exist('lsqnonlin', 'file') ~= 2
    error('blk4_localize:noToolbox', 'lsqnonlin needs the Optimization Toolbox. Use cfg.solver = ''lm''.');
end
fun  = @(P) L \ (deltad - hModel(P, Rx, ref, others));
o    = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', opt.maxIter, ...
                    'StepTolerance', opt.tol, 'FunctionTolerance', 1e-14);
[P, cost, ~, flag, out] = lsqnonlin(fun, P, [], [], o);
conv = flag > 0;  it = out.iterations;
end

function [Pcov, bad] = crlbAt(P, L, Rx, ref, others)
% CRLB = inv(H' inv(R) H), computed with the whitened Jacobian.
Hw  = L \ jacobianModel(P, Rx, ref, others);
F   = Hw.' * Hw;                                     % Fisher information
bad = rcond(F) < 1e-12;
if bad, Pcov = pinv(F); else, Pcov = F \ eye(2); end
Pcov = (Pcov + Pcov.') / 2;
end

function amb = isAmbiguous(fit, Pcov)
% Another run reached a clearly different position with (almost) the same cost.
rad = max(3 * sqrt(trace(Pcov)), 0.1);               % "different" = outside 3 sigma
ok  = isfinite(fit.allC);
d   = vecnorm(fit.allP(:, ok) - fit.P, 2, 1);
amb = any(d > rad & fit.allC(ok) <= fit.cost + 4);
end

function [pass, thr] = chi2Test(cost, nT, alpha)
% Cost follows chi-square with (N_TDoA - 2) degrees of freedom if TDoAs agree.
dof = nT - 2;
if dof < 1, pass = true; thr = NaN; return; end      % no redundancy -> nothing to test
thr  = 2 * gammaincinv(1 - alpha, dof / 2);          % base MATLAB, no toolbox
pass = cost <= thr;
end

function [L, reg, R] = safeChol(R)
% Cholesky (lower) with automatic regularization if R is not positive definite.
reg = false;
[L, p] = chol(R, 'lower');
bump = 1e-12 * max(trace(R) / size(R, 1), eps);  k = 0;
while p ~= 0 && k < 25
    R = R + bump * eye(size(R));
    [L, p] = chol(R, 'lower');
    bump = bump * 10;  k = k + 1;  reg = true;
end
if p ~= 0
    error('blk4_localize:badR', 'R could not be made positive definite.');
end
end

function warns = addWarn(warns, id, msg)
warning(['blk4_localize:' id], '%s', msg);
warns{end+1} = msg;
end

function v = getf(s, name, default)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name)), v = s.(name); else, v = default; end
end