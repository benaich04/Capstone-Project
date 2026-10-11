function plotScene(cfg, Phat, Pcov)
%PLOTSCENE  Plot receivers, walls, true TX and (optionally) the estimate.
%   plotScene(cfg)              -> geometry only
%   plotScene(cfg, Phat)        -> + estimated position
%   plotScene(cfg, Phat, Pcov)  -> + error ellipse (cfg.ellipseConf)

figure('Name', 'Scene'); hold on; grid on; axis equal;

for w = 1:size(cfg.walls, 1)                                    % walls
    plot(cfg.walls(w,[1 3]), cfg.walls(w,[2 4]), 'k-', 'LineWidth', 3);
end

plot(cfg.Rx(:,1), cfg.Rx(:,2), 'b^', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
for k = 1:cfg.nRx
    lbl = sprintf('  RX%d', k);
    if k == cfg.refIdx, lbl = [lbl ' (ref)']; end
    text(cfg.Rx(k,1), cfg.Rx(k,2), lbl);
end

plot(cfg.P0(1), cfg.P0(2), 'rp', 'MarkerSize', 14, 'MarkerFaceColor', 'r');
leg = {'RX', 'True TX'};
if ~isempty(cfg.walls), leg = [{'Wall'} repmat({''}, 1, size(cfg.walls,1)-1) leg]; end

if nargin >= 2 && ~isempty(Phat)
    plot(Phat(1), Phat(2), 'gx', 'MarkerSize', 12, 'LineWidth', 2);
    leg{end+1} = 'Estimate';
end
if nargin >= 3 && ~isempty(Pcov)
    k2 = -2 * log(1 - cfg.ellipseConf);          % chi-square, 2 DoF
    [V, D] = eig((Pcov + Pcov.')/2);
    t  = linspace(0, 2*pi, 200);
    E  = V * sqrt(k2 * D) * [cos(t); sin(t)];
    plot(Phat(1) + E(1,:), Phat(2) + E(2,:), 'g-');
    leg{end+1} = sprintf('%g%% ellipse', 100*cfg.ellipseConf);
end

legend(leg, 'Location', 'bestoutside');
xlabel('x [m]'); ylabel('y [m]'); title('Scene');
end
