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

    % if finds mat files - cidre stitch, otherwise average
    [alternative_correction,model] = check_cidreModel(coords,userConfig);
    if alternative_correction
        im = correct_not_average(im,model);
    else
        im = correct_average(coords,userConfig,im,verbose);
    end





%Calculate average filename from tile coordinates. We could simply load the
%image for one layer and one channel, or we could try odd stuff like averaging
%layers or channels. This may make things worse or it may make things better. 
function im = correct_average(coords,userConfig,im,verbose)

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

            if userConfig.tile.averageSlowRows
                aveTemplate(:,:,1) = repmat(mean(aveTemplate(:,:,1),1), [size(aveTemplate,1),1]);
                aveTemplate(:,:,2) = repmat(mean(aveTemplate(:,:,2),1), [size(aveTemplate,1),1]);
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



function [alternative_correction,model] = check_cidreModel(coords,userConfig)

    avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];
%     layer=coords(2); %optical section
    chan=coords(5);
    optical_section = 0;
    % find mat files
    fname_cidre = [avDir sprintf('/cidre_chanel%i_optical_section_%i.mat',chan,optical_section)];
    % how cidre model structure should look like
    modelC_def.method    = 'CIDRE';
    modelC_def.v         = [];
    modelC_def.z         = [];
    modelC_def.v_small   = [];
    modelC_def.z_small   = [];
    
    % find mat files
    fname_basic = [avDir sprintf('/basic_chanel_%i.mat',chan)];
    % how BaSiC model structure should look like
    modelB_def.method    = 'basic';
    modelB_def.v         = [];
    modelB_def.z         = [];

    % check if the mat files exist and load the backgrounds
    if exist(fname_cidre,'file')>0
        load(fname_cidre);
        names_def = fieldnames(modelC_def);
        names = fieldnames(model);
        tf = strcmp(names_def,names);
        if ~isempty(find(tf==0))
            alternative_correction = 0;
            disp('the fields in the cidre model are not correct.')
        else 
            alternative_correction = 1;

        end
    elseif exist(fname_basic,'file')>0
         load(fname_basic);
         % get the default names
         names_def = fieldnames(modelB_def);
         names = fieldnames(model);
         % compare if teh fields are simillar
         tf = strcmp(names_def,names);
         if ~isempty(find(tf==0))
            alternative_correction = 0;
            disp('the fields in the cidre model are not correct.')
        else 
            alternative_correction = 1;
        end
                 
    else
        % will do average tile correction
        alternative_correction = 0;
    end
