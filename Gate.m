classdef Gate < comsolkit.Layer
    % Gate extends layer with electric potential functionality.
    
    properties(Dependent)
        voltage % Voltage applied to the gate.
    end
    properties(Constant)
        BASE_TAG_POTENTIAL = 'layer_pot'; % Base potential string.
    end
    properties(Access=private)
        potentialTag % Tag to the electrostatic potential of the gate.
    end
    
    methods
        function obj = Gate(varargin)
            
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'FromPotentialTag', '', @ischar);
            addParameter(p, 'Voltage', 0, ...
                         @(x) isnumeric(x) && length(x) == 1);
            parse(p,varargin{:});
            
            obj = obj@comsolkit.Layer(p.Unmatched);
            
            if ~isEmpty(p.Results.FromPotentialTag)
                obj.potentialTag = p.Results.FromPotentialTag;
                
                hasPotential = obj.hModel.es.feature().index( ...
                                obj.potentialTag);
                
                assert(hasPotential, '%s has no potential %s.', ...
                       obj.hModel.es.tag(), obj.potentialTag); 
            else
                obj.potentialTag = obj.hModel.es.feature().uniquetag( ...
                                        obj.BASE_TAG_POTENTIAL);
                   
                potential = obj.hModel.es.feature.create( ...
                                obj.potentialTag, 'ElectricPotential', 3);
                            
                potential.selection.named(obj.selectionTag);
                potential.label(obj.name);
            end
        end
    end
end