function [tileStats,imStack]=writeTileStats(imStack,tileIndex,thisDirName,statsFile)
    % Writes a tile stats MAT file to each directory
    %
    % function [tileStats,imStack]=writeTileStats(imStack,tileIndex,thisDirName,statsFile)
    %
    % Purpose
    % The tile stats file contains a bunch of useful statistics that other 
    % functions can later use to work out things like the intensity of the
    % background tiles, etc. 
    %
    % Inputs
    % imStack - A cell array of image stacks. The rows are channels and the
    %           columns are optical sections.
    % tileIndex - A cell array of tileIndex matrices.
    % thisDirName - a string defining the directory to which we will save the data
    % statsFile - string defining where to save the data.
    %
    %
    % Outputs
    % tileStats - tile statistics data structure
    % imStack - cell array of image stacks after offset correction (nothing 
    %           is changed if no offset correction was requested).
    % 
    % Rob Campbell - Basel 2017


    fprintf('Creating stats file: %s\n',statsFile)

    tileStats.dirName=thisDirName;
    userConfig=readStitchItINI;
    M=readMetaData2Stitchit;

    for thisChan = 1:size(imStack,1) % Channels
        for thisLayer = 1:size(imStack,2) % Optical sections

            if isempty(imStack{thisChan,thisLayer}), continue, end

            tileStats.tileIndex{thisChan,thisLayer}=tileIndex{thisChan,thisLayer}(:,1);

            thisStack = imStack{thisChan,thisLayer};
            mu = squeeze(mean(mean(thisStack)));
            tileStats.mu{thisChan,thisLayer} = mu;

            [mu,sortedInds] = sort(mu);

            % Find the offset value using a mixture of Gaussians based on the dimmest tiles
            % This is useful for some imaging systems only. For ScanImage it could be helpful
            % but for systems that discard this offset it won't mean anything. So we don't 
            % calculate this for systems where it won't help
            tileStats.offsetMean(thisChan,thisLayer) = 0; % by default set to zero then over-write if the user asked for an offset
            if userConfig.tile.doOffsetSubtraction
                switch M.System.type
                case 'bakingtray'
                    proportionOfDimmestFramesToUse=0.1;
                    nDimmestFrames = floor(length(sortedInds)*proportionOfDimmestFramesToUse);

                    if nDimmestFrames==0;
                        nDimmestFrames=1;
                    end

                    dimFrames=thisStack(:,:,sortedInds(1:nDimmestFrames));
                    options = statset('MaxIter', 1000);
                    Gm=fitgmdist(single(dimFrames(1:100:end)'),2, 'SharedCovariance', true, 'Options', options); % Mixture of 2 Gaussians
                    if Gm.Converged
                        [~,maxPropInd]=max(Gm.ComponentProportion);
                        tileStats.offsetMean(thisChan,thisLayer) = Gm.mu(maxPropInd);
                    else
                        % It's already filled with a zero
                    end
                end % switch
            end %if userConfig.tile.doOffsetSubtraction





            % Create a threshold that should capture most of the empty tiles.
            % This will allow us to exclude most of them without having to resort
            % to fixed thresholds.
            % TODO: Possibly we can use the model fit from above to help with this, 
            %       but I'm not sure how.

            bottomFivePercent = mu(1:round(length(mu)*0.05));
            if std(bottomFivePercent)>0.6
                fprintf('%s - Empty tile threshold not trustworthy (STD=%0.2f), setting it to the mean of dimmest tile.\n',...
                    mfilename, std(bottomFivePercent))
                emptyTileThresh=mu(1);
            else
                STDvals=zeros(size(mu));
                for ii=1:length(mu)
                    STDvals(ii)=std(mu(1:ii));
                end
                f=find(STDvals<0.085); %A threshold that we'll consider to represent the empty tiles

                emptyTileThresh=mu(f(end))*1.01;
            end

            tileStats.emptyTileThresh(thisChan,thisLayer)=emptyTileThresh;

            %Store a histogram for each tile
            tileStats.histogram{thisChan,thisLayer} = cell(1,size(thisStack,3));
            for thisTile = 1:size(thisStack,3)
                tmp = single(thisStack(:,:,thisTile));
                [n,x] = hist(tmp(1:10:end), 1000); %every 10th for speed, even though it means we'll miss the extreme values. 
                tileStats.histogram{thisChan,thisLayer}{thisTile} = [n;x];
            end
        end
    end
    save(statsFile,'tileStats')

    % If a second output (the offset-corrected image stack) is requested, then create this, 
    % otherwise just return.
    if nargout<2
        return
    end

    % Apply the tile offset. (It will be zero if it was not calculated)
    for thisChan = 1:size(imStack,1) % Channels
        offsetMu = mean(tileStats.offsetMean(thisChan,:)); %since all depths will have the same underlying value
        offsetMu = cast(offsetMu,class(imStack{1,1}));

        for thisLayer = 1:size(imStack,2) % Optical sections
            imStack{thisChan,thisLayer} = imStack{thisChan,thisLayer} - offsetMu;
        end
    end