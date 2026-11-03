function [deltad, R, info3] = blk3_tdoa(Hhat, noiseVar, cfg)
% blk3_tdoa
% block 3 of the localization chain
% takes the channel estimates from block 2, finds when the direct (first) path
% arrived at each receiver and turns the arrival time differences into
% distance differences for block 4
% it also builds R, which tells block 4 how much to trust each distance difference
%
% inputs
%   Hhat      N_allocated x N_rx complex channel estimates, one column per
%             receiver, one row per used subcarrier (lowest k first)
%             20 MHz: 52 x nRx with k = -26..-1, 1..26
%             40 MHz: 104 x nRx, 80 MHz: 208 x nRx (the L-LTF repeats every 20 MHz)
%   noiseVar  1 x nRx noise power of ONE L-LTF symbol per receiver (from block 2)
%   cfg       settings from config.m
%             needs     fs, c, nRx, refIdx, others, zpFactor, interp, pfa,
%                       pfaCellFactor, maxPaths, tauFloorVar
%             optional  firstPathMethod, maxEarly, lowSnr_dB, closeSep,
%                       closeInflate, firstPath_dB (only for 'threshold'),
%                       k and Nfft (subcarrier numbers and fft size, for any
%                       other wifi format, otherwise worked out from fs)
%   nothing about the number of subcarriers or receivers is hard coded,
%   it all comes from cfg and the size of Hhat
%
% outputs
%   deltad    distance differences in m, deltad(i) = d(others(i)) - d(refIdx)
%   R         covariance of deltad in m^2 (the trust matrix)
%   info3     extra results for debugging and plots
%             tauHat       arrival time per receiver in s, measured from block 2's
%                          window so it is not the time of flight (only the
%                          differences mean something)
%             snrHat_dB    snr from the total power (debug only)
%             snrFirst_dB  snr of the first path (this is the one used for R)
%             sigmaTau2    final timing variance per receiver in s^2
%             crbMulti     multipath crlb per receiver (NaN if only one path)
%             lowSnr       true if the first path snr < lowSnr_dB
%             closePath    true if another path is within closeSep
%             pathTau      delays of the paths SIC kept (empty = none)
%             pathAmp      amplitudes of those paths
%             cir          CIR per receiver (peak height = path amplitude)
%
% note for block 4
% R already includes multipath, close paths and low snr, so R^-1 can be used directly and flagged 
% receivers just get a big variance (small weight)
% you can also drop a flagged receiver, but if it is refIdx then every TDoA shares its error
%
% checked with test_blk3.
% owner  Salama Al-Ali 


%% step 0  check the inputs and read the settings

nSub = size(Hhat, 1);      % number of used subcarriers (N_allocated)
nRx  = size(Hhat, 2);      % number of receivers (N_rx)

% which subcarriers the rows are and the fft size, from cfg
[k, Nfft] = subcarrierLayout(cfg);

if nRx ~= cfg.nRx || numel(noiseVar) ~= nRx
    error('blk3_tdoa:InvalidInput', 'Hhat and noiseVar must match cfg.nRx');
end
if any(~isfinite(Hhat(:))) || any(~isfinite(noiseVar(:))) || any(noiseVar < 0)
    error('blk3_tdoa:InvalidInput', 'inputs must be finite and noiseVar must be >= 0');
end
% Hhat needs one row per subcarrier in the layout
if nSub ~= numel(k)
    error('blk3_tdoa:InvalidInput', ...
        'Hhat has %d rows but cfg gives %d subcarriers', nSub, numel(k));
end

% optional settings get a default if they are not in config.m
method       = getSetting(cfg, 'firstPathMethod', 'sic');
maxEarly     = getSetting(cfg, 'maxEarly', 300e-9);   % [s] how far before the strongest path the first one can be
lowSnr_dB    = getSetting(cfg, 'lowSnr_dB', -3);      % [dB] below this outliers start happening
closeSep     = getSetting(cfg, 'closeSep', 1.5/cfg.fs); % [s] paths closer than this are hard to separate (75 ns at 20 MHz)
closeInflate = getSetting(cfg, 'closeInflate', 10);   % variance factor for close paths
tauFloorVar  = cfg.tauFloorVar;                       % [s^2] small floor so R stays invertible

% stop with an error if a setting is wrong instead of quietly doing something else
if ~strcmp(cfg.interp, 'parabola')
    error('blk3_tdoa:BadInterp', 'only cfg.interp = ''parabola'' is implemented');
