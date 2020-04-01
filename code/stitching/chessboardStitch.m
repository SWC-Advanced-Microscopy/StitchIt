function varargout=chessboardStitch(planeToStitch,channel,params)
% Chessboard stitch a defined optical plane and channel to test stitching quality. 
%
% function imData = chessboardStitch(planeToStitch,channel,params)
%
% Purpose
% Stitching quality is easiest to assess when "chessboard stitching" the image:
% https://github.com/SainsburyWellcomeCentre/BakingTray/wiki/Fine-tuning-positioning-accuracy
% This function produces a chessboard stitched image that is returned
% as a matrix and can be viewed with exploreChessBoard
%
%
% Inputs
% planeToStitch - vector defining the physical and optical section to stitch
% channel - scalar defining which channel to stitch
% params - optional parameter structure to be used for stitching. 
%
%
% Outputs
% imData - a structure containing the stitched image and also the 
%          parameters used to generate it. This can be fed back in
%          into this funtion in a modified form to produce different
%          stitching results. 
%
%
% Example
% Stitch physical section 2, optical plane 1, channel 1:
% >> IM=chessboardStitch([3,1],1);
%
% Now visualise this:
% >> exploreChessBoard(IM) % (mouse wheel zooms, right-drag to pan )
% >> exploreChessBoard(IM,2000) %Again but with a new threshold 
%
% Notice something we want change:
% >> IM(2) = IM;
% >> IM(2).params.affineMat = affineMatGen('rot', -0.4); %This function is in BakingTray
% >> IM(2) = chessboardStitch([3,1],1,IM(2).params); %To use new parameters
%
% Compare the two stitching results side by side:
% >> exploreChessBoard(IM,2000)
%
%
% Rob Campbell - September 2019, SWC
%
% See also: exploreChessBoard


if nargin<3
    params=[];
end

if isstruct(params)
    % Write a temporary file for the stitcher to read. A bit crap, but this 
    % is by far the easiest way. 

    tagStr = 'zzCHESSzz';
    d=dir(['*',tagStr,'*']);
    if ~isempty(d)
        for ii=1:length(d)
            fprintf('Deleting old temporary params file %s\n', d(ii).name);
            delete(d(ii).name)
        end
    end

    % TODO the following is BakingTray-specific because it assumes we are using YML files
    tmp = readMetaData2Stitchit;
    fullParams = yaml.ReadYaml(tmp.paramFileName);

    %Replace the fields related with stitching
    fullParams.StitchingParameters.VoxelSize = params.voxelSize;
    fullParams.StitchingParameters.lensDistort = params.lensDistort;
    fullParams.StitchingParameters.affineMat = params.affineMat;

    [~,fname,ext] = fileparts(params.paramFileName);
    newFname = [fname,'_',tagStr,ext];
    yaml.WriteYaml(newFname,fullParams);
end


try
    [im,p]=stitchSection(planeToStitch,channel,'ChessBoard',true);
    if isstruct(params)
       delete(newFname)
    end
catch ME
    if isstruct(params)
        delete(newFname)
    end
    rethrow(ME)
end


if nargout>0
    out.im=im;
    out.params=p;
    varargout{1}=out;
end


