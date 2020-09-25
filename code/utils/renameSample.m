function renameSample(~,newSampleName)
	% Change the name of the sample in the current directory
	%
	% function renameSample(newSampleName)
	%
	% PURPOSE
	% Rename the sample in the current directory. This function renames
	% paramater files and also the sample ID within those files. The function
	% will not alter the name of the directory it is called from or 
	% the names of downsampled image files or any other similar files you
	% may produce. If you need to rename a sample, it therefore makes the
	% most sense to do this before you start producing downsampled stacks
	% of this sort. 
	%
	%
	% INPUTS
	% newSampleName - string specifiying new name
	%
	%
	% Rob Campbell - SWC 2019

	newSampleName = regexprep(newSampleName, ' ', '_'); %remove spaces
	newSampleName = regexprep(newSampleName, '[^0-9a-z_A-Z-]', ''); %remove non alphanumeric chars
	if regexp(newSampleName(1),'\d')
	    %Do not allow sample name to start with a number
	    newSampleName = ['sample_',newSampleName];
	elseif regexpi(newSampleName(1),'[^a-z]')
	    %Do not allow the sample to start with something that isn't a letter
	    newSampleName = ['sample_',newSampleName(2:end)];
	end


	m=readMetaData2Stitchit;
	origSampleName = m.sample.ID;
	configFileNames = dir(['*',m.sample.ID,'*']);

	%Rename these files
	for ii=1:length(configFileNames)
	    newFileName = strrep(configFileNames(ii).name,origSampleName,newSampleName);
	    fprintf('Renaming %s to %s\n',configFileNames(ii).name,newFileName)
	    movefile(configFileNames(ii).name,newFileName);
	end

	% Change param name in file
	m=readMetaData2Stitchit;
	oldFileContents = fileread(m.paramFileName);
	newFileContents = regexprep(oldFileContents,origSampleName,newSampleName);
	fid = fopen(m.paramFileName,'w');
	fprintf(fid,'%s',newFileContents);
	fclose(fid);

end
