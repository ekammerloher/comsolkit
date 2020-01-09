function varargout = eval_plane(varargin)
% eval_plane(model, 'ParameterName', ParameterValue, ...)
%
% Required parameters:
% --------------------
% model
%
% Optional parameters:
% --------------------
% selection: box1
% dataset: ''
% solnum: 'end'
% refine: 1
% expression: {'V', 'es.nD/e_const'}
% plot: false

p = inputParser;
p.addRequired('model');
p.addParameter('selection', 'box1');
p.addParameter('dataset', '');
p.addParameter('solnum', 'end');
p.addParameter('outersolnum', 'end');
p.addParameter('refine', 1);
p.addParameter('expression', {'V', 'es.nD/e_const'});
p.addParameter('plot', false);
p.parse(varargin{:});

% outersol = false;
% try
%     sol = p.Results.model.result.dataset(p.Results.dataset).getString('solution');
%     model.sol(sol).feature('s1').feature('p1').getStringArray('plistarr');
% catch
%     outersol = true;
% end

% if false%outersol % Automatic switching broke with Comsol 5.4 Update 4.
%     solnumStr = 'outersolnum';
%     solnumVal = p.Results.solnum;
% else
%     solnumStr = 'solnum';
%     solnumVal = p.Results.solnum;
% end


data = mpheval(p.Results.model, p.Results.expression, ...
               'dataset', p.Results.dataset, ...
               ...%solnumStr, solnumVal, ...  
               'outersolnum', p.Results.outersolnum, ...
               'solnum', p.Results.solnum, ...
               'selection', p.Results.selection, ...
               'refine', p.Results.refine);

% Prepare unique value mask I if output requested.
if nargout > 0
    % Ensure unique data values (over-defined points are possible in
    % case of multiple self-consistent targets).
    [~, I, ~] = unique([data.p(1,:)' data.p(2,:)'],'first','rows');
    I = sort(I);
end

for k=1:numel(p.Results.expression)
    if p.Results.plot
        figure(99+k);
        clf;
        trisurf(data.t'+1, ...
                data.p(1,:),data.p(2,:), ...
                data.(sprintf('d%d', k)), ...
                'EdgeColor', 'none');
        hColorbar = colorbar();
        xlabel(hColorbar, data.unit{k});
        view(2);
        axis image
        axis tight
    end

    if k <= nargout % If output is requested.
        % Ensure unique values using mask I.
        x = data.p(1,I)';
        y = data.p(2,I)';
        d = data.(sprintf('d%d', k))(I)';
        d = d(:); % Ensure column vector format. Comsol 5.4 Update 4 fix.

        % Remove nan values.
        nan_flags = isnan(x) | isnan(y) | isnan(d);
        x(nan_flags) = [];
        y(nan_flags) = [];
        d(nan_flags) = [];


        if k>1 % Reuse prev Interpolant triangulation, replace values only.
            varargout{k} = varargout{k-1};
            varargout{k}.Values = d;
        else
            varargout{k} = scatteredInterpolant(x, y, d);
            varargout{k}.Method = 'natural';
            varargout{k}.ExtrapolationMethod = 'none';
        end
    end
end
