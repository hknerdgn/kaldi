function M=batch_beamform_scp(inwavscps,scenhancescps,outputdir,outrefwavscp,param)
% M=batch_beamform_scp(inwavscps,outputdir,outrefwavscp,param)
% perform data driven beamforming using multiple channels provided in
% the inwavscps cell array
% which is a cell array of scp files to be used for beamforming
% output file is written to outputdir as the same as the input wav path with param.dirdepth dirs
%


if ~exist('param', 'var')
    param = struct;
end

paramdefaults={ ...
    'method',            'string', 'mvdr';...% method of channel conversion
    'context',               'ns',  '5'    ;...% context for filter/regressor
    'fcontext',              'ns',  '3'    ;...% fcontext for filterplus
    'delayrange',            'ns',  '0'    ;...% delay range for fitting (sync differences)
    'pinv_epsilon',          'ns',  '0.1'  ;...% epsilon for pseudo inverse
    'sourcerank',            'ns',  '-1'   ;...
    'dirdepth',              'ns',   '1'   ;...% how many of the parent directories of the input wav file to take to form the output
    'rankmethod',         'string', 'ev',  ;...
    'usemaskvad',         'string', 'false';...
    'processmask',        'string', 'false';...
    'tworound',           'string', 'false';...
    'combinemasks',       'string', 'false';...% combine multichannel masks into a single mask
    'combinemethod',      'string',   'max'; ...% mean, max or min
    'postmask',           'string', 'false';...
    'postmaskmin',            'ns', '0.25' ;...
    'min_lambda',             'ns',  '0.1' ;...% 
    'channel',            'string', 'lch'  ;...% channel to take from inputs if multichannel wav file
    'framesize_ms',          'ns',  '25'   ;...% frame size (window length) in ms
    'nshift_ms',             'ns',  '10'   ;...% frame shift (hop size) in ms
    'enhancedir',        'string',  ''     ;...% enhanced files directory for inputs
    'enhance_mfile',     'string',  ''     ;...% enhancement m-file to run for each channel (not used if enhancedir given or if isempty)
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


num_channels=length(inwavscps);

for j=1:num_channels
  [fid,errmsg]=fopen(inwavscps{j},'r');
  if (fid < 0)
    fprintf('Cannot open file %s for reading, with error mesg %s.\n',inwavscps{j},errmsg);
    return;
  end 
  C{j}=textscan(fid,'%s %s');
  fclose(fid);
end

num_enh_channels=length(scenhancescps);
if (num_enh_channels ~= num_channels)
  fprintf('No appropriate enhance scp provided. Will not use sc enhancements');
else
for j=1:num_channels
  fid=fopen(scenhancescps{j},'r');
  if (fid < 0)
    fprintf('Cannot open file %s for reading, with error mesg %s.\n',scenhancescps{j},errmsg);
    return;
  end
  E{j}=textscan(fid,'%s %s');
  fclose(fid);
end
end

Nlines=length(C{1}{1});

for k=1:Nlines
    uttId=C{1}{1}{k};
    for (c=1:num_channels)
         infile{c}=C{c}{2}{k};
    end
    % make output filename
    [indir, name, ext]=fileparts(infile{1});
    indirtake='';
    for (ddep=1:param.dirdepth)
      [indir2, name2, ext2]=fileparts(indir);
      indirtake=sprintf('%s/%s',name2,indirtake);
      indir=indir2;
    end

    outpath=sprintf('%s/%s%s.wav',outputdir,indirtake,name);
    if (~exist(outpath,'file'))
        fprintf('\n---------------\nWriting to output file %s\n',outpath);
        [xwav,Fs]=multichannel_wavread(infile);
        len1=length(xwav{1});
        param.Fs=Fs;
        [x,param]=multichannel_stft(xwav,param);
        if (num_enh_channels == num_channels)
            for (c=1:num_channels)
                enhfile{c}=E{c}{2}{k};
            end
            
            [xenhwav,Fs]=multichannel_wavread(enhfile);
            for (c=1:num_channels)
		len2=length(xenhwav{c});
		if (len2 > len1)
                	xenhwav{c}=xenhwav{c}(1:len1);
		else
			xenhwav{c}=[xenhwav{c}; zeros(len1-len2,1)];
		end
            end
            [xenh,param]=multichannel_stft(xenhwav,param);
            for (c=1:num_channels)
                param.m{c}=min(1,max(0,abs(xenh{c})./abs(x{c})));
            end
	    if (strcmp(param.combinemasks,'true')),
       		if (strcmp(param.combinemethod,'max')),
			com_mask=zeros(size(param.m{1}));
		        for (c=1:num_channels)
			        com_mask=max(com_mask,param.m{c});
		        end
       		elseif (strcmp(param.combinemethod,'mean')),
			com_mask=zeros(size(param.m{1}));
		        for (c=1:num_channels)
			        com_mask=com_mask+param.m{c};
		        end
			com_mask=com_mask./num_channels;
       		elseif (strcmp(param.combinemethod,'min')),
			com_mask=ones(size(param.m{1}));
		        for (c=1:num_channels)
			        com_mask=min(com_mask,param.m{c});
		        end
		end
		% set all masks to the common mask, so that we do not change the rest of the code
 	        for (c=1:num_channels)
		        param.m{c}=com_mask;
	        end
                fprintf('Combining channel masks with %s.\n',param.combinemethod);
	    end
        end
	param.exclude_channels=[];
	param.channel_badness=zeros(1,num_channels);
	for j=1:num_channels
		difen=sum(diff(xwav{j}).^2)/sum(xwav{j}.^2);
		ddifen=sum(diff(diff(xwav{j})).^2)/sum(xwav{j}.^2);
		enprof=filter(ones(1,2*Fs/100),1,abs(xwav{j}));
		enprof=enprof(Fs/100:Fs/100:end);
		diflen=sum(diff(enprof).^2)./sum(enprof.^2);
		minenr=sum(enprof < max(enprof)/20)/length(enprof);
		rtzero=sum(xwav{j}==0)/length(xwav{j});
	 	bdness=diflen+difen/4+ddifen/3+minenr+5*rtzero;
		param.channel_badness(j)=bdness;
	end
	medbad=median(param.channel_badness);
	param.exclude_channels = find(param.channel_badness > 1.5*medbad);
        % param.m=multichannel_sc_enhance(xwav,param); % enhance each channel as a
        % single channel to obtain an initial mask
	%param.sourcerank=2;
	%param.process_mask=1;
        [y,g,ref,newmask]=beamform_mvdr_new(x,param);
        if (strcmp(param.tworound,'true'))
	  param.m=newmask;
          fprintf('Doing second round:\n');
          [y,g,ref,newmask]=beamform_mvdr_new(x,param);
	  param=rmfield(param,'m');
        end
	if (strcmp(param.postmask,'true'))
		postmask=param.m{ref}; % this is combined mask if combinemask was chosen!!
		postmask(postmask < param.postmaskmin)=param.postmaskmin;
		y=y.*postmask;
		fprintf('Post masking with mic %d s mask with minimum allowed mask %.2f.\n',ref,param.postmaskmin);
	end
	refwav{k}=C{ref}{2}{k}; % full wave file path corr to the ref mic
	refuttid{k}=C{ref}{1}{k}; % uttId
        mag=abs(y);
        phase=angle(y);
        param.inputtype='amp_spec';
        [ywav, paramout]=resynth_log_spec(mag,phase,param);
        ywav=ywav(1:len1);
	ywav=0.5*ywav./max(ywav); % to avoid clipping
        [base, dir]=basename(outpath);
        if (~exist(dir,'dir'))
            mkdir(dir);
        end
        wavwrite(ywav,Fs,16,outpath);
	txtfile=sprintf('%s.ref.txt',outpath);
	FID=fopen(txtfile,'w');
	fprintf(FID,'%d',ref);
	fclose(FID);
	for i=1:num_channels
		filter_real=real(squeeze(g(:,ref,i)));
		filter_imag=imag(squeeze(g(:,ref,i)));
		filter_ri(i,:)=[filter_real(:)' filter_imag(:)'];
	end
        save(sprintf('%s.filters.txt',outpath),'filter_ri','-ascii');
    else
        fprintf('\n--------------\nSkipping output file %s since it exists\n',outpath);
	txtfile=sprintf('%s.ref.txt',outpath);
	FID=fopen(txtfile,'r');
	refstr=fgets(FID);
	ref=strread(refstr,'%d');
	fclose(FID);
	refwav{k}=C{ref}{2}{k}; % full wave file path corr to the ref mic
	refuttid{k}=C{ref}{1}{k}; % uttId
    end
end


[FIDref,errmsg]=fopen(outrefwavscp,'w');
if (FIDref < 0)
  fprintf('Cannot open file %s for writing, with error mesg %s.\n',outrefwavscp,errmsg);
  return;
end
for k=1:Nlines,
  fprintf(FIDref,'%s %s\n',refuttid{k},refwav{k});
end
fclose(FIDref);

M=1;% for success

end
