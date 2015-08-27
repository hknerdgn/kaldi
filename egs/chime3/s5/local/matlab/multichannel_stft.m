function [x,param]=multichannel_stft(xwav,param)

if ~exist('param', 'var')
    param = struct;
end

paramdefaults={ ...    
    'max_channels',          'ns',  '10'   ;...% maximum number of channels in inputfile
    'framesize_ms',          'ns',  '25'   ;...% frame size (window length) in ms
    'nshift_ms',             'ns',  '10'   ;...% frame shift (hop size) in ms
    'Fs',                    'ns',  '16000';...% sampling rate
    % begin some feature extraction parameters for log_spectrum.m
    % note that framesize and nshift parameters are either given at the input
    % or if they are not given, they are derived from the default _ms variants above
    'nframe_smooth',         'ns', '1'    ;...% number of smoothed frames (1 means no smoothing)
    'cut_dc',                'ns', '1'    ;...% remove DC component from features, default is yes!
    'cut_nyquist',           'ns', '0'    ;...% remove omega=pi component from features, default is no
    'split_cep',             'ns', '32'   ;...% number of cepstral coefficients at output if log_spectrum is used to get them
    'logfactor',             'ns', '1'    ;...% logfactor multiplying log(things), can be used to get dB output by giving 10/log(10)
    'logfloor',              'ns', '1e-9' ;...% logfloor added to nonnegative things before taking log of them such as log(things+logfloor)
    };

[nopt,nf]=size(paramdefaults); % nf is always 3 and not used

for i=1:nopt
    if (~isfield(param,paramdefaults{i,1})),
        if (strcmp(paramdefaults{i,2},'string')==1),
            eval(sprintf('param.%s = ''%s'';',paramdefaults{i,1},paramdefaults{i,3}));
        else
            eval(sprintf('param.%s = %s;',paramdefaults{i,1},paramdefaults{i,3}));
        end
    end
end

% feature params
param.fs = param.Fs;
Fs = param.Fs;

if (~isfield(param,'framesize'))
    param.framesize = param.framesize_ms/1000 * Fs;
end

if (~isfield(param,'nshift'))
    param.nshift = param.nshift_ms/1000 * Fs;
end

% window parameter for STFT in log_spectrum
param.awin = ((0.5 - 0.5*cos((1:param.framesize)/param.framesize*2*pi)).^0.85)';

period = param.nshift / param.Fs;

% default is zero padding
param.padded_framesize = 2^(ceil(log2(param.framesize)));

nch=length(xwav);

for i=1:nch,
    [x_amp_spec_zp, x_phase_zp] = log_spectrum(xwav{i},  param, { 'amp_spec' , 'phase' });
    x{i}= x_amp_spec_zp.*exp(sqrt(-1)*x_phase_zp);
    [nfft1,nframes1]=size(x{i});
    if (i==1)
        nfft=nfft1;
        nframes=nframes1;
    else
        assert(nfft==nfft1);
        assert(nframes==nframes1);
    end
end
