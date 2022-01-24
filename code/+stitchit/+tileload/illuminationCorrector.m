function im = illuminationCorrector(im,coords,userConfig,index,verbose)
    % Perform illumination correction for aqcuired tiles as they area loaded
    %
    % function im = stitchit.tileload.illuminationCorrector(im,coords,userConfig,index,verbose)
    %
    % Purpose
    % There are multiple tileLoad functions for different imaging systems
    % but all perform illumination correction via this function. Different illumination
    % correction system are possible and this function selects between them and implements
    % them as appropriate. This function is called by tileLoad.
    %
    % Inputs
    % im - the image stack to correct
    % coords - the coords argument from tileLoad
    % userConfig - [optional] use setings from this INI file. If missing, the default is loaded. 
    % verbose - false by default
    %
    %
    % Outputs
    % im - the cropped and illumination corrected stack.
    %
    %
    % Rob Campbell - Basel 2017


    if nargin<3 || isempty(userConfig)
        userConfig = readStitchItINI;
    end

    if nargin<4 
        index=[];
    end

    if nargin<5
        verbose=false;
    end


    % Do not proceed if the grand average directory does not exist
    avDir = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir);
    if ~exist(avDir,'dir')
        fprintf([' Can not proceed with illumination correction. Found no grand average images in .%s%s\n',...
            ' Please create grand averages with collateAverageImages.\n'],...
            filesep,avDir)
        return
    end


    % For now we just load the brute-force average template 
    % TOOD: handle other template types, such as CIDRE
    aveTemplate = loadBruteForceMeanAveFile(coords,userConfig);

    if isempty(aveTemplate) || ~isstruct(aveTemplate)
        fprintf('Illumination correction requested but not performed\n')
        return
    end

    if verbose
        fprintf('Doing %s illumination correction\n',userConfig.tile.illumCorType)
    end


    % The following stops the average template from containing negative numbers
    % It's a bit of a hack to deal with https://github.com/SainsburyWellcomeCentre/StitchIt/issues/145
    correctIllumOffset=true;
    if correctIllumOffset
        chan = coords(5);
        m=stitchit.tools.getOffset(chan);
    else
        m=0;
    end

    switch userConfig.tile.illumCorType
        case 'split'
            
            if isempty(index)
                fprintf('*** ERROR in tileLoad.illuminationCorrector: split illumination requested but tile index not provided. Not correcting\n')
            end

            %Divide by the template. Separate odd and even rows as needed
            oddRows=find(mod(index(:,5),2));
            if ~isempty(oddRows)
                im(:,:,oddRows)=stitchit.tools.divideByImage(im(:,:,oddRows),aveTemplate.oddRows-m); 
            end

            evenRows=find(~mod(index(:,5),2)); 
            if ~isempty(evenRows)
                im(:,:,evenRows)=stitchit.tools.divideByImage(im(:,:,evenRows),aveTemplate.evenRows-m);
            end
        case 'pool'
            im=stitchit.tools.divideByImage(im,aveTemplate.pooledRows - m);
        otherwise
            fprintf('Unknown illumination correction type: %s. Not correcting!', userConfig.tile.illumCorType)
    end







function avData = loadBruteForceMeanAveFile(coords,userConfig)
    % Determine the average filename (correct channel and optical plane/layer) from tile coordinates.

    layer=coords(2); %optical section
    chan=coords(5);

    %If we find a .bin file. Prompt the user to re-run collate average images to make the new-style files. 
    fname = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir, num2str(chan), sprintf('%02d.bin',layer));
    if exist(fname)
        fprintf('\n ===> ERROR: Found an old-style .bin file. Plase re-run collateAverageImages <===\n\n')
        avData=[];
    end

    fname = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir, num2str(chan), sprintf('%02d_bruteAverageTrimmean.mat',layer));

    if exist(fname,'file')
        load(fname) % Will produce the "avData" variable <------
    else
        avData=[];
        fprintf('%s Can not find average template file %s\n',mfilename,fname)
    end