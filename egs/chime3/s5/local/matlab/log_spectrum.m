
function [varargout] = log_spectrum_mask(x, params, outputs)
    %addpath('..\discriminativeTransforms\src')
    if ~exist('outputs','var')
        outputs = {'log_spec'};
    end
    if ischar(outputs)
        outputs = {outputs};
    end
    
    if ~exist('params','var')
        error('at least specify params.framesize')
    end


    if ~isfield(params, 'awin')
        if ~isfield(params, 'framesize')
            error('specify a frame size')
        end
        params.awin = sqrt(hann(params.framesize, 'periodic'));   % 
    end
    params.framesize = length(params.awin);
    
    if ~isfield(params, 'nshift')
        params.nshift = floor(length(params.awin)/2);   % default overlap of 50%
    end

    if ~isfield(params, 'cut_dc')
        params.cut_dc = 0;
    end

    if ~isfield(params, 'cut_nyquist')
        params.cut_nyquist = 0;
    end
    if ~isfield(params, 'nframe_smooth')
        params.nframe_smooth = 1;
    end

    if ~isfield(params, 'logfactor')
        params.logfactor = 10/log(10);
    end
    
    if ~isfield(params, 'dbfloor')
        pfloor = 0;
    else
        pfloor = exp(params.dbfloor/params.logfactor);
    end
    
    if ~isfield(params, 'preemphasis')
        params.preemphasis = 0;
    end
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%
if ~isfield(params,'mask_type') || isempty(params.mask_type)
    params.mask_type = 'off';
end

if ~isfield(params,'mask_arg') || isempty(params.mask_arg)
    params.mask_arg = 0.5;
end

    
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % swin = synthwin(awin, nshift);
    
    if params.nframe_smooth == 1      
        sx = stft(x, params.framesize, params.nshift, params.awin, params);
        px = abs(sx).^2;
		[nfreq,nframes]=size(px);
		
		switch params.mask_type
			case 'off'
				mask = 1;
			case 'random'
				mask = (rand(nfreq,nframes) <= params.mask_arg);
			case 'lowpass'
				mask = ones(nfreq,nframes);
				mask(1:floor(params.mask_arg * nfreq),:) = 0;
		end
	
        px = mask.*px;

    else
        nshift_smooth = params.nshift / params.nframe_smooth;
        if nshift_smooth ~= floor(nshift_smooth)
           error('The smoothing factor should be an integral divisor of the window shift.'); 
        end
        sx = stft(x, params.framesize, nshift_smooth, params.awin, params);
        
        [ndim nframes_full] = size(sx);

        % need integer number of batches of frames to smooth
        nframes = floor(nframes_full/params.nframe_smooth);
        nframes_smoothing = params.nframe_smooth*nframes;
        
          
        sx = sx(:,1:nframes_smoothing);

        px = squeeze(mean(reshape(abs(sx).^2,[ndim, params.nframe_smooth, nframes]),2));
        % could also use the max instead of mean

        % take phase and full fft from center bins 
        ind_center_frames = (1:params.nframe_smooth:nframes_smoothing) + ceil(params.nframe_smooth/2) - 1;   
        sx = sx(:,ind_center_frames);
        
        
    end
            
    
    if ~isfield(params, 'normalize')
        avpowx = 1;
    else
        switch params.normalize
            case 'qtile'
                thresh_qtile = .8;    
                avpowx = normalizer(px,thresh_qtile);
            otherwise
                error ('unknown normalize method');
        end
    end
    
    
    phase = angle(sx);

    px = px./avpowx;
    
    fmin = 1;
    if params.cut_dc
        fmin = 2;
    end
    
    dim = size(sx,1);
    fmax = dim;
    if params.cut_nyquist
        % assume even window length
        fmax = dim - 1;
    end
    
    msk = false(dim,1);
    ind = fmin:fmax;
    msk(ind) = true;
    % compute log spectrum
    if any(ismember({'log_spec', 'log_amp', 'log_mag', 'log_power', 'cepstrum', 'hicep', 'locep', 'hilifter', 'lolifter'}, outputs))
        if isfield(params, 'logfloor') && params.logfloor > 0
            px = max(px, params.logfloor);
	    px = mask.*px;
        %error('logfloor')
        end
        pxdb = params.logfactor*log(px + pfloor);
        % compute cepstrum 
        if any(ismember({'cepstrum', 'hicep', 'locep', 'hilifter', 'lolifter'}, outputs))
            pxdbtemp = pxdb; 
            pxdbtemp(~msk,:) = 0;
            cepx = dct(pxdbtemp);
        end    
    end
    
    
    for iarg = 1:nargout
        arg = outputs{iarg};
        switch arg
            case {'log_power', 'log_spec'}
                varargout{iarg} = pxdb(msk,:);
            case {'log_amp', 'log_mag'}
                varargout{iarg} = 0.5*pxdb(msk,:);
            case {'pow_spec'}
                varargout{iarg} = px(msk,:);
            case {'amp_spec'}
                varargout{iarg} = sqrt(px(msk,:));
            case 'aud_spec'
                varargout{iarg} = px(msk,:) .^ (1/3);
            case 'cepstrum'
                varargout{iarg} = cepx;                
            case 'locep'
                varargout{iarg} = cepx(1:params.split_cep-1,:);                
            case 'hicep'
                varargout{iarg} = cepx(params.split_cep:end,:);
            case 'lolifter'
                temp = cepx;
                temp(params.split_cep:end,:) = 0;
                temp = idct(temp);
                temp = temp(msk,:);
                varargout{iarg} = temp;
            case 'hilifter'
                temp = cepx; 
                temp(1:params.split_cep-1,:) = 0;
                temp = idct(temp);
                temp = temp(msk,:);
                varargout{iarg} = temp;
            case 'phase'                
                varargout{iarg} = phase(msk,:);
            case 'complex'
                varargout{iarg} = sx(msk,:)/sqrt(avpowx);
            case 'log_gain'
                varargout{iarg} = params.logfactor*log(avpowx);
            case 'params'
                varargout{iarg} = params;
            otherwise
                error('unrecognized output type %s', outputs{iarg});
        end
    end
end


function avpow = normalizer(px, qt)

    % sp: input spectrogram
    % qt: threshold quantile

    % normalize by power of frames over a given threshold
    pframe = sum(px);
    sortedpf = sort(pframe);
    thresh = sortedpf(floor(length(pframe)*qt));
    avpow = mean(pframe(pframe>thresh));

end

