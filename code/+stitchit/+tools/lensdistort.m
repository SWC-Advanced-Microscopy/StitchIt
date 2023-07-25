function outputIm = lensdistort(inputIm, k, varargin)
% lensdistort corrects for barrel and pincusion lens abberations
%
%   outputIm = lensdistort(inputIm, k)
%
% Purpose
%   lensdistort corrects for radially symmetric distortions in image "inputIm" using
%   distortion parameter "k". Allowed lens distortions can be one of two types: 
%   a) Barrel distortion, where image magnification decreases with distance from the 
%      optical axis. The apparent effect is that of an image which has been mapped 
%      around a sphere (or barrel). Lines that do not go through the centre of the
%      image are outwards.
%   b) Pincushion distortion, where image magnification increases with the distance 
%      from the optical axis. The visible effect is that lines that do not go through 
%      the centre of the image are bowed inwards, towards the centre of the image, 
%      like a pincushion [1]. 
%
%
% Input arguments (required)
%  inputIm - The image to be corrected. Can be uint8, int8, uint16, int16, uint32,
%   int32, single, double, or logical. An input indexed image can be uint8,
%   uint16, single, double, or logical. inputIm can be an image stack also. 
%
%  k - signed scalar or vector of length 2 defining the distortion correction to apply.
%      If a scalar, the same degree of correction is applied to both axes. If a 
%      vector of length 2 it applies different corrections to the rows and columns:
%      [k_row,k_column]. A value of zero produces no correction along that axis.
%
%
% Input arguments (optional parameter/value pairs)
%
%   'borderType'            String that controls the treatment of the image
%                           edges. Valid strings are 'fit' and 'crop'. By 
%                           default, 'borderType' is set to 'crop'. 
%
%   'interpMethod'         String that specifies the interpolating kernel 
%                           that the separable resampler uses. Valid
%                           strings are 'cubic', 'linear' and 'nearest'. By
%                           default, the 'interpolation' is set to 'nearest'
%
%   'padMethod'             String that controls how the resampler 
%                           interpolates or assigns values to output elements 
%                           that map close to or outside the edge of the input 
%                           array. Valid strings are 'bound', circular',
%                           'fill', 'replicate', and symmetric'. By
%                           default, the 'padMethod' is set to 'fill'
%
%    'padValue'             Scalar defining the value with which the image the will be padded.
%                           By default this will be the minimum value found in the image.
%
%   'fType'                 Integer between 1 and 4 that specifies the
%                           distortion model to be used. The models
%                           available are:
%                           1:    s = r.*(1./(1+k.*r));
%                           2:    s = r.*(1./(1+k.*(r.^2)));
%                           3:    s = r.*(1+k.*r);
%                           4:    s = r.*(1+k.*(r.^2)); % DEFAULT
%
%   'affineMat'             If supplied, the distortion matrices are both transformed by this
%                           affine matrix. No error checks on its correctness.
%                           e.g. to shear: [1,0,0; 0.125,1,0; 0,0,1]
%
%   Examples
%   --------
%       c=checkerboard(25,30);
%       inputIm = c(:,:,1)*2^8;
%
%       figure
%       subplot(2,2,1), imagesc(inputIm), title('orig')
%       subplot(2,2,2), imagesc(lensdistort(inputIm, 0.2)), title('barrel')
%       subplot(2,2,3), imagesc(lensdistort(inputIm, -0.2)), title('pincushion')
%       subplot(2,2,4), imagesc(lensdistort(inputIm,[ -0.2,0.4])), title('both')
%
%
%   References
%   --------------
%   [1] http://en.wikipedia.org/wiki/Distortion_(optics), August 2012.
%
%   [2] Harri Ojanen, "Automatic Correction of Lens Distortion by Using
%       Digital Image Processing," July 10, 1999.
%
%   [3] G.Vassy and T.Perlaki, "Applying and removing lens distortion in post 
%       production," year???
%
%   [4] http://www.mathworks.com/products/demos/image/...
%       create_gallery/tform.html#34594, August 2012.
%
%   Created by Jaap de Vries, 8/31/2012
%   jpdvrs@yahoo.com
%
% Modifications
% - Separate k for rows and columns (R. Campbell, June 2018)
% - Neaten, update examples, etc (R. Campbell, June 2018)
% - Set default interpolator to nearest (R. Campbell, June 2018)
% - Allow the padding value to be set via an input argument (R. Campbell, June 2018)
% - Allow inputIm to be an image stack and process it in one go for speed. (R. Campbell, June 2018)
% - Affine transformation along with distortion correction. (R. Campbell, June 2018)


%-------------------------------------------------------------------------
% Parse input arguments

p = inputParser;
p.CaseSensitive = false;

% Specifies the required inputs
addRequired(p,'inputIm',@isnumeric);
addRequired(p,'k',@isnumeric);