end
if ~strcmp(method, 'sic') && ~strcmp(method, 'threshold')
    error('blk3_tdoa:BadFirstPathMethod', ...
        'cfg.firstPathMethod has to be ''sic'' or ''threshold'' (got ''%s'')', method);
end


%% step 1  frequency layout

% a delay tau shows up in Hhat as a phase of -2*pi*fk*tau
% so we need the real frequency (in Hz) of every row, not just its number k
% k and Nfft came from subcarrierLayout in step 0 (20 MHz: k = -26..26, Nfft = 64)
fk    = k * cfg.fs / Nfft;           % subcarrier frequencies in Hz (312.5 kHz apart)
sumF2 = sum(fk.^2);                  % frequency spread, used in the crlb

N  = Nfft * cfg.zpFactor;            % size of the zero-padded ifft (1024 at 20 MHz, zpFactor = 16)
dt = 1 / (cfg.fs * cfg.zpFactor);    % time between CIR samples (3.125 ns at 20 MHz)

% empty arrays that the loop fills in, one entry per receiver
cir         = zeros(N, nRx);
tauHat      = zeros(nRx, 1);
snrHat_dB   = zeros(nRx, 1);
snrFirst_dB = zeros(nRx, 1);
crbMulti    = NaN(nRx, 1);           % stays NaN if only one path is found
closePath   = false(nRx, 1);
lowSnr      = false(nRx, 1);
pathTauAll  = cell(nRx, 1);
pathAmpAll  = cell(nRx, 1);


%% steps 2 to 4  one receiver at a time

for r = 1:nRx
    H = Hhat(:, r);                  % the channel values of this receiver

    % noise on each value of Hhat
    % block 2 gives the noise of ONE L-LTF symbol but Hhat is the average of
    % TWO symbols, and averaging two values halves the variance
    sigH2 = noiseVar(r) / 2;

    % step 2  channel impulse response (used for plots and the threshold method)
    cir(:, r) = makeCIR(H, k, Nfft, N);

    % snr from the total power, debug only because reflections add power too
    totalPower   = mean(abs(H).^2);
    signalPower  = max(totalPower - sigH2, 0);
    snrHat_dB(r) = toDb(signalPower, sigH2);

    % step 3  find the first (direct) path
    if strcmp(method, 'sic')
        [tauHat(r), pathTauAll{r}, pathAmpAll{r}, aFirst] = firstPathSIC( ...
            H, sigH2, k, fk, Nfft, N, dt, cfg.pfa, cfg.maxPaths, cfg.pfaCellFactor, maxEarly);
    else
        [tauHat(r), aFirst] = firstPathThreshold(H, k, fk, Nfft, N, dt, cfg.firstPath_dB);
    end

    % step 4  how much can we trust this receiver (the quality inspector)
    % snr of the path we actually timed
    % aFirst is an average of nSub values (52 at 20 MHz) so it has noise
    % power sigH2/nSub in it, which we take out
    firstPower     = max(abs(aFirst)^2 - sigH2/nSub, 0);
    snrFirst_dB(r) = toDb(firstPower, sigH2);

    % if SIC found more than one path, the others make the first one harder
    % to time, so we also work out the multipath crlb
    tauPaths = pathTauAll{r};
    if strcmp(method, 'sic') && numel(tauPaths) > 1 && sigH2 > 0
        [~, jF] = min(tauPaths);                       % which one is the first path
        crbMulti(r) = multipathCRB(tauPaths, pathAmpAll{r}, fk, sigH2, jF);
        if ~isfinite(crbMulti(r))
            crbMulti(r) = maxEarly^2/12;               % the paths can't be separated at all
        end

        % is another path closer than closeSep (near the 20 MHz limit)?
        sepOthers = abs(tauPaths - tauPaths(jF));      % distance of every path from the first one
        sepOthers(jF) = [];                            % don't compare the first path with itself
        closePath(r) = any(sepOthers < closeSep);
    end

    % low snr flag, below this the estimate sometimes jumps to a wrong peak
    lowSnr(r) = snrFirst_dB(r) < lowSnr_dB;
end


%% step 5  TDoA as distance differences

% the unknown send time and block 2's 400 ns offset are the same for every
% receiver, so they cancel when we subtract
others = cfg.others(:);
tauRef = tauHat(cfg.refIdx);
deltad = cfg.c * (tauHat(others) - tauRef);


%% step 6  timing variance of each receiver, then R

% (a) single path crlb   sigma^2 = 1 / (8*pi^2 * SNR * sum(fk^2))
%     the snr has to be linear here, not dB
%     no noise gives Inf snr, we use realmax instead so the result is 0 and
%     the floor takes over
snrLinear = 10.^(snrFirst_dB/10);
snrLinear(~isfinite(snrLinear)) = realmax;
sigmaTau2 = 1 ./ (8*pi^2 * snrLinear * sumF2) + tauFloorVar;

