function signal = istft(spec,fshift,s,opts)

% Inverse STFT by overlap-add for single or multichannel signals
% December 2010, Jonathan Le Roux
%
% Input
%  spec         STFT spectrogram (nbin x nframes x nchannels)
%  fshift       frame shift
%  s            synthesis window function (default: sqrt(hanning))
%
% Output
%  signal       resynthesized signal (column vector)

[N,M,I]=size(spec);
if mod(N,2)==1
    flength=2*(N-1);
    %spec=cat(1,spec,conj(flipdim(spec(2:(N-1),:,:),1)));
else
    flength=N;
end
if ~exist('opts','var')
    opts = struct;
end

if ~isfield(opts, 'framepadding')
    opts.framepadding = 0;
end 

Q=flength/fshift;
if ~exist('s','var')||isempty(s)
    s = sqrt(hann(opts.framesize,'periodic'))*2/Q;
else
    if size(s,2)>1, s=s'; end
    if length(s)~=opts.framesize, error('The size of the specified window is incorrect'); end
end

T=fshift*(M-1)+flength;
signal=zeros(T,I);

for m=1:M
   iframe=ifft(reshape(spec(:,m,:),[],I),flength,'symmetric');
   iframe=iframe(1:opts.framesize,:);
   signal((m-1)*fshift+(1:opts.framesize),:)=signal((m-1)*fshift+(1:opts.framesize),:)...
       + bsxfun(@times,iframe,s);    
end

if opts.framepadding == 1
    signal=signal(((Q-1)*fshift+1):(T-(Q-1)*fshift),:);    
end
