function minProj = recoverVasculature(imStack, thresh, filtSize)
% Obtain vasculature pattern from serial-section 2p data
%
% function minProj = recoverVasculature(imStack, thresh, filtSize)
%
% Purpose
% Find the surface of the brain in a down-sampled image stack in order to 
% bring out the vasculature. This can be then be used for tasks such as
% aligning associated in vivo data to the Allen Atlas. 
%
% Inputs
% imStack - 3-D downsampled image stack 
% thresh - Threshold for defining the surface of the brain (100 by default)
%          Try smaller values if the image looks too smooth. 
% filt -  The size of the median filter applied to the 2-D image  for 
%         smoothing the surface estimate (5 by default). The vasculature 
%         may pop out better with larger values. 
%
% 
% Usage Note
% The first step of the process performs a 3-D median filter on the 
% image stack. Since this is slow, the result is cached. If you wish
% re-use the last cached filtered stack supply an empty array as the
% first input argument. e.g.
% >> myImStack = stitchit.tools.mhd_read('downsampledMHD_25/dsRC_LR09_190311_125513_25_25_02.mhd');
% >> mp = recoverVasculature(myImStack);
% >> mp = recoverVasculature([],200); % Repeat with a non-default threshold value
%
%
% P. Znamenskiy, 2018, London


if nargin<3
    filtSize = 5;
end
if nargin<2
    thresh = 100;
end

if mod(filtSize,2) == 0
    filtSize = filtSize+1;
    fprintf('Setting filtSize to %d as it should be an odd number\n',filtSize)
end
% Handle caching of the smoothed stack
cacheName = [mfilename,'_CACHED_STACK'];
if isempty(imStack)
    fprintf('Retrieving cached stack\n')
    imStack = evalin('base',cacheName);
else
    fprintf('Median filtering image stack...')
    imStack = medfilt3(imStack,[3,3,3]); % This is to tidy the stack and small filter is all that's needed
    assignin('base',cacheName,imStack)
    fprintf('\n')
end



fprintf('Finding brain surface')
% find the surface
brainPos = zeros(size(imStack,2), size(imStack,3));
for indY = 1:size(imStack,2)
    for indZ = 1:size(imStack,3)
        brainSurface = find(imStack(:,indY,indZ)>thresh,1,'first'); %Index of first brain pixel
        if ~isempty(brainSurface)
            brainPos(indY, indZ) = brainSurface;
        end
    end
end
fprintf('\n')


brainPos = medfilt2(brainPos,[filtSize,filtSize]);

minProj = zeros(size(imStack,2), size(imStack,3));

% look up mean flourescence around median filtered surface
for indY = 1:size(imStack,2)
    for indZ = 1:size(imStack,3)
        if brainPos(indY,indZ)<size(imStack,1)-1 && brainPos(indY,indZ)>1
        	% average over surrounding pixels - this could be an input argument
            minProj(indY, indZ) = mean(imStack(brainPos(indY,indZ)-1: ...
                brainPos(indY, indZ)+1,indY,indZ));
        end
    end
end
