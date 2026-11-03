function [h,H] = tdoaModel(p,Rx,refIdx)
%TDOAMODEL Range differences [m] and analytic position Jacobian.
% Output rows follow receiver order with refIdx omitted. Positions are 2-D.
p = p(:)';
v = bsxfun(@minus,p,Rx);
d = sqrt(sum(v.^2,2));
others = [1:refIdx-1 refIdx+1:size(Rx,1)];
h = d(others)-d(refIdx);
if nargout > 1
    if any(d <= eps*max(1,max(d)))
        H = NaN(numel(others),2); return
    end
    u = bsxfun(@rdivide,v,d);
    H = bsxfun(@minus,u(others,:),u(refIdx,:));
end
end
