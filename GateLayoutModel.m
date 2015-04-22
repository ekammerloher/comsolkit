classdef GateLayoutModel < comsolkit.LayeredModel
    % GateLayoutModel Inherits from LayeredModel and adds gates.
    
    properties(Dependent)
        es % Handle to the electrostatic physics feature.
    end
    properties(Constant)
        BASE_TAG_ES = 'es'; % Tag of electrostatic physics feature.
    end
    
    methods
        function obj = GateLayoutModel(varargin)
            % GateLayoutModel Creates a gate layout model.
            %
            %  GateLayoutModel(varargin)
            %
            %  Parameters:
            %  FromFile: Load from a mph-file on the file system
            %  FromTag: Load from an existing model on the server by tag
            %  %%% parameters below only for new models %%%
            %  LengthUnit: Length of a unit in meters (default: 1e-9)
            
            obj = obj@comsolkit.LayeredModel(varargin{:});
            
            % Create electrostatics physics, if it does not exist.
            esIndex = obj.model.physics.index(obj.BASE_TAG_ES);
            
            if esIndex < 0
                obj.model.physics.create(obj.BASE_TAG_ES, ...
                                         'Electrostatics', ...
                                         obj.geom.tag());
            end
        end
        
        
        function es = get.es(obj)
            esIndex = obj.model.physics.index(obj.BASE_TAG_ES);
            
            assert(esIndex >= 0, 'Could not find electrostatics %s.', ...
                   obj.BASE_TAG_ES);
               
            es = obj.model.physics(obj.BASE_TAG_ES);
        end
        
        
        function savedObj = saveobj(obj)
            % saveobj Saves the object including the comsol model.
            %
            %  savedObj = saveobj(obj)
            
            savedObj = saveobj@comsolkit.ComsolModel(obj);
        end
    end
    methods(Static)
        function loadedObj = loadobj(obj)
            % loadobj Loads the object including the comsol model.
            %
            %  loadedObj = loadobj(obj)
            
            loadedObj = loadobj@comsolkit.ComsolModel(obj);
        end
    end
end

