%model.component("comp1").physics("es").create("term5", "Terminal", 2);
%model.component("comp1").physics("es").feature("term5").selection().named("geom1_ext3_bnd");
%model.component("comp1").physics("es").feature("term5").set("TerminalType", "Voltage");

classdef Terminal < comsolkit.Layer
    % Terminal extends layer with electric potential functionality.
    
    properties(Dependent)
        voltage % Voltage applied to the Terminal.
        terminal % Handle to the electric potential feature of Gate.
    end
    properties(Constant)
        BASE_TAG_TERMINAL = 'layer_ter'; % Base terminal string.
    end
    properties(Access=private)
        terminalTag % Tag to the electrostatic potential of the gate.
    end
    
    methods
        function obj = Terminal(hModel, varargin)
            % Terminal Creates a Terminal object.
            %
            %  Terminal(hModel)
            %  Terminal(hModel, varargin)
            %
            %  Parameters:
            %  hModel: Required handle to parent ComsolModel type object
            %  Name: Common name of workpane and the extrude feature.
            %  Distance: Distance of layer. Can be monotonous array 
            %            (pos/neg, default: 1)
            %  zPosition: z-Position of the layer (default: 0)
            %  Voltage: Voltage of the term. Can be parameter. (default: 0)
            %  %%% when creating from existing extruded workplane/pot. %%%
            %  FromExtrudeTag: Tag of an existing extrude feature
            %  FromTerminalTag: Tag of an existing electric potential

            assert(isa(hModel, 'comsolkit.GateLayoutModel'), ...
                   'hModel has to be of class comsolkit.GateLayoutModel');
            
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'FromTerminalTag', '', @ischar);
            addParameter(p, 'Voltage', 0, ...
                         @(x) (isnumeric(x) && isscalar(x)) || ischar(x));
            parse(p,varargin{:});
            
            obj = obj@comsolkit.Layer(hModel, p.Unmatched);
            
            if ~isempty(p.Results.FromTerminalTag)
                obj.terminalTag = p.Results.FromTerminalTag;
            else
                obj.terminalTag = obj.hModel.es.feature().uniquetag( ...
                                        obj.BASE_TAG_TERMINAL);
                   
                terminal = obj.hModel.es.feature.create( ...
                                obj.terminalTag, 'Terminal', 2);
                            
                terminal.selection.named(obj.boundaryTag);
                terminal.name(obj.name);
                terminal.set('TerminalType', 'Voltage');
            end
            
            try
                obj.voltage = p.Results.Voltage;
            catch ME
                warning('Error caugt. Clear gate features and rethrow.');
                obj.delete()
                rethrow(ME);
            end
        end
        
        
        function update_selection(obj)
            % Skip this, when constructing the object.
            if obj.hModel.es.feature().index(obj.terminalTag) >=0
                obj.terminal.selection.named(obj.boundaryTag);
            end
        end
        
            
        function terminal = get.terminal(obj)
            
            import com.comsol.model.*;
            
            hasTerminal = obj.hModel.es.feature().index(obj.terminalTag);
                
            assert(hasTerminal >= 0, '%s has no terminal %s.', ...
                   obj.hModel.es.tag(), obj.terminalTag); 
               
            terminal = obj.hModel.es.feature(obj.terminalTag);
            terminal.name(obj.name);
        end
        
        
        function voltage = get.voltage(obj)
            
            import com.comsol.model.*;
            
            if obj.terminal.isActive()
                voltage = char(obj.terminal.getString('V0'));
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
            
            obj.terminal.set('V0', newVoltage);
        end
        
        
        function delete(obj)
            % delete Removes the workplane/extrude/potential from the model.
            %
            %  delete(obj)
            
            try
                obj.hModel.es.feature().remove(obj.terminalTag);
            catch
                warning('Could not remove Terminal %s from server.', ...
                        obj.terminalTag);
            end
            
            delete@comsolkit.Layer(obj);
        end
        
        
        function st = info_struct(obj)
            % info_struct Generates information struct about the object.
            %
            %  st = info_struct(obj)

            st = info_struct@comsolkit.Layer(obj);
            st.voltage = obj.voltage;
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
        % TODO: Update this for terminal in all classes.
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
