function [out,state] = tdoaStaticStep(z,R,Rx,refIdx,packetId,state,options)
%TDOASTATICSTEP Cumulative information fusion for a stationary transmitter.
% NEW reconstruction because the referenced original file was NOT supplied.
% Preserves independent TDoA packet information, readiness, physical and
% innovation gates, batch consistency, and covariance. Not valid for motion.
% Interface mirrors tdoaWindowStep, without a finite window argument.
if nargin<6, state=[]; end
if nargin<7, options=[]; end
[z,R,o]=tdoaValidate(z,R,Rx,refIdx,options);
validateattributes(packetId,{'double'},{'scalar','finite','integer','nonnegative','<=',flintmax});
K=numel(z);
R=o.covarianceScale*R;
if isempty(state)
    state=struct('version',1,'Rx',Rx,'refIdx',refIdx,'options',o, ...
        'lastPacketId',-1,'J',zeros(K),'b',zeros(K,1), ...
        'Z',zeros(K,0),'RR',zeros(K,K,0),'nAccepted',0, ...
        'nRejected',0,'nMissing',0,'consecutiveRejected',0);
elseif ~isstruct(state)||~isfield(state,'version')||state.version~=1
    error('tdoa:State','Start the cumulative estimator with empty state.');
elseif ~isequal(state.Rx,Rx)||state.refIdx~=refIdx||~isequal(state.options,o)
    error('tdoa:StateChange','Reset cumulative state when geometry, reference or options change.');
end
if packetId<=state.lastPacketId
    error('tdoa:PacketOrder','Duplicate/out-of-order packet ID.');
end
state.lastPacketId=packetId;
out=struct('position',NaN(2,1),'covariance',NaN(2), ...
    'accepted',false,'hasEstimate',false,'ready',false,'status','missing', ...
    'modelMismatch',false,'nominalRadius95',NaN, ...
    'consistencyStatistic',NaN,'consistencyThreshold',NaN, ...
    'innovationNIS',NaN,'innovationThreshold',NaN, ...
    'meanMeasurement',NaN(K,1),'meanCovariance',NaN(K), ...
    'fitCost',NaN,'nAccepted',state.nAccepted, ...
    'nRejected',state.nRejected,'nMissing',state.nMissing, ...
    'uncertaintyConditional',true);
accept=false;
if any(isnan(z))
    state.nMissing=state.nMissing+1;
else
    other=[1:refIdx-1 refIdx+1:size(Rx,1)];
    baseline=sqrt(sum(bsxfun(@minus,Rx(other,:),Rx(refIdx,:)).^2,2));
    limit=sqrt(2*gammaincinv(o.gateProbability,K/2))*sqrt(diag(R));
    if any(abs(z)>baseline+limit)
        state.nRejected=state.nRejected+1;
        state.consecutiveRejected=state.consecutiveRejected+1;
        out.status='rejected_physical';
    else
        if o.enableInnovationGate && state.nAccepted>=o.gateAfter
            mu=state.J\state.b;
            Q=state.J\eye(K);
            innovation=z-mu;
            S=R+Q;
            out.innovationNIS=innovation'*(S\innovation);
            out.innovationThreshold=2*gammaincinv(o.gateProbability,K/2);
        end
        if isfinite(out.innovationNIS)&&out.innovationNIS>out.innovationThreshold
            state.nRejected=state.nRejected+1;
            state.consecutiveRejected=state.consecutiveRejected+1;
            out.status='rejected_innovation';
        else
            accept=true;
        end
    end
end
if accept
    Jnew=state.J+(R\eye(K));
    bnew=state.b+(R\z);
    solver=o; solver.covarianceScale=1;
    [~,~,test]=tdoaLocalize(Jnew\bnew,Jnew\eye(K),Rx,refIdx,[],solver);
    if test.valid
        state.J=Jnew; state.b=bnew;
        state.Z(:,end+1)=z; state.RR(:,:,end+1)=R;
        state.nAccepted=state.nAccepted+1;
        state.consecutiveRejected=0;
        out.accepted=true; out.status='updated';
    else
        state.nRejected=state.nRejected+1;
        state.consecutiveRejected=state.consecutiveRejected+1;
        out.status=['rejected_' test.reason];
    end
end
if state.nAccepted>0
    mu=state.J\state.b;
    Q=state.J\eye(K);
    solver=o; solver.covarianceScale=1;
    [p,C,f]=tdoaLocalize(mu,Q,Rx,refIdx,[],solver);
    if f.valid
        out.position=p; out.covariance=C; out.hasEstimate=true;
        out.meanMeasurement=mu; out.meanCovariance=Q;
        out.fitCost=f.cost;
        out.nominalRadius95=sqrt(-2*log(0.05)*max(eig(C)));
        batchCost=0;
        h=tdoaModel(p,Rx,refIdx);
        for j=1:state.nAccepted
            e=state.Z(:,j)-h;
            batchCost=batchCost+e'*(state.RR(:,:,j)\e);
        end
        df=state.nAccepted*K-2;
        if df>0
            out.consistencyStatistic=batchCost;
            out.consistencyThreshold=2*gammaincinv(o.gateProbability,df/2);
            out.modelMismatch=batchCost>out.consistencyThreshold;
        end
        if state.consecutiveRejected>=o.maxConsecutiveRejected
            out.modelMismatch=true;
        end
        out.ready=state.nAccepted>=o.minimumPackets && ~out.modelMismatch;
        if out.accepted && state.nAccepted<o.minimumPackets
            out.status='startup';
        elseif out.accepted && out.modelMismatch
            out.status='updated_model_mismatch';
        end
    elseif out.accepted
        out.status=['rejected_' f.reason];
    end
end
out.nAccepted=state.nAccepted;
out.nRejected=state.nRejected;
out.nMissing=state.nMissing;
end
