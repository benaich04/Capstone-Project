function checkIO(name, x, cfg)
%CHECKIO  Check a block output against the interface contract.
%   checkIO(name, x, cfg) errors with a clear message if x has the wrong
%   size/type. Use it at the end of your test so integration never breaks.
%
%   Names: 'Y', 'Hhat', 'noiseVar', 'deltad', 'R', 'Phat', 'Pcov',
%          'Ptrk', 'PtrkCov', 'Ppred'
%
%   Example:  checkIO('deltad', deltad, cfg);

n  = cfg.nRx;
nT = cfg.nTDoA;

switch name
    case 'Y'
        req(isnumeric(x) && ismatrix(x),      'must be a numeric matrix');
        req(size(x,2) == n,                   sprintf('must have %d columns (one per RX), got %d', n, size(x,2)));
        req(size(x,1) > size(x,2),            'rows = samples, columns = receivers (transpose?)');
        req(all(isfinite(x(:))),              'contains NaN/Inf');
    case 'Hhat'
        req(isequal(size(x), [cfg.nActive n]), sprintf('must be %d x %d, got %s', cfg.nActive, n, mat2str(size(x))));
        req(all(isfinite(x(:))),              'contains NaN/Inf');
    case 'noiseVar'
        req(isequal(size(x), [1 n]),          sprintf('must be 1 x %d (row), got %s', n, mat2str(size(x))));
        req(all(x > 0) && isreal(x),          'must be real and > 0');
    case 'deltad'
        req(isequal(size(x), [nT 1]),         sprintf('must be %d x 1 (column), got %s', nT, mat2str(size(x))));
        req(isreal(x) && all(isfinite(x)),    'must be real and finite');
        maxBase = max(vecnorm(cfg.Rx - cfg.Rx(cfg.refIdx,:), 2, 2));
        if any(abs(x) > maxBase + 1e-6)
            warning(['checkIO:' name], ['deltad: some values exceed the receiver ' ...
                'baseline (physically impossible). Check sign / units.']);
        end
    case 'R'
        req(isequal(size(x), [nT nT]),        sprintf('must be %d x %d, got %s', nT, nT, mat2str(size(x))));
        req(isreal(x) && norm(x - x.', 'fro') <= 1e-9*max(1, norm(x,'fro')), 'must be real symmetric');
        req(all(eig((x+x.')/2) > 0),          'must be positive definite');
    case {'Phat', 'Ptrk', 'Ppred'}
        req(isequal(size(x), [2 1]),          sprintf('must be 2 x 1 (column), got %s', mat2str(size(x))));
        req(isreal(x) && all(isfinite(x)),    'must be real and finite');
    case {'Pcov', 'PtrkCov'}
        req(isequal(size(x), [2 2]),          sprintf('must be 2 x 2, got %s', mat2str(size(x))));
        req(isreal(x) && norm(x - x.', 'fro') <= 1e-9*max(1, norm(x,'fro')), 'must be real symmetric');
        req(all(eig((x+x.')/2) >= 0),         'must be positive semi-definite');
    otherwise
        error('checkIO:unknown', 'Unknown interface name "%s".', name);
end

if isfield(cfg, 'verbose') && cfg.verbose
    fprintf('  checkIO: %-9s OK  %s\n', name, mat2str(size(x)));
end

    function req(cond, msg)
        if ~cond
            error(['checkIO:' name], '%s %s', name, msg);
        end
    end
end

