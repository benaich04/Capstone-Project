function [Y, truth] = blk1_txChannel(cfg)
% Block 1: Generate a Wi-Fi signal and simulate what each receiver gets.
% The signal is affected by distance, delay, path loss, phase, reflections,
% frequency offset and noise.
% All receivers use the same time axis, which we need later for TDoA.
%
% cfg contains the simulation settings.
% Y contains the received signals (one column for each receiver).
% truth stores the actual values so we can check our results in the tests.
% Requires WLAN Toolbox.

% Check that the wall inputs are valid
if ~isempty(cfg.walls)
    if size(cfg.walls, 2) ~= 4
        error('blk1:walls', 'cfg.walls must be K x 4, one row [x1 y1 x2 y2] per wall.');
    end
    wl = hypot(cfg.walls(:,3) - cfg.walls(:,1), cfg.walls(:,4) - cfg.walls(:,2));
    bad = find(~isfinite(wl) | wl < 1e-9, 1);
    if ~isempty(bad)
        error('blk1:walls', 'cfg.walls row %d has zero length or NaN/Inf values.', bad);
    end
end
if cfg.padSamples < 1 || cfg.padSamples ~= round(cfg.padSamples)
    error('blk1:pad', 'cfg.padSamples must be a positive integer.');
end

nRx    = size(cfg.Rx, 1);
P0     = cfg.P0(:);                         % TX position
lambda = cfg.c / cfg.fc;                    % Wavelength
PL_dB  = @(dist) 20*log10(4*pi*dist/lambda);% Free-space path loss

%% 1) Generate the Wi-Fi packet
% We use a non-HT Wi-Fi packet with L-STF, L-LTF, L-SIG and DATA.
% Block 2 will use the training fields for detection and channel estimation.

nht = wlanNonHTConfig('ChannelBandwidth', cfg.cbw, 'PSDULength', cfg.psduLen);
if wlanSampleRate(nht) ~= cfg.fs
    error('blk1:fs', 'cfg.fs = %g Hz must equal the Wi-Fi sample rate %g Hz for %s.', ...
          cfg.fs, wlanSampleRate(nht), cfg.cbw);
end
psdu = randi([0 1], 8*cfg.psduLen, 1);      % Random data bits
tx   = wlanWaveformGenerator(psdu, nht);

% Set the average signal power to our chosen transmit power
Pt_W = 10^((cfg.Pt_dBm - 30)/10);
tx   = tx / sqrt(mean(abs(tx).^2)) * sqrt(Pt_W);

%% 2) Calculate the distances to each receiver
% First calculate the direct distance from the TX to each RX.
% If there is a wall, also check for a possible reflected path.

d       = zeros(nRx, 1);                    % Direct distances
dB      = nan(nRx, 1);                      % Reflected distances
bounceP = nan(2, nRx);                      % Reflection points
blocked = false(nRx, 1);                    % Check if a wall crosses the direct path
for i = 1:nRx
    Ri = cfg.Rx(i, :).';
    d(i) = norm(Ri - P0);
    [dB(i), bounceP(:, i), blocked(i)] = findBounce(P0, Ri, cfg.walls);
end
hasBounce = ~isnan(dB);
if any(blocked)
    warning('blk1:blocked', ['A wall crosses the direct path to RX %s. Walls are modelled ' ...
            'as reflectors only: the direct path is NOT attenuated.'], mat2str(find(blocked).'));
end

%% 3) Add an unknown start time
% In reality the receivers do not know exactly when the TX starts.
% We use one random start time for all receivers.
% We also add zeros before and after the packet to allow for the delays
% without the signal wrapping around when using the FFT.

t0    = rand * cfg.tStartMax;
dMax  = max([d; dB(hasBounce)]);            % Longest path
nLate = ceil((cfg.tStartMax + dMax/cfg.c) * cfg.fs);
x     = [zeros(cfg.padSamples, 1); tx; zeros(cfg.padSamples + nLate, 1)];
L     = numel(x);

%% 4) Simulate the channel for each receiver
% Each receiver gets a delayed and weaker version of the transmitted signal.
% The carrier phase also changes based on the propagation delay.
% If a reflection exists, we add another delayed and weaker copy.

