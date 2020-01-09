function [C, terminals] = get_capacitance_matrix(varargin)
% C = get_capacitance_matrix(model, 'ParameterName', ParameterValue, ...)
% 
% Evaluates 'es.Cinv', obtained via a stationary source sweep of Terminal
% features (available only with the AC/DC module).
%
% Parameters:
% -----------
% dataset: 'dset7' (dataset of stationary source sweep)
% matrixType: 'mutual' (return mutual or maxwell capacitance)
%
p = inputParser;
p.addRequired('model');
p.addParameter('dataset', 'dset7');
p.addParameter('matrixType', 'maxwell', ...
               @(s)validatestring(s, {'mutual', 'maxwell'}));
p.parse(varargin{:});

Cinv = mphevalglobalmatrix(p.Results.model, 'es.Cinv', ...
                        'dataset', p.Results.dataset, 'trans', 'none');

terminals = Cinv(~isnan(Cinv(:,1)),1);
Cinv = Cinv(:,2:end); % Remove terminal indices in first column.

% C has now shape (3 terminal example):
% xxx NaN NaN
% xxx NaN NaN
% xxx NaN NaN
% NaN xxx NaN
% NaN xxx NaN
% NaN xxx NaN
% NaN NaN xxx
% NaN NaN xxx
% NaN NaN xxx

Cinv = Cinv(~isnan(Cinv)); % Remove NaN entries.
Cinv = reshape(Cinv, numel(terminals), numel(terminals));
C = inv(Cinv); % Invert to obtain Maxwell capacitance matrix.

if strcmp(p.Results.matrixType, 'mutual')
    Cdiag = diag(C); % This is sum of mutual capacitances per column.
    C = -1.*(C-diag(Cdiag)); % Remove diagonal & convert remaining matrix.
    Cdiag = Cdiag - sum(C,1)'; % Extract missing mutual capacitance.
    C = C + diag(Cdiag);
end
end