function ax = plotCapstoneGeometry(cfg,truth,Phat,Ptrk,Pcov,ax)
%PLOTCAPSTONEGEOMETRY Show TX/RX layout, paths, optional wall reflections,
% raw and tracked position and 95%% local covariance ellipse.
if nargin<6 || isempty(ax)
    figure('Name','Wi-Fi TDoA Geometry','Color','w'); ax=gca;
end
hold(ax,'on'); axis(ax,'equal'); grid(ax,'on');
if isfield(cfg,'walls') && ~isempty(cfg.walls)
    for w=1:size(cfg.walls,1)
        plot(ax,cfg.walls(w,[1 3]),cfg.walls(w,[2 4]),'k-', ...
            'LineWidth',3,'DisplayName','Wall');
    end
end
if isstruct(truth) && isfield(truth,'P0')
    for r=1:size(cfg.Rx,1)
        plot(ax,[truth.P0(1) cfg.Rx(r,1)], ...
            [truth.P0(2) cfg.Rx(r,2)],'--', ...
            'Color',[0.72 0.72 0.72],'HandleVisibility','off');
        if isfield(truth,'hasBounce')&&truth.hasBounce(r) ...
                &&all(isfinite(truth.bouncePoint(:,r)))
            b=truth.bouncePoint(:,r);
            plot(ax,[truth.P0(1) b(1) cfg.Rx(r,1)], ...
                [truth.P0(2) b(2) cfg.Rx(r,2)],':', ...
                'LineWidth',1.5,'Color',[0.65 0.3 0.8], ...
                'DisplayName','Reflected path');
            plot(ax,b(1),b(2),'mo','HandleVisibility','off');
        end
    end
    plot(ax,truth.P0(1),truth.P0(2),'p','MarkerSize',13, ...
        'MarkerFaceColor',[0.2 0.7 0.35],'Color',[0.1 0.5 0.2], ...
        'DisplayName','True TX');
end
plot(ax,cfg.Rx(:,1),cfg.Rx(:,2),'^','MarkerSize',9, ...
    'MarkerFaceColor',[0.05 0.3 0.75],'Color',[0 0.2 0.5], ...
    'LineStyle','none','DisplayName','RX');
for i=1:size(cfg.Rx,1)
    text(ax,cfg.Rx(i,1),cfg.Rx(i,2),sprintf(' RX%d',i),'FontWeight','bold');
end
if ~isempty(Phat)&&all(isfinite(Phat))
    plot(ax,Phat(1),Phat(2),'x','MarkerSize',12, ...
        'LineWidth',2,'Color',[0.85 0.22 0.16],'DisplayName','Raw estimate');
    if ~isempty(Pcov)&&all(isfinite(Pcov(:)))
        plotCovEllipse(ax,Phat,Pcov);
    end
end
if ~isempty(Ptrk)&&all(isfinite(Ptrk))
    plot(ax,Ptrk(1),Ptrk(2),'o','MarkerSize',9, ...
        'LineWidth',1.8,'Color',[0.2 0.45 0.9],'DisplayName','Tracked estimate');
end
xlabel(ax,'x (m)'); ylabel(ax,'y (m)'); title(ax,'2-D Wi-Fi TDoA localization');
legend(ax,'Location','best');
hold(ax,'off');
end

function plotCovEllipse(ax,p,C)
[V,D]=eig((C+C')/2);
a=sqrt(max(diag(D),0)*(-2*log(0.05)));
phi=linspace(0,2*pi,180);
xy=V*diag(a)*[cos(phi);sin(phi)]+p(:);
plot(ax,xy(1,:),xy(2,:),'-','Color',[0.85 0.22 0.16], ...
    'LineWidth',1.4,'DisplayName','95% CRLB ellipse (local)');
end
