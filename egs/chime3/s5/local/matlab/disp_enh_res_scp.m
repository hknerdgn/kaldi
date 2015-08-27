function[] = disp_res(mat_files_format, jobrange, eval_scp, out_csv)
% function[] = disp_res(mat_files_format, JOBrange, eval_scp)
% mat_files_format should be a string with %d sign in it in places where
% the %d will be replaced by a job number from jobrange
% eval_scp is a cell array of scp files from which uttId's will be taken
% to report the result for each eval_scp separately


[resdir, resname, ext]=fileparts(sprintf(mat_files_format,jobrange(1)));
[resdir2, resname2, ext2]=fileparts(resdir);
[resdir3, resname3, ext3]=fileparts(resdir2);
method=sprintf('%s_%s',resname3,resname2);

if (~exist('out_csv','var'))
   out_csv=sprintf('%s/%s_%s.csv',resdir,resname,resname3);
end

fprintf('Writing csv file to %s\n',out_csv);

k=0;
for i=jobrange
   load(sprintf(mat_files_format,i), 'measures');
   N=length(measures);
   allmeasures(k+1:k+N)=measures(1:N);
   k=k+N;
end

measures=allmeasures;

fprintf('Read %d measures from files\n',length(measures));

fnametotask=containers.Map;

numtask=length(eval_scp);
nm=length(measures);
taskexist=zeros(1,numtask);
for t=1:numtask
	tasknow=eval_scp{t};
	fid = fopen(tasknow,'r');
        if (fid < 0)
		continue;
	end	
	F=textscan(fid,'%s %s');
	fclose(fid);
	numfiles = length(F{1});
	fprintf('Assigning %d files to task file %s\n',numfiles,tasknow);
	for ff=1:numfiles
		uttId=F{1}{ff};
		fnametotask(uttId)=tasknow;
	end

	for m=1:nm
		if (isKey(fnametotask,measures(m).utt))
			measures(m).task=fnametotask(measures(m).utt);
		else
			measures(m).task='unknown_task';
		end
	end
	tasknow=eval_scp{t};
	taskidx{t}= strcmp({measures.task}, tasknow);
	ntf=sum(taskidx{t});
	fprintf('Found %d files in measures for task %s\n',ntf,tasknow);
	if (ntf>0) taskexist(t)=1; end
end

	
%levs = {'m6dB','m3dB', '0dB', '3dB', '6dB', '9dB'};
%levs = {'0','10', '20'};

% turns measures(i).lev into a cell array and takes their unique
% seems to be sorted
levs = unique({measures.lev});

fidcsv=fopen(out_csv,'w');
if (fidcsv < 0)
   fprintf('cannot open %s for writing',out_csv);
   return;
end

measuresOfInterest = {'glosnr','bglosnr','segsnr','bsegsnr','sdr','bsdr','sir','bsir','pesqwb','bpesqwb','stoi','bstoi'};
fprintf(fidcsv,'method,task,');

for jj=1:length(measuresOfInterest),
   fprintf(fidcsv,'%s,',measuresOfInterest{jj});
end
fprintf(fidcsv,'\n');

for t=1:numtask
 	if (taskexist(t) == 0) continue; end
	tasknow=eval_scp{t};
        [taskdir, taskname, ext]=fileparts(tasknow);
        [taskdir2, taskname2, ext2]=fileparts(taskdir);
	fprintf('------------\nEvaluating %s\n',tasknow);
	thisline=sprintf('%s,%s',method,taskname2);
for measureCell=measuresOfInterest

measureNow=cell2mat(measureCell);

% get arrays of measures of interest

if (isfield(measures,measureNow))

fprintf('\n------\n%s\n',measureNow);

eval(sprintf('%s=[measures.%s];',measureNow,measureNow));

for l = levs;
    fprintf('%s\t\t', char(l)); 
end
fprintf('%s\n', 'overall');


for l = levs;
    idx = (strcmp({measures.lev}, l) & taskidx{t});
    eval(sprintf('now%s=[%s(idx)];',measureNow,measureNow));
    eval(sprintf('mean_measure=mean(now%s);',measureNow));
    eval(sprintf('std_measure=std(now%s);',measureNow));
    fprintf('%.2f-+%.2f\t', mean_measure,std_measure);
end 
    % overall
    idx = taskidx{t};
    eval(sprintf('now%s=[%s(idx)];',measureNow,measureNow));
    eval(sprintf('mean_measure=mean(now%s);',measureNow));
    eval(sprintf('std_measure=std(now%s);',measureNow));
    fprintf('%.2f-+%.2f\t', mean_measure,std_measure);
    thisline=sprintf('%s,%.2f',thisline,mean_measure);

end % if isfield

end

fprintf('\n');
fprintf(fidcsv,thisline);
fprintf(fidcsv,'\n');
end

end
