function startBackgroundWebPreview(chanToPlot,config)
    % Starts a background MATLAB process that sends low-res preview images of one channels to the web
    %
    % Purpose
    % Start an instance of MATLAB running the web preview in a loop
    % The function is Linux-specific

    mPath = config.syncAndCrunch.MATLABpath;
    nSecRun = which('buildSectionRunner');

    % The script file name we will build to run the background task
    params = readMetaData2Stitchit;
    micName = strrep(params.System.ID,' ','_');
    username = getenv('username');
    pathToBSfile = fullfile(tempdir,['webPreviewBootstrap_', username, '_', ,micName,'.m']);
    logFilePath = fullfile(tempdir,['webPreviewLogFile_', username, '_', micName]);
    
    % Before proceeding, let's kill any currently running background web previews
    PIDs=stitchit.tools.findProcesses(pathToBSfile);
    stitchit.tools.killPIDs(PIDs)

    % Write the boostrap file
    fid = fopen(pathToBSfile,'w');

    if fid<0
       fprintf('%s FAILED TO OPEN FILE at %s for writing\n', mfilename, pathToBSfile)
    else
        fprintf(fid,'cd(''%s'');\n', fileparts(nSecRun)); %cd to the function directory
        fprintf(fid,'buildSectionRunner(%d,''%s'');\n', chanToPlot, pwd);
        fclose(fid);
    end
 

    % Make empty log file
    fid = fopen(logFilePath,'w');
    if fid<0
       fprintf('%s FAILED TO OPEN FILE at %s for writing\n', mfilename, logFilePath)
    end
    fclose(fid);


    if exist(mPath,'file')
        CMD = sprintf('%s -nosplash -nodesktop -r ''run("%s")'' > %s &', mPath, pathToBSfile, logFilePath);
        msg = sprintf('Running background web preview with:\n %s\n', CMD);
        stitchit.tools.writeLineToLogFile('StitchIt_Log.txt', msg); %HARD-CODED log file name, but ok...
        unix(CMD);
    else
        fprintf(['Can not find MATLAB executable at %s. ', ...
        'Not running background web preview process.\n'...
        'Web preview may lag behind acquisition if dataset is large.\n'], mPath)
    end

