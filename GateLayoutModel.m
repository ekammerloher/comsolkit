classdef GateLayoutModel < comsolkit.LayeredModel
    % GateLayoutModel Inherits from LayeredModel and adds gates.
    
    properties(Dependent)
        es % Handle to the electrostatic physics feature.
    end
    properties(Constant)
        BASE_TAG_ES = 'es'; % Tag of electrostatic physics feature.
        DEFAULT_GATE_CLASS = @comsolkit.Gate; % Used for import functions.
    end
    
    methods
        function obj = GateLayoutModel(varargin)
            % GateLayoutModel Creates a gate layout model.
            %
            %  GateLayoutModel(varargin)
            %
            %  Parameters:
            %  FromFile: Load from a mph-file on the file system
            %  FromTag: Load from an existing model on the server by tag
            %  %%% parameters below only for new models %%%
            %  LengthUnit: Length of a unit in meters (default: 1e-9)
            
            obj = obj@comsolkit.LayeredModel(varargin{:});
            
            % Create electrostatics physics, if it does not exist.
            esIndex = obj.model.physics.index(obj.BASE_TAG_ES);
            
            if esIndex < 0
                obj.model.physics.create(obj.BASE_TAG_ES, ...
                                         'Electrostatics', ...
                                         obj.geom.tag());
            end
        end
        
        
        function es = get.es(obj)
            esIndex = obj.model.physics.index(obj.BASE_TAG_ES);
            
            assert(esIndex >= 0, 'Could not find electrostatics %s.', ...
                   obj.BASE_TAG_ES);
               
            es = obj.model.physics(obj.BASE_TAG_ES);
        end
        
        
        function savedObj = saveobj(obj)
            % saveobj Saves the object including the comsol model.
            %
            %  savedObj = saveobj(obj)
            
            savedObj = saveobj@comsolkit.ComsolModel(obj);
        end
        
        
        function import_gds_file(obj, gdsFile)
            % import_gds_file Import gds structures into layerArray.
            %
            %  import_gds_file(obj, gds_file)
            %
            %  The gds-file in gds_file should have
            %  either a single structure with n elements corresponding to
            %  n gates or a structure with n element referencing a 
            %  structure with one element per structure.
            %  The later allows to have named gates.
            %
            %  Schematic (option 1 with named gates):
            %                 S               (array of elements)
            %       |----|----|----|----|
            %       E    E    E    E    E     (element references struct)
            %       |    |    |    |    |
            %       S    S    S    S    S     (struct represents gate)
            %       |    |    |    |    |
            %       E    E    E    E    E     (element contains XY coords)
            %
            %  Schematic (option 2):
            %                 S               (array of elements)
            %       |----|----|----|----|
            %       E    E    E    E    E     (element contains XY coords)
            
            % TODO: Extend import to deal with multiple polygons per gate.
            
            gdsLibrary = read_gds_library(gdsFile);
            
            % Scale gds data according to ComsolModel.lengthUnit.
            userUnit = get(gdsLibrary,'uunit');
            ratio = userUnit / obj.lengthUnit;
            
            % Find root structure element.
            topName = topstruct(gdsLibrary);
            assert(length(topName) == 1, 'Only one top structure allowed');
            
            topStruct = obj.struct_by_name(gdsLibrary, topName);
            
        end
    end
    methods(Access = private)
    	function s = struct_by_name(~, lib, str)
            % struct_by_name  Helper returns gds_structs by name.
            structNames = cellfun(@sname, lib(:), 'UniformOutput', false);
            s_logic = cellfun(@(x) isequal(x,str), structNames);
            s = lib(s_logic);
            if iscell(s) % FIX: some programs save gds differently
                s = s{1};
            end
        end
    end
    methods(Static)
        function loadedObj = loadobj(obj)
            % loadobj Loads the object including the comsol model.
            %
            %  loadedObj = loadobj(obj)
            
            loadedObj = loadobj@comsolkit.ComsolModel(obj);
        end
    end
end

