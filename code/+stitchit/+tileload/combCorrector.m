
function im = combCorrector(im,sectionDir,coords,userConfig)
    % crops tiles for stitchit tileLoad
    %
    % function im = stitchit.tileload.combCorrector(im,sectionDir,coords,userConfig)
    %
    % Purpose
    % There are multiple tileLoad functions for different imaging systems
    % but all do the comb correction of tiles the same way using this function. 
    % This function is called by tileLoad.
    %
    % Inputs
    % im - the image stack to crop
    % sectionDir - Path to the directory containing section data. 
    % coords - the coords argument from tileLoad
    % userConfig - [optional] this INI file details. If missing, this 
    %              is loaded and cropping params extracted from it. 
    %
    % Outputs
    % im - the cropped stack. 
    %
    %
    % Rob Campbell - Basel 2017

    if nargin<4 || isempty(userConfig)
        userConfig = readStitchItINI;
    end
    
    % if finds txt for shift - do the rows correction, otherwise Robs
    % corrections
    [TxTflag, Image_shift,stripe_size]  = check_rowsShiftTxt(coords,userConfig);
    if TxTflag
        im = correct_rowsShift(im,Image_shift,stripe_size);
    else
        im = correct_phases(im,sectionDir,coords,userConfig);
    end
    
    
    function [TxTflag, Image_shift,stripe_size]  = check_rowsShiftTxt(coords,userConfig)
        filename_shift = fullfile(userConfig.subdir.rawDataDir, userConfig.subdir.averageDir, '/Shifts_per_tile.txt');
        if exist(filename_shift)
            TxTflag = 1;
            fid = fopen(filename_shift, 'r');
            C = textscan(fid, '%s', [9 Inf]);
            A = fscanf(fid,'%d',[9 Inf]);
            fclose(fid);
            
            ind = find(A(1,:)==coords(1) & A(2,:)==coords(2));
            Image_shift = A(4:6,ind);
            stripe_size = A(7:end,ind);
        else
            TxTflag = 0;
            Image_shift = 0;
            stripe_size = 0;
        end
    
    
    
    
    
    function im = correct_phases(im,sectionDir,coords,userConfig)
        % DUPE
        %TODO: this is duplicated from tileLoad. 
        % it's easier this way but if it takes too long, we can feed in these
        % variables from tileLoad
        % 
        %Load tile index file (this function isn't called if the file doesn't exist so no 
        %need to check if it's there.
        tileIndexFile=sprintf('%s%stileIndex',sectionDir,filesep);
        index=readTileIndex(tileIndexFile);


        %Find the index of the optical section and tile(s)
        f=find(index(:,3)==coords(2)); %Get this optical section 
        index = index(f,:);

        indsToKeep=1:length(index);

        if coords(3)>0
            f=find(index(:,4)==coords(3)); %Row in tile array
            index = index(f,:);
            indsToKeep=indsToKeep(f);
        end

        if coords(4)>0
            f=find(index(:,5)==coords(4)); %Column in tile array
            index = index(f,:);
            indsToKeep=indsToKeep(f);
        end
        %% /DUPE

        corrStatsFname = sprintf('%s%sphaseStats_%02d.mat',sectionDir,filesep,coords(2));

        if ~exist(corrStatsFname,'file')
            fprintf('%s. phase stats file %s missing. \n',mfilename,corrStatsFname)
        else
            load(corrStatsFname);
            phaseShifts = phaseShifts(indsToKeep);
            im = applyPhaseDelayShifts(im,phaseShifts);
        end

        
    function IM = correct_rowsShift(im,Image_shift,stripe_size)
        IM = uint16(zeros(size(im)));
        for i = 1:size(im,3)
            Im = im(:,:,i);
            Im_shift = Image_shift(:,i);
            Im_stripe_size = stripe_size(:,i);
            start_stripe = 0;
            for S = 1:length(Im_stripe_size)
                stripes = Im_stripe_size(S);% no
                shift = Im_shift(S);    
                % take only part of the tile image due to different shifts
                im_stripe = Im(:,start_stripe+1:stripes);
                % shift to the left or right
                if shift>=0
                    % shift to the left
                    im1_shift = im_stripe;
                    for rows = 2:2:size(im1_shift,1)
                        im1_shift(rows,shift+1:end) = im_stripe(rows,1:end-shift);
                    end

                else
                    %     % shift to the right
                    shift = abs(shift);
                    im1_shift = im_stripe;
                    for rows = 2:2:size(im1_shift,1)
                        im1_shift(rows,1:end-shift) = im_stripe(rows,shift+1:end);
                    end

                end
                % rebuild the image but shifted
                Im(:,start_stripe+1:stripes) = im1_shift;
                start_stripe = stripes;
                IM(:,:,i) = Im;
            end
        end
    

