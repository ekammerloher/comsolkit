classdef GateLayoutModel < comsolkit.LayeredModel
    % GateLayoutModel Inherits from LayeredModel and adds gates.
    
    properties(Dependent)
        es % Handle to the electrostatic physics feature.
        std % Handle to the stationary study feature for solving the model.
    end
    properties(Constant)
        BASE_TAG_ES = 'es'; % Tag of the electrostatic physics feature.
        BASE_TAG_STD = 'std'; % Tag of the study feature.
        BASE_TAG_STAT = 'stat'; % Tag of the stationary feature.
        DEFAULT_GATE_CLASS = @comsolkit.Gate; % Used for import functions.
        DEFAULT_POT_VAR = 'mod1.V'; % Evaluate this for the potential.
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
            
            % Create stationary study, if it does not exist.
            stdIndex = obj.model.study.index(obj.BASE_TAG_STD);
            
            if stdIndex < 0
                study = obj.model.study.create(obj.BASE_TAG_STD);
                study.feature.create(obj.BASE_TAG_STAT, 'Stationary');
            else
                study = obj.model.study(obj.BASE_TAG_STD);
                statIndex = study.feature().index(obj.BASE_TAG_STAT);
                assert(statIndex >= 0, ...
                       'No stationary study feature found.');
            end
        end
        
        
        function es = get.es(obj)
            
            import com.comsol.model.*;
            
            esIndex = obj.model.physics.index(obj.BASE_TAG_ES);
            
            assert(esIndex >= 0, 'Could not find electrostatics %s.', ...
                   obj.BASE_TAG_ES);
               
            es = obj.model.physics(obj.BASE_TAG_ES);
        end
        
        
        function std = get.std(obj)
            
            import com.comsol.model.*;
            
            stdIndex = obj.model.study.index(obj.BASE_TAG_STD);
            
            assert(stdIndex >= 0, 'Could not find study %s.', ...
                   obj.BASE_TAG_STD);
               
            std = obj.model.study(obj.BASE_TAG_STD);
        end
        
        
        function savedObj = saveobj(obj)
            % saveobj Saves the object including the comsol model.
            %
            %  savedObj = saveobj(obj)
            
            savedObj = saveobj@comsolkit.ComsolModel(obj);
        end
        
        
        function potential = compute_interpolated_potential(obj, ...
                                coordinateArray, varargin)
            % compute_interpolated_potential Solves model, returns pot.
            %
            %  potential = compute_interpolated_potential(obj, ...
            %                    coordinateArray)
            %  potential = compute_interpolated_potential(obj, ...
            %                    coordinateArray, mRows, nColms)
            %
            %  Parameters:
            %  coordinateArray: Solution is evaluated at this points, when
            %                   they do not correspond to mesh vertices,
            %                   values are interpolated (3 x n size).
            %  mRows, nColms: Reshape the data, when on a grid (optional).
            %
            %  Example:
            %   precision = 10;
            %   l_domain = 3000;
            %   w_domain = 1200;
            %   x0 = 0:precision:l_domain;
            %   y0 = 0:precision:w_domain;
            %   z0 = [-100]; % Depth.
            %   [x,y,z] = meshgrid(x0,y0,z0);
            %   xyz = [x(:),y(:),z(:)]';
            %   pot = compute_interpolated_potential(xyz, ...
            %           length(x0), length(y0));
            
            import com.comsol.model.*;
            
            assert(nargin == 2 || nargin == 4, ...
                   'Wrong number of arguments');
            assert(isnumeric(coordinateArray) && ...
                   size(coordinateArray, 1) == 3, ...
                   'Wrong coordinateArray format');
            
            obj.std.run; % Solve the model.
            
            % Retrieve interpolated potential values.
            potential = evaluate_interpolated_expression(obj, ...
                obj.DEFAULT_POT_VAR, coordinateArray, varargin);
        end
                 
        
        function [coordinateCell, nameCell] = import_gds_file(obj, gdsFile)
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
            
            assert(exist(gdsFile, 'file') == 2, 'File does not exist.');
            
            gdsLibrary = read_gds_library(gdsFile);
            
            % Scale gds data according to ComsolModel.lengthUnit.
            userUnit = get(gdsLibrary,'uunit');
            ratio = userUnit / obj.lengthUnit;
            
            % Find root structure element.
            topName = topstruct(gdsLibrary);
            assert(ischar(topName), 'Only one top structure allowed');
            
            topStruct = obj.struct_by_name(gdsLibrary, topName);
            
            % The case with one element per structure.
            % If first element reference, assume all.
            if is_ref(topStruct(1))
                % Iterate over reference structures, get real structures.
                nameCell = cell(1, numel(topStruct));
                coordinateCell = cell(1, numel(topStruct));
                for i = 1:numel(topStruct)
                    % Get referenced structure by name.
                    referenceStruct = obj.struct_by_name(gdsLibrary, ...
                                                get(topStruct(i),'sname'));

                     % Include offset but no strans (rotation, scaling).
                    xyOffset = get(topStruct(i),'xy');
                    
                    % This struct has allways one child.
                    xy = get(referenceStruct(1),'xy');
                    xy = xy{1};
                    
                    xy = bsxfun(@plus, xy, xyOffset); % Add offset.
                    
                    xy = xy .* ratio;
                    coordinateCell{i} = {xy};
                    nameCell{i} = referenceStruct.sname;
                end
            else
                nameCell = {};
                coordinateCell = cell(1, numel(topStruct));
                for i = 1:numel(topStruct)
                    if is_ref(topStruct(i))
                        % This should not happen.
                        warning('Skipped reference element %d.', i);
                        continue;
                    end
                    
                    xy = get(topStruct(i),'xy');
                    xy = xy{1};
                    xy = xy .* ratio;
                    coordinateCell{i} = {xy};
                end
            end
        end
        
        
        function choose_domain_region(obj)
            % choose_domain_region Defines domain region on layerArray.
            %
            %  choose_domain_region(obj)
            %
            %  Usage:
            %  Draw a rectangle around the region to consider and
            %  double-click inside the rectangle.
            
            f = figure;
            set(f, 'Name', ['Select domain region and double-click ' ...
                'inside to confirm.']);
            obj.layerArray.plot();
            h = imrect;
            pos = wait(h);
            fprintf('Dimensions:\n\torigin_x: %f\n\torigin_y: %f\n', ...
                    pos(1), pos(2));
            fprintf('\tl_domain: %f\n\tw_domain: %f\n', pos(3), pos(4));
            
            fprintf(['Set this parameters in models created from a ' ...
                     'template via set_param:\n']);
                 
            fprintf('\t%s.set_param(''origin_x'', %f);\n', ...
                    inputname(1), pos(1));
            fprintf('\t%s.set_param(''origin_y'', %f);\n', ...
                    inputname(1), pos(2));
            fprintf('\t%s.set_param(''l_domain'', %f);\n', ...
                    inputname(1), pos(3));
            fprintf('\t%s.set_param(''w_domain'', %f);\n', ...
                    inputname(1), pos(4));
                
            close(f);
        end    
    end
    methods(Access = private)
    	function s = struct_by_name(~, lib, str)
            % struct_by_name  Helper returns gds_structs by name.
            %
            % s = struct_by_name(~, lib, str)
            
            nameCell = cellfun(@sname, lib(:), 'UniformOutput', false);
            logicCell = cellfun(@(x) isequal(x,str), nameCell);
            s = lib(logicCell);
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

