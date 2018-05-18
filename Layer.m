% Based on: http://de.mathworks.com/help/matlab/ref/ ...
% matlab.mixin.heterogeneous-class.html
classdef Layer < matlab.mixin.Heterogeneous % Necessary for polymorphy.
    % Layer Bundles a comsol workplane and an extrude feature into an unit.
    
    properties(Dependent)
        name % Common name of the workplane and the extrude feature.
        zPosition % z-Position of the layer in the model.
        distance % The extrude distance from zPosition.
        workPlane % Handle to the workplane feature of Layer.
        extrude % Handle to the extrude feature of Layer.
        boundaryTag % Tag of the extrude boundary selection.
        domainTag % Tag of the extrude boundary selection.
        polygonCell % Cell containing nx2 arrays of polygons (if any).
    end
    properties(Constant)
        BASE_TAG_WORKPLANE = 'layer_wp'; % Base wp string for uniquetag.
        BASE_TAG_EXTRUDE = 'layer_ext'; % Base ext string for uniquetag.
        BASE_TAG_POLY = 'dyn_poly'; % Base poly string for uniquetag.
        WORKPLANE_NAME_PREFIX = 'wp_'; % Prefix of workplane label.
    end
    properties(Access=protected)
        extrudeTag % Tag to the extrude feature of the layer.
        workPlaneTag % Tag to the workplane feature of the layer.
        hModel % Handle to a ComsolModel object or a derived object.
    end
    
    methods
        function obj = Layer(hModel, varargin)
            % Layer Creates a Layer object.
            %
            %  Layer(hModel)
            %  Layer(hModel, varargin)
            %
            %  Parameters:
            %  hModel: Required handle to parent ComsolModel type object
            %  Name: Common name of workpane and the extrude feature.
            %  Distance: Thickness of layer. Can be monotonous array or
            %            scalar, pos/neg. If zero the extrude feature is 
            %            deactivated and the workplane is used as a zero 
            %            thickness layer, default: 1)
            %  zPosition: z-Position of the layer (default: 0)
            %  %%% when creating from existing extruded workplane %%%
            %  FromExtrudeTag: Tag of an existing extrude feature
            
            import com.comsol.model.*;
            
            obj.hModel = hModel;
            
            p = inputParser();
            p.addParameter('Name', '', @ischar);
            p.addParameter('FromExtrudeTag', '', @ischar);
            p.addParameter('Distance', 1, @isnumeric);
            p.addParameter('zPosition', 0, ...
                @(x) (isnumeric(x) && isscalar(x)) || ischar(x));
            
            p.parse(varargin{:});
            
            if isempty(p.Results.FromExtrudeTag)
                obj.workPlaneTag = char(hModel.geom.feature().uniquetag( ...
                    obj.BASE_TAG_WORKPLANE));
                obj.extrudeTag = char(hModel.geom.feature().uniquetag( ...
                    obj.BASE_TAG_EXTRUDE));
                
                % Setup workplane.
                workPlane = hModel.geom.feature().create(obj.workPlaneTag, ...
                                                         'WorkPlane');
                workPlane.set('quickplane', 'xy');
                
                % Setup extrude. Will use previous workplane automatically.
                extrude = hModel.geom.feature().create(obj.extrudeTag, ...
                                                       'Extrude');
                extrude.selection('input').set(obj.workPlaneTag);
                
            else % Check extrude feature, when constructing from a tag.
                obj.extrudeTag = p.Results.FromExtrudeTag;
                
                % Use getter of extrude.
                extrudeFrom = char(obj.extrude.getString('extrudefrom'));

                assert(strcmp(extrudeFrom, 'workplane'), ...
                              ['Extrude feature must extrude from a ' ...
                               'workplane and not a face.']);
            end
            
            try
                % Use setters to assign extrude feature and workplane
                % properties.
                obj.zPosition = p.Results.zPosition;
                obj.distance = p.Results.Distance;

                % Set common name, if provided. Use setter.
                if ~isempty(p.Results.Name)
                    obj.name = p.Results.Name;
                end
            catch ME
                warning('Error caugt. Clear layer features and rethrow.');
                obj.delete()
                rethrow(ME);
            end
        end
        
        
        function update_selection(obj)
            % update_selection This is called when the distance property is
            % updated. Overload to update the selection to workplane or
            % extrude feature.
        end
        
        
        function extrude = get.extrude(obj)
            
            import com.comsol.model.*;
            
            extrudeIndex = obj.hModel.geom.feature().index(obj.extrudeTag);
            
            % Is -1 when not in list.
            assert(extrudeIndex >= 0, ...
                   'Could not find extrude feature %s.', ...
                   obj.extrudeTag);
            
            extrude = obj.hModel.geom.feature(obj.extrudeTag);
        end
        
        
        function workPlane = get.workPlane(obj)
            
            import com.comsol.model.*;
            
            if isempty(obj.workPlaneTag) % Legacy code.
                % The extrude feature could have multiple workplanes.
                inputObjectCell = cell( ... 
                    obj.extrude.selection('input').objects());
                
                 assert(isscalar(inputObjectCell), ... 
                        ['Layer expects one workplane for the extrude ' ...
                        'feature. Found %d.'], length(inputObjectCell));
                    obj.workPlaneTag = inputObjectCell{1};
            end
                           
            workplaneIndex = ...
                obj.hModel.geom.feature().index(obj.workPlaneTag);
            
            % Is -1 when not in list.
            assert(workplaneIndex >= 0, 'Could not find workplane %s.', ...
                   obj.workPlaneTag);
            
            workPlane = obj.hModel.geom.feature(obj.workPlaneTag);
        end
        
        
        function boundaryTag = get.boundaryTag(obj)
            
            import com.comsol.model.*;
            
            if obj.extrude.isActive() % Check if non-zero thickness layer.
                obj.extrude.set('createselection', 'on');
                obj.workPlane.set('createselection', 'off');
                selectionCell = cell(obj.extrude.outputSelection());
            
                % Assume we are interested in boundaries. Their selection
                % name is the last element - 1.
                boundaryTag = selectionCell{end-1};
            else
                obj.extrude.set('createselection', 'off');
                obj.workPlane.set('createselection', 'on');
                selectionCell = cell(obj.workPlane.outputSelection());
                % For workplane bnd is the last element.
                boundaryTag = selectionCell{end};
            end
            
            % Not so nice way to access selection from model.selection.
            % Since geometry selections seperate levels with dots.
            boundaryTag = strrep(boundaryTag, '.', '_');
            
            % <gtag>_<trimmedseltag>_<lvl>
            boundaryTag = [char(obj.hModel.geom.tag()) '_' boundaryTag];
        end
        
        
        function domainTag = get.domainTag(obj)
            
            import com.comsol.model.*;
            
            if obj.extrude.isActive() % Check if non-zero thickness layer.
                selectionCell = cell(obj.extrude.outputSelection());

                % Assume we are interested in domains. Their selection name
                % is the last element.
                domainTag = selectionCell{end};

                % Not so nice way to access selection from model.selection.
                % Since geometry selections seperate levels with dots.
                domainTag = strrep(domainTag, '.', '_');

                % <gtag>_<trimmedseltag>_<lvl>
                domainTag = [char(obj.hModel.geom.tag()) '_' domainTag];
            else
                warning('distance is 0. No domains defined.');
                domainTag = '';
            end
        end
    
        
        function layerName = get.name(obj)
            
            import com.comsol.model.*;
            
            layerName = char(obj.extrude.name());
            
            % Ensure the same name is set for the workplane.
            obj.workPlane.name([obj.WORKPLANE_NAME_PREFIX layerName]);
        end
        
        
        function obj =  set.name(obj, newName)
            
            import com.comsol.model.*;
            
            assert(ischar(newName) && ~isempty(newName), ...
                'The new name %s is not valid.', newName);
            
            obj.extrude.name(newName);
            obj.workPlane.name([obj.WORKPLANE_NAME_PREFIX newName]);
        end
        
        
        function distance = get.distance(obj)
            
            import com.comsol.model.*;
            
            if obj.extrude.isActive() % Check if non-zero thickness layer.
                distance = obj.extrude.getDoubleArray('distance');
            else
                distance = 0;
            end
        end
        
        
        function obj =  set.distance(obj, newDistance)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newDistance) && ~isempty(newDistance), ...
                   'The new distance is not valid.');
            
            if all(newDistance ~= 0) % Layer has finite thickness.
                obj.extrude.active(true);
                obj.extrude.set('distance', newDistance);
            else % Layer has zero thickness.
                obj.extrude.active(false);
            end
            obj.update_selection();
        end
        
        
        function zPosition = get.zPosition(obj)
            
            import com.comsol.model.*;
            
            zPosition = char(obj.workPlane.getString('quickz'));
            if ~isnan(str2double(zPosition))
                zPosition = str2double(zPosition);
            end
        end
        
        
        function obj = set.zPosition(obj, newPosition)
            
            import com.comsol.model.*;
            
            assert((isnumeric(newPosition) && isscalar(newPosition)) || ischar(newPosition), ...
                   'The new position is not valid.');
            
            obj.workPlane.set('quickz', newPosition);
        end
        
        
        function polygonCell = get.polygonCell(obj)
            
            import com.comsol.model.*;
            
            itr = obj.workPlane.geom.feature().iterator;
            polygonCell = {};

            while itr.hasNext()
                feature = itr.next();
                featureType = char(feature.getType());

                if strcmp(featureType, 'Polygon')
                    coordinates = feature.getDoubleMatrix('table');
                    polygonCell{end+1} = coordinates;
                end
            end
        end
        
        
        function obj = set.polygonCell(obj, newCell)
            
            import com.comsol.model.*;
            
            assert(iscell(newCell), 'Input must be a cell.');
            
            itr = obj.workPlane.geom.feature().iterator;
            indexCell = 1;
            nPolygons = 0;
            
            % While there are polygon features, update their table. Ensure,
            % that newCell has eneugh coordinateArrays.
            while itr.hasNext() && indexCell <= length(newCell)
                feature = itr.next();
                featureType = char(feature.getType());

                if strcmp(featureType, 'Polygon')
                    coordinateArray = newCell{indexCell};
                    
                    assert(isnumeric(coordinateArray) && ...
                           size(coordinateArray, 2) == 2 && ...
                           ~isempty(coordinateArray), ...
                           'Coordinates at index %d are not valid.', ...
                            indexCell);
                       
                    feature.set('table', coordinateArray);
                    indexCell = indexCell + 1;
                    nPolygons = nPolygons + 1;
                end
            end
            
            % While newCell contains additional polygons, add them.
            while nPolygons < length(newCell)
                coordinateArray = newCell{indexCell};
                    
                assert(isnumeric(coordinateArray) && ...
                       size(coordinateArray, 2) == 2 && ...
                       ~isempty(coordinateArray), ...
                       'Coordinates at index %d are not valid.', ...
                       indexCell);
                       
                obj.add_poly(coordinateArray);
                indexCell = indexCell + 1;
                nPolygons = nPolygons + 1;
            end
            
            % While there are too many polygon features, delete them.
            % First skip polygons defined in newCell.
            itr = obj.workPlane.geom.feature().iterator;
            indexCell = 1;
            while itr.hasNext() && indexCell <= length(newCell)
                feature = itr.next();
                featureType = char(feature.getType());

                if strcmp(featureType, 'Polygon')
                    indexCell = indexCell + 1;
                end
            end
            % Delete the rest.
            while itr.hasNext()
                feature = itr.next();
                featureType = char(feature.getType());

                if strcmp(featureType, 'Polygon')
                    % Remove feature from feature list by tag.
                    obj.workPlane.geom.feature().remove(feature.tag());
                end
            end
        end
        
        
        function obj = edit_polygon_cell(obj)
            % edit_polygon_cell Edit/add polygons by mouse.
            %
            % edit_polygon_cell(obj)
            %
            %  Usage:
            %  Add polygons by vertex. Double-click inside to confirm
            %  position. Double click inside the red polygon to start new
            %  polygons. Close the figure to finish.
            
            hFigure = figure();
            
            % API: https://docs.oracle.com/javase/7/docs/ ...
            % api/java/util/LinkedList.html
            coordinateList = java.util.LinkedList(); % Jave linked list.
            
            set(hFigure, 'Name', ['Edit polygonCell vertices. ' ...
                'Double-click inside to confirm position. ' ...
                'Close the figure to finish. ' ...
                'Click in red one to start draw new polygons.']);
            obj.hModel.layerArray.plot('Color', [0.6 0.6 0.6]);
            
            % Retrive existing polygon coordinates.
            polygonCell = obj.polygonCell;
            
            % Maintain a handle to the last polygon created.
            lastHandle = impoly.empty();
            
            % Add existing polygons first.
            for polygon = polygonCell
                hPolygon = impoly(gca, polygon{1}, 'Closed', true);
                lastHandle = hPolygon;
                coordinateList.add(polygon{1});
                
                % This is java indexing starting from 0.
                currentIndex = coordinateList.size-1;
                % Update changes in the polygon using a listener.
                addNewPositionCallback(hPolygon, ...
                    @(pos) coordinateList.set(currentIndex, pos));
            end
            
            % Idle till the user double-clicks inside the last red polygon.
            if ~isempty(lastHandle)
                lastHandle.setColor('r');
                wait(lastHandle);
            end
            
            % Add polygons till the figure is closed.
            while ishandle(hFigure)
                try
                    hPolygon = impoly('Closed', true);
                    coordinateList.add(wait(hPolygon)); % Get coordinates.
                    % This is java indexing starting from 0.
                    currentIndex = coordinateList.size-1;
                    % Update changes in the polygon using a listener.
                    addNewPositionCallback(hPolygon, ...
                        @(pos) coordinateList.set(currentIndex, pos));
                catch
                end
            end
            
            % Add valid polygons to polygonCell.
            itr = coordinateList.iterator;
            polygonCell = {};
            while itr.hasNext()
                position = itr.next();
               
                if ~isempty(position)
                    if size(position, 1) < 3
                        warning('Skipping a polygon. Too few points.');
                        continue;
                    end
                    
                    % Check if polygon is closed.
                    if position(1,1) ~= position(end,1) || ...
                       position(1,2) ~= position(end,2)
                        % Make the polygon closed.
                        position = [ position; position(1,:)];
                    end
                    
                    polygonCell{end+1} = position;
                end
            end
            
            % Set the new coordinates in the model.
            obj.polygonCell = polygonCell;
        end
        
        
        function delete(obj)
            % delete Removes the workplane/extrude-feature from the model.
            %
            %  delete(obj)
            
            import com.comsol.model.*;
            try
                obj.hModel.geom.feature().remove(obj.extrudeTag);
            catch
                warning('Could not remove Layer %s Ext. from server.', ...
                        obj.extrudeTag);
            end
            try
                obj.hModel.geom.feature().remove(obj.workPlaneTag);
            catch
                warning('Could not remove Layer %s Wrp. from server.', ...
                        obj.workPlaneTag);
            end                
        end
        
        
        function polyTag = add_poly(obj, coordinateArray)
            % add_poly Adds a polygon defined by an n x 2 array.
            %
            %  polyTag = add_poly(obj, coordinateArray)
            
            import com.comsol.model.*;
            
            assert(isnumeric(coordinateArray) && ...
                   size(coordinateArray, 2) == 2 && ...
                   ~isempty(coordinateArray), ...
                   'Coordinates are not valid.');
               
            
            polyTag = char(obj.workPlane.geom.feature().uniquetag( ...
                obj.BASE_TAG_POLY));
            poly = obj.workPlane.geom.feature.create(polyTag, 'Polygon');
            poly.set('source', 'table');
            poly.set('table', coordinateArray);
        end
        
        
        function clear_workplane(obj)
            % clear_workplane Clears the workplan geometry feature list.
            %
            %  clear_workplane(obj)
            
            import com.comsol.model.*;
            
            obj.workPlane.geom.feature().clear();
        end


        function st = info_struct(obj)
            % info_struct Generates information struct about the object.
            %
            %  st = info_struct(obj)
            
            maxDistance = max([obj.distance(:) 0]);
            minDistance = min([obj.distance(:) 0]);

            st = struct('class', class(obj), ...
                         'name', obj.name, ...
                         'zPos', obj.zPosition, ...
                          'thickness', maxDistance - minDistance);
        end

        
        function str = info_string(obj)
            % info_string Generates information string about the object.
            %
            %  str = info_string(obj)
            
            maxDistance = max([obj.distance(:) 0]);
            minDistance = min([obj.distance(:) 0]);

            str = sprintf('%-30s %-30s %-15f %-15f', class(obj), ...
                          obj.name, obj.zPosition, ...
                          maxDistance - minDistance);
        end
        
        
        function indexCell = choose_polygon_indices(obj)
            % choose_polygon_indices Returns mask of selected indices.
            %
            %  indexCell = choose_polygon_indices(obj)
            %
            %  Usage:
            %  Draw a polygon selection around the region of interest and
            %  double-click inside the polygon.
            
            objArray = [ obj ];
            assert(isscalar(objArray), 'This function is not vectorized.');
            
            f = figure;
            set(f, 'Name', ['Select a closed region and double-click ' ...
                'inside to confirm.']);
            obj.plot();
            h = impoly('Closed', true);
            pos = wait(h);
            
            polygonCell = obj.polygonCell;
            indexCell = {};
            for polygon = polygonCell
                xPolygon = polygon{1}(:,1);
                yPolygon = polygon{1}(:,2);
                xSelection = pos(:,1);
                ySelection = pos(:,2);
                
                % Returns indices inside the selection region.
                in = inpolygon(xPolygon, yPolygon, xSelection, ySelection);
                
                indexCell{end+1} = in;
            end
            
            close(f);
        end 
    end
    methods(Sealed)
        function plot(obj, varargin)
            % plot Plots workplane features.
            %
            %  plot(obj, varargin)
            %
            %  Parameters:
            %  Names: Print layer names in the plot (default: 'off')
            %  View: Use matlab plot function '2D' or mphviewselection
            %        '3D' (default: '2D')
            %  varargin: Passed on to the plot function. See help plot for
            %            '2D' and help mphviewselection for '3D'
            
            % Collect objs on vectorised function call. This function works
            % vectorized and has therefore to be sealed in a polymorphic
            % scenario.
            
            import com.comsol.model.*;
            
            objArray = [ obj ];
            
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'Names', 'off', @ischar);
            addParameter(p, 'View', '2D', @ischar);
            parse(p,varargin{:});
            
            hold on; % Will draw into open figure with this.
            axis equal; % Maintain proportions of geometry.
            
            for layer = objArray
                
                switch p.Results.View
                    case '2D'
                        % Use java iterator, since GeomFeatureList has a
                        % java.lang.Iterable interface.
                        itr = layer.workPlane.geom.feature().iterator;

                        while itr.hasNext()
                            feature = itr.next();
                            featureType = char(feature.getType());

                            %disp(featureType);
                            switch featureType
                                case 'Polygon'
                                    coordinates = ...
                                        feature.getDoubleMatrix('table');

                                    plot(coordinates(:,1), ...
                                         coordinates(:,2), ...
                                         'red', p.Unmatched);

                                    if strcmp(p.Results.Names, 'on')
                                        meanCoord = mean(coordinates, 1);
                                        text(meanCoord(1), ...
                                             meanCoord(2), ...
                                             layer.name, ...
                                             'Interpreter', 'none');
                                    end
                                otherwise
                                    warning(['Skipping feature %s. ' ...
                                             'Type %s not implemented. '
                                             'Update plot().'], ...
                                             char(feature.tag()), ...
                                             featureType);
                            end
                        end
                    case '3D'
                        % mphviewselection does not accept a struct with
                        % Parameter/value pairs. It has to be a cell.
                        fNames = fieldnames(p.Unmatched);
                        sValues = struct2cell(p.Unmatched);
                        v = {fNames{:}; sValues{:}}; % 2 x n cell.
                        v = {v{:}}; % Exploit linear indexing.
                        
                        mphviewselection(obj.hModel.model, ...
                                         obj.domainTag, ...
                                         'facealpha', 0.5, v{:});
                    otherwise
                        warning('View value %s not implemented', ...
                                p.Results.View);
                end
            end
            
            hold off;
        end
    end
    methods(Static)
        function clear_geometry_features(hModel)
            % clear_geometry_features Removes by tag pattern BASE_TAG*.
            %
            %  clear_geometry_features(hModel)
            %
            %  Parameters:
            %  hModel: ComsolModel object or a derived object.
            
            import com.comsol.model.*;
            
            itr = hModel.geom.feature().iterator;
            removeCell = {};
            while itr.hasNext()
                feature = itr.next();
                featureTag = char(feature.tag());
                
                isExtrude = strncmp(featureTag, ...
                              comsolkit.Layer.BASE_TAG_EXTRUDE, ...
                              length(comsolkit.Layer.BASE_TAG_EXTRUDE));
                isWorkplane = strncmp(featureTag, ...
                              comsolkit.Layer.BASE_TAG_WORKPLANE, ...
                              length(comsolkit.Layer.BASE_TAG_WORKPLANE));

                if isExtrude || isWorkplane
                    %hModel.geom.feature().remove(featureTag);
                    removeCell{end+1} = featureTag;
                end
            end
            % Does not work from inside the iterator. Concurrency error.
            for featureTag = removeCell
                hModel.geom.feature().remove(featureTag{1});
            end
        end
    end
end
