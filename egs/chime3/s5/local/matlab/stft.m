function [spec,spec_full] = stft(x,flength,fshift,w,opts)
% Short-Time Fourier Transform for single or multichannel signals
% December 2010, Jonathan Le Roux.

% Input
%  x            data vector
%  flength      frame length 
%  fshift       frame shift 
%  w            analysis window

if mod(flength,2) == 1
    error('odd ffts not yet implemented')
end



if size(x,2)>size(x,1)
    x=x'; % ensure the channels correspond to columns of x
end
I= size(x,2);

if nargin < 3
   fshift=flength/2; 
end
Q=flength/fshift;
if ~exist('opts','var')
    opts = struct;
end
if ~isfield(opts, 'framepadding')
    opts.framepadding = 0;
end 
if ~isfield(opts, 'padded_framesize')
    opts.padded_framesize = opts.framesize;
end

if opts.framepadding == 1
    x=cat(1,zeros((Q-1)*fshift,I),x,zeros((Q-1)*fshift,I));%padding with 0 for perfect reconstruction near the boundaries
end
T = size(x,1);

M=ceil((T-flength)/fshift)+1;
x=cat(1,x,zeros((M-1)*fshift+flength-T,I));

spec=zeros(opts.padded_framesize,M,I);
if nargin<4
    w=sqrt(hann(flength,'periodic'));
else
    if size(w,2)>1, w=w'; end
    if length(w)~=flength, error('The size of the specified window is incorrect'); end
end

for m=1:M
    window = x((1:flength)+(m-1)*fshift,:);
    % this actually has to be done for every window separately
    % for 100% compatibility
    if opts.preemphasis > 0
        window(2:end,:) = window(2:end,:) - opts.preemphasis * window(1:end-1,:);
        window(1,:) = (1 - opts.preemphasis) * window(1,:);
    end
   %frame=bsxfun(@times,x((1:flength)+(m-1)*fshift,:),w);
   frame=bsxfun(@times,window,w);
   temp=fft(frame, opts.padded_framesize);% we use the same normalization as matlab, i.e. 1/T in ifft only
   spec(:,m,:)=temp;
end
spec_full = spec;    
spec=spec(1:(opts.padded_framesize/2+1),:,:);