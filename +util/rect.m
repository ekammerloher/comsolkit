function r = rect(origin, width, height)
    % rect Helper function to define rectangle.
    %
    % r = rect(origin, width, height)

    r =  [0,0; 0,height; width,height; width,0]+origin;
end
