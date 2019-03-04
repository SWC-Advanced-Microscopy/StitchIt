function [okToRun,stats]=checkDiskUsage(ROIs,stitchedDataStats)
    % Check the amount of free space and how much extra space we will need to complete the ROI cropping.
    % Don't proceed if not enough space is available. Also report how much will be reclaimed once the 
    % cropping is complete. 
    %
    % Inputs
    % ROIs - The output of sampleSplitter.returnROIparams
    % stitchedDataStats - [optional] is the output of findStitchedData
    %                If supplied and has a length>1 then the total disk usage
    %                required to perform all crops is calculated. If they are done
    %                sequentially, then it would make sense for the user to supply
    %                one element at a time as an optional input argument.
    %
    % Outputs
    % okToRun - if true, there will be enough to proceed. false otherwise. 
    % stats - detailed information in a structure on how much space will be left and so on
    %


    if nargin<2 || isempty(stitchedDataStats)
        stitchedDataStats=findStitchedData;
    end

    totalDiskUsageByFullStacks = sum([stitchedDataStats(:).diskSizeInGB]);
    areaOfROIs = sum([ROIs.areaProportion]); %assumes non-overlapping ROIs
    totalDiskUsageOfCroppedStack = areaOfROIs * totalDiskUsageByFullStacks;
    d=stitchit.tools.returnDiskSpace;


    if totalDiskUsageOfCroppedStack > (d.freeGB-2)
        okToRun=false;
    else
        okToRun=true;
    end

    % Report to screen
    fprintf('\n%0.1f GB free disk space\n', d.freeGB)

    if totalDiskUsageOfCroppedStack<1
        croppedUsageStr = sprintf('%0.1f MB', totalDiskUsageOfCroppedStack*1024);
    else
        croppedUsageStr = sprintf('%0.1f GB', totalDiskUsageOfCroppedStack);
    end

    dUsage = totalDiskUsageByFullStacks-totalDiskUsageOfCroppedStack;
    if dUsage<1
        finalUsageStr = sprintf('%0.1f MB', dUsage*1024);
    else
        finalUsageStr = sprintf('%0.1f GB', dUsage);
    end

    fprintf('ROI splitting will temporaily add %s but finally will save %s.\n\n', ...
             croppedUsageStr, finalUsageStr);


    if nargout>1
        stats.totalDiskUsageByFullStacksInGB = totalDiskUsageByFullStacks;
        stats.totalDiskUsageOfCroppedStackInGB = totalDiskUsageOfCroppedStack;
        stats.diskUsage = d;
        stats.okToRun=okToRun;
    end
