classdef (Abstract) micSys

    %StitchIt abstract class that defines the methods used to handle data 
    %from different data acquisition systems.
    properties (Constant)
    end


    methods (Abstract)

        % For user documentation for each method run "help MethodName" at the command line
        % e.g. help tileLoad

        % Load raw tile data 
        tileLoad(obj,coords,doIlluminationCorrection,doCrop,doPhaseCorrection)

        %Get the parameter file from the acquisition system
        getTiledAcquisitionParamFile(obj)

        % Read acquisition meta data into a MATLAB structure
        readMetaData2Stitchit(obj)

        % Index all raw data tiles in an experiment, link original file names to position in tile array 
        generateTileIndex(obj)

          %Get section directory base name from the parameter file name
        directoryBaseName(obj)

        %Extract section number from directory name
        sectionDirName2sectionNum(obj,sectionDirName)

        %Determine which channels are available
        channelsAvailableForStitching(obj)

    end

end