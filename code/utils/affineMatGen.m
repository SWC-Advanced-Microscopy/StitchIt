function varargout = affineMatGen(varargin)
% affineMatGen -- generate affine transformation matrix for rotation, shear, and scale
%
% function varargout = affineMatGen(varargin)
%
% * Purpose
% Simplify setting the affine matrix option in the BakingTray settings files. 
% This function allows the user to define rotation, shear, or scale and applies
% these to a test image if desired, returns the matrix as an optional output or
% prints it to screen in a form that can be pasted into BakingTray settings files. 
%
% * Inputs (optional param/value pairs)
% rotationAngle - scalar. Angle in degrees
% shear - vector of length 2. 
% scale - scalar or vector of length 2
% dispRes - bool. If true show result image
%
% * Outputs
% * aMat - the affine matrix (3 x 3). If missing, the matrix is printed to the 
%          command line.
%
%
% Examples
% Only Rotations
% >> affineMatGen('rot',30,'dispRes',true)
%
% - [0.8660, 0.5000, 0.0]
% - [-0.5000, 0.8660, 0.0]
% - [0.0, 0.0, 1.0]
%
%
% >> affineMatGen('rot',-30,'dispRes',true)
%
% - [0.8660, -0.5000, 0.0]
% - [0.5000, 0.8660, 0.0]
% - [0.0, 0.0, 1.0]
%
%
% Rotate and scale
% >> affineMatGen('rot',-30,'scale',0.5,'dispRes',true)
%
% - [0.4330, -0.2500, 0.0]
% - [0.2500, 0.4330, 0.0]
% - [0.0, 0.0, 1.0]
%
%
% Scale and shear
%
% >> affineMatGen('shea',[0.4,0.1],'scale',2.5,'dispRes',true)
%
% - [2.5000, 0.2500, 0.0]
% - [1.0, 2.5000, 0.0]
% - [0.0, 0.0, 1.0]
%
%
% Rob Campbell - SWC 2019





    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    %Parse optional arguments
    params = inputParser;
    params.CaseSensitive = false;
    params.addParameter('rotationAngle', 0, @(x) isnumeric(x) && isscalar(x));
    params.addParameter('shear', [0,0], @(x) isnumeric(x) && ismatrix(x));
    params.addParameter('scale', [1,1], @(x) isnumeric(x) );
    params.addParameter('dispRes', false, @(x) islogical(x) || x==0 || x==1);
    params.parse(varargin{:});

    rotationAngle=params.Results.rotationAngle;
    shear=params.Results.shear;
    scale=params.Results.scale;
    dispRes=params.Results.dispRes;
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


    if nargin == 0 
        return
    end



    %https://www.mathworks.com/discovery/affine-transformation.html
    rotMat = eye(3);
    if rotationAngle~=0
        rAngC = cos(deg2rad(rotationAngle));
        rAngS = sin(deg2rad(rotationAngle));

        rotMat(1,1)=rAngC;
        rotMat(2,2)=rAngC;
        rotMat(1,2)=rAngS;
        rotMat(2,1)=rAngS*-1;
    end

    shearMat = eye(3);
    if any(shear~=0)
        shearMat(1,2)=shear(2);
        shearMat(2,1)=shear(1);
    end

    scaleMat = eye(3);
    if length(scale)==1
        scale = repmat(scale,[1,2]);
    end
    if any(scale~=0)
        scaleMat(1,1)=scale(1);
        scaleMat(2,2)=scale(2);
    end


    aMat = rotMat * shearMat * scaleMat;


    % Optionally display the effect of the transform using a checkerboard
    if dispRes
        f=findobj('Tag',mfilename);
        if isempty(f)
            f=figure;
            set(f,'Tag',mfilename);
        else
            clf(f)
        end

        % Generate a grid we will deform
        myMat=checkerboard(15,15);
        myMat(2,:)=1;
        myMat(end-1,:)=1;
        myMat(:,2)=1;
        myMat(:,end-1)=1;

        % Display this
        subplot(1,2,1)
        imagesc(myMat)
        axis equal tight

        % Deform and display results
        subplot(1,2,2)
        tform = affine2d(aMat);
        myMat = imwarp(myMat,tform);
        imagesc(myMat)
        axis equal tight

        colormap gray
    end



    % Either return as a matrix or print to screen in a format
    % suitable for pasting into a BakingTray settings file.
    if nargout>0
        varargout{1}=aMat;
    else
        %Print to the screen
        fprintf('\n')
        for ii=1:size(aMat,1)
            fprintf(' - [')
            for jj = 1:size(aMat,2)
                if mod(aMat(ii,jj),1)==0
                    fprintf('%0.1f',aMat(ii,jj))
                else
                    fprintf('%0.6f',aMat(ii,jj))
                end
                if jj<size(aMat,2)
                    fprintf(', ')
                end
            end
            fprintf(']\n')
        end
        fprintf('\n')
    end