% (b) multipath: never reduce the uncertainty, the bigger value wins
useMulti = isfinite(crbMulti);
sigmaTau2(useMulti) = max(sigmaTau2(useMulti), crbMulti(useMulti) + tauFloorVar);

% (c) paths too close to separate, inflate (factor measured in test_blk3)
sigmaTau2(closePath) = sigmaTau2(closePath) * closeInflate;

% (d) low snr, an outlier can land anywhere in the maxEarly window
%     the variance of a uniform error over a width W is W^2/12
sigmaTau2(lowSnr) = sigmaTau2(lowSnr) + maxEarly^2/12;

% R: every TDoA uses RX1, so they all share RX1's error (off-diagonal terms)
% and the diagonal also has each receiver's own error
%   var(e_i - e_1)            = sigma_i^2 + sigma_1^2
%   cov(e_i - e_1, e_j - e_1) = sigma_1^2
% times c^2 to go from s^2 to m^2
nTDoA     = numel(others);
sharedVar = cfg.c^2 * sigmaTau2(cfg.refIdx);      % RX1's error, in every entry
R = zeros(nTDoA);
for i = 1:nTDoA
    for j = 1:nTDoA
        R(i, j) = sharedVar;
        if i == j
            R(i, j) = R(i, j) + cfg.c^2 * sigmaTau2(others(i));   % own error on the diagonal
        end
    end
end


%% step 7  extra results for debugging and plots

info3.tauHat      = tauHat;
info3.snrHat_dB   = snrHat_dB;
info3.snrFirst_dB = snrFirst_dB;
info3.sigmaTau2   = sigmaTau2;
info3.crbMulti    = crbMulti;
info3.lowSnr      = lowSnr;
info3.closePath   = closePath;
info3.pathTau     = pathTauAll;
info3.pathAmp     = pathAmpAll;
info3.cir         = cir;
end



%% helper functions


function value = getSetting(cfg, name, default)
% use cfg.(name) if it is there, otherwise the default
if isfield(cfg, name)
    value = cfg.(name);
else
    value = default;
end
end


function db = toDb(signalPower, noisePower)
% snr in dB, no noise gives Inf
% eps stops log10(0) = -Inf when the signal power comes out as 0
if noisePower > 0
    db = 10*log10(max(signalPower / noisePower, eps));
else
    db = Inf;
end
end


function [k, Nfft] = subcarrierLayout(cfg)
% subcarrier numbers k (lowest first) and fft size of the channel estimate
% if config.m gives cfg.k and cfg.Nfft we just use those, so any wifi
% format works
% otherwise we work them out from the sample rate for the L-LTF:
% every 20 MHz piece has 64 fft bins and uses subcarriers -26..-1, 1..26,
% and wider channels repeat that piece every 64 bins
if isfield(cfg, 'k') && isfield(cfg, 'Nfft')
    k    = cfg.k(:);
    Nfft = cfg.Nfft;
    return
end
nSeg = round(cfg.fs / 20e6);                  % number of 20 MHz pieces
if ~any(nSeg == [1 2 4 8]) || abs(cfg.fs - nSeg*20e6) > 1
    error('blk3_tdoa:BadLayout', ...
        'cfg.fs = %g Hz is not 20/40/80/160 MHz, give cfg.k and cfg.Nfft instead', cfg.fs);
end
Nfft = 64 * nSeg;
base = [-26:-1 1:26].';                       % one 20 MHz piece
k = zeros(52*nSeg, 1);
for s = 1:nSeg
    offset = 64*(s-1) - 32*(nSeg-1);          % centre of piece s
    k((s-1)*52+1 : s*52) = base + offset;
end
end


function c = makeCIR(H, k, Nfft, N)
% zero-padded channel impulse response of one receiver
% the ifft asks: at what time delay do all these frequency measurements line up
%   1. put the values in an Nfft bin fft grid (52 values in 64 bins at 20 MHz)
%      matlab can't use negative indices and the fft keeps the negative
%      frequencies at the END of the array, so subcarrier k goes to
%      index mod(k,Nfft)+1 (k = -1 goes to Nfft)
%   2. fftshift moves DC to the middle so the zeros can go evenly on both
%      outer edges (zero padding), the measured bins keep their spacing
%   3. ifftshift puts the order back the way ifft wants it, then ifft
%   4. ifft divides by N, so we multiply by N/(number of subcarriers) so that
%      a path of amplitude a gives a peak of height |a| (needed to compare
%      peaks with the threshold)
Hgrid = zeros(Nfft, 1);
Hgrid(mod(k, Nfft) + 1) = H;                  % step 1

