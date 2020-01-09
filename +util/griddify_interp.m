function [griddedData, x, y] = griddify_interp(interpolant, precision)
    % griddify_interp Evaluates scatteredInterpolant on a grid.
    %
    % [griddedData, x, y] = griddify_interp(interpolant, precision)

    indPoints = convhull(interpolant.Points, 'simplify', true);

    warnStruct = warning('query', 'MATLAB:polyshape:repairedBySimplify');
    warning('off', 'MATLAB:polyshape:repairedBySimplify');

    bounds = polyshape(interpolant.Points(indPoints,1), ...
                       interpolant.Points(indPoints,2));

    warning(warnStruct);

    [xMinMax, yMinMax] = bounds.boundingbox;

    if nargin < 2
        largeSide = max([diff(xMinMax) diff(yMinMax)]);
        precision = largeSide/100;
    end

    x = linspace(xMinMax(1), xMinMax(2), round(diff(xMinMax/precision)));
    y = linspace(yMinMax(1), yMinMax(2), round(diff(yMinMax/precision)));
    [xq, yq] = meshgrid(x,y);

    griddedData = interpolant(xq, yq);
end
