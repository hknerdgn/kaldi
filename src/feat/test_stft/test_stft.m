% Copyright 2015 Hakan Erdogan

% matlab script for testing kaldi stft implementation
% stft.m and istft.m are written to mimic kaldi stft extraction in matlab
% these matlab scripts can also be used to perform stft and istft
% The produced STFTs are compared between matlab and kaldi
% matlab version also can perform output_type='complex' which gives complex STFT and 
% matlab version has snip_edges='perfect' for perfect reconstruction.
% Note that: istft.m does not use any window (or uses rectangular window), this is deliberate
% and the reason is that if the num_fft is larger than the frame_length, the signal should not be windowed
% before overlap-add

warning('off','all');

[x,fs]=wavread('test.wav');
x=2^15 * x; % kaldi uses 16 bit integers directly whereas matlab scales to -+1 range
param.samp_freq=fs;
param.window_type='hamming';
param.frame_shift_ms=10;
param.frame_length_ms=30;
param.round_to_power_of_two='true';
param.snip_edges='false';
param.output_type='real_and_imaginary';
param.output_layout='block';
param.cut_dc='false';
param.cut_nyquist='false';
param.nsamples=length(x);
param
fp=param.frame_length_ms*0.001; % frame period in seconds

Sx1=stft(x,param);
writehtk('test.wav.stft_htk.1',Sx1.',fp,9);
xhat1=istft(Sx1,param);
fprintf('NMSE between istft(stft(x)) and x = %f .\n',norm(x-xhat1)/norm(x));

param.output_type='real_and_imaginary';
param.output_layout='interleaved';
param.cut_dc='false';
param.cut_nyquist='false';
param

Sx2=stft(x,param);
writehtk('test.wav.stft_htk.2',Sx2.',fp,9);
xhat2=istft(Sx2,param);
fprintf('NMSE between istft(stft(x)) and x = %f .\n',norm(x-xhat2)/norm(x));

param.round_to_power_of_two='false';
param.output_type='real_and_imaginary';
param.output_layout='block';
param.cut_dc='false';
param.cut_nyquist='false';
param

Sx3=stft(x,param);
writehtk('test.wav.stft_htk.3',Sx3.',fp,9);
xhat3=istft(Sx3,param);
fprintf('NMSE between istft(stft(x)) and x = %f .\n',norm(x-xhat3)/norm(x));

param.round_to_power_of_two='true';
param.output_type='real_and_imaginary';
param.output_layout='block';
param.cut_dc='false';
param.cut_nyquist='true';
param

Sx4=stft(x,param);
writehtk('test.wav.stft_htk.4',Sx4.',fp,9);
xhat4=istft(Sx4,param);
fprintf('NMSE between istft(stft(x)) and x = %f .\n',norm(x-xhat4)/norm(x));

param.snip_edges='true';
param.output_type='real_and_imaginary';
param.output_layout='block';
param.cut_dc='false';
param.cut_nyquist='false';
param

Sx5=stft(x,param);
writehtk('test.wav.stft_htk.5',Sx5.',fp,9);
xhat5=istft(Sx5,param);
fprintf('NMSE between istft(stft(x)) and x = %f .\n',norm(x-xhat5)/norm(x));


% now lets check something else unrelated to kaldi
param.num_fft=1024;
param.snip_edges='perfect';
param.output_type='complex';
param.window_type='rectangular';
%param.window_type='hamming';
Sx6=stft(x,param);
% define a random FIR filter
LH=500;
h=rand(LH,1);
Sh=fft(h,param.num_fft);
Sxh6=bsxfun(@times,Sx6,Sh(1:(param.num_fft/2+1)));
hconvx1=conv(h,x);  % find convolution directly
param.nsamples=length(hconvx1);
param
hconvx2=istft(Sxh6,param);   % this should also work for convolution
range=LH+1:param.nsamples-LH-1; % due to symmetry at the edges for stft, the results will not be the same
range=1:param.nsamples; % due to symmetry at the edges for stft, the results will not be the same
fprintf('NMSE between istft(H . stft(x)) and h*x = %f .\n',norm(hconvx1(range)-hconvx2(range))/norm(hconvx1(range)));
