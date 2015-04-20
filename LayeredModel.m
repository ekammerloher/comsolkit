classdef LayeredModel < comsolkit.ComsolModel
    % LayeredModel Inherits from ComsolModel and adds layer functionality.
    
    properties
    end
    
    methods
        function obj = LayeredModel(varargin)
            obj = obj@comsolkit.ComsolModel(varargin{:});
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