
function [y params] = resynth_log_spec(x, phase, params)
%if ~isdeployed
%    addpath('../discriminativeTransforms/src')
%end
if ~exist('params','var')
    error('params be required')
end

if ~isfield(params, 'framesize')
    error('specify a frame size')
end

if ~isfield(params, 'awin')
    params.awin = sqrt(0.5 * (1 - cos(2 * pi * (0:params.framesize) / params.framesize)))';
    params.awin = params.awin(1:params.framesize);
    %params.awin = sqrt(hann(params.framesize, 'periodic'));   %
end

if ~isfield(params, 'nshift')
    params.nshift = floor(length(params.awin)/2);   % default overlap of 50%
end

if ~isfield(params, 'swin')
    params.swin = synthwin(params.awin, params.nshift);
end

if ~isfield(params, 'cut_dc')
    params.cut_dc = 0;
end

if ~isfield(params, 'cut_nyquist')
    params.cut_nyquist = 0;
end
% should we care about this?
%     if ~isfield(params, 'nframe_smooth')
%         params.nframe_smooth = 1;
%     end

if ~isfield(params, 'logfactor')
    params.logfactor = 10/log(10);
end

if ~isfield(params, 'dbfloor')
    pfloor = 0;
else
    pfloor = exp(params.dbfloor/params.logfactor);
end

if ~isfield(params, 'inputtype')
    params.inputtype = 'log_power';
end

[dim nframes ] = size(x);
num_extra = params.cut_dc + params.cut_nyquist;
dim = dim + num_extra;

fmin = 1;
if params.cut_dc
    fmin = 2;
end

fmax = dim;
if params.cut_nyquist
    % assume even window length
    fmax = dim - 1;
end

msk = false(dim, 1);
ind = fmin:fmax;
msk(ind) = true;


switch params.inputtype
    case 'cepstrum'
        pxdb = idct(x);
        px = exp(pxdb/params.logfactor);
        px(~msk) = 0;
    case 'pspec'
        px = zeros(length(msk),nframes);
        px(msk,:) = x;
        temp = phase;
        phase = zeros(length(msk),nframes);
        phase(msk,:) = temp;
        clear temp;
    case 'amp_spec'
        px = zeros(length(msk),nframes);
        px(msk,:) = x.^2;
        temp = phase;
        phase = zeros(length(msk),nframes);
        phase(msk,:) = temp;
        clear temp;
    case 'log_power'
        % assume log_power
        px = zeros(length(msk),nframes);
        px(msk,:) = exp(x/params.logfactor);
        temp = phase;
        phase = zeros(length(msk),nframes);
        phase(msk,:) = temp;
        clear temp;
    otherwise
        error('expected a input type')
end

% remove pfloor
if pfloor > 0
    px = max(0, px - pfloor);
end


sx = sqrt(px).*exp(1i*phase);
% experiment
sx(end,:) = real(sx(end,:));
assignin('base','sx2',sx);

params.lag =  params.nshift/params.nframe_smooth * floor((params.nframe_smooth-1)/2);
y = cat(1,zeros(params.lag,1),istft(sx, params.nshift, params.swin, params));


