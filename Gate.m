classdef Gate < comsolkit.Layer
    % Gate extends layer with electric potential functionality.
    
    properties(Dependent)
        voltage % Voltage applied to the gate.
        potential % Handle to the electric potential feature of Gate.
    end
    properties(Constant)
        BASE_TAG_POTENTIAL = 'layer_pot'; % Base potential string.
        BASE_TAG_FLOATING = 'layer_fp'; % Base floating potential string.
        FLOATING_NAME_PREFIX = 'fp_'; % Prefix of floating potential label.
    end
    properties(Access=private)
        potentialTag % Tag to the electrostatic potential of the gate.
        floatingTag % Tag to the floating potential of the gate.
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
            %  Voltage: Voltage of the gate. Can be parameter. (default: 0)
            %  %%% when creating from existing extruded workplane/pot. %%%
            %  FromExtrudeTag: Tag of an existing extrude feature
            %  FromPotentialTag: Tag of an existing electric potential

            assert(isa(hModel, 'comsolkit.GateLayoutModel'), ...
                   'hModel has to be of class comsolkit.GateLayoutModel');
            
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'FromPotentialTag', '', @ischar);
            addParameter(p, 'Voltage', 0, ...
                         @(x) (isnumeric(x) && isscalar(x)) || ischar(x));
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
                potential.name(obj.name);
            end
            
            % Used to introduce floating potentials when voltage = NaN.
            obj.floatingTag = '';
            
            try
                obj.voltage = p.Results.Voltage;
            catch ME
                warning('Error caugt. Clear gate features and rethrow.');
                obj.delete()
                rethrow(ME);
            end
        end
        
        
        function update_selection(obj)
            if isnan(obj.voltage)
                if ~isempty(obj.floatingTag)
                    floating = obj.hModel.es.feature(obj.floatingTag);
                    floating.selection.named(obj.boundaryTag);
                end
            else
                obj.potential.selection.named(obj.boundaryTag);
            end
        end
        
            
        function potential = get.potential(obj)
            
            import com.comsol.model.*;
            
            hasPotential = obj.hModel.es.feature().index(obj.potentialTag);
                
            assert(hasPotential >= 0, '%s has no potential %s.', ...
                   obj.hModel.es.tag(), obj.potentialTag); 
               
            potential = obj.hModel.es.feature(obj.potentialTag);
            potential.name(obj.name);
        end
        
        
        function voltage = get.voltage(obj)
            
            import com.comsol.model.*;
            
            if obj.potential.isActive() % Check if floating potential.
                voltage = char(obj.potential.getString('V0'));
                if ~isnan(str2double(voltage))
                    voltage = str2double(voltage);
                end
            else
                voltage = NaN;
            end
        end
        
        
        function obj = set.voltage(obj, newVoltage)
            
            import com.comsol.model.*;
            
            assert((isnumeric(newVoltage) && isscalar(newVoltage)) || ischar(newVoltage), ...
                   'New voltage is not valid.');
            
            obj.potential.set('V0', newVoltage);
            
            if all(isnan(newVoltage))
                obj.potential.active(false);
                if isempty(obj.floatingTag)
                    obj.floatingTag = ...
                        obj.hModel.es.feature().uniquetag( ...
                        obj.BASE_TAG_FLOATING);
                    floating = obj.hModel.es.feature.create( ...
                               obj.floatingTag, 'FloatingPotential', 2);
                            
                    floating.selection.named(obj.boundaryTag);
                    floating.name([obj.FLOATING_NAME_PREFIX obj.name]);
                else
                    hasFloating = obj.hModel.es.feature().index( ...
                                    obj.floatingTag);
                
                    assert(hasFloating >= 0, '%s has no floating %s.', ...
                           obj.hModel.es.tag(), obj.floatingTag); 
               
                    floating = obj.hModel.es.feature(obj.floatingTag);
                    floating.active(true);
                    floating.name([obj.FLOATING_NAME_PREFIX obj.name]);
                end
                                        
                                    
            else
                obj.potential.active(true);
                if ~isempty(obj.floatingTag)
                    hasFloating = obj.hModel.es.feature().index( ...
                                        obj.floatingTag);

                    assert(hasFloating >= 0, '%s has no floating %s.', ...
                           obj.hModel.es.tag(), obj.floatingTag); 

                    floating = obj.hModel.es.feature(obj.floatingTag);
                    floating.active(false);
                    floating.name([obj.FLOATING_NAME_PREFIX obj.name]);
                end
            end
        end
        
        
        function delete(obj)
            % delete Removes the workplane/extrude/potential from the model.
            %
            %  delete(obj)
            
            try
                obj.hModel.es.feature().remove(obj.potentialTag);
                if ~isempty(obj.floatingTag)
                    obj.hModel.es.feature().remove(obj.floatingTag);
                end
                    
            catch
                warning('Could not remove Potential %s from server.', ...
                        obj.potentialTag);
            end
            
            delete@comsolkit.Layer(obj);
        end
        
        
        function str = info_string(obj)
            % info_string Generates information string about the object.
            %
            %  str = info_string(obj)
            
            str = info_string@comsolkit.Layer(obj);
            str = sprintf('%s voltage: %s', str, num2str(obj.voltage));
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

                isFloating = strncmp(featureTag, ...
                             comsolkit.Gate.BASE_TAG_FLOATING, ...
                             length(comsolkit.Gate.BASE_TAG_FLOATING));

                if isPotential || isFloating
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