function tifs=stitchAllSubDirectories(varargin)

    % %
    % % 
    %    WARNING: *** stitchAllSubDirectories has been deprecated ***
    % 
    %
    % What you should do:
    % Please use stitchAllChannels from now on since stitchAllSubDirectories 
    % will be totally removed in the future.
    %
    % What is the difference between these two functions?
    % stitchAllChannels is called from the sample directory and does
    % what is says: it stitches all channels from the current sample.
    % stitchAllSubDirectories did this but could could also descend 
    % into multiple sample directories and stitch them all.
    %
    % Why is stitchAllSubDirectories being removed?
    % 1) I think it was only ever used to stitch all channels so its other
    %    behaviors were poorly tested. 
    % 2) It required unix-specific system calls so didn't work on Windows.


    help(mfilename)

    if nargin>0
        fprintf('\n\n ** THIS IS JUST A WRAPPER AROUND stitchAllChannels.\n ** IT DOES NOT ACCEPT INPUT ARGS.\n')
        fprintf(' ** You should use stitchAllChannels instead.\n\n\n')
        return
    end
    tifs=[];
    tifs=stitchAllChannels;

