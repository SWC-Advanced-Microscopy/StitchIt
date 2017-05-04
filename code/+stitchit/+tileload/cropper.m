function [im,cropByPixels] = cropper(im,userConfig,verbose)
    % crops tiles for stitchit tileLoad
    %
    % function im = stitchit.tileload.cropper(im,userConfig,verbose)
    %
    % Purpose
    % There are multiple tileLoad functions for different imaging systems
    % but all crop tiles the same way using this function. 
    % This function is called by tileLoad.
    %
    % Inputs
    % im - the image stack to crop
    % userConfig - [optional] this INI file details. If missing, this 
    %              is loaded and cropping params extracted from it. 
    % verbose - false by default
    %
    % Outputs
    % im - the cropped stack. 
    % cropByPixels - The number of pixels on each side of the image that were trimmed. 
    %
    %
    % Rob Campbell - Basel 2017

    if nargin<2 || isempty(userConfig)
        userConfig = readStitchItINI;
    end

    if nargin<3 || isempty(verbose)
        verbose=false;
    end

    cropByPixels=round(size(im,1) * userConfig.tile.cropProportion); 

    if verbose
        fprintf('Cropping images by %d pixels on each size\n', cropByPixels)
    end

    im  = im(cropByPixels+1:end-cropByPixels, cropByPixels+1:end-cropByPixels, :);
