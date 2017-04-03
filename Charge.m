classdef Charge < comsolkit.Layer
    % Gate extends layer with electric potential functionality.
    
    properties(Dependent)
        charge    % actual charge
        chargeHandle % Handle to the Charge feature .
    end
    properties(Constant)
        BASE_TAG_CHARGE = 'layer_charge'; % Base charge string.
    end
    properties(Access=private)
        chargeTag
        potentialTag % Tag to the electrostatic potential of the gate.
%         floatingTag % Tag to the floating potential of the gate.
    end
    
    methods
        function obj = Charge(hModel, varargin)
            % Charge Creates a Charge object.
            %
            %  Charge(hModel)
            %  Charge(hModel, varargin)
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

            assert(isa(hModel, 'comsolkit.GateLayoutModel'), ...
                   'hModel has to be of class comsolkit.GateLayoutModel');
            
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'FromPotentialTag', '', @ischar);
            addParameter(p, 'Qp', 0, ...
                         @(x) isnumeric(x) && isscalar(x));
            parse(p,varargin{:});
            
            obj = obj@comsolkit.Layer(hModel, p.Unmatched);
            
            if ~isempty(p.Results.FromPotentialTag)
                obj.chargeTag = p.Results.FromPotentialTag;
            else
                obj.chargeTag = obj.hModel.es.feature().uniquetag( ...
                                        obj.BASE_TAG_CHARGE);
                   
                chargeHandle = obj.hModel.es.feature.create( ...
                                obj.chargeTag, 'PointCharge');
                            
                chargeHandle.selection.named(obj.pointTag);
                chargeHandle.name(obj.name);
            end
            
            obj.charge = p.Results.Qp;
            
        end        
        
        function chargeHandle = get.chargeHandle(obj)
            
            import com.comsol.model.*;
            
            hasCharge = obj.hModel.es.feature().index(obj.chargeTag);
                
            assert(hasCharge >= 0, '%s has no potential %s.', ...
                   obj.hModel.es.tag(), obj.chargeTag); 
               
            chargeHandle = obj.hModel.es.feature(obj.chargeTag);
            chargeHandle.name(obj.name);
        end
        
        function obj = set.charge(obj, newCharge)
            
            import com.comsol.model.*;
            
            assert(isnumeric(newCharge) && isscalar(newCharge), ...
                   'New Charge is not valid.');
            
            obj.chargeHandle.set('Qp', newCharge);
                        
            obj.chargeHandle.active(true);
           
        end
        
        function charge = get.charge(obj)
            
            import com.comsol.model.*;
                       
            charge = str2double(obj.hModel.es.feature(obj.chargeTag).getString('Qp'));
        end             
        
               
        function delete(obj)
            % delete Removes the workplane/extrude/potential from the model.
            %
            %  delete(obj)
            
            delete@comsolkit.Layer(obj);
            try
                obj.hModel.es.feature().remove(obj.chargeTag);
            catch
                warning('Could not remove Charge %s from server.', ...
                        obj.chargeTag);
            end
        end
        
        
        function str = info_string(obj)
            % info_string Generates information string about the object.
            %
            %  str = info_string(obj)
            
            str = info_string@comsolkit.Layer(obj);
            str = sprintf('%s charge: %f', str, obj.charge);
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
                              comsolkit.Gate.BASE_TAG_CHARGE, ...
                              length(comsolkit.Gate.BASE_TAG_CHARGE));

                isFloating = strncmp(featureTag, ...
                             comsolkit.Gate.BASE_TAG_CHARGE, ...
                             length(comsolkit.Gate.BASE_TAG_CHARGE));

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