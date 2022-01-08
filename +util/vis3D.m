function vis3D(varargin)
    %  Creates a plot of 
    %
    %  Layer(hModel)
    %  Layer(hModel, varargin)
    %
    %  Parameters:
    %  hModel: Required handle to parent ComsolModel type object
    %  gateTab: An input gate table with columns - name, zPos, thickness, shape
    %           The zPos is used only for ordering, so need not be exact, it will
    %           be decided by the function itself and output correctly. The thickness
    %           is the desired thickness of the gate, and the shape is the actual
    %           gate shape without overlaps.
    % 'Axes': specify an axex handel, otherwise draw into figure 99.
    % 'FaceColor': specify a face color for the patch objects. Can be an
    % colormap at least as long as the unique names, otherwise use perula
    % with colorcoding by unique names.
    % 'Alpha': Specify transparency value of patch objects.
    par = inputParser;
    par.addRequired('gateTab');
    par.addParameter('Axes', []);
    par.addParameter('FaceColor', []);
    par.addParameter('Alpha', 1);
    par.parse(varargin{:});

    if isempty(par.Results.Axes) % Create new figure if no axes was given.
        hF = figure(99);
        clf(hF);
        ax = axes(hF);    
    else
        ax = par.Results.Axes;
    end
    axis(ax, 'equal');
    view(ax,3);

    gateTab = par.Results.gateTab;
    gates = gateTab.shape;
    thickness = gateTab.thickness;
    zPos = gateTab.zPos;
    names = gateTab.name;
    
    name_unique = unique(names);
    idx = 1:length(name_unique);
    colors = parula(length(name_unique));
    cmap = containers.Map(name_unique, idx);
    
    for i = 1:length(gates)
        p = gates(i);
        if p.NumHoles > 0
            warning('Holes detected in shape of ''%s''. Plotting of holes not implemented yet.', names(i));
        end
        gName = gateTab.name(i);
        p = regions(p);
        for j=1:length(p)
            v = rmholes(p(j)).Vertices;
                

            vm = [v(:,1), v(:,2), zPos(i)*ones(size(v,1), 1); v(:,1), v(:,2), (thickness(i)+zPos(i))*ones(size(v,1), 1)];
            fm = comsolkit.util.vertices2faces(vm);
            if isempty(par.Results.FaceColor)
                faceColor = colors(cmap(gName), :);
            else
                if size(par.Results.FaceColor,1) > 1
                    faceColor = par.Results.FaceColor(cmap(gName),:);
                else
                    faceColor = par.Results.FaceColor;
                end
            end
            % Edge color tracks face color, but 35% darker.
            rgb = validatecolor(faceColor,'one');
            hsv = rgb2hsv(rgb);
            hsv(3) = max([0.75*hsv(3),0]);
            rgb = hsv2rgb(hsv);
            hP = patch(ax, 'Faces', fm, 'Vertices', vm, 'FaceColor', faceColor, 'EdgeColor', rgb);
            alpha(hP, par.Results.Alpha);
            hold(ax,'on');
        end
    end
    hold(ax,'off');
end