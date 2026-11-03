function checkIO(block, cfg, varargin)
%CHECKIO Strict runtime interface assertions after each supplied/new block.
% checkIO(1,cfg,Y,truth), checkIO(2,cfg,Hhat,noiseVar),
% checkIO(3,cfg,deltad,R,info3), checkIO(4,cfg,Phat,Pcov,info4),
% checkIO(5,cfg,Ptrk,PtrkCov,Ppred,state).
N = size(cfg.Rx,1);
M = N-1;
switch block
    case 1
        assert(numel(varargin)==2, 'checkIO:ArgumentCount','Block 1 outputs Y, truth.');
        Y=varargin{1}; t=varargin{2};
        assert(isnumeric(Y)&&ismatrix(Y)&&size(Y,2)==N&&size(Y,1)>0, ...
            'checkIO:Block1','Y must be L x nRx numeric.');
        assert(all(isfinite(Y(:))),'checkIO:Block1','Y has NaN or Inf.');
        assert(isstruct(t),'checkIO:Block1','truth must be a struct.');
        if ~isfield(t,'available') || t.available
            assert(isfield(t,'P0')&&isequal(size(t.P0),[2 1]), ...
                'checkIO:Block1','truth.P0 missing or wrong shape.');
            assert(isfield(t,'d')&&isequal(size(t.d),[N 1]), ...
                'checkIO:Block1','truth.d missing or wrong shape.');
        end
    case 2
        assert(numel(varargin)==2, 'checkIO:ArgumentCount','Block 2 outputs Hhat, noiseVar.');
        H=varargin{1}; v=varargin{2};
        assert(isnumeric(H)&&ismatrix(H)&&size(H,2)==N&&size(H,1)>0, ...
            'checkIO:Block2','Hhat must be nAllocated x nRx.');
        assert(all(isfinite(H(:))),'checkIO:Block2','Hhat contains NaN/Inf.');
        assert(isnumeric(v)&&isequal(size(v),[1 N])&&isreal(v) ...
            &&all(isfinite(v))&&all(v>=0), ...
            'checkIO:Block2','noiseVar must be a nonnegative 1 x nRx vector.');
    case 3
        assert(numel(varargin)==3,'checkIO:ArgumentCount','Block 3 outputs deltad, R, info3.');
        z=varargin{1}; R=varargin{2}; info=varargin{3};
        assert(isnumeric(z)&&isequal(size(z),[M 1])&&isreal(z)&&all(isfinite(z)), ...
            'checkIO:Block3','deltad must be finite (nRx-1) x 1, in m.');
        assertCov(R,M,true,'Block3');
        assert(isstruct(info)&&isfield(info,'tauHat') ...
            &&isequal(size(info.tauHat),[N 1]), ...
            'checkIO:Block3','info3.tauHat must be nRx x 1.');
    case 4
        assert(numel(varargin)>=2,'checkIO:ArgumentCount','Block 4 needs Phat, Pcov.');
        p=varargin{1}; C=varargin{2};
        assert(isnumeric(p)&&isequal(size(p),[2 1])&&isreal(p)&&all(isfinite(p)), ...
            'checkIO:Block4','Phat must be a finite real 2 x 1 column (m).');
        assertCov(C,2,false,'Block4');
    case 5
        assert(numel(varargin)==4,'checkIO:ArgumentCount','Block 5 outputs Ptrk, PtrkCov, Ppred, state.');
        p=varargin{1}; C=varargin{2}; pp=varargin{3}; s=varargin{4};
        assert(isnumeric(p)&&isequal(size(p),[2 1])&&isreal(p)&&all(isfinite(p)), ...
            'checkIO:Block5','Ptrk must be a finite real 2 x 1 column.');
        assertCov(C,2,false,'Block5');
        assert(isnumeric(pp)&&isequal(size(pp),[2 1])&&isreal(pp)&&all(isfinite(pp)), ...
            'checkIO:Block5','Ppred must be a finite real 2 x 1 column.');
        assert(isstruct(s),'checkIO:Block5','State output must be a struct.');
    otherwise
        error('checkIO:Block','Unknown block %s.',mat2str(block));
end
end

function assertCov(C,n,strictPD,name)
assert(isnumeric(C)&&isequal(size(C),[n n])&&isreal(C)&&all(isfinite(C(:))), ...
    'checkIO:Covariance','%s covariance must be real finite %d x %d.',name,n,n);
assert(norm(C-C.','fro')<=1e-7*max(norm(C,'fro'),eps), ...
    'checkIO:Covariance','%s covariance is not symmetric.',name);
S=(C+C.')/2;
if strictPD
    [~,p]=chol(S);
    assert(p==0,'checkIO:Covariance','%s covariance must be positive definite.',name);
else
    assert(min(eig(S))>=-1e-7*max(norm(S,'fro'),eps), ...
        'checkIO:Covariance','%s covariance must be positive semidefinite.',name);
end
end