% Sets the default values for the optional parameters
addParameter(p,'borderType','crop', @(x) any(validatestring(x,{'fit','crop'})) );
addParameter(p,'interpMethod','nearest', @(x) any(validatestring(x, {'cubic','linear', 'nearest'})) );
addParameter(p,'padMethod','fill', @(x) any(validatestring(x,{'bound','circular', 'fill', 'replicate', 'symmetric'})) );
addParameter(p,'fType',4, @isnumeric);
addParameter(p,'padValue', min(inputIm(:)), @isnumeric);
addParameter(p,'affineMat',[],@isnumeric)


% Pass all parameters and input to the parse method
parse(p,inputIm,k,varargin{:});

borderType = p.Results.borderType;
interpMethod = p.Results.interpMethod;
padMethod = p.Results.padMethod;
fType = p.Results.fType;
padValue = double(p.Results.padValue);
affineMat = p.Results.affineMat;

%Make zeros in k very small numbers instead otherwise the correction fails
%and ensure k has a length of 2 regardless of what the user asked for. 
if length(k)==1
    k=repmat(k,1,2);
end
k(k==0) = 1E-9;


%-------------------------------------------------------------------------
% Run the correction but short-circuit if nothing was requested
if all(k==0) && isempty(affineMat)
    outputIm=inputIm;
end
outputIm = imDistCorrect(inputIm,k);




%-------------------------------------------------------------------------
% Nested functions follow

    function correctedImage = imDistCorrect(inputIm,k)
        % imDistCorrect performs the transformation

        % Determine the size of the image to be distorted
        [M,N,~]=size(inputIm);
        centre = [round(N/2), round(M/2)];

        [xi,yi] = meshgrid(1:N,1:M); % Create N x M (#pixels) x-y points

        %  Convert the mesh into a column vector of coordinates relative to the centre
        xt = xi(:) - centre(1);
        yt = yi(:) - centre(2);

        [theta,r] = cart2pol(xt,yt); % Convert the x-y coordinates to polar coordinates

        % maxR is the maximum vector length (image centre to image corner)
        maxR = sqrt(centre(1)^2 + centre(2)^2);

        r = r/maxR; % Normalize the polar coordinate "r" based on maxR


        % Apply distortion to rows
        s = distortFun(r,k(1),fType);  % Apply the r-based transformation
        s2 = s * maxR; % un-normalize s
        brcor = borderCorrect(r,s,k(1), centre, maxR);
        s2 = s2 * brcor;
        ut = pol2cart(theta,s2); % Convert back to Cartesian coordinates
        xid = reshape(ut,size(xi)) + centre(1); %pixel shifts along columns (the distorted version of xi)


        % Apply distortion to columns
        s = distortFun(r,k(2),fType);  % Apply the r-based transformation
        s2 = s * maxR; % un-normalize s
        brcor = borderCorrect(r,s,k(2), centre, maxR);
        s2 = s2 * brcor;
        [~,vt] = pol2cart(theta,s2); % Convert back to Cartesian coordinates
        yid = reshape(vt,size(yi)) + centre(2); %pixel shifts along rows (the distorted version of yi)


        tmap_B = cat(3,xid,yid);

        if ~isempty(affineMat)
            tform = affine2d(affineMat);
            tmap_B = imwarp(tmap_B,tform);

            %We crop the image about the centre to keep it the same size
            Mind = (1:M) + floor((size(tmap_B,2)-M)/2);
            Nind = (1:N) + floor((size(tmap_B,1)-N)/2);
            tmap_B = tmap_B(Nind,Mind,:);
        end


        resamp = makeresampler(interpMethod, padMethod);
        correctedImage = tformarray(inputIm,[],resamp,[2 1],[1 2],[],tmap_B, padValue);

    end %imDistCorrect



    function s = distortFun(r,k,fcNum)
        % distortFun returns the model type to be used
        %
        % r - normalised radius value in polar coordinates
        % k - correction factor for distortion
        % fcNum - The correction function to apply

        switch fcNum
            case(1)
                s = r.*(1./(1+k.*r));
            case(2)
                s = r.*(1./(1+k.*(r.^2)));
            case(3)
                s = r.*(1+k.*r);
            case(4)
                s = r.*(1+k.*(r.^2));
            otherwise
                error('Distortion function "%d" is unknown', fcNum)
        end %switch
    end %distortFun



    function x = borderCorrect(r,s,k,centre, maxR)
        % borderCorrect creates a scaling parameter based on the 'borderType' selected
        %
        % r - normalised radius value in polar coordinates
        % s - the transformed (see distortFun) normalised radius value in polar coordinates
        % k - correction factor for distortion
        % centre - coordinates of the image centre
        % maxR - the maximum vector length (image centre to image corner) used to normalise r

        if k < 0
            if strcmp(borderType, 'fit')
               x = r(1)/s(1); 
            end
            if strcmp(borderType, 'crop')
               x = 1/(1 + k*(min(centre)/maxR)^2);
            end
        elseif k > 0
            if strcmp(borderType, 'fit')
               x = 1/(1 + k*(min(centre)/maxR)^2);
            end
            if strcmp(borderType, 'crop')
               x = r(1)/s(1);
            end
        end
    end %borderCorrect


end %lensdistort
