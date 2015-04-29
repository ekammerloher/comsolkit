% Based on: http://de.mathworks.com/help/matlab/ref/ ...
% matlab.mixin.heterogeneous-class.html
classdef Layer < matlab.mixin.Heterogeneous % Necessary for polymorphy.
    % Layer Bundles a comsol workplane and an extrude feature into an unit.
    
    properties(Dependent)
        name % Common name of the workplane and the extrude feature.
        distance % The extrude distance from zPosition.
        zPosition % z-Position of the layer in the model.
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
            %  Distance: Distance of layer. Can be monotonous array 
            %            (must be non-zero, pos/neg, default: 1)
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
                @(x) isnumeric(x) && isscalar(x));
            
            p.parse(varargin{:});
            
            if isempty(p.Results.FromExtrudeTag)
                workPlaneTag = char(hModel.geom.feature().uniquetag( ...
                    obj.BASE_TAG_WORKPLANE));
                obj.extrudeTag = char(hModel.geom.feature().uniquetag( ...
                    obj.BASE_TAG_EXTRUDE));
                
                % Setup workplane.
                workPlane = hModel.geom.feature().create(workPlaneTag, ...
                                                         'WorkPlane');
                workPlane.set('quickplane', 'xy');
                
                % Setup extrude. Will use previous workplane automatically.
                extrude = hModel.geom.feature().create(obj.extrudeTag, ...
                                                       'Extrude');
                extrude.set('createselection', 'on');
                extrude.selection('input').set(workPlaneTag);
                
            else % Check extrude feature, when constructing from a tag.
                obj.extrudeTag = p.Results.FromExtrudeTag;
                
                % Use getter of extrude.
                extrudeFrom = char(obj.extrude.getString('extrudefrom'));

                assert(strcmp(extrudeFrom, 'workplane'), ...
                              ['Extrude feature must extrude from a ' ...
                               'workplane and not a face.']);
            end
            
            % Use setters to assign extrude feature and workplane
            % properties.
            obj.zPosition = p.Results.zPosition;
            obj.distance = p.Results.Distance;
                
            % Set common name, if provided. Use setter.
            if ~isempty(p.Results.Name)
                obj.name = p.Results.Name;
            end
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
            
            % The extrude feature could have multiple workplanes as inputs.
            % Just assume one for our usecase.
            inputObjectCell = cell( ...
                obj.extrude.selection('input').objects());
            
            assert(isscalar(inputObjectCell), ...
                   ['Layer expects one workplane for the extrude ' ...
                    'feature. Found %d.'], length(inputObjectCell));
                            
            workplaneIndex = ...
                obj.hModel.geom.feature().index(inputObjectCell{1});
            
            assert(workplaneIndex >= 0, 'Could not find workplane %s.', ...
                   inputObjectCell{1});
            
            workPlane = obj.hModel.geom.feature(inputObjectCell{1});
        end
        
        
        function boundaryTag = get.boundaryTag(obj)
            
            import com.comsol.model.*;
            
            selectionCell = cell(obj.extrude.outputSelection());
            
            % Assume we are interested in boundaries. Their selection name
            % is the last element - 1.
            boundaryTag = selectionCell{end-1};
            
            % Not so nice way to access selection from model.selection.
            % Since geometry selections seperate levels with dots.
            boundaryTag = strrep(boundaryTag, '.', '_');
            
            % <gtag>_<trimmedseltag>_<lvl>
            boundaryTag = [char(obj.hModel.geom.tag()) '_' boundaryTag];
        end
        
        
        function domainTag = get.domainTag(obj)
            
            import com.comsol.model.*;
            
            selectionCell = cell(obj.extrude.outputSelection());
            
            % Assume we are interested in domains. Their selection name
            % is the last element.
            domainTag = selectionCell{end};
            
            % Not so nice way to access selection from model.selection.
            % Since geometry selections seperate levels with dots.
            domainTag = strrep(domainTag, '.', '_');
            
            % <gtag>_<trimmedseltag>_<lvl>
            domainTag = [char(obj.hModel.geom.tag()) '_' domainTag];
        end
    
        
        function layerName = get.name(obj)
            
            import com.comsol.model.*;
            
            layerName = char(obj.extrude.label());
            
            % Ensure the same name is set for the workplane.
            obj.workPlane.label([obj.WORKPLANE_NAME_PREFIX layerName]);
        end
        
        
        function obj =  set.name(obj, newName)
            
            import com.comsol.model.*;
            
            assert(ischar(newName) && ~isempty(newName), ...
                'The new name %s is not valid.', newName);
            
            obj.extrude.label(newName);
            obj.workPlane.label([obj.WORKPLANE_NAME_PREFIX newName]);
        end
        
        
        function distance = get.distance(obj)
            
            import com.comsol.model.*;
            
            distance = obj.extrude.getDoubleArray('distance');
        end
        
        
        function obj =  set.distance(obj, newDistance)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newDistance) && ~isempty(newDistance), ...
                   'The new distance is not valid.');
            
            obj.extrude.set('distance', newDistance);
        end
        
        
        function zPosition = get.zPosition(obj)
            
            import com.comsol.model.*;
            
            zPosition = obj.workPlane.getDouble('quickz');
        end
        
        
        function obj = set.zPosition(obj, newPosition)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newPosition) && isscalar(newPosition), ...
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
        
        
        function delete(obj)
            % delete Removes the workplane/extrude-feature from the model.
            %
            %  delete(obj)
            
            import com.comsol.model.*;
            
            try
                workplaneTag = obj.workPlane.tag();
                obj.hModel.geom.feature().remove(obj.extrudeTag);
                obj.hModel.geom.feature().remove(workplaneTag);
            catch
                warning('Could not remove Layer %s from server.', ...
                        obj.extrudeTag);
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