classdef ComsolModel < handle % All copies are references to same object
    % COMSOLMODEL Manages the comsol object on a comsol server
    
    % Dependent variables are created from model on demand. Not saved.
    % based on: http://de.mathworks.com/help/matlab/matlab_oop/ ...
    % avoiding-property-initialization-order-dependency.html
    properties(Dependent)
        lengthUnit % Base length of a unit in meters.
        tag % Tag of the model object.
        geom % Maintain a handle to the first geometry object
    end
    properties(Constant)
        % Conversion of unit string in comsol to a value in meters.
        UNIT = {{'nm',1e-9}, ...
                {[native2unicode(hex2dec({'00' 'b5'}),'unicode'), ... % um
                  'm'], 1e-6}, ...
                {'mm',1e-3}, ...
                {'m',1}};
    end
    properties(Transient)
        model % The com.comsol.clientapi.impl.ModelClient object.
    end
    properties(Access=private)
        mphFile = []; % mph-file is saved/loaded from here.
    end
    
    methods
        % Encapsulate comsol communication?
        % Exists tag method that calls index on model entity list or if
        % this function is not avalible .tags and searches for tag?
        % Get domain numbers with explicit geometry selections.
        % Get entity index array via coordinate checks.
        % Functions to createBox/Poly/Selection/Ellipse/Workplane etc.
        % Use .clear() in a workplane instead of manual delete.
        % Domain numbers with selection.entities(2).
        % For elm = list print(elem); end.
        % Check if tag exists by index > 0 on any ModelEntityList.
        
        function obj = ComsolModel(varargin)
            
            import com.comsol.model.*;
            import com.comsol.model.util.*;
            
            defaultLengthUnit = 1e-9; % In nm per default.
            defaultDimension = 3; % 3d geometry per default.
            
            p = inputParser();
            p.addParameter('LengthUnit', defaultLengthUnit, ...
                           @(x) isnumeric(x) && x>0);
            p.addParameter('GeomDimension', defaultDimension, ...
                           @(x) isnumeric(x) && x >= 1 && x <= 3);
            p.addParameter('FromFile', '', @ischar);
            p.addParameter('FromTag', '', @ischar);
            
            p.parse(varargin{:});
            
            isFromFile = ~isempty(p.Results.FromFile);
            isFromTag = ~isempty(p.Results.FromTag);
            isUnitDefined = ~ismember('LengthUnit',p.UsingDefaults);
            isDimensionDefined = ~ismember('GeomDimension', ...
                p.UsingDefaults);
            
            if isFromFile && isFromTag
                error(['Can construct a %s object either from a file or '
                       'a model on the server by tag'], 'ComsolModel');
                   
            elseif isFromFile % Load from a file on the file system.
                if isUnitDefined || isDimensionDefined
                    warning('LengthUnit and/or GeomDimension ignored.');
                end
                
                if exist(p.Results.FromFile, 'file') == 2
                    modelTag = ModelUtil.uniquetag('Model');
                    obj.model = ModelUtil.load(modelTag, ...
                                               p.Results.FromFile);
                else
                    error('Could not find the file %s', ...
                          p.Results.FromFile);
                end
                
            elseif isFromTag % Load from Comsol Server.
                if isUnitDefined || isDimensionDefined
                    warning('LengthUnit and/or GeomDimension ignored.');
                end
                
                modelTagCell = cell(ModelUtil.tags());
                isValidTag = ismember(p.Results.FromTag, modelTagCell);
                
                if isValidTag
                    obj.model = ModelUtil.model(p.Results.FromTag);
                else
                    error('Unknown model with tag %s', p.Results.FromTag);
                end
                
            else % Create a new model on the server.
                modelTag = ModelUtil.uniquetag('Model');
                obj.model = ModelUtil.create(modelTag);
                
                % Create the geometry with specified dimension.
                geomTag = obj.model.geom().uniquetag('geom');
                obj.model.geom().create(geomTag, p.Results.GeomDimension);

                obj.lengthUnit = p.Results.LengthUnit;
            end
            
            obj.model.hist.disable; % Explicitly disable undo history.
        end
        
        
        % Get/set methods technique based on:
        % http://de.mathworks.com/help/matlab/matlab_oop/...
        % property-access-methods.html
        function set.tag(obj, newTag)
            
            import com.comsol.model.*;
            
            assert(ischar(newTag),'Tag must be a string');
            
            % TODO: Do some checks on model or define get/set for model.
            obj.model.tag(newTag);
        end
        
        
        function tag = get.tag(obj)
            
            import com.comsol.model.*;
            
            % TODO: Do some checks on model or define get/set for model.
            tag = char(obj.model.tag());
        end
        
        
        function geom = get.geom(obj)
            
            import com.comsol.model.*;
            
            % TODO: Do some checks on model or define get/set for model.
            tagCell = cell(obj.model.geom().tags());
            
            assert(~isempty(tagCell), ...
                'No geometry entities found in model %s.', obj.tag);
            
            geom = obj.model.geom().get(tagCell{1});
        end
        
        
