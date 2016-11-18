function tileStats=writeTileStats(imStack,tileIndex,thisDirName,statsFile)
    % Writes a tile stats MAT file to each directory
    %
    % function writeTileStats(imStack,tileIndex,thisDirName,statsFile)
    %
    % Purpose
    % The tile stats file contains a bunch of useful statistics that other 
    % functions can later use to work out things like the intensity of the
    % background tiles, etc. 
    %
    % Input
    % imStack - A cell array of image stacks. The rows are channels and the
    %           columns are optical sections.
    % tileIndex - A cell array of tileIndex matrices.
    % thisDirName - a string defining the directory that contain these data
    % statsFile - string defining where to save the data. 


    fprintf('Creating stats file: %s\n',statsFile)              

    tileStats.dirName=thisDirName;

    for thisChan = 1:size(imStack,1) % Channels
        for thisLayer = 1:size(imStack,2) % Optical sections
            
            if isempty(imStack{thisChan,thisLayer}), continue, end
            
            tileStats.tileIndex{thisChan,thisLayer}=tileIndex{thisChan,thisLayer}(:,1);

            thisStack = imStack{thisChan,thisLayer};
            mu = squeeze(mean(mean(thisStack)));
            tileStats.mu{thisChan,thisLayer} = mu;

            % Create a threshold that should capture most of the empty tiles.
            % This will allow us to exclude most of them without having to resort
            % to fixed thresholds
            mu = sort(mu);
            bottomFivePercent = mu(1:round(length(mu)*0.05));
            if std(bottomFivePercent)>0.5
                fprintf('%s - Empty tile threshold not trustworthy, setting it to the mean of dimmest tile\n',mfilename)
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

        end
    end
    save(statsFile,'tileStats')