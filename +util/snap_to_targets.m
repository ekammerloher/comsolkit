function new_pos = snap_to_targets(pos, x, y, snap_radius)
    % snap_to_targets Constraint function for impoly to snap to target points.
    new_pos = pos;

    for currVert=1:size(pos, 1)
        radius = hypot(x-pos(currVert,1), y-pos(currVert,2));
        if any(radius < snap_radius)
            [~, idx] = min(radius);
            new_pos(currVert,1) = x(idx);
            new_pos(currVert,2) = y(idx);
        end
    end
end
