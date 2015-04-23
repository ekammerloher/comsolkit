classdef Gate < comsolkit.Layer
    % Gate extends layer with electric potential functionality.
    
    properties(Dependent)
        voltage % Voltage applied to the gate.
        potential % Handle to the electric potential feature of Gate.
    end
    properties(Constant)
        BASE_TAG_POTENTIAL = 'layer_pot'; % Base potential string.
    end
    properties(Access=private)
        potentialTag % Tag to the electrostatic potential of the gate.
    end
    
    methods
        function obj = Gate(hModel, varargin)
            % Gate Creates a Gate object.
            %
            %  Gate(hModel)
            %  Gate(hModel, varargin)
            %
            %  Parameters:
            %  hModel: Required handle to parent ComsolModel type object
            %  Name: Common name of workpane and the extrude feature.
            %  Distance: Distance of layer. Can be monotonous array 
            %            (must be non-zero, pos/neg, default: 1)
            %  zPosition: z-Position of the layer (default: 0)
            %  Voltage: Voltage of the gate (default: 0)
            %  %%% when creating from existing extruded workplane/pot. %%%
            %  FromExtrudeTag: Tag of an existing extrude feature
            %  FromPotentialTag: Tag of an existing electric potential
            
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'FromPotentialTag', '', @ischar);
            addParameter(p, 'Voltage', 0, ...
                         @(x) isnumeric(x) && length(x) == 1);
            parse(p,varargin{:});
            
            obj = obj@comsolkit.Layer(hModel, p.Unmatched);
            
            if ~isempty(p.Results.FromPotentialTag)
                obj.potentialTag = p.Results.FromPotentialTag;
            else
                obj.potentialTag = obj.hModel.es.feature().uniquetag( ...
                                        obj.BASE_TAG_POTENTIAL);
                   
                potential = obj.hModel.es.feature.create( ...
                                obj.potentialTag, 'ElectricPotential', 2);
                            
                potential.selection.named(obj.selectionTag);
                potential.label(obj.name);
            end
            
            obj.voltage = p.Results.Voltage;
        end
        
        
        function potential = get.potential(obj)
            
            import com.comsol.model.*;
            
            hasPotential = obj.hModel.es.feature().index(obj.potentialTag);
                
            assert(hasPotential >= 0, '%s has no potential %s.', ...
                   obj.hModel.es.tag(), obj.potentialTag); 
               
            potential = obj.hModel.es.feature(obj.potentialTag);
        end
        
        
        function voltage = get.voltage(obj)
            
            import com.comsol.model.*;
            
            voltage = str2double(obj.potential.getString('V0'));
        end
        
        
        function obj = set.voltage(obj, newVoltage)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newVoltage) && length(newVoltage) == 1, ...
                   'New voltage is not valid.');
               
            obj.potential.set('V0', newVoltage);
        end
    end
end