Hpad = zeros(N, 1);
startIdx = floor((N - Nfft)/2) + 1;           % where the Nfft bins start in the big array
Hpad(startIdx:startIdx+Nfft-1) = fftshift(Hgrid);   % step 2

c = ifft(ifftshift(Hpad)) * (N / numel(H));   % steps 3 and 4
end


function n = toSignedIndex(idx, N)
% turns a matlab index (1..N) of the circular CIR into a signed sample number
% the second half of the array is NEGATIVE delay, for N = 8 the
% indices 1..8 mean 0 1 2 3 -4 -3 -2 -1 (works on vectors too)
n = idx - 1;
secondHalf = (n >= N/2);
n(secondHalf) = n(secondHalf) - N;
end


function off = parabolaOffset(mag, idx, N)
% the peak is like the top of a hill but we only know the height at fixed
% points, so we fit a parabola through the peak sample and its two
% neighbours and return how far (in samples) its top is from idx
% the neighbours wrap around because the CIR is circular
y1 = mag(mod(idx - 2, N) + 1);        % left neighbour
y2 = mag(idx);                        % the peak sample
y3 = mag(mod(idx, N) + 1);            % right neighbour
d  = y1 - 2*y2 + y3;
off = 0;
if abs(d) > eps                       % flat top, keep off = 0 so we don't divide by 0
    off = 0.5*(y1 - y3)/d;
    off = min(off, 0.5);              % the top can't be more than half a sample away
    off = max(off, -0.5);
end
end


function a = pathAmplitude(H, fk, tau)
% complex amplitude of a path at delay tau
% multiplying by exp(+j2*pi*fk*tau) (positive sign) undoes the rotation the
% delay caused, so all the arrows line up, then the mean averages the noise out
a = mean(H .* exp(1j*2*pi*fk*tau));
end


function Hm = pathModel(fk, tauList, ampList)
% rebuilds the paths we found, each one is a*exp(-j*2*pi*fk*tau)
% the matrix has one column per path, multiplying by the amplitudes adds
% the paths up (same as a loop over the paths)
if isempty(tauList)
    Hm = zeros(numel(fk), 1);                      % nothing found yet
    return