%         function model = get.model(obj)
%             
%             import com.comsol.model.*;
%             
%             % This is a bit of a hack, since I could not find a function to
%             % test connectivity to the server. Calling any function, when
%             % connection is lost results in an exception. Call a cheap
%             % function for this.
%             try
%                 obj.model.isActive();
%             catch
%                 obj.model = [];
%                 warning('Exception accessing the model object');
%             end
%             model = obj.model;
%         end
        
        
        function set.lengthUnit(obj, unitValue)
            
            import com.comsol.model.*;
            
            assert(isnumeric(unitValue) && unitValue>0, ...
                   'The new value must be a number.');
            
            % Check if a unit for this value exists in UNITS. Generate
            % logical array.
            logicIndex = cellfun(@(x) isequal(x{2}, unitValue), obj.UNIT);
            
            if sum(logicIndex) == 1 % Only one match should be possible.
                unitPair = obj.UNIT(logicIndex);
                unitPair = unitPair{1}; % Is 1x1 cell of 1x2 cell.
                
                fprintf('Length unit set to %s\n', unitPair{1});
                obj.geom.lengthUnit(unitPair{1});
            else
                warning(['Length %e m as a unit is not recognized. ' ...
                         'Set to 1 m.'], unitValue);
                obj.geom.lengthUnit('m');
            end
        end
        
        
        function lengthUnit = get.lengthUnit(obj)
            
            import com.comsol.model.*;
            
            % Get unit from comsol.
            unitString = char(obj.geom.lengthUnit());
            
            % Check if a value for this unit exists in UNITS. Generate
            % logical array.
            logicIndex = cellfun(@(x) isequal(x{1}, unitString), obj.UNIT);
            
            if sum(logicIndex) ~= 1 % Only one match should be possible.
                error(['Unit %s is not well defined. Update UNITS with' ...
                         ' the right string/value pair.'], unitString);
            end

            unitPair = obj.UNIT(logicIndex);
            unitPair = unitPair{1}; % Is 1x1 cell of 1x2 cell.
            lengthUnit = unitPair{2};
        end
        
        
        function delete(obj)
            % delete Removes the comsol object from the server.
            
            import com.comsol.model.util.*;
            
            % Call superclass delete method.
            delete@handle(obj);
            
            deletedTag = obj.tag;
            ModelUtil.remove(obj.tag); % Removes model from server.
            
            modelTagCell = cell(ModelUtil.tags());
            isValidTag = ismember(deletedTag, modelTagCell);
            
            if isValidTag
                warning(['Could not delete model object from server. ' ...
                        'Model is accessed by another client.']);
            end
        end
        
        
        function savedObj = saveobj(obj)
            
            import com.comsol.model.*;
            
            if ~isempty(obj.model)
                % Create temp mph file and read it in.
                tmpFile = tempname;
                tmpFile = [tmpFile '.mph']; % Enshure correct file type.

                obj.model.save(tmpFile);

                % Save as uint8 to save space.
                fid = fopen(tmpFile,'rb');
                obj.mphFile = fread(fid, '*uint8');
                fclose(fid);

                delete(tmpFile); % Clean up.
            else
                warning('Could not save comsol object');
            end
            savedObj = obj;
        end
        
        
        function msg = save_mph(obj, fileName)
            % save_mph Saves the comsol model to a mph-file.
            
            import com.comsol.model.*;
            
            if ~isempty(obj.model)
                obj.model.save(fileName);
                msg = sprintf('Model %s saved to %s.\n', ...
                    obj.tag, fileName);
            else
                warning('Could not save comsol object');
            end
        end
        
        
        function param = get_param(obj, paramName)
            % get_param Wrapper to get comsol model parameters.
            
            % Get all parameter names.
            paramCell = cell(obj.model.param.varnames());
            isValidParam = ismember(paramName, paramCell);
            
            if isValidParam
                param = char(obj.model.param.get(paramName));
            else
                warning('Parameter %s undefined.', paramName);
            end
        end
        
        
        function set_param(obj, paramName, value, varargin)
            % set_param Wrapper to set comsol model parameters.
            
            if nargin > 3
                obj.model.param.set(paramName, value, varargin{1});
            else
                obj.model.param.set(paramName, value);
            end
        end
        
        
        function modelEntity = get_or_create(~, modelEntityList, ...
                                             tag, varargin)
            % get_or_create Helper function to get/create an entity.
            
            import com.comsol.model.*;
            
            if modelEntityList.index(tag) >= 0 % Not in list: -1.
                modelEntity = modelEntityList.get(tag);
            else
                modelEntity = modelEntityList.create(tag, varargin{:});
            end
        end
    end
    methods(Static)
        function loadedObj = loadobj(obj)
            
            import com.comsol.model.*;
            import com.comsol.model.util.*;
            
            if ~isempty(obj.mphFile)
                % Create temp mph file and write mphFile to it.
                tmpFile = tempname;
                tmpFile = [tmpFile '.mph']; % Enshure correct file type.
                fid = fopen(tmpFile,'wb');
                fwrite(fid, obj.mphFile, 'uint8');
                fclose(fid);
                
                % Load mph file with a new tag.
                modelTag = ModelUtil.uniquetag('Model');
                obj.model = ModelUtil.load(modelTag, tmpFile);
                
                delete(tmpFile); % Clean up.
                obj.mphFile = [];
            else
                warning('Could not create model object.');
            end
            
            loadedObj = obj;
        end
    end
end