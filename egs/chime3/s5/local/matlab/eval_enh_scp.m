% Evaluate the eval_scp files listed in the given scp file against
% the clean reference clean_scp using the noisy signals noisy_scp,
% in terms of source separation measures, and compute
% the results to be written in outbase.mat and outbase.csv
function [ measures ] = eval_enh_scp(eval_scp, noisy_scp, clean_scp, outbase, param)
% function [ measures ] = eval_enh_scp(eval_scp, noisy_scp, clean_scp, outbase, param)
% writes evaluation results to outbase.mat and outbase.csv

if ~exist('outbase', 'var')
	error('Please provide outbase')
end

if (~exist('param','var'))
	param=struct;
end

if (~isfield(param,'channel'))
	param.channel='lch';
end

if (~isfield(param,'pesqbinary'))
	param.pesqbinary='/data/erdogan/erdogan04/tools/pesq_bin/pesq';
end

% for new dataset, write the get_utt_lev_spk part at the bottom
% supported datasets: chime2 and timit_carnoise, timit_carnoise2

if (~isfield(param,'dataset'))
	param.dataset='unknown';
end

if (~isfield(param,'eval_mixture'))
	param.eval_mixture=1;
end

if (~isfield(param,'eval_segsnr'))
	param.eval_segsnr=1;
end
if (~isfield(param,'eval_pesq'))
	param.eval_pesq=1;
end
if (~isfield(param,'eval_stoi'))
	param.eval_stoi=1;
end
if (~isfield(param,'eval_bss'))
	param.eval_bss=1;
end

eval_mixture = param.eval_mixture;
eval_bss = param.eval_bss;
eval_pesq = param.eval_pesq;
eval_segsnr = param.eval_segsnr;
eval_stoi = param.eval_stoi;

resmatfile=strcat(outbase,'.mat');
rescsvfile=strcat(outbase,'.csv');

if exist(resmatfile,'file') && ~isfield(param,'measures');
    fprintf('The file %s exists. Doing nothing!...\n',resmatfile);
    return
end

fid1 = fopen(eval_scp, 'r');
fid2 = fopen(noisy_scp, 'r');
fid3 = fopen(clean_scp, 'r');

res_fid = fopen(rescsvfile, 'w');


C1=textscan(fid1,'%s %s');
C2=textscan(fid2,'%s %s');
C3=textscan(fid3,'%s %s');

fclose(fid1);
fclose(fid2);
fclose(fid3);

N1=length(C1{1});
N2=length(C2{1});
N3=length(C3{1});

assert(N1<=N2); % eval scp should be a subset of noisy and clean ones
assert(N1<=N3);

if (~isfield(param,'measures'))
	measures = repmat(struct('lev', '--', 'spk', '--', 'utt', '--', 'sdr', 0, 'sar', 0, 'sir', 0), N1, 1);
else
	measures = param.measures; % to load an earlier run of measures
end

