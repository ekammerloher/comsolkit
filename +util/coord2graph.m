function g = coord2graph(coord, weights, costFnc)
    % coord2graph Convert n x 2 array of coordinates to a graph.
    %
    % g = coord2graph(coord)

    if nargin < 2
        weights = zeros(size(coord,1));
    end
    if nargin < 3
        % Default cost is distance of nodes.
        costFnc = @(d, w) d;
    end

    % Make coordinates unique.
    [~, I, ~] = unique(coord,'first','rows');
    I = sort(I);
    x = coord(I,1);
    y = coord(I,2);
    w = weights(I);

    % Remove nan values.
    nan_flags = isnan(x) | isnan(y);
    x(nan_flags) = [];
    y(nan_flags) = [];
    w(nan_flags) = [];

    % Create new triangulation after cleanup.
    T = delaunay(x,y);
    E = [T(:,1) T(:,2); T(:,2) T(:,3); T(:,1) T(:,3)]; % Generate all edges.
    E = sort(E,2);
    E = unique(E, 'rows'); % Remove duplicate edges.

    % Calculate distances.
    d = hypot(x(E(:,1))-x(E(:,2)), ...
              y(E(:,1))-y(E(:,2)));

    cost = costFnc(d, w);

    edgeTable = table(E, cost, 'VariableNames', {'EndNodes', 'Weight'});
    % Put coordinates in as auxilliary information.
    nodeTable = table(x, y, 'VariableNames', {'x', 'y'});
    g = graph(edgeTable, nodeTable);
end
