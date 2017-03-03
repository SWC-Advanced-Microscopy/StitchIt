function saveMatrixAsCSV(data, fname, colNames)
%  function saveMatrixAsCSV(data, fname, colNames)
%
% Save matrix 'data' as a csv file with columns labeled from colNames which
% is a csv string.
%
% This function saves as tab sep to a temporary file and converts to csv
% with sed. 
%
% Rob Campbell, March 2006

if nargin==0
    help(mfilename)
    return
end

    
data=double(data); 


r=round(rand*1E5);
tmp=sprintf('%s.%d.tmp',fname,r);

save(tmp,'data', '-ASCII', '-TABS')

if isunix
	unix(sprintf('sed ''s/\t /,/g'' %s > %s.csv',tmp,tmp));
else
	error('You are attempting to run %s to write %s. However this function uses sed and won''t run on Windows\n',...
		mfilename,fname)
end




if nargin>2
    unix(['echo "', colNames, '" > ', fname]);
    unix(sprintf('cat %s.csv >> %s', tmp,fname));
elseif nargin==2
    unix(sprintf('cat %s.csv > %s', tmp,fname));
end


delete([tmp,'*'])
