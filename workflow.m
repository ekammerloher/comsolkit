% Connect to a server/start up livelink to comsol.
comsolkit.GateLayoutModel.server_connect(); % server_disconnect() to disconnect. Can be a remote server, see help.
comsolkit.GateLayoutModel.get_server_tags(); % Currently models on the server.

%% Create GateLayoutModel object from a template file. Check out help comsolkit.GateLayoutModel.GateLayoutModel.
gl = comsolkit.GateLayoutModel('FromFile', '.../template/template_GaAs.mph'); % Can be from an model on the server as well.
gl.lengthUnit % The unit of length in parts of a meter. Can be changed.
gl.tag % Tag of the model on the server. Can be changed.
gl.plot(); % Plots geometry of the model.

%% Import gds file. Or add layer by layer with gl.add_layer(...). Check out help comsolkit.GateLayoutModel.batch_add_layer.
[coordinateCell, nameCell] = gl.import_gds_file('LFL_v1.gds'); % gdsii-toolbox can sometimes crash matlab. Save your work here.
gl.batch_add_layer(coordinateCell, nameCell, gl.DEFAULT_GATE_CLASS); % Gate objects inherit from Layer. Layers live in gl.layerArray.
[gl.layerArray(:).distance] = deal(30); % This is the gate thickness, default is 1. Computation time improves if this is >1.
% The distance cannot be zero, since consolkit relies on domain type geometry to setup boundary conditions.
gl.layerArray(1).name = 'gate1'; % Rename the gate.
% gl.layerArray(1).zPosition = 2; % Change the z position of the gate.
gl.print_layer_info();
% You can remove a layer with remove_layer(index), batch_remove_layer(startIndex, stopIndex), remove_all_layers().
% In case somethin went wrong and the model contains features created by comsolkit, that are not present in gl.layerArray,
% you can clean up any dynamically created features from the geometry by the static methods comsolkit.Gate.clear_geometry_features()
% and from the electrostatic pysics by comsolkit.Gate.clear_es_features().
gl.layerArray.plot('Names', 'on'); % plot() for Layer objects works for vectorized calls of the function.
gl.layerArray(1).plot(); % Or like this.
gl.layerArray(3:6).plot(); % This works too.

%% Helper to choose the domain dimensions.
gl.choose_domain_region();

%% Setup domain dimensions of the template.
gl.set_param('origin_x', 29899.679724);
gl.set_param('origin_y', 23420.449309);
gl.set_param('l_domain', 2538.594470);
gl.set_param('w_domain', 1078.341014);

%% Enable surface charge density of 2DEG.
chargeDensity = -1.60217657e-19 * 1e15;
gl.set_param('charge_density', chargeDensity);

%% Model 3D view.
gl.plot(); % Gates should appear now in the model.
gl.print_param_info(); % Access parameters with set_param()/get_param().

%% Save the GateLayoutModel object, including the comsol model (saved into the object, mat-fiels can be potentially big).
save('gl.mat','gl'); % gl.save_mph(fileName) would just save the model as a mph-file.

%% Set some voltage.
[gl.layerArray(:).voltage] = deal(0);
gl.layerArray(10).voltage = 1; % Setting the voltage to NaN makes the gate floating.

%% Or like this.
v = [-0.3743 -0.1576 -0.4439 -0.5815 -0.6181 -0.6780 -0.6497 0 -0.5005 0 0 0 0 0 0 -0.6008 -0.6947 -0.8423 0.0000 -0.6500 0.0000 -1.1170];
for i=1:length(gl.layerArray); gl.layerArray(i).voltage = v(i); end

%% Change gate shape.
gl.layerArray(1).polygonCell % This shows all polygons the gate is made out of. You can edit this freely. Change coordinates, add/remove polygons.
gl.layerArray(1).choose_polygon_indices(); % Will draw the gate and you can select an area. A mask for the selected indices is returned.
coords = gl.layerArray(1).polygonCell{1};
gl.layerArray(1).polygonCell{1} = (coords.*1.1) .+ 1; % Scale and translate the whole polygon a bit.

%% Edit/create a gate by mouse.
gl.add_layer(gl.layerArray(1).polygonCell); % Will create a new gate with the same XY coordinates as Gate 1.
gl.layerArray(end).edit_polygon_cell(); % Edit the vertices, add new polygons. Can be used to make a screening layer to simulate the free 2DEG.
gl.layerArray(end).name = 'Screening';
gl.layerArray(end).distance = 10; % Increase thickness from default 1 to simplify mesh and reduce computation time.
gl.layerArray(end).zPosition = str2double(gl.get_param('t_2DEG')) - gl.layerArray(end).distance; % Put it in contact with 2DEG from below.

%% Obtain a rasterized interpolated potential.
precision = 10;
l_domain = str2double(gl.get_param('l_domain'));
w_domain = str2double(gl.get_param('w_domain'));
origin_x = str2double(gl.get_param('origin_x'));
origin_y = str2double(gl.get_param('origin_y'));
x0 = origin_x:precision:l_domain+origin_x;
y0 = origin_y:precision:w_domain+origin_y;
z0 = str2double(gl.get_param('t_2DEG'));
[x,y,z] = meshgrid(x0,y0,z0);
xyz = [x(:),y(:),z(:)]'; % This is now a 3 x n of points to evaluate.

%% Model is solved and values are returned at interpolated coordinates.
tic;
pot = gl.compute_interpolated_potential(xyz, length(y0), length(x0)); % length(x0), length(y0) are used to reshape the results. Can be omitted.
toc;

%% Mesh detail, can range from 1-9, where one is fine.
gl.model.mesh('mesh1').feature('size').getString('hauto')
mphmesh(gl.model, 'mesh1', 'Facealpha', 0.5); % Plot model mesh.

%% Adjust mesh size.
gl.model.mesh('mesh1').feature('size').set('hauto', 2);

%% Plot the potential.
imagesc(x0,y0,pot);
colormap(parula(512));
colorbar();
set(gca,'YDir','normal');

%% Overlay gates.
gl.layerArray.plot('Names', 'on');

%% Get unit 1 potentials for all gates ans save them to pots array.
gl.set_param('charge_density', 0); % Otherwise this will not make sense.

pots = zeros(length(y0), length(x0), ...
    length(gl.layerArray)); % prepare array for results
[layerArray] = deal(0);

for gate_index = 1:length(gl.layerArray)
    
    gl.layerArray(gate_index).voltage = 1;

    pots(:,:,gate_index) = gl.compute_interpolated_potential(xyz, ...
                               length(y0), length(x0));
    
    gl.layerArray(gate_index).voltage = 0;
end

%% Check pots array.
for gate_index = 1:length(m.Layout)
    imagesc(x0,y0,pots(:,:,gate_index));
    colormap(parula(512));
    set(gca,'YDir','normal');
    pause;
end