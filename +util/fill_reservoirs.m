function rhoMask = fill_reservoirs(varargin)
% rhoMask = fill_reservoirs(rho, 'ParameterName', ParameterValue, ...)
%
% Processes potentially noisy rho image and returns binary mask.
% Per default only erodes 3 pixels with imerode. Sufficient to remove noise
% and unconnect reservoirs at domain boundaries. Search for active contour
% also possible.
%
% Parameters:
% -----------
% cutoff: 1e15 (initial mask, rho<cutoff)
% edgeDist: 0 (remove edge pixels inward)
% missingMethod: 'pchip' (how to fill NaN values in rho)
% contourIter: 0 (activecontour iterations)
% contractionBias: 0.5 (bias how much to inflate/deflate contour)
% outwardDist: 3 (erode pixels)

p = inputParser;
p.addRequired('rho');
p.addParameter('cutoff', 1e15);
p.addParameter('edgeDist', 0);
p.addParameter('missingMethod', 'pchip');
p.addParameter('contourIter', 0);
p.addParameter('contourContractionBias', .5);
p.addParameter('outwardDist', 3);
p.parse(varargin{:});

% Fill missing entries.
rho = fillmissing(p.Results.rho, p.Results.missingMethod);

% Cut away everything below cutoff.
rho0Mask = rho < p.Results.cutoff;

if p.Results.contourIter > 0
    % Segment image via iterative foreground/background image segmentation.
    rhoMask = ~activecontour(rho, ~rho0Mask, p.Results.contourIter, ...
                             'Chan-Vese', 'SmoothFactor', 0, ...
                             'ContractionBias', ...
                             p.Results.contourContractionBias);
else
    rhoMask = rho0Mask;
end

if p.Results.outwardDist > 0
    se = strel('square', p.Results.outwardDist);
    rhoMask = imerode(rhoMask, se);
end

if p.Results.edgeDist>0
    edgeMask = false(size(rhoMask));
    edgeMask(p.Results.edgeDist:end-p.Results.edgeDist, ...
             p.Results.edgeDist:end-p.Results.edgeDist) = true;
    rhoMask = and(rhoMask, edgeMask);
end
end
