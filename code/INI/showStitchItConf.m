function varargout=showStitchItConf(rawFile,INIfname)
% Print the current stitching settings to screen
%
% function fileContents=showStitchItConf(rawFile)
%
% Inputs
% rawFile - 0 by default. If 1, prints the raw contants of the file to screen.
%           if 0 is parses it and prints only what the INI parser sees. If -1 we
%           print nothing to screen. 
% INIfname - [optional] 'stitchitConf.ini' by default
%
%
% Outputs 
% fileContents - the raw contents of the INI file. optional. 
%                Doesn't depend on rawFile.
%
% Rob Campbell - Basel 2015

if nargin<1
    rawFile=0;
end

if nargin<2
    INIfname='stitchitConf.ini';
end



%Read INI file
ini = IniConfig();
ini.ReadFile(INIfname);


if rawFile==1 | nargout>0
    fileContents=ini.ToString();
end

if rawFile==1
    fprintf(fileContents)
end


if nargout>0
    varargout{1}=fileContents;
end

if rawFile==0
    showFields(readStitchItINI(INIfname));
end





function showFields(thisStruct)

    f=fields(thisStruct);

    for ii=1:length(f)
        thisField = thisStruct.(f{ii});
        if isstruct(thisField)
            showFields(thisField);
            continue
        end

        fprintf('%s - ',f{ii})

        if ischar(thisStruct.(f{ii}))
            fprintf('%s\n\n',thisStruct.(f{ii}))
        else
            disp(thisStruct.(f{ii}))
        end

    end