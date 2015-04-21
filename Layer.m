classdef Layer
    % Layer Bundles a comsol workplane and an extrude feature into an unit.
    
    properties(Dependent)
        name % Common name of the workplane and the extrude feature.
        thickness % Thickness of the layer produced by the extrude feature.
        zPosition % z-Position of the layer in the model.
        workPlane % Handle to the workplane feature of Layer.
        extrude % Handle to the extrude feature of Layer.
        selectionTag % Tag of the extrude domain selection feature.
    end
    properties(Constant)
        BASE_TAG_WORKPLANE = 'layer_wp'; % Base wp name for uniquetag.
        BASE_TAG_EXTRUDE = 'layer_ext'; % Base ext name for uniquetag.
    end
    properties(Access=private)
        extrudeTag % Access extrude distance in extrude feature.
        hModel % Handle to a ComsolModel object or a derived object.
    end
    
    methods
        function obj = Layer(hModel, varargin)
            % Layer Creates a Layer object.
            %
            %  Parameters:
            %  hModel: Required handle to parent ComsolModel type object
            %  Name: Common name of workpane and the extrude feature.
            %  Thickness: Thickness of layer (must be non-zero, default: 1)
            %  zPosition: z-Position of the layer (default: 0)
            %  %%% when creating from existing extruded workplane %%%
            %  ExtrudeTag: Tag of an existing extrude feature
            
            import com.comsol.model.*;
            
            obj.hModel = hModel;
            
            p = inputParser();
            p.addParameter('Name', '', @ischar);
            p.addParameter('ExtrudeTag', '', @ischar);
            p.addParameter('Thickness', 1, ...
                @(x) isnumeric(x) && length(x) == 1);
            p.addParameter('zPosition', 0, ...
                @(x) isnumeric(x) && length(x) == 1);
            
            p.parse(varargin{:});
            
            if isempty(p.Results.ExtrudeTag);
                workPlaneTag = hModel.geom.uniquetag('layer_wp');
                obj.extrudeTag = hModel.geom.uniquetag('layer_ext');
                
                % Setup workplane.
                workPlane = hModel.geom.feature().create(workPlaneTag, ...
                                                         'WorkPlane');
                workPlane.set('quickplane', 'xy');
                workPlane.set('quickz', p.Results.zPosition);
                
                % Setup extrude.
                extrude = hModel.geom.feature().create(obj.extrudeTag, ...
                                                       'Extrude');
                extrude.set('createselection', 'on');
                extrude.selection('input').set(workPlaneTag);
                extrude.set('distance', p.Results.Thickness);
                
                % Set common name, if provided.
                if ~isempty(p.Results.Name)
                    workPlane.label(p.Results.Name);
                    extrude.label(p.Results.Name);
                end
                % getDoubleArray('distance') to get distance, check for
                % single value.
                % selection('input').objects() to get the tag back, check,
                % that it is one tag.
            else
                % TODO: Checks on the extrude feature: has workpane
                obj.extrudeTag = p.Results.ExtrudeTag;
                obj.extrudeTag = p.Results.ExtrudeTag;
                obj.extrudeTag = p.Results.ExtrudeTag;
            end
        end
    end
end
