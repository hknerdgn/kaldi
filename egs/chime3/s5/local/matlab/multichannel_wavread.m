function [xwav,Fs]=multichannel_wavread(infile,param)

nch=length(infile);
for c=1:nch
    [xNow,fsNow]=wavread(infile{c});
    xwav{c}=xNow;
    if (c==1)
        Fs=fsNow;
    else
        assert(Fs==fsNow);
    end
end