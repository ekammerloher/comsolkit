classdef Layer < handle
    % Layer Bundles a comsol workplane and an extrude feature into an unit.
    
    properties(Dependent)
        name % Common name of the workplane and the extrude feature.
        distance % The extrude distance from zPosition.
        zPosition % z-Position of the layer in the model.
        workPlane % Handle to the workplane feature of Layer.
        extrude % Handle to the extrude feature of Layer.
        selectionTag % Tag of the extrude domain selection feature.
    end
    properties(Constant)
        BASE_TAG_WORKPLANE = 'layer_wp'; % Base wp string for uniquetag.
        BASE_TAG_EXTRUDE = 'layer_ext'; % Base ext string for uniquetag.
        BASE_TAG_POLY = 'dyn_poly'; % Base poly string for uniquetag.
        WORKPLANE_NAME_PREFIX = 'wp_'; % Prefix of workplane label.
    end
    properties(Access=private)
        extrudeTag % Access extrude distance in extrude feature.
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
                @(x) isnumeric(x) && length(x) == 1);
            
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
            
            assert(length(inputObjectCell) == 1, ...
                   ['Layer expects one workplane for the extrude ' ...
                    'feature. Found %d.'], length(inputObjectCell));
                            
            workplaneIndex = ...
                obj.hModel.geom.feature().index(inputObjectCell{1});
            
            assert(workplaneIndex >= 0, 'Could not find workplane %s.', ...
                   inputObjectCell{1});
            
            workPlane = obj.hModel.geom.feature( inputObjectCell{1});
        end
        
        
        function selectionTag = get.selectionTag(obj)
            
            import com.comsol.model.*;
            
            selectionCell = cell(obj.extrude.outputSelection());
            
            % Assume we are interested in domains. Their selection name is
            % the last element.
            domainTag = selectionCell{end};
            
            % Not so nice way to access selection from model.selection.
            % Since geometry selections seperate levels with dots.
            domainTag = strrep(domainTag, '.', '_');
            
            % <gtag>_<trimmedseltag>_<lvl>
            selectionTag = [char(obj.hModel.geom.tag()) '_' domainTag];
        end
    
        
        function layerName = get.name(obj)
            
            import com.comsol.model.*;
            
            layerName = char(obj.extrude.label());
            
            % Ensure the same name is set for the workplane.
            obj.workPlane.label([obj.WORKPLANE_NAME_PREFIX layerName]);
        end
        
        
        function set.name(obj, newName)
            
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
        
        
        function set.distance(obj, newDistance)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newDistance) && ~isempty(newDistance), ...
                   'The new distance is not valid.');
            
            obj.extrude.set('distance', newDistance);
        end
        
        
        function zPosition = get.zPosition(obj)
            
            import com.comsol.model.*;
            
            zPosition = obj.workPlane.getDouble('quickz');
        end
        
        
        function set.zPosition(obj, newPosition)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newPosition) && length(newPosition) == 1, ...
                   'The new position is not valid.');
            
            obj.workPlane.set('quickz', newPosition);
        end
        
        
        function delete(obj)
            % delete Removes the workplane/extrude-feature from the model.
            %
            %  delete(obj)
            
            import com.comsol.model.*;
            
            workplaneTag = obj.workPlane.tag();
            obj.hModel.geom.feature().remove(obj.extrudeTag);
            obj.hModel.geom.feature().remove(workplaneTag);
        end
        
        
        function polyTag = add_poly(obj, coordinateArray)
            % add_poly Adds a polygon defined by an n x 2 array.
            %
            %  polyTag = add_poly(obj, coordinateArray)
            
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
            
            obj.workPlane.geom.feature().clear();
        end
        
        
        function print(obj)
            % print Prints information string about the object.
            %
            %  print(obj)
            
            objArray = [ obj ]; % Collect objs on vectorised function call.
            
            for layer = objArray
                fprintf('%s(%s), zPosition: %f\n', layer.name, ...
                        class(layer), layer.zPosition);
            end
        end
    end
end