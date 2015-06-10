classdef ComsolModel < handle % All copies are references to same object
    % COMSOLMODEL Manages the comsol object on a comsol server
    
    % Dependent variables are created from model on demand. Not saved.
    % Based on: http://de.mathworks.com/help/matlab/matlab_oop/ ...
    % avoiding-property-initialization-order-dependency.html
    properties(Dependent)
        lengthUnit % Length of a unit in meters.
        tag % Tag of the model object.
        geom % Maintain a handle to the first geometry object
    end
    properties
        comsolVersion % Track version, since some methods change from 4.4 to 5.
    end
    properties(Constant)
        % Conversion of unit string in comsol to a value in meters.
        UNIT = {{'nm',1e-9}, ...
                {[native2unicode(hex2dec({'00' 'b5'}),'unicode'), ... % um
                  'm'], 1e-6}, ...
                {'mm',1e-3}, ...
                {'m',1}};
        BASE_TAG_MODEL = 'Model'; % Base model string for uniquetag.
        BASE_TAG_GEOM = 'geom'; % Base geom string for uniquetag.
    end
    properties(Transient)
        model % The com.comsol.clientapi.impl.ModelClient object.
    end
    properties(Access=private)
        mphFile = []; % mph-file is saved/loaded from here.
    end
    
    methods
        function obj = ComsolModel(varargin)
            % ComsolModel Creates a comsol model object.
            %
            %  ComsolModel(varargin)
            %
            %  Parameters:
            %  FromFile: Load from a mph-file on the file system
            %  FromTag: Load from an existing model on the server by tag
            %  %%% parameters below only for new models %%%
            %  LengthUnit: Length of a unit in meters (default: 1e-9)
            %  GeomDimension: Dimensions of the model (default: 3)
            
            import com.comsol.model.*;
            import com.comsol.model.util.*;
            
            defaultLengthUnit = 1e-9; % In nm per default.
            defaultDimension = 3; % 3d geometry per default.
            
            p = inputParser();
            p.addParameter('LengthUnit', defaultLengthUnit, ...
                           @(x) isnumeric(x) && x>0 && isscalar(x));
            p.addParameter('GeomDimension', defaultDimension, ...
                           @(x) isnumeric(x) && x >= 1 && x <= 3 && ...
                           isscalar(x));
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
                       'a model on the server by tag.'], 'ComsolModel');
                   
            elseif isFromFile % Load from a file on the file system.
                % if isUnitDefined || isDimensionDefined
                %     warning(['LengthUnit and/or GeomDimension ' ...
                %              'ignored. Model created from file/tag.']);
                % end
                
                if exist(p.Results.FromFile, 'file') == 2
                    modelTag = ModelUtil.uniquetag(obj.BASE_TAG_MODEL);
                    obj.model = ModelUtil.load(modelTag, ...
                                               p.Results.FromFile);
                else
                    error('Could not find the file %s.', ...
                          p.Results.FromFile);
                end
                
            elseif isFromTag % Load from Comsol Server.
                % if isUnitDefined || isDimensionDefined
                %     warning(['LengthUnit and/or GeomDimension ' ...
                %              'ignored. Model created from file/tag.']);
                % end
                
                modelTagCell = cell(ModelUtil.tags());
                isValidTag = ismember(p.Results.FromTag, modelTagCell);
                
                if isValidTag
                    obj.model = ModelUtil.model(p.Results.FromTag);
                else
                    error('Unknown model with tag %s.', p.Results.FromTag);
                end
                
            else % Create a new model on the server.
                modelTag = ModelUtil.uniquetag(obj.BASE_TAG_MODEL);
                obj.model = ModelUtil.create(modelTag);
                
                % Create the geometry with specified dimension.
                geomTag = obj.model.geom().uniquetag(obj.BASE_TAG_GEOM);
                obj.model.geom().create(geomTag, p.Results.GeomDimension);

                obj.lengthUnit = p.Results.LengthUnit;
            end
            
            obj.model.hist.disable; % Explicitly disable undo history.
            obj.comsolVersion = obj.model.getComsolVersion();
        end
        
        
        % Get/set methods technique based on:
        % http://de.mathworks.com/help/matlab/matlab_oop/...
        % property-access-methods.html
        function set.tag(obj, newTag)
            
            import com.comsol.model.*;
            
            assert(ischar(newTag),'Tag must be a string.');
            
            obj.model.tag(newTag);
        end
        
        
        function tag = get.tag(obj)
            
            import com.comsol.model.*;
            
            tag = char(obj.model.tag());
        end
        
        
        function geom = get.geom(obj)
            
            import com.comsol.model.*;
            
            tagCell = cell(obj.model.geom().tags());
            
            assert(~isempty(tagCell), ...
                   'No geometry entities found in model %s.', obj.tag);
            
            % Use the first geometry in a possibly larger list.
            geom = obj.model.geom().get(tagCell{1});
        end
        
        
        function model = get.model(obj)
            
            import com.comsol.model.*;
            
            % This is a bit of a hack, since I could not find a function to
            % test connectivity to the server. Calling any function, when
            % connection is lost results in an exception. Call a cheap
            % function for this.
            % TODO: try isvalid()
            try
                obj.model.isActive();
            catch
                % TODO: inputname(1) fails to get object name.
                error('Exception accessing the model object.');
            end
            model = obj.model;
        end
        
        
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
                
                % fprintf('Length unit set to %s.\n', unitPair{1});
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
            
            % Only one match should be possible.
            assert(sum(logicIndex) == 1, ...
                   ['Unit %s is not well defined. Update UNITS with' ...
                    ' the right string/value pair.'], unitString);

            unitPair = obj.UNIT(logicIndex);
            unitPair = unitPair{1}; % Is 1x1 cell of 1x2 cell.
            lengthUnit = unitPair{2};
        end
        
        
        function delete(obj)
            % delete Removes the object (also from the server).
            %
            %  delete(obj)
            
            import com.comsol.model.util.*;
            
            % Call superclass delete method.
            delete@handle(obj);
            
            try
                deletedTag = obj.tag;
                ModelUtil.remove(obj.tag); % Removes model from server.

                modelTagCell = cell(ModelUtil.tags());
                isValidTag = ismember(deletedTag, modelTagCell);

                if isValidTag
                    warning(['Could not delete model %s from server. ' ...
                             'Model is accessed by another client.'], ...
                             deletedTag);
                end
            catch
                warning(['Could not delete model object from server. ' ...
                         'Connection lost?']);
            end
        end
        
        
        function savedObj = saveobj(obj)
            % saveobj Saves the object including the comsol model.
            %
            %  savedObj = saveobj(obj)
            
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
                warning('Could not save comsol object.');
            end
            savedObj = obj;
        end
        
        
        function msg = save_mph(obj, fileName)
            % save_mph Saves the comsol model to a mph-file.
            %
            %  save_mph(obj, fileName)
            
            import com.comsol.model.*;
            
            if ~isempty(obj.model)
                obj.model.save(fileName);
                msg = sprintf('Model %s saved to %s.\n', ...
                    obj.tag, fileName);
            else
                warning('Could not save comsol object.');
            end
        end
        
        
        function [param, description] = get_param(obj, paramName)
            % get_param Wrapper to get comsol model parameters.
            %
            %  [param, description] = get_param(obj, paramName)
            
            import com.comsol.model.*;
            
            % Get all parameter names.
            paramCell = cell(obj.model.param.varnames());
            isValidParam = ismember(paramName, paramCell);
            
            if isValidParam
                param = char(obj.model.param.get(paramName));
                description = char(obj.model.param.descr(paramName));
            else
                warning('Parameter %s undefined.', paramName);
            end
        end
        
        
        function set_param(obj, paramName, value, varargin)
            % set_param Wrapper to set comsol model parameters.
            %
            %  set_param(obj, paramName, value)
            %  set_param(obj, paramName, value, description)
            
            import com.comsol.model.*;
            
            if nargin > 3
                obj.model.param.set(paramName, value, varargin{1});
            else
                obj.model.param.set(paramName, value);
            end
        end
        
        
        function print_param_info(obj)
            % print_param_info Prints parameter information in a table.
            %
            %  print_param_info(obj)
            
            import com.comsol.model.*;
            
            % Get all parameter names.
            paramCell = cell(obj.model.param.varnames());
            
            fprintf('%-30s %-30s %s\n','Parameter', 'Value', ...
                    'Description');
            fprintf([repmat('-', 1, 93), '\n']);
            
            % paramCell is n x 1. For wants 1 x n, so transpose.
            for paramName = paramCell'
                [paramValue, description] = obj.get_param(paramName{1});
                fprintf('%-30s %-30s %s\n', paramName{1}, paramValue, ...
                        description);
            end
        end
        
        
        function plot(obj, varargin)
            % plot Wrapper for mphgeom. See help mphgeom for parameters.
            %
            %  plot(obj)
            %  plot(obj, varargin)
            
            mphgeom(obj.model, obj.geom.tag(), 'facealpha', 0.5);
        end


        function data = evaluate_interpolated_expression(obj, expr, ...
                        	coordinateArray, varargin)
            % evaluate_interpolated_expression Evaluates expression.
            %
            %  data = evaluate_interpolated_expression(obj, expr, ...
            %                    coordinateArray)
            %  data = evaluate_interpolated_expression(obj, expr, ...
            %                    coordinateArray, mRows, nColms)
            %
            %  Parameters:
            %  coordinateArray: Expression is evaluated at this points,
            %                   when they do not correspond to mesh
            %                   vertices, values are interpolated
            %                   (3 x n size).
            %  expr: Expression to evaluate (e.g. 'mod1.V', 'es.nD')
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
            %   pot = evaluate_interpolated_expression(xyz, 'mod1.V', ...
            %           length(x0), length(y0));
            
            import com.comsol.model.*;
            
            assert(nargin == 2 || nargin == 4, ...
                   'Wrong number of arguments');
            assert(isnumeric(coordinateArray) && ...
                   size(coordinateArray, 1) == 3, ...
                   'Wrong coordinateArray format');
            
            obj.std.run; % Solve the model.
            
            % Retrieve interpolated potential values.
            try
                data = mphinterp(obj.model, expr, ...
                                      'coord', coordinateArray);
            catch
                warning(['Was unable to evaluate expression on domain. '
                         'Will try edim=boundary now.']);
                data = mphinterp(obj.model, expr, 'edim', 'boundary', ...
                                      'coord', coordinateArray);
            end
                              
            if nargin == 4
                mRows = varargin{1};
                nColms = varargin{2};
                data = reshape(data, mRows, nColms);
            end
        end
                
        
            
    end
    methods(Static)
        function loadedObj = loadobj(obj)
            % loadobj Loads the object including the comsol model.
            %
            %  loadedObj = loadobj(obj)
            
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
                modelTag = ModelUtil.uniquetag(obj.BASE_TAG_MODEL);
                obj.model = ModelUtil.load(modelTag, tmpFile);
                
                delete(tmpFile); % Clean up.
                obj.mphFile = [];
            else
                warning('Could not create model object.');
            end
            
            loadedObj = obj;
        end
        
        
        function server_connect(varargin)
            % server_connect Initialize live link and connect to server.
            %
            %  server_connect()
            %  server_connect(ipAddress, port)
            %  server_connect(ipAddress, port, user, passWord)
            
            import com.comsol.model.*;
            import com.comsol.model.util.*;
            
            switch nargin
                case 0
                    mphstart();
                case 2
                    ipAddress = varargin{1};
                    port = varargin{2};
                    
                    assert(ischar(ipAddress) && isnumeric(port), ...
                           'ipAddress is a string and port a number.');
                    try
                        mphstart(ipAddress, port);
                    catch
                        ModelUtil.connect(ipAddress, port);
                    end
                case 4
                    ipAddress = varargin{1};
                    port = varargin{2};
                    user = varargin{3};
                    passWord = varargin{4};
                    
                    assert(ischar(ipAddress) && isnumeric(port), ...
                           'ipAddress is a string and port a number.');
                    assert(ischar(user) && ischar(passWord), ...
                           'user and passWord are strings.');
                    try
                        mphstart(ipAddress, port, user, passWord);
                    catch
                        ModelUtil.connect(ipAddress, port, user, passWord);
                    end
                otherwise
                    error(['Wrong number of arguments. See help ' ...
                           'comsolkit.ComsolModel.connect_server']);
            end
            
            % Command timeout in seconds. Account for connectivity delays.
            % TODO: Cannot find this class in imports?
            % ModelUtil.setServerBusyHandler(ServerBusyHandler(5));
        end
        
        
        function server_disconnect()
            % server_disconnect Disconnect from comsol server.
            %
            %  server_disconnect()
            
            import com.comsol.model.util.*;
            
            ModelUtil.disconnect();
        end
        
        
        function modelCell = get_server_tags()
            % get_server_tags Returns tags of models on the server.
            %
            %  modelCell = get_server_tags()
            
            import com.comsol.model.util.*;
            
            modelCell = cell(ModelUtil.tags());
        end
    end    
end