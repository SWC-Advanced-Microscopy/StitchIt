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
    % userConfig - [optional] use settings from this INI file. If missing, the default is loaded.
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
    % TODO: we might in the future want to handle other template types, such as CIDRE.
    aveTemplate = stitchit.tileload.loadBruteForceMeanAveFile(coords,userConfig);


    if isempty(aveTemplate) || ~isstruct(aveTemplate)
        fprintf('Illumination correction requested but not performed\n')
        return
    end

    if verbose
        fprintf('Doing %s illumination correction\n',userConfig.tile.illumCorType)
    end


    % Optionally correct the illumination offset to avoid negative numbers in the final image
    %if userConfig.tile.doOffsetSubtraction
    if true
        m = stitchit.tools.getOffset(coords)
    else
        m = 0;
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
            im=stitchit.tools.divideByImage(im,aveTemplate.pooledRows-m);
        otherwise
            fprintf('Unknown illumination correction type: %s. Not correcting!', userConfig.tile.illumCorType)
    end





