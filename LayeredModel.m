classdef LayeredModel < comsolkit.ComsolModel
    % LayeredModel Inherits from ComsolModel and adds layer functionality.
    
    properties
        layerArray % Contains Layer object handles.
    end
    properties(Constant)
        LAYER_NAME_BASE = 'layer'; % Base name for batch_add_layer.
    end
    
    methods
        function obj = LayeredModel(varargin)
            % LayeredModel Creates a comsol model object supporting layers.
            %
            %  LayeredModel(varargin)
            %
            %  Parameters:
            %  FromFile: Load from a mph-file on the file system
            %  FromTag: Load from an existing model on the server by tag
            %  %%% parameters below only for new models %%%
            %  LengthUnit: Length of a unit in meters (default: 1e-9)
            %  GeomDimension: Dimensions of the model (default: 3)
            
            % Call super constructor with explicit 3d geometry.
            obj = obj@comsolkit.ComsolModel(varargin{:}, ...
                                            'GeomDimension', 3);
            
            % Prepare array for Layer objects.
            obj.layerArray = comsolkit.Layer.empty;
        end
        
        
        function [startIndex, stopIndex] = batch_add_layer(obj, ...
                                       coordinateCell, varargin)
            % batch_add_layer Creates layers with polygons per layer.
            %
            %  [startIndex, stopIndex] = batch_add_layer(obj, ...
            %                                            coordinateCell)
            %  [startIndex, stopIndex] = batch_add_layer(obj, ...
            %                                          coordinateCell, ...
            %                                          nameCell)
            %  [startIndex, stopIndex] = batch_add_layer(obj, ...
            %                           coordinateCell, nameCell, varargin)
            %
            %  Parameter:
            %  coordinateCell: Cell array of cell arrays with n x 2 
            %                  coorinate arrays: {{[...], ...}, {...}, ...}
            %  nameCell: Cell array of names per layer element (optional).
            %            If not provided, names are generated using a
            %            pattern based on LAYER_NAME_BASE
            %  varargin: Passed on to Layer object constructor. See help of
            %            comsolkit.Layer.Layer
            %
            %  Return Parameters:
            %  startIndex, stopIndex: Start/stop index of added layers to
            %                         layerArray
            
            if nargin < 3
                nameCell = {};
            else
                nameCell = varargin{1};
            end
            
            assert(iscell(coordinateCell) && iscell(nameCell), ...
                   'Input parameters not valid.');
            
            if isempty(nameCell) || ...
               length(nameCell) ~= length(coordinateCell)
                % Creates cell array of unique name strings.
                nameCell = sprintfc([obj.LAYER_NAME_BASE '%d'], ...
                                    1:length(coordinateCell));
            end
            
            startIndex = length(obj.layerArray) + 1;
            % Loop over input cell of coordinate arrays.
            for i = 1:length(coordinateCell)
                coordinateArrayCell = coordinateCell{i};
                name = nameCell{i};

                obj.layerArray(end+1) = comsolkit.Layer(obj, ...
                                                       varargin{2:end}, ... 
                                                       'Name', name);
                for coordinateArray = coordinateArrayCell
                    obj.layerArray(end).add_poly(coordinateArray{1});
                end
            end
            stopIndex = length(obj.layerArray);
        end
        
        
        function index = add_layer(obj, coordinateArrayCell, varargin)
            % add_layer Creates one layer with polygons.
            %
            %  index = add_layer(obj, coordinateArrayCell)
            %  index = add_layer(obj, coordinateArrayCell, name)
            %  index = add_layer(obj, coordinateArrayCell, name, varargin)
            %
            %  Parameter:
            %  coordinateArrayCell: Cell array with n x 2 
            %                  coorinate arrays: {[...], ...}
            %  name: Name of layer element (optional). If not provided,
            %        a name is generated from LAYER_NAME_BASE
            %  varargin: Passed on to Layer object constructor. See help of
            %            comsolkit.Layer.Layer
            %
            %  Return Parameters:
            %  index: Index of added layer to layerArray
            
            if nargin < 3
                index = obj.batch_add_layer({coordinateArrayCell});
            else
                name = varargin{1};
                index = obj.batch_add_layer({coordinateArrayCell}, ...
                                            {name}, ...
                                            varargin{2:end});
            end
        end
        
        
        function batch_remove_layer(obj, startIndex, stopIndex)
            % batch_remove_layer Remove layers from server and layerArray.
            %
            %  batch_remove_layer(obj, startIndex, stopIndex)
            
            assert(length(startIndex) == 1 && ...
                   length(stopIndex) == 1 && ...
                   startIndex >= 1 && ...
                   startIndex <= stopIndex && ...
                   stopIndex <= length(obj.layerArray), ...
                   'Start/stop index is not valid.');
               
            for i = startIndex:stopIndex
                obj.layerArray(i).delete();
            end
            % Mask the deleted Layer objects.
            obj.layerArray = obj.layerArray( ...
                             [1:startIndex-1 stopIndex+1:end]);
        end
        
        
        function remove_all_layers(obj)
            % remove_all_layers Remove all layers from layerArray.
            %
            %  remove_all_layers(obj)
            
            endIndex = length(obj.layerArray);
            
            obj.batch_remove_layer(1, endIndex);
        end
        
        
        function savedObj = saveobj(obj)
            % saveobj Saves the object including the comsol model.
            %
            % savedObj = saveobj(obj)
            
            savedObj = saveobj@comsolkit.ComsolModel(obj);
        end
    end
    methods(Static)
        function loadedObj = loadobj(obj)
            % loadobj Loads the object including the comsol model.
            %
            % loadedObj = loadobj(obj)
            
            loadedObj = loadobj@comsolkit.ComsolModel(obj);
        end
    end
end