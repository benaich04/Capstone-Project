function [out,state] = tdoaWindowStep(z,R,Rx,refIdx,packetId,state,options,window)
%TDOAWINDOWSTEP Finite-window stationary localization, independent of legacy fusion.
% IDs count capture slots (including dropped slots). Old data expire on EVERY call.
% No old-position innovation gate: changes can enter and trigger mismatch instead
% of being permanently rejected. Physical bounds and solver checks remain active.
% Optional decay uses sandwich mean covariance, not inverse weighted information.
% Assumes independent packets and one fixed position within the window.
if nargin<6, state=[]; end
if nargin<7, options=[]; end
if nargin<8 || isempty(window), window=tdoaWindowOptions(); end
[z,R,o]=tdoaValidate(z,R,Rx,refIdx,options);
validateattributes(packetId,{'double'},{'scalar','finite','integer','nonnegative','<=',flintmax});
w=tdoaWindowOptions(); names=fieldnames(window);
for j=1:numel(names)
    if ~isfield(w,names{j}), error('tdoa:WindowOption','Unknown window option.'); end
    w.(names{j})=window.(names{j});
end
validateattributes(w.length,{'numeric'},{'scalar','integer','>=',o.minimumPackets,'finite'});
validateattributes(w.decay,{'numeric'},{'scalar','real','finite','>',0,'<=',1});
if w.decay^(w.length-1)<1e-12, error('tdoa:WindowWeights','Decay underflows over this window.'); end
K=numel(z); R=o.covarianceScale*R;
if isempty(state)
    state=struct('version',12,'Rx',Rx,'refIdx',refIdx,'options',o,'window',w, ...
        'lastPacketId',-1,'ids',zeros(1,0),'Z',zeros(K,0),'RR',zeros(K,K,0), ...
        'nAccepted',0,'nRejected',0,'nMissing',0);
elseif ~isstruct(state) || ~isfield(state,'version') || state.version~=12
    error('tdoa:State','Use empty state for the window estimator.');
elseif ~isequal(state.Rx,Rx) || state.refIdx~=refIdx || ~isequal(state.options,o) || ~isequal(state.window,w)
    error('tdoa:StateChange','Reset state when geometry, reference or settings change.');
end
if packetId<=state.lastPacketId, error('tdoa:PacketOrder','Duplicate/out-of-order packet ID.'); end
state.lastPacketId=packetId;
keep=state.ids>=packetId-w.length+1;
state.ids=state.ids(keep); state.Z=state.Z(:,keep); state.RR=state.RR(:,:,keep);
out=struct('position',NaN(2,1),'covariance',NaN(2),'accepted',false, ...
    'hasEstimate',false,'ready',false,'status','missing','modelMismatch',false, ...
    'nominalRadius95',NaN,'consistencyStatistic',NaN,'consistencyThreshold',NaN, ...
    'innovationNIS',NaN,'innovationThreshold',NaN,'fitCost',NaN, ...
    'nAccepted',state.nAccepted,'nRejected',state.nRejected,'nMissing',state.nMissing, ...
    'windowCount',numel(state.ids),'effectiveAgeCount',0,'meanMeasurement',NaN(K,1), ...
    'meanCovariance',NaN(K),'uncertaintyConditional',true);
add=false;
if any(isnan(z))
    state.nMissing=state.nMissing+1;
else
    ids=[1:refIdx-1 refIdx+1:size(Rx,1)];
    baseline=sqrt(sum(bsxfun(@minus,Rx(ids,:),Rx(refIdx,:)).^2,2));
    margin=sqrt(2*gammaincinv(o.gateProbability,K/2))*sqrt(diag(R));
    if any(abs(z)>baseline+margin)
        state.nRejected=state.nRejected+1; out.status='rejected_physical';
    else
        state.ids(end+1)=packetId; state.Z(:,end+1)=z; state.RR(:,:,end+1)=R; add=true;
    end
end
n=numel(state.ids);
if n>0
    a=w.decay.^(packetId-state.ids); a=a/max(a);
    J=zeros(K); B=J; b=zeros(K,1); J0=J; b0=b;
    for j=1:n
        W=state.RR(:,:,j)\eye(K);
        J=J+a(j)*W; B=B+a(j)^2*W; b=b+a(j)*W*state.Z(:,j);
        J0=J0+W; b0=b0+W*state.Z(:,j);
    end
    mu=J\b; Q=(J\B)/J; Q=(Q+Q')/2;
    solver=o; solver.covarianceScale=1;
    [p,C,f]=tdoaLocalize(mu,Q,Rx,refIdx,[],solver);
    if f.valid
        % Consistency uses an UNWEIGHTED batch fit. Exponential weights do not
        % have the same chi-square distribution as an ordinary batch residual.
        pCheck=p; checkOK=true;
        if w.decay~=1
            [pCheck,~,fc]=tdoaLocalize(J0\b0,J0\eye(K),Rx,refIdx,[],solver);
            checkOK=fc.valid;
        end
        statistic=0;
        if checkOK
            h=tdoaModel(pCheck,Rx,refIdx);
            for j=1:n
                e=state.Z(:,j)-h; statistic=statistic+e'*(state.RR(:,:,j)\e);
            end
            df=n*K-2;
            if df>0
                out.consistencyStatistic=statistic;
                out.consistencyThreshold=2*gammaincinv(o.gateProbability,df/2);
                out.modelMismatch=statistic>out.consistencyThreshold;
            end
        else
            out.modelMismatch=true;
        end
        out.position=p; out.covariance=C; out.hasEstimate=true; out.fitCost=f.cost;
        out.meanMeasurement=mu; out.meanCovariance=Q;
        out.effectiveAgeCount=sum(a)^2/sum(a.^2); % Age weights only; not full covariance ESS.
        out.nominalRadius95=sqrt(2*gammaincinv(.95,1)*max(eig(C)));
        out.ready=n>=o.minimumPackets && ~out.modelMismatch;
        if add
            state.nAccepted=state.nAccepted+1; out.accepted=true; out.status='updated';
            if n<o.minimumPackets, out.status='startup'; end
            if out.modelMismatch, out.status='updated_model_mismatch'; end
        end
    else
        out.status=['rejected_' f.reason];
        if add
            state.ids(end)=[]; state.Z(:,end)=[]; state.RR(:,:,end)=[];
            state.nRejected=state.nRejected+1;
        end
        % No stale position/covariance is reported as a current window solution.
    end
end
out.nAccepted=state.nAccepted; out.nRejected=state.nRejected; out.nMissing=state.nMissing;
out.windowCount=numel(state.ids);
end
