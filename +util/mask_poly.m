function newPolyShape = mask_poly(polyShape, mask)
    % mask_poly Mask polyShape to within mask.
    %
    % newPolyShape = mask_poly(polyShape, mask)

    assert(isa(polyShape, 'polyshape'), 'Input must be a polyshape');
    assert(isa(mask, 'polyshape') && isscalar(mask), ...
           'Input must be a scalar polyshape');

    newPolyShape = polyshape.empty;
    for p=polyShape(:)'
        new_p = p.intersect(mask);
        if new_p.NumRegions ~= 0
        newPolyShape(end+1) = new_p;
        end
    end
end