end
pathMatrix = exp(-1j*2*pi*fk*tauList(:).');        % subcarriers x number of paths
Hm = pathMatrix * ampList(:);
end


function [tauFirst, aFirst] = firstPathThreshold(H, k, fk, Nfft, N, dt, firstPath_dB)
% OLD first path method, only kept to compare against
% takes the earliest local peak that is within firstPath_dB of the strongest peak
mag = abs(makeCIR(H, k, Nfft, N));
threshold = max(mag) * 10^(firstPath_dB/20);

% local peaks: higher than the left neighbour and at least as high as the
% right one (circshift handles the wrap around of the circular CIR)
leftNb  = circshift(mag, 1);
rightNb = circshift(mag, -1);
isPeak  = (mag > leftNb) & (mag >= rightNb);
peaks   = find(isPeak & mag >= threshold);

if isempty(peaks)
    [~, firstIdx] = max(mag);                       % fallback, the strongest peak
else
    [~, e] = min(toSignedIndex(peaks, N));          % earliest signed position
    firstIdx = peaks(e);
end

tauFirst = (toSignedIndex(firstIdx, N) + parabolaOffset(mag, firstIdx, N)) * dt;
aFirst   = pathAmplitude(H, fk, tauFirst);
end


function [tauFirst, pathTau, pathAmp, aFirst] = firstPathSIC(H, sigH2, k, fk, Nfft, N, dt, ...
    pfa, maxPaths, cellFactor, maxEarly)
% first path with successive interference cancellation (SIC)
% (Bomfin & Chafii, Algorithm 1)
%   find the strongest path, subtract it so its sidelobes go too,
%   fix all the paths found so far, repeat until only noise is left,
%   then take the earliest real path
% basically remove what you already found so it doesn't hide the other paths
nSub = numel(H);

% noise threshold from the false alarm probability
% one CIR sample averages nSub noisy values, so its noise variance is sigH2/nSub
% and |noise| is rayleigh: P(|n| > T) = exp(-T^2/(sigH2/nSub))
% with about cellFactor*nSub chances per CIR, P(false path) = pfa
% cellFactor = 3.5 was measured in test_blk3 (section 6) for 20 MHz and
% zpFactor 16, rerun that test for any other setup
T = sqrt(sigH2/nSub * log(cellFactor*nSub/pfa));
T = max(T, 1e-3 * max(abs(makeCIR(H, k, Nfft, N))));     % only matters with no noise (tiny leftovers)

pathTau = [];            % delays of the paths found so far
pathAmp = [];            % and their amplitudes
for p = 1:maxPaths
    resid = H - pathModel(fk, pathTau, pathAmp);   % what isn't explained yet
    mag = abs(makeCIR(resid, k, Nfft, N));
    [peak, i] = max(mag);
    if peak < T
        break;                                     % only noise left
    end
    t = (toSignedIndex(i, N) + parabolaOffset(mag, i, N)) * dt;
    pathTau(end+1) = t;
    pathAmp(end+1) = pathAmplitude(resid, fk, t);
    [pathTau, pathAmp] = refinePaths(H, k, fk, Nfft, N, dt, pathTau, pathAmp);
end

% keep paths that are still above the threshold
keep = abs(pathAmp) >= T;

% and not more than maxEarly before the strongest one
% (a noise spike far away is not a direct path)
if any(keep)
    keptAmp = abs(pathAmp);
    keptAmp(~keep) = 0;                            % ignore the ones we already dropped
    [~, iStrong] = max(keptAmp);
    keep = keep & (pathTau >= pathTau(iStrong) - maxEarly);
end

if any(keep)
    pathTau = pathTau(keep);
    pathAmp = pathAmp(keep);
    [tauFirst, jFirst] = min(pathTau);             % earliest path we kept
    aFirst = pathAmp(jFirst);
else
    % nothing passed, so fall back to the strongest peak and return empty lists
    mag = abs(makeCIR(H, k, Nfft, N));
    [~, i] = max(mag);
    tauFirst = (toSignedIndex(i, N) + parabolaOffset(mag, i, N)) * dt;
    aFirst = pathAmplitude(H, fk, tauFirst);
    pathTau = [];
    pathAmp = [];
end
end


function [tauList, ampList] = refinePaths(H, k, fk, Nfft, N, dt, tauList, ampList)
% re-estimate each path with all the OTHER paths subtracted
% without this a slightly wrong first estimate leaves a small leftover peak
% that looks like a fake ("ghost") path
% 5 passes is our choice, the estimates settle within a few
nP = numel(tauList);
halfWin = round(N / Nfft / 2);                     % half of one original sample (8 for zpFactor 16)
for pass = 1:5
    for q = 1:nP
        others = [1:q-1, q+1:nP];                  % every path except q
        resid = H - pathModel(fk, tauList(others), ampList(others));
        mag = abs(makeCIR(resid, k, Nfft, N));

        % only search +/- halfWin samples (half of one original sample,
        % +/- 25 ns at 20 MHz) around the current estimate, so it can't
        % jump to another path
        c0  = mod(round(tauList(q)/dt), N) + 1;    % current estimate as a CIR index
        win = mod(c0 - 1 + (-halfWin:halfWin), N) + 1;   % the indices around it
        [~, j] = max(mag(win));
        iq = win(j);

        tauList(q) = (toSignedIndex(iq, N) + parabolaOffset(mag, iq, N)) * dt;
        ampList(q) = pathAmplitude(resid, fk, tauList(q));
    end
end
end


function crb = multipathCRB(tauList, ampList, fk, sigH2, jFirst)
% crlb of the first path's delay when ALL the paths are unknown
% (delay, Re(a) and Im(a) for every path)
% same fisher information idea as the single path crlb:
%   J = (2/sigH2) * Re(D' * D), where D holds the model derivatives
% delays are scaled by Ts = 1/max|fk| inside, otherwise J has entries about
% 1e16 apart and matlab thinks it is singular, we convert back at the end
Ts = 1 / max(abs(fk));
nP = numel(tauList);
D  = zeros(numel(fk), 3*nP);
for p = 1:nP
    e = exp(-1j*2*pi*fk*tauList(p));
    D(:, 3*p-2) = -1j*2*pi*(fk*Ts) .* ampList(p) .* e;   % d/d(tau/Ts)
    D(:, 3*p-1) = e;                                     % d/d Re(a)
    D(:, 3*p)   = 1j*e;                                  % d/d Im(a)
end
J = (2/sigH2) * real(D' * D);
if rcond(J) < 1e-12
    crb = Inf;                                           % the paths can't be separated
    return
end
Jinv = J \ eye(3*nP);
crb  = Jinv(3*jFirst-2, 3*jFirst-2) * Ts^2;              % back to s^2
end
