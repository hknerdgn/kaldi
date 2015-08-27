function [ basename, dirname ] = basename(fname, ext)

% normalize extension    
if exist('ext', 'var') && ext(1) ~= '.'
    ext = [ '.' ext ];
end

% split
idx = find(fname == '/');
if length(idx) > 0
    basename = fname(idx(end)+1:end);
    dirname = '';
    if idx(end) > 1
        dirname = fname(1:idx(end)-1);    
    end
else
    basename = fname;
end

% remove extension
if exist('ext', 'var')
    idx = strfind(basename, ext);
    if size(idx) > 0
        basename = basename(1:idx(1)-1);
    end
end
    
end
