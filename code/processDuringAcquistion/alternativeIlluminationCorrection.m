function alternativeIlluminationCorrection(varargin)
% The function calculates background images to correct nonlinear
% illumination for Tissue Vision tiles. Two mathods are available: CIDRE
% and BaSiC. By default it performs CIDRE correction.
% One model is calculated per 1 channel.
% The model.mat files are save in a rawData/avarageDir
% The following stitching then checks if this mat file exist or not and
% corrects the background if the file exist.
%
% stitchitConf.ini file needs to have doIlluminationCorrection = 1
% 
% Example:
% calculate CIDRE backgrounds
% alternativeIlluminationCorrection
%
% or specify 'cidre' or 'basic'
% alternativeIlluminationCorrection('basic')
%
% Natalia Chicherova - Basel, 2017

if nargin==0
    method = 'cidre';
else
    method = varargin{1};
end
fprintf('Backgound correction method is %s\n',method);

% destination folder is average dir of the average images
userConfig=readStitchItINI;
avDir = [userConfig.subdir.rawDataDir,filesep,userConfig.subdir.averageDir];
if ~exist(avDir,'dir')
    mkdir(avDir)
end

% find the number of channels for stitching
chansToStitch=channelsAvailableForStitching;

switch method
    case 'cidre'
        % calculate background model for illumination correction with CIDRE
        for thisChan=chansToStitch 
            tic;
             % source directory name is adjusted to the tissue cyte way of saving
            source = sprintf('./rawData/*_0%i.tif',thisChan);
            cidre(source, 'destination',avDir);
            t=toc/60;
            fprintf('Time for one chanel is %i minutes\n',t);
        end
    case 'basic'
        % do correction with BaSiC
        for thisChan=chansToStitch 
            % source directory name is adjusted to the tissue cyte way of saving
            source = sprintf('./rawData/*_0%i.tif',thisChan);
            basic_correction(source,'destination',avDir);
        end
end

