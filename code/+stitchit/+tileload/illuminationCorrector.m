function im = illuminationCorrector(im,coords,userConfig,index,verbose)
    % illumination corrects tiles for stitchit tileLoad
    %
    % function im = stitchit.tileload.illuminationCorrector(im,coords,cropBy,userConfig,offSetValue,verbose)
    %
    % Purpose
    % There are multiple tileLoad functions for different imaging systems
    % but all perform illumination correction the same way using this function. 
    % This function is called by tileLoad.
    %
    % Inputs
    % im - the image stack to correct
    % coords - the coords argument from tileLoad
    % userConfig - [optional] this INI file details. If missing, this 
    %              is loaded and cropping params extracted from it. 
    % verbose - false by default
    %
    % Outputs
    % im - the cropped stack. 
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


    avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];

    if ~exist(avDir,'dir')
        fprintf('Please create grand averages with collateAverageImages\n')
    end

    aveTemplate = coords2ave(coords,userConfig);

    if isempty(aveTemplate)
        fprintf('Illumination correction requested but not performed\n')
        return
    end

    if verbose
        fprintf('Doing %s illumination correction\n',userConfig.tile.illumCorType)
    end

    switch userConfig.tile.illumCorType
        case 'split'
            
            if isempty(index)
                fprintf('*** ERROR in tileLoad.illuminationCorrector: split illumination requested but tile index not provided. Not correcting\n')
            end

            %Divide by the template. Separate odd and even rows as needed       
            oddRows=find(mod(index(:,5),2));
            if ~isempty(oddRows)
                im(:,:,oddRows)=stitchit.tools.divideByImage(im(:,:,oddRows),aveTemplate(:,:,2)); 
            end

            evenRows=find(~mod(index(:,5),2)); 
            if ~isempty(evenRows)
                im(:,:,evenRows)=stitchit.tools.divideByImage(im(:,:,evenRows),aveTemplate(:,:,1));
            end
        case 'pool'
            aveTemplate = mean(aveTemplate,3);
            if userConfig.subdir.averageDir
                aveTemplate = repmat(mean(aveTemplate,1), [size(aveTemplate,1),1]);
            end
            im=stitchit.tools.divideByImage(im,aveTemplate);
        otherwise
            fprintf('Unknown illumination correction type: %s. Not correcting!', userConfig.tile.illumCorType)
    end






%Calculate average filename from tile coordinates. We could simply load the
%image for one layer and one channel, or we could try odd stuff like averaging
%layers or channels. This may make things worse or it may make things better. 
function aveTemplate = coords2ave(coords,userConfig)

    layer=coords(2); %optical section
    chan=coords(5);

    fname = sprintf('%s/%s/%d/%02d.bin',userConfig.subdir.rawDataDir,userConfig.subdir.averageDir,chan,layer); %TODO: replace with fullfile
    if exist(fname,'file')
        %The OS caches, so for repeated image loads this is negligible. 
        aveTemplate = loadAveBinFile(fname); 
    else
        aveTemplate=[];
        fprintf('%s Can not find average template file %s\n',mfilename,fname)
    end