Y   = zeros(L, nRx);
Prx = zeros(nRx, 1);                        % Received power from direct path
phi = 2*pi*rand(1, nRx);                    % Random phase for each RX
if isfield(cfg, 'rxPhaseOn') && ~cfg.rxPhaseOn, phi(:) = 0; end
for i = 1:nRx
    tau = d(i) / cfg.c;
    g   = 10^(-PL_dB(d(i))/20) * exp(-1j*2*pi*cfg.fc*tau);
    yi  = g * fracDelay(x, t0 + tau, cfg.fs);

    if hasBounce(i)
        tauB = dB(i) / cfg.c;
        gB   = 10^(-(PL_dB(dB(i)) + cfg.reflLoss_dB)/20) * exp(-1j*2*pi*cfg.fc*tauB);
        yi   = yi + gB * fracDelay(x, t0 + tauB, cfg.fs);
    end

    Prx(i)  = Pt_W * 10^(-PL_dB(d(i))/10);
    Y(:, i) = yi * exp(1j*phi(i));
end

%% 5) Add frequency offset and noise
% We use the same CFO for all receivers since they share a receiver clock.
% For noise, we calculate the thermal noise power using kTBF.
% MATLAB's randn generates complex Gaussian noise with that power.

cfo = (2*rand - 1) * cfg.cfoMax;
n   = (0:L-1).';
Y   = Y .* exp(1j*2*pi*cfo*n/cfg.fs);

kB = 1.380649e-23;  T0 = 290;
noiseVar = kB*T0*cfg.fs * 10^(cfg.NF_dB/10);
Y = Y + sqrt(noiseVar/2) * (randn(L, nRx) + 1j*randn(L, nRx));

%% 6) Save the true values for testing
% These are the values we know from the simulation.
% We use them to compare with the estimated results in our tests.
% Block 2 only needs Y, not these true values.

others = setdiff(1:nRx, cfg.refIdx);
truth.P0          = P0;
truth.d           = d;
truth.tau         = d / cfg.c;
truth.deltad      = d(others) - d(cfg.refIdx);
truth.t0          = t0;
truth.tArrival    = cfg.padSamples/cfg.fs + t0 + d/cfg.c;
truth.hasBounce   = hasBounce;
truth.blocked     = blocked;
truth.dBounce     = dB;
truth.tArrivalB   = cfg.padSamples/cfg.fs + t0 + dB/cfg.c;
truth.bouncePoint = bounceP;
truth.Prx_dBm     = 10*log10(Prx) + 30;
truth.noiseVar    = noiseVar;
truth.SNR_dB      = 10*log10(Prx / noiseVar);
truth.cfo         = cfo;
truth.phase       = phi(:);
truth.pktStart    = cfg.padSamples + 1;
truth.pktLength   = numel(tx);
truth.x           = x;
end

% ---------------------------------------------------------
function y = fracDelay(x, tau, fs)
% Apply a delay to the signal, including delays smaller than one sample.
% We do this in the frequency domain using the FFT and a phase shift.
% The zero padding helps prevent the delayed packet from wrapping around.
% Small ringing can happen near the packet edges because of interpolation.

L = numel(x);
k = (0:L-1).';
f = (k - L*(k >= ceil(L/2))) * fs/L;
y = ifft(fft(x) .* exp(-1j*2*pi*f*tau));
end

% ---------------------------------------------------------
function [dB, pB, blocked] = findBounce(P, R, walls)
% Find the shortest reflected path from the TX to the RX.
% We use the image method, where the TX is mirrored across the wall.
% If the line from the mirrored TX to the RX crosses the wall segment,
% we have a valid reflection.
% We also check whether a wall crosses the direct TX-RX path.

dB = NaN;  pB = [NaN; NaN];  blocked = false;
cr = @(a, b) a(1)*b(2) - a(2)*b(1);
for w = 1:size(walls, 1)
    A = walls(w, 1:2).';  B = walls(w, 3:4).';
    sP = cr(B - A, P - A);
    sR = cr(B - A, R - A);
    if sP*sR < 0 && cr(R - P, A - P)*cr(R - P, B - P) < 0
        blocked = true;
    end
    if sP*sR <= 0, continue; end

    u   = (B - A) / norm(B - A);
    img = 2*(A + u*(u.'*(P - A))) - P;

    % Find where the line from the image to the RX meets the wall
    M = [R - img, A - B];
    if abs(det(M)) < 1e-12, continue; end
    st = M \ (A - img);
    if all(st >= 0 & st <= 1)
        len = norm(R - img);
        if isnan(dB) || len < dB
            dB = len;
            pB = img + st(1)*(R - img);
        end
    end
end
end
