function varargout=estimateEndTime
% Estimates time at which the current imaging run will end
%
% function endTime=estimateEndTime
%
% PURPOSE
% Estimate time at which the current imaging run will end. Initially uses the 
% number of tiles, etc, to figure this out. Once 5 sections have been taken,
% it uses the interval between sections instead. 
%
% Rob Campbell - Basel 2015



%First calculate the number of hours the whole thing will take
param=readMetaData2Stitchit;



if strcmp(param.System.type,'bakingtray')
    out=estimateEndTimeBT; %TODO: have BT calculate this so StitchIt does nothing at all
    if nargout>0
        varargout{1}=out;
    end
    return
end

%TODO: the following is a poor way of proceeding
%could calculate the tile time from the line period and number of lines plus the move time
timeFor832Tile = 0.715; %Time in seconds for an 832*832 image
tileTime = timeFor832Tile * param.tile.nRows/832;

%number of hours per phyical section (i.e. per section directory)
cuttingTime = (35/param.Slicer.cuttingSpeed) + param.Slicer.postCutDelay + 2; %approximate number of seconds per cut
hoursPerDirectory = (param.mosaic.numOpticalPlanes * param.numTiles.X * param.numTiles.Y * tileTime + cuttingTime) / 60^2;


%Total time is, therefore:
totalTime = hoursPerDirectory*param.mosaic.numSections;




%If we have enouggh data directories, we can obtain a potentially more 
%accurate value by looking at the number of directories produced and the
%start time of the acquisition
userConfig=readStitchItINI;

d=dir( fullfile(userConfig.subdir.rawDataDir,[directoryBaseName,'*']) );

if length(d)>5
    nDir = length(d);
    elapsedDays = now-datenum(param.sample.acqStartTime);
        hoursPerDirectory = (elapsedDays*24)/nDir;
       totalTime = hoursPerDirectory * param.mosaic.numSections;
end



%So now the time left in hours is:
timeLeft = totalTime * (param.mosaic.numSections-length(d))/param.mosaic.numSections;

if timeLeft > 1.5
    remainingString=sprintf('Time left: %d hours', round(timeLeft));
elseif timeLeft <= hoursPerDirectory
    remainingString='All sections acquired';
else
    remainingString=sprintf('Time left: %d minutes', round(timeLeft*60));
end

if timeLeft <= hoursPerDirectory
    finishingString='FINISHED';
else
    finishingString=sprintf('Finishing at %s', datestr(now+timeLeft/24, 'HH:MM on ddd dd/mm'));
end

    
if nargout<1
    fprintf('%s\n',remainingString);
    fprintf('%s\n',finishingString);
end

if nargout>0
    out.finishingString=finishingString;
    out.remainingString=remainingString;
    out.hoursPerDirectory=hoursPerDirectory;
    varargout{1}=out;
end
