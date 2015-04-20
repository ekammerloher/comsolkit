classdef Layer
    % Layer Bundles a comsol workplane and an extrude feature into an unit.
    
    properties(Dependent)
        thickness % Thickness of the layer produced by the extrude feature.
        zPosition % z-Position of the layer in the model.
        workPlane % Handle to the workplane feature of Layer.
        extrude % Handle to the extrude feature of Layer.
        selectionTag % Tag of the extrude domain selection feature.
    end
    properties(Access=private)
        workPlaneTag % Keep the tag to access all workplane features.
        extrudeTag % Access extrude distance in extrude feature.
        hModel % Handle to a ComsolModel object or a derived object.
    end
    
    methods
        function obj = Layer(hModel, varargin)
            % Layer Creates a Layer object.
            %
            %  Parameters:
            %  hModel: Required handle to parent ComsolModel type object
            %  Thickness: Thickness of layer (must be non-zero, default: 1)
            %  zPosition: z-Position of the layer (default: 0)
            %  %%% when creating from existing extruded workplane %%%
            %  ExtrudeTag: Tag of an existing extrude feature
            
            import com.comsol.model.*;
            
            obj.hModel = hModel;
            
            p = inputParser();
            p.addParameter('ExtrudeTag', '', @ischar);
            p.addParameter('WorkPlaneTag', '', @ischar);
            p.addParameter('Thickness', 1, ...
                @(x) isnumeric(x) && length(x) == 1);
            p.addParameter('zPosition', 0, ...
                @(x) isnumeric(x) && length(x) == 1);
            
            p.parse(varargin{:});
            
            hasWorkPlaneTag = ~isempty(p.Results.WorkPlaneTag);
            hasExtrudeTag = ~isempty(p.Results.ExtrudeTag);
            
            if xor(hasWorkPlaneTag, hasExtrudeTag)
            end

            if ~hasWorkPlaneTag
                obj.workPlaneTag = hModel.geom.uniquetag('layer_wp');
            else
                obj.workPlaneTag = p.Results.WorkPlaneTag;
            end
            
            % Setup workplane and use zPosition setter to set quickz.
            workPlane = hModel.get_or_create(h.Model.geom.feature(), ...
                                             obj.workPlaneTag, ...
                                             'WorkPlane');
            workPlane.set('quickplane', 'xy');
            obj.zPosition = p.Results.zPosition;
            %workPlane.set('quickz', p.Results.depth);
            
            if ~hasExtrudeTag
                obj.extrudeTag = hModel.geom.uniquetag('layer_ext');
            else
                obj.extrudeTag = p.Results.ExtrudeTag;
            end
            
            % Setup extrude and use thickness setter to set distance.
            extrude = hModel.get_or_create(h.Model.geom.feature(), ...
                                             obj.extrudeTag, 'Extrude');
            extrude.set('createselection', 'on');
            extrude.selection('input').set(obj.workPlaneTag);
            obj.thickness = p.Results.Thickness;
        end
    end
end
