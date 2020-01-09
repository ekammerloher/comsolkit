function [nodes, path, pos, val] = cost_spline_path(interpolant, nodes)
% Optimize spline nodes coordinates (nx2) based on cost and path length.
% Spline bound to convex hull: interpolant.ExtrapolationMethod = 'none'

    assert(isa(interpolant, 'scatteredInterpolant'), ...
           'Cost data must be supplied using a scatteredInterpolant.');

    t = linspace(0, 1, size(nodes,1));
    tSampled = linspace(0, 1, size(nodes,1)*50); % Sampling along spline.

    enclose_start_end = @(n) [nodes(1,:); n; nodes(end,:)];
    segment_length = @(n) sqrt(sum(diff(n).^2,2));
    minLen = segment_length(enclose_start_end([]));
    nodes = nodes(2:end-1,:);

    function f = objective(currNodes)
        path = spline(t, enclose_start_end(currNodes)', tSampled)';
        seg = segment_length(path);
        pos = cumsum([0; seg]);
        val = interpolant(path(:,1), path(:,2));

%        normLen = (pos(end)-minLen)/(pos(end)+minLen); % Is now [0, 1).
%        f = trapz(pos,val)/(1-normLen);
        f = trapz(pos,val);
    end

    function stop = plotPath(currNodes, ~, flag)
        stop = false;
        switch flag
            case 'init'
                line(path(:,1), path(:,2), 'Marker', '.', ...
                     'LineStyle', 'none', 'Tag', 'optimPlotPath');
                line(currNodes(:,1), currNodes(:,2), 'Marker', 'o', ...
                     'LineStyle', 'none', 'Tag', 'optimPlotNodes');
                axis equal;
            case 'iter'
                h = findobj(get(gca,'Children'),'Tag','optimPlotPath');
                set(h, 'XData', path(:,1), 'YData', path(:,2));
                h = findobj(get(gca,'Children'),'Tag','optimPlotNodes');
                set(h, 'XData', currNodes(:,1), 'YData', currNodes(:,2));
        end
    end

    function stop = plotIntegral(~, ~, flag)
        stop = false;
        switch flag
            case 'init'
                line(pos, val, 'Tag', 'optimPlotIntegral');
                axis tight;
            case 'iter'
                h = findobj(get(gca,'Children'),'Tag','optimPlotIntegral');
                set(h, 'XData', pos, 'YData', val);
        end
    end

    problem.solver = 'fmincon';
    problem.objective = @objective;
    problem.x0 = nodes;
    problem.lb = repmat([min(interpolant.Points(:,1)), ...
                         min(interpolant.Points(:,2))],size(nodes,1),1);
    problem.ub = repmat([max(interpolant.Points(:,1)), ...
                         max(interpolant.Points(:,2))],size(nodes,1),1);
    problem.options = optimset('TolX', 10e-15, 'MaxIter', 1e3, ...
                               'MaxFunEvals', 1e6, 'Disp', 'off');
%    problem.options = optimset('TolX', 10e-15, 'MaxIter', 1e3, ...
%                               'MaxFunEvals', 1e6, 'Disp', 'Iter', ...
%                               'PlotFcns', {@plotPath, ...
%                                            @plotIntegral, ...
%                                            @optimplotfval});

    nodes = enclose_start_end(fmincon(problem));
end
