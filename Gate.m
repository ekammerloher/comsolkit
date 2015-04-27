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
                         @(x) isnumeric(x) && isscalar(x));
            parse(p,varargin{:});
            
            obj = obj@comsolkit.Layer(hModel, p.Unmatched);
            
            if ~isempty(p.Results.FromPotentialTag)
                obj.potentialTag = p.Results.FromPotentialTag;
            else
                obj.potentialTag = obj.hModel.es.feature().uniquetag( ...
                                        obj.BASE_TAG_POTENTIAL);
                   
                potential = obj.hModel.es.feature.create( ...
                                obj.potentialTag, 'ElectricPotential', 2);
                            
                potential.selection.named(obj.boundaryTag);
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
            
            assert(isnumeric(newVoltage) && isscalar(newVoltage), ...
                   'New voltage is not valid.');
               
            obj.potential.set('V0', newVoltage);
        end
        
        
        function delete(obj)
            % delete Removes the workplane/extrude/potential from the model.
            %
            %  delete(obj)
            
            delete@comsolkit.Layer(obj);
            try
                obj.hModel.es.feature().remove(obj.potentialTag);
            catch
                warning('Could not remove Potential %s from server.', ...
                        obj.potentialTag);
            end
        end
        
        
        function str = info_string(obj)
            % info_string Generates information string about the object.
            %
            %  str = info_string(obj)
            
            str = info_string@comsolkit.Layer(obj);
            str = sprintf('%s voltage: %f', str, obj.voltage);
        end
    end
    methods(Static)
        function clear_es_features(hModel)
            % clear_es_features Removes by tag pattern BASE_TAG*.
            %
            %  clear_es_features(hModel)
            %
            %  Parameters:
            %  hModel: ComsolModel object or a derived object.
            
            import com.comsol.model.*;
            
            assert(isa(hModel, 'comsolkit.GateLayoutModel'), ...
                   'hModel has to be of class comsolkit.GateLayoutModel');
            
            itr = hModel.es.feature().iterator;
            removeCell = {};
            while itr.hasNext()
                feature = itr.next();
                featureTag = char(feature.tag());
                
                isPotential = strncmp(featureTag, ...
                              comsolkit.Gate.BASE_TAG_POTENTIAL, ...
                              length(comsolkit.Gate.BASE_TAG_POTENTIAL));
               
                if isPotential
                    removeCell{end+1} = featureTag;
                end
            end
            % Does not work from inside the iterator. Concurrency error.
            for featureTag = removeCell
                hModel.es.feature().remove(featureTag{1});
            end
        end    
    end    
end