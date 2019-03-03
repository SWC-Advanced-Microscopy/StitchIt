function everythingOK = checkROIapplication(stitchedDataStruct, croppedDir)
% Confirm that the data in croppedDir match what is expected
% based on the structure stitchedDataStruct
%
% Inputs
% stitchedDataStruct - one instance (i.e. length of 1) from
% output of findStitchedData
% croppeDir - relative or absolute path to the cropped image
% directory corresponding to the information in stitchedDataStruct.
%
%
%


  everythingOK=false;
  if length(stitchedDataStruct)>1
    fprintf(['\ncheckROIapplication expects argument stitchedDataStruct ', ...
             'to have a length of 1\n'])
    return
  end

  % Get data from cropped directory such that it's in the same
  % format as the original stitched data.
  croppedDirStruct = findStitchedData(croppedDir);


  % Are all channels present?
  if length(croppedDirStruct.channel) ~= ...
        length(stitchedDataStruct.channel)
    
    fprintf(['\nDirectory %s does not contain the same number of channels ', ...
             'as original directory %s\n'], croppedDir, ...
            stitchedDataStruct.stitchedBaseDir)
    
    return

  end

  % Are all files present?
  if ~isequal( [croppedDirStruct.channel(:).numTiffs], ...
               [stitchedDataStruct.channel(:).numTiffs] )

    fprintf(['\nDirectory %s does not contain the same number of TIFFs ', ...
             'as original directory %s\n'], croppedDir, ...
            stitchedDataStruct.stitchedBaseDir)
      fprintf('             Orig     ROI \n')
    for ii=1:length(croppedDirStruct.channel)
      fprintf('Channel %d -- %d  vs  %d \n', ...
              croppedDirStruct.channelsPresent(ii), ...
              stitchedDataStruct.channel(ii).numTiffs, ...
              croppedDirStruct.channel(ii).numTiffs)
    end
    
    return

  end


  % Are all files the same size? TODO

  everythingOK=true;
