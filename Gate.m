classdef Gate < comsolkit.Layer
    % Gate extends layer with electric potential functionality.
    
    methods
        function obj = Gate(varargin)
            obj = obj@comsolkit.Layer(varargin{:});
        end
    end
end