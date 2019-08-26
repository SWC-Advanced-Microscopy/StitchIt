function out = filterAndProjectStack(im)
% filterAndProjectStack
%
% function filteredStack = filterAndProjectStack(im)
%
% Purpose
% Reduce noise and median filter downsampled stack. Then
% take max intensity projection. This can then be used to 
% draw a border around the brain.
%
% Inputs
% im - 3D image stack
%
% Outputs
% out - 2D max intensity projection of the filtered stack.
%
%
% Rob Campbell - August 2019


    fprintf('Making and filtering max intensity projection\n')
    if exist('imresize3','file')
        tmp = imresize3(im,0.5);
        tmp = medfilt3(tmp,[3,3,3]);
        tmp = imresize(tmp,2);
    else
        %Same as above, just slower
        tmp = medfilt3(im,[3,3,3]);
    end

    out = max(tmp,[],3);
