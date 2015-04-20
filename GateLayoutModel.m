classdef GateLayoutModel < comsolkit.LayeredModel
    %LayeredModel Inherits from ComsolModel and adds layer functionality.
    
    properties
    end
    
    methods
        function obj = GateLayoutModel(varargin)
            obj = obj@comsolkit.LayeredModel(varargin{:});
        end
        
        
        function savedObj = saveobj(obj)
            % saveobj Saves the object including the comsol model.
            savedObj = saveobj@comsolkit.ComsolModel(obj);
        end
    end
    methods(Static)
        function loadedObj = loadobj(obj)
            % loadobj Loads the object including the comsol model.
            loadedObj = loadobj@comsolkit.ComsolModel(obj);
        end
    end
end

