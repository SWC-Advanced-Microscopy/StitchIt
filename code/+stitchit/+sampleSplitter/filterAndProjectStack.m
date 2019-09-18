function [projectedStack,filteredStack] = filterAndProjectStack(im)
% filterAndProjectStack
%
% function projectedStack = filterAndProjectStack(im)
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
% projectedStack - 2D max intensity projection of the filtered stack.
%
%
% Rob Campbell - August 2019


    fprintf('Making and filtering max intensity projection\n')
    if exist('imresize3','file')
        filteredStack = imresize3(im,0.5);
        filteredStack = medfilt3(filteredStack,[3,3,3]);
        filteredStack = imresize(filteredStack,2);
    else
        %Same as above, just slower
        filteredStack = medfilt3(im,[3,3,3]);
    end

    projectedStack = max(filteredStack,[],3);
