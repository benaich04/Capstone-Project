function [z,R,o] = tdoaValidate(z,R,Rx,refIdx,o)
%TDOAVALIDATE Shared strict interface validation; never repairs covariance silently.
if nargin < 5 || isempty(o), o = tdoaOptions(); end
defaults = tdoaOptions(); names = fieldnames(o);
for k=1:numel(names)
    if ~isfield(defaults,names{k}), error('tdoa:Option','Unknown option: %s',names{k}); end
    defaults.(names{k}) = o.(names{k});
end
o = defaults;
validateattributes(Rx,{'double'},{'real','finite','2d','ncols',2});
N = size(Rx,1);
if N<3, error('tdoa:Geometry','At least three receivers are required.'); end
validateattributes(refIdx,{'numeric'},{'scalar','integer','>=',1,'<=',N});
if size(unique(Rx,'rows'),1)~=N, error('tdoa:Geometry','Receiver positions must be distinct.'); end
s = svd(bsxfun(@minus,Rx,mean(Rx,1)),0);
if s(2)<=1e-10*s(1), error('tdoa:Geometry','Collinear layout has unresolved 2-D mirror ambiguity.'); end
validateattributes(z,{'double'},{'real','vector','numel',N-1}); z=z(:);
if any(isinf(z)), error('tdoa:Measurement','Inf is invalid; use NaN for a missing packet.'); end
validateattributes(R,{'double'},{'real','finite','size',[N-1 N-1]});
if norm(R-R','fro')>1e-10*max(norm(R,'fro'),realmin)
    error('tdoa:Covariance','R must be symmetric.');
end
R=(R+R')/2; [~,bad]=chol(R);
if bad || rcond(R)<1e-12, error('tdoa:Covariance','R must be positive definite and well conditioned.'); end
ints={'maxIterations','maxDampingTrials','gateAfter','maxConsecutiveRejected','minimumPackets'};
for k=1:numel(ints), validateattributes(o.(ints{k}),{'numeric'},{'scalar','integer','positive','finite'}); end
positive={'gradientTolerance','initialDamping','ambiguityCostGap'};
for k=1:numel(positive), validateattributes(o.(positive{k}),{'numeric'},{'scalar','real','finite','positive'}); end
validateattributes(o.minInformationRcond,{'numeric'},{'scalar','>',0,'<',1});
validateattributes(o.gateProbability,{'numeric'},{'scalar','>',0.5,'<',1});
validateattributes(o.covarianceScale,{'numeric'},{'scalar','finite','>=',1});
validateattributes(o.multistart,{'logical'},{'scalar'});
validateattributes(o.enableInnovationGate,{'logical'},{'scalar'});
end
