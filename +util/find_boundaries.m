function boundaries = find_boundaries(varargin)
% boundaries = find_boundaries(mask, 'ParameterName', ParameterValue, ...)
%
% Finds boundaries in logical mask and simplifies them using the
% Ramer-Douglas-Peucker algorithm from:
% https://de.mathworks.com/matlabcentral/fileexchange/41986-ramer-douglas-peucker-algorithm-demo
% Ensures boundaries are closed and clockwise.
%
% Parameters:
% -----------
% skipBound: 10 (skip boundaries with <10 points before simplification)
% tolerance: 3 (specify tolerance for simplification)
% snapToXBoundTol: 4 (snap points close to boundary to boundary)
% snapToYBoundTol: 4 (snap points close to boundary to boundary)

p = inputParser;
p.addRequired('mask');
p.addParameter('skipBound', 10);
p.addParameter('tolerance', 3);
p.addParameter('snapToXBoundTol', 4);
p.addParameter('snapToYBoundTol', 4);
p.parse(varargin{:});

boundaries = bwboundaries(p.Results.mask);

skipMask = cell2mat(cellfun(@(c)size(c,1)<p.Results.skipBound, ...
                            boundaries, 'UniformOutput', false));
boundaries(skipMask) = [];

if p.Results.snapToXBoundTol > 0 || p.Results.snapToYBoundTol > 0
    x = cell2mat(cellfun(@(c) c(:,2), boundaries, 'UniformOutput', false));
    y = cell2mat(cellfun(@(c) c(:,1), boundaries, 'UniformOutput', false));
    I = convhull(x, y);
    convX = x(I);
    convY = y(I);
end

for ii = 1:numel(boundaries)
    b = boundaries{ii};
    b = [b(:,2), b(:,1)]; % bwboundaries has unintuitive xy output.

    if p.Results.tolerance > 0
        epsilon = p.Results.tolerance;
        b = RDP_recs(b, size(b,1));
    end

    if p.Results.snapToXBoundTol > 0
        [minX, maxX] = bounds(convX);
        maskMin = b(:,1) < minX + p.Results.snapToXBoundTol;
        maskMax = b(:,1) > maxX - p.Results.snapToXBoundTol;
        b(maskMin,1) = minX;
        b(maskMax,1) = maxX;
    end

    if p.Results.snapToYBoundTol > 0
        [minY, maxY] = bounds(convY);
        maskMin = b(:,2) < minY + p.Results.snapToYBoundTol;
        maskMax = b(:,2) > maxY - p.Results.snapToYBoundTol;
        b(maskMin,2) = minY;
        b(maskMax,2) = maxY;
    end

    % Remove duplicate points.
    [~, I, ~] = unique(b,'first','rows');
    I = sort(I);
    x = b(I,1);
    y = b(I,2);

    % Enshure polygon is closed and cw.
    [x, y] = closePolygonParts(x, y);
    [x, y] = poly2cw(x, y);

    boundaries{ii}=[x,y];
end

function ptList_reduced = RDP_recs(ptList, n)
    if n <= 2
        ptList_reduced = ptList;
        return;
    end
    % Find the point with the maximum distance.
    dmax = -inf;
    idx = 0;
    for k = 2:n-1
        d = PerpendicularDistance(ptList(k,:), ptList([1,n],:));
        if d > dmax
            dmax = d;
            idx = k;
        end
    end
    % If max distance is greater than epsilon, recursively simplify.
    if dmax > epsilon
        % Recursive call.
        recList1 = RDP_recs(ptList(1:idx,:), idx);
        recList2 = RDP_recs(ptList(idx:n,:), n-idx+1);
        % Build the result list.
        ptList_reduced = [recList1;recList2(2:end,:)];
    else
        ptList_reduced = ptList([1,n],:);
    end
end

function d = PerpendicularDistance(pt, lineNode)
    Ax = lineNode(1,1);
    Ay = lineNode(1,2);
    Bx = lineNode(2,1);
    By = lineNode(2,2);
    d_node = sqrt((Ax-Bx).^2+(Ay-By).^2);
    if d_node > eps
        d = abs(det([1 1 1;pt(1) Ax Bx;pt(2) Ay By]))/d_node;
    else
        d = sqrt((pt(1)-Ax).^2+(pt(2)-Ay).^2);
    end
end
end