for i=1:N1
    eval_utt = C1{1}{i};
    jj=find(ismember(C2{1},eval_utt));
    kk=find(ismember(C3{1},eval_utt));
    if (isempty(jj) || isempty(kk))
	fprintf('utt id %s not found in %s or %s.\nQuitting...\n',eval_utt,noisy_fname, clean_fname);
	return;
    end
    %noisy_utt = C2{1}{jj};
    %clean_utt = C3{1}{kk};
    

    eval_fname = C1{2}{i};
    noisy_fname = C2{2}{jj};
    clean_fname = C3{2}{kk};
    
    [y, Fs] = wavread(clean_fname);

    if strcmp(param.channel, 'lch')
       y = y(:, 1);
    elseif strcmp(param.channel, 'rch')
       y = y(:, 2);
    elseif strcmp(param.channel, 'sum')
       y = mean(y, 2);
    end

    [x, Fs] = wavread(noisy_fname);

    if strcmp(param.channel, 'lch')
       x = x(:, 1);
    elseif strcmp(param.channel, 'rch')
       x = x(:, 2);
    elseif strcmp(param.channel, 'sum')
       x = mean(x, 2);
    end
    
    [yhat, Fs] = wavread(eval_fname);
    yhat = yhat(:, 1);
    
    measures(i).noisy_fname = noisy_fname;
    measures(i).clean_fname = clean_fname;
    measures(i).eval_fname = eval_fname;

    [utt,lev,spk] = get_utt_lev_spk(eval_fname,param.dataset);

    measures(i).lev = lev;
    measures(i).spk = spk;
    measures(i).utt = eval_utt;
    %measures(i).utt = utt;
    
    nsamp = min([ size(x, 1) size(y, 1) size(yhat, 1) ]);
    x = x(1:nsamp, :);
    y = y(1:nsamp, :);
    yhat = yhat(1:nsamp, :);
    
    n = x - y;
    nhat = x - yhat;
    
    src = [ y'; n' ];
    se  = [ yhat'; nhat' ];
    if eval_mixture
        sb = [ x'; zeros(length(x), 1)' ];
    end
    
    if eval_bss
    [sdr, sir, sar]  = bss_eval_sources_nosort(se, src);
    measures(i).sdr = sdr(1);
    measures(i).sir = sir(1);
    measures(i).sar = sar(1);
    end

    % pesq
    if eval_pesq
    [pesqwb] = pesqbin(y,yhat,Fs,'wb',param.pesqbinary);
    [pesqnb] = pesqbin(y,yhat,Fs,'nb',param.pesqbinary);
    measures(i).pesqwb = pesqwb;
    measures(i).pesqnbm = pesqnb(1);
    measures(i).pesqnbl = pesqnb(2);
    end

    % STOI
    if eval_stoi
    stoi_enh = stoi(y, yhat, Fs);
    measures(i).stoi = stoi_enh;
    end

    % segsnr and glosnr
    % if have signal processing toolbox, using 'Vq' argument instead of 'wz' may be better
    if eval_segsnr
    [segsnr,glosnr]=snrseg(yhat,y,Fs,'wz',0.03);
    measures(i).segsnr = segsnr;
    measures(i).glosnr = glosnr;
    end
    
    if eval_mixture
	if eval_bss
        [bsdr, bsir, bsar] = bss_eval_sources_nosort(sb, src);
        measures(i).bsdr = bsdr(1);
        measures(i).bsir = bsir(1);
        measures(i).bsar = bsar(1);
	end
	% pesq
	if eval_pesq
        [bpesqwb] = pesqbin(y,x,Fs,'wb',param.pesqbinary);
        [bpesqnb] = pesqbin(y,x,Fs,'nb',param.pesqbinary);
        measures(i).bpesqwb = bpesqwb;
        measures(i).bpesqnbm = bpesqnb(1);
        measures(i).bpesqnbl = bpesqnb(2);
	end
	% stoi
	if eval_stoi
        stoi_mix = stoi(y, x, Fs);
        measures(i).bstoi = stoi_mix;
	end
        % segsnr and glosnr
        % if have signal processing toolbox, using 'Vq' argument instead of 'wz' may be better
	if eval_segsnr
        [bsegsnr,bglosnr]=snrseg(x,y,Fs,'wz',0.03);
        measures(i).bsegsnr = bsegsnr;
        measures(i).bglosnr = bglosnr;
	end
    end
    
    %fprintf('enh wav = %s: SDR = %.2f, SIR = %.2f, SAR = %.2f\n', enh_wav, measures(i).sdr, measures(i).sir, measures(i).sar);
    %fprintf('noisy wav = %s: SDR = %.2f, SIR = %.2f, SAR = %.2f\n\n', noisy_wav, measures(i).bsdr, measures(i).bsir, measures(i).bsar);
    
    if eval_mixture
	if eval_bss
        fprintf('%s %s @ %s [ %d / %d ] SDR = %.2f dB, mixSDR = %.2f dB, Gain = %.2f dB\n', utt, spk, lev, i, N1, measures(i).sdr, measures(i).bsdr ,measures(i).sdr - measures(i).bsdr);
        fprintf('%s %s @ %s [ %d / %d ] SIR = %.2f dB, mixSIR = %.2f dB, Gain = %.2f dB\n', utt, spk, lev, i, N1, measures(i).sir, measures(i).bsir ,measures(i).sir - measures(i).bsir);
	end
	if eval_pesq
        fprintf('%s %s @ %s [ %d / %d ] PESQ = %.2f, mixPESQ = %.2f, Gain = %.2f\n', utt, spk, lev, i, N1, measures(i).pesqwb, measures(i).bpesqwb ,measures(i).pesqwb - measures(i).bpesqwb);
	end
	if eval_stoi
        fprintf('%s %s @ %s [ %d / %d ] STOI = %.2f, mixSTOI = %.2f, Gain = %.2f\n', utt, spk, lev, i, N1, measures(i).stoi, measures(i).bstoi ,measures(i).stoi - measures(i).bstoi);
	end
	if eval_segsnr
        fprintf('%s %s @ %s [ %d / %d ] SSNR = %.2f, mixSSNR = %.2f, Gain = %.2f\n', utt, spk, lev, i, N1, measures(i).segsnr, measures(i).bsegsnr ,measures(i).segsnr - measures(i).bsegsnr);
        fprintf('%s %s @ %s [ %d / %d ] SNR = %.2f, mixSNR = %.2f, Gain = %.2f\n', utt, spk, lev, i, N1, measures(i).glosnr, measures(i).bglosnr ,measures(i).glosnr - measures(i).bglosnr);
	end
    else
	if eval_bss
        fprintf('%s %s @ %s [ %d / %d ] SDR = %.2f dB\n', utt, spk, lev, i, N1, measures(i).sdr);
        fprintf('%s %s @ %s [ %d / %d ] SIR = %.2f dB\n', utt, spk, lev, i, N1, measures(i).sir);
	end
	if eval_pesq
        fprintf('%s %s @ %s [ %d / %d ] PESQ = %.2f\n', utt, spk, lev, i, N1, measures(i).pesqwb);
	end
	if eval_stoi
        fprintf('%s %s @ %s [ %d / %d ] STOI = %.2f\n', utt, spk, lev, i, N1, measures(i).stoi);
	end
	if eval_segsnr
        fprintf('%s %s @ %s [ %d / %d ] SSNR = %.2f\n', utt, spk, lev, i, N1, measures(i).segsnr);
        fprintf('%s %s @ %s [ %d / %d ] SNR = %.2f\n', utt, spk, lev, i, N1, measures(i).glosnr);
	end
    end
    
	if eval_bss
        fprintf(res_fid,'%s, %d, %s, %s, %.2f, ', utt, i, spk, lev, measures(i).sdr);
        fprintf(res_fid,'%.2f, ', measures(i).sir);
        fprintf(res_fid,'%.2f, ', measures(i).sar);
	end
	if eval_pesq
        fprintf(res_fid,'%.2f, ', measures(i).pesqwb);
	end
	if eval_stoi
        fprintf(res_fid,'%.2f, ', measures(i).stoi);
	end
	if eval_segsnr
        fprintf(res_fid,'%.2f, ', measures(i).segsnr);
        fprintf(res_fid,'%.2f, ', measures(i).glosnr);
	end
	fprintf(res_fid,'\n');
