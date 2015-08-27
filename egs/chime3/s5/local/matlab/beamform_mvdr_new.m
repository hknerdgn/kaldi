function [z,g,ref,newmask] = beamform_mvdr(y, param)
% [z, filters, ref] = beamform_mvdr(y, param)
% y and param.m are cell arrays of STFTs and masks respectively.
% All y{i} and param.m{i} for all i should have the same dimensions
% Finds a filter-and-sum beamforming result STFT z which will form a signal closer
% to the reference clean signal (after masking) and also makes the noise parts
% after beamforming close to zero

% reference signal can be given as a param, or a way to choose it can be
% given

if ~exist('param', 'var')
    param = struct;
end

paramdefaults={ ...
    'method',           'string', 'filter';...% method of filtering
    'refmic',                'ns',  '5'   ;...% constant reference mic
    'epsilon_phivv',         'ns',  '0.0001' ;...% epsilon for phivv
    'damp_phivv',            'ns',  '0.8' ;...% damping factor for phivv
    'min_lambda',            'ns',  '0.1' ;...% minimum lambda
    'mratio',                'ns',  '0.05' ;...% ratio of length of file where mask=0 from begin+end
    'mframes',               'ns',  '100'  ;...% frames where mask=0 from begin+end
    'usemaskvad',            'string',   'true';...% use mask as a VAD
    'exclude_channels',      'ns',  '[]'   ;...% exclude channels
    'sourcerank',           'ns',  '-1'    ;...% rank of the source spatial covariance phixx, -1 for ignoring it
    'rankmethod',            'string',  'gev'  ;...% ranking eigenvalues method
    'processmask',          'string',  'false'    ;...% smoothen the mask and make it higher
    'channel_badness',       'ns',  '0'   ;...% channel badness
    'beta',                  'ns',  '0'   ;...% beta for mvdr
    'optConfUp',             'ns',  '0.90' ;...% confident region mask value must be greater
    'optConfDown',           'ns',  '0.30' ;...% confident region mask value must be less
    'noisychannels',         'ns',  ''     ;...% list of noisy channels not be included in the first round of beamforming
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

nch=length(y);
[nfft,nframes]=size(y{1});

noisyframeratio=1;

if (~isfield(param,'m'))
    fprintf('No mask given, will assume param.mframes in the begin and end of file to be mask=0 and rest mask=1\n');
    nfrz=min(floor(nframes/4),floor(param.mframes/2));
    %nfrz=floor(nframes*param.mratio/2);
    for i=1:nch,
        m{i}=ones(nfft,nframes);
        m{i}(:,1:nfrz)=0.0;
        m{i}(:,end-nfrz+1:end)=0.0;
    end
    noisyframeratio=2*nfrz/nframes;    
else
  fprintf('Mask given and will be used.\n');
  m=param.m;
  if (strcmp(param.processmask, 'true'))
   fprintf('Processing mask to be higher and smoother\n');
   for i=1:nch,
    %size(m{i})
    m{i}=sqrt(m{i});  % make it unlikely to lose real speech under low mask
    m{i}=medfilt2(m{i},[9,3]); % smoothen the mask with median filter
   end
  end
  if (strcmp(param.usemaskvad,'true'))
      fprintf('Using the mask for VAD determination\n');
  % one forth of chosen frames, never to exceed half of the utterance
      nfrz=min(floor(nframes/8),floor(param.mframes/4));
      for i=1:nch,
  % first half coming from begin and end portions
          m{i}=ones(nfft,nframes);
          noisyframes=[1:nfrz, nframes-nfrz+1:nframes];
  % second half coming from lowest mask-sum frames
          sumcolmask=sum(param.m{i}(:,:),1);
          check=nfrz+1:nframes-nfrz;
          [sv,si]=sort(sumcolmask(check),'ascend');
          noisyframes=[noisyframes, check(si(1:2*nfrz))];
          m{i}(:,noisyframes)=0.0;
      end
      noisyframeratio=4*nfrz/nframes;    
  elseif (strcmp(param.usemaskvad,'trust'))
      fprintf('Using the mask for VAD determination\n');
  % find maskvad from masksum < 0.25 for each frame
      for i=1:nch,
          sumcolmask=sum(param.m{i}(:,:),1);
	  noisyframes=find(sumcolmask/nfft < 0.25);
          m{i}(:,noisyframes)=0.0;
      end
  else
      fprintf('Using the mask directly\n');
      nch2=length(m);
      assert(nch==nch2);
      [nfft2,nframes2]=size(m{1});
      assert(nfft==nfft2);
      assert(nframes==nframes2);
  end
end

if (strcmp(param.rankmethod,'evbest'))
  fprintf('Using eigen-decomposition with eigendirections SNR > 1\n');
elseif (strcmp(param.rankmethod,'gevbest'))
  fprintf('Using generalized eigen-decomposition with eigendirections SNR > 1 \n');
elseif (param.sourcerank > 0 && strcmp(param.rankmethod,'ev'))
  fprintf('Using eigen-decomposition with sourcerank %d\n',param.sourcerank);
elseif (param.sourcerank > 0 && strcmp(param.rankmethod,'gev'))
  fprintf('Using generalized eigen-decomposition with sourcerank %d\n',param.sourcerank);
end
fprintf('Noisy frame ratio=%f\n',noisyframeratio);

% beamform y{1..end} to obtain z

bf_filters=zeros(nfft,nch,nch); % second (nch) dimension is ref mic and third (nch) is for each mic

if (strcmp(param.method,'mvdr'))
    fprintf('nfft=%d, nframes=%d, nch=%d\n',nfft,nframes,nch);
    ref=param.refmic;
    if (ismember(ref,param.exclude_channels))
	[dummy,ref]=min(param.channel_badness);
    end
    nch_total=nch;
    n_excl=length(param.exclude_channels);
    if (n_excl > 0)
	fprintf('Exclude channels ');
	fprintf('%d ',param.exclude_channels);
	fprintf('\n');	
	taken_channels=setdiff(1:nch,param.exclude_channels);
	ref=find(taken_channels==ref);
    else
	taken_channels=1:nch;
	fprintf('Include all channels\n');
    end
    fprintf('Channel badnesses ');
    fprintf('%.2f ',param.channel_badness);
    fprintf('\n');
    nch=nch_total-n_excl;
    phiyy=zeros(nch,nch);
    phivv=zeros(nch,nch);
    Y=zeros(nfft,nframes,nch);
    V=zeros(nfft,nframes,nch);
    hnow=zeros(1,1,nch);
    target_est=zeros(nch,nfft,nframes);
    maskratio=zeros(1,nch);
    j=0;
    for jj=1:nch_total
	if (ismember(jj,param.exclude_channels)) 
		continue; 
	end
	j=j+1;
	Y(:,:,j)=y{jj}(:,:);
	V(:,:,j)=y{jj}(:,:).*(1-m{jj}(:,:));
	maskratio(j)=sum(m{jj}(:))/(nfft*nframes);
        fprintf('Mask ratio for channel %d is %f\n',jj,maskratio(j));
        %[h,b]=hist(m{jj}(:),10);
        %fprintf('%.1f ',b);fprintf('\n');
        %fprintf('%d ',h);fprintf('\n');
    end
    noise_en=zeros(1,nch);
    signal_en=zeros(1,nch);
    for f=1:nfft
	ych=squeeze(Y(f,:,:));
	vch=squeeze(V(f,:,:));
	phiyy=(ych'*ych)';
	%phivv=param.damp_phivv*1/noisyframeratio*(vch'*vch)';
	phivv=(vch'*vch)';
   	[vv,dv]=eigs(phivv,1); % largest eigenvalue of phivv
        if (dv < 0.0001) dv =0.0001; end
	% regularize these things, we need to add a larger regularization matrix to phiyy
	% sinve phiyy is the sum of phixx and phivv and it may be necessary to regularize both phixx and phivv
	%phiyy=phiyy+2*param.epsilon_phivv*eye(nch);
	%phivv=phivv+param.epsilon_phivv*eye(nch);
	%phiyy=phiyy+2*dv/1000*eye(nch);
	phiyy=phiyy+2*dv/1000*eye(nch);
	phivv=phivv+dv/1000*eye(nch);
	if (strcmp(param.rankmethod,'evbest'))
		%fprintf('Using eigen-decomposition with sourcerank %d',param.sourcerank);
       		phixx=phiyy-phivv;
   	 	[v,d]=eigs(phixx,nch); % investigate joint diagonalization of phiyy and phivv later
		dd=diag(d);
		noise_d=diag(v'*phivv*v);
		eig_snrs=dd(:)./noise_d(:);
   		%fprintf('SNRs:');
		%fprintf('%.1f ',eig_snrs);
   		%fprintf('\n');
   		chose=find(eig_snrs > 1);
		if (isempty(chose)) chose=1; end
		phixx_est=v(:,chose)*diag(dd(chose))*v(:,chose)'; % an estimate of phixx
		phivv=phiyy-phixx_est; % an estimate of phivv obtained from limited-rank assumption
	        preSNR=phivv\phiyy; % inv(phivv)*phiyy
	elseif (strcmp(param.rankmethod,'gevbest'))
		%fprintf('Using generalized eigen-decomposition with sourcerank %d',param.sourcerank);
       		phixx=phiyy-phivv;
   	 	[v,d]=eigs(phivv\phixx,nch); % joint diagonalization of phiyy and phivv
 		dd=diag(d);
   		%fprintf('SNRs:');
		%fprintf('%.1f ',dd);
   		%fprintf('\n');
   		chose=find(dd > 1);
		if (isempty(chose)) chose=1; end
                preSNR=eye(nch)+v(:,chose)*diag(dd(chose))*v(:,chose)';
	elseif (param.sourcerank > 0 && strcmp(param.rankmethod,'ev'))
		%fprintf('Using eigen-decomposition with sourcerank %d',param.sourcerank);
       		phixx=phiyy-phivv;
   	 	[v,d]=eigs(phixx,nch); % investigate joint diagonalization of phiyy and phivv later
		dd=diag(d);
		noise_d=diag(v'*phivv*v);
		eig_snrs=dd(:)./noise_d(:);
		[sv, si]=sort(eig_snrs,'descend');
   		chose=si(1:param.sourcerank);
		phixx_est=v(:,chose)*diag(dd(chose))*v(:,chose)'; % an estimate of phixx
		phivv=phiyy-phixx_est; % an estimate of phivv obtained from limited-rank assumption
	        preSNR=phivv\phiyy; % inv(phivv)*phiyy
	elseif (param.sourcerank > 0 && strcmp(param.rankmethod,'gev'))
		%fprintf('Using generalized eigen-decomposition with sourcerank %d',param.sourcerank);
       		phixx=phiyy-phivv;
   	 	[v,d]=eigs(phivv\phixx,param.sourcerank); % joint diagonalization of phiyy and phivv
                preSNR=eye(nch)+v*d*v';
        else
		preSNR=phivv\phiyy;
	end
	lambda_f=trace(preSNR)-nch;
        %fprintf('%f ',lambda_f);
        if (lambda_f < param.min_lambda) 
		%fprintf('lambda_f=%f < %f for f=%d. Should not happen!! Setting back to %f.\n',lambda_f,param.min_lambda,f,param.min_lambda);
		lambda_f=param.min_lambda;
        end
	h=1/(param.beta+lambda_f)*(preSNR-eye(nch));
	% calc error energy for each possible ref channel
	for j=1:nch
		noise_en(j)=noise_en(j)+abs(h(:,j)'*phivv*h(:,j));
		signal_en(j)=signal_en(j)+abs(h(:,j)'*phiyy*h(:,j));
		hnow=reshape(h(:,j),[1 1 nch]);
		target_est(j,f,:)=sum(bsxfun(@times,Y(f,:,:),hnow),3);
                bf_filters(f,taken_channels(j),taken_channels(1:nch))=hnow;
	end
    end
    mysnr=signal_en./noise_en;
    for ii=1:length(param.noisychannels)
      mysnr(taken_channels == param.noisychannels(ii))=0; % to avoid taking noisychannels as ref
    end
    [max_snr, ref]=max(mysnr);
else
    fprintf('method not implemented %s.\n', param.method);
    return;
end

fprintf('Final ref mic is %d\n',taken_channels(ref));
    fprintf('Taken channel residual noise and signal energies and SNR ');
    fprintf('\n CH  ');
    fprintf('%3d      ',taken_channels);
    fprintf('\n N   ');
    fprintf('%.2e ',noise_en);
    fprintf('\n S   ');
    fprintf('%.2e ',signal_en);
    fprintf('\n SNR ');
    fprintf('%.2e ',signal_en./noise_en);
    fprintf('\n');
z=squeeze(target_est(ref,:,:));
g=bf_filters;
ref=taken_channels(ref);
newmask=cell(1,nch_total);
for jj=1:nch_total,
  j=find(taken_channels == jj);
  if (isempty(j)),
    newmask{jj}=ones(nfft,nframes);
  else
    newmask{jj}=min(1,max(0,abs(squeeze(target_est(j,:,:)))./abs(y{jj}(:,:))));
  end
end
