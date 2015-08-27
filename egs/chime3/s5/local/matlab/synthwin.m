function w=synthwin(win,njump,s);
% synthwin 
% compute synthesis window given an analysis window 
% so that it the combination of analysis and synthesis windows
% provide perfect reconstruction with a tapered synthesis window


%  optional parameter s varies the shape of the resulting synthesis window
% you probably just want to use the default s = .5 though
% the full window prior to normalizing is the product of 
% an analysis and synthesis window
% suppose we take the full window and factor it 
% so that the total window prior to normaliztion is
% twin  = win.*swin = twin^(s).*twin^(1-s).
% with scalar s.  

% so  presynth window swin = synth window ^ ((1-s)/s)
%             s== 1: swin is rectangle
%             0.5 < s < 1: swin is broader than analysis window
%             s==0.5: swin == analysis window
%             0 < s < 0.5 : swin is narrower than analysis window

% you can also pass in your own synthesis window in s, which will be 
% reweighted so that the full window laps appropriately.
% for vector valued s:  total pre-normalization window twin = win.*s;

% john hershey 11/10/02 

nwin = length(win);
if nargin < 3
  s = 0.5; % 1-> square synth,0.5-> synth=anal, ->0 ->highly tapered synth
end  
if length(s)==1  % synth win derived from analy win via exponent
  twin = win.^(1/s);  % implicit analwin * synthwin
  swin = twin.^(1-s); % synthwin  
elseif length(s)==nwin  % user supplied pre-synth win
  swin = s;
  twin = swin.*win;
else 
  error('invalid window parameter')
end

nback=ceil(nwin/njump);
nwin1=nback*njump;
w=[twin(:); zeros(nwin1-nwin,1)];
w=reshape(w,njump,nback);
w=sum(w,2);
w=repmat(1./w,nback,1);
w=w(1:nwin);

w = w.*swin;


% a simpler version from a simpler time
%function w=synthwin(win,njump);
%nwin = length(win);
%
%nback=ceil(nwin/njump);
%nwin1=nback*njump;
%w=[win(:); zeros(nwin1-nwin,1)];
%w=reshape(w,njump,nback);
%w=sum(w,2);
%w=repmat(1./w,nback,1);
%w=w(1:nwin);
%