end

save(resmatfile, 'measures');

fclose(res_fid);

function [utt,lev,spk]=get_utt_lev_spk(filename,dataset)
    if (strcmp(dataset,'timit_carnoise') || strcmp(dataset,'TC'))
    	[utt, dirname] = basename(filename, '.wav');
    	lev = utt(end-9:end-8); % lev
    	if (strcmp(lev,'r0'))
       	   lev ='0';
    	end
    	spk = dirname;
    elseif (strcmp(dataset,'timit_carnoise2') || strcmp(dataset,'TC2'))
    	[utt, dirname] = basename(filename, '.wav');
    	lev = utt(end-6:end-4); % lev
    	spk = utt(1:1);
    elseif (strcmp(dataset,'chime2') || strcmp(dataset,'CH2') || strcmp(dataset,'CH'))
    	[utt, dirname] = basename(filename, '.wav');
        idx = find(dirname == '/');
        lev = dirname(idx(2)+1:idx(3)-1); % lev
        spk = dirname(idx(end)+1:end);
    elseif (strcmp(dataset,'chime2_orig') || strcmp(dataset,'CH2org') || strcmp(dataset,'CH2orig') )
    	[utt, dirname] = basename(filename, '.wav');
        idx = find(dirname == '/');
        lev = dirname(idx(2)+1:idx(3)-1); % lev
        spk = dirname(idx(end)+1:end);
    elseif (strcmp(dataset,'chime3') || strcmp(dataset,'CH3'))
    	[utt, dirname] = basename(filename, '.wav');
        lev = utt(14:16); % type of noise
        spk = utt(1:3);
    elseif (strcmp(dataset,'chime3_simu') || strncmp(dataset,'CH3sim',6))
    	[utt, dirname] = basename(filename, '.wav');
        lev = utt(14:16); % type of noise
        spk = utt(1:3);
    elseif (strcmp(dataset,'chime3_lev0') || strncmp(dataset,'CH3lev0',7))
    	[utt, dirname] = basename(filename, '.wav');
        lev = utt(14:16); % type of noise
        spk = utt(1:3);
    elseif (strcmp(dataset,'chime3_chanconv') || strncmp(dataset,'CH3cc',5))
    	[utt, dirname] = basename(filename, '.wav');
        lev = utt(14:16); % type of noise
        spk = utt(1:3);
    elseif (strcmp(dataset,'chime3_big') || strncmp(dataset,'CH3big',6))
    	[utt, dirname] = basename(filename, '.wav');
        lev = utt(14:16); % type of noise
        spk = utt(1:3);
    else
        fprintf('Unknown dataset %s. default values are used.\n',dataset);
    	[utt, dirname] = basename(filename, '.wav');
        lev = 'default'; % type of noise
        spk = 'default';
    end
end

end
