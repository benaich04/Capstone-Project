function [p,C,info] = tdoaLocalize(z,R,Rx,refIdx,pinit,options)
%TDOALOCALIZE Whitened damped Gauss-Newton 2-D range-difference localization.
% Inputs: z [m], full R [m^2], Rx Nx2 [m], reference, optional initial point.
% Outputs: p 2x1 [m], local model covariance C; info.valid must be checked.
% No truth input. No convex-hull constraint. Nonlinear global uniqueness is not assured.
if nargin<5, pinit=[]; end
if nargin<6, options=[]; end
[z,R,o]=tdoaValidate(z,R,Rx,refIdx,options);
R=o.covarianceScale*R;
p=NaN(2,1); C=NaN(2);
info=struct('valid',false,'reason','missing_measurement','converged',false, ...
    'cost',NaN,'iterations',0,'starts',0,'informationRcond',0,'ambiguous',false);
if any(isnan(z)), return; end
if ~isempty(pinit), validateattributes(pinit,{'double'},{'real','finite','vector','numel',2}); end
origin=mean(Rx,1); localRx=bsxfun(@minus,Rx,origin);
radius=max(sqrt(sum(localRx.^2,2)));
starts=[0 0];
if ~isempty(pinit), starts=[pinit(:)'-origin;starts]; end
if o.multistart
    a=(0:7)'*pi/4;
    starts=[starts;radius*[cos(a) sin(a)];3*radius*[cos(a) sin(a)]];
end
starts=unique(starts,'rows','stable'); L=chol(R,'lower');
solutions=NaN(size(starts)); costs=Inf(size(starts,1),1); iterations=zeros(size(costs));
for j=1:size(starts,1)
    [q,cost,ok,it]=solveOne(starts(j,:)',z,L,localRx,refIdx,o);
    if ok, solutions(j,:)=q'; costs(j)=cost; end
    iterations(j)=it;
end
[best,j]=min(costs); info.starts=size(starts,1); info.iterations=sum(iterations);
info.reason='solver_failed';
if ~isfinite(best), return; end
q=solutions(j,:)'; [~,H]=tdoaModel(q,localRx,refIdx); A=L\H; F=A'*A;
info.converged=true; info.cost=best; info.informationRcond=rcond(F);
if info.informationRcond<o.minInformationRcond, info.reason='weak_geometry'; return; end
C=F\eye(2); C=(C+C')/2;
distance=sqrt(sum(bsxfun(@minus,solutions,q').^2,2));
separation=max(0.1*radius,3*sqrt(trace(C)));
info.ambiguous=any(costs<=best+o.ambiguityCostGap & distance>separation);
if info.ambiguous, C=NaN(2); info.reason='ambiguous'; return; end
p=q+origin'; info.valid=true; info.reason='ok';
end

function [q,cost,ok,it]=solveOne(q,z,L,Rx,ref,o)
ok=false; cost=Inf; damping=o.initialDamping;
for it=1:o.maxIterations
    [h,H]=tdoaModel(q,Rx,ref);
    if any(~isfinite(H(:))), return; end
    r=L\(z-h); A=L\H; cost=r'*r; F=A'*A; g=A'*r;
    if norm(g,Inf)<=o.gradientTolerance*(1+norm(A,'fro')*norm(r))
        ok=true; return
    end
    D=diag(max(diag(F),max(trace(F),realmin)*1e-12)); accepted=false;
    for attempt=1:o.maxDampingTrials
        step=(F+damping*D)\g;
        if all(isfinite(step))
            trial=q+step; rr=L\(z-tdoaModel(trial,Rx,ref)); newCost=rr'*rr;
            if isfinite(newCost) && newCost<cost
                q=trial; cost=newCost; damping=max(damping/3,1e-12); accepted=true; break
            end
        end
        damping=damping*10;
    end
    if ~accepted, return; end
end
% A step at the iteration limit is not silently classified as converged.
end
