function coordinateCell = poly2cell(polyShape, scalefactor)
    % poly2cell Convert polyshape array to a coordinateCell.
    %
    %  coordinateCell = poly2cell(polyShape, scalefactor)

    assert(isa(polyShape, 'polyshape'), 'Input must be a polyshape');
    if nargin < 2
        scalefactor = 1;
    end
    assert(isnumeric(scalefactor) && isscalar(scalefactor), ...
           'scalefactor must be a scalar number.');

    coordinateCell = cell(0,numel(polyShape));
    for ii=1:numel(polyShape)
        coordinateCell{ii} = arrayfun(@(c) {c.Vertices.*scalefactor}, ...
                                      polyShape(ii).regions);
    end
end
