function [xyPath, pos] = cost_image_path(costInt, startTargetPoints, resolut)
    [cost, x, y] = asd.f.griddify_Interpolant(costInt, resolut);
    [X, Y] = meshgrid(x, y);
    p = [X(:), Y(:)];
    v = cost(:);

    % Use Image Graph to construct 8-connected graph.
    G = imageGraph(size(cost));
    E = G.Edges.EndNodes;

    % Weight engineering.
    d = hypot(p(E(:,1),1)-p(E(:,2),1), ...
            p(E(:,1),2)-p(E(:,2),2));
    f = abs(v(E(:,1)) - ...
            v(E(:,2)));
    w = f + mean(f).*normalize(d, 'range');
    G.Edges.Weight = w;

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
