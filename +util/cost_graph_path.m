function [xyPath, pos] = cost_graph_path(costInt, startTargetPoints)
    % Construct graph from triangulation.
    p = costInt.Points;
    T = delaunay(p(:,1), p(:,2)); % Create triangulation.
    E = [T(:,1) T(:,2); T(:,2) T(:,3); T(:,1) T(:,3)]; % Generate all edges.
    E = sort(E,2);
    E = unique(E, 'rows'); % Remove duplicate edges.

    % Weight engineering.
    d = hypot(p(E(:,1),1)-p(E(:,2),1), ...
            p(E(:,1),2)-p(E(:,2),2));
    f = abs(costInt.Values(E(:,1)) - ...
            costInt.Values(E(:,2)));
    minK = mink(f, 5); % 5th smallest value.
    w = f + minK(end).*normalize(d, 'range');

    edgeTable = table(E, w, 'VariableNames', {'EndNodes', 'Weight'});
    G = graph(edgeTable);

    % Move from coordinates to closest node IDs.
    startPoint = startTargetPoints(1,:);
    endPoint = startTargetPoints(end,:);
    startEndNode = dsearchn(p, [startPoint; endPoint]);

    path = shortestpath(G, startEndNode(1), startEndNode(2));

    % Move back to coordinates.
    xyPath = p(path,:);

    xyPath = downsample(xyPath, 1);
    t = linspace(0, 1, size(xyPath,1));
    tSampled = linspace(0, 1, numel(path)); % Undersampling along spline.
    xyPath = spline(t, xyPath', tSampled)';

    % Generate arc length.
    segment_length = @(n) sqrt(sum(diff(n).^2,2));
    seg = segment_length(xyPath);
    pos = cumsum([0; seg]);
end
