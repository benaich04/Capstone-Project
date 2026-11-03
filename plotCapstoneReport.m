function plotCapstoneReport(res,cfg)
%PLOTCAPSTONEREPORT Summary presentation plots without replacing block data.
figure('Name','Capstone Integration Dashboard','Color','w');
T=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
ax=nexttile(T,1);
plotCapstoneGeometry(cfg,res.last.truth,res.last.Phat,res.last.Ptrk,res.last.Pcov,ax);
ax=nexttile(T,2);
plot(ax,res.time,res.rawError,'o-','LineWidth',1.1,'DisplayName','Raw error'); hold(ax,'on');
plot(ax,res.time,res.trackError,'s-','LineWidth',1.1,'DisplayName','Tracked error');
ylabel(ax,'Error (m)');xlabel(ax,'Time (s)');title(ax,'Position error');
grid(ax,'on');legend(ax,'Location','best');
ax=nexttile(T,3);
bar(ax,res.last.deltad);
set(ax,'XTick',1:numel(res.last.deltad));
xticklabels(ax,arrayfun(@(j)sprintf('RX%d - RX%d',j,cfg.refIdx),cfg.others,'UniformOutput',false));
ylabel(ax,'Distance difference (m)');title(ax,'Measured TDoAs (last packet)');grid(ax,'on');
ax=nexttile(T,4);
info=res.last.info3;
N=size(info.cir,1);
tau=((0:N-1)'-N/2)/(cfg.fs*cfg.zpFactor)*1e9;
plot(ax,tau,abs(fftshift(info.cir,1)),'LineWidth',1.0);
xlabel(ax,'Relative delay (ns)');ylabel(ax,'|CIR|');
title(ax,'Four receiver CIR magnitudes');grid(ax,'on');
sgtitle(T,sprintf('%s | Raw RMSE %.3f m | Track RMSE %.3f m', ...
    cfg.experimentMode,res.rawRMSE,res.trackRMSE));
